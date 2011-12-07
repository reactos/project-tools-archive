#!/bin/bash
#
# Quick rapps links checker
# Copyright 2011 Pierre Schweitzer <pierre@reactos.org>
#
# Released under GNU GPL v2 or any later version.

rm all_links.txt 1>&2 2>/dev/null
cat *.txt > all_links.txt

while read line
do
	link=`echo $line | grep "URLDownload" | tr -d '\n' | tr -d '\r' | awk '{print $3}'`
	if [ ! -z "$link" ]; then
		echo "Testing $link..."
		wget --spider --force-html $link
	fi
done < "all_links.txt"

rm all_links.txt
