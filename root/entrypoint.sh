#!/bin/bash
export LC_ALL=C.UTF-8
export LANG=C.UTF-8

check_permissions(){

  if [ "$UID" == "0" ]; then
     echo "User is root, will change permissions on target files to be readable and writeble by everyone!"
  else 
    is_owner=true

    for folder in $IN_FOLDER $OUT_FOLDER $PROCESSED_FOLDER; do

      owner_uid=$(stat --format '%u' "${folder}")
      owner_gid=$(stat --format '%g' "${folder}")

      if [ $owner_uid -ne $UID ]; then
        echo "User UID: $UID, folder UID: $owner_uid - missmatch for folder ${folder}"
        is_owner=false
      fi 

      if [ $owner_gid -ne $GID ]; then
        echo "User GID: $GID, folder GID: $owner_gid - missmatch for folder ${folder}"
        is_owner=false
      fi

    done

    if [ "${is_owner}" != "true" ]; then 
      echo "Please correct the UID/GID environment variable before restarting the container"
      exit 1
    else 
      echo "User is the owner the folders"
    fi
  fi

}

process_file(){

  current_file="${1}"
  
  if [[ "${current_file,,}" =~ .*pdf$ ]]; then
    echo "-------------------------------------------------------------------"
    echo "Processing file: ${current_file}"
    gosu ${UID}:${GID} ocrmypdf ${OCRMYPDF_OPTIONS} "${IN_FOLDER}/${current_file}" "${OUT_FOLDER}/${current_file}"
    if [ $? -eq 0 ]; then
      echo "Successfully processed file and moved file to ${PROCESSED_FOLDER}" 
      gosu ${UID}:${GID} mv --force "${IN_FOLDER}/${current_file}" "${PROCESSED_FOLDER}/${current_file}"
      if [ $UID -eq 0 ] && [ $GID -eq 0 ]; then
        chmod 666 "${OUT_FOLDER}/${current_file}"
      fi
    fi
  fi

}

echo "Verify ownership of folders"
check_permissions

echo "Processing existing files in ${IN_FOLDER}"
for existing_file in $IN_FOLDER/*; do
  process_file "${existing_file##*/}"
done

echo "Processing new files created in or moved to ${IN_FOLDER}"
inotifywait -m $IN_FOLDER -e create -e moved_to |
  while read path action file; do
    process_file "${file}"
  done



