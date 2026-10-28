"""New-workspace materialization and auditable environment/provenance bindings."""
import difflib
import hashlib
import json
from pathlib import Path
import shutil
import shlex
import tomllib

ROOT = Path(__file__).resolve().parents[1]
TRACE = 'reference_capture/runs/cos738-reference-capture-1792956866366487215/trace.toml'
OLD_SEAL = 'b7ed68f73366f127416afbcaab3462c52325597e7ce54e3a14b69db895e482cb'

# These computational/measurement implementations must remain byte-identical.
KERNELS = ['SDN_Model_Comparison/source_fidelity/detector.jl'] + [
    'Literature_Review/CA1/Revision_Protocol/' + name for name in [
        'handover.jl', 'lifecycle.jl', 'controllers.jl', 'Handover_Bounds.toml',
        'validation/oracle.jl', 'validation/differential.jl', 'validation/lifecycle_checks.jl',
        'validation/controller_checks.jl', 'validation/comparison_map.jl',
        'reference_capture/capture.py', 'reference_capture/replay.jl',
        'reference_capture/sources/detector.py', 'reference_capture/sources/detectortypes.py',
        'reference_capture/sources/fattree.py', 'study/Study.jl', 'study/entry.jl',
        'study/analyze.jl', 'study/coverage.jl', 'study/verify_artifacts.jl']
] + ['Literature_Review/CA1/Emulation/' + name for name in [
    'Step2/CiscoAdapter.jl', 'Step2/packet_worker.py', 'Step2/validate.jl',
    'Step3/Wire.jl', 'Step3/wire.py', 'Step3/timing.jl', 'Comparison/controller.jl',
    'Comparison/guard.py', 'Comparison/audit.py', 'Interop/packet_io.py',
    'Interop/bridge_smoke.jl', 'Interop/network_smoke.jl', 'Interop/sandbox.sh']]


def sha(path):
    with Path(path).open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def write_json(path, value):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2) + '\n')


def toml_value(value):
    if isinstance(value, bool):
        return str(value).lower()
    if isinstance(value, str):
        return json.dumps(value)
    if isinstance(value, (int, float)):
        return repr(value)
    if isinstance(value, list):
        return '[' + ','.join(map(toml_value, value)) + ']'
    if isinstance(value, dict):
        return '{' + ','.join(json.dumps(k) + '=' + toml_value(v) for k, v in value.items()) + '}'
    raise TypeError(type(value))


