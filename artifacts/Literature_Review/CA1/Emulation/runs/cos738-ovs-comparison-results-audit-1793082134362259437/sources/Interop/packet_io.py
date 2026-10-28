"""Only packet I/O inside a Mininet host; all topology/control operations are Julia-led."""
import json
import os
from pathlib import Path
import socket
import struct
import sys
import time

assert 'cos738-ovs-' in Path('/proc/self/cgroup').read_text()
uidmap=list(map(int,Path('/proc/self/uid_map').read_text().split()))
assert len(uidmap)==3 and uidmap[0]==0 and uidmap[1]!=0 and uidmap[2]==1
mode,interface,output=sys.argv[1:]
token=b'COS738-MININET-PYTHONCALL-VLAN'
with socket.socket(socket.AF_PACKET,socket.SOCK_RAW,socket.htons(3)) as sock:
    sock.setsockopt(263,8,1)
    sock.bind((interface,0))
    if mode=='send':
        frame=b'\xff'*6+bytes.fromhex('02000000000188b5')+token.ljust(46,b'.')
        assert sock.send(frame)==len(frame)
        print('SENT')
    elif mode=='receive':
        sock.settimeout(2)
        Path(output+'.ready').write_text('ready\n')
        while True:
            data,ancillary,_,_=sock.recvmsg(65535,128)
            if token not in data:
                continue
            tag=None
            if data[12:14]==b'\x81\x00':
                tag=struct.unpack('!H',data[14:16])[0]&0xfff
            for level,kind,value in ancillary:
                if level==263 and kind==8:
                    aux=struct.unpack_from('=IIIHHHH',value)
                    if aux[0]&(1<<4):tag=aux[5]&0xfff
            Path(output).write_text(json.dumps({'hex':data.hex(),'vlan_id':tag,'interface':interface,
                'pid':os.getpid(),'network_namespace':str(Path('/proc/self/ns/net').readlink()),
                'received_monotonic_ns':time.monotonic_ns()})+'\n')
            assert tag==101
            break
    else:
        raise ValueError(mode)
