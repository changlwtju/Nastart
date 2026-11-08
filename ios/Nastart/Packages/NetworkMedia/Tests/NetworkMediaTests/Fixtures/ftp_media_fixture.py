#!/usr/bin/env python3
"""Local-only FTP server for library and video range tests. Serves <dir>/root."""
import json, os, socket, sys, threading, time

base = sys.argv[1]
bind = sys.argv[2] if len(sys.argv) > 2 else "127.0.0.1"
root = os.path.join(base, "root")
log = []
lock = threading.Lock()


def note(text):
    with lock:
        log.append(text)
        with open(os.path.join(base, "commands.tmp"), "w") as f:
            json.dump(log, f)
        os.replace(os.path.join(base, "commands.tmp"), os.path.join(base, "commands.json"))


def synology():
    """Mirrors what a real DSM FTP service advertises and refuses."""
    return os.path.exists(os.path.join(base, "synology"))


def facts(path, name):
    st = os.stat(path)
    kind = "dir" if os.path.isdir(path) else "file"
    size = "" if kind == "dir" else f"size={st.st_size};"
    modified = time.strftime("%Y%m%d%H%M%S", time.gmtime(st.st_mtime))
    extra = "UNIX.mode=0755;UNIX.owner=fixture;UNIX.group=users;" if synology() else ""
    return f"modify={modified};type={kind};unique={st.st_ino:x};{size}{extra} {name}"


def handle(conn):
    conn.sendall(b"220 ready\r\n")
    reader = conn.makefile("rb")
    listener = None
    rest = 0
    utf8 = False
    cwd = root
    while True:
        line = reader.readline()
        if not line:
            return
        text = line.decode("utf8").rstrip("\r\n")
        verb, _, arg = text.partition(" ")
        verb = verb.upper()
        note(verb if verb != "PASS" else "PASS")
        path = os.path.join(root, arg.lstrip("/"))
        if verb == "FEAT" and synology():
            conn.sendall(b"211- Extensions supported:\r\n UTF8\r\n TVFS\r\n REST STREAM\r\n"
                         b" MLST modify*;type*;unique*;size*;UNIX.mode*;UNIX.owner*;UNIX.group*;\r\n"
                         b" MLSD modify*;type*;unique*;size*;UNIX.mode*;UNIX.owner*;UNIX.group*;\r\n211 End.\r\n")
        elif verb == "OPTS" and synology():
            if arg.upper() == "UTF8 ON":
                utf8 = True
                conn.sendall(b"200 OK, UTF-8 enabled\r\n")
            else:
                conn.sendall(b"501 OPTS command is not defined for MLST.\r\n")
        elif verb == "FEAT":
            conn.sendall(b"211-Features\r\n UTF8\r\n TVFS\r\n REST STREAM\r\n MLST type*;size*;modify*;unique*;\r\n211 End\r\n")
        elif verb == "USER":
            conn.sendall(b"331 password\r\n")
        elif verb == "PASS":
            conn.sendall(b"230 ok\r\n" if arg == "local-only" else b"530 denied\r\n")
        elif verb in ("TYPE", "OPTS"):
            conn.sendall(b"200 ok\r\n")
        elif verb == "EPSV":
            listener = socket.socket()
            listener.bind((bind, 0))
            listener.listen(1)
            conn.sendall(f"229 Entering (|||{listener.getsockname()[1]}|)\r\n".encode())
        elif verb == "MLST" and synology() and "[" in arg:
            conn.sendall(f"250- Start of list for {arg}\r\n550 {arg}: No such file or directory.\r\n250 End of list\r\n".encode())
        elif verb == "MLST":
            body = facts(path, os.path.basename(path)) if os.path.exists(path) else None
            if body is None:
                conn.sendall(b"550 missing\r\n")
            else:
                conn.sendall(f"250-Listing\r\n {body.rsplit(' ', 1)[0]} {arg}\r\n250 End\r\n".encode())
        elif verb == "CWD":
            cwd = path
            conn.sendall(b"250 ok\r\n")
        elif verb == "REST":
            rest = int(arg)
            conn.sendall(b"350 ok\r\n")
        elif verb in ("MLSD", "RETR"):
            conn.sendall(b"150 opening\r\n")
            data, _ = listener.accept()
            listener.close()
            try:
                if verb == "MLSD":
                    if not arg:
                        path = cwd
                    glob_refused = synology() and "[" in arg
                    rows = [] if glob_refused else [facts(os.path.join(path, n), n) for n in sorted(os.listdir(path))]
                    if not glob_refused:
                        rows.insert(0, "type=OS.unix=symlink;modify=20200101000000; link-to-elsewhere")
                    data.sendall("".join(r + "\r\n" for r in rows).encode("utf8" if utf8 or not synology() else "gbk"))
                else:
                    with open(path, "rb") as f:
                        f.seek(rest)
                        rest = 0
                        while chunk := f.read(65536):
                            data.sendall(chunk)
                data.close()
                conn.sendall(b"226 done\r\n")
            except OSError:
                data.close()
                conn.sendall(b"426 aborted\r\n")
        elif verb == "QUIT":
            conn.sendall(b"221 bye\r\n")
            return
        else:
            conn.sendall(b"502 no\r\n")


def worker(conn):
    try:
        handle(conn)
    except OSError:
        pass
    finally:
        conn.close()


server = socket.socket()
server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
server.bind((bind, 0))
server.listen(8)
server.settimeout(0.1)
with open(os.path.join(base, "port.tmp"), "w") as f:
    f.write(str(server.getsockname()[1]))
os.replace(os.path.join(base, "port.tmp"), os.path.join(base, "port"))
while not os.path.exists(os.path.join(base, "stop")):
    try:
        conn, _ = server.accept()
    except socket.timeout:
        continue
    threading.Thread(target=worker, args=(conn,), daemon=True).start()
