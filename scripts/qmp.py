import socket, json, sys, time
SOCK = "/run/macos-qmp.sock"
def conn():
    s = socket.socket(socket.AF_UNIX); s.connect(SOCK); f = s.makefile("rwb")
    f.readline()                                  # greeting
    f.write(b'{"execute":"qmp_capabilities"}\n'); f.flush(); f.readline()
    return s, f
def cmd(f, c, **args):
    m = {"execute": c}
    if args: m["arguments"] = args
    f.write((json.dumps(m)+"\n").encode()); f.flush()
    while True:
        line = f.readline()
        if not line: return None
        d = json.loads(line)
        if "return" in d or "error" in d: return d
s, f = conn()
action = sys.argv[1]
if action == "shot":
    print(cmd(f, "screendump", filename=sys.argv[2]))
elif action == "keys":
    for k in sys.argv[2:]:
        print(cmd(f, "send-key", keys=[{"type":"qcode","data":k}]))
        time.sleep(0.6)
elif action == "status":
    print(cmd(f, "query-status"))
