"""Original Python reference: native sensitivity and matched snapshot benchmark."""
import hashlib
import importlib.util
import json
import logging
import math
import os
from pathlib import Path
import struct
import sys
import time
import tomllib

import numpy as np

HERE=Path(__file__).resolve().parent
ROOT=HERE.parent
mode, index, output = sys.argv[1], int(sys.argv[2]), Path(sys.argv[3])
manifest=tomllib.loads((HERE/'Manifest.toml').read_text())
for name, expected in manifest['source_sha256'].items():
    assert hashlib.sha256((ROOT/name).read_bytes()).hexdigest()==expected,name
source=ROOT/'reference_capture/sources'
sys.path.insert(0,str(source))
spec=importlib.util.spec_from_file_location('spotlight_study_reference',source/'detector.py')
d=importlib.util.module_from_spec(spec);spec.loader.exec_module(d)
d.logger.disabled=True  # same no-log measurement boundary for both implementations
assert not os.environ.get('NETWORKX_AUTOMATIC_BACKENDS'), 'undeclared NetworkX backend'

def dump(value):
    if isinstance(value,bool):return str(value).lower()
    if isinstance(value,str):return json.dumps(value)
    if isinstance(value,(int,float)):
        assert not isinstance(value,float) or math.isfinite(value)
        return repr(value)
    if isinstance(value,(list,tuple)):return '['+','.join(dump(x) for x in value)+']'
    if isinstance(value,dict):return '{'+','.join(json.dumps(str(k))+'='+dump(v) for k,v in value.items())+'}'
    raise TypeError(type(value))

def save(data):
    text='data='+dump(data)+'\n'
    assert tomllib.loads(text)['data']==data
    tmp=output.with_suffix('.tmp');tmp.write_text(text);tmp.replace(output)

def setup(kind):return d.prep_trial_cisco() if kind=='cisco' else d.prep_trial(4)
def fingerprint(cache):
    text=''.join(s+':'+','.join(sorted(cache[s]))+'\n' for s in sorted(cache))
    return hashlib.sha256(text.encode()).hexdigest()
def sealcheck():
    base=ROOT.parents[2]/'SDN_Model_Comparison';p=base/'Delivery_Manifest.json'
    digest=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
    assert digest(p)=='b7ed68f73366f127416afbcaab3462c52325597e7ce54e3a14b69db895e482cb'
    m=json.loads(p.read_text())
    for section,count in [('files',194),('external_context_snapshots',2)]:
        assert len(m[section])==count
        for name,want in m[section].items():assert digest(base/name)==want,name

def resources():
    cg=next(x.split('::',1)[1] for x in Path('/proc/self/cgroup').read_text().splitlines() if x.startswith('0::'))
    p=Path('/sys/fs/cgroup')/cg.lstrip('/')
    return {'scope':cg,'memory_max_bytes':int((p/'memory.max').read_text()),'swap_max_bytes':int((p/'memory.swap.max').read_text()),
            'cpu_max':(p/'cpu.max').read_text().strip(),'affinity':sorted(os.sched_getaffinity(0)),
            'memory_peak_at_checkpoint_bytes':int((p/'memory.peak').read_text())}

result={'status':'RUNNING','mode':'sensitivity' if mode=='sensitivity' else 'benchmark','index':index,
        'implementation':'python_numpy','primary_data':False,'rows':[]}
try:
    sealcheck()
    if mode=='sensitivity':
        cell=manifest['sensitivity_cells'][index];kind,config=cell['fixture'],cell['configuration']
        hosts,switches,devices,g=setup(kind);k=20 if config=='k20' else 3
        eps=np.sqrt(1.0/g.number_of_edges())
        sample_count=int((0.5/eps**2)*(np.log2(math.comb(4,2))+1+np.log(10)))
        assert sample_count==manifest['sample_counts'][kind]
        for seed in manifest['sensitivity_seeds']:
            np.random.seed(seed);start=time.perf_counter()
            cache={s.mac:d.panther_similarity(g,source=s.mac,k=k,path_length=4,weight=None) for s in switches}
            cache_seconds=time.perf_counter()-start
            aug_start=time.perf_counter()
            if config=='k3_adjacent':
                for s in switches:
                    for node in g[s.mac]:
                        if node.startswith('H'):cache[s.mac].setdefault(node,0.0)
            augmentation_seconds=time.perf_counter()-aug_start
            d.PANTHER=True;d.shortest_path_memoize.cache_clear()
            begin=time.perf_counter();states,alarms,_=d.detection_search(hosts,switches,devices,cache)
            search_seconds=time.perf_counter()-begin
            state=np.random.get_state()
            state_sha=hashlib.sha256(state[1].tobytes()+str(state[2:]).encode()).hexdigest()
            result['rows'].append({'fixture':kind,'configuration':config,'seed':seed,'cache':{str(s):sorted(str(n) for n in ns) for s,ns in cache.items()},
                'cache_sha256':fingerprint(cache),'sample_paths_per_query':sample_count,'cache_build_seconds':cache_seconds,'augmentation_seconds':augmentation_seconds,
                'detector_seconds':search_seconds,'pair_checks':states,'alarms':alarms,'alert':alarms>0,
                'rng_final_sha256':state_sha,'rng_family':'NumPy legacy RandomState MT19937'})
            save(result)
    elif mode in ('cold','warm'):
        condition=manifest['benchmark_conditions'][index]
        kind,k=condition['fixture'],condition['k']
        trace=tomllib.loads((ROOT/manifest['reference_trace']).read_text())['trace']
        case=next(c for c in trace['cases'] if c['fixture']==kind and c['k']==k and not c['noop'])
        hosts,switches,devices,g=setup(kind)
        cache={q['source']:{n:struct.unpack('>d',bytes.fromhex(b))[0] for n,b in zip(q['cache_order'],q['cache_score_bits'])} for q in case['queries']}
        d.PANTHER=True
        def measured():
            d.shortest_path_memoize.cache_clear()  # outside the timed boundary
            before=time.perf_counter();states,alarms,_=d.detection_search(hosts,switches,devices,cache)
            elapsed=time.perf_counter()-before
            assert states==case['states_checked'] and alarms==case['violations_found']
            return elapsed
        if mode=='warm':measured()
        repetitions=manifest['warm_repetitions'] if mode=='warm' else 1
        result.update(condition=index,fixture=kind,k=k,measurement=mode,elapsed_seconds=[measured() for _ in range(repetitions)],
            states_checked=case['states_checked'],alarms=case['violations_found'],logging_enabled=False)
    else:raise ValueError('unknown Python study mode')
    sealcheck()
    for name,expected in manifest['source_sha256'].items():
        assert hashlib.sha256((ROOT/name).read_bytes()).hexdigest()==expected,name
    result.update(status='PASS',resources=resources())
    save(result)
    print('PYTHON STUDY PASS',mode,index,len(result['rows']))
except BaseException as error:
    result.update(status='FAIL',error=repr(error));save(result);raise
