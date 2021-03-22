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

errors=0

IFS=''
while read file
do
    if [ -n "$(is_likely_text_file "$file")" ]; then
        x=$(tail -c 1 "$file")
        if [ "$x" != "" ] && [ "$file" != "VERSION" ] && [ "$file" != "VERSION_CODENAME" ]; then
            echo "error: no newline at end of file: $file"
            errors=$((errors+1))
        fi
    fi
done < <(file -f "$1" --mime | grep '\btext' | cut -d: -f1)

if [ $errors -gt 0 ]; then
    echo "Found $errors file(s) with errors."
    exit 0
fi
