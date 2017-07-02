#!/bin/bash

DIRECTORIES_TO_SYNC=$1

if [ $# -lt 1 ]; then
  echo 'Illegal number of parameters'
  exit -1
fi

if [ ! -f "$1" ]; then
  echo 'The first argument must be file'
  exit -1
fi

DESTINATION=''
if [ $# -gt 1 ] && [ -d "$2" ]; then
  DESTINATION=$2
elif [ $# -gt 1 ] && [ ! -d "$2" ]; then
  echo 'The second argument must be a valid directory'
  exit -1
fi

IGNORE_FILE=''
if [ $# -gt 2 ] && [ -f "$3" ]; then
  IGNORE_FILE=$3
elif [ $# -gt 2 ] && [ ! -f "$3" ]; then
  echo 'The third argument must be a file'
  exit -1
fi

rm ./store

while read -r SYNC_DIRECTORY;
  do
    CURRENT_SOURCE="$(id -un)@$(hostname --long)"
    SYNC_SOURCE=$(echo "$SYNC_DIRECTORY" | cut -f1 -d':')
    DIRECTORY=$(echo "$SYNC_DIRECTORY" | cut -f2 -d':')

    if [ "$SYNC_SOURCE" == "$CURRENT_SOURCE" ]; then
      find "$DIRECTORY" -maxdepth 1 -mindepth 1 | while read -r subdir;
        do
          if [ -d "$subdir/.git" ]; then # check if the subdirectory is a git repository
            NUM_AFFECTED_FILES=$(git --git-dir "$subdir"/.git --work-tree "$subdir" status -s | wc -l)
            if [ "$NUM_AFFECTED_FILES" -gt 0 ]; then
              git --git-dir "$subdir/.git" --work-tree "$subdir" diff HEAD -p > "$(basename $subdir).patch"
            fi
          else
            echo "$subdir" >> store
          fi
        done
    fi
  done < "$DIRECTORIES_TO_SYNC"

  NUM_PATCHES=$(find . -maxdepth 1 -mindepth 1 -name '*.patch'| wc -l)
  if [ "$NUM_PATCHES" -ge 1 ]; then
    if [ "$DESTINATION" != "" ]; then
      NUM_PATCH_ARCHIVES=$(find "$DESTINATION" -maxdepth 1 -mindepth 1 -name 'patches*.tar.gz' | wc -l)
    else
      NUM_PATCH_ARCHIVES=$(find . -maxdepth 1 -mindepth 1 -name 'patches*.tar.gz' | wc -l)
    fi

    if [ "$IGNORE_FILE" != "" ]; then
      tar -czvf "patches-$NUM_PATCH_ARCHIVES.tar.gz" --files-from <(find . -maxdepth 1 -mindepth 1 -name '*.patch') -X "$IGNORE_FILE"
    else
      tar -czvf "patches-$NUM_PATCH_ARCHIVES.tar.gz" --files-from <(find . -maxdepth 1 -mindepth 1 -name '*.patch') --exclude=node_modules
    fi
    rm ./*.patch
  fi

  NUM_STORES=$(wc -l < store)
  if [ "$NUM_STORES" -ge 1 ]; then
    if [ "$DESTINATION" != "" ]; then
      NUM_STORE_ARCHIVES=$(find "$DESTINATION" -maxdepth 1 -mindepth 1 -name 'stores*.tar.gz' | wc -l)
    else
      NUM_STORE_ARCHIVES=$(find . -maxdepth 1 -mindepth 1 -name 'stores*.tar.gz' | wc -l)
    fi

    if [ "$IGNORE_FILE" != "" ]; then
      tar -czvf "stores-$NUM_STORE_ARCHIVES.tar.gz" --files-from store -X "$IGNORE_FILE"
    else
      tar -czvf "stores-$NUM_STORE_ARCHIVES.tar.gz" --files-from store --exclude=node_modules
    fi

    rm ./store
  fi

  if [ "$DESTINATION" != "" ]; then
    mv "./stores-$NUM_STORE_ARCHIVES.tar.gz" "./patches-$NUM_PATCH_ARCHIVES.tar.gz" "$DESTINATION/"
  fi

exit 0
