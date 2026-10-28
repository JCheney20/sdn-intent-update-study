"""Verify real Nix imports and save interpreter/native-library provenance."""
import contextlib
import hashlib
import importlib.metadata
import io
import json
import os
from pathlib import Path
import platform
import sys
import tomllib

import numpy
import networkx
import matplotlib
import matplotlib.pyplot

here = Path(__file__).resolve().parent
status = tomllib.loads((here / "Setup_Status.toml").read_text())
components = json.loads((here / "referenceComponents.json").read_text())
expected = json.loads((here / "referenceVersions.json").read_text())
assert platform.python_version() == expected.pop("python") == status["python_version"]
expected.update(json.loads((here / "transitiveVersions.json").read_text()))
actual = {name: importlib.metadata.version(name) for name in expected}
assert actual == expected, (actual, expected)
assert sys.executable == components["interpreter"]
assert os.environ["PYTHONHASHSEED"] == "0" and not sys.flags.ignore_environment
assert sys.flags.no_user_site and sys.flags.safe_path and sys.dont_write_bytecode
assert "" not in sys.path and os.getcwd() not in sys.path
allowed = {str(Path(p) / components["sitePackages"]) for p in components["paths"]}
assert all(p in allowed for p in sys.path if "site-packages" in p), sys.path
assert matplotlib.get_backend().lower() == "agg"
# Exercise the actual RNG/numeric/graph imports without running artifact code.
assert numpy.random.RandomState(7).randint(0, 100) == 47
assert networkx.shortest_path(networkx.path_graph(3), 0, 2) == [0, 1, 2]
config = io.StringIO()
with contextlib.redirect_stdout(config):
    numpy.show_config()
cg = next(x.split("::", 1)[1] for x in Path("/proc/self/cgroup").read_text().splitlines() if x.startswith("0::"))
cgroup = Path("/sys/fs/cgroup") / cg.lstrip("/")
report = {
    "scope": cg, "memory_max_bytes": int((cgroup / "memory.max").read_text()),
    "swap_max_bytes": int((cgroup / "memory.swap.max").read_text()),
    "cpu_max": (cgroup / "cpu.max").read_text().strip(),
    "cpu_affinity": sorted(os.sched_getaffinity(0)),
    "memory_peak_at_checkpoint_bytes": int((cgroup / "memory.peak").read_text()),
    "status": "PASS", "python_version": platform.python_version(),
    "python_executable": sys.executable, "python_sha256": hashlib.sha256(Path(sys.executable).read_bytes()).hexdigest(),
    "versions": actual, "component_count": len(components["paths"]),
    "components": components["paths"], "sys_path": sys.path,
    "module_files": {"numpy": numpy.__file__, "networkx": networkx.__file__, "matplotlib": matplotlib.__file__},
    "numpy_native_config": config.getvalue(), "platform": platform.platform(), "machine": platform.machine(),
    "hash_seed": 0, "matplotlib_backend": matplotlib.get_backend(),
    "source_compilation": False, "combined_withPackages_wrapper_built": False,
    "artifact_executed": False, "reference_observability_or_replay_validated": False,
}
(here / "realization/runtime_check.json").write_text(json.dumps(report, indent=2) + "\n")
print(f"PASS: actual Python {platform.python_version()} imports and {len(actual)} package pins; Nix components={len(components['paths'])}")
