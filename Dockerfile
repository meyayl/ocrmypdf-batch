FROM ubuntu:22.04 as base

FROM base AS download
ENV DEBIAN_FRONTEND=noninteractive

RUN set -eu; \ 
    apt-get update; \
    apt-get install --yes wget upx gcc libc-dev; \
    wget -L -O /usr/local/bin/gosu https://github.com/tianon/gosu/releases/download/1.11/gosu-amd64; \
    chmod +x /usr/local/bin/gosu; \
    strip /usr/local/bin/gosu; \
    upx -q /usr/local/bin/gosu;

FROM base AS builder
ENV DEBIAN_FRONTEND=noninteractive

RUN set -eu; \
    apt-get update; \
	apt-get install --yes --no-install-recommends \
      build-essential autoconf automake libtool \
      libleptonica-dev \
      zlib1g-dev \
      curl \
      ca-certificates \
      git upx gcc libc-dev; \
    git clone https://github.com/agl/jbig2enc; \
    cd jbig2enc; \
    ./autogen.sh; \
	./configure; \
	make; \
	make install; \
    cd ..; \
    rm -rf jbig2; \
    strip /usr/local/bin/jbig2; \
    upx -q /usr/local/bin/jbig2

FROM base
ENV DEBIAN_FRONTEND=noninteractive

LABEL org.label-schema.build-date=$BUILD_DATE \
      org.label-schema.name="OCRmyPDF" \
      org.label-schema.description="orcympdf batch processor" \
      org.label-schema.vcs-url="https://github.com/meyayl/ocrmypdf-batch" \
      org.label-schema.vcs-ref=$VCS_REF \
      org.label-schema.version=$VERSION \
      org.label-schema.schema-version="1.0"

ENV IN_FOLDER=/in  OUT_FOLDER=/out PROCESSED_FOLDER=/processed OCRMYPDF_OPTIONS="-l deu+eng" UID=0 GID=0

RUN apt-get update \
    && apt-get install --yes --no-install-recommends \
      ghostscript \
      icc-profiles-free \
      libxml2 \
      pngquant \
      python3-pip \
      liblept5 \
      libsm6 libxext6 libxrender-dev \
      zlib1g \
      pngquant \
      python3 \
      qpdf \
      unpaper \
      tesseract-ocr \
      tesseract-ocr-deu \
      tesseract-ocr-eng \
      tesseract-ocr-fra \
      tesseract-ocr-por \
      tesseract-ocr-spa \
      inotify-tools \
    && rm -rf /var/lib/apt/lists/* /tmp/* \
    && mkdir --mode=777 /in \
    && mkdir --mode=777 /out \
    && mkdir --mode=777 /processed

RUN pip3 install ocrmypdf

COPY --from=builder /usr/local/lib/*.so* /usr/local/lib/
COPY --from=builder /usr/local/bin/ /usr/local/bin/
COPY --from=download /usr/local/bin/gosu /usr/local/bin/gosu
VOLUME ["/in", "/out", "/processed"]

COPY /root/entrypoint.sh /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
