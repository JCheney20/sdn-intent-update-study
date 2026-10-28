"""Resolve a pinned replication environment. No experiments or native builds."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
CA1 = ROOT / 'artifacts/Literature_Review/CA1'

def sha(path):
    with Path(path).open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()

def command(args, env=None):
    result = subprocess.run(args, env=env, capture_output=True, text=True, timeout=60)
    if result.returncode:
        raise RuntimeError(f'Environment command failed ({result.returncode}): {args}\n{result.stdout}\n{result.stderr}')
    return result.stdout.strip()

def python_env(config):
    env = {k: v for k, v in os.environ.items() if not k.startswith(('PYTHON', 'NIX_PYTHON')) and k != 'LD_LIBRARY_PATH'}
    env.update(PYTHONNOUSERSITE='1', PYTHONDONTWRITEBYTECODE='1', PYTHONHASHSEED='0', OPENBLAS_NUM_THREADS='1',
               OMP_NUM_THREADS='1', MKL_NUM_THREADS='1', MPLBACKEND='Agg')
    if config.get('cache_root'):
        env.update(XDG_CACHE_HOME=config['cache_root'], MPLCONFIGDIR=str(Path(config['cache_root']) / 'matplotlib'))
    if config.get('library_paths'):
        env['LD_LIBRARY_PATH'] = ':'.join(config['library_paths'])
    if config['python_sites']:
        env.update(NIX_PYTHONPATH=':'.join(config['python_sites']),
                   NIX_PYTHONEXECUTABLE=config['python'],
                   NIX_PYTHONPREFIX=str(Path(config['python']).parent.parent))
    return env

def configure(args):
    output = Path(args.output).absolute()
    if output.exists():
        raise SystemExit('Refusing to overwrite environment configuration: ' + str(output))
    config = {'schema': 1, 'route': args.route, 'python_sites': [], 'tool_components': {},
              'interop_components': {}, 'native_builds': False,
              'library_paths': [str(Path(p).absolute()) for p in args.library_path],
              'cache_root': str(output.parent / (output.stem + '-cache'))}
    if args.route == 'nix':
        def evaluate(folder, attribute):
            return json.loads(command(['nix', 'eval', '--no-write-lock-file', '--json', str(folder) + '#' + attribute]))
        ref = evaluate(CA1 / 'Revision_Protocol/reference_environment', 'referenceComponents.x86_64-linux')
        config['python'] = ref['interpreter']
        config['python_sites'] = [str(Path(p) / ref['sitePackages']) for p in ref['paths']]
        config['tool_components'] = evaluate(CA1 / 'Emulation', 'emulationComponents.x86_64-linux')
        config['interop_components'] = evaluate(CA1 / 'Emulation/Interop', 'components.x86_64-linux')
        paths = set(ref['paths']) | {v['path'] for block in ('tool_components', 'interop_components') for v in config[block].values()}
        for path in sorted(paths):
            if not Path(path).exists():
                if not args.realise:
                    raise SystemExit('Missing cached output (use --realise for cache-only retrieval): ' + path)
                subprocess.run(['nix-store', '--realise', '--max-jobs', '0', path], check=True, timeout=60)
        config['reference_components'] = ref
    else:
        if not args.python:
            raise SystemExit('--python is required for the native route')
        config['python'] = str(Path(args.python).absolute())
        prefixes = dict(value.split('=', 1) for value in args.tool_prefix)
        programs = {'openvswitch': 'ovs-vsctl', 'iproute2': 'ip', 'tcpdump': 'tcpdump',
                    'mininet': 'mnexec', 'nettools': 'ifconfig', 'iputils': 'ping',
                    'util-linux': 'unshare', 'ethtool': 'ethtool', 'procps': 'ps',
                    'psmisc': 'killall', 'which': 'which'}
        for name, program in programs.items():
            found = shutil.which(program)
            prefix = prefixes.get(name) or (str(Path(found).parent.parent) if found else None)
            if not prefix or not (Path(prefix) / 'bin' / program).is_file():
                raise SystemExit(f'Missing {program}; supply --tool-prefix {name}=/prefix')
            entry = {'path': str(Path(prefix).absolute()), 'version': 'external; binary hash recorded'}
            block = 'tool_components' if name in ('openvswitch', 'iproute2', 'tcpdump') else 'interop_components'
            config[block][name] = entry
        prefix = str(Path(config['python']).parent.parent)
        for block in ('tool_components', 'interop_components'):
            config[block]['python'] = {'path': prefix, 'version': '3.11.7'}
        config['interop_components']['mininet']['version'] = '2.3.1b4'
        config['interop_components']['mininet-python'] = {'path': str(ROOT / 'replication/vendor/mininet'), 'version': '2.3.1b4'}
        config['reference_components'] = {'interpreter': config['python'], 'paths': [], 'sitePackages': ''}
    env = python_env(config)
    expected = json.loads((CA1 / 'Revision_Protocol/reference_environment/referenceVersions.json').read_text())
    expected.update(json.loads((CA1 / 'Revision_Protocol/reference_environment/transitiveVersions.json').read_text()))
    code = 'import importlib.metadata as m,json,sys,sysconfig; names=json.loads(sys.argv[1]); print(json.dumps(dict(python=".".join(map(str,sys.version_info[:3])), packages={n:m.version(n) for n in names}, lib=sysconfig.get_config_var("LIBDIR")+"/"+sysconfig.get_config_var("LDLIBRARY"))))'
    observed = json.loads(command([config['python'], '-s', '-P', '-B', '-c', code, json.dumps([n for n in expected if n != 'python'])], env))
    assert observed['python'] == expected['python'], observed['python']
    assert observed['packages'] == {k: v for k, v in expected.items() if k != 'python'}, observed['packages']
    # Check actual extension loading, not only distribution metadata. NixOS users
    # may supply explicit runtime library directories; ordinary Linux usually needs none.
    imports = 'import hashlib,numpy,networkx,matplotlib.pyplot; import networkx.algorithms.similarity as s; import networkx.algorithms.shortest_paths.unweighted as u; from pathlib import Path; assert hashlib.sha256(Path(s.__file__).read_bytes()).hexdigest()=="639191975356f88155ab0a2039d1c9b3e4801e6a6fd5281f37b30817bcbca1d4"; assert hashlib.sha256(Path(u.__file__).read_bytes()).hexdigest()=="12e89988711010eac5669994326e764e100d8f27d679684a60522b9efbbd1bfb"'
    command([config['python'], '-s', '-P', '-B', '-c', imports], env)
    config['library_sha256'] = {str(p): sha(p) for directory in config['library_paths'] for p in sorted(Path(directory).glob('*.so*')) if p.is_file()}
    config['python_lib'] = observed['lib']
    assert Path(config['python_lib']).is_file(), config['python_lib']
    julia = args.julia or shutil.which('julia')
    if not julia:
        raise SystemExit('Julia 1.13.1 required; supply --julia /path/to/bin/julia')
    runtime = command([julia, '--startup-file=no', '--history-file=no', '-e', 'print(string(VERSION),"\\n",realpath(joinpath(Sys.BINDIR,"julia")))'], env).splitlines()
    assert runtime[0] == '1.13.1', runtime
    config['julia'] = runtime[1]
    # Import the real vendored dependency closure before any scientific run.
    # This includes runtime data (e.g. MacroTools/animals.txt), not just .jl files.
    probe_env = dict(env)
    project = CA1 / 'Emulation/Interop'
    probe_env.update(JULIA_LOAD_PATH=str(ROOT / 'replication/vendor/julia') + ':' + str(project) + ':@stdlib',
                     JULIA_DEPOT_PATH=str(output.parent / (output.stem + '-probe-depot')) + ':',
                     JULIA_PKG_OFFLINE='true', JULIA_CONDAPKG_BACKEND='Null', JULIA_CONDAPKG_OFFLINE='true',
                     JULIA_PYTHONCALL_EXE=config['python'], JULIA_PYTHONCALL_LIB=config['python_lib'],
                     MININET_PYTHON_SOURCE=str(ROOT / 'replication/vendor/mininet'))
    probe = 'using PythonCall, CondaPkg; @assert Base.pkgversion(PythonCall)==v"0.9.37"; @assert Base.pkgversion(CondaPkg)==v"0.2.38"; @assert CondaPkg.backend()==:Null; @assert startswith(pyconvert(String,pyimport("sys").version),"3.11.7"); pyimport("sys").path.insert(0,ENV["MININET_PYTHON_SOURCE"]); @assert pyconvert(String,pyimport("mininet.net").VERSION)=="2.3.1b4"; println("VENDORED INTEROP IMPORT PASS")'
    command([config['julia'], '--project=' + str(project), '--startup-file=no', '--history-file=no', '--compiled-modules=no', '--threads=1', '--gcthreads=1', '-e', probe], probe_env)
    config['vendored_interop_import_checked'] = True
    ovs = Path(config['tool_components']['openvswitch']['path']) / 'bin/ovs-vsctl'
    ovs_version = command([str(ovs), '--version'], env)
    assert 'Open vSwitch) 3.2.1' in ovs_version, ovs_version
    config['tool_components']['openvswitch']['version'] = '3.2.1'
    config['versions'] = {'julia': '1.13.1', 'python': observed['python'], **observed['packages'], 'openvswitch': '3.2.1', 'mininet': '2.3.1b4'}
    config['binary_sha256'] = {name: sha(path) for name, path in {'julia': config['julia'], 'python': config['python'], 'python_lib': config['python_lib'], 'ovs-vsctl': ovs}.items()}
    config['source_checkout'] = str(ROOT)
    config['host_note'] = 'This records concrete binaries on this host; route=native performs no Nix resolution. It does not certify a clean non-Nix operating system.'
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(config, indent=2) + '\n')
    print('ENVIRONMENT PASS', config['route'], output)

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--route', choices=['nix', 'native'], required=True)
    parser.add_argument('--output', required=True)
    parser.add_argument('--julia')
    parser.add_argument('--python')
    parser.add_argument('--tool-prefix', action='append', default=[], metavar='NAME=PREFIX')
    parser.add_argument('--library-path', action='append', default=[], metavar='DIRECTORY', help='explicit native shared-library search directory, recorded and hashed')
    parser.add_argument('--realise', action='store_true', help='retrieve missing Nix outputs from cache only; no local builds')
    configure(parser.parse_args())
