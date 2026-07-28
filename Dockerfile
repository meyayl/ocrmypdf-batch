ARG IMAGE_VERSION="17.8.1-0"
ARG IMAGE_CREATED="2026-07-24"
FROM ubuntu:24.04 AS  base

FROM base AS download
ARG TARGETARCH
ARG DEBIAN_FRONTEND=noninteractive
# renovate: datasource=github-releases depName=ncopa/su-exec
ARG SU_EXEC_VERSION="0.3"

RUN set -eux; \
    apt-get update; \
    apt-get install --yes --no-install-recommends ca-certificates wget; \
    case "${TARGETARCH}" in \
        amd64) ARCH="x86_64" ;; \
        arm64) ARCH="arm64" ;; \
        *) echo "Unsupported architecture: ${TARGETARCH}"; exit 1 ;; \
    esac; \
    wget -L -O /usr/local/bin/su-exec "https://github.com/ncopa/su-exec/releases/download/v${SU_EXEC_VERSION}/su-exec-static-v${SU_EXEC_VERSION}-${ARCH}"; \
    chmod +x /usr/local/bin/su-exec

FROM base
ARG IMAGE_VERSION
ARG IMAGE_CREATED
ARG DEBIAN_FRONTEND=noninteractive
# renovate: datasource=pypi depName=ocrmypdf
ARG OCRMYPDF_VERSION="17.8.1"

COPY --from=download /usr/local/bin/su-exec /usr/local/bin/su-exec

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
    && mkdir --mode=777 /in \
    && mkdir --mode=777 /out \
    && mkdir --mode=777 /processed

VOLUME ["/in", "/out", "/processed"]

COPY /root/entrypoint.sh /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]

ENV IN_FOLDER="/in"  \
    OUT_FOLDER="/out" \
    PROCESSED_FOLDER="/processed" \
    OCRMYPDF_OPTIONS="-l deu+eng" \
    MAP_UID="0" \
    MAP_GID="0"

LABEL org.opencontainers.image.title="meyay/ocrmypdf-batch"
LABEL org.opencontainers.image.description="A Docker image that wraps OCRmyPDF (with jbig2 and unpaper) for unattended batch OCR of scanned PDFs"
LABEL org.opencontainers.image.version="${IMAGE_VERSION}"
LABEL org.opencontainers.image.created="${IMAGE_CREATED}"
LABEL org.opencontainers.image.licenses="LGPL-2.1"
LABEL org.opencontainers.image.documentation="https://github.com/meyayl/ocrmypdf-batch"
LABEL org.opencontainers.image.source="https://github.com/meyayl/ocrmypdf-batch"
LABEL org.opencontainers.image.url="https://github.com/meyayl/ocrmypdf-batch"
