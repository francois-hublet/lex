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
dune exec -- ./bin/main.exe <path/to/.lex file> [-mode (mfotl|doc|owl|owlgraph)]
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

### Exporting declarations as an OWL ontology

`-mode owl` compiles the *declarations* of a `.lex` or `.rex` program — its
types and its events and predicates, but not its rules — to an
[OWL](https://www.w3.org/TR/owl-ref/) ontology, serialized in RDF/XML (MIME type
`application/rdf+xml`):

```bash
dune exec -- ./bin/main.exe example/tutorial/tutorial.lex -mode owl -o tutorial.owl
```

Without `-o`, the ontology is written next to the input file, with the extension
`.owl` appended. The ontology IRI defaults to
`https://lex-lang.org/ontology/<name>`, where `<name>` is the name of the input
file; use `-ns <IRI>` to choose another one.

Declarations are encoded as follows:

* every declared type becomes an `owl:Class`, whether or not it has a base type.
  A Lex type is a sort of its own — `type purpose is string` says how purposes
  are written down, not that a purpose *is* a string — so an atomic base type is
  recorded as a `lex:baseType` annotation and nothing more;
* a type whose base type is another declared type becomes a subclass of it, so
  the type refinements of a `.rex` file are reflected in the ontology;
* an event or predicate becomes an `owl:Class`, i.e. a
  [reified n-ary relation](https://www.w3.org/TR/swbp-n-aryRelations/), with one
  functional property per argument, restricted to exactly one value. An argument
  ranging over a declared type gives an `owl:ObjectProperty`; only an argument
  declared directly with an atomic type (`t : span`) gives an
  `owl:DatatypeProperty`, ranging over the matching XML Schema datatype.

Events and predicates are not distinguished in the ontology: both are relations
declared by the program, and both become subclasses of `lex:Declaration`.

Documentation strings are exported as `rdfs:comment`. Lex-specific information
that has no OWL counterpart — the enforcement type of a declaration, the
position of an argument — is exported as annotations in the
`https://lex-lang.org/ontology/core#` namespace.

### Drawing the ontology

`-mode owlgraph` draws the same declarations as a class diagram, and writes it
to a PNG file:

```bash
dune exec -- ./bin/main.exe example/GDPR/gdpr.lex -mode owlgraph -o gdpr.png
```

Without `-o`, the diagram is written next to the input file, with the extension
`.png` appended. This mode requires [Graphviz](https://graphviz.org) — the
`sfdp` command must be on the `PATH`.

Each event and predicate is drawn as a box labelled with its enforcement type
and coloured by it, listing the arguments declared directly with an atomic type;
an argument ranging over a declared type is drawn as an edge to that type
instead. As in the ontology, events and predicates are not told apart. Declared
types are the ochre ellipses, with their atomic base type in parentheses where
they have one, and a dashed generalization links a type to its base type.

### Restricting to one section

Both modes accept `-section`, which keeps only the vocabulary of one section of
the law:

```bash
dune exec -- ./bin/main.exe example/GDPR/gdpr.lex -mode owlgraph -section "article 6"
```

A section is given as a sequence of section kinds and names, from the outermost
to the innermost — `"article 6"`, or `"article 6 paragraph 1 point b"` to narrow
it further. Intermediate levels may be skipped, and nesting levels are ignored,
so `"paragraph 1"` also matches a `paragraph[1] "1"`. Names containing spaces
are not supported.

Kept are the events and predicates mentioned by the rules of that section, the
types their arguments range over, and the types those types are built from. A
declaration that no rule of the section mentions is not part of its vocabulary,
even if it is written under it.

Without `-o`, the section is appended to the name of the output file, e.g.
`gdpr.lex-article-6.png`.

To install the VS Code extension for `.lex` syntax highlighting:

```bash
code --install-extension vscode/lex/lex-0.0.1.vsix
```

