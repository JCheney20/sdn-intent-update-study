"""Launch the locked Nix Python/components inside an already bounded job.

No Nix builder, pip, venv or source compilation is involved. The NIX_PYTHONPATH
mechanism is the one supplied by Nixpkgs' own Python sitecustomize module.
"""
import hashlib
import json
import os
from pathlib import Path
import sys
import tomllib

here = Path(__file__).resolve().parent
status = tomllib.loads((here / "Setup_Status.toml").read_text())
for name, expected in status["input_sha256"].items():
    if hashlib.sha256((here / name).read_bytes()).hexdigest() != expected:
        raise SystemExit(f"Frozen reference input changed: {name}")

cg = next(line.split("::", 1)[1] for line in Path("/proc/self/cgroup").read_text().splitlines() if line.startswith("0::"))
if "cos738-" not in cg:
    raise SystemExit("Reference execution requires the bounded COS738 runner")
base = Path("/sys/fs/cgroup") / cg.lstrip("/")
if int((base / "memory.max").read_text()) > 2**31 or int((base / "memory.swap.max").read_text()) != 0:
    raise SystemExit("Reference memory/swap limits missing")
quota, period = map(int, (base / "cpu.max").read_text().split())
if quota > 2 * period or not os.sched_getaffinity(0) <= {0, 1}:
    raise SystemExit("Reference CPU quota/affinity limits missing")

components = json.loads((here / "referenceComponents.json").read_text())
for path in components["paths"]:
    if not Path(path).is_dir():
        raise SystemExit(f"Cached component is not realized: {path}")
interpreter = components["interpreter"]
env = {k: v for k, v in os.environ.items() if not k.startswith("PYTHON")}
env.update({
    "NIX_PYTHONPATH": ":".join(str(Path(p) / components["sitePackages"]) for p in components["paths"]),
    "NIX_PYTHONEXECUTABLE": interpreter,
    "NIX_PYTHONPREFIX": str(Path(interpreter).parent.parent),
    "PYTHONNOUSERSITE": "1", "PYTHONHASHSEED": "0",
    "OPENBLAS_NUM_THREADS": "1", "OMP_NUM_THREADS": "1", "MKL_NUM_THREADS": "1",
    "MPLBACKEND": "Agg", "MPLCONFIGDIR": str(here / "runtime_cache/matplotlib"),
    "XDG_CACHE_HOME": str(here / "runtime_cache"),
})
# -I would ignore PYTHONHASHSEED. Use a scrubbed environment, -s and safe-path -P
# instead, so reference hash order is fixed without adding cwd/user packages.
os.execve(interpreter, [interpreter, "-s", "-P", "-B", *sys.argv[1:]], env)
