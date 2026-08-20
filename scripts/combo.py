import socket, json, sys, time
s=socket.socket(socket.AF_UNIX); s.connect("/run/macos-qmp.sock"); f=s.makefile("rwb")
f.readline(); f.write(b'{"execute":"qmp_capabilities"}\n'); f.flush(); f.readline()
def send(keys):
    f.write((json.dumps({"execute":"send-key","arguments":{"keys":[{"type":"qcode","data":k} for k in keys]}})+"\n").encode()); f.flush()
    while True:
        l=f.readline()
        if not l: return
        d=json.loads(l)
        if "return" in d or "error" in d: return d
for grp in sys.argv[1:]:
    print(send(grp.split("+")))
    time.sleep(0.5)
