[![](https://images.microbadger.com/badges/image/meyay/ocrmypdf-batch.svg)](https://microbadger.com/images/meyay/ocrmypdf-batch "Get your own image badge on microbadger.com")[![](https://images.microbadger.com/badges/version/meyay/ocrmypdf-batch.svg)](https://microbadger.com/images/meyay/ocrmypdf-batch "Get your own version badge on microbadger.com")[![](https://images.microbadger.com/badges/commit/meyay/ocrmypdf-batch.svg)](https://microbadger.com/images/meyay/ocrmypdf-batch "Get your own commit badge on microbadger.com")
# ocrmypdf-batch

OCRmyPDF 9.0.3. batch processing image with jbig2 and unpaper.   

On container start it will process all existing PDF files in the IN_FOLDER, once existing files are processed, it registers iNotify watches on the IN_FOLDER and waits for new files that are copied or moved to the IN_FOLDER. It will only process image based PDF files and ignore PDF files that are already text based.

During file processing, the target files will be written in the OUT_FOLDER. Every successfully processed PDF file will be moved into the PROCESSED_FOLDER.

If you scanner is able to send PDF-Files to a file share, you could use that folder as the IN_FOLDER and let this container do it's magic.

If you need to modify the OCRmyPDF options, you will need to delete and re-create the container using the new options in the ENV OCRMYPDF_OPTIONS. Synology users can simply stop the container, modify the ENV values and restart it.

Installed Tesseract-OCR languages: deu, eng, fra, por, spa

## Docker CLI Usage 
```sh
docker run -d \
 --name=ocrmypdf-batch \
 --volume $PWD/read-only:/read-only \
 --volume $PWD/read-write:/read-write \
 --volume $PWD/merged:/merged \
  meyay/ocrmypdf-batch:9.0.3
```
## Docker Compose Usage 
```
version: '2.2'
services:
  ocrmypdf-batch:
    image: meyay/ocrmypdf:9.0.3
    container_name: ocrmypdf-batch
    volumes:
    - $PWD/in:/in:rw
    - $PWD/processed:/processed:rw
    - $PWD/out:/out:rw
```

## Parameters
The environment parameters are split into two halves, separated by an equal, the left hand side representing the host and the right the container side.

IN_FOLDER=/in  OUT_FOLDER=/out PROCESSED_FOLDER=/processed OCRMYPDF_OPTIONS="-l deu+eng" UID=0 GID=0

| ENV| DEFAULT | DESCRIPTION |
| ------ | ------ | ------ |
| IN_FOLDER | /in | Optional: path inside the container. See VOLUMES table for description. |
| OUT_FOLDER | /out | Optional: path inside the container. See VOLUMES table for description.|
| PROCESSED_FOLDER| /processed | Optional: path inside the container. See VOLUMES table for description.|
| OCRMYPDF_OPTIONS| -l deu+eng |  Optional: command line parameters for OCRmyPDF, see list of options below. |
| UID | 0 | Optional: user id to be used to execute OCRmyPDF, if a UID different then 0 is used, it must match the owner of the folders |
| GID | 0 | Optional: group id to be used to execute OCRmyPDF, if a GID different then 0 is used, it must match the owner of the folders |

The volume parameters are split into two halves, separated by a colon, the left hand side representing the host and the right the container side.

| VOLUMES |  DESCRIPTION |
| ------ | ------ |
| /in |  Mount point for incomming files. Needs to match IN_FOLDER. |
| /out | Mount point for final files. Needs to match OUT_FOLDER. |
| /processed |  Mount point for processed orignals. Needs to match PROCESSED_FOLDER. |

##ä OCRmyPDF Parameters for use with OCRMMPYDF_OPTIONS 

[-h] [-l LANGUAGE] [--image-dpi DPI]
[--output-type {pdfa,pdf,pdfa-1,pdfa-2,pdfa-3}]
[--sidecar [FILE]] [--version] [-j N] [-q] [-v [VERBOSE]]
[--title TITLE] [--author AUTHOR] [--subject SUBJECT]
[--keywords KEYWORDS] [-r] [--remove-background] [-d] [-c]
[-i] [--unpaper-args UNPAPER_ARGS] [--oversample DPI]
[--remove-vectors] [--threshold] [-f] [-s] [--redo-ocr]
[--skip-big MPixels] [-O {0,1,2,3}] [--jpeg-quality Q]
[--png-quality Q] [--jbig2-lossy] [--pages PAGES]
[--max-image-mpixels MPixels] [--tesseract-config CFG]
[--tesseract-pagesegmode PSM] [--tesseract-oem MODE]
[--pdf-renderer {auto,hocr,sandwich}]
[--tesseract-timeout SECONDS]
[--rotate-pages-threshold CONFIDENCE]
[--pdfa-image-compression {auto,jpeg,lossless}]
[--user-words FILE] [--user-patterns FILE]
[--fast-web-view MEGABYTES] [-k]


## Shell access
For shell access while the container is running, `docker exec -it ocrmypdf-batch /bin/bash`
