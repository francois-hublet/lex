# GDPRSocial case study (WhyEnf / EnfFlash)

This folder contains the Django case study used for GDPR enforcement experiments.

## Installation

This case study supports exactly two setup options:

1. Local install
2. Docker

## Option 1: Local install

### 1) Build the enforcer executable first (required)

Use the `enfflash` branch of WhyEnf:

- Repository: https://github.com/runtime-enforcement/whyenf/tree/enfflash

Build it with the repository `Makefile` (builds both OCaml and Rust parts):

```bash
git clone -b enfflash https://github.com/runtime-enforcement/whyenf.git ~/Git/whyenf
cd ~/Git/whyenf
make build
```

After this, the executable is at `~/Git/whyenf/bin/enfflash.exe` (the target
is named `enfflash` in the `enfflash` branch's `bin/dune`, despite the
`enfguard`-named CLI flags below). Symlink it to the name the rest of these
instructions use:

```bash
ln -sfn ~/Git/whyenf/bin/enfflash.exe ~/Git/whyenf/enfguard
```

### 2) Set up GDPRSocial

From this folder:

```bash
cd /home/franz/Git/Lex/evaluation/02_case_studies/GDPRSocial
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
python manage.py migrate
ln -sfn ~/Git/whyenf/enfguard ./enfguard
```

`requirements.txt` includes all Python dependencies used by the app (including `scikit-learn`).

For benchmarking, also install the benchmark-specific requirements:

```bash
pip install -r benchmark/privacy_testsuite/requirements.txt
```

### 3) Run

```bash
make clean
make run
```

App access:

- http://127.0.0.1:8000/
- Login page: http://127.0.0.1:8000/accounts/login/

Optional: replay monitor over current log in another terminal:

```bash
make replay
```

### 4) Run benchmark (local)

From this folder:

```bash
# Enforced benchmark (requires a built enfguard executable):
bash benchmark/privacy_testsuite/run_benchmark.sh gdpr ~/Git/whyenf/enfguard

# Un-instrumented baseline (no enforcer needed):
bash benchmark/privacy_testsuite/run_benchmark.sh baseline
```

This runs:

1. `prepare_databases.py` (snapshot preparation, skipped if already done)
2. `privacy_test.py` (benchmark execution)

Expected runtime is around 5–7 minutes per run.
Results are written under `output/minitwitter_<timestamp>/`.

The baseline measures raw app latency without enforcement overhead. Run
both to compare.

## Option 2: Docker

### 1) Build a separate WhyEnf EnfFlash image

From this folder:

```bash
docker build -f Dockerfile.enfflash -t whyenf-enfflash:latest .
```

### 2) Build this case-study image

From this folder (note the parent `..` build context):

```bash
docker build -f Dockerfile -t gdprsocial:latest ..
```

### 3) Run container

```bash
docker run --rm -it \
	-p 8000:8000 \
	gdprsocial:latest
```

App access:

- http://127.0.0.1:8000/
- Login page: http://127.0.0.1:8000/accounts/login/

### 4) Run benchmark (Docker)

To keep benchmark results on the host, mount a local output folder:

```bash
mkdir -p output

# Enforced benchmark:
docker run --rm -it \
  -v "$(pwd)/output:/app/output" \
  gdprsocial:latest \
  bash benchmark/privacy_testsuite/run_benchmark.sh gdpr /opt/whyenf/enfguard

# Un-instrumented baseline (no enforcer argument needed):
docker run --rm -it \
  -v "$(pwd)/output:/app/output" \
  gdprsocial:latest \
  bash benchmark/privacy_testsuite/run_benchmark.sh baseline
```

Expected runtime is around 5–7 minutes per run.
Results are written to `./output/minitwitter_<timestamp>/` on the host.
Run both policies and compare latencies to measure enforcement overhead.

## Notes

- The old `whyenf/bin/whyenf.exe` path is obsolete for this setup.
- For Docker, `enfguard` and `enfflash` are copied from the separate `whyenf-enfflash:latest` image.





