#!/bin/bash
export LC_ALL=C.UTF-8
export LANG=C.UTF-8

source /app/bin/activate

if [ "${1}" == "help" ]; then
  exec ocrmypdf -h
fi

terminate=0
trap 'terminate=1' SIGTERM SIGINT

check_permissions(){

  current_uid=$(id -u)
  current_gid=$(id -g)

  if [ "${current_uid}" -ne "${MAP_UID}" ] || [ "${current_gid}" -ne "${MAP_GID}" ]; then
    echo "🛑 Container is running as ${current_uid}:${current_gid}, but MAP_UID/MAP_GID is set to ${MAP_UID}:${MAP_GID}. Start the container with a matching user, e.g. --user ${MAP_UID}:${MAP_GID}"
    exit 1
  fi

  is_ok=true

  for folder in ${IN_FOLDER} ${OUT_FOLDER} ${PROCESSED_FOLDER}; do

    owner_uid=$(stat --format '%u' "${folder}")
    owner_gid=$(stat --format '%g' "${folder}")

    if [ "${owner_uid}" -ne "${MAP_UID}" ] || [ "${owner_gid}" -ne "${MAP_GID}" ]; then
      echo "❌ Folder ${folder} is owned by ${owner_uid}:${owner_gid}, expected ${MAP_UID}:${MAP_GID}"
      is_ok=false
    fi

    [ -x "${folder}" ] || { echo "❌ User ${MAP_UID}:${MAP_GID} cannot enter folder ${folder} (missing execute permission)"; is_ok=false; }
    [ -r "${folder}" ] || { echo "❌ User ${MAP_UID}:${MAP_GID} cannot read folder ${folder} (missing read permission)"; is_ok=false; }
    [ -w "${folder}" ] || { echo "❌ User ${MAP_UID}:${MAP_GID} cannot write folder ${folder} (missing write permission)"; is_ok=false; }

  done

  if [ "${is_ok}" != "true" ]; then
    echo "🛑 Please correct the folder ownership/permissions, or the MAP_UID/MAP_GID environment variables, before restarting the container"
    exit 1
  else
    echo "✅ User ${MAP_UID}:${MAP_GID} owns and can enter, read, and write all folders"
  fi

}

process_file(){

  current_file="${1}"

  if [[ "${current_file,,}" =~ .*pdf$ ]]; then
    echo "📄 Processing file: ${current_file}"
    if ocrmypdf ${OCRMYPDF_OPTIONS} "${IN_FOLDER}/${current_file}" "${OUT_FOLDER}/${current_file}"; then
      echo "✅ Successfully processed file and moved file to ${PROCESSED_FOLDER}"
      mv --force "${IN_FOLDER}/${current_file}" "${PROCESSED_FOLDER}/${current_file}"
    else
      echo "❌ Error processing file: ${current_file}, leaving it in ${IN_FOLDER}"
    fi
  fi

}

echo "🔍 Verify folder ownership and permissions"
check_permissions

echo "📂 Processing existing files in ${IN_FOLDER}"
for existing_file in $IN_FOLDER/*; do
  [ "${terminate}" -eq 0 ] || break
  process_file "${existing_file##*/}"
done

echo "👀 Waiting to process new files created in or moved to ${IN_FOLDER}"
while [ "${terminate}" -eq 0 ]; do
  if read -r -t 1 path action file; then
    process_file "${file}"
  fi
done < <(inotifywait -m "${IN_FOLDER}" -e create -e moved_to)

echo "🛑 Termination signal received, current job finished, shutting down"
