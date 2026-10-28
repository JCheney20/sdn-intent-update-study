"""Independent raw-fixture/OVS/packet audit. Does not import Julia controller code."""
from collections import Counter
import csv
import json
from pathlib import Path
import statistics
import sys
import tomllib
from guard import HERE, CA1, check as check_freeze, sha

RUNS=HERE.parent/'runs'
checks=0

def require(value,label):
 global checks
 checks+=1
 assert value,label

bounds=tomllib.loads((CA1/'Revision_Protocol/Handover_Bounds.toml').read_text())['fixtures'][0]
trace=tomllib.loads((CA1/'Revision_Protocol/reference_capture/runs/cos738-reference-capture-1792956866366487215/trace.toml').read_text())
raw=next(c for c in trace['trace']['cases'] if c['fixture']=='cisco' and c['k']==3 and not c['noop'])
adjacency=dict(zip(raw['physical']['nodes'],raw['physical']['adjacency']))
ports={(n,m):i+(0 if n.startswith('H') else 1) for n,ns in adjacency.items() for i,m in enumerate(ns)}
old=set();new=set()
for s,rs in raw['rules'].items():
 old.update((s,r[0],r[1],0) for r in rs['initial'])
 new.update((s,r[0],r[1],0) for r in [r for r in rs['initial'] if r not in rs['removed']]+rs['added'])
new1={(s,i,o,1) for s,i,o,_ in new}


def frame(hexdata):
 data=bytes.fromhex(hexdata);assert len(data)>=34
 eth=int.from_bytes(data[12:14],'big');offset=14;tag=None
 if eth==0x8100:
  tag=int.from_bytes(data[14:16],'big')&4095;eth=int.from_bytes(data[16:18],'big');offset=18
 assert eth==0x0800
 ip=data[offset:];ihl=(ip[0]&15)*4;length=int.from_bytes(ip[2:4],'big')
 assert ip[0]>>4==4 and ihl>=20 and length<=len(ip) and ip[9]==253
 checksum=sum(int.from_bytes(ip[i:i+2],'big') for i in range(0,ihl,2))
 while checksum>>16:checksum=(checksum&65535)+(checksum>>16)
 assert checksum==65535
 payload=ip[ihl:length];assert payload.startswith(b'COS738S2:')
 return int(payload.split(b':',2)[1]),tag,ip[:length],data[:12]


def resources(run):
 r=json.loads((run/'receipt.json').read_text())
 require(r['exit_code']==0 and int((run/'exit_code').read_text())==0,'successful bounded job')
 require(r['memory_max_bytes']==2147483648 and r['swap_max_bytes']==0,'memory/swap')
 require(r['cpu_max']=='200000 100000' and r['affinity']==[0,1],'CPU quota/affinity')
 require(r['elapsed_seconds']<120 and r['memory_peak_at_checkpoint_bytes']<2147483648,'elapsed/peak')
 return r


def wiring(evidence):
 wire=evidence['wire_realization'];ns=wire['node_namespaces']
 require((wire['logical_nodes'],wire['logical_edges'],wire['helper_nodes'])==(22,28,1),'declared logical graph')
 expected={frozenset(e) for e in raw['physical']['edges'] if frozenset(e)!=frozenset(('C10','C4'))}|{frozenset(('C10','wire')),frozenset(('wire','C4'))}
 require(len(wire['expanded_edges'])==29 and {frozenset((e['left'],e['right'])) for e in wire['expanded_edges']}==expected,'expanded wire graph')
 require(len({ns[h] for h in raw['hosts']})==12,'host namespaces')
 for edge in wire['expanded_edges']:
  n,m=edge['left'],edge['right'];l,r=edge['left_interface'],edge['right_interface']
  require(l['ifname']==wire['physical_interfaces'][n][m] and r['ifname']==wire['physical_interfaces'][m][n],'actual interface identities')
  require(l['linkinfo']['info_kind']==r['linkinfo']['info_kind']=='veth','actual veths')
  if ns[n]==ns[m]:require(l['link']==r['ifname'] and r['link']==l['ifname'],'same-namespace peers')
  else:require(l['link_index']==r['ifindex'] and r['link_index']==l['ifindex'],'cross-namespace peers')
 require(len(wire['actual_ports'])==sum(len(adjacency[s]) for s in raw['switches']),'complete ofport domain')
 for port in wire['actual_ports']:require(port['port']==ports[port['switch'],port['neighbor']],'preserved switch ofport')


