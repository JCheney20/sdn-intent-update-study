"""Observe the byte-identical Spotlight helper; never replace its algorithm."""
import ast
import contextlib
import hashlib
import importlib.util
import io
import json
import logging
import math
import os
from pathlib import Path
import struct
import sys
import tomllib
import warnings

import numpy as np
import networkx as nx
import networkx.algorithms.similarity as similarity
import networkx.algorithms.shortest_paths.unweighted as unweighted

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
OUT = Path(sys.argv[1]).resolve()
plan = tomllib.loads((HERE / "Capture_Plan.toml").read_text())
sha = lambda p: hashlib.sha256(Path(p).read_bytes()).hexdigest()
for name, expected in plan["source_sha256"].items():
    assert sha(HERE / name) == expected, name
assert sha(similarity.__file__) == "639191975356f88155ab0a2039d1c9b3e4801e6a6fd5281f37b30817bcbca1d4"
assert sha(unweighted.__file__) == "12e89988711010eac5669994326e764e100d8f27d679684a60522b9efbbd1bfb"
assert not os.environ.get("NETWORKX_AUTOMATIC_BACKENDS"), "undeclared NetworkX backend"
sys.path.insert(0, str(HERE / "sources"))
spec = importlib.util.spec_from_file_location("spotlight_reference", HERE / "sources/detector.py")
d = importlib.util.module_from_spec(spec)
spec.loader.exec_module(d)

# Verify the known CLI/helper distinction without executing CLI/CSV output.
cli_calls = [n for n in ast.walk(ast.parse((HERE / "sources/detector.py").read_text()))
             if isinstance(n, ast.Call) and isinstance(n.func, ast.Name) and n.func.id == "cisco_trial"]
assert any(any(k.arg == "panther_k" and isinstance(k.value, ast.Constant) and k.value.value == 20
                   for k in n.keywords) for n in cli_calls)

bits = lambda x: struct.pack(">d", float(x)).hex()
def state():
    algorithm, keys, pos, gauss, cached = np.random.get_state()
    return {"algorithm": algorithm, "keys": keys.tolist(), "position": pos,
            "has_gauss": gauss, "cached_gaussian_bits": bits(cached)}

def graph(g):
    return {"nodes": list(g), "adjacency": [list(g[n]) for n in g],
            "directed": g.is_directed(), "edges": [list(e) for e in g.edges]}

def rules(switches):
    return {s.mac: {key: [[f.ingress.mac, f.egress.mac, str(f.source_match), str(f.dest_match)]
                         for f in getattr(s, attr)]
                   for key, attr in [("initial", "init_flowrules"), ("removed", "new_flowrules_rm"), ("added", "new_flowrules_add")]}
            for s in switches}

