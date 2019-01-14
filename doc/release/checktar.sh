#!/bin/bash -eu

echo "To check: "

find . -name '*NE_PAS_LIVRER*'
find . -name '*nonfree*' -o -name '*non_free*' -o -name '*non-free*'

PLUGINS=( genassigns mthread volatile acsl-importer caveat-importer cfp security pathcrawler a3export )

for A in ${PLUGINS[@]}
do
    if [ -e src/plugins/$A ]; then
        echo "!!! Error: trying to release $A"
    fi
done
