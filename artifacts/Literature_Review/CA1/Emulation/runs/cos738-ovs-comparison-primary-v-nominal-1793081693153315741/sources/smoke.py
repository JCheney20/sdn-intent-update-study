"""Private netdev/veth packet controls; feasibility only, not Cisco outcomes."""
import json
import os
from pathlib import Path
import select
import socket
import struct
import subprocess
import sys
import tempfile
import time

HERE = Path(__file__).resolve().parent
TOOLS = json.loads((HERE / 'Components.json').read_text())
RUN = Path(os.environ['COS738_OVS_RUN_DIR'])
assert 'cos738-ovs-' in Path('/proc/self/cgroup').read_text()
assert os.geteuid() == 0 and Path('/proc/self/ns/net').readlink().as_posix() != sys.argv[1]
uidmap = list(map(int, Path('/proc/self/uid_map').read_text().split()))
assert len(uidmap) == 3 and uidmap[0] == 0 and uidmap[1] != 0 and uidmap[2] == 1, 'host-root execution forbidden'
assert len(json.loads(subprocess.check_output([TOOLS['iproute2']['path'] + '/bin/ip', '-json', 'link', 'show']))) == 1, 'namespace not initially empty'
IP = TOOLS['iproute2']['path'] + '/bin/ip'
OVS = TOOLS['openvswitch']['path']
log = []
processes = []
sockets = []
report = {'status': 'RUNNING', 'datapath': 'netdev', 'ovs_version': TOOLS['openvswitch']['version'],
          'network_namespace': str(Path('/proc/self/ns/net').readlink()), 'uid_map': uidmap, 'packets': []}

def command(args):
    result = subprocess.run(args, text=True, capture_output=True, timeout=8)
    log.append({'argv': args, 'exit': result.returncode, 'stdout': result.stdout, 'stderr': result.stderr})
    assert result.returncode == 0, f'command failed: {args}: {result.stderr}'
    return result.stdout

def waitfile(path):
    deadline = time.monotonic() + 5
    while not path.exists():
        assert all(p.poll() is None for p in processes), 'OVS daemon exited'
        assert time.monotonic() < deadline, f'socket missing: {path}'
        time.sleep(.02)