class Observer:
    def __init__(self):
        self.queries = []
        self.subsets = []
        self.pairs = []
        self.packet_matches = []
        self.current = None
        self.subset = None
        self.pair = None
        self.direction = None
        self.saved = []

    def patch(self, obj, name, wrapper):
        original = getattr(obj, name)
        self.saved.append((obj, name, original))
        setattr(obj, name, wrapper(original))

    def __enter__(self):
        def query(original):
            def call(g, source, **kwargs):
                assert self.current is None
                q = {"source": str(source), "requested_k": kwargs.get("k", 5),
                     "path_length": kwargs.get("path_length", 5), "weight": str(kwargs.get("weight", "weight")),
                     "rng_before": state(), "walks": [], "argpartition_calls": [], "argsort_calls": []}
                self.current = q
                try:
                    result = original(g, source, **kwargs)
                    q["cache_order"] = [str(n) for n in result]
                    q["cache_score_bits"] = [bits(v) for v in result.values()]
                    q["rng_after"] = state()
                    self.queries.append(q)
                    return result
                finally:
                    self.current = None
            return call
        def paths(original):
            def call(g, sample_size, **kwargs):
                q = self.current
                assert q is not None
                q["sample_count"] = int(sample_size)
                q["generator_path_length"] = kwargs["path_length"]
                for path in original(g, sample_size, **kwargs):
                    q["walks"].append([str(n) for n in path])
                    yield path  # original list, not a substituted or reordered path
                index = kwargs["index_map"]
                q["index_order"] = [str(n) for n in index]
                q["memberships"] = {str(n): sorted(int(i) for i in ids) for n, ids in index.items()}
            return call
        def partition(original):
            def call(a, kth, *args, **kwargs):
                result = original(a, kth, *args, **kwargs)
                if self.current is not None:
                    self.current["argpartition_calls"].append({"scores_bits": [bits(v) for v in a],
                        "kth": int(kth), "indices": result.tolist()})
                return result
            return call
        def argsort(original):
            def call(a, *args, **kwargs):
                result = original(a, *args, **kwargs)
                if self.current is not None:
                    self.current["argsort_calls"].append({"scores_bits": [bits(v) for v in a], "indices": result.tolist()})
                return result
            return call
        def subsets(original):
            def call(switches):
                for subset in original(switches):
                    self.subset = [s.mac for s in subset]
                    self.subsets.append(self.subset)
                    yield subset
            return call
        def pairs(original):
            def call(hosts):
                for a, b in original(hosts):
                    p = {"subset": self.subset, "source": a.mac, "destination": b.mac, "directions": []}
                    self.pair = p
                    self.pairs.append(p)
                    yield a, b
            return call
        def connected(original):
            def call(*args, **kwargs):
                result = original(*args, **kwargs)
                if self.direction is not None:
                    self.direction["lookup_paths"].append(list(result.path))
                return result
            return call
        def detect(original):
            def call(a, b, *args, **kwargs):
                record = {"source": a.mac, "destination": b.mac, "lookup_paths": []}
                self.direction = record
                try:
                    result = original(a, b, *args, **kwargs)
                    record.update(expectation=result.expectation.name, status=result.status.name, path=list(result.path))
                    self.pair["directions"].append(record)
                    return result
                finally:
                    self.direction = None
            return call
        def match(original):
            def call(conn, devices):
                result = original(conn, devices)
                self.packet_matches.append({"subset": [s.mac for s in conn.updated_switches],
                    "source": conn.source.mac, "destination": conn.dest.mac, "path": list(conn.path), "matches": result})
                return result
            return call
        for obj, name, wrapper in [(d, "panther_similarity", query), (similarity, "generate_random_paths", paths),
            (np, "argpartition", partition), (np, "argsort", argsort), (d, "unique_subsets", subsets),
            (d, "generate_host_pairs", pairs), (d, "is_connected", connected),
            (d, "detect_extra_connectivity_of_pair", detect), (d, "do_packets_match", match)]:
            self.patch(obj, name, wrapper)
        return self

    def __exit__(self, *_):
        for obj, name, original in reversed(self.saved):
            setattr(obj, name, original)


def invoke(fn):
    stream = io.StringIO()
    handler = logging.StreamHandler(stream)
    handler.setFormatter(logging.Formatter("%(levelname)s:%(message)s"))
    old_handlers, old_level = d.logger.handlers[:], d.logger.level
    d.logger.handlers = [handler]
    d.logger.setLevel(logging.WARNING)
    old_propagate = d.logger.propagate
    d.logger.propagate = False
    try:
        with warnings.catch_warnings(record=True) as caught:
            warnings.simplefilter("always")
            result = fn()
        return result, stream.getvalue(), [str(w.message) for w in caught]
    finally:
        d.logger.handlers, d.logger.level, d.logger.propagate = old_handlers, old_level, old_propagate


def capture_case(kind, k, noop=False):
    hosts, switches, devices, physical = d.prep_trial_cisco() if kind == "cisco" else d.prep_trial(4)
    if noop:
        for s in switches:
            s.new_flowrules_add.clear()
            s.new_flowrules_rm.clear()
    original_rules = rules(switches)
    initial = d.build_initial_topology(switches, hosts)
    final = d.build_final_topology(initial, tuple(switches))
    call = lambda: d.detection(physical, hosts, switches, devices, not noop, panther_k=k, path_length=4)
    np.random.seed(plan["seed"])
    start = state()
    d.shortest_path_memoize.cache_clear()
    plain, plain_log, plain_warnings = invoke(call)
    plain_state = state()
    np.random.seed(plan["seed"])
    assert state() == start
    d.shortest_path_memoize.cache_clear()
    with Observer() as observer:
        observed, log, observed_warnings = invoke(call)
    assert plain[1] == observed[1] and plain[3] == observed[3], "observability normal result mismatch"
    assert plain_log == log and plain_warnings == observed_warnings, "observability log/warning mismatch"
    assert plain_state == state(), "observability RNG mismatch"
    assert rules(switches) == original_rules, "reference mutated input rules"
    assert len(observer.queries) == (0 if noop else len(switches))
    return {"fixture": kind, "k": k, "noop": noop, "seed": plan["seed"], "physical": graph(physical),
        "hosts": [h.mac for h in hosts], "switches": [s.mac for s in switches], "rules": original_rules,
        "initial_graph": graph(initial), "final_graph": graph(final), "initial_rng": start, "final_rng": plain_state,
        "plain_return": list(plain), "instrumented_return": list(observed), "normal_log": plain_log,
        "states_checked": plain[1], "violations_found": plain[3], "observability_passed": True,
        "queries": observer.queries, "subsets": observer.subsets, "pairs": observer.pairs,
        "packet_matches": observer.packet_matches}


