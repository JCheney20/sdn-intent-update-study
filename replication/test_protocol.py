"""Small stdlib regression checks for the replication boundary, not the science."""
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import tomllib
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parent))
from workspace import ROOT, Workspace, toml_value
from run import reference_semantics, Replication
from configure import python_env


class ProtocolTests(unittest.TestCase):
    def test_native_library_paths_are_explicit(self):
        env = python_env({'python_sites': [], 'library_paths': ['/opt/zlib/lib', '/opt/cxx/lib']})
        self.assertEqual(env['LD_LIBRARY_PATH'], '/opt/zlib/lib:/opt/cxx/lib')
        self.assertNotIn('LD_LIBRARY_PATH', python_env({'python_sites': [], 'library_paths': []}))

    def test_toml_roundtrip(self):
        value = {'a/b': 'a path with "quotes"', 'count': 15, 'flag': True, 'list': ['a', 'b']}
        self.assertEqual(tomllib.loads('data=' + toml_value(value))['data'], value)

    def test_reference_comparison_excludes_only_clocks(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'trace.toml'
            value = {'cases': [{'plain_return': [0.1, 4, 0.2, 2, 0.3],
                                'instrumented_return': [0.2, 4, 0.3, 2, 0.4], 'choice': [1, 2]}]}
            path.write_text('trace=' + toml_value(value))
            clean = reference_semantics(path)
            self.assertEqual(clean['cases'][0]['plain_return'], [4, 2])
            self.assertEqual(clean['cases'][0]['choice'], [1, 2])

    def test_workspace_is_fresh_and_kernels_are_checked(self):
        original = ROOT / 'artifacts/Literature_Review/CA1'
        config = {'route': 'unit-test', 'python_sites': [], 'library_paths': [],
                  'python': '/runtime/bin/python3.11', 'python_lib': '/runtime/lib/libpython3.11.so',
                  'julia': '/runtime/bin/julia',
                  'reference_components': {'interpreter': '/runtime/bin/python3.11', 'paths': [], 'sitePackages': ''},
                  'tool_components': json.loads((original / 'Emulation/Components.json').read_text()),
                  'interop_components': json.loads((original / 'Emulation/Interop/Components.json').read_text())}
        with tempfile.TemporaryDirectory() as directory:
            w = Workspace(Path(directory) / 'new')
            w.prepare(config)
            process = Replication(w.output, config)
            self.assertIn('rw\t' + str(w.output), process.env['SDN_REPLICATION_TMP_BINDS'])
            self.assertEqual((w.emu / 'Interop/sandbox.sh').read_bytes(), (original / 'Emulation/Interop/sandbox.sh').read_bytes())
            self.assertIn('replication_isolate.sh', (w.emu / 'Interop/run.sh').read_text())
            self.assertFalse((w.model / 'study/attempts').exists())
            self.assertFalse((w.emu / 'Comparison/Manifest.json').exists())
            fresh = Path(directory) / 'fresh-trace.toml'
            fixture = w.model / 'reference_capture/runs/cos738-reference-capture-1792956866366487215/trace.toml'
            fresh.write_text(fixture.read_text() + '\n# fresh capture provenance\n')
            w.bind_reference_trace(fresh)
            from workspace import sha
            self.assertEqual(tomllib.loads((w.model / 'validation/Controller_Inputs.toml').read_text())['reference_trace_sha256'], sha(fixture))
            w.kernel_check()
            self.assertEqual(json.loads((w.output / 'RESOURCE_PROFILE.json').read_text())['emulation_hard_deadline_seconds'], 130)
            self.assertIn('129s', (w.emu / 'scope.sh').read_text())
            self.assertIn('128s', (w.emu / 'scope.sh').read_text())
            self.assertIn('timeout=125', (w.emu / 'scope_entry.py').read_text())
            audit = w.emu / 'Comparison/audit.py'
            content = audit.read_bytes()
            audit.write_bytes(content + b'\n# unauthorized non-resource modification\n')
            with self.assertRaises(AssertionError):
                w.kernel_check()
            audit.write_bytes(content)
            w.kernel_check()
            self.assertNotIn('external_context_snapshots', (w.tree / 'SDN_Model_Comparison/Delivery_Manifest.json').read_text())
            with self.assertRaises(AssertionError):
                w.prepare(config)
            kernel = w.model / 'handover.jl'
            kernel.write_text(kernel.read_text() + '\n# injected regression\n')
            with self.assertRaises(AssertionError):
                w.kernel_check()

    def test_unapproved_scope_cannot_execute_command(self):
        with tempfile.TemporaryDirectory() as directory:
            marker = Path(directory) / 'executed'
            result = subprocess.run([sys.executable, '-I', '-B', str(ROOT / 'replication/bounded.py'),
                                     str(Path(directory) / 'receipt.json'), sys.executable, '-c',
                                     f'from pathlib import Path;Path({str(marker)!r}).touch()'], capture_output=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertFalse(marker.exists())

if __name__ == '__main__':
    unittest.main()
