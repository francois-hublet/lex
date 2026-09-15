# Artifact Appendix — Lex: A Language for Compliance by Design

This document accompanies the paper submission to CCS 2026 and describes how
to build and exercise the artifact for the "Functional" and "Results
Reproduced" badges.

## 1. Overview

The artifact consists of three components, all built as Docker images from
this repository:

| Component | Path | Role |
|---|---|---|
| Lex compiler | `src/`, `bin/` | Compiles `.lex`/`.rex` files to MFOTL policies and HTML documentation (RQ1, RQ2) |
| `GDPRSocial` | `evaluation/02_case_studies/GDPRSocial` | Instrumented Django microblogging app (RQ2, RQ3) |
| `GDPRFS` | `evaluation/02_case_studies/GDPRFS` | Instrumented FUSE filesystem (RQ2, RQ3) |

Both case-study apps are enforced at runtime by
[WhyEnf/EnfGuard](https://github.com/runtime-enforcement/whyenf) (submodule
`enfguard/`, plus the `enfflash` branch built as a separate image).

## 2. Claims and how to reproduce them

The paper asks four research questions. RQ1–RQ3 are (partially)
computationally reproducible; RQ4 is a human-subject study and is not.

| RQ | Paper claim | Reproduction | Badge |
|---|---|---|---|
| RQ1 | Lex formalizes GDPR/BGG/IRC (Table 1) | `make artifact-rq1` | Functional + exact Results (LOC matches the paper exactly) |
| RQ1 | GDPR coverage breakdown F/C/E/I (Table 2) | `make artifact-rq1-table2` | Functional + close Results (≤0.1pp on every figure) |
| RQ2 | Instrumentation LOC and engineering effort (Table 3) | `make artifact-rq2` | Functional + exact Results (7 of 8 LOC figures exact; GDPRSocial's instrumented Python is within 9 of 2,445) |
| RQ3 | Runtime latency overhead (Table 4) | `make artifact-rq3-fast` (and optionally `artifact-rq3-full`) | Functional + approximate Results |
| RQ4 | User study (SUS, reading, auditing) | Not reproducible; materials only | Documented, see §5 |

"Approximate Results" means: the scripts recompute the same statistic from
the same source artifacts, but exact figures may differ slightly from the
paper (host-hardware-dependent latencies for RQ3). The scripts print the
paper's original numbers alongside the reproduced ones for comparison, and
each documents its
expected margin of deviation.

## 3. Requirements

- Docker (tested with Docker Engine ≥ 24). No local OCaml/Python toolchain
  is required — everything runs inside the built images.
- A Linux host with git submodule access to clone `enfguard/`.
- ~6 GB free disk space for the four Docker images plus build cache.
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
- Expect a total of ~20–30 minutes end-to-end for `artifact-build` +
  `artifact-rq1` + `artifact-rq2` + `artifact-rq3-fast` on a typical
  workstation; GDPRSocial's two RQ3 runs dominate at ~5–7 minutes each.

## 4. Quick start

```bash
git clone <this-repo-url> lex-artifact
cd lex-artifact
git checkout artifact
git submodule update --init --recursive

make artifact-build      # builds lex, whyenf-enfflash, gdprsocial, gdprfs images
make artifact-rq1        # Table 1: compile GDPR/BGG/IRC, report LOC
make artifact-rq1-table2 # Table 2: GDPR coverage by F/C/E/I category
make artifact-rq2        # Table 3: instrumented app LOC breakdown
make artifact-rq3-fast   # Table 4: latency, baseline vs. enforced (no LLM)
# optional, needs --privileged/--device fuse already granted above, plus an API key:
make artifact-rq3-full
```

Each target writes its output under `artifact/out/` (git-ignored) and also
prints a human-readable summary to stdout.

Basic sanity check that the compiler itself works correctly (unit tests):

```bash
docker run --rm -v "$(pwd):/workspace" -w /workspace lex:latest \
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
  i5, 32 GB RAM, 20 repetitions). The scripts here run fewer repetitions by
  default for a fast pass; expect the same qualitative pattern (moderate,
  mostly sub-100ms enforcement overhead; GDPRFS write/erasure exceeding
  100ms due to the LLM call / bulk file deletion) rather than matching
  numbers.

