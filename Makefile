build:
	dune build

clean:
	dune clean

install-deps:
	opam install . --deps-only

install:
	dune build
	opam install .

mli:
	ocamlc -i src/*.ml

# ---------------------------------------------------------------------------
# Artifact evaluation (CCS 2026). See ARTIFACT.md for details.
# ---------------------------------------------------------------------------

CS_DIR       := evaluation/02_case_studies
IMG_LEX      := lex:latest
IMG_ENFFLASH := whyenf-enfflash:latest
IMG_SOCIAL   := gdprsocial:latest
IMG_FS       := gdprfs:latest

.PHONY: artifact-build artifact-rq1 artifact-rq2 artifact-rq3-fast artifact-rq3-full artifact-clean

# Build every Docker image used by the artifact (Lex compiler + both case studies).
artifact-build:
	git submodule update --init --recursive
	docker build -t $(IMG_LEX) .
	docker build -f $(CS_DIR)/GDPRSocial/Dockerfile.enfflash -t $(IMG_ENFFLASH) $(CS_DIR)
	docker build -f $(CS_DIR)/GDPRSocial/Dockerfile -t $(IMG_SOCIAL) $(CS_DIR)
	docker build -f $(CS_DIR)/GDPRFS/Dockerfile -t $(IMG_FS) $(CS_DIR)

# RQ1: compile the three legal formalizations (Table 1) and report LOC.
artifact-rq1:
	./artifact/rq1_formalize.sh

# RQ1: GDPR coverage by F/C/E/I category (Table 2).
artifact-rq1-table2:
	./artifact/rq1_table2.sh

# RQ2: report the instrumented/baseline LOC breakdown (Table 3).
artifact-rq2:
	./artifact/rq2_loc.sh

# RQ3: latency benchmark, baseline + enforced/no-LLM (safe default, no --privileged, no API key).
artifact-rq3-fast:
	./artifact/rq3_benchmark.sh fast

# RQ3 (optional, full): also exercises GDPRFS's FUSE + LLM path.
# Requires --privileged/--device /dev/fuse and OPENAI_API_KEY.
artifact-rq3-full:
	./artifact/rq3_benchmark.sh full

artifact-clean:
	-docker rmi $(IMG_LEX) $(IMG_ENFFLASH) $(IMG_SOCIAL) $(IMG_FS)
