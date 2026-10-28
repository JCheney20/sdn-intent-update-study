"""Check evaluated Nix versions against the immutable artifact's requirement pins."""
import hashlib
import json
from pathlib import Path
import tomllib

here = Path(__file__).resolve().parent
status = tomllib.loads((here / "Setup_Status.toml").read_text())
for name, expected in status["input_sha256"].items():
    assert hashlib.sha256((here / name).read_bytes()).hexdigest() == expected, f"stale metadata: {name}"
source = here.parents[3] / "SDN_Model_Comparison/source_fidelity/sources/requirements.txt.txt"
pins = dict(line.strip().lower().split("==") for line in source.read_text().splitlines() if "==" in line)
versions = json.loads((here / "referenceVersions.json").read_text())
assert versions.pop("python") == status["python_version"], "interpreter build changed"
assert status["python_version"].startswith("3.11."), "reference requires Python 3.11"
versions.update(json.loads((here / "transitiveVersions.json").read_text()))
assert len(versions) == status["matched_direct_and_transitive_package_versions"]
components = json.loads((here / "referenceComponents.json").read_text())
assert components["tkinterVersion"] == status["python_version"]
for name, observed in versions.items():
    assert observed == pins[name], f"{name}: Nix {observed}, artifact {pins[name]}"
print(f"PASS: Python {status['python_version']} and {len(versions)} direct/transitive package pins match")
