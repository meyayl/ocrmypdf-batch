# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A Docker image that wraps OCRmyPDF (with jbig2 and unpaper) for unattended batch OCR of scanned PDFs. There is no application source code — the entire project is a `Dockerfile`, a single shell entrypoint script, and a GitHub Actions pipeline that builds/tests/publishes the image. Changes to this repo are almost always edits to one of those, or to `README.md`.

## Architecture

- `Dockerfile` — multi-stage build on `ubuntu:24.04`.
  - `download` stage fetches the `su-exec` static binary for the target arch (amd64/arm64) and is discarded except for that binary. Requires `ca-certificates` to be installed alongside `wget` — without it there's no CA trust store for the HTTPS fetch.
  - Final stage installs Tesseract (with `deu`, `eng`, `fra`, `por`, `spa` language packs), Ghostscript, `unpaper`, `jbig2`, `qpdf`, `pngquant`, `inotify-tools`, and installs `ocrmypdf` itself (pinned via `ARG OCRMYPDF_VERSION`) into a Python venv at `/app`. Ghostscript stays installed even though `ocrmypdf` also ships `pypdfium2` as a pip dependency — Ghostscript is still needed as the fallback renderer for `--output-type pdfa`.
  - `/in`, `/out`, `/processed` are declared as volumes and created with mode 777.
  - `root/entrypoint.sh` is copied to `/entrypoint.sh` and set as the `ENTRYPOINT`.
  - `ARG` version pins (`OCRMYPDF_VERSION`, `SU_EXEC_VERSION`) are each preceded by a `# renovate: datasource=... depName=...` comment so Renovate (see `renovate.json`) can bump them automatically — keep that pairing intact when changing either. Both must stay double-quoted (`="x.y.z"`) for the regex to match.
  - `IMAGE_VERSION`/`IMAGE_CREATED` build args and OCI labels are normally overridden by the pipeline's `compute-version` job (see below); the in-file defaults only matter for a manual `docker build .` with no `--build-arg`s.

- `root/entrypoint.sh` — the entire runtime logic:
  1. If the container's command is `help` (e.g. `docker run ... help`), it `exec`s `ocrmypdf -h` and exits immediately — no permission checks, no folder access. This is also how the README tells users to look up `OCRMYPDF_OPTIONS` flags, since the flag list isn't duplicated in the README anymore.
  2. `check_permissions()` — if `MAP_UID` is `0`, runs as root and warns that output will be world read/write. Otherwise verifies that `IN_FOLDER`/`OUT_FOLDER`/`PROCESSED_FOLDER` are owned by `MAP_UID:MAP_GID`, and exits with an error telling the user to fix ownership if not. It never chowns anything itself.
  3. `process_file()` — given a filename, if it ends in `.pdf` (case-insensitive), runs `ocrmypdf ${OCRMYPDF_OPTIONS} "${IN_FOLDER}/<file>" "${OUT_FOLDER}/<file>"` via `su-exec ${MAP_UID}:${MAP_GID}` (always, unconditionally — see the non-root limitation below). On success, moves the source file to `PROCESSED_FOLDER` and, if still running as root, `chmod 666`s the output file. On failure, logs an error and leaves the file in `IN_FOLDER` for retry on next restart.
  4. On startup, processes every existing file in `IN_FOLDER`, then watches it via `inotifywait` (`create`/`moved_to`) for new files, calling `process_file` per event.
  5. Graceful shutdown: a `SIGTERM`/`SIGINT` trap sets a `terminate` flag. The watch loop uses `read -t 1` (not a plain blocking read — a blocking `read` on a pipe is *not* reliably interrupted by a trapped signal in bash, it just retries on EINTR) so it periodically rechecks the flag even when idle. Whatever file is currently mid-`process_file` is allowed to finish; no new file is started once the flag is set.

  **Known limitation, not a bug to "fix" casually**: `su-exec` is called unconditionally by `process_file`, even to self-target the UID/GID the process is already running as. `su-exec` always calls `setgroups()`/`setuid()`/`setgid()`, which need real `CAP_SETUID`/`CAP_SETGID` in the process's *effective* capability set. Docker's `cap_add` only expands the *bounding* set for a non-root `user:`, not the effective set — so running the whole container as a non-root Docker user (rather than root + `MAP_UID`/`MAP_GID` + `su-exec`) does not work, confirmed empirically (`su-exec: setgroups(1001): Operation not permitted`). Only the root-container + `MAP_UID`/`MAP_GID` pattern is supported. Fixing this for real would mean skipping `su-exec` in `process_file` when already running as the target UID/GID — a deliberate future change, not something to do incidentally.

- Configuration is entirely environment-variable driven (see README for the full table): `IN_FOLDER`, `OUT_FOLDER`, `PROCESSED_FOLDER`, `OCRMYPDF_OPTIONS`, `MAP_UID`, `MAP_GID`. `OCRMYPDF_OPTIONS` is passed through unquoted/unescaped to `ocrmypdf`. The valid flag list isn't duplicated in the README — it's looked up live via `docker run --rm <image> help`.

