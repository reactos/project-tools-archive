#!/bin/bash
REPOS="$1"
TXN="$2"
SVNLOOK="$3"

while read changeline;
do
    file=${changeline:4}
    if [ "text/plain;charset=UTF-16" == "`$SVNLOOK propget -t \"$TXN\" \"$REPOS\" svn:mime-type \"$file\" 2> /dev/null`" ]
    then
        if [ "${changeline:0:1}" == "D" ]; then
            continue
        fi
        contents=`$SVNLOOK cat -t "$TXN" "$REPOS" "$file"`
        if [ "`echo ${contents:0:2}`" != $'\xff\xfe' ]
        then
            echo "$file has to be encoded in UTF16LE." >&2
            exit 1
        fi
    fi
done < <($SVNLOOK changed -t "$TXN" "$REPOS")