class Workspace:
    def __init__(self, output):
        self.output = Path(output).resolve()
        self.tree = self.output / 'work/artifacts'
        self.ca1 = self.tree / 'Literature_Review/CA1'
        self.model = self.ca1 / 'Revision_Protocol'
        self.emu = self.ca1 / 'Emulation'
        self.patches = self.output / 'adaptations.json'

    def replace(self, relative, old, new, count=1):
        path = self.tree / relative
        before = path.read_text()
        assert before.count(old) == count, f'Adaptation no longer matches {relative}: {old!r}'
        after = before.replace(old, new)
        assert after != before
        path.write_text(after)
        changes = json.loads(self.patches.read_text()) if self.patches.exists() else []
        changes.append({'path': relative, 'before_sha256': hashlib.sha256(before.encode()).hexdigest(),
                        'after_sha256': sha(path), 'reason': 'replication environment/provenance or fresh-run binding',
                        'diff': ''.join(difflib.unified_diff(before.splitlines(True), after.splitlines(True)))})
        write_json(self.patches, changes)

    def kernel_check(self):
        for name in KERNELS:
            original = (ROOT / 'artifacts' / name).read_bytes()
            observed = (self.tree / name).read_bytes()
            if name == 'Literature_Review/CA1/Emulation/Comparison/audit.py':
                # Only the author-approved job budget changes, never packet/measurement checks.
                new = b"['elapsed_seconds']<130"
                assert observed.count(new) == 1, 'Missing explicit 130-second audit profile'
                observed = observed.replace(new, b"['elapsed_seconds']<120", 1)
            assert original == observed, 'Scientific kernel changed: ' + name
        vendor = json.loads((ROOT / 'replication/VENDOR.json').read_text())
        for name, expected in vendor['files'].items():
            assert sha(ROOT / 'replication/vendor' / name) == expected, name
        assert sha(self.emu / 'Interop/replication_isolate.sh') == sha(ROOT / 'replication/isolate.sh'), 'Isolation launcher changed'

    def bind_reference_trace(self, fresh):
        settings_path = self.model / 'validation/Controller_Inputs.toml'
        settings = tomllib.loads(settings_path.read_text())
        shutil.copy2(fresh, self.model / TRACE)
        observed = sha(self.model / TRACE)
        if settings['reference_trace_sha256'] != observed:
            self.replace('Literature_Review/CA1/Revision_Protocol/validation/Controller_Inputs.toml',
                         settings['reference_trace_sha256'], observed)

    def checksum_file(self, relative, names):
        path = self.tree / relative
        path.write_text(''.join(f'{sha(path.parent / name)}  {name}\n' for name in names))

    def rebind_seal(self, relative):
        original = ROOT / 'artifacts' / relative
        names = [line.split('  ', 1)[1] for line in original.read_text().splitlines()]
        if relative.endswith('Interop/Environment_Manifest.sha256'):
            names.append('replication_isolate.sh')
        self.checksum_file(relative, names)

    def prepare(self, config):
        assert not self.output.exists(), 'Fresh output directory required; no overwrite/retry'
        assert not self.output.is_relative_to(ROOT), 'Outputs must be outside the source checkout'
        self.output.mkdir(parents=True)
        write_json(self.output / 'environment.json', config)
        study_sources = {'Study.jl', 'common.jl', 'entry.jl', 'freeze.jl', 'coverage.jl',
                         'analyze.jl', 'verify_artifacts.jl', 'python_study.py', 'run.sh', 'run_all.sh', 'Protocol.md'}
        ignored = {'runs', 'attempts', 'verification', 'realization', 'revision_search',
                   'snapshots', 'cache_probes', 'runtime_cache', 'freeze-v1-pre-data'}
        for source in (ROOT / 'artifacts').rglob('*'):
            if not source.is_file() or source.is_symlink():
                continue
            relative = source.relative_to(ROOT / 'artifacts')
            name = str(relative)
            if name.endswith('/' + TRACE):
                pass  # Retained immutable fixture; fresh reference capture must reproduce it.
            elif any(part in ignored for part in relative.parts):
                continue
            elif '/Revision_Protocol/study/' in name and source.name not in study_sources:
                continue
            elif '/Emulation/' in name:
                if source.suffix not in {'.py', '.jl', '.sh', '.nix', '.lock', '.toml', '.md'} and source.name not in {'Components.json', 'JuliaSources.json', 'Parameters.json'}:
                    continue
                if source.name in {'Manifest.toml', 'Audit.json', 'Results.json'}:
                    continue
            target = self.tree / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, target)
        # Public historical dependency closure, not private assessment metadata.
        historical = self.tree / 'SDN_Model_Comparison'
        files = {str(p.relative_to(historical)): sha(p) for p in sorted(historical.rglob('*')) if p.is_file()}
        write_json(historical / 'Delivery_Manifest.json', {
            'schema': 'public-replication-scientific-closure-v1', 'files': files,
            'scope': 'Actually imported historical detector and its upstream attribution/source snapshots.',
            'excluded_administrative_context': True})
        public_hash = sha(historical / 'Delivery_Manifest.json')
        for suffix in ['Revision_Protocol/validation/entry.jl', 'Revision_Protocol/study/common.jl',
                       'Revision_Protocol/study/python_study.py', 'Revision_Protocol/reference_capture/run.sh']:
            path = 'Literature_Review/CA1/' + suffix
            self.replace(path, OLD_SEAL, public_hash)
            old = '("files",194),("external_context_snapshots",2)' if suffix.endswith('.jl') else "('files',194),('external_context_snapshots',2)"
            new = f'("files",{len(files)})' if suffix.endswith('.jl') else f"('files',{len(files)})"
            self.replace(path, old, new)
        # Relocate launcher bindings; the scientific implementations above stay unchanged.
        shutil.copy2(ROOT / 'replication/isolate.sh', self.emu / 'Interop/replication_isolate.sh')
        original_python = json.loads((ROOT / 'artifacts/Literature_Review/CA1/Revision_Protocol/reference_environment/referenceComponents.json').read_text())['interpreter']
        original_julia = tomllib.loads((ROOT / 'artifacts/Literature_Review/CA1/Revision_Protocol/study/Manifest.toml').read_text())['julia_executable']
        original_lib = str(Path(original_python).parent.parent / 'lib/libpython3.11.so')
        mininet_module = str(ROOT / 'replication/vendor/mininet')
        original_interop = json.loads((ROOT / 'artifacts/Literature_Review/CA1/Emulation/Interop/Components.json').read_text())
        old_mininet = original_interop['mininet-python']['path'] + '/lib/python3.11/site-packages'
        for suffix in ['Interop/run.sh', 'Step2/run.sh', 'Step3/run.sh', 'Comparison/run.sh']:
            path = 'Literature_Review/CA1/Emulation/' + suffix
            for old, new in [(original_python, config['python']), (original_lib, config['python_lib']),
                             (old_mininet, mininet_module), (original_julia, config['julia'])]:
                if old != new:
                    self.replace(path, old, shlex.quote(new))
            base = '$PWD' if suffix == 'Interop/run.sh' else '$interop'
            self.replace(path, 'bash "' + base + '/sandbox.sh"',
                         'bash "' + base + '/replication_isolate.sh" "' + base + '/sandbox.sh"')
        # Author-approved replication-only increase; frozen studies keep their 120-second profile.
        self.replace('Literature_Review/CA1/Emulation/scope.sh', '120s', '129s')
        self.replace('Literature_Review/CA1/Emulation/scope.sh', '118s', '128s')
        entry = 'Literature_Review/CA1/Emulation/scope_entry.py'
        self.replace(entry, 'timeout=115', 'timeout=125')
        self.replace(entry, '115-second inner ceiling', '125-second inner ceiling; hard outer limit is 130 seconds')
        for audit in ['Interop/verify_step1.py', 'Step2/audit.py', 'Comparison/audit.py']:
            self.replace('Literature_Review/CA1/Emulation/' + audit,
                         "['elapsed_seconds']<120", "['elapsed_seconds']<130")
        write_json(self.output / 'RESOURCE_PROFILE.json', {
            'emulation_hard_deadline_seconds': 130, 'outer_term_seconds': 129, 'kill_after_seconds': 1,
            'inner_shell_deadline_seconds': 128, 'inner_process_deadline_seconds': 125,
            'original_model_deadlines_unchanged': True, 'cpus': [0, 1],
            'cpu_quota_percent': 200, 'memory_max_bytes': 2**31, 'memory_swap_max_bytes': 0,
            'serialized': True, 'reason': 'Author authorized 130 seconds after retained Nix replication timeout.'})
        reference = self.model / 'reference_environment'
        write_json(reference / 'referenceComponents.json', config['reference_components'])
        setup = {'schema_version': 2, 'status': 'REPLICATION_ENVIRONMENT_PINNED', 'route': config['route'],
                 'input_sha256': {name: sha(reference / name) for name in ['flake.nix', 'flake.lock',
                  'referenceComponents.json', 'referenceVersions.json', 'transitiveVersions.json']}}
        (reference / 'Setup_Status.toml').write_text('\n'.join(key + '=' + toml_value(value) for key, value in setup.items()) + '\n')
        write_json(self.emu / 'Components.json', config['tool_components'])
        write_json(self.emu / 'Interop/Components.json', config['interop_components'])
        packages = {p.name: str(p.absolute()) for p in (ROOT / 'replication/vendor/julia').iterdir() if p.is_dir()}
        write_json(self.emu / 'Interop/JuliaSources.json', packages)
        for folder in ['Packages', 'gc_roots']:
            target = self.emu / 'Interop' / folder
            target.mkdir()
            for name, path in packages.items():
                (target / name).symlink_to(path, target_is_directory=True)
        # Command aliases make shell scripts use the configured interpreters, not host wrappers.
        tools = self.output / 'tools/bin'
        tools.mkdir(parents=True)
        for name, executable in [('julia', config['julia']), ('python3', config['python']), ('python3.11', config['python'])]:
            launcher = tools / name
            launcher.write_text('#!/bin/sh\nexec ' + shlex.quote(executable) + ' "$@"\n')
            launcher.chmod(0o755)
        self.rebind_seal('Literature_Review/CA1/Emulation/Environment_Manifest.sha256')
        self.rebind_seal('Literature_Review/CA1/Emulation/Interop/Environment_Manifest.sha256')
        self.rebind_seal('Literature_Review/CA1/Emulation/Step2/Validated_Source_Manifest.sha256')
        self.kernel_check()
        write_json(self.output / 'INPUTS.json', {'original_export_sha256': sha(ROOT / 'EXPORT.json'),
            'configuration_sha256': sha(self.output / 'environment.json'),
            'scientific_kernels': {name: sha(self.tree / name) for name in KERNELS},
            'public_historical_manifest_sha256': public_hash,
            'original_artifacts_are_read_only': True, 'original_attempts_reused': False,
            'route': config['route'], 'private_course_context_required': False,
            'isolation_launcher_sha256': sha(self.emu / 'Interop/replication_isolate.sh')})
