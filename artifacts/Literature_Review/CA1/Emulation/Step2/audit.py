"""Independent read-only interpretation of raw fixture, kernel links, OVS dumps and packets."""
import hashlib
import json
from pathlib import Path
import re
import struct
import tomllib

HERE=Path(__file__).resolve().parent
ROOT=HERE.parent.parent/'Revision_Protocol'
RUNS=HERE.parent/'runs'
CASES={
 'static':('cos738-ovs-cisco-static-1793019493516907649',19),
 'queue':('cos738-ovs-cisco-queue-1793019558819216870',1),
 'version':('cos738-ovs-cisco-version-1793019621615437691',12),
}
checks=0

def check(condition,label):
    global checks
    checks+=1
    assert condition,label

manifest=tomllib.loads((ROOT/'study/Manifest.toml').read_text())
tracepath='reference_capture/runs/cos738-reference-capture-1792956866366487215/trace.toml'
check(hashlib.sha256((ROOT/tracepath).read_bytes()).hexdigest()==manifest['source_sha256'][tracepath],'executed source trace binding')
source=next(c for c in tomllib.loads((ROOT/tracepath).read_text())['trace']['cases'] if c['fixture']=='cisco' and c['k']==3 and not c['noop'])
adjacency=dict(zip(source['physical']['nodes'],source['physical']['adjacency']))
ports={(n,v):i+(0 if n.startswith('H') else 1) for n,ns in adjacency.items() for i,v in enumerate(ns)}
old=set();new=set()
for s,r in source['rules'].items():
    for row in r['initial']:old.add((s,row[0],row[1],0))
    for row in [x for x in r['initial'] if x not in r['removed']]+r['added']:new.add((s,row[0],row[1],0))
new1={(s,i,o,1) for s,i,o,_ in new}

# This parser does not use the adapter's flow-string generator or Julia table representation.
def decode_dump(s,text):
    forwarding=set();helpers=[];gates=set()
    for line in text.splitlines():
        if 'cookie=' not in line:continue
        before,actions=line.strip().split(' actions=',1)
        fields={k.strip():v.strip() for k,v in (x.strip().split('=',1) for x in before.split(',') if '=' in x)}
        cookie=int(fields['cookie'],16);table=int(fields['table']);priority=int(fields['priority'])
        if cookie==0x20000000:
            assert table==1 and priority==100 and ',ip,' in before
            assert fields['nw_src']==fields['nw_dst']=='10.0.0.0/8'
            ingress=next(n for n in adjacency[s] if ports[(s,n)]==int(fields['in_port']))
            egress=next(n for n in adjacency[s] if ports[(s,n)]==int(actions.removeprefix('output:')))
            if fields.get('vlan_tci')=='0x0000/0x1fff':tag=0
            else:
                assert fields.get('dl_vlan')=='101';tag=1
            forwarding.add((s,ingress,egress,tag))
        elif cookie==0x10000000:helpers.append((table,priority,actions))
        elif cookie==0x30000000:
            assert s=='C2' and table==0
            tagmatch={'0x1000/0x1000':'present','0x0000/0x1fff':'none'}.get(fields.get('vlan_tci'),'any')
            gates.add((int(fields['in_port']),priority,tagmatch,actions))
        else:raise AssertionError('unknown flow class')
    assert sorted(helpers)==[(0,0,'goto_table:1'),(1,0,'drop')]
    return forwarding,gates,len(helpers)

def gates_for(oldopen,newopen,newtag):
    result=set()
    for host,opened,tag in [('H5',oldopen,0),('H6',newopen,newtag)]:
        port=ports[('C2',host)]
        if not opened:result.add((port,200,'any','drop'));continue
        action='goto_table:1' if tag==0 else 'push_vlan:0x8100,set_field:4197->vlan_vid,goto_table:1'
        result.add((port,200,'none',action));result.add((port,201,'present','pop_vlan,'+action))
    return result

def decode_frame(hexdata):
    data=bytes.fromhex(hexdata);assert len(data)>=34
    etype=int.from_bytes(data[12:14],'big');offset=14;tag=None
    if etype==0x8100:
        tag=int.from_bytes(data[14:16],'big')&4095
        etype=int.from_bytes(data[16:18],'big');offset=18
    assert etype==0x0800
    ip=data[offset:];ihl=(ip[0]&15)*4;total=int.from_bytes(ip[2:4],'big')
    assert ip[0]>>4==4 and ihl>=20 and total<=len(ip) and ip[9]==253
    checksum=sum(int.from_bytes(ip[i:i+2],'big') for i in range(0,ihl,2))
    while checksum>>16:checksum=(checksum&65535)+(checksum>>16)
    assert checksum==65535
    payload=ip[ihl:total];assert payload.startswith(b'COS738S2:')
    return int(payload.split(b':',2)[1]),tag,ip[:total],data[:12]

expected_static={101:('H9',None),102:(None,None),150:(None,None),151:(None,None),152:('H9',None),160:('H10',None),161:(None,None)}
expected_static.update({i:(None,None) for i in range(111,123)})
expected_version={401:('H9',None),402:(None,None),403:('H9',None),404:('H10',101),405:('H10',101),410:('H10',101),411:(None,None),412:('H9',None),413:(None,None),420:(None,None),421:('H10',101),422:('H10',101)}
summary=[];flow_counts=[]
for mode,(name,count) in CASES.items():
    run=RUNS/name;data=json.loads((run/'adapter_validation.json').read_text());resource=json.loads((run/'receipt.json').read_text())
    check(data['status']=='PASS' and int((run/'exit_code').read_text())==0,'accepted adapter run')
    check(data['validation_only'] and not data['primary_data'],'not primary data')
    check(resource['memory_max_bytes']==2**31 and resource['swap_max_bytes']==0,'RAM/swap')
    check(resource['cpu_max']=='200000 100000' and resource['affinity']==[0,1],'CPU envelope')
    check(resource['elapsed_seconds']<120 and resource['memory_peak_at_checkpoint_bytes']<2**31,'runtime bounds')
    check(all(data['cleanup'].values()),'normal cleanup')
    for file,expected in data['source_sha256'].items():
        check(hashlib.sha256((HERE/file).read_bytes()).hexdigest()==expected,'current validated source')
        check(hashlib.sha256((run/'sources/Step2'/file).read_bytes()).hexdigest()==expected,'retained source snapshot')
    evidence=data['adapter_evidence'];actualports=evidence['actual_ports']
    check(len(actualports)==sum(len(adjacency[s]) for s in source['switches']),'complete switch port domain')
    for row in actualports:check(row['port']==ports[(row['switch'],row['neighbor'])],'OVS port mapping')
    check(len(evidence['kernel_edges'])==28,'kernel edge count')
    check({frozenset((e['left'],e['right'])) for e in evidence['kernel_edges']}=={frozenset(e) for e in source['physical']['edges']},'actual edge identities')
    ns=evidence['node_namespaces'];check(len({ns[h] for h in source['hosts']})==12,'host namespace separation')
    for node,info in evidence['workers'].items():
        check(info['status']=='READY' and info['netns']==ns[node],'packet worker namespace')
        check(info['interfaces']==evidence['interfaces'][node],'packet worker physical interfaces')
    for edge in evidence['kernel_edges']:
        n,m=edge['left'],edge['right'];l,r=edge['left_interface'],edge['right_interface']
        check(l['ifname']==evidence['interfaces'][n][m] and r['ifname']==evidence['interfaces'][m][n],'kernel interface identity')
        check(l['linkinfo']['info_kind']==r['linkinfo']['info_kind']=='veth','actual virtual link kind')
        if ns[n]==ns[m]:check(l['link']==r['ifname'] and r['link']==l['ifname'],'same-namespace reciprocal peers')
        else:check(l['link_index']==r['ifindex'] and r['link_index']==l['ifindex'],'cross-namespace reciprocal peers')
    for snapshot in evidence['snapshots']:
        s,label=snapshot['switch'],snapshot['label']
        if label=='old-static':expected=old;g=(True,False,0)
        elif label=='new-static':expected=new;g=(False,True,0)
        elif label=='queue-closed':expected=new;g=(False,False,0)
        elif label=='queue-open':expected=new;g=(False,True,0)
        elif label=='staged':expected=old|new1;g=(True,False,0)
        elif label=='committed':expected=old|new1;g=(False,True,1)
        elif label=='cleaned':expected=new1;g=(False,True,1)
        else:raise AssertionError(label)
        found,gates,helpers=decode_dump(s,snapshot['dump'])
        check(found=={r for r in expected if r[0]==s},'raw-source to actual forwarding correspondence')
        check(gates==(gates_for(*g) if s=='C2' else set()),'physical gates/tag assignment')
        check((snapshot['oldopen'],snapshot['newopen'],snapshot['newtag'])==g,'snapshot state declaration')
        flow_counts.append(dict(mode=mode,label=label,switch=s,logical_rows=len(found),gate_flows=len(gates),helper_flows=helpers,total_flows=len(found)+len(gates)+helpers))
    expected_cases=expected_static if mode=='static' else expected_version if mode=='version' else {301:('H10',None)}
    check(len(data['cases'])==count and {c['id'] for c in data['cases']}==set(expected_cases),'declared packet-control coverage')
    for case in data['cases']:
        ident,_,body,mac=decode_frame(case['sent_hex']);check(ident==case['id'],'emitted identity')
        expected,tag=expected_cases[ident]
        check((case['expected_host'],case['expected_vlan'])==(expected,tag),'independent case expectation')
        hosts=[e for e in case['observed'] if e['node'].startswith('H')]
        check([e['node'] for e in hosts]==([] if expected is None else [expected]),'physical destination observations')
        if 'arrival_ns' in case:check(case['send']['before_ns']>=case['arrival_ns'],'preserved pre-admission arrival')
        for event in hosts:
            rxid,rxtag,rxbody,rxmac=decode_frame(event['hex'])
            check(rxid==ident and rxtag==tag and rxbody==body and rxmac==mac,'actual bytes/version preserved')
            check(event['received_ns']>=case['send']['before_ns'],'shared monotonic clock ordering')
            raw=bytes.fromhex(event['raw_received_hex']);canonical=bytes.fromhex(event['hex'])
            if raw!=canonical:
                check(event['aux_vlan_tci'] is not None and raw[:12]+struct.pack('!HH',0x8100,event['aux_vlan_tci'])+raw[12:]==canonical,'explicit RX offload reconstruction')
    if mode=='queue':
        q=data['queue'];check(q['admitted_ids']==[301] and q['emission_calls']==1 and q['overflow_disposition']=='OUTSIDE_DOMAIN','queue conservation')
        check(q['pending_wait_ns']==q['emission_before_ns']-q['arrival_ns']>0,'waiting origin not reset')
    if mode=='version':
        check(max(data['staged_extra_forwarding_rows'].values())==1,'logical capacity separate from helpers')
        check(sum(s['label']=='committed' for s in evidence['snapshots'])==1 and next(s for s in evidence['snapshots'] if s['label']=='committed')['switch']=='C2','one-switch commit only')
    summary.append(dict(mode=mode,run=name,packet_controls=count,driver_checks=data['checks'],elapsed_seconds=resource['elapsed_seconds'],checkpoint_peak_bytes=resource['memory_peak_at_checkpoint_bytes']))

