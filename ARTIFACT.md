# Artifact Appendix — Lex: A Language for Compliance by Design

This document accompanies the paper submission to CCS 2026 and describes how
to build and exercise the artifact for the "Functional" and "Results
Reproduced" badges.

**Pinned versions.** The enforcer (EnfFlash) is built from the `enfflash`
branch of [whyenf](https://github.com/runtime-enforcement/whyenf) at commit
`25826c4` (`evaluation/02_case_studies/GDPRSocial/Dockerfile.enfflash`); the
Lex compiler is built from this repository and its `enfguard/` submodule; the
Python dependencies of both case studies are pinned to exact versions in
their `requirements.txt`. `artifact-rq3-full` (the LLM-analyzer path) needs a
reviewer-supplied OpenAI key; without one, that step is skipped.

## 1. Overview

The artifact consists of three components, all built as Docker images from
this repository:

| Component | Path | Role |
|---|---|---|
| Lex compiler | `src/`, `bin/` | Compiles `.lex`/`.rex` files to MFOTL policies and HTML documentation (RQ1, RQ2) |
| `GDPRSocial` | `evaluation/02_case_studies/GDPRSocial` | Instrumented Django microblogging app (RQ2, RQ3) |
| `GDPRFS` | `evaluation/02_case_studies/GDPRFS` | Instrumented FUSE filesystem (RQ2, RQ3) |

Both case-study apps are enforced at runtime by EnfFlash, built from the
`enfflash` branch of [WhyEnf/EnfGuard](https://github.com/runtime-enforcement/whyenf)
(pinned commit, see above) as a separate image. The policies they enforce are
compiled from the case studies' `.rex` refinements by
`artifact/compile_policies.sh`, which `make artifact-build` runs before
building the application images (`make artifact-policies` runs it alone).

## 2. Claims and how to reproduce them

The paper asks four research questions. RQ1–RQ3 are (partially)
computationally reproducible; RQ4 is a human-subject study and is not.

| RQ | Paper claim | Reproduction | Badge |
|---|---|---|---|
| RQ1 | Lex formalizes GDPR/BGG/IRC (Table 1) | `make artifact-rq1` | Functional + exact Results (LOC matches the paper exactly) |
| RQ1 | GDPR coverage breakdown F/C/E/I (Table 2) | `make artifact-rq1-table2` | Functional + close Results (≤0.1pp on every figure) |
| RQ2 | Instrumentation LOC and engineering effort (Table 3) | `make artifact-rq2` | Functional + exact Results (all 8 LOC figures exact) |
| RQ3 | Runtime latency overhead (Table 4) | `make artifact-rq3-fast` (and optionally `artifact-rq3-full`) | Functional + approximate Results |
| RQ4 | User study (SUS, reading, auditing) | Not reproducible; materials only | Documented, see §5 |

"Approximate Results" means: the scripts recompute the same statistic from
the same source artifacts, but exact figures may differ slightly from the
paper (host-hardware-dependent latencies for RQ3). The scripts print the
paper's original numbers alongside the reproduced ones for comparison, and
each documents its
expected margin of deviation.

**Table 2** is computed from the per-provision F/C/E/I classification of the
GDPR (`example/GDPR/classification_published.tex`). `make artifact-rq1-table2`
runs `example/GDPR/gdpr_stats.py`, which weights every classified provision by
its word count in the GDPR's official Formex text (`example/GDPR/GDPR.xml`)
and aggregates the weights into the percentages of Table 2. Differences of
<0.1pp from the paper come from the edition of the Formex text.

## 3. Requirements

- Docker (tested with Docker Engine ≥ 24). No local OCaml/Python toolchain
  is required — everything runs inside the built images.
- A Linux x86-64 host with git submodule access to clone `enfguard/`.
- ~6 GB free disk space for the five Docker images plus build cache.
- Memory: the Lex and EnfFlash images build Z3 and other OCaml packages with
  opam, limited to 4 parallel jobs (`OPAMJOBS`). 16 GB RAM is recommended; if
  a build is killed for lack of memory, use `make artifact-build OPAMJOBS=2`
  (or 1).
- The scripts that compile Lex code run the Lex image as your host user
  (`docker run --user "$(id -u):$(id -g)"`) on the bind-mounted checkout, so
  they work for any host UID.
- For `make artifact-rq3-fast` / `artifact-rq3-full`: the ability to run
  `docker run --privileged --device /dev/fuse` (GDPRFS mounts a real FUSE
  filesystem inside its container). If your evaluation environment cannot
  grant this, skip the GDPRFS enforced-mode lines in
  `artifact/rq3_benchmark.sh` and rely on RQ1/RQ2 plus GDPRSocial's RQ3 run,
  which needs no special privileges.
- Optional, for `make artifact-rq3-full` only: an OpenAI API key, to
  exercise GDPRFS's LLM-based file analyzer (`gpt-5.4-mini` in the paper).
  Without it, the LLM-analyzer benchmark step is skipped automatically and
  everything else still runs.
- Expect ~20–30 minutes for `artifact-build` + `artifact-rq1` +
  `artifact-rq2`, plus ~5–7 minutes for each of GDPRSocial's two RQ3 runs.
  GDPRFS's RQ3 runs are benchmarked at the paper's preload sizes (10², 10³,
  10⁴ files); preloading 10⁴ files through FUSE takes considerably longer.
  For a shorter pass, run `FS_PRELOAD=100,1000 make artifact-rq3-fast`.

## 4. Quick start

```bash
git clone <this-repo-url> lex-artifact
cd lex-artifact
git checkout artifact
git submodule update --init --recursive

make artifact-build      # builds the lex image, compiles the case-study policies,
                         # then builds the whyenf-enfflash, gdprsocial, gdprfs,
                         # lex-cloc images
make artifact-rq1        # Table 1: compile GDPR/BGG/IRC, report LOC
make artifact-rq1-table2 # Table 2: GDPR coverage by F/C/E/I category
make artifact-rq2        # Table 3: instrumented app LOC breakdown
make artifact-rq3-fast   # Table 4: latency, baseline vs. enforced (no LLM);
                         # ends with the aggregated table (make artifact-table4)
# optional, needs --privileged/--device fuse already granted above, plus an API key:
make artifact-rq3-full
```

`artifact-rq3-*` accept the environment variables `FS_PRELOAD` (GDPRFS
preload sizes, default `100,1000,10000`) and `FS_N` (GDPRFS iterations per
setup, default 3; the paper uses 20). `make artifact-table4` re-prints the
aggregated Table 4 from the latest results.

Each target writes its output under `artifact/out/` (git-ignored) and also
prints a human-readable summary to stdout.

Basic sanity check that the compiler itself works correctly (unit tests):

```bash
docker run --rm --user "$(id -u):$(id -g)" -v "$(pwd):/workspace" -w /workspace lex:latest \
  sh -lc "dune build @runtest"
```

## 5. What is not computationally reproduced, and why

- **RQ4 (user study)** involved 23 human participants recruited through our
  institution's subject pool under IRB-equivalent review, and no raw or
  per-participant survey data is redistributed here for participant privacy.
  The study materials used are included for reference: the 30-minute
  training document (`extended_report/`, `docs/tutorials`), the formalization
  used in the training/reading/auditing tasks
  (`evaluation/03_user_study/evaluation.lex` and its generated
  documentation `evaluation.lex_doc.html`), and the Qualtrics survey
  instrument (`evaluation/03_user_study/Qualtrics Survey.pdf`).
- **Exact RQ3 latency figures** are hardware-dependent (paper: 2.4 GHz Intel
  i5, 32 GB RAM, native runs without containers, 20 repetitions). The scripts
  here run in Docker with fewer GDPRFS repetitions by default (`FS_N=3`);
  expect the same qualitative pattern (moderate enforcement overhead that
  does not grow with n; GDPRFS write/erasure exceeding 100ms due to the LLM
  call / bulk file deletion) rather than matching numbers.

## 6. Repository map for reviewers

- `src/`, `bin/` — the Lex compiler (OCaml/dune).
- `evaluation/01_formalization/` — GDPR/BGG/IRC `.lex` formalizations (RQ1,
  Table 1) and the `minitwit_gdpr.rex` refinement excerpt.
- `example/GDPR/classification_published.tex`, `gdpr_stats.py` — the
  per-provision F/C/E/I classification of the GDPR and the script that
  computes Table 2 from it (RQ1).
- `evaluation/02_case_studies/GDPRSocial/`, `.../GDPRFS/` — the two
  instrumented applications (RQ2, RQ3), each with its own detailed README
  covering local (non-Docker) installation as well.
- `evaluation/03_user_study/` — RQ4 materials (see §5).
- `example/`, `docs/` — tutorial examples and the language documentation
  (`mkdocs`-based; not required for artifact evaluation).
- `artifact/` — the reproduction scripts referenced above, including
  `compile_policies.sh` (compiles the case-study refinements into the
  policies the applications enforce) and `rq3_table4.py` (aggregates the RQ3
  CSVs into Table 4's layout).

## 7. Troubleshooting

- `docker build` for `GDPRSocial`/`GDPRFS` fails with a missing file under
  `instrlib/`: make sure you build with the context shown above (the
  Makefile targets already pass the correct `-f`/context combination;
  if invoking `docker build` manually, the context must be
  `evaluation/02_case_studies`, not the app subdirectory).
- `enfguard/` is empty: run `git submodule update --init --recursive`.
- GDPRFS enforced-mode runs hang waiting for a service: the container's
  `docker-entrypoint.sh` polls each internal service (consent platform,
  purpose platform, FUSE daemon) before starting the benchmark; this can
  take a few seconds longer on a loaded host. If it hangs indefinitely,
  check that `--privileged --device /dev/fuse` was passed.
- `docker build` of the `lex` or `whyenf-enfflash` image is killed while
  building Z3 (out of memory): rebuild with fewer parallel opam jobs,
  `make artifact-build OPAMJOBS=2`.
- `mkdir(_build): Permission denied` when running a compile step: the
  scripts pass `--user "$(id -u):$(id -g)"`; if you run the Lex image by
  hand on a bind-mounted checkout, pass it too.