try:
    with tempfile.TemporaryDirectory(prefix='cos738-ovs-') as temp:
        private = Path(temp)
        env = dict(os.environ, OVS_RUNDIR=temp, OVS_LOGDIR=temp, OVS_DBDIR=temp)
        # Explicit short private paths avoid sockaddr_un length limits and system services.
        command([OVS + '/bin/ovsdb-tool', 'create', str(private / 'db'), OVS + '/share/openvswitch/vswitch.ovsschema'])
        daemon_logs = []
        def daemon(binary, args):
            stream = (RUN / (binary + '.stderr.log')).open('w')
            daemon_logs.append(stream)
            processes.append(subprocess.Popen([OVS + '/bin/' + binary, *args], env=env, stdout=stream, stderr=subprocess.STDOUT))
        daemon('ovsdb-server', [str(private / 'db'), '--remote=punix:' + str(private / 'db.sock'),
               '--pidfile=' + str(private / 'db.pid'), '--unixctl=' + str(private / 'db.ctl'), '--no-chdir'])
        waitfile(private / 'db.sock')
        def vsctl(*args):
            return command([OVS + '/bin/ovs-vsctl', '--db=unix:' + str(private / 'db.sock'), '--timeout=5', *args])
        vsctl('--no-wait', 'init')
        vsctl('--no-wait', 'set', 'Open_vSwitch', '.', 'other_config:n-handler-threads=1', 'other_config:n-revalidator-threads=1')
        daemon('ovs-vswitchd', ['unix:' + str(private / 'db.sock'), '--pidfile=' + str(private / 'vs.pid'),
               '--unixctl=' + str(private / 'vs.ctl'), '--no-chdir'])
        vsctl('add-br', 'br0', '--', 'set', 'bridge', 'br0', 'datapath_type=netdev', 'protocols=OpenFlow14',
              'fail_mode=secure', 'other_config:disable-in-band=true')
        waitfile(private / 'br0.mgmt')
        for i in (1, 2, 3):
            command([IP, 'link', 'add', f'h{i}', 'type', 'veth', 'peer', 'name', f'p{i}'])
            for name in (f'h{i}', f'p{i}'):
                command([IP, 'link', 'set', name, 'up'])
            vsctl('add-port', 'br0', f'p{i}', '--', 'set', 'interface', f'p{i}', f'ofport_request={i}')
            assert vsctl('get', 'interface', f'p{i}', 'ofport').strip() == str(i)
        endpoint = 'unix:' + str(private / 'br0.mgmt')
        def ofctl(*args):
            return command([OVS + '/bin/ovs-ofctl', '-O', 'OpenFlow14', *args])
        report['openflow_features'] = ofctl('show', endpoint)
        for name in ('h1', 'h2', 'h3'):
            s = socket.socket(socket.AF_PACKET, socket.SOCK_RAW, socket.htons(3))
            s.setsockopt(263, 8, 1)  # PACKET_AUXDATA preserves VLAN evidence when RX offload strips it.
            s.bind((name, 0))
            s.setblocking(False)
            sockets.append(s)
        def install(actions):
            flows = private / 'flows'
            flows.write_text('priority=100,in_port=1,dl_type=0x88b5,actions=' + actions + '\npriority=0,actions=drop\n')
            ofctl('--bundle', 'replace-flows', endpoint, str(flows))
            return ofctl('dump-flows', endpoint)
        def probe(label, expected_port, vlan=None):
            token = ('COS738-' + label).encode()
            packet = b'\xff' * 6 + bytes.fromhex('02000000000188b5') + token.ljust(46, b'.')
            for receiver in sockets[1:]:
                while select.select([receiver], [], [], 0)[0]:
                    receiver.recvmsg(65535, 128)
            sent_at = time.monotonic_ns()
            assert sockets[0].send(packet) == len(packet)
            found = []
            deadline = time.monotonic() + .3
            while time.monotonic() < deadline:
                ready = select.select(sockets[1:], [], [], max(0, deadline-time.monotonic()))[0]
                for receiver in ready:
                    data, ancillary, _, _ = receiver.recvmsg(65535, 128)
                    if token not in data:
                        continue
                    tag = None
                    if data[12:14] == b'\x81\x00':
                        tag = struct.unpack('!H', data[14:16])[0] & 0xfff
                    for level, kind, value in ancillary:
                        if level == 263 and kind == 8:
                            aux = struct.unpack_from('=IIIHHHH', value)
                            if aux[0] & (1 << 4):
                                tag = aux[5] & 0xfff
                    found.append({'interface': receiver.getsockname()[0], 'hex': data.hex(),
                                  'received_monotonic_ns': time.monotonic_ns(), 'vlan_id': tag})
            report['packets'].append({'label': label, 'sent_monotonic_ns': sent_at, 'sent_hex': packet.hex(), 'received': found})
            assert [item['interface'] for item in found] == ([] if expected_port is None else [expected_port]), (label, found)
            if vlan is not None:
                assert found[0]['vlan_id'] == vlan, (label, found)
        report['old_flows'] = install('output:2')
        probe('old-target', 'h2')
        report['new_flows'] = install('output:3')
        probe('new-target', 'h3')
        report['closed_flows'] = install('drop')
        probe('closed-gate', None)
        report['tag_flows'] = install('push_vlan:0x8100,set_field:4197->vlan_vid,output:3')
        probe('version-tag', 'h3', 101)
        report['interface_dump'] = vsctl('list', 'interface')
        report['status'] = 'PASS'
        # Stop daemons before removing their private sockets/database.
        for p in reversed(processes):
            p.terminate()
        for p in reversed(processes):
            p.wait(timeout=5)
        for stream in daemon_logs:
            stream.close()
except BaseException as error:
    report.update(status='FAIL', error=repr(error))
    raise
finally:
    for s in sockets:
        s.close()
    for p in reversed(processes):
        if p.poll() is None:
            p.kill()
            p.wait(timeout=2)
    report['commands'] = log
    (RUN / 'packet_smoke.json').write_text(json.dumps(report, indent=2) + '\n')
print('OVS NETDEV PACKET SMOKE PASS; private veth frames, bundle, gate and VLAN controls')
