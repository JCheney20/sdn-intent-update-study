"""Read-only archive/member verification. Never extract or execute archived code."""
import hashlib
import json
from pathlib import Path
import sys
import tarfile

ROOT = Path(__file__).resolve().parent

def verify(directory):
    index = json.loads((ROOT / 'INDEX.json').read_text())
    for run in index['runs']:
        archive = Path(directory) / run['archive']
        with archive.open('rb') as stream:
            assert hashlib.file_digest(stream, 'sha256').hexdigest() == run['archive_sha256'], archive
        assert archive.stat().st_size == run['archive_bytes']
        expected = json.loads((ROOT / run['files']).read_text())
        seen = set()
        with tarfile.open(archive, 'r:gz') as tar:
            for member in tar:
                assert member.isfile(), 'Non-regular archive member'
                prefix = run['id'] + '/'
                assert member.name.startswith(prefix)
                name = member.name[len(prefix):]
                assert name in expected and name not in seen, name
                assert not Path(name).is_absolute() and '..' not in Path(name).parts
                assert member.size == expected[name]['bytes']
                with tar.extractfile(member) as stream:
                    assert hashlib.file_digest(stream, 'sha256').hexdigest() == expected[name]['sha256'], name
                seen.add(name)
        assert seen == set(expected) and len(seen) == run['file_count']
        print(f"PASS {run['id']}: {len(seen)} byte-preserved files; recorded status {run['status']}")
    print('Integrity only: no extraction, installation, experiment or scientific re-audit performed.')

if __name__ == '__main__':
    verify(sys.argv[1])
