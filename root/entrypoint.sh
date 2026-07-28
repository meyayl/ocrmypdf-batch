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

  if [ "${MAP_UID}" == "0" ]; then
    echo "⚠️ User is root, will change permissions on target files to be readable and writable by everyone!"
  else 
    is_owner=true

    for folder in ${IN_FOLDER} ${OUT_FOLDER} ${PROCESSED_FOLDER}; do

      ls=$(stat --format '%u' "${folder}")
      owner_gid=$(stat --format '%g' "${folder}")

      if [ ${owner_uid} -ne ${MAP_UID} ]; then
        echo "❌ User UID: ${MAP_UID}, folder UID: ${owner_uid} - missmatch for folder ${folder}"
        is_owner=false
      fi 

      if [ ${owner_gid} -ne ${MAP_GID} ]; then
        echo "❌ User GID: ${MAP_GID}, folder GID: ${owner_gid} - missmatch for folder ${folder}"
        is_owner=false
      fi

    done

    if [ "${is_owner}" != "true" ]; then 
      echo "🛑 Please correct the MAP_UID/MAP_GID environment variable before restarting the container"
      exit 1
    else
      echo "✅ User is the owner the folders"
    fi
  fi

}

process_file(){

  current_file="${1}"
  
  if [[ "${current_file,,}" =~ .*pdf$ ]]; then
    echo "📄 Processing file: ${current_file}"
    if su-exec "${MAP_UID}:${MAP_GID}" ocrmypdf ${OCRMYPDF_OPTIONS} "${IN_FOLDER}/${current_file}" "${OUT_FOLDER}/${current_file}"; then
      echo "✅ Successfully processed file and moved file to ${PROCESSED_FOLDER}"
      su-exec "${MAP_UID}:${MAP_GID}" mv --force "${IN_FOLDER}/${current_file}" "${PROCESSED_FOLDER}/${current_file}"
      if [ ${MAP_UID} -eq 0 ] && [ ${MAP_GID} -eq 0 ]; then
        chmod 666 "${OUT_FOLDER}/${current_file}"
      fi
    else
      echo "❌ Error processing file: ${current_file}, leaving it in ${IN_FOLDER}"
    fi
  fi

}

echo "🔍 Verify ownership of folders"
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