# Corrupted in-memory controls must be rejected, without touching stored results.
first=json.loads((RUNS/CASES['static'][0]/'adapter_validation.json').read_text())
text=next(s['dump'] for s in first['adapter_evidence']['snapshots'] if s['switch']=='C2')
try:decode_dump('C2',text.replace('nw_dst=10.0.0.0/8','nw_dst=11.0.0.0/8'));rejected=False
except (AssertionError,ValueError,StopIteration):rejected=True
check(rejected,'corrupted prefix rejected')
bad=bytearray.fromhex(first['cases'][0]['sent_hex']);bad[24]^=1
try:decode_frame(bad.hex());rejected=False
except (AssertionError,ValueError):rejected=True
check(rejected,'corrupted IPv4 bytes rejected')
check(int((HERE/'verification/unbounded.exit-code').read_text())!=0,'unbounded Step-2 invocation refused')
report=dict(status='PASS',checks=checks,summary=summary,flow_counts=flow_counts,primary_data=False,
            audit_source_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
            source_trace_sha256=manifest['source_sha256'][tracepath],
            scope='adapter controls only; finite observations, not timed handover or universal safety')
(HERE/'Audit.json').write_text(json.dumps(report,indent=2)+'\n')
print(f'STEP 2 AUDIT PASS: {checks} checks, {sum(c[1] for c in CASES.values())} packet controls, raw source/OVS/kernel/queue/version agreement.')
