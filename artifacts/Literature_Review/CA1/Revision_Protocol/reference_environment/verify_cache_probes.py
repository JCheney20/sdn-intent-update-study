"""Validate bounded HTTP probe evidence; does not install or build anything."""
import hashlib
import json
from pathlib import Path
import re
import tomllib
from urllib.parse import urlsplit

here = Path(__file__).resolve().parent
# These probes concern the retained original pin, not a later adopted revision.
snapshot = here / "revision_search/original-7f7306271be20e53f3d9bdc0aafc3a93be4314f5"
status = tomllib.loads((snapshot / "Setup_Status.toml").read_text())
for name, expected in status["input_sha256"].items():
    assert hashlib.sha256((snapshot / name).read_bytes()).hexdigest() == expected, name
root = here / "cache_probes"
paths = json.loads((root / "package_paths.json").read_text())
urls = (root / "configured_substituters.txt").read_text().split()
assert len(urls) == 6 and len(set(urls)) == 6
records = []
for base in urls:
    host = urlsplit(base).netloc
    assert urlsplit(base).scheme == "https" and urlsplit(base).path in ("", "/")
    directory = root if host == "cache.nixos.org" else root / host
    for name, path in paths.items():
        if name == "python" and host != "cache.nixos.org":
            continue
        match = re.fullmatch(r"/nix/store/([0-9a-z]{32})-[^/]+", path)
        assert match, path
        prefix = directory / name
        url = prefix.with_suffix(".url").read_text().strip()
        assert url == base.rstrip("/") + "/" + match[1] + ".narinfo", url
        http = int(prefix.with_suffix(".http-status").read_text())
        code = int(prefix.with_suffix(".exit-code").read_text())
        assert (http, code) in ((200, 0), (404, 22)), (url, http, code)
        if http == 200:
            text = prefix.with_suffix(".narinfo").read_text()
            assert "StorePath: " + path + "\n" in text
            assert "NarHash: sha256:" in text and "Sig:" in text
        records.append({"cache": host, "package": name, "http_status": http})
missing = [name for name in ("numpy", "networkx", "matplotlib", "reference")
           if not Path(paths[name]).exists()
           and all(r["http_status"] == 404 for r in records if r["package"] == name)]
assert len(records) == 25 and len(missing) == 4
print(json.dumps({
    "status": "BLOCKED_UNCACHED_OUTPUTS",
    "valid_requests": len(records),
    "advertised_python_output": paths["python"],
    "uncached_and_not_present_locally": missing,
    "scope": "current exact outputs and configured caches at probe time; not proof about all possible caches or revisions",
    "signature_verified_by_nix": False,
    "source_build_started": False,
    "invalid_initial_requests_excluded": True,
    "records": records,
}, indent=2))
