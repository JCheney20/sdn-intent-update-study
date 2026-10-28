"""Read-only integrity/accounting checks. Python 3.11+, standard library only."""
import csv
import hashlib
import json
from pathlib import Path
import tomllib

ROOT = Path(__file__).resolve().parent
ARTIFACTS = ROOT / 'artifacts'
CA1 = ARTIFACTS / 'Literature_Review/CA1'
MODEL = CA1 / 'Revision_Protocol'
EMU = CA1 / 'Emulation/Comparison'

def digest(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()

def checked(base, name, expected):
    path = (base / name).resolve()
    assert path.is_relative_to(ARTIFACTS), f'Path escapes artifact tree: {name}'
    assert path.is_file() and not (base / name).is_symlink(), name
    assert digest(path) == expected, f'Checksum mismatch: {name}'

def seal(base, count, expected):
    manifest = base / 'Output_Manifest.sha256'
    assert digest(manifest) == expected, str(manifest)
    lines = manifest.read_text().splitlines()
    assert len(lines) == count
    for line in lines:
        sha, name = line.split('  ', 1)
        checked(base, name, sha)

assert digest(MODEL / 'study/Manifest.toml') == '7ca19f71f0d88d709e4e415e9b4b28e4ba013fd3d73d45f066ddbc1aff6a915e'
model = tomllib.loads((MODEL / 'study/Manifest.toml').read_text())
for name, expected in model['source_sha256'].items():
    checked(MODEL, name, expected)
assert digest(EMU / 'Manifest.json') == '906476a7eae8e12d97737c3715f5d7b38f39a7ce284f37d937f05d6b1456ee1b'
emu = json.loads((EMU / 'Manifest.json').read_text())
for name, expected in emu['sources'].items():
    checked(CA1, name, expected)
seal(MODEL / 'study', 628, '6fce85fb4d814da41aad396c3a27c0ee889a97e8d3e514ebcd3a38e14327d9c5')
seal(EMU, 2041, 'a3985df2da943e066f8ee4484d36e91149cf6eeb529be4ab9919ca09de65017d')

release_paths = set()
for line in (ROOT / 'SHA256SUMS').read_text().splitlines():
    expected, name = line.split('  ', 1)
    path = ROOT / name
    assert path.resolve().is_relative_to(ROOT) and not path.is_symlink(), name
    assert digest(path) == expected and name not in release_paths, name
    release_paths.add(name)
actual_release = {str(path.relative_to(ROOT)) for path in ROOT.rglob('*')
                  if path.is_file() and '.git' not in path.relative_to(ROOT).parts
                  and path.name != 'SHA256SUMS'}
assert release_paths == actual_release, 'Unlisted/missing release files'

inventory = json.loads((ROOT / 'EXPORT.json').read_text())['files']
assert len(inventory) == len({row['path'] for row in inventory})
for row in inventory:
    checked(ROOT, row['path'], row['sha256'])
    assert (ROOT / row['path']).stat().st_size == row['bytes']
actual = {str(path.relative_to(ROOT)) for path in ARTIFACTS.rglob('*') if path.is_file()}
assert actual == {row['path'] for row in inventory}, 'Unlisted/missing artifact files'
assert not any(path.is_symlink() for path in ARTIFACTS.rglob('*'))

vendor = json.loads((ROOT / 'replication/VENDOR.json').read_text())
for name, expected in vendor['files'].items():
    path = ROOT / 'replication/vendor' / name
    assert path.resolve().is_relative_to(ROOT / 'replication/vendor') and not path.is_symlink()
    assert digest(path) == expected, 'Vendored dependency changed: ' + name
assert {str(p.relative_to(ROOT / 'replication/vendor')) for p in (ROOT / 'replication/vendor').rglob('*') if p.is_file()} == set(vendor['files'])

with (MODEL / 'study/Primary_Results.csv').open(newline='') as stream:
    primary = list(csv.DictReader(stream))
assert len(primary) == 92 and len(model['primary_cells']) == 12
report = tomllib.loads((MODEL / 'study/Artifact_Verification.toml').read_text())
assert report['status'] == 'PASS' and report['sensitivity_trials'] == 576 and report['benchmark_jobs'] == 48
result = json.loads((EMU / 'Results.json').read_text())
assert result['status'] == 'PASS' and len(result['cells']) == 6
assert result['primary_episodes'] == 30 and result['primary_packets'] == 45
assert sum(cell['episodes'] for cell in result['cells']) == 30
assert sum(cell['old_wrong'] for cell in result['cells']) == 5
assert all(cell['new_pass'] == 5 for cell in result['cells'])
assert all(cell['late'] == cell['unobserved'] == cell['duplicates'] == 0 for cell in result['cells'])
print(f'PASS: {len(inventory)} byte-preserved exported files; model 628-output seal; emulation 2041-output seal.')
print('PASS: frozen source inputs and recorded study accounting. No experiment or replication performed.')
print('LIMIT: private historical package/context and original machine environment are not reproduced; see REPRODUCIBILITY.md.')
