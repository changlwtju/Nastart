import ipaddress
import unittest

from device_packet_budget import PacketBudget, packet_size


def ipv4(payload=100, interface="en0", protocol=6, pre=14):
    ip = bytearray(20)
    ip[0] = 0x45
    ip[9] = protocol
    ip[12:16] = ipaddress.ip_address("192.0.2.1").packed
    ip[16:20] = ipaddress.ip_address("192.0.2.2").packed
    transport = bytearray(20 if protocol == 6 else 8)
    transport[:4] = (8080).to_bytes(2, "big") + (50000).to_bytes(2, "big")
    if protocol == 6:
        transport[12] = 0x50
    length = len(ip) + len(transport) + payload
    ip[2:4] = length.to_bytes(2, "big")
    return {"interface_name": interface, "frame_pre_length": pre,
            "data": bytes(14 if pre == 0 or interface == "pdp_ip" else pre)
                    + ip + transport + bytes(payload)}


class PacketBudgetTests(unittest.TestCase):
    def test_ipv4_body_and_ip_overhead_are_separate(self):
        size = packet_size(ipv4())
        self.assertEqual(size.ip_bytes, 140)
        self.assertEqual(size.tcp_payload_bytes, 100)
        self.assertEqual(size.source_port, 8080)

    def test_raw_cellular_frame_has_synthetic_header(self):
        self.assertEqual(packet_size(ipv4(interface="pdp_ip0", pre=0)).ip_bytes, 140)
        self.assertEqual(packet_size(ipv4(interface="pdp_ip", pre=4)).ip_bytes, 140)

    def test_pcapd_base_name_and_unit_are_combined(self):
        packet = ipv4(interface="en")
        packet["unit"] = 0
        self.assertEqual(packet_size(packet).interface, "en0")
        packet = ipv4(interface="pdp_ip", pre=4)
        packet["unit"] = 2
        self.assertEqual(packet_size(packet).interface, "pdp_ip2")

    def test_udp_counts_even_without_process_or_tcp(self):
        budget = PacketBudget(100)
        budget.add(ipv4(protocol=17))
        self.assertEqual(budget.ip_bytes, 128)
        self.assertTrue(budget.stop_required)

    def test_cellular_udp_is_counted_without_claiming_tcp_media(self):
        packet = ipv4(interface="pdp_ip", protocol=17, pre=4)
        packet["unit"] = 1
        size = packet_size(packet)
        self.assertEqual(size.interface, "pdp_ip1")
        self.assertEqual(size.ip_protocol, 17)
        self.assertEqual(size.ip_bytes, 128)
        self.assertEqual(size.tcp_payload_bytes, 0)
        self.assertIsNone(size.source_port)

    def test_ipv6_with_synthetic_ipv4_ether_type(self):
        ip = bytearray(40)
        ip[0] = 0x60
        ip[4:6] = (108).to_bytes(2, "big")
        ip[6] = 17
        ip[8:24] = ipaddress.ip_address("2001:db8::1").packed
        ip[24:40] = ipaddress.ip_address("2001:db8::2").packed
        size = packet_size({"interface_name": "pdp_ip0", "frame_pre_length": 0,
                            "data": b"\x00" * 12 + b"\x08\x00" + ip + bytes(108)})
        self.assertEqual(size.ip_bytes, 148)
        self.assertIsNone(size.source_port)

    def test_loopback_and_tunnel_are_not_counted_again(self):
        budget = PacketBudget(1000)
        for interface in ["lo0", "utun6"]:
            self.assertIsNone(budget.add(ipv4(interface=interface)))
        self.assertEqual(budget.ip_bytes, 0)

    def test_non_ip_link_layer_frame_does_not_masquerade_as_ip(self):
        packet = {"interface_name": "en", "unit": 0, "protocol_family": 0,
                  "frame_pre_length": 14, "data": bytes(42)}
        self.assertIsNone(packet_size(packet))

    def test_nonstandard_metadata_family_does_not_drop_valid_ip(self):
        packet = ipv4()
        packet["protocol_family"] = 0x766C616E
        self.assertEqual(packet_size(packet).ip_bytes, 140)

    def test_vlan_tag_is_not_mistaken_for_ip_header(self):
        packet = ipv4()
        packet["protocol_family"] = 0x766C616E
        packet["data"] = bytes(12) + b"\x81\x00\x00\x01\x08\x00" + packet["data"][14:]
        self.assertEqual(packet_size(packet).ip_bytes, 140)

    def test_arp_skipped_even_with_unusual_family_metadata(self):
        packet = {"interface_name": "en", "unit": 0, "protocol_family": 2,
                  "frame_pre_length": 14,
                  "data": bytes(12) + b"\x08\x06" + bytes(28)}
        self.assertIsNone(packet_size(packet))

    def test_truncated_vlan_fails_closed(self):
        packet = {"interface_name": "en0", "frame_pre_length": 14,
                  "data": bytes(12) + b"\x81\x00" + bytes(2)}
        with self.assertRaises(ValueError):
            packet_size(packet)

    def test_raw_ethernet_arp_with_zero_pre_length(self):
        packet = {"interface_name": "en", "unit": 0, "interface_type": 6,
                  "protocol_family": 2, "frame_pre_length": 0,
                  "data": bytes(12) + b"\x08\x06" + bytes(28)}
        self.assertIsNone(packet_size(packet, raw=True))

    def test_raw_ethernet_ip_with_zero_pre_length(self):
        packet = ipv4(interface="en")
        packet.update(unit=0, interface_type=6, frame_pre_length=0)
        packet["data"] = bytes(12) + b"\x08\x00" + packet["data"][14:]
        self.assertEqual(packet_size(packet, raw=True).tcp_payload_bytes, 100)

    def test_raw_cellular_does_not_require_synthetic_ethernet(self):
        packet = ipv4(interface="pdp_ip", pre=4)
        packet["data"] = bytes(4) + packet["data"][14:]
        self.assertEqual(packet_size(packet, raw=True).ip_bytes, 140)

    def test_raw_vlan_non_ip_is_not_an_invalid_ip_packet(self):
        packet = {"interface_name": "en", "unit": 0, "interface_type": 6,
                  "protocol_family": 0x766C616E, "frame_pre_length": 14,
                  "data": bytes(12) + b"\x81\x00\x00\x01\x83\x00" + bytes(42)}
        self.assertIsNone(packet_size(packet, raw=True))

    def test_retransmission_and_ack_count_toward_budget(self):
        budget = PacketBudget(300)
        budget.add(ipv4())
        budget.add(ipv4())
        self.assertFalse(budget.stop_required)
        budget.add(ipv4(payload=0))
        self.assertTrue(budget.stop_required)

    def test_truncated_physical_header_fails_closed(self):
        budget = PacketBudget(1000)
        with self.assertRaises(ValueError):
            budget.add({"interface_name": "en0", "frame_pre_length": 14,
                        "data": bytes(15)})
        self.assertTrue(budget.stop_required)

    def test_declared_ip_length_survives_payload_snap_length(self):
        packet = ipv4(payload=1000)
        packet["data"] = packet["data"][:54]
        self.assertEqual(packet_size(packet).ip_bytes, 1040)


if __name__ == "__main__":
    unittest.main()
