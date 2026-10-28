"""Small red-capable checks for the independent packet/flow parsers; no networking."""
import json
from pathlib import Path
import sys
sys.path.insert(0,str(Path(__file__).resolve().parent))
import audit

run=audit.RUNS/'cos738-ovs-wire-timing-vector-1793079788777892588'
data=json.loads((run/'timing_validation.json').read_text())
case=next(c for c in data['cases'] if c['id']==7001)
assert audit.frame(case['sent_hex'])[0:2]==(7001,None)
bad=bytearray.fromhex(case['sent_hex']);bad[24]^=1
try:audit.frame(bad.hex())
except AssertionError:pass
else:raise AssertionError('bad checksum accepted')
snapshot=next(s for s in data['adapter_evidence']['snapshots'] if s['switch']=='C2' and s['label']=='timing-old')
fwd,gates=audit.dump('C2',snapshot['dump'])
assert fwd=={r for r in audit.old if r[0]=='C2'} and gates==audit.gateflows((True,False,0))
try:audit.dump('C2',snapshot['dump'].replace('nw_dst=10.0.0.0/8','nw_dst=11.0.0.0/8'))
except AssertionError:pass
else:raise AssertionError('wrong prefix accepted')
assert audit.median_ms([]) is None
print('INDEPENDENT PARSER CHECKS PASS: real bytes/flows accepted; corrupt checksum/prefix rejected')
