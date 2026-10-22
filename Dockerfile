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

# WORKDIR creates missing directories as root, and COPY --chown does not
# change the ownership of the destination directory itself.
RUN mkdir -p /home/opam/lex && chown opam:opam /home/opam/lex

USER opam
WORKDIR /home/opam/lex
COPY --chown=opam:opam . /home/opam/lex

# Limit opam's build parallelism (opam's default is nproc); building Z3 with one
# job per core can exhaust memory on many-core machines. Lower it with
# --build-arg OPAMJOBS=2 (make artifact-build OPAMJOBS=2) if memory is tight.
ARG OPAMJOBS=4
ENV OPAMJOBS=${OPAMJOBS}

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
    && dune build \
    && chmod -R a+rX /home/opam
# (chmod: the artifact scripts run this image as the host user, via
# docker run --user, on a bind-mounted checkout; the opam switch under
# /home/opam must therefore be readable by any user.)

# Run commands directly instead of through the base image's `opam exec --`
# entrypoint, which writes logs under /home/opam/.opam and therefore fails for
# any other user. Login shells (sh -lc ..., bash -l) load the opam environment
# from ~/.profile.
ENTRYPOINT []
CMD ["bash", "-l"]