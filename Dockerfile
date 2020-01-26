FROM ubuntu:19.10 AS download
RUN apt update \
    && apt install --yes wget upx gcc libc-dev \
    && wget -L -O /usr/local/bin/gosu https://github.com/tianon/gosu/releases/download/1.11/gosu-amd64 \
    && chmod +x /usr/local/bin/gosu \
    && strip /usr/local/bin/gosu \
    && upx -q /usr/local/bin/gosu

FROM ubuntu:19.10 AS builder
RUN apt-get update && apt-get install --yes --no-install-recommends \
      build-essential autoconf automake libtool \
      libleptonica-dev \
      zlib1g-dev \
      curl \
      ca-certificates \
      upx gcc libc-dev \
    && mkdir jbig2 \
    && curl -L https://github.com/agl/jbig2enc/archive/0.29.tar.gz | tar xz -C jbig2 --strip-components=1 \
    && cd jbig2 \
    && ./autogen.sh && ./configure && make && make install \
    && cd .. \
    && rm -rf jbig2 \
    && strip /usr/local/bin/jbig2 \
    && upx -q /usr/local/bin/jbig2

FROM ubuntu:19.10

LABEL org.label-schema.build-date=$BUILD_DATE \
      org.label-schema.name="OCRmyPDF" \
      org.label-schema.description="orcympdf batch processor" \
      org.label-schema.vcs-url="https://github.com/jbarlow83/OCRmyPDF" \
      org.label-schema.vcs-ref=$VCS_REF \
      org.label-schema.version=$VERSION \
      org.label-schema.schema-version="1.0"

ENV IN_FOLDER=/in  OUT_FOLDER=/out PROCESSED_FOLDER=/processed OCRMYPDF_OPTIONS="-l deu+eng" UID=0 GID=0

RUN apt update \
    && apt-get install --yes --no-install-recommends \
      ocrmypdf \
      ghostscript \
      img2pdf \
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

COPY --from=builder /usr/local/lib/*.so* /usr/local/lib/
COPY --from=builder /usr/local/bin/ /usr/local/bin/
COPY --from=download /usr/local/bin/gosu /usr/local/bin/gosu
VOLUME ["/in", "/out", "/processed"]

COPY /root/entrypoint.sh /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