def relay(events,ident,sourcehex,tag,required=True):
 rx=[e for e in events if e.get('node','wire')=='wire' and e['id']==ident and e.get('kind')=='receive']
 tx=[e for e in events if e.get('node','wire')=='wire' and e['id']==ident and e.get('kind')=='release']
 require(len(rx)==len(tx) and len(rx) in ((1,) if required else (0,1)),'wire receive/release counts')
 if not rx:return None
 r,t=rx[0],tx[0]
 require(r['hex']==t['hex'],'transparent full canonical bytes')
 decoded=frame(r['hex']);original=frame(sourcehex)
 require(decoded[0]==ident and decoded[1]==tag and decoded[2:]==original[2:],'wire identity/version/content')
 require(r['input_side']==0 and t['output_side']==1,'transparent direction')
 require(r['due_ns']==r['received_ns']+250000000 and t['before_ns']>=r['due_ns'],'minimum residence')
 require(t['after_ns']-r['received_ns']<=1000000000,'observed timing operating envelope')
 return r


def timing(name):
 run=RUNS/name;d=json.loads((run/'timing_validation.json').read_text());r=resources(run)
 require(d['status']=='PASS' and d['validation_only'] and not d['primary_data'],'timing validation only')
 require(all(d['cleanup'].values()),'timing cleanup')
 for f,h in d['source_sha256'].items():
  require(sha(HERE.parent/'Step3'/f)==h and sha(run/'sources/Step3'/f)==h,'accepted timing sources')
 wiring(d['adapter_evidence'])
 strict=[c for c in d['cases'] if c['strict']]
 require(len(strict)==6 and {c['id'] for c in strict}==set(range(7001,7004))|set(range(7011,7014)),'six declared timing cases')
 for c in d['cases']:
  tag=None if c['source']=='H5' else 101
  expected=bounds['old_path'][-1] if c['source']=='H5' else bounds['new_path'][-1]
  rx=relay(c['relay_events'],c['id'],c['sent_hex'],tag)
  if c['strict'] and c['source']=='H5':require(c['send']['before_ns']<=rx['received_ns']<=c['marker_ns']<rx['due_ns'],'real old residency marker')
  hosts=[e for e in c['observation']['records'] if e['node'].startswith('H')]
  require(len(hosts)==1 and hosts[0]['id']==c['id'] and hosts[0]['node']==expected,'actual timing destination')
  parsed=frame(hosts[0]['hex']);original=frame(c['sent_hex'])
  require(parsed[1]==tag and parsed[2:]==original[2:],'actual timing bytes/version')
  require(hosts[0]['received_ns']<=c['observation']['deadline_ns'],'timing application cutoff')
 report=dict(status='PASS',run=name,checks=checks,cases=len(strict),resource=r)
 (HERE/'Timing_Audit.json').write_text(json.dumps(report,indent=2)+'\n')
 return report


def dump(s,text):
 fwd=set();gates=set();helpers=[]
 for line in text.splitlines():
  if 'cookie=' not in line:continue
  before,action=line.strip().split(' actions=',1)
  f={k.strip():v.strip() for k,v in (x.strip().split('=',1) for x in before.split(',') if '=' in x)}
  cookie=int(f['cookie'],16);table=int(f['table']);priority=int(f['priority'])
  if cookie==0x20000000:
   assert table==1 and priority==100 and ',ip,' in before and f['nw_src']==f['nw_dst']=='10.0.0.0/8'
   i=next(n for n in adjacency[s] if ports[s,n]==int(f['in_port']))
   o=next(n for n in adjacency[s] if ports[s,n]==int(action.removeprefix('output:')))
   if f.get('vlan_tci')=='0x0000/0x1fff':tag=0
   else:assert f.get('dl_vlan')=='101';tag=1
   fwd.add((s,i,o,tag))
  elif cookie==0x10000000:helpers.append((table,priority,action))
  elif cookie==0x30000000:
   assert s=='C2' and table==0
   mask={'0x0000/0x1fff':'none','0x1000/0x1000':'present'}.get(f.get('vlan_tci'),'any')
   gates.add((int(f['in_port']),priority,mask,action))
  else:raise AssertionError('unknown flow cookie')
 assert sorted(helpers)==[(0,0,'goto_table:1'),(1,0,'drop')]
 return fwd,gates


