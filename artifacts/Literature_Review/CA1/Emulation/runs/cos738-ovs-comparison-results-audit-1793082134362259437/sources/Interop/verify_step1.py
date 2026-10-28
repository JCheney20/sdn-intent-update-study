"""Read-only verification of retained Step-1 controls; no Mininet/Julia execution."""
import hashlib
import json
from pathlib import Path
import tomllib

HERE=Path(__file__).resolve().parent
RUNS=HERE.parent/'runs'
checks=0

def check(condition,label):
    global checks
    checks+=1
    assert condition,label

def toml(path):
    return tomllib.loads(path.read_text())

for line in (HERE/'Environment_Manifest.sha256').read_text().splitlines():
    expected,name=line.split('  ',1)
    check(hashlib.sha256((HERE/name).read_bytes()).hexdigest()==expected,'source binding: '+name)
components=json.loads((HERE/'Components.json').read_text())
check(components['mininet']['version']=='2.3.1b4','Mininet pin')
sources=json.loads((HERE/'JuliaSources.json').read_text())
lock=json.loads((HERE/'flake.lock').read_text())
for name,path in sources.items():
    project=toml(Path(path)/'Project.toml')
    check(project['name']==name,'Julia package identity')
    check((HERE/'Packages'/name).resolve()==Path(path),'Julia package path')
    check('narHash' in lock['nodes'][name]['locked'] and 'rev' in lock['nodes'][name]['locked'],'immutable Julia source lock')
    check((HERE/'gc_roots'/name).resolve()==Path(path),'Julia source GC root')
check(toml(HERE/'Project.toml')['preferences']['CondaPkg']['backend']=='Null','no Conda backend')
check(not (HERE/'.CondaPkg').exists() and not (HERE/'.venv').exists(),'no managed Python environment')
bridge=RUNS/'cos738-ovs-pythoncall-import-1793014645892112702'
b=toml(bridge/'bridge_smoke.toml')
check(b['status']=='PASS' and b['pythoncall_version']=='0.9.37','real PythonCall import')
check(b['condapkg_backend']=='Null' and b['mininet_version']=='2.3.1b4','pinned embedded module')
check(b['python_executable']==components['python']['path']+'/bin/python3.11','locked Python executable')
for name,expected in [('cos738-ovs-mininet-network-1793015266155977570',0),
                      ('cos738-ovs-mininet-network-1793015519428636501',0),
                      ('cos738-ovs-mininet-cleanup-negative-1793015577639407271',1)]:
    run=RUNS/name
    r=json.loads((run/'receipt.json').read_text());data=toml(run/'network_smoke.toml')
    check(int((run/'exit_code').read_text())==expected and r['exit_code']==expected,'expected process disposition')
    check(r['memory_max_bytes']==2**31 and r['swap_max_bytes']==0,'hard memory/swap')
    check(r['cpu_max']=='200000 100000' and r['affinity']==[0,1],'CPU envelope')
    check(r['elapsed_seconds']<120 and r['memory_peak_at_checkpoint_bytes']<=2**31,'job bound')
    check(data['node_netns'][0]!=data['node_netns'][1] and all(ns!=data['netns'] for ns in data['node_netns'][:2]),'separate Mininet host namespaces')
    check(data['node_netns'][2]==data['netns'],'switch stays in private parent network')
    check(data['ovs_daemons_exited'],'private daemon cleanup')
    if expected:
        check(data['status']=='FAIL' and data['error'].startswith('EXPECTED feasibility cleanup injection'),'injected failure, not unexpected mismatch')
        check(data['cleanup_interfaces_removed'] and data['cleanup_nodes_reaped'],'failure-path cleanup')
    else:
        check(data['status']=='PASS' and data['resident_interpreter_confirmed'],'resident Julia/embedded Python')
        check(data['post_ready_ping_loss_percent']==0.0,'real post-readiness packets')
        check('0 received' in data['closed_ping_output'] or '0 packets received' in data['closed_ping_output'],'closed forwarding control')
        check('OF1.4' in data['vlan_flows'],'OpenFlow version/readback')
        packet=json.loads((run/'mininet_packet.json').read_text())
        check(packet['vlan_id']==101 and packet['network_namespace']==data['node_netns'][1],'actual VLAN delivery into Mininet host')
        check(b'COS738-MININET-PYTHONCALL-VLAN' in bytes.fromhex(packet['hex']),'captured packet identity')
        check(data['mininet_interfaces_removed'] and data['mininet_node_processes_reaped'],'normal cleanup')
check(int((HERE/'verification/unbounded.exit-code').read_text())!=0,'unbounded launcher refused')
print(f'STEP 1 VERIFICATION PASS: {checks} checks; Mininet/PythonCall route feasible on the isolated netdev backend.')
print('No Cisco adapter validation, frozen emulation experiment, production guarantee or speed comparison is established.')
