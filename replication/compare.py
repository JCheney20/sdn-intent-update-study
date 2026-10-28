"""Compare deterministic scientific outcomes; never require identical timings."""
import csv
import hashlib
import json
import math
from pathlib import Path
import sys
import tomllib

sys.path.insert(0, str(Path(__file__).resolve().parent))
from workspace import ROOT, Workspace, sha, write_json


def read_csv(path):
    with Path(path).open(newline='') as stream:
        return list(csv.DictReader(stream))


def sensitivities(study):
    rows = {}
    for folder in (study / 'runs').iterdir():
        result = folder / 'result.toml'
        if not result.is_file():
            continue
        data = tomllib.loads(result.read_text())['data']
        if data['mode'] != 'sensitivity':
            continue
        assert data['status'] == 'PASS'
        for row in data['rows']:
            key = (data['implementation'], row['fixture'], row['configuration'], row['seed'])
            fields = ['cache', 'cache_sha256', 'rng_final_sha256', 'alert', 'alarms', 'pair_checks', 'sample_paths_per_query']
            assert key not in rows
            rows[key] = {name: row[name] for name in fields}
    assert len(rows) == 576
    return rows


def compare(output):
    w = Workspace(output)
    w.kernel_check()
    original = ROOT / 'artifacts/Literature_Review/CA1'
    study = w.model / 'study'
    baseline = original / 'Revision_Protocol/study'
    current = read_csv(study / 'Primary_Results.csv')
    expected = read_csv(baseline / 'Primary_Results.csv')
    def nonclock(rows):
        return [{key: value for key, value in row.items() if key != 'decision_seconds'} for row in rows]
    assert len(current) == 92 and nonclock(current) == nonclock(expected), 'Primary scientific comparison differs'
    assert sensitivities(study) == sensitivities(baseline), 'Sensitivity choices/results differ'
    assert tomllib.loads((study / 'Sensitivity_Results.toml').read_text()) == tomllib.loads((baseline / 'Sensitivity_Results.toml').read_text())
    assert tomllib.loads((study / 'Coverage_Results.toml').read_text())['summary'] == tomllib.loads((baseline / 'Coverage_Results.toml').read_text())['summary']
    catalogue = tomllib.loads((study / 'Catalogue.toml').read_text())['plans']
    assert set(catalogue) == set(tomllib.loads((baseline / 'Catalogue.toml').read_text())['plans'])
    benchmarks = tomllib.loads((study / 'Benchmark_Results.toml').read_text())['conditions']
    assert len(benchmarks) == 16 and all(math.isfinite(row['inner_search_median_seconds']) and row['inner_search_median_seconds'] >= 0 for row in benchmarks)
    audit = tomllib.loads((study / 'Artifact_Verification.toml').read_text())
    assert audit['status'] == 'PASS' and audit['primary_cells'] == 12 and audit['primary_rows'] == 92
    validation = json.loads((w.output / 'VALIDATION.json').read_text())
    checks = {}
    for kind, expected_count in [('cisco', 227590), ('fat4', 601999)]:
        mode = 'controllers-' + kind
        receipt = tomllib.loads((Path(validation['jobs'][mode]) / 'receipt.toml').read_text())
        assert receipt['status'] == 'PASS' and receipt['controllers']['checks'] == expected_count
        checks[kind] = receipt['controllers']['checks']
    replay = tomllib.loads((Path(validation['replay']) / 'replay_receipt.toml').read_text())
    assert replay['status'] == 'PASS' and replay['checks'] == 44800
    emulation = json.loads((w.emu / 'Comparison/Results.json').read_text())
    emulation_base = json.loads((original / 'Emulation/Comparison/Results.json').read_text())
    fields = ['cell', 'episodes', 'new_pass', 'old_pass', 'old_wrong', 'unobserved', 'late', 'duplicates', 'bundles', 'extra_rows', 'peak_switch_flows']
    assert emulation['status'] == 'PASS'
    assert [{k: row[k] for k in fields} for row in emulation['cells']] == [{k: row[k] for k in fields} for row in emulation_base['cells']]
    assert (emulation['primary_episodes'], emulation['primary_packets']) == (30, 45)
    assert json.loads((w.output / 'EMULATION.json').read_text())['duplicate_refused']
    report = {'status': 'PASS', 'route': json.loads((w.output / 'environment.json').read_text())['route'],
              'scientific_kernels_byte_identical': True, 'controller_checks': checks,
              'reference_replay_checks': replay['checks'], 'fresh_controller_catalogue_entries': len(catalogue),
              'primary_model_rows_equal_excluding_timing': len(current), 'sensitivity_records_equal': 576,
              'baseline_event_coverage_equal': True, 'benchmark_jobs': 48, 'benchmark_timings_required_equal': False,
              'emulation_cells_equal_excluding_timing': 6, 'primary_episodes': 30, 'primary_packets': 45,
              'new_source_manifest_sha256': sha(study / 'Manifest.toml'),
              'new_emulation_manifest_sha256': sha(w.emu / 'Comparison/Manifest.json'),
              'scope': 'Fresh serialized bounded jobs from this checkout on the recorded host, not a clean operating-system or hardware certification.'}
    write_json(w.output / 'COMPARISON.json', report)
    ignore = {'depot', 'runtime_cache', '__pycache__', 'gc_roots', 'Packages'}
    files = sorted(path for path in (w.output / 'work').rglob('*')
                   if path.is_file() and not path.is_symlink() and not any(part in ignore for part in path.relative_to(w.output).parts))
    (w.output / 'REPLICATION_OUTPUTS.sha256').write_text(''.join(f'{sha(path)}  {path.relative_to(w.output)}\n' for path in files))
    print(json.dumps(report, indent=2))

if __name__ == '__main__':
    compare(sys.argv[1])