def gateflows(flags):
 oldopen,newopen,tag=flags;out=set()
 for host,opened,version in [('H5',oldopen,0),('H6',newopen,tag)]:
  p=ports['C2',host]
  if not opened:out.add((p,200,'any','drop'));continue
  action='goto_table:1' if version==0 else 'push_vlan:0x8100,set_field:4197->vlan_vid,goto_table:1'
  out.add((p,200,'none',action));out.add((p,201,'present','pop_vlan,'+action))
 return out


def episode(e,data,params):
 method=e['method'];scenario=e['scenario'];t0=e['request_ns']
 require(e['resident_pid']==e['embedded_pid']==data['ready_pid'],'resident process per update')
 require(e['observation']['deadline_ns']==t0+params['observation_window_ns'],'common prospective deadline')
 expected_roles={'new','old'} if scenario=='inflight' else {'new'}
 require({r['role'] for r in e['requests']}==expected_roles and len(e['requests'])==len(expected_roles),'declared offered workload')
 actual=[]
 for req in e['requests']:
  ident,_,body,mac=frame(req['hex']);require(ident==req['id'],'stable emitted identity')
  expected=bounds['old_path'][-1] if req['role']=='old' else bounds['new_path'][-1]
  tag=101 if method=='V' and req['role']=='new' else None
  if req['role']=='new':require(req['arrival_ns']==t0 and req['send']['before_ns']>=t0,'original arrival/pre-admission waiting')
  rx=relay(e['observation']['records'],ident,req['hex'],tag,required=req['role']=='old')
  if req['role']=='old':require(req['send']['before_ns']<=rx['received_ns']<=t0<rx['due_ns'],'actual pre-update admission/residency')
  found=[x for x in e['observation']['records'] if x['node'].startswith('H') and x['id']==ident]
  for x in found:
   parsed=frame(x['hex']);require(parsed[0]==ident and parsed[2:]==(body,mac),'host raw bytes/checksum')
  ontime=[x for x in found if x['received_ns']<=e['observation']['deadline_ns']]
  wrong=any(x['node']!=expected or x['vlan']!=tag for x in found)
  status='WRONG_DESTINATION_OR_VERSION' if wrong else 'DUPLICATE' if len(found)>1 else 'UNOBSERVED' if not found else 'LATE' if not ontime else 'PASS'
  age=min((x['received_ns'] for x in ontime),default=None)
  age=None if age is None else age-req['arrival_ns']
  recorded=next(x for x in e['outcomes'] if x['id']==ident)
  require(recorded['status']==status and recorded['service_age_ns']==age,'independent outcome/age')
  actual.append(dict(role=req['role'],status=status,age_ns=age,admission_wait_ns=req['send']['before_ns']-req['arrival_ns']))
 require(all(x['id'] in {r['id'] for r in e['requests']} for x in e['observation']['records'] if x['node'].startswith('H')),'no cross-episode host contamination')
 phases=e['control']['phases'];kinds=[p['kind'] for p in phases]
 expected={'ordinary':['replace_activate','replace'],'Q':['close','drain_wait','replace','replace','open'],'V':['stage','commit','retirement_wait','clean']}[method]
 require(kinds==expected,'declared procedure order')
 for p in phases:require(p['after_ns']>=p['before_ns']>=t0,'phase clock order')
 waits=[p for p in phases if p['kind'] in ('drain_wait','retirement_wait')]
 for p in waits:
  duration=params['drain_wait_ns'] if p['kind']=='drain_wait' else params['retirement_wait_ns']
  require(p['after_ns']-p['before_ns']>=duration,'fixed wait never receipt-driven/shortened')
 total_wait=sum(p['after_ns']-p['before_ns'] for p in waits)
 control=e['control']
 require(control['intentional_wait_ns']==total_wait and control['controller_wall_ns']==control['completion_ns']-t0,'wall/wait accounting')
 require(control['nonwait_wall_ns']==control['controller_wall_ns']-total_wait,'combined nonwait accounting')
 activation=next(p for p in phases if p['kind'] in ('replace_activate','open','commit'))
 require(control['admission']['before_ns']>=activation['after_ns'],'release only after activation/readback')
 snaps=data['adapter_evidence']['snapshots'][e['snapshot_first']-1:e['snapshot_last']]
 require(len(snaps)=={'ordinary':2,'Q':4,'V':9}[method],'actual switch-local bundle count')
 state={s:{r for r in old if r[0]==s} for s in raw['switches']};flags=(True,False,0);peak=0;peakflows=0
 for snap in snaps:
  s,label=snap['switch'],snap['label']
  if label=='ordinary-activate':require(s=='C2','ordinary activation local');state[s]={r for r in new if r[0]==s};flags=(False,True,0)
  elif label=='ordinary-replace':require(s=='C5','ordinary egress');state[s]={r for r in new if r[0]==s}
  elif label=='Q-close':require(s=='C2','Q close local');flags=(False,False,0)
  elif label=='Q-replace':require(s in ('C2','C5') and flags==(False,False,0),'Q closed replacements');state[s]={r for r in new if r[0]==s}
  elif label=='Q-open':require(s=='C2','Q open local');flags=(False,True,0)
  elif label=='staged':state[s]={r for r in old|new1 if r[0]==s}
  elif label=='committed':
   require(s=='C2' and set().union(*state.values())==old|new1,'complete staging before local commit');flags=(False,True,1)
  elif label=='cleaned':require(flags==(False,True,1),'cleanup after commit');state[s]={r for r in new1 if r[0]==s}
  else:raise AssertionError(label)
  fwd,gates=dump(s,snap['dump'])
  require(fwd==state[s] and gates==(gateflows(flags) if s=='C2' else set()),'actual pipeline matches raw intent/phase')
  baseline=max(sum(r[0]==s for r in old),sum(r[0]==s for r in new))
  peak=max(peak,len(fwd)-baseline);peakflows=max(peakflows,len(fwd)+len(gates)+2)
 require(set().union(*state.values())==(new1 if method=='V' else new),'final target forwarding')
 require(peak==params['extra_forwarding_rows'][method],'actual logical budget')
 return dict(requests=actual,bundles=len(snaps),extra=peak,peakflows=peakflows,controller_ns=control['controller_wall_ns'],nonwait_ns=control['nonwait_wall_ns'])


