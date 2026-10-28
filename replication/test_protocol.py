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
from run import reference_semantics
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
        config = {'route': 'unit-test', 'python': '/runtime/bin/python3.11', 'python_lib': '/runtime/lib/libpython3.11.so',
                  'julia': '/runtime/bin/julia',
                  'reference_components': {'interpreter': '/runtime/bin/python3.11', 'paths': [], 'sitePackages': ''},
                  'tool_components': json.loads((original / 'Emulation/Components.json').read_text()),
                  'interop_components': json.loads((original / 'Emulation/Interop/Components.json').read_text())}
        with tempfile.TemporaryDirectory() as directory:
            w = Workspace(Path(directory) / 'new')
            w.prepare(config)
            self.assertFalse((w.model / 'study/attempts').exists())
            self.assertFalse((w.emu / 'Comparison/Manifest.json').exists())
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
