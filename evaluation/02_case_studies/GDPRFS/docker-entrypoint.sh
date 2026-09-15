#!/bin/bash
# docker-entrypoint.sh
#
# Starts all GDPRFS services before running the requested command.
#
# Modes:
#   baseline         – no FUSE required; runs immediately
#   gdpr_no_llm      – starts consent/purpose platforms + FUSE daemon
#   gdpr_with_llm    – same + LLM Analyzer (requires OPENAI_API_KEY)
#
# Usage:
#   docker run --rm gdprfs:latest                        # baseline (default)
#   docker run --rm --privileged --device /dev/fuse \
#       gdprfs:latest python3 -m benchmark.simple --mode gdpr_no_llm --n 3
#   docker run --rm --privileged --device /dev/fuse \
#       -e OPENAI_API_KEY=sk-... \
#       gdprfs:latest python3 -m benchmark.simple --mode gdpr_with_llm --n 3

set -e

APP=/app
PYTHON=python3
FUSE_MOUNT=/tmp/mnt

# ── Determine whether the requested mode needs FUSE ─────────────────────────
# Scan all args for --mode <val> or --mode=<val>
REQUESTED_MODE="baseline"
PREV=""
for arg in "$@"; do
    if [ "$PREV" = "--mode" ]; then
        REQUESTED_MODE="$arg"
    fi
    case "$arg" in
        --mode=*) REQUESTED_MODE="${arg#--mode=}" ;;
    esac
    PREV="$arg"
done

NEEDS_FUSE=false
if [ "$REQUESTED_MODE" = "gdpr_no_llm" ] || [ "$REQUESTED_MODE" = "gdpr_with_llm" ] || [ "$REQUESTED_MODE" = "all" ]; then
    NEEDS_FUSE=true
fi

# ── Baseline: just run the command directly ──────────────────────────────────
if ! $NEEDS_FUSE; then
    cd "$APP"
    exec "$@"
fi

# ── FUSE mode: pre-flight checks ─────────────────────────────────────────────
if [ ! -c /dev/fuse ]; then
    echo "[entrypoint] ERROR: /dev/fuse not available."
    echo "  Run the container with: --privileged --device /dev/fuse"
    exit 1
fi

echo "[entrypoint] FUSE device present – starting full GDPRFS stack..."

# Allow FUSE 'allow_other' option (needed when running as root inside container)
if ! grep -q 'user_allow_other' /etc/fuse.conf 2>/dev/null; then
    echo 'user_allow_other' >> /etc/fuse.conf
fi

# Create required directories
mkdir -p /var/lib/gdprfs/upper \
         /var/lib/gdprfs/mirror \
         /var/lib/gdprfs/access_responses
mkdir -p "$FUSE_MOUNT"
chmod 777 "$FUSE_MOUNT"

# ── Wait helper ──────────────────────────────────────────────────────────────
wait_for_port() {
    local name="$1" port="$2" retries="${3:-30}"
    echo -n "[entrypoint] Waiting for $name (port $port)"
    for i in $(seq 1 "$retries"); do
        if python3 -c "import socket; s=socket.socket(); s.settimeout(1); s.connect(('127.0.0.1',$port)); s.close()" 2>/dev/null; then
            echo " ready."
            return 0
        fi
        echo -n "."
        sleep 1
    done
    echo " TIMEOUT waiting for $name"
    return 1
}

# ── External Consent Platform (port 5000) ────────────────────────────────────
echo "[entrypoint] Starting External Consent Platform..."
cd "$APP/external_consent_platform"
PYTHONPATH="$APP/external_consent_platform:$APP" "$PYTHON" app.py &
ECP_PID=$!

# ── Internal Purpose Platform (port 8000) ────────────────────────────────────
echo "[entrypoint] Starting Internal Purpose Platform..."
cd "$APP/internal_purpose_platform"
PYTHONPATH="$APP/internal_purpose_platform:$APP" "$PYTHON" app.py &
IPP_PID=$!

# ── LLM Analyzer (port 5005) – only if key is set ────────────────────────────
LLM_PID=""
if [ -n "${OPENAI_API_KEY:-}" ]; then
    echo "[entrypoint] Starting LLM Analyzer..."
    cd "$APP/LLManalyzer"
    PYTHONPATH="$APP/LLManalyzer:$APP" "$PYTHON" api.py &
    LLM_PID=$!
elif [ "$REQUESTED_MODE" = "gdpr_with_llm" ]; then
    echo "[entrypoint] WARNING: OPENAI_API_KEY not set; LLM Analyzer will not start."
    echo "  Pass -e OPENAI_API_KEY=sk-... to the docker run command."
fi

# ── Wait for web services ─────────────────────────────────────────────────────
wait_for_port "External Consent Platform" 5000
wait_for_port "Internal Purpose Platform" 8000
if [ -n "$LLM_PID" ]; then
    wait_for_port "LLM Analyzer" 5005
fi

# ── Initialise GDPRFS database (idempotent) ───────────────────────────────────
echo "[entrypoint] Initialising GDPRFS database..."
cd "$APP"
PYTHONPATH="$APP" "$PYTHON" gdprfs/setup_db.py 2>&1 | grep -v "^$" || true

# ── FUSE daemon (ports 7000 ingest + mounts /tmp/mnt) ────────────────────────
echo "[entrypoint] Starting FUSE daemon (mount: $FUSE_MOUNT)..."
cd "$APP"
PYTHONPATH="$APP" \
    INSTRLIB_EXE="${INSTRLIB_EXE:-/opt/whyenf/enfguard}" \
    "$PYTHON" gdprfs/myfs.py "$FUSE_MOUNT" -f -o allow_other &
FUSE_PID=$!

wait_for_port "FUSE ingest server" 7000 180

# Brief settle: let the enforcer process its initial log
sleep 2

echo "[entrypoint] All services running. Starting benchmark..."

# ── Cleanup on exit ───────────────────────────────────────────────────────────
cleanup() {
    echo "[entrypoint] Shutting down services..."
    fusermount3 -u "$FUSE_MOUNT" 2>/dev/null || umount -l "$FUSE_MOUNT" 2>/dev/null || true
    kill "$FUSE_PID" "$ECP_PID" "$IPP_PID" ${LLM_PID:+"$LLM_PID"} 2>/dev/null || true
}
trap cleanup EXIT

cd "$APP"
exec "$@"
