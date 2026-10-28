"""Prospective source freeze and exclusive attempt ledger; no network operations."""
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import shutil
import sys

HERE=Path(__file__).resolve().parent
CA1=HERE.parent.parent
MANIFEST=HERE/'Manifest.json'
SEAL=HERE/'Frozen_Manifest.sha256'
FILES=[
 'Emulation/Comparison/'+f for f in ['Parameters.json','Protocol.md','controller.jl','guard.py','run.sh','audit.py']
]+[
 'Emulation/Step3/Wire.jl','Emulation/Step3/wire.py',
 'Emulation/Step2/CiscoAdapter.jl','Emulation/Step2/packet_worker.py','Emulation/Step2/Validated_Source_Manifest.sha256',
 'Emulation/scope.sh','Emulation/scope_entry.py','Emulation/Components.json','Emulation/Environment_Manifest.sha256',
 'Emulation/Interop/Components.json','Emulation/Interop/Environment_Manifest.sha256','Emulation/Interop/JuliaSources.json',
 'Emulation/Interop/flake.lock','Emulation/Interop/Project.toml','Emulation/Interop/sandbox.sh',
 'Revision_Protocol/handover.jl','Revision_Protocol/Handover_Bounds.toml','Revision_Protocol/study/Manifest.toml',
 'Revision_Protocol/reference_capture/runs/cos738-reference-capture-1792956866366487215/trace.toml',
]

def sha(path):
 return hashlib.sha256(path.read_bytes()).hexdigest()

def check():
 assert sha(MANIFEST)==SEAL.read_text().split()[0],'frozen manifest changed'
 data=json.loads(MANIFEST.read_text())
 for name,expected in data['sources'].items():
  assert sha(CA1/name)==expected,'frozen source changed: '+name
 return data

def freeze():
 assert not MANIFEST.exists() and not SEAL.exists(),'refuse to overwrite study freeze'
 params=json.loads((HERE/'Parameters.json').read_text())
 gate=json.loads((HERE/'Timing_Audit.json').read_text())
 assert gate['status']=='PASS' and gate['run']==params['validation_timing_run'],'timing gate not independently accepted'
 data=dict(study_id=params['study_id'],created_utc=datetime.now(timezone.utc).isoformat(),parameters=params,
           timing_audit=gate,sources={name:sha(CA1/name) for name in FILES})
 with MANIFEST.open('x') as f:json.dump(data,f,indent=2);f.write('\n')
 with SEAL.open('x') as f:f.write(sha(MANIFEST)+'  Manifest.json\n')
 print('PROSPECTIVE FREEZE',sha(MANIFEST),'30 primary episodes; no primary outcomes yet')


def begin(mode,cell):
 data=check();params=data['parameters']
 assert mode in ('validation','primary') and cell in params['cell_order']
 if mode=='validation':assert cell==params['validation_cell']
 if mode=='primary':
  validation=json.loads((HERE/'attempts/validation-envelope.json').read_text())
  audit=json.loads((HERE/'Validation_Audit.json').read_text())
  assert validation.get('exit_code')==0 and audit['status']=='PASS' and audit['run']==Path(validation['run']).name,'validation envelope not accepted'
 run=Path(os.environ['COS738_OVS_RUN_DIR']).resolve()
 attempts=HERE/'attempts';attempts.mkdir(exist_ok=True)
 path=attempts/('validation-envelope.json' if mode=='validation' else 'primary-'+cell+'.json')
 record=dict(mode=mode,cell=cell,run=str(run),manifest_sha256=sha(MANIFEST),status='STARTED',started_utc=datetime.now(timezone.utc).isoformat())
 try:
  with path.open('x') as f:json.dump(record,f,indent=2);f.write('\n')
 except FileExistsError:
  print('ATTEMPT_REFUSED: already consumed '+mode+' '+cell+'; no namespace/network launched',file=sys.stderr)
  raise SystemExit(2)
 frozen=run/'sources/Frozen/CA1'
 for name in data['sources']:
  target=frozen/name;target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(CA1/name,target)
 shutil.copy2(MANIFEST,run/'frozen_manifest.json')
 print('ATTEMPT_CONSUMED',mode,cell,'before network launch',flush=True)


def finish(mode,cell,code):
 check()
 path=HERE/'attempts'/('validation-envelope.json' if mode=='validation' else 'primary-'+cell+'.json')
 record=json.loads(path.read_text())
 assert record['run']==str(Path(os.environ['COS738_OVS_RUN_DIR']).resolve())
 record.update(status='FINISHED',exit_code=int(code),ended_utc=datetime.now(timezone.utc).isoformat())
 result=Path(record['run'])/'comparison.json'
 if result.exists():record['result_status']=json.loads(result.read_text())['status']
 path.write_text(json.dumps(record,indent=2)+'\n')

if __name__=='__main__':
 action=sys.argv[1]
 if action=='freeze':freeze()
 elif action=='check':check();print('FROZEN SOURCES PASS')
 elif action=='begin':begin(*sys.argv[2:])
 elif action=='finish':finish(*sys.argv[2:])
 else:raise ValueError(action)