def job(record,params,mode):
 run=Path(record['run']);data=json.loads((run/'comparison.json').read_text());resource=resources(run)
 require(record.get('exit_code')==0 and data['status']=='PASS' and data['mode']==mode,'accepted attempt/result')
 require(data['manifest_sha256']==sha(HERE/'Manifest.json'),'manifest identity')
 for name,h in json.loads((HERE/'Manifest.json').read_text())['sources'].items():require(sha(run/'sources/Frozen/CA1'/name)==h,'executed source snapshot')
 require(all(data['cleanup'].values()),'normal cleanup')
 wiring(data['adapter_evidence'])
 require(len(data['warmup'])==6 and [e['method']+'-'+e['scenario'] for e in data['warmup']]==params['warm_order'],'all relevant paths warmed')
 require(data['ready_pid']==data['ready_embedded_pid'],'embedded readiness')
 for warm in data['warmup']:
  audited=episode(warm,data,params)
  require(warm['phase']=='warmup' and warm['control']['completion_ns']<data['ready_ns'],'warmup precedes readiness')
  if warm['method'] in ('Q','V'):require(all(x['status']=='PASS' for x in audited['requests']),'qualified warm controls')
 require(len(data['episodes'])==params['repetitions'] and data['primary_data']==(mode=='primary'),'finite repetitions/no promotion')
 rows=[]
 for e in data['episodes']:
  require(e['phase']==('primary' if mode=='primary' else 'validation') and e['request_ns']>=data['ready_ns'],'measured boundary')
  require(e['method']+'-'+e['scenario']==data['cell'],'cell identity')
  rows.append(episode(e,data,params))
 return data,resource,rows


def validate():
 params=check_freeze()['parameters'];record=json.loads((HERE/'attempts/validation-envelope.json').read_text())
 data,r,rows=job(record,params,'validation')
 require(all(x['status']=='PASS' for row in rows for x in row['requests']),'Q envelope agreement')
 report=dict(status='PASS',checks=checks,run=Path(record['run']).name,episodes=len(rows),whole_job_seconds=r['elapsed_seconds'],launch_to_ready_seconds=data['launch_to_ready_ns']/1e9,checkpoint_peak_bytes=r['memory_peak_at_checkpoint_bytes'])
 (HERE/'Validation_Audit.json').write_text(json.dumps(report,indent=2)+'\n');return report


