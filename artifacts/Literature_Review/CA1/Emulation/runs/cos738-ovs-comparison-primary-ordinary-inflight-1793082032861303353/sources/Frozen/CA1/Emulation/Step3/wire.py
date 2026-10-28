"""Transparent two-port delay wire. Packet identity affects logging only, never forwarding."""
import heapq
import json
import os
from pathlib import Path
import selectors
import socket
import struct
import sys
import time


def delay_ns(milliseconds):
    if type(milliseconds) is not int or not 0 <= milliseconds <= 1000:
        raise ValueError('delay must be an integer in [0,1000] ms')
    return milliseconds * 1_000_000


def enqueue(queue, serial, side, frame, received_ns, delay):
    heapq.heappush(queue, (received_ns + delay, serial, side, frame, received_ns))


def identity(data):
    if len(data) < 34:
        return None
    ethertype = int.from_bytes(data[12:14], 'big')
    offset = 14
    if ethertype == 0x8100 and len(data) >= 38:
        ethertype = int.from_bytes(data[16:18], 'big')
        offset = 18
    if ethertype != 0x0800:
        return None
    ip = data[offset:]
    ihl = (ip[0] & 15) * 4
    if ip[0] >> 4 != 4 or ihl < 20 or len(ip) < ihl or ip[9] != 253:
        return None
    payload = ip[ihl:int.from_bytes(ip[2:4], 'big')]
    if not payload.startswith(b'COS738S2:'):
        return None
    try:
        return int(payload.split(b':', 2)[1])
    except ValueError:
        return None


def self_check():
    q = []
    enqueue(q, 1, 0, b'first', 10, delay_ns(250))
    enqueue(q, 2, 1, b'second', 11, delay_ns(250))
    assert q[0][0] > 250_000_009
    assert heapq.heappop(q) == (250_000_010, 1, 0, b'first', 10)
    assert heapq.heappop(q) == (250_000_011, 2, 1, b'second', 11)
    for value in [-1, 1001, True, 0.25]:
        try:
            delay_ns(value)
        except ValueError:
            continue
        raise AssertionError('invalid delay accepted')
    assert identity(b'bad') is None
    print('WIRE PURE CHECK PASS', flush=True)


def main():
    assert 'cos738-ovs-' in Path('/proc/self/cgroup').read_text()
    assert str(Path('/proc/self/ns/net').readlink()) != os.environ['HOST_NETNS']
    config = json.loads(sys.argv[1])
    names = config['interfaces']
    assert len(names) == 2 and names[0] != names[1]
    delay = delay_ns(config['delay_ms'])
    selector = selectors.DefaultSelector()
    selector.register(sys.stdin, selectors.EVENT_READ, 'command')
    sockets = []
    queue = []
    events = []
    serial = 0

    def reply(value):
        print(json.dumps(value, separators=(',', ':')), flush=True)

    def log(value):
        events.append(value)
        assert len(events) <= 4096, 'wire event ceiling exceeded'

    try:
        for side, name in enumerate(names):
            sock = socket.socket(socket.AF_PACKET, socket.SOCK_RAW, socket.htons(3))
            sock.setsockopt(263, 8, 1)
            sock.bind((name, 0))
            sock.setblocking(False)
            sockets.append(sock)
            selector.register(sock, selectors.EVENT_READ, side)
        reply(dict(status='READY', pid=os.getpid(), netns=str(Path('/proc/self/ns/net').readlink()),
                   interfaces=names, delay_ns=delay))
        running = True
        while running:
            now = time.monotonic_ns()
            while queue and queue[0][0] <= now:
                due, _, side, data, received = heapq.heappop(queue)
                before = time.monotonic_ns()
                count = sockets[1-side].send(data)
                after = time.monotonic_ns()
                assert count == len(data), 'incomplete wire transmission'
                ident = identity(data)
                if ident is not None:
                    log(dict(kind='release', id=ident, input_side=side, output_side=1-side,
                             received_ns=received, due_ns=due, before_ns=before, after_ns=after, hex=data.hex()))
                now = time.monotonic_ns()
            timeout = None if not queue else max(0, (queue[0][0]-time.monotonic_ns())/1e9)
            for key, _ in selector.select(timeout):
                if key.data == 'command':
                    line = sys.stdin.readline()
                    if not line:
                        running = False
                        break
                    command = json.loads(line)
                    if command['op'] == 'drain':
                        reply(dict(events=events, cutoff_ns=time.monotonic_ns(),
                                   pending_ids=[i for entry in queue if (i := identity(entry[3])) is not None]))
                        events = []
                    elif command['op'] == 'stop':
                        reply(dict(status='STOPPED', queued_at_stop=len(queue)))
                        running = False
                        break
                    else:
                        raise ValueError(command['op'])
                    continue
                side = key.data
                # One receive per readiness iteration keeps timer/command handling fair.
                try:
                    raw, ancillary, flags, address = key.fileobj.recvmsg(65535, 128)
                except BlockingIOError:
                    continue
                if address[2] == socket.PACKET_OUTGOING:
                    continue
                assert not flags & socket.MSG_TRUNC, 'truncated wire frame'
                received = time.monotonic_ns()
                data = raw
                tci = None
                for level, kind, value in ancillary:
                    if level == 263 and kind == 8:
                        aux = struct.unpack_from('=IIIHHHH', value)
                        if aux[0] & (1 << 4):
                            tci = aux[5]
                if tci is not None and data[12:14] != b'\x81\x00':
                    data = data[:12] + struct.pack('!HH', 0x8100, tci) + data[12:]
                serial += 1
                enqueue(queue, serial, side, data, received, delay)
                assert len(queue) <= 256, 'wire queue ceiling exceeded'
                ident = identity(data)
                if ident is not None:
                    log(dict(kind='receive', id=ident, input_side=side, received_ns=received,
                             due_ns=received+delay, raw_received_hex=raw.hex(), aux_vlan_tci=tci, hex=data.hex()))
    finally:
        for sock in sockets:
            sock.close()
        selector.close()


if __name__ == '__main__':
    if sys.argv[1:] == ['--self-test']:
        self_check()
    else:
        main()
