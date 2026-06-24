## Installation

Lex supports two setup options:

1. Local install
2. Docker

---

### Option 1: Local install

Requirements:

- [opam](https://opam.ocaml.org/doc/Install.html)
- OCaml 4.13.1
- [dune](https://dune.build/)

From the repository root:

```bash
git submodule update --init --recursive
opam switch create 4.13.1 || true
eval $(opam env)
opam install -y dune core_unix menhir=20250912 xml-light ppx_jane calendar z3 pyml=20250807 alcotest
dune build
```

Optional (install CLI globally in current switch):

```bash
opam install . -y
```

---

### Option 2: Docker

Requirements:
- [Docker](https://www.docker.com/)

From the repository root:

```bash
git submodule update --init --recursive
docker build -t lex:latest .
```

Open an interactive shell in the prepared environment:

```bash
docker run --rm -it lex:latest
```

---

## Usage

From the repository root:

```bash
dune exec -- ./bin/main.exe <path/to/.lex file> [-mode (mfotl|doc)]
```

Example:

```bash
dune exec -- ./bin/main.exe example/unit/hello.lex
```

### Test-compile examples for evaluation formalizations

Targets:
- `evaluation/01_formalization/gdpr.lex`
- `evaluation/01_formalization/minitwit_gdpr.rex`

#### Local

```bash
# 1) gdpr.lex
./_build/default/bin/main.exe evaluation/01_formalization/gdpr.lex -o /tmp/gdpr_eval01
ls -lh /tmp/gdpr_eval01.sig /tmp/gdpr_eval01.mfotl

# 2) minitwit_gdpr.rex
./_build/default/bin/main.exe evaluation/01_formalization/minitwit_gdpr.rex -o /tmp/minitwit_eval01
ls -lh /tmp/minitwit_eval01.sig /tmp/minitwit_eval01.mfotl
```

#### Docker

Compile directly from the mounted repository:

```bash
docker run --rm -v "$PWD:/workspace" lex:latest sh -lc '
	dune exec -- ./bin/main.exe /workspace/evaluation/01_formalization/gdpr.lex -o /tmp/gdpr_eval01 && \
	dune exec -- ./bin/main.exe /workspace/evaluation/01_formalization/minitwit_gdpr.rex -o /tmp/minitwit_eval01 && \
	ls -lh /tmp/gdpr_eval01.sig /tmp/gdpr_eval01.mfotl /tmp/minitwit_eval01.sig /tmp/minitwit_eval01.mfotl
'
```

Both commands were validated in Docker:
- `gdpr_eval01.mfotl` and `gdpr_eval01.sig` were generated successfully
- `minitwit_eval01.mfotl` and `minitwit_eval01.sig` were generated successfully

`-mode doc` compiles a Lex program to a human-readable HTML file.

To install the VS Code extension for `.lex` syntax highlighting:

```bash
code --install-extension vscode/lex/lex-0.0.1.vsix
```

