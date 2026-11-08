# A local SMB server for tests, loopback only. Needs impacket, so the tests skip
# unless NASTART_SMB_FIXTURE_PYTHON names a Python that has it.
# argv: state directory, share directory. Writes "port" when ready; stops when "stop" appears.
import logging, os, socket, sys, threading, time
from pathlib import Path
from impacket import ntlm, smb3structs, smbserver

state, share = Path(sys.argv[1]), sys.argv[2]
logging.basicConfig(level=logging.CRITICAL)
probe = socket.socket()
probe.bind(("127.0.0.1", 0))
port = probe.getsockname()[1]
probe.close()
server = smbserver.SimpleSMBServer(listenAddress="127.0.0.1", listenPort=port)
server.setSMB2Support(True)
server.addShare("TEST", share, "")
server.addCredential("fixture", 0, ntlm.compute_lmhash("local-only").hex(), ntlm.compute_nthash("local-only").hex())

# impacket's refusal has no error body. Send the one real servers use.
inner = server._SimpleSMBServer__server
original = smbserver.SMB2Commands.smb2SessionSetup
def session_setup(conn, srv, packet):
    result = original(conn, srv, packet)
    if result[2] == 0xc000006d:
        error = smb3structs.SMB2Error()
        error["ByteCount"] = 0
        error["Buffer"] = b"\x00"
        return [error], None, result[2]
    return result
inner.hookSmb2Command(smb3structs.SMB2_SESSION_SETUP, session_setup)
threading.Thread(target=server.start, daemon=True).start()
time.sleep(0.3)
(state / "port").write_text(str(port))
while not (state / "stop").exists():
    time.sleep(0.05)
os._exit(0)
