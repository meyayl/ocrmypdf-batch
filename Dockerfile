ARG IMAGE_VERSION="17.10.0-0"
ARG IMAGE_CREATED="2026-08-06"
FROM ubuntu:24.04@sha256:d78ab76437b1afc5f01e223d6bf0172763f404bb166441328845adbef44518cb AS base

ARG DEBIAN_FRONTEND=noninteractive
ARG IMAGE_VERSION
ARG IMAGE_CREATED
# renovate: datasource=pypi depName=ocrmypdf
ARG OCRMYPDF_VERSION="17.10.0"

RUN apt-get update \
    && apt-get install --yes --no-install-recommends \
        python3 \
        python3-venv \
        ghostscript \
        tesseract-ocr \
        tesseract-ocr-deu \
        tesseract-ocr-eng \
        tesseract-ocr-fra \
        tesseract-ocr-por \
        tesseract-ocr-spa \
        inotify-tools \
        icc-profiles-free \
        libxml2 \
        liblept5 \
        libsm6 libxext6 libxrender-dev \
        zlib1g \
        qpdf \
        unpaper \
        jbig2 \
        pngquant \
    && rm -rf /var/lib/apt/lists/* /tmp/*

RUN python3 -m venv /app \
    && /app/bin/python3 -m pip install --upgrade pip \
    && /app/bin/pip install "ocrmypdf==${OCRMYPDF_VERSION}" \
    && rm -rf /tmp/* \
    && chmod -R a+rX /app

RUN groupadd --gid 1001 ocrmypdf \
    && useradd --uid 1001 --gid 1001 --no-create-home --shell /usr/sbin/nologin ocrmypdf \
    && mkdir -p /in /out /processed \
    && chown 1001:1001 /in /out /processed

VOLUME ["/in", "/out", "/processed"]

COPY /root/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

USER 1001:1001
ENTRYPOINT ["/entrypoint.sh"]

# Confirms the watch loop (inotifywait) is still alive; checked via /proc
# directly since procps isn't installed and pulling it in just for pgrep/ps
# isn't worth the extra package.
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD grep -aq inotifywait /proc/[0-9]*/cmdline 2>/dev/null || exit 1

ENV IN_FOLDER="/in"  \
    OUT_FOLDER="/out" \
    PROCESSED_FOLDER="/processed" \
    OCRMYPDF_OPTIONS="-l deu+eng"

LABEL org.opencontainers.image.title="meyay/ocrmypdf-batch"
LABEL org.opencontainers.image.description="A Docker image that wraps OCRmyPDF (with jbig2 and unpaper) for unattended batch OCR of scanned PDFs"
LABEL org.opencontainers.image.version="${IMAGE_VERSION}"
LABEL org.opencontainers.image.created="${IMAGE_CREATED}"
LABEL org.opencontainers.image.licenses="LGPL-2.1"
LABEL org.opencontainers.image.documentation="https://github.com/meyayl/ocrmypdf-batch"
LABEL org.opencontainers.image.source="https://github.com/meyayl/ocrmypdf-batch"
LABEL org.opencontainers.image.url="https://github.com/meyayl/ocrmypdf-batch"
