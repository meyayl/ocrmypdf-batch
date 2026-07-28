# 📑 ocrmypdf-batch

A Docker image that watches a folder and turns scanned PDFs into searchable, text-based PDFs — automatically, unattended, forever.

Built on [OCRmyPDF](https://github.com/ocrmypdf/OCRmyPDF), with `jbig2` for smaller PDF/A files and `unpaper` for descreening and cleanup.

## ✨ Features

- **Set-and-forget watching** — OCRs every existing PDF in `IN_FOLDER` on startup, then watches for new files via `inotify`.
- **Skips what's already done** — ignores PDFs that are already text-based; only image-based PDFs get OCR'd. (OCRmyPDF feature)
- **Keeps originals safe** — the searchable copy goes to `OUT_FOLDER`; the original is moved to `PROCESSED_FOLDER` only once OCR succeeds.
- **Fails loud, not silent** — a file that errors during processing stays in `IN_FOLDER` with a clear log message, so nothing is lost and it's retried on the next restart. (OCRmyPDF feature)
- **Graceful shutdown** — on `docker stop`, the file currently being processed is allowed to finish before the container exits.
- **Runs as any user** — map to a non-root `MAP_UID`/`MAP_GID` to match your host folder permissions, or leave it at root for zero-config use.
- **Multi-arch** — built for both `amd64` and `arm64`.
- **Five languages out of the box** — Tesseract-OCR: `deu`, `eng`, `fra`, `por`, `spa`.

## 🚀 Quick Start

### Docker CLI
```sh
docker run -d \
 --name=ocrmypdf-batch \
 --volume $PWD/in:/in \
 --volume $PWD/out:/out \
 --volume $PWD/processed:/processed \
  meyay/ocrmypdf-batch:latest
```

### Docker Compose
```yaml
services:
  ocrmypdf-batch:
    image: meyay/ocrmypdf-batch:latest
    container_name: ocrmypdf-batch
    volumes:
      - $PWD/in:/in:rw
      - $PWD/out:/out:rw
      - $PWD/processed:/processed:rw
```

Drop a scanned PDF into `./in`. A searchable copy appears in `./out`; the original moves to `./processed`. If your scanner can deliver PDFs straight to a network share, point `IN_FOLDER` at that share and let the container do the rest.

## 🧠 How It Works

1. **🔍 Verify ownership** — checks that `IN_FOLDER`, `OUT_FOLDER`, and `PROCESSED_FOLDER` are owned by `MAP_UID`/`MAP_GID` (skipped when running as root).
2. **📂 Process existing files** — every PDF already sitting in `IN_FOLDER` is OCR'd once, in order.
3. **👀 Watch for new files** — an `inotify` watch on `IN_FOLDER` picks up anything created or moved in afterwards.
4. **🛑 Shut down gracefully** — `SIGTERM`/`SIGINT` (e.g. `docker stop`) stops the watch loop only after the file currently being processed has finished; no half-written PDFs.

## ⚙️ Environment Variables

| ENV                | Default      | Description |
|--------------------|--------------|--------------|
| `IN_FOLDER`        | `/in`        | Path inside the container watched for incoming PDFs. |
| `OUT_FOLDER`       | `/out`       | Path inside the container where searchable PDFs are written. |
| `PROCESSED_FOLDER` | `/processed` | Path inside the container where successfully OCR'd originals are moved. |
| `OCRMYPDF_OPTIONS` | `-l deu+eng` | Command-line options passed straight through to `ocrmypdf` — see [OCRmyPDF Options](#-ocrmypdf-options) below. |
| `MAP_UID`          | `0`          | User ID `ocrmypdf` runs as. If not `0`, must match the owner of all three folders. |
| `MAP_GID`          | `0`          | Group ID `ocrmypdf` runs as. If not `0`, must match the owner of all three folders. |

> Changing any environment variable requires recreating the container.

## 📁 Volumes

| Volume       | Description |
|--------------|--------------|
| `/in`        | Mount point for incoming files. Must match `IN_FOLDER`. |
| `/out`       | Mount point for finished, searchable PDFs. Must match `OUT_FOLDER`. |
| `/processed` | Mount point for processed originals. Must match `PROCESSED_FOLDER`. |

## 🔧 OCRmyPDF Options

`OCRMYPDF_OPTIONS` accepts any command-line option that `ocrmypdf` itself supports. Since that list grows and changes with the `ocrmypdf` version bundled in the image, look it up directly from the container instead of a hard-coded copy here:

```sh
docker run --rm meyay/ocrmypdf-batch:latest help
```

Passing `help` as the container command short-circuits the normal startup — it just prints `ocrmypdf -h` and exits, without touching any volumes.

