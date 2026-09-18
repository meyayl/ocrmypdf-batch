ARG IMAGE_VERSION="17.11.0-1"
ARG IMAGE_CREATED="2026-08-29"
FROM ubuntu:24.04@sha256:b3cc40b72b93588182b5410f723c7aaf142363311c2aa993d8a453ddcbb3ae15 AS base

ARG DEBIAN_FRONTEND=noninteractive
ARG IMAGE_VERSION
ARG IMAGE_CREATED
# renovate: datasource=pypi depName=ocrmypdf
ARG OCRMYPDF_VERSION="17.12.1"

# renovate: datasource=repology depName=ubuntu_24_04/python3-defaults versioning=deb
ARG PYTHON3_VERSION="3.12.3-0ubuntu2.1"
# renovate: datasource=repology depName=ubuntu_24_04/ghostscript versioning=deb
ARG GHOSTSCRIPT_VERSION="10.02.1~dfsg1-0ubuntu7.8"
# renovate: datasource=repology depName=ubuntu_24_04/tesseract-ocr versioning=deb
ARG TESSERACT_OCR_VERSION="5.3.4-1build5"
# renovate: datasource=repology depName=ubuntu_24_04/tesseract-lang versioning=deb
ARG TESSERACT_LANG_VERSION="1:4.1.0-2"
# renovate: datasource=repology depName=ubuntu_24_04/inotify-tools versioning=deb
ARG INOTIFY_TOOLS_VERSION="3.22.6.0-4"
# renovate: datasource=repology depName=ubuntu_24_04/icc-profiles-free versioning=deb
ARG ICC_PROFILES_FREE_VERSION="2.0.1+dfsg-1.1"
# renovate: datasource=repology depName=ubuntu_24_04/libxml2 versioning=deb
ARG LIBXML2_VERSION="2.9.14+dfsg-1.3ubuntu3.8"
# renovate: datasource=repology depName=ubuntu_24_04/leptonlib versioning=deb
ARG LIBLEPT5_VERSION="1.82.0-3build4"
# renovate: datasource=repology depName=ubuntu_24_04/libsm versioning=deb
ARG LIBSM6_VERSION="2:1.2.3-1build3"
# renovate: datasource=repology depName=ubuntu_24_04/libxext versioning=deb
ARG LIBXEXT6_VERSION="2:1.3.4-1build2"
# renovate: datasource=repology depName=ubuntu_24_04/libxrender versioning=deb
ARG LIBXRENDER_DEV_VERSION="1:0.9.10-1.1build1"
# renovate: datasource=repology depName=ubuntu_24_04/zlib versioning=deb
ARG ZLIB1G_VERSION="1:1.3.dfsg-3.1ubuntu2.2"
# renovate: datasource=repology depName=ubuntu_24_04/qpdf versioning=deb
ARG QPDF_VERSION="11.9.0-1.1ubuntu0.1"
# renovate: datasource=repology depName=ubuntu_24_04/unpaper versioning=deb
ARG UNPAPER_VERSION="7.0.0-3build1"
# renovate: datasource=repology depName=ubuntu_24_04/jbig2enc versioning=deb
ARG JBIG2_VERSION="0.29-2.1build1"
# renovate: datasource=repology depName=ubuntu_24_04/pngquant versioning=deb
ARG PNGQUANT_VERSION="2.18.0-1build2"

RUN apt-get update \
    && apt-get install --yes --no-install-recommends \
        python3=${PYTHON3_VERSION} \
        python3-venv=${PYTHON3_VERSION} \
        ghostscript=${GHOSTSCRIPT_VERSION} \
        tesseract-ocr=${TESSERACT_OCR_VERSION} \
        tesseract-ocr-deu=${TESSERACT_LANG_VERSION} \
        tesseract-ocr-eng=${TESSERACT_LANG_VERSION} \
        tesseract-ocr-fra=${TESSERACT_LANG_VERSION} \
        tesseract-ocr-por=${TESSERACT_LANG_VERSION} \
        tesseract-ocr-spa=${TESSERACT_LANG_VERSION} \
        inotify-tools=${INOTIFY_TOOLS_VERSION} \
        icc-profiles-free=${ICC_PROFILES_FREE_VERSION} \
        libxml2=${LIBXML2_VERSION} \
        liblept5=${LIBLEPT5_VERSION} \
        libsm6=${LIBSM6_VERSION} libxext6=${LIBXEXT6_VERSION} libxrender-dev=${LIBXRENDER_DEV_VERSION} \
        zlib1g=${ZLIB1G_VERSION} \
        qpdf=${QPDF_VERSION} \
        unpaper=${UNPAPER_VERSION} \
        jbig2=${JBIG2_VERSION} \
        pngquant=${PNGQUANT_VERSION} \
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
