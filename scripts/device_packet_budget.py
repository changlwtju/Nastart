"""Count IP traffic from pymobiledevice3 pcapd packets without PID filtering.

The counter is a measurement primitive, not a carrier billing meter or a
standalone cellular safety guarantee. Validate capture coverage and stop latency
on Wi-Fi before using its budget signal. Raw frames must stay outside the repo.
"""
from dataclasses import dataclass
import ipaddress
import re
from typing import Optional


@dataclass(frozen=True)
class PacketSize:
    interface: str
    ip_bytes: int
    source: str
    destination: str
    source_port: Optional[int] = None
    destination_port: Optional[int] = None
    tcp_payload_bytes: int = 0
    # Base IP protocol/next-header value; IPv6 extension chains are not decoded.
    ip_protocol: int = 0


def physical_interface(name):
    return bool(re.fullmatch(r"en\d+|pdp_ip\d*", name))


def packet_size(packet, raw=False):
    """Read IP lengths, including UDP/QUIC, from pcapd.watch() output.

    pcapd.watch() adds a synthetic 14-byte Ethernet header to raw IP and
    pdp_ip frames. Use the IP version, not that header's synthetic EtherType.
    Retransmissions count again, as they consume network capacity too.
    Prefer raw=True with device_packet_struct.parse() output: watch() rejects
    unknown metadata families and can double-wrap Ethernet frames.
    """
    raw_name = packet["interface_name"]
    # pcapd sends the base name and unit separately (for example "en", 0).
    name = (raw_name + str(int(packet["unit"]))
            if raw_name in {"en", "pdp_ip"} and "unit" in packet else raw_name)
    if not physical_interface(name):
        return None
    pre = int(packet["frame_pre_length"])
    offset = 14 if pre == 0 or raw_name == "pdp_ip" else pre
    ethernet = False
    if raw:
        # pcapd can report zero frame_pre_length for an actual Ethernet frame
        # on en. watch() blindly prepends another Ethernet header in that case.
        # Decode the original bytes before that lossy normalization instead.
        ethernet = bool(re.fullmatch(r"en\d*", raw_name)) and int(packet.get("interface_type", -1)) == 6
        offset = (14 if ethernet else pre)
    frame = bytes(packet["data"])
    if offset == 14 and len(frame) >= 14:
        ether_type = int.from_bytes(frame[12:14], "big")
        while ether_type in {0x8100, 0x88A8}:
            if len(frame) < offset + 4:
                raise ValueError("Truncated VLAN header")
            ether_type = int.from_bytes(frame[offset + 2:offset + 4], "big")
            offset += 4
        if ether_type in {0x0806, 0x888E, 0x88CC}:
            return None  # ARP, EAPOL, LLDP; none carries an IP packet.
        if ethernet and ether_type not in {0x0800, 0x86DD}:
            return None  # Actual Ethernet type identifies a non-IP frame.
    data = frame[offset:]
    if not data:
        raise ValueError("Missing IP header on physical interface")
    version = data[0] >> 4
    if not ethernet and version not in {4, 6} and int(packet.get("protocol_family", -1)) == 0:
        return None  # Explicit non-IP link-layer frame, for example ARP.
    if version == 4:
        if len(data) < 20:
            raise ValueError("Truncated IPv4 header")
        header_size = (data[0] & 15) * 4
        length = int.from_bytes(data[2:4], "big")
        if header_size < 20 or length < header_size or len(data) < header_size:
            raise ValueError("Invalid IPv4 length")
        source = str(ipaddress.IPv4Address(data[12:16]))
        destination = str(ipaddress.IPv4Address(data[16:20]))
        protocol = data[9]
        # Later fragments have no TCP header. They still count as IP traffic.
        fragmented = bool(int.from_bytes(data[6:8], "big") & 0x1FFF)
    elif version == 6:
        if len(data) < 40:
            raise ValueError("Truncated IPv6 header")
        payload_size = int.from_bytes(data[4:6], "big")
        if payload_size == 0:
            raise ValueError("IPv6 jumbogram needs separate length validation")
        length = 40 + payload_size
        header_size = 40
        source = str(ipaddress.IPv6Address(data[8:24]))
        destination = str(ipaddress.IPv6Address(data[24:40]))
        protocol = data[6]
        fragmented = False
    else:
        raise ValueError("Unsupported physical IP packet")
    source_port = destination_port = None
    payload = 0
    if protocol == 6 and not fragmented and len(data) >= header_size + 20:
        tcp = data[header_size:]
        tcp_header = (tcp[12] >> 4) * 4
        if tcp_header < 20 or header_size + tcp_header > length:
            raise ValueError("Invalid TCP header")
        source_port = int.from_bytes(tcp[:2], "big")
        destination_port = int.from_bytes(tcp[2:4], "big")
        payload = length - header_size - tcp_header
    return PacketSize(name, length, source, destination, source_port,
                      destination_port, payload, protocol)


class PacketBudget:
    """Conservatively count both directions on physical interfaces."""
    def __init__(self, limit_bytes):
        if limit_bytes <= 0:
            raise ValueError("Budget must be positive")
        self.limit_bytes = limit_bytes
        self.ip_bytes = 0
        self.packets = 0
        self.failed = False

    def add(self, packet, raw=False):
        try:
            size = packet_size(packet, raw=raw)
        except (KeyError, TypeError, ValueError):
            self.failed = True
            raise
        if size is not None:
            self.ip_bytes += size.ip_bytes
            self.packets += 1
        return size

    @property
    def stop_required(self):
        return self.failed or self.ip_bytes >= self.limit_bytes
