#!/bin/bash -e

# $1: file containing the list of files to check
# prints a warning for each file not finishing with a newline,
# unless it is one of a few well-known exceptions (e.g. VERSION).
# Note: requires the 'file' command-line tool to check which files are text.

if [ $# -lt 1 ]; then
    echo "usage: $0 file_list.txt"
    exit 2
fi

is_likely_text_file() {
    case $(file -b --mime-type - < "$1") in
        (text/*) echo "1"
    esac
}

declare -A exceptions
exceptions=(["VERSION"]=1 ["VERSION_CODENAME"]=1)

errors=0

IFS=''
file -f "$1" --mime | grep '\btext' | cut -d: -f1 |
while read file
do
    if [ -n "$(is_likely_text_file "$file")" ]; then
        x=$(tail -c 1 "$file")
        if [ "$x" != "" ]; then
            if [ ! ${exceptions["$file"]+x} ]; then
                echo "error: no newline at end of file: $file"
                errors=$((errors+1))
            fi
        fi
    fi
done

if [ $errors -gt 0 ]; then
    echo "Found $error(s) files with errors."
    exit 0
fi
