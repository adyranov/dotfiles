#!/usr/bin/env bash

function backup_file {
    target="$1"

    if [ -e "${target}" ] && [ ! -L "${target}" ]; then
        mv ${target} ${target}.df.bak
        echo "Backed up ${target}"
    fi
}

function restore_file {
    target="$1"

    if [ -e "${target}.df.bak" ] && [ -L "${target}" ]; then
        unlink ${target}
        mv ${target}.df.bak ${target}
        echo "Restored ${target}"
    fi
}

for i in $(find . -name "_*")
do
    source="${PWD}/${i/.\//}"
    target="${HOME}/${i/.\/_/.}"
    if [ "$1" = "restore" ]; then
       restore_file ${target}
    else
        backup_file ${target}
        ln -sfn ${source} ${target}
    fi
done

for i in $(find . -name "+*")
do
    source_folder="${PWD}/${i/.\//}"
    target_folder="${HOME}/${i/.\/+/.}"

    if [ ! -e "${target_folder}" ]; then
        mkdir ${target_folder}
        chmod --reference ${source_folder} ${target_folder}
        echo "Created directory ${target_folder}"
    fi

    for k in ${source_folder}/*
    do
      source="${k}"
      target="${source/${source_folder}/${target_folder}}"
      if [ "$1" = "restore" ]; then
          restore_file ${target}
      else
          backup_file ${target}
          ln -sf ${source} ${target}
      fi
    done
done
