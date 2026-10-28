# Stopped before prospective freeze: audit launcher import

The author approved the verified Julia-side vector workaround and continuing remaining gates while no further errors/corrections occur. The correction was applied only to Step3/Wire.jl: retain the Python list, `collect(PyList{Py}(raw))`, then `only(links)`.

## Passed

- The first failed timing attempt's original 70-file manifest and all referenced files were mirrored under `Step3/history/attempt1/Emulation/Step3/`, preserving the original manifest bytes and relative paths. SHA-256 remains `4c37ab00cfab325a72909e0a1524edebcaed58ac187168523b4c390ea0622b10`. `Step3/Previous_Attempt_Archive.json` records the relocation. The original run directory also remains unchanged.
- Corrected integration: `cos738-ovs-wire-timing-vector-1793079788777892588`, exit zero, 79 runtime checks; three strict H5 old frames and three H6 new/tagged frames plus one sacrificial warm frame. All correct hosts/versions. Observed wire residence about 250.128–250.868 ms. 29 expanded veth edges/unchanged 28-edge logical Cisco graph and ofports checked; all normal cleanup flags true. Whole job 74.917922 s, checkpoint peak 650,756,096 B, original two-CPU/2 GiB/zero-swap envelope.
- Prospective comparison source authored under this directory: fixed candidate 30 episodes, separate warm-up, one validation-envelope job before primary, source/attempt guard, controller/harness separation, independent analyzer. **Not frozen or scientifically executed.**
- Julia parse check `1793080949721779726`, shell/Python syntax and independent byte/flow parser positive/corruption checks `1793080950244468841` passed.

## New stop condition

Standalone independent timing audit `cos738-ovs-comparison-timing-audit-1793080951116435196` failed before audit execution:

```text
from guard import HERE, CA1, check as check_freeze, sha
ModuleNotFoundError: No module named 'guard'
```

Command used the deliberate `python3 -I -B` isolation flags. Isolated mode excludes the script directory from module search. The parser self-check explicitly inserts its absolute source directory before importing `audit`; that invocation succeeded. The standalone audit entry point currently does not do so.

This is a local audit-module discovery error, not an observed relay/packet/model disagreement. The full independent timing audit has **not** passed. A likely minimal correction is to insert the absolute `Path(__file__).resolve().parent` into `sys.path` before importing `guard`, retaining `-I` and avoiding dependence on the caller's working directory. No correction/retry of this error has been applied.

Failed audit source copies were retained in its run's `sources/Comparison/`; traceback, exit and resource receipt remain. The failed metadata job took 0.186755 s with checkpoint peak 28,381,184 B and performed no network setup. No active COS738 scope remains.

`Manifest.json` and the comparison attempt directory do not exist: no scientific freeze, consumed primary attempt, validation-envelope run or primary episode occurred. The prior Step-2 773-file seal and archived first timing-attempt seal were checked unchanged. The manuscript has not been modified.

Awaiting review of this new correction before completing the independent timing audit, source freeze, validation-envelope job, six primary cells, final independent analysis and manuscript integration for author review.
