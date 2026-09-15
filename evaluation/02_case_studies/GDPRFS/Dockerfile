# ──────────────────────────────────────────────────────────────────────────────
# GDPRFS – Docker image
#
# Supports all three benchmark modes:
#   baseline         – plain filesystem, no FUSE (default)
#   gdpr_no_llm      – FUSE + EnfGuard enforcer, LLM disabled
#   gdpr_with_llm    – FUSE + EnfGuard enforcer + LLM analyzer
#
# FUSE modes require a privileged container:
#   docker run --rm --privileged --device /dev/fuse gdprfs:latest \
#       python3 -m benchmark.simple --mode gdpr_no_llm --n 3
#
# Build (from evaluation/02_case_studies/ directory):
#   docker build -f GDPRSocial/Dockerfile.enfflash -t whyenf-enfflash:latest .
#   docker build -f GDPRFS/Dockerfile -t gdprfs:latest .
# ──────────────────────────────────────────────────────────────────────────────

ARG ENFFLASH_IMAGE=whyenf-enfflash:latest
FROM ${ENFFLASH_IMAGE} AS enfflash

FROM python:3.13-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

# System deps:
#   libfuse-dev + fuse   – FUSE2 dev headers + userspace tools (for fuse-python + FUSE daemon)
#   fuse3                – fusermount3 (used in cleanup / reset)
#   poppler-utils        – pdftotext for PDF content analysis
#   build-essential      – compilers needed to build fuse-python C extension
#   curl                 – used by entrypoint readiness checks (fast; avoids Python import)
#   libz3-4              – runtime shared library for the enfguard/enfflash enforcer binary
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        build-essential \
        curl \
        fuse \
        fuse3 \
        libfuse-dev \
        libz3-4 \
        pkg-config \
        poppler-utils \
    && echo 'user_allow_other' >> /etc/fuse.conf \
    && rm -rf /var/lib/apt/lists/* \
    && ln -s /usr/lib/x86_64-linux-gnu/libz3.so.4 /usr/lib/x86_64-linux-gnu/libz3.so

# Install Python dependencies (includes fuse-python built against libfuse-dev above)
COPY GDPRFS/requirements.txt ./requirements.txt
RUN pip install --no-cache-dir -r requirements.txt

# Copy the GDPRFS application
COPY GDPRFS /app

# Replace the app-local instrlib with the shared canonical version
RUN rm -rf /app/instrlib
COPY instrlib /app/instrlib

# Reuse binaries built in the shared WhyEnf image (same setup as GDPRSocial)
COPY --from=enfflash /opt/whyenf/enfguard /opt/whyenf/enfguard
COPY --from=enfflash /usr/local/bin/enfflash /usr/local/bin/enfflash
RUN chmod +x /opt/whyenf/enfguard /usr/local/bin/enfflash \
    && rm -rf /app/enfguard

# Create /var/lib/gdprfs structure (template PDF + placeholder files)
RUN mkdir -p /var/lib/gdprfs/upper \
             /var/lib/gdprfs/mirror \
             /var/lib/gdprfs/access_responses \
    && python3 -c "from reportlab.pdfgen import canvas; from reportlab.lib.pagesizes import A4; c=canvas.Canvas('/var/lib/gdprfs/redacted_template.pdf',pagesize=A4); c.setFont('Helvetica',16); c.drawCentredString(A4[0]/2,A4[1]/2,'redacted by GDPRFS'); c.save()" \
    && touch /var/lib/gdprfs/.gdprowner

# Initialise the GDPRFS SQLite database (creates gdprfs.db in /app)
RUN cd /app && PYTHONPATH=/app python3 gdprfs/setup_db.py

# Entrypoint: starts all services when FUSE modes are requested
COPY GDPRFS/docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh

EXPOSE 5000 7000 8000 8005

ENTRYPOINT ["/docker-entrypoint.sh"]

# Default: baseline benchmark (no FUSE required)
CMD ["python3", "-m", "benchmark.simple", "--mode", "baseline", "--n", "3"]