def median_ms(values):
 values=list(values)
 return statistics.median(values)/1e6 if values else None


def results():
 params=check_freeze()['parameters'];rows=[];resource_rows=[];packet_count=0
 for cell in params['cell_order']:
  record=json.loads((HERE/'attempts'/('primary-'+cell+'.json')).read_text());data,r,episodes=job(record,params,'primary')
  requests=[x for e in episodes for x in e['requests']];packet_count+=len(requests)
  newreq=[x for x in requests if x['role']=='new'];oldreq=[x for x in requests if x['role']=='old']
  outcomes_count=Counter(x['status'] for x in requests)
  row=dict(cell=cell,episodes=len(episodes),new_pass=sum(x['status']=='PASS' for x in newreq),old_pass=sum(x['status']=='PASS' for x in oldreq),old_wrong=sum(x['status']=='WRONG_DESTINATION_OR_VERSION' for x in oldreq),unobserved=outcomes_count['UNOBSERVED'],late=outcomes_count['LATE'],duplicates=outcomes_count['DUPLICATE'],
           admission_wait_median_ms=statistics.median(x['admission_wait_ns'] for x in newreq)/1e6,
           new_service_age_median_ms=median_ms(x['age_ns'] for x in newreq if x['status']=='PASS'),
           completion_median_ms=statistics.median(e['controller_ns'] for e in episodes)/1e6,
           nonwait_median_ms=statistics.median(e['nonwait_ns'] for e in episodes)/1e6,bundles=episodes[0]['bundles'],extra_rows=episodes[0]['extra'],peak_switch_flows=max(e['peakflows'] for e in episodes))
  if cell.startswith(('Q-','V-')):require(all(x['status']=='PASS' for x in requests),'primary model/implementation agreement')
  rows.append(row);resource_rows.append(dict(cell=cell,run=Path(record['run']).name,whole_job_seconds=r['elapsed_seconds'],launch_to_ready_seconds=data['launch_to_ready_ns']/1e9,checkpoint_peak_bytes=r['memory_peak_at_checkpoint_bytes']))
 require(sum(r['episodes'] for r in rows)==30 and packet_count==45,'complete declared primary grid')
 report=dict(status='PASS',checks=checks,primary_episodes=30,primary_packets=packet_count,cells=rows,resources=resource_rows,manifest_sha256=sha(HERE/'Manifest.json'))
 (HERE/'Results.json').write_text(json.dumps(report,indent=2)+'\n')
 with (HERE/'Results.csv').open('w',newline='') as f:
  writer=csv.DictWriter(f,fieldnames=list(rows[0]));writer.writeheader();writer.writerows(rows)
 text=['# Frozen Cisco emulation results','',f'PASS: independent audit {checks} checks; 30 episodes / 45 primary packets.','',
       '| Cell | New PASS | Old PASS / wrong | Admission wait ms | New service age ms | Completion ms | Nonwait ms | Bundles |',
       '|---|---:|---:|---:|---:|---:|---:|---:|']
 for r in rows:
  age='--' if r['new_service_age_median_ms'] is None else f"{r['new_service_age_median_ms']:.3f}"
  text.append(f"| {r['cell']} | {r['new_pass']}/5 | {r['old_pass']} / {r['old_wrong']} | {r['admission_wait_median_ms']:.3f} | {age} | {r['completion_median_ms']:.3f} | {r['nonwait_median_ms']:.3f} | {r['bundles']} |")
 text+=['','Times are cell medians of five warmed updates, not population bounds or a pure-language comparison. Intentional fixed one-second waits are included in completion and excluded from nonwait wall time. Application receive deadlines are finite. Userspace OVS/transparent 250 ms wire/one old and one new request only; no hardware, congestion, arbitrary faults or universal real-time guarantee. Warmup/validation are excluded from primary rows.','', 'Startup/warm-up and resource receipts are retained separately in Results.json.']
 (HERE/'Results.md').write_text('\n'.join(text)+'\n');return report

if __name__=='__main__':
 action=sys.argv[1]
 report=timing(sys.argv[2]) if action=='timing' else validate() if action=='validation' else results() if action=='results' else None
 assert report is not None
 print('INDEPENDENT AUDIT PASS',action,'checks=',report['checks'])