def small_controls():
    result = []
    for k, reverse in [(1, False), (4, False), (5, False), (4, True)]:
        names = [f"P-{i}" for i in range(4)]
        g = nx.Graph()
        g.add_nodes_from(names[::-1] if reverse else names)
        edges = list(zip(names, names[1:]))
        g.add_edges_from(edges[::-1] if reverse else edges)
        call = lambda: d.panther_similarity(g, "P-0", k=k, path_length=4, weight=None)
        np.random.seed(plan["seed"])
        plain, log, warn = invoke(call)
        end = state()
        np.random.seed(plan["seed"])
        with Observer() as observer:
            observed, log2, warn2 = invoke(call)
        assert list(plain.items()) == list(observed.items()) and end == state() and log == log2 and warn == warn2
        result.append({"k": k, "reverse_order": reverse, "physical": graph(g), "warnings": warn,
                       "queries": observer.queries, "observability_passed": True})
    prefix = d.FlowRule(d.Action.INIT, d.Host("source", d.IPv4Address("10.0.0.0")), d.Switch("dest"),
                        d.IPv4Network("10.0.0.0/8"), d.IPv4Network("10.0.0.0/8"))
    matches = [prefix.packet_match(d.IPv4Address(a), d.IPv4Address(b)) for a, b in
               [("10.0.0.0", "10.0.0.0"), ("11.0.0.0", "10.0.0.0"), ("10.0.0.0", "11.0.0.0")]]
    assert matches == [True, False, False]
    zero = np.zeros(5)
    indices = np.argpartition(zero, -3)[-3:]
    ranking = indices[np.argsort(zero[indices])][::-1]
    return {"cache_boundaries": result, "prefix_matches": matches, "all_zero_top3": ranking.tolist()}


def toml_value(value):
    if isinstance(value, bool):
        return str(value).lower()
    if isinstance(value, str):
        return json.dumps(value)
    if isinstance(value, (int, float)):
        assert not isinstance(value, float) or math.isfinite(value)
        return repr(value)
    if isinstance(value, (list, tuple)):
        return "[" + ",".join(toml_value(v) for v in value) + "]"
    if isinstance(value, dict):
        return "{" + ",".join(json.dumps(k) + "=" + toml_value(v) for k, v in value.items()) + "}"
    raise TypeError(type(value))

receipt = {"status": "RUNNING", "artifact_executed": True, "primary_data": False}
try:
    cases = [capture_case(kind, k) for kind in plan["topologies"] for k in plan["cache_k"]]
    cases.append(capture_case("cisco", 3, noop=True))
    trace = {"schema_version": 1, "seed": plan["seed"], "cases": cases, "controls": small_controls(),
             "source_sha256": plan["source_sha256"], "source_cli_cisco_k_hardcoded_20": True}
    text = "trace=" + toml_value(trace) + "\n"
    assert tomllib.loads(text)["trace"] == trace, "TOML trace round-trip changed data"
    (OUT / "trace.toml").write_text(text)
    (OUT / "trace.json").write_text(json.dumps(trace, indent=2) + "\n")
    receipt.update(status="PASS", observability_passed=True, cases=len(cases),
                   queries=sum(len(c["queries"]) for c in cases), trace_sha256=sha(OUT / "trace.toml"),
                   plain_timing_fields_excluded_from_equality=True, replay_validated=False)
    print("CAPTURE PASS", receipt["cases"], "detector cases", receipt["queries"], "main queries")
except BaseException as error:
    receipt.update(status="FAIL", error=repr(error))
    raise
finally:
    (OUT / "capture_receipt.json").write_text(json.dumps(receipt, indent=2) + "\n")
