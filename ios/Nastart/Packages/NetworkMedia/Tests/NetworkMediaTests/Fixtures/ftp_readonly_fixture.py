"""Owned loopback FTP peer; no NAS, user credentials or external network."""
import pathlib,socket,ssl,threading,time,json,sys
root=pathlib.Path(sys.argv[1]);mode=sys.argv[2];behavior=sys.argv[3]
stop=threading.Event();lock=threading.RLock();connections=[];listeners=[];workers=[]
state={'accepted':0,'commands':[],'retrieved':[],'plaintextCredentials':0,'mlsd':0,'mlst':0,'closed':0,'dataEOF':False,'unexpected':[],'controlTLS':[],'dataTLS':[]}
nfo=b'<movie><title>owned fixture</title></movie>';picture=b'owned-image'*173
if behavior=='maximum-nfo':nfo=nfo+b' '*(65536-len(nfo))
files={'Movie.nfo':nfo,'poster.jpg':picture,'Movie.mkv':b'never retrieve video','%2F.NFO':nfo,'é.nfo':nfo,'e\u0301.nfo':nfo}

def publish():
 with lock:
  tmp=root/'state.tmp';tmp.write_text(json.dumps(state));tmp.replace(root/'state.json')

def ctx(other=False):
 c=ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER);c.minimum_version=ssl.TLSVersion.TLSv1_2
 c.load_cert_chain(root/('other.pem'if other else'valid.pem'),root/('other.key'if other else'valid.key'));return c
context=ctx()if mode!='plain'else None
othercontext=ctx(True)if mode!='plain'and behavior=='data-other'else context

def facts(name,post=False):
 size=len(files[name]);modify='20261027000000';unique='inode-'+str(list(files).index(name))
 if behavior=='changed-list'and state['mlsd']>1:modify='20261027000001'
 if behavior=='missing-version':modify=None
 if behavior=='oversized'and name.endswith('.nfo'):size=65537
 if behavior=='changed-after'and post:unique+='changed'
 return 'type=file;size='+str(size)+';'+('modify='+modify+';'if modify else'')+'unique='+unique+';'

def serve(conn):
 passive=None;secure=False
 try:
  conn.settimeout(3);connections.append(conn)
  if mode=='implicit':conn=context.wrap_socket(conn,server_side=True);connections.append(conn);secure=True;state['controlTLS'].append(conn.version())
  conn.sendall(b'220 Owned fixture\r\n')
  if behavior=='silent':
   while not stop.is_set():
    data=conn.recv(1)
    if not data:return
   return
  stream=conn.makefile('rb')
  while not stop.is_set():
   raw=stream.readline(16385)
   if not raw:return
   text=raw.decode('utf-8').rstrip('\r\n');verb,_,arg=text.partition(' ')
   with lock:
    state['commands'].append(verb if verb in ['USER','PASS']else text)
    if verb in ['USER','PASS']and not secure:state['plaintextCredentials']+=1
    publish()
   if verb=='AUTH'and arg=='TLS'and mode=='explicit':

    if behavior=='reject-tls':conn.sendall(b'500 TLS unavailable\r\n');continue
    conn.sendall(b'234 Upgrade\r\n');conn=context.wrap_socket(conn,server_side=True);connections.append(conn);stream=conn.makefile('rb');secure=True;state['controlTLS'].append(conn.version())
   elif verb=='USER':conn.sendall(b'331 Password required\r\n')
   elif verb=='PASS':conn.sendall(b'530 Rejected\r\n'if behavior=='auth-reject'else b'230 Logged in\r\n')
   elif verb in ['PBSZ','PROT','TYPE','OPTS']:conn.sendall(b'200 Accepted\r\n')
   elif verb=='FEAT':
    conn.sendall(b'211-Features\r\n TVFS\r\n MLST type*;size*;modify*;unique*;\r\n'+(b''if behavior=='no-utf8'else b' UTF8\r\n')+b'211 End\r\n')
   elif verb in ['EPSV','PASV']:
    if verb=='EPSV'and behavior=='pasv':conn.sendall(b'502 Use PASV\r\n');continue
    passive=socket.socket();passive.bind(('127.0.0.1',0));passive.listen(1);passive.settimeout(3);listeners.append(passive);port=passive.getsockname()[1]
    reply=('229 Entering (|||'+str(port)+'|)\r\n')if verb=='EPSV'else('227 Entering (203,0,113,9,'+str(port//256)+','+str(port%256)+')\r\n')
    conn.sendall(reply.encode())
   elif verb=='MLST':
    name=arg.rsplit('/',1)[-1];state['mlst']+=1
    if name not in files:conn.sendall(b'550 Unknown\r\n');continue
    path='/outside/'+name if behavior=='wrong-path'else arg
    post=state['mlst']%2==0
    conn.sendall(('250-Listing\r\n '+facts(name,post)+' '+path+'\r\n250 End\r\n').encode())
   elif verb in ['MLSD','RETR']:
    if verb=='MLSD':
     state['mlsd']+=1
     if arg not in ['/video/media','/video/media/Child']:
      conn.sendall(b'550 Out of scope\r\n');continue
     payload=''.join(facts(name)+' '+name+'\r\n'for name in files).encode()
     if behavior=='bad-listing':payload+=b'type=OS.unix=slink; Escape\r\n'
    else:
     name=arg.rsplit('/',1)[-1];state['retrieved'].append(arg)
     if name.endswith('.mkv'):state['unexpected'].append('video RETR');conn.sendall(b'550 Not allowed\r\n');continue
     payload=files[name]
     if behavior=='short':payload=payload[:2]
    if passive is None:conn.sendall(b'425 No data\r\n');continue
    conn.sendall(b'150 Data\r\n');data,_=passive.accept();connections.append(data);data.settimeout(3)
    if secure:data=othercontext.wrap_socket(data,server_side=True);connections.append(data);state['dataTLS'].append(data.version())
    if behavior=='data-silent':
     while not stop.is_set():
      if not data.recv(1):state['dataEOF']=True;break
    else:data.sendall(payload)
    data.close();passive.close();passive=None
    conn.sendall(b'426 Failed\r\n'if behavior=='completion-fail'else b'226 Complete\r\n')
   elif verb=='QUIT':conn.sendall(b'221 Goodbye\r\n');return
   else:state['unexpected'].append(verb);conn.sendall(b'500 Unsupported\r\n')
 except (OSError,ValueError,ssl.SSLError):pass
 finally:
  try:conn.close()
  except OSError:pass
  if passive:
   try:passive.close()
   except OSError:pass
  with lock:state['closed']+=1;publish()

listener=socket.socket();listener.bind(('127.0.0.1',0));listener.listen(16);listener.settimeout(.05);publish();(root/'port').write_text(str(listener.getsockname()[1]))
try:
 while not(root/'stop').exists():
  try:
   conn,_=listener.accept();state['accepted']+=1;t=threading.Thread(target=serve,args=(conn,),daemon=True);workers.append(t);t.start()
  except socket.timeout:continue
finally:
 stop.set();listener.close()
 for c in connections+listeners:
  try:c.shutdown(socket.SHUT_RDWR)
  except OSError:pass
  try:c.close()
  except OSError:pass
 for t in workers:t.join(2)
 state['allWorkersStopped']=not any(t.is_alive()for t in workers);publish()
