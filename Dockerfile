FROM ocaml/opam:debian-ocaml-4.13

USER root
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        libgmp-dev \
        m4 \
        pkg-config \
        python3 \
        python3-dev \
        z3 \
        libz3-dev \
    && rm -rf /var/lib/apt/lists/*

USER opam
WORKDIR /home/opam/lex
COPY --chown=opam:opam . /home/opam/lex

RUN opam update \
    && opam install -y \
        dune \
        core_unix \
        menhir=20250912 \
        xml-light \
        ppx_jane \
        calendar \
        z3 \
        pyml=20250807 \
        alcotest \
    && eval $(opam env) \
    && dune build

CMD ["bash"]