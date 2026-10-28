# Licensing and third-party notices

## Original material

Copyright © 2026 Justin Marc Cheney.

- Original software, scripts and configuration are available under the [MIT License](LICENSES/MIT.txt).
- Original documentation, research notes and original study records are available under [Creative Commons Attribution 4.0 International](LICENSES/CC-BY-4.0.txt).

These grants cover only material for which the author can grant rights. Quoted passages, copied upstream code, adapted algorithms and third-party metadata retain their applicable rights and notices. Inclusion in a run snapshot does not change ownership or license. A root-level blanket license must not be interpreted as relicensing those files.

## Spotlight: CC BY 4.0

Ben Weintraub, Jiwon Kim, Ran Tao, Cristina Nita-Rotaru, Hamed Okhravi, Dave (Jing) Tian and Benjamin E. Ujcich, **Spotlight: CCS Artifact**, 2024, Zenodo record 12735280, <https://doi.org/10.5281/zenodo.12735280>.

The retained [Zenodo metadata](artifacts/SDN_Model_Comparison/source_fidelity/sources/zenodo-record.json) identifies the artifact license as CC BY 4.0. The version-history metadata also identifies that license for the earlier record 11642350. Copied original detector, topology-generator, dependency and container-file snapshots occur under `artifacts/SDN_Model_Comparison/source_fidelity/sources/`, `Revision_Protocol/inputs/` and `Revision_Protocol/reference_capture/sources/`. Their repeated frozen run snapshots retain the same attribution and terms.

The Julia module `artifacts/SDN_Model_Comparison/source_fidelity/detector.jl` is an adaptation, not unchanged Python execution. Its header identifies Spotlight topology/flow logic and NetworkX Panther/BFS provenance. RNG transforms, tie handling and implementation differences are disclosed in the study. This mixed-provenance module is not presented as exclusively MIT-licensed original code.

The retained text extraction `Revision_Protocol/inputs/spotlight-paper.md` is from **Exploiting Temporal Vulnerabilities for Unauthorized Access in Intent-Based Networking**, ACM CCS 2024, pp. 3630–3644, <https://doi.org/10.1145/3658644.3670301>. Its first-page notice explicitly licenses the paper under CC BY 4.0. The file is a text extraction, not the publisher's original PDF; attribution and the license notice remain in the extraction.

## NetworkX: BSD-3-Clause

NetworkX 3.2.1 similarity/unweighted-path source snapshots and derived Panther/BFS material retain the [NetworkX copyright and BSD license](artifacts/SDN_Model_Comparison/source_fidelity/sources/networkx-license-3.2.1.txt). The corresponding source metadata identifies the upstream version. This includes the relevant portions of the Julia detector adaptation. No MIT grant here removes those notice, redistribution or endorsement conditions.

## External dependencies

Julia, Python, NumPy, Matplotlib, Mininet, Open vSwitch, PythonCall, CondaPkg, Nixpkgs and other dependencies retain their respective licenses. This export includes version/lock/provenance records and the author's integration code, not their installed binaries or the Nix-store package trees. Fetch/install dependencies through their upstream distributions and honor their notices. Names in logs or metadata are not endorsements.

## Material deliberately not redistributed

- NetViews/MSNetViews and other third-party reading copies without a confirmed applicable redistribution grant.
- Unrelated literature PDFs, publisher templates, course instructions and editorial records.
- The private historical course-context snapshots, which contain identifying assessment information.

The original local archive remains unchanged. Exclusions are distribution decisions, not scientific-input corrections. Author-written research summaries may cite these works; that does not place the underlying works under the author's license.

License texts in `LICENSES/` were obtained from the SPDX license-list text distribution. The applicable CC BY 4.0 canonical legal code is <https://creativecommons.org/licenses/by/4.0/legalcode>.
