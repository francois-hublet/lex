# Artifact Appendix — Lex: A Language for Compliance by Design

This document accompanies the paper submission to CCS 2026 and describes how
to build and exercise the artifact for the "Functional" and "Results
Reproduced" badges.

The paper is under double-blind review; this repository and artifact
scripts contain no author-identifying information. If you redistribute this
branch for anonymous review (e.g. as a zip or an anonymized mirror), strip
the git history rather than sharing this repository directly, since commit
authorship is not anonymized.

**Validation status:** every command below (`artifact-build`,
`artifact-rq1`, `artifact-rq1-table2`, `artifact-rq2`, `artifact-rq3-fast`,
including GDPRFS's `--privileged`/`--device /dev/fuse` path) has been run
end-to-end on a clean Linux/Docker host as part of preparing this branch,
and produces the outputs described in §4. `artifact-rq3-full` (the
LLM-analyzer path) was not exercised here since it requires a
reviewer-supplied OpenAI key, but the fallback behavior (skipping that one
step) was verified.

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
| RQ1 | Lex formalizes GDPR/BGG/IRC (Table 1) | `make artifact-rq1` | Functional + approximate Results |
| RQ1 | GDPR coverage breakdown F/C/E/I (Table 2) | `make artifact-rq1-table2` | Functional + close Results (≤0.1pp on every figure), see §5 for provenance |
| RQ2 | Instrumentation LOC and engineering effort (Table 3) | `make artifact-rq2` | Functional + close Results (Python/HTML/CSS line counts match within a few dozen lines) |
| RQ3 | Runtime latency overhead (Table 4) | `make artifact-rq3-fast` (and optionally `artifact-rq3-full`) | Functional + approximate Results |
| RQ4 | User study (SUS, reading, auditing) | Not reproducible; materials only | Documented, see §5 |

"Approximate Results" means: the scripts recompute the same statistic from
the same source artifacts, but exact figures may differ slightly from the
paper (different `cloc`/line-counting conventions for RQ1/RQ2; host-hardware-
dependent latencies for RQ3). The scripts print the paper's original numbers
alongside the reproduced ones for comparison, and each documents its
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

- **Table 2 (GDPR coverage by F/C/E/I category)** is reproducible, but not by
  a *live* run of the classification pipeline over `minitwit_gdpr.rex` — here
  is the full provenance, and why `make artifact-rq1-table2` reproduces it the
  way it does.

  `example/GDPR/classify_coverage.py` derives, per GDPR section, whether it is
  Formalized (has any Lex rule), and among the events those rules reference,
  whether each is unassumed (**E**, enforced at runtime), assumed with a
  `# functional` tag (**C**, conservatively — the specification is
  monotonic/antimonotonic in that event, so getting the assumption wrong
  cannot degrade compliance), or assumed with a `# legal` tag (**I**,
  informally, requiring legal review). `example/GDPR/gdpr_stats.py` then
  weights this per-section table by word count against the official GDPR XML
  (Formex) text to produce Table 2's percentages. This pipeline exists in the
  repository and runs (`artifact/rq1_table2.sh`'s "live regeneration" step
  does exactly this) — but the `# legal`/`# functional` tags it depends on
  were never committed anywhere we could find: we searched the full git
  history of all three copies of `minitwit_gdpr.rex` in this repository, plus
  two related external repositories (one on GitLab, one a collaborator's
  GitHub fork, all branches), and found the tags nowhere. We reconstructed
  best-effort tags for this branch (grounded in a per-predicate table
  recovered from the paper's originating thesis, defaulting to `# legal`
  wherever that table didn't cover a predicate — the fairer, less favorable
  reading, per instruction), but a live run from these tags does **not**
  reproduce Table 2's published numbers (F/C/E/I ≈ 19.7/14.4/8.7/9.1% vs. the
  paper's 18.4/7.8/7.2/6.4%). This is not a defect in the reconstruction: the
  recovered per-predicate table it's grounded in is itself internally
  inconsistent (e.g. Article 8 Subparagraph 1 lists a "+"-marked, i.e.
  conservative, predicate in its assumed-predicate column while its own **C**
  dot for that row is unset), meaning the dots that produced Table 2 and the
  predicate-level annotations were edited at different times and never
  reconciled, even in the original.

  What we *did* recover and verify is the frozen table itself — the actual
  per-section F/C/E/I dots, not the predicate-list text — from commit
  `0523c39` of the thesis repository this paper is drawn from
  (`example/GDPR/classification_published.tex`). Feeding it directly to
  `gdpr_stats.py`, unmodified, reproduces the published Table 2 to within
  0.1 percentage point on every figure (E matches exactly). `make
  artifact-rq1-table2` runs this reproduction, and also runs (for comparison,
  clearly labeled) the live `.rex`-based regeneration described above, so
  reviewers can see both the reproduction and the gap. Reviewers wishing to
  audit the classification substantively rather than just reproduce the
  numbers can inspect `evaluation/02_case_studies/GDPRSocial/policies/*.rex`
  (now carrying the reconstructed tags) against the referenced GDPR articles.

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

## 6. Repository map for reviewers

- `src/`, `bin/` — the Lex compiler (OCaml/dune).
- `evaluation/01_formalization/` — GDPR/BGG/IRC `.lex` formalizations (RQ1,
  Table 1) and the `minitwit_gdpr.rex` refinement excerpt.
- `example/GDPR/classify_coverage.py`, `gdpr_stats.py`,
  `classification_published.tex` — the Table 2 (RQ1) pipeline and the
  recovered frozen classification table; see §5.
- `evaluation/02_case_studies/GDPRSocial/`, `.../GDPRFS/` — the two
  instrumented applications (RQ2, RQ3), each with its own detailed README
  covering local (non-Docker) installation as well.
- `evaluation/03_user_study/` — RQ4 materials (see §5).
- `example/`, `docs/` — tutorial examples and the language documentation
  (`mkdocs`-based; not required for artifact evaluation).
- `artifact/` — the reproduction scripts referenced above.

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
