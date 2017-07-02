#!/bin/bash

DIRECTORIES_TO_SYNC=$1

if [ $# -ne 1 ]; then
  echo 'illegal number of parameters'
  exit -1
fi

if [ ! -f "$1" ]; then
  echo 'The specified argument is not a file'
  exit -1
fi

rm store
echo $DIRECTORIES_TO_SYNC
cat $DIRECTORIES_TO_SYNC

while read SYNC_DIRECTORY;
  do
    CURRENT_SOURCE="$(id -un)@$(hostname --long)"
    SYNC_SOURCE=$(echo $SYNC_DIRECTORY | cut -f1 -d':')
    DIRECTORY=$(echo $SYNC_DIRECTORY | cut -f2 -d':')

    if [ "$SYNC_SOURCE" == "$CURRENT_SOURCE" ]; then
      ls $DIRECTORY | while read subdir;
        do
          SYNCABLE_SUBDIRECTORY="$(readlink -f $DIRECTORY)/$subdir"
          if [ -d "$SYNCABLE_SUBDIRECTORY/.git" ]; then # check if the subdirectory is a git repository
            NUM_AFFECTED_FILES=$(git --git-dir "$SYNCABLE_SUBDIRECTORY/.git" --work-tree "$SYNCABLE_SUBDIRECTORY" status -s | wc -l)
            if [ "$NUM_AFFECTED_FILES" -gt 0 ]; then
                git --git-dir "$SYNCABLE_SUBDIRECTORY/.git" --work-tree "$SYNCABLE_SUBDIRECTORY" diff HEAD -p > "$(basename $SYNCABLE_SUBDIRECTORY).patch"
            fi
          else
            echo "$SYNCABLE_SUBDIRECTORY" >> store
          fi
        done
    fi
  done < "$DIRECTORIES_TO_SYNC"

  NUM_PATCHES=$(ls *.patch | wc -l)
  if [ "$NUM_PATCHES" -ge 1 ]; then
    NUM_PATCH_ARCHIVES=$(ls patches*.tar.gz | wc -l)
    tar -czvf "patches-$NUM_PATCH_ARCHIVES.tar.gz" --files-from <(ls *.patch)
    rm *.patch
  fi

  NUM_STORES=$(cat store | wc -l)
  if [ "$NUM_PATCHES" -ge 1 ]; then
    NUM_STORE_ARCHIVES=$(ls stores*.tar.gz | wc -l)
    cat store
    tar -czvf "stores-$NUM_STORE_ARCHIVES.tar.gz" --files-from store --exclude=node_modules
    rm store
  fi

exit 0
