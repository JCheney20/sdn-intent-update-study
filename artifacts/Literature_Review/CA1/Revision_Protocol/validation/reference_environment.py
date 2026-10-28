"""Metadata-only reference prerequisite inspection. No artifact/third-party imports."""
import hashlib
import importlib.metadata
import json
from pathlib import Path
import platform
import sys

requirements, output = map(Path, sys.argv[1:])
pins = {}
for line in requirements.read_text().splitlines():
    if line.strip() and not line.lstrip().startswith("#"):
        name, version = line.strip().split("==")
        pins[name.casefold()] = version

# These third-party packages are direct imports or the pinned RNG implementation.
required = ("numpy", "networkx", "matplotlib")
rows = []
for name in required:
    expected = pins[name]
    try:
        observed = importlib.metadata.version(name)
    except importlib.metadata.PackageNotFoundError:
        observed = "MISSING"
    rows.append((name, expected, observed))
python_ok = sys.version_info[:2] == (3, 11)
ready = python_ok and all(want == got for _, want, got in rows)
quote = json.dumps
lines = [
    'status = ' + quote("METADATA_READY_IMPORTS_NOT_TESTED" if ready else "BLOCKED_PREREQUISITES"),
    'python_executable = ' + quote(sys.executable),
    'python_version = ' + quote(platform.python_version()),
    'required_python_series = "3.11"',
    'python_series_matches = ' + str(python_ok).lower(),
    'requirements_sha256 = ' + quote(hashlib.sha256(requirements.read_bytes()).hexdigest()),
    'isolated_mode = ' + str(bool(sys.flags.isolated)).lower(),
    'artifact_executed = false',
    'third_party_imports_executed = false',
    'installation_or_network_attempted = false',
    'transitive_environment_validated = false',
]
for name, want, got in rows:
    lines += ['', '[[dependencies]]', 'name = ' + quote(name),
              'expected = ' + quote(want), 'observed = ' + quote(got),
              'matches = ' + str(want == got).lower()]
output.write_text("\n".join(lines) + "\n")
print("REFERENCE_ENVIRONMENT", "METADATA_READY_IMPORTS_NOT_TESTED" if ready else "BLOCKED_PREREQUISITES")