## CI/CD (`.github/`)

- `workflows/pipeline.yaml` — the main pipeline (multi-arch build, integration tests, CVE scans, tagged releases, dual publish to GHCR + Docker Hub). Adapted from the sibling repo `../docker-languagetool`'s pipeline; job structure mirrors it closely.
  - `compute-version` derives the image tag from `Dockerfile`'s `ARG OCRMYPDF_VERSION` line as `${OCRMYPDF_VERSION}-N`, where `N` auto-increments per existing matching git tag. On a tag push, the tag itself is the version. The `on.push.tags` filter (`[0-9]+.[0-9]+.[0-9]+-[0-9]+`) uses GitHub's glob dialect, not regex — `+` here means "one or more of the preceding atom", not a literal plus.
  - `integration-test-image` runs the `.github/tests/*.yml` compose variants (see below) on both `ubuntu-latest` and `ubuntu-24.04-arm` runners.
  - Requires these secrets to actually succeed: `DOCKERHUB_USERNAME`, `DOCKERHUB_TOKEN`, `RELEASE_APP_ID`, `RELEASE_APP_PRIVATE_KEY` (a GitHub App used for tag creation, since tags pushed with the default `GITHUB_TOKEN` don't retrigger workflows).
- `workflows/reusable-super-linter.yaml` — generic reusable Super-Linter wrapper, called with `devops-only: true` (this repo has no application-language code to lint).
- `linters/` — Super-Linter sub-tool configs. `.hadolint.yaml` ignores `DL3008` (unpinned apt package versions — deliberate policy, not an oversight) and `DL3047` (wget without a progress bar).
- `tests/*.yml` — docker-compose variants for `integration-test-image`, all bind-mounting `/in`, `/out`, `/processed` (required for this project, unlike optional volumes in other images):
  - `privileged-defaults.yml` — root container, no `MAP_UID`/`MAP_GID` override (zero-config path).
  - `privileged-rw.yml` — root container, `MAP_UID`/`MAP_GID=1001` (the su-exec drop-privilege path).
  - `privileged-ro.yml` — same as `-rw` plus `read_only: true` + `tmpfs: [/tmp:exec]` (immutable rootfs; ocrmypdf/tesseract still need `/tmp` scratch space).
  - There is deliberately no `unprivileged-*` variant — see the non-root limitation above.
  - Non-`defaults` variants need their bind-mounted host folders pre-chowned to `1001:1001` before `docker compose up` (the entrypoint verifies ownership but never fixes it). Do this via a disposable container (`docker run --rm -v ...:/in ... --entrypoint=chown <image> -R 1001:1001 /in /out /processed`), not host-level `sudo chown` — more portable, and doesn't depend on the runner having passwordless sudo.
  - The integration test drops `tests/fixtures/sample.pdf` (a synthetic, no-real-data image-only PDF) into `/in` and retries the copy (via `cp` to a temp name + `mv`, which re-triggers a `moved_to` event) if the output hasn't appeared yet — a single fire-and-forget write occasionally misses its `inotify` event on some Docker backends, so the retry isn't optional defensive fluff.
- `renovate.json` — the Dockerfile custom-manager regex matches *any* `# renovate: datasource=... depName=...` comment immediately followed by `ARG ..._VERSION="..."`; this is why both `OCRMYPDF_VERSION` and `SU_EXEC_VERSION` must stay quoted.

## Working in this repo

- Local build/run without CI:
  ```sh
  docker build -t ocrmypdf-batch .
  docker run --rm -v $PWD/in:/in -v $PWD/out:/out -v $PWD/processed:/processed ocrmypdf-batch
  ```
  Drop a scanned PDF into `./in` before/while the container is running to exercise the OCR path. `docker run --rm ocrmypdf-batch help` prints `ocrmypdf`'s own `--help` and exits without touching any volumes.
- `in/`, `out/`, and `processed/` at the repo root (and under `.github/tests/`) are local scratch/test volumes (gitignored) — not part of the shipped image content.
- To test multi-arch changes to the `Dockerfile` locally: `docker buildx build --platform linux/amd64,linux/arm64 -t ocrmypdf-batch:test .` (or one platform at a time — this is how the amd64 arch-detection bug and the missing `ca-certificates` bug were both caught).
- To lint the `Dockerfile` the same way CI does: `docker run --rm -v "$PWD/Dockerfile:/Dockerfile:ro" -v "$PWD/.github/linters/.hadolint.yaml:/.hadolint.yaml:ro" hadolint/hadolint hadolint -c /.hadolint.yaml /Dockerfile`.
- To validate workflow YAML: `docker run --rm -v "$PWD:/repo" -w /repo rhysd/actionlint:latest` catches more than plain YAML syntax checks (e.g. mismatched reusable-workflow inputs).
- When changing installed Tesseract language packs or other apt packages, update the "Installed Tesseract-OCR languages" line in `README.md` to match.
- When bumping the `ocrmypdf` pin, no README update is needed for flags anymore (it points at `docker run ... help` instead of a static list) — just update `ARG OCRMYPDF_VERSION` in the `Dockerfile`.
