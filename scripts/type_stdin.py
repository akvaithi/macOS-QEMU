import socket, json, sys, time
SOCK="/run/macos-qmp.sock"
PLAIN={' ':'spc','-':'minus','.':'dot','/':'slash',',':'comma',';':'semicolon',
       '=':'equal','[':'bracket_left',']':'bracket_right','\\':'backslash',
       "'":'apostrophe','`':'grave_accent','\n':'ret','\t':'tab'}
SHIFT={'|':'backslash','_':'minus','~':'grave_accent',':':'semicolon','"':'apostrophe',
       '<':'comma','>':'dot','?':'slash','+':'equal','(':'9',')':'0','!':'1','@':'2',
       '#':'3','$':'4','%':'5','^':'6','&':'7','*':'8','{':'bracket_left','}':'bracket_right'}
s=socket.socket(socket.AF_UNIX); s.connect(SOCK); f=s.makefile("rwb")
f.readline(); f.write(b'{"execute":"qmp_capabilities"}\n'); f.flush(); f.readline()
def send(keys):
    f.write((json.dumps({"execute":"send-key","arguments":{"keys":keys}})+"\n").encode()); f.flush()
    while True:
        l=f.readline()
        if not l: return
        d=json.loads(l)
        if "return" in d or "error" in d: return d
def q(n): return {"type":"qcode","data":n}
text=sys.stdin.read().rstrip("\n")
for ch in text:
    if ch.isalpha(): k=[q("shift"), q(ch.lower())] if ch.isupper() else [q(ch)]
    elif ch.isdigit(): k=[q(ch)]
    elif ch in PLAIN: k=[q(PLAIN[ch])]
    elif ch in SHIFT: k=[q("shift"), q(SHIFT[ch])]
    else: continue
    send(k); time.sleep(0.05)
print("ok", len(text), "chars")
