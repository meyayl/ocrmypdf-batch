ARG IMAGE_VERSION="17.8.1-0"
ARG IMAGE_CREATED="2026-07-24"
FROM ubuntu:24.04 AS base

ARG DEBIAN_FRONTEND=noninteractive
ARG IMAGE_VERSION
ARG IMAGE_CREATED
# renovate: datasource=pypi depName=ocrmypdf
ARG OCRMYPDF_VERSION="17.8.1"

RUN apt-get update \
    && apt-get install --yes --no-install-recommends \
      python3 \
      python3-venv \
      ghostscript \
      icc-profiles-free \
      libxml2 \
      liblept5 \
      libsm6 libxext6 libxrender-dev \
      zlib1g \
      pngquant \
      qpdf \
      unpaper \
      tesseract-ocr \
      tesseract-ocr-deu \
      tesseract-ocr-eng \
      tesseract-ocr-fra \
      tesseract-ocr-por \
      tesseract-ocr-spa \
      inotify-tools \
      jbig2 \
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

ENV IN_FOLDER="/in"  \
    OUT_FOLDER="/out" \
    PROCESSED_FOLDER="/processed" \
    OCRMYPDF_OPTIONS="-l deu+eng" \
    MAP_UID="1001" \
    MAP_GID="1001"

LABEL org.opencontainers.image.title="meyay/ocrmypdf-batch"
LABEL org.opencontainers.image.description="A Docker image that wraps OCRmyPDF (with jbig2 and unpaper) for unattended batch OCR of scanned PDFs"
LABEL org.opencontainers.image.version="${IMAGE_VERSION}"
LABEL org.opencontainers.image.created="${IMAGE_CREATED}"
LABEL org.opencontainers.image.licenses="LGPL-2.1"
LABEL org.opencontainers.image.documentation="https://github.com/meyayl/ocrmypdf-batch"
LABEL org.opencontainers.image.source="https://github.com/meyayl/ocrmypdf-batch"
LABEL org.opencontainers.image.url="https://github.com/meyayl/ocrmypdf-batch"
