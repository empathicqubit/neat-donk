#! /bin/bash
FILENAMES=("$@")
declare -A SEEN
((I = 0))
set -m
which inotifywait >/dev/null
function checker {
    inotifywait -q -m -e close_write "${FILENAMES[@]}" | while read LINE ; do
        if ! [ ${SEEN["$LINE"]+y} ] ; then
            SEEN["$LINE"]=1
            echo "$LINE"
        fi ;
        TOTAL=${#SEEN[@]}
        COUNT=$#
        if ((TOTAL == COUNT)) ; then
            kill -s TERM 0
        fi
    done
}
checker &
wait