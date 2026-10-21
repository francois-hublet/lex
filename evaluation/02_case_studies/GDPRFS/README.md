# GDPR-Compliant File System (GDPRFS)

A FUSE-based filesystem that enforces GDPR compliance at the OS level. Every
file read, write, rename, and delete is intercepted and checked against
consent policies, PII ownership rules, and GDPR article requirements in real
time using the [WhyEnf/EnfGuard](https://github.com/runtime-enforcement/whyenf)
policy enforcer.

**GDPR articles implemented:** 5 (Accuracy), 6 (Lawful Basis), 9 (Special
Categories), 15 (Right of Access), 16 (Right to Rectification), 17 (Right to
Erasure), 30 (Records of Processing Activities).

---

## Table of Contents

1. [Architecture](#1-architecture)
2. [Local Install](#2-local-install)
3. [Docker Install](#3-docker-install)
4. [Running the Application](#4-running-the-application)
5. [Benchmark](#5-benchmark)
6. [Instrumentation Library (instrlib)](#6-instrumentation-library-instrlib)

---

## 1. Architecture

| Component | Port | Role |
|-----------|------|------|
| **FUSE Daemon** (`gdprfs/myfs.py`) | 7000 (ingest) | Core filesystem + GDPR enforcement |
| **External Consent Platform** (`external_consent_platform/`) | 5000 | Data Subject portal – consent, Art 15/16/17 |
| **Internal Purpose Platform** (`internal_purpose_platform/`) | 8000 | Internal user portal – sessions, `.gdprowner` |
| **LLM Analyzer** (`LLManalyzer/`) | 5005 | GPT-based PII / special-category scanner |

FUSE mounts at `/tmp/mnt`; upper layer at `/var/lib/gdprfs/upper`.

---

## 2. Local Install

### Prerequisites

- Linux with FUSE support (`/dev/fuse` accessible to your user)
- Python 3.12 or later
- `poppler-utils` (`sudo apt install -y poppler-utils`)
- EnfGuard enforcer (built automatically by `setup_fuse_env.sh`)

### Setup

```bash
cd evaluation/02_case_studies/GDPRFS

# Create virtual environment, install all deps, build EnfGuard, configure FUSE
./setup_fuse_env.sh
```

The script:
- Creates `.gdprfs-venv/` and installs all Python packages
- Installs / links `python-fuse` from system packages
- Clones and builds the EnfGuard binary into `enfguard/bin/`
- Creates `/var/lib/gdprfs/` with required files
- Configures `/dev/fuse` permissions

### Initialise the database

```bash
source .gdprfs-venv/bin/activate
python3 gdprfs/setup_db.py
```

### OpenAI key for LLM Analyzer (required for `gdpr_with_llm`)

You must provide your own key; no key is bundled with this project.
Create `openai.secret` in the GDPRFS folder:

```
OPENAI_API_KEY=sk-...
```

---

## 3. Docker Install

The Docker image supports **all three benchmark modes**.  Baseline runs without
any special privileges.  The two GDPR FUSE modes need `/dev/fuse` and a
privileged container.  The `docker-entrypoint.sh` automatically starts the
required services before running the benchmark command.

### Build

From the `evaluation/02_case_studies/` directory (the parent context is needed
so Docker can access the shared `instrlib/`):

1) Build the shared WhyEnf image once (same as GDPRSocial):

```bash
cd evaluation/02_case_studies
docker build -f GDPRSocial/Dockerfile.enfflash -t whyenf-enfflash:latest .
```

2) Build GDPRFS image (reuses `whyenf-enfflash:latest`):

```bash
docker build -f GDPRFS/Dockerfile -t gdprfs:latest .
```

### Mode 1 – Baseline (no FUSE required)

```bash
docker run --rm gdprfs:latest
# or with custom iterations:
docker run --rm gdprfs:latest python3 -m benchmark.simple --mode baseline --n 5
```

Expected output:

```
============================================================
  Mode: baseline  |  Iterations: 3
============================================================
  [baseline] iteration 1/3 ... total=0.0172s
  ...
  Completed 3/3 iterations

  CSV saved to /app/benchmark/results/simple_perf_results.csv
  ...  t_total   0.0155±0.0015
Done.
```

### Mode 2 – GDPR no LLM

The entrypoint boots Consent Platform → Purpose Platform → FUSE daemon, waits
for each to be ready, then runs the benchmark:

```bash
docker run --rm --privileged --device /dev/fuse \
    gdprfs:latest \
    python3 -m benchmark.simple --mode gdpr_no_llm --n 3
```

### Mode 3 – GDPR with LLM

Requires your own OpenAI API key from `openai.secret`. The entrypoint starts
the LLM Analyzer only when `OPENAI_API_KEY` is set.

Load key from `openai.secret` and run:

```bash
KEY=$(grep -v '^#' openai.secret | head -1 | sed 's/OPENAI_API_KEY=//')
docker run --rm --privileged --device /dev/fuse \
    -e OPENAI_API_KEY="$KEY" \
    gdprfs:latest \
    python3 -m benchmark.simple --mode gdpr_with_llm --n 3
```

### All modes in one run

```bash
docker run --rm --privileged --device /dev/fuse \
    gdprfs:latest \
    python3 -m benchmark.simple --mode all --n 3
```

### How the entrypoint works

`docker-entrypoint.sh` detects the `--mode` flag and starts services accordingly:

| Mode | Services started before benchmark |
|------|----------------------------------|
| `baseline` | none – executes immediately |
| `gdpr_no_llm` | Consent Platform (5000) → Purpose Platform (8000) → FUSE daemon (7000) |
| `gdpr_with_llm` | same + LLM Analyzer (5005); requires user key in `openai.secret` |
| `all` | same as `gdpr_with_llm`; provide key if you want the LLM step enabled |

Each service is polled until it responds before the next one starts.

### Persistent results

```bash
docker run --rm --privileged --device /dev/fuse \
    -v "$(pwd)/results:/app/benchmark/results" \
    gdprfs:latest \
    python3 -m benchmark.simple --mode gdpr_no_llm --n 3
```

---

## 4. Running the Application

### Start all services (local)

The enforcer needs the `-fix-since` option, which instrlib passes from the
`INSTRLIB_EXTRA_ARGS` environment variable (the Docker image sets it already):

```bash
export INSTRLIB_EXTRA_ARGS=-fix-since
```

```bash
source .gdprfs-venv/bin/activate

# Terminal 1 – External Consent Platform (port 5000)
cd external_consent_platform && python3 app.py

# Terminal 2 – Internal Purpose Platform (port 8000)
cd internal_purpose_platform && python3 app.py

# Terminal 3 – LLM Analyzer (port 5005)
cd LLManalyzer && python3 api.py

# Terminal 4 – FUSE daemon (requires root / fuse group membership)
cd ..   # back to GDPRFS root
sudo -E PYTHONPATH=. .gdprfs-venv/bin/python3 gdprfs/myfs.py /tmp/mnt -f -o allow_other
```

Alternatively, use the convenience script (opens gnome-terminal tabs):

```bash
./run_all.sh
```

### Access

| Interface | URL |
|-----------|-----|
| Data Subject consent portal | http://127.0.0.1:5000 |
| Internal users (purpose/session portal) | http://127.0.0.1:8000 |
| LLM Analyzer API | http://127.0.0.1:5005 |
| FUSE ingest API | http://127.0.0.1:7000 |

### Stop

- Web services: `Ctrl+C` in each terminal
- FUSE daemon: `./reset_myfs_sudo.sh`

### Reset databases

```bash
rm gdprfs.db && python3 gdprfs/setup_db.py
rm external_consent_platform/instance/external_consent_platform.db
rm internal_purpose_platform/instance/internal_purpose_platform.db
```

---

## 5. Benchmark

`benchmark/simple.py` measures six primitive operations across three modes:

| Mode | Description |
|------|-------------|
| `baseline` | Plain local filesystem + in-memory SQLite consent store. No FUSE, no enforcer. |
| `gdpr_no_llm` | GDPRFS/FUSE with EnfGuard enforcer; LLM scanner disabled. |
| `gdpr_with_llm` | GDPRFS/FUSE with EnfGuard enforcer and LLM scanner enabled. |

Operations: `t_read_file`, `t_write_file`, `t_give_consent`, `t_remove_consent`,
`t_request_erasure`, `t_request_rectification`, `t_total`.

### Local – baseline only (no FUSE)

```bash
source .gdprfs-venv/bin/activate
python3 -m benchmark.simple --mode baseline --n 3
```

### Local – GDPR modes (full stack running, see §4)

```bash
source .gdprfs-venv/bin/activate
# single mode:
python3 -m benchmark.simple --mode gdpr_no_llm --n 3
python3 -m benchmark.simple --mode gdpr_with_llm --n 3
# all modes at once:
python3 -m benchmark.simple --mode all --n 3
```

### Local – with preloaded files

```bash
python3 -m benchmark.simple --mode all --n 3 --preload 100,1000
```

### Docker – see §3 for all Docker commands

### Output

Results are saved as CSV to `benchmark/results/simple_perf_results.csv`
(or `simple_perf_results_preload<N>.csv` for preload runs).

---

## 6. Instrumentation Library (instrlib)

GDPRFS uses the **shared** instrumentation library at
`evaluation/02_case_studies/instrlib/` – the same copy used by GDPRSocial.

The GDPRFS folder contains a legacy `instrlib/` subdirectory that predates the
shared copy.  The Docker image replaces it with the shared version.  Key
differences:

| File | Shared instrlib | GDPRFS local instrlib |
|------|-----------------|-----------------------|
| `instrument.py` | Full implementation | Compatibility shim → `instrument_working.py` |
| `pdp.py` (`EnfGuard`) | Supports `-func` / `-state` CLI args | Older version without those args |
| `pep.py` | Modern `dict[…]` type hints | Older `Dict[…]` style |
| `instrument_working.py` | Not present | FUSE-aware variant (superseded by `InstrumentNoAttr` in `myfs.py`) |

`myfs.py` uses `InstrumentNoAttr` (defined locally) for FUSE class decoration,
making it fully compatible with the shared instrlib.

**For local development** with the shared instrlib, add the shared copy to
`PYTHONPATH`:

```bash
export PYTHONPATH=/path/to/evaluation/02_case_studies:$PYTHONPATH
```

