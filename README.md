[![Docker Pulls](https://img.shields.io/docker/pulls/meyay/ocrmypdf-batch)](https://hub.docker.com/r/meyay/ocrmypdf-batch)  ![Docker Image Version (latest semver)](https://img.shields.io/docker/v/meyay/ocrmypdf-batch) ![Docker Image Size (latest semver)](https://img.shields.io/docker/image-size/meyay/ocrmypdf-batch) [![Open Issues](https://img.shields.io/github/issues-search/meyayl/ocrmypdf-batch?query=is%3Aissue%20state%3Aopen&label=Open%20Issues)](https://github.com/meyayl/ocrmypdf-batch/issues?q=is%3Aissue%20state%3Aopen)

# ocrmypdf-batch

A Docker image that watches a folder and turns scanned PDFs into searchable, text-based PDFs — automatically, unattended, forever.

Built on [OCRmyPDF](https://github.com/ocrmypdf/OCRmyPDF), with `jbig2` for smaller PDF/A files and `unpaper` for descreening and cleanup.

## Features

- **Set-and-forget watching** — OCRs every existing PDF in `IN_FOLDER` on startup, then watches for new files via `inotify`.
- **Skips what's already done** — ignores PDFs that are already text-based; only image-based PDFs get OCR'd. (OCRmyPDF feature)
- **Keeps originals safe** — the searchable copy goes to `OUT_FOLDER`; the original is moved to `PROCESSED_FOLDER` only once OCR succeeds.
- **Fails loud, not silent** — a file that errors during processing stays in `IN_FOLDER` with a clear log message, so nothing is lost and it's retried on the next restart. (OCRmyPDF feature)
- **Graceful shutdown** — on `docker stop`, the file currently being processed is allowed to finish before the container exits.
- **Non-root by default** — runs as a dedicated unprivileged user (`1001:1001`), no capabilities required at all. Change the container's user (`--user`/`user:`) to match any other host folder ownership.
- **Multi-arch** — built for both `amd64` and `arm64`.
- **Five languages out of the box** — Tesseract-OCR: `deu`, `eng`, `fra`, `por`, `spa`.

## Quick Start

The container always runs as an unprivileged user — by default `1001:1001`, baked into the image. The host folders it mounts must already be owned by that same UID/GID, so create and `chown` them first:

```sh
mkdir -p in out processed
sudo chown 1001:1001 in out processed
```

### Docker CLI

```sh
docker run -d \
 --name=ocrmypdf-batch \
 --read-only \
 --tmpfs /tmp \
 --cap-drop=ALL \
 --security-opt=no-new-privileges \
 --volume $PWD/in:/in \
 --volume $PWD/out:/out \
 --volume $PWD/processed:/processed \
  meyay/ocrmypdf-batch:latest
```

### Docker Compose

An example [`docker-compose.yml`](docker-compose.yml) is included in this repository:

```yaml
services:
  ocrmypdf-batch:
    image: meyay/ocrmypdf-batch:latest
    container_name: ocrmypdf-batch
    restart: unless-stopped
    read_only: true
    tmpfs:
      - /tmp
    cap_drop:
      - ALL
    security_opt:
      - no-new-privileges
    environment:
      OCRMYPDF_OPTIONS: "-l deu+eng"
    # user: "1000:1000"  # run as a different UID/GID; chown ./in ./out ./processed to match
    volumes:
      - ./in:/in
      - ./out:/out
      - ./processed:/processed
```

Run it with `docker compose up -d`.

Both examples run the container hardened: a read-only root filesystem (with a `tmpfs` for `/tmp`, which `ocrmypdf`/`tesseract` need for scratch space but never execute anything from), every Linux capability dropped with none re-added (nothing the container does needs any capability at all — no root, no privilege dropping), and `no-new-privileges` to block escalation. Verified end-to-end with `cap_drop: ALL` and zero `cap_add`.

To run as a different UID/GID (e.g. to match an existing NAS share), change the container's user (`--user`/`user:`) and the ownership of the host folders together. If they disagree, the container refuses to start with a clear error rather than silently failing partway through.

Drop a scanned PDF into `./in`. A searchable copy appears in `./out`; the original moves to `./processed`. If your scanner can deliver PDFs straight to a network share, point `IN_FOLDER` at that share and let the container do the rest.

## How It Works

1. **Verify permissions** — checks that `IN_FOLDER`, `OUT_FOLDER`, and `PROCESSED_FOLDER` are owned by whichever user the container is actually running as, and that it can enter, read, and write each of them. Exits with a clear error rather than continuing on a partial match.
2. **Process existing files** — every PDF already sitting in `IN_FOLDER` is OCR'd once, in order.
3. **Watch for new files** — an `inotify` watch on `IN_FOLDER` picks up anything created or moved in afterwards.
4. **Shut down gracefully** — `SIGTERM`/`SIGINT` (e.g. `docker stop`) stops the watch loop only after the file currently being processed has finished; no half-written PDFs.

## Environment Variables

| ENV                | Default      | Description                                                                                                     |
|--------------------|--------------|-----------------------------------------------------------------------------------------------------------------|
| `IN_FOLDER`        | `/in`        | Path inside the container watched for incoming PDFs.                                                            |
| `OUT_FOLDER`       | `/out`       | Path inside the container where searchable PDFs are written.                                                    |
| `PROCESSED_FOLDER` | `/processed` | Path inside the container where successfully OCR'd originals are moved.                                         |
| `OCRMYPDF_OPTIONS` | `-l deu+eng` | Command-line options passed straight through to `ocrmypdf` — see [OCRmyPDF Options](#ocrmypdf-options) below.   |

> Changing any environment variable requires recreating the container.

## Volumes

| Volume       | Description                                                         |
| ------------ | ------------------------------------------------------------------- |
| `/in`        | Mount point for incoming files. Must match `IN_FOLDER`.             |
| `/out`       | Mount point for finished, searchable PDFs. Must match `OUT_FOLDER`. |
| `/processed` | Mount point for processed originals. Must match `PROCESSED_FOLDER`. |

## OCRmyPDF Options

`OCRMYPDF_OPTIONS` accepts any command-line option that `ocrmypdf` itself supports. Since that list grows and changes with the `ocrmypdf` version bundled in the image, look it up directly from the container instead of a hardcoded copy here:

```sh
docker run --rm meyay/ocrmypdf-batch:latest help
```

Passing `help` as the container command short-circuits the normal startup — it just prints `ocrmypdf -h` and exits, without touching any volumes.
