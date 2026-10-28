"""One child process inside a verified replication scope; never an unbounded fallback."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import time

scope = next(line.split('::', 1)[1] for line in Path('/proc/self/cgroup').read_text().splitlines() if line.startswith('0::'))
assert 'cos738-study-replication-' in scope or 'cos738-ovs-replication-' in scope
cgroup = Path('/sys/fs/cgroup') / scope.lstrip('/')
read = lambda name: (cgroup / name).read_text().strip()
quota, period = map(int, read('cpu.max').split())
assert int(read('memory.max')) == 2**31 and int(read('memory.swap.max')) == 0
assert 0 < quota <= 2 * period and set(os.sched_getaffinity(0)) <= {0, 1}
output, command = Path(sys.argv[1]), sys.argv[2:]
assert command
receipt = {'command': command, 'scope': scope, 'affinity': sorted(os.sched_getaffinity(0)),
           'memory_max_bytes': int(read('memory.max')), 'swap_max_bytes': int(read('memory.swap.max')),
           'cpu_max': read('cpu.max'), 'entry_sha256': hashlib.sha256(Path(__file__).read_bytes()).hexdigest()}
start = time.monotonic()
code = 1
try:
    code = subprocess.run(command, check=False, timeout=115).returncode
except subprocess.TimeoutExpired:
    receipt['error'] = '115-second inner deadline exceeded'
    code = 124
finally:
    receipt.update(exit_code=code, elapsed_seconds=time.monotonic() - start,
                   memory_peak_at_checkpoint_bytes=int(read('memory.peak')))
    output.write_text(json.dumps(receipt, indent=2) + '\n')
sys.exit(code if code >= 0 else 128 - code)
