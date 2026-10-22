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
IMG_CLOC     := lex-cloc:latest
# Parallel jobs for the opam builds in the Lex and EnfFlash images.
OPAMJOBS     ?= 4

.PHONY: artifact-build artifact-policies artifact-rq1 artifact-rq1-table2 artifact-rq2 artifact-rq3-fast artifact-rq3-full artifact-table4 artifact-clean

# Build every Docker image used by the artifact (Lex compiler, both case studies,
# and cloc for RQ2).
# The case-study policies are compiled from their .rex sources (artifact-policies)
# before the application images are built.
artifact-build:
	git submodule update --init --recursive
	docker build --build-arg OPAMJOBS=$(OPAMJOBS) -t $(IMG_LEX) .
	./artifact/compile_policies.sh
	docker build --build-arg OPAMJOBS=$(OPAMJOBS) -f $(CS_DIR)/GDPRSocial/Dockerfile.enfflash -t $(IMG_ENFFLASH) $(CS_DIR)
	docker build -f $(CS_DIR)/GDPRSocial/Dockerfile -t $(IMG_SOCIAL) $(CS_DIR)
	docker build -f $(CS_DIR)/GDPRFS/Dockerfile -t $(IMG_FS) $(CS_DIR)
	docker build -f artifact/Dockerfile.cloc -t $(IMG_CLOC) artifact

# Compile the GDPRSocial/GDPRFS refinements (.rex) into the policies the apps enforce.
artifact-policies:
	./artifact/compile_policies.sh

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

# RQ3: aggregate the latest RQ3 CSVs into Table 4's layout (run after artifact-rq3-*).
artifact-table4:
	./artifact/rq3_table4.sh

artifact-clean:
	-docker rmi $(IMG_LEX) $(IMG_ENFFLASH) $(IMG_SOCIAL) $(IMG_FS) $(IMG_CLOC)
