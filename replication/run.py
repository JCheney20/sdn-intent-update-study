"""Fresh, bounded replication. Frozen public artifacts are never execution outputs."""
import argparse
import fcntl
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import time
import tomllib

sys.path.insert(0, str(Path(__file__).resolve().parent))
from configure import python_env
from workspace import ROOT, TRACE, Workspace, sha, write_json


def reference_semantics(path):
    data = tomllib.loads(Path(path).read_text())['trace']
    for case in data['cases']:
        for name in ['plain_return', 'instrumented_return']:
            case[name] = [case[name][1], case[name][3]]  # Exclude only three measured clock fields.
    return data


class Replication:
    def __init__(self, output, config):
        self.w = Workspace(output)
        self.c = config
        self.env = python_env(config)
        self.env['PATH'] = ':'.join([str(self.w.output / 'tools/bin'),
            *(entry['path'] + '/bin' for block in ['tool_components', 'interop_components'] for entry in config[block].values()), os.environ['PATH']])
        self.env.update(JULIA_PKG_OFFLINE='true', JULIA_LOAD_PATH='@stdlib',
                        JULIA_DEPOT_PATH=str(self.w.output / 'depot') + ':')

    def execute(self, args, cwd=None, expected=0, env=None):
        args = list(map(str, args))
        ident = str(time.time_ns())
        folder = self.w.output / 'coordinator'
        folder.mkdir(exist_ok=True)
        start = time.monotonic()
        result = subprocess.run(args, cwd=cwd, env=env or self.env, capture_output=True, text=True)
        (folder / (ident + '.log')).write_text(result.stdout + result.stderr)
        with (self.w.output / 'commands.jsonl').open('a') as stream:
            stream.write(json.dumps({'command': args, 'cwd': str(cwd), 'exit_code': result.returncode,
                'expected_exit_code': expected, 'elapsed_seconds': time.monotonic() - start, 'log': ident + '.log'}) + '\n')
        print(result.stdout, end='', flush=True)
        if result.returncode != expected:
            print(result.stderr, end='', file=sys.stderr)
            raise RuntimeError(f'Command failed ({result.returncode}); retained log {folder / (ident + ".log")}')
        return result.stdout

    def script(self, script, *args, expected=0, env=None):
        output = self.execute(['bash', script, *args], expected=expected, env=env)
        match = re.search(r'^Run: (.+)$', output, re.M)
        return Path(match[1]) if match else None

    def bounded(self, label, command, family='ovs', expected=0):
        unit = f'cos738-{family}-replication-{label}-{time.time_ns()}'
        folder = self.w.output / 'audits' / unit
        folder.mkdir(parents=True)
        args = ['timeout', '--signal=TERM', '--kill-after=1s', '120s',
                'systemd-run', '--user', '--scope', '--quiet', '--expand-environment=no', '--unit=' + unit,
                '-p', 'MemoryMax=2147483648', '-p', 'MemorySwapMax=0', '-p', 'CPUQuota=200%',
                'timeout', '--signal=TERM', '--kill-after=1s', '118s', 'taskset', '-c', '0,1',
                self.c['python'], '-s', '-P', '-B', ROOT / 'replication/bounded.py', folder / 'receipt.json', *command]
        try:
            self.execute(args, expected=expected)
        finally:
            subprocess.run(['systemctl', '--user', 'kill', '--kill-whom=all', unit + '.scope'], capture_output=True)
        return folder

    def emulation_job(self, label, relative, *args, expected=0, extra_env=None):
        env = dict(self.env)
        env.update(extra_env or {})
        return self.script(self.w.emu / 'scope.sh', 'replication-' + label,
                           'bash', self.w.emu / relative, *args, expected=expected, env=env)

    def validation(self):
        w = self.w
        jobs = {}
        for mode in ['preflight', 'environment', 'oracle', 'differential', 'lifecycle']:
            jobs[mode] = str(self.script(w.model / 'validation/run.sh', mode))
        capture = self.script(w.model / 'reference_capture/run.sh', 'capture')
        baseline = ROOT / 'artifacts/Literature_Review/CA1/Revision_Protocol' / TRACE
        assert reference_semantics(capture / 'trace.toml') == reference_semantics(baseline), 'Reference scientific choices differ from baseline'
        # Compatibility fixture filename is retained so every scientific kernel remains unchanged.
        shutil.copy2(capture / 'trace.toml', w.model / TRACE)
        write_json(w.output / 'REFERENCE_BINDING.json', {'new_capture': str(capture),
            'compatibility_fixture_path': TRACE, 'fresh_trace_sha256': sha(capture / 'trace.toml'),
            'baseline_trace_sha256': sha(baseline), 'all_scientific_choices_equal': True,
            'excluded_clock_fields': ['plain_return[0,2,4]', 'instrumented_return[0,2,4]']})
        replay = self.script(w.model / 'reference_capture/run.sh', 'replay', capture)
        for mode in ['controllers-cisco', 'controllers-fat4']:
            jobs[mode] = str(self.script(w.model / 'validation/run.sh', mode))
        write_json(w.output / 'VALIDATION.json', {'jobs': jobs, 'capture': str(capture), 'replay': str(replay)})
        freeze = 'Literature_Review/CA1/Revision_Protocol/study/freeze.jl'
        for old, new in [
            ('reference_capture/runs/cos738-reference-replay-1792957198528826086/replay_receipt.toml', str((replay / 'replay_receipt.toml').relative_to(w.model))),
            ('validation/runs/cos738-revision-1792996081759461393/receipt.toml', str((Path(jobs['controllers-cisco']) / 'receipt.toml').relative_to(w.model))),
            ('validation/runs/cos738-revision-1792996109974263456/receipt.toml', str((Path(jobs['controllers-fat4']) / 'receipt.toml').relative_to(w.model)))]:
            w.replace(freeze, old, new)
        self.script(w.model / 'study/run.sh', 'freeze')

    def model(self):
        self.script(self.w.model / 'study/run_all.sh')
        command = [self.c['julia'], '--startup-file=no', '--history-file=no', '--compiled-modules=no', '--threads=1', '--gcthreads=1']
        self.bounded('model-audit', [*command, self.w.model / 'study/verify_artifacts.jl'], family='study')
        self.bounded('coverage', [*command, self.w.model / 'study/coverage.jl'], family='study')

    def emulation(self):
        w = self.w
        interop = {}
        interop['bridge'] = self.emulation_job('bridge', 'Interop/run.sh', 'bridge')
        interop['network1'] = self.emulation_job('network1', 'Interop/run.sh', 'network')
        interop['network2'] = self.emulation_job('network2', 'Interop/run.sh', 'network')
        interop['negative'] = self.emulation_job('cleanup-control', 'Interop/run.sh', 'network', expected=1,
                                               extra_env={'FEASIBILITY_FAIL_AFTER_READY': '1'})
        checker = 'Literature_Review/CA1/Emulation/Interop/verify_step1.py'
        for old, key in [('cos738-ovs-pythoncall-import-1793014645892112702', 'bridge'),
                         ('cos738-ovs-mininet-network-1793015266155977570', 'network1'),
                         ('cos738-ovs-mininet-network-1793015519428636501', 'network2'),
                         ('cos738-ovs-mininet-cleanup-negative-1793015577639407271', 'negative')]:
            w.replace(checker, old, interop[key].name)
        self.negative_launch(w.emu / 'Interop/run.sh', 'bridge', w.emu / 'Interop/verification')
        w.rebind_seal('Literature_Review/CA1/Emulation/Interop/Environment_Manifest.sha256')
        self.bounded('step1-audit', [self.c['python'], '-I', '-B', w.emu / 'Interop/verify_step1.py'])
        step2 = {}
        for mode in ['static', 'queue', 'version']:
            step2[mode] = self.emulation_job('cisco-' + mode, 'Step2/run.sh', mode)
        checker = 'Literature_Review/CA1/Emulation/Step2/audit.py'
        for old, mode in [('cos738-ovs-cisco-static-1793019493516907649', 'static'),
                          ('cos738-ovs-cisco-queue-1793019558819216870', 'queue'),
                          ('cos738-ovs-cisco-version-1793019621615437691', 'version')]:
            w.replace(checker, old, step2[mode].name)
        self.negative_launch(w.emu / 'Step2/run.sh', 'static', w.emu / 'Step2/verification')
        self.bounded('step2-audit', [self.c['python'], '-I', '-B', w.emu / 'Step2/audit.py'])
        w.rebind_seal('Literature_Review/CA1/Emulation/Step2/Validated_Source_Manifest.sha256')
        timing = self.emulation_job('timing', 'Step3/run.sh', 'timing')
        self.bounded('timing-audit', [self.c['python'], '-I', '-B', w.emu / 'Comparison/audit.py', 'timing', timing.name])
        params = w.emu / 'Comparison/Parameters.json'
        data = json.loads(params.read_text())
        data['validation_timing_run'] = timing.name
        write_json(params, data)
        self.bounded('emulation-freeze', [self.c['python'], '-I', '-B', w.emu / 'Comparison/guard.py', 'freeze'])
        self.emulation_job('envelope', 'Comparison/run.sh', 'validation', data['validation_cell'])
        self.bounded('envelope-audit', [self.c['python'], '-I', '-B', w.emu / 'Comparison/audit.py', 'validation'])
        for cell in data['cell_order']:
            self.emulation_job('primary-' + cell.lower(), 'Comparison/run.sh', 'primary', cell)
        self.bounded('packet-results-audit', [self.c['python'], '-I', '-B', w.emu / 'Comparison/audit.py', 'results'])
        # Actual duplicate rejection, before namespace/network setup; do not infer it from file presence.
        record = w.emu / 'Comparison/attempts/primary-ordinary-nominal.json'
        before = record.read_bytes()
        self.emulation_job('duplicate-control', 'Comparison/run.sh', 'primary', 'ordinary-nominal', expected=2)
        assert record.read_bytes() == before
        write_json(w.output / 'EMULATION.json', {'interop': {k: str(v) for k, v in interop.items()},
            'step2': {k: str(v) for k, v in step2.items()}, 'timing': str(timing), 'duplicate_refused': True})

    def negative_launch(self, script, mode, folder):
        folder.mkdir(exist_ok=True)
        env = dict(self.env)
        env.pop('COS738_OVS_RUN_DIR', None)
        result = subprocess.run(['bash', str(script), mode], env=env, capture_output=True, text=True, timeout=5)
        assert result.returncode != 0
        (folder / 'unbounded.exit-code').write_text(str(result.returncode) + '\n')
        (folder / 'unbounded.log').write_text(result.stdout + result.stderr)

    def phase(self, name):
        ledger = self.w.output / 'PHASES.json'
        phases = json.loads(ledger.read_text()) if ledger.exists() else {}
        assert name not in phases, 'Phase already attempted; preserve it and use a new replication ID after a failure'
        order = ['validation', 'model', 'emulation', 'compare']
        for prerequisite in order[:order.index(name)]:
            assert phases.get(prerequisite, {}).get('status') == 'PASS', prerequisite
        phases[name] = {'status': 'STARTED', 'started_ns': time.time_ns()}
        write_json(ledger, phases)
        try:
            self.w.kernel_check()
            for key, path in {'julia': self.c['julia'], 'python': self.c['python'],
                              'python_lib': self.c['python_lib'],
                              'ovs-vsctl': str(Path(self.c['tool_components']['openvswitch']['path']) / 'bin/ovs-vsctl')}.items():
                assert sha(path) == self.c['binary_sha256'][key], 'Runtime binary changed: ' + key
            for path, expected in self.c.get('library_sha256', {}).items():
                assert sha(path) == expected, 'Configured native library changed: ' + path
            if name == 'compare':
                self.execute([self.c['python'], '-I', '-B', ROOT / 'replication/compare.py', self.w.output])
            else:
                getattr(self, name)()
            self.w.kernel_check()
            phases[name]['status'] = 'PASS'
        except BaseException as error:
            phases[name].update(status='FAIL', error=repr(error))
            raise
        finally:
            phases[name]['ended_ns'] = time.time_ns()
            write_json(ledger, phases)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--environment', required=True)
    parser.add_argument('--output', required=True)
    parser.add_argument('--phase', choices=['prepare', 'validation', 'model', 'emulation', 'compare', 'all'], default='all')
    args = parser.parse_args()
    config = json.loads(Path(args.environment).read_text())
    assert config['source_checkout'] == str(ROOT), 'Configure the environment from this checkout'
    # One local replication at a time across routes/checkouts; no stale-lock deletion.
    with Path(f'/tmp/sdn-study-replication-{os.getuid()}.lock').open('a') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        process = Replication(args.output, config)
        if args.phase in ('prepare', 'all'):
            subprocess.run([sys.executable, '-I', '-B', str(ROOT / 'verify.py')], check=True)
            process.w.prepare(config)
        else:
            assert process.w.output.is_dir()
            assert (process.w.output / 'environment.json').read_text() == json.dumps(config, indent=2) + '\n'
        if args.phase != 'prepare':
            for name in (['validation', 'model', 'emulation', 'compare'] if args.phase == 'all' else [args.phase]):
                process.phase(name)

if __name__ == '__main__':
    main()
