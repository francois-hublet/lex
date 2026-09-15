ARG ENFFLASH_IMAGE=whyenf-enfflash:latest
FROM ${ENFFLASH_IMAGE} AS enfflash

FROM python:3.13-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        build-essential \
        libz3-4 \
        psmisc \
    && rm -rf /var/lib/apt/lists/* \
    && ln -s /usr/lib/x86_64-linux-gnu/libz3.so.4 /usr/lib/x86_64-linux-gnu/libz3.so

COPY GDPRSocial/requirements.txt ./requirements.txt
RUN pip install --no-cache-dir -r requirements.txt

COPY GDPRSocial /app
RUN rm -rf /app/instrlib
COPY instrlib /app/instrlib
COPY --from=enfflash /opt/whyenf/enfguard /opt/whyenf/enfguard
COPY --from=enfflash /usr/local/bin/enfflash /usr/local/bin/enfflash
RUN chmod +x /opt/whyenf/enfguard /usr/local/bin/enfflash

EXPOSE 8000

ENV INSTRLIB_EXE=/opt/whyenf/enfguard

CMD ["python", "manage.py", "runserver", "0.0.0.0:8000", "--noreload"]