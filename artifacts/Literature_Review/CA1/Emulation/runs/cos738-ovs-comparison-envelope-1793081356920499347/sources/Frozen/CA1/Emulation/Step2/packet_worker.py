"""Packet I/O only in a private Mininet namespace. No topology or control policy."""
import json
import os
from pathlib import Path
import selectors
import socket
import struct
import sys
import time

assert 'cos738-ovs-' in Path('/proc/self/cgroup').read_text()
assert str(Path('/proc/self/ns/net').readlink()) != os.environ['HOST_NETNS']
mapping=json.loads(sys.argv[1])
selector=selectors.DefaultSelector()
selector.register(sys.stdin,selectors.EVENT_READ,'command')
sockets={}
events=[]

def collect(sock,neighbor):
    while True:
        try:data,ancillary,_,address=sock.recvmsg(65535,128)
        except BlockingIOError:return
        if address[2]==socket.PACKET_OUTGOING:continue
        if len(data)<14:continue
        raw_received_hex=data.hex()
        tci=None
        for level,kind,value in ancillary:
            if level==263 and kind==8:
                aux=struct.unpack_from('=IIIHHHH',value)
                if aux[0]&(1<<4):tci=aux[5]
        if tci is not None and data[12:14]!=b'\x81\x00':
            data=data[:12]+struct.pack('!HH',0x8100,tci)+data[12:]
        vlan=None;offset=14;ethertype=struct.unpack('!H',data[12:14])[0]
        if ethertype==0x8100 and len(data)>=18:
            vlan=struct.unpack('!H',data[14:16])[0]&0xfff
            ethertype=struct.unpack('!H',data[16:18])[0];offset=18
        if ethertype!=0x0800 or len(data)<offset+20:continue
        ip=data[offset:];ihl=(ip[0]&15)*4
        if ip[0]>>4!=4 or ihl<20 or len(ip)<ihl or ip[9]!=253:continue
        payload=ip[ihl:struct.unpack('!H',ip[2:4])[0]]
        if not payload.startswith(b'COS738S2:'):continue
        ident=int(payload.split(b':',2)[1])
        checksum=sum(struct.unpack('!'+str(ihl//2)+'H',ip[:ihl]))
        while checksum>>16:checksum=(checksum&65535)+(checksum>>16)
        events.append({'id':ident,'neighbor':neighbor,'interface':address[0],'hex':data.hex(),
            'raw_received_hex':raw_received_hex,'aux_vlan_tci':tci,
            'vlan':vlan,'source_ip':'.'.join(map(str,ip[12:16])),
            'destination_ip':'.'.join(map(str,ip[16:20])),'ipv4_checksum_valid':checksum==65535,
            'received_ns':time.monotonic_ns()})
        assert len(events)<=256,'capture ceiling exceeded'

def reply(value):
    print(json.dumps(value,separators=(',',':')),flush=True)

try:
    for neighbor,interface in mapping.items():
        sock=socket.socket(socket.AF_PACKET,socket.SOCK_RAW,socket.htons(3))
        sock.setsockopt(263,8,1)
        sock.bind((interface,0));sock.setblocking(False)
        sockets[neighbor]=sock;selector.register(sock,selectors.EVENT_READ,neighbor)
    reply({'status':'READY','pid':os.getpid(),'netns':str(Path('/proc/self/ns/net').readlink()),'interfaces':mapping})
    running=True
    while running:
        for key,_ in selector.select():
            if key.data!='command':
                collect(key.fileobj,key.data);continue
            line=sys.stdin.readline()
            if not line:running=False;break
            command=json.loads(line)
            for neighbor,sock in sockets.items():collect(sock,neighbor)
            op=command['op']
            if op=='send':
                frame=bytes.fromhex(command['hex']);assert 14<=len(frame)<=4096
                before=time.monotonic_ns()
                count=sockets[command['neighbor']].send(frame)
                after=time.monotonic_ns()
                assert count==len(frame)
                reply({'status':'SENT','bytes':count,'before_ns':before,'after_ns':after})
            elif op=='drain':
                reply({'events':events});events=[]
            elif op=='stop':reply({'status':'STOPPED'});running=False;break
            else:raise ValueError(op)
finally:
    for sock in sockets.values():sock.close()
    selector.close()
