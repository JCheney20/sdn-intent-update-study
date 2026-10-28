# Frozen Cisco emulation results

PASS: independent audit 3707 checks; 30 episodes / 45 primary packets.

| Cell | New PASS | Old PASS / wrong | Admission wait ms | New service age ms | Completion ms | Nonwait ms | Bundles |
|---|---:|---:|---:|---:|---:|---:|---:|
| ordinary-nominal | 5/5 | 0 / 0 | 9.311 | 261.540 | 18.308 | 18.308 | 2 |
| Q-nominal | 5/5 | 0 / 0 | 1044.456 | 1296.128 | 1044.651 | 43.614 | 4 |
| V-nominal | 5/5 | 0 / 0 | 43.483 | 294.636 | 1081.600 | 80.562 | 9 |
| V-inflight | 5/5 | 5 / 0 | 46.881 | 298.798 | 1087.716 | 86.670 | 9 |
| Q-inflight | 5/5 | 5 / 0 | 1042.612 | 1294.880 | 1042.753 | 41.714 | 4 |
| ordinary-inflight | 5/5 | 0 / 5 | 9.247 | 262.038 | 18.150 | 18.150 | 2 |

Times are cell medians of five warmed updates, not population bounds or a pure-language comparison. Intentional fixed one-second waits are included in completion and excluded from nonwait wall time. Application receive deadlines are finite. Userspace OVS/transparent 250 ms wire/one old and one new request only; no hardware, congestion, arbitrary faults or universal real-time guarantee. Warmup/validation are excluded from primary rows.

Startup/warm-up and resource receipts are retained separately in Results.json.
