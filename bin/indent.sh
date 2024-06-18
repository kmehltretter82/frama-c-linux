##########################################################################
#                                                                        #
#  This file is part of Frama-C.                                         #
#                                                                        #
#  Copyright (C) 2007-2024                                               #
#    CEA (Commissariat à l'énergie atomique et aux énergies              #
#         alternatives)                                                  #
#                                                                        #
#  you can redistribute it and/or modify it under the terms of the GNU   #
#  Lesser General Public License as published by the Free Software       #
#  Foundation, version 2.1.                                              #
#                                                                        #
#  It is distributed in the hope that it will be useful,                 #
#  but WITHOUT ANY WARRANTY; without even the implied warranty of        #
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         #
#  GNU Lesser General Public License for more details.                   #
#                                                                        #
#  See the GNU Lesser General Public License version 2.1                 #
#  for more details (enclosed in the file licenses/LGPLv2.1).            #
#                                                                        #
##########################################################################

# Help

case "$1" in
    "-h"|"--help")
        echo "indent [-h|--help] [DIR|FILE]"
        echo ""
        echo "  Re-indent and remove trailing spaces in OCaml sources."
        echo "  By default, find sources in '.', but can be applied on a"
        echo "  directory or on a single file."
        echo ""
        echo "  Only applies to writable '*.ml' and '*.mli' files."
        exit 0 ;;
esac

# Root file or directory

ROOT="."
if [ "$1" != "" ]
then
    ROOT="$1"
fi

# re-indent and de-spacify all files

for file in $(find $ROOT \( -name "*.ml" -or -name "*.mli" \) -perm -u+w); do
    if file $file | grep -wq "ISO-8859"; then
        echo "Convert $file";
        iconv -f ISO-8859-1 -t UTF-8 $file > $file.tmp;
        mv $file.tmp $file;
    fi;
    echo "Indent  $file"
    sed -e's/[[:space:]]*$//' $file > $file.tmp;
    mv $file.tmp $file;
    ocp-indent -i $file;
done
