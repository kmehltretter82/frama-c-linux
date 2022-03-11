#!/bin/sh -e
# --------------------------------------------------------------------------
# ---  Generate Files for Ivette Distribution
# --------------------------------------------------------------------------

Distribute() {
    repo=$1
    Distrib=$repo/Makefile.distrib
    Headers=$repo/headers/header_spec.txt
    rm -f $Distrib
    rm -f $Headers
    mkdir -p $1/headers
    if [ "$repo" == "." ]
    then
        src=ivette
    else
        src=ivette/$repo
    fi
    echo "Distributing $src"
    for f in $(git -C $repo ls-files .)
    do
        case $f in
            Makefile.distrib | headers/* )
            ;;
            *)
                echo "DISTRIB_FILES += $src/$f" >> $Distrib
                case $f in
                    *.sh | *.json | */dome/doc/* | configure.js | .* | webpack*.js )
                        echo "$f: .ignore" >> $Headers
                        ;;
                    *Make* | *.js* | *.ts* | *.ml*)
                        echo "$f: CEA_LGPL" >> $Headers
                        ;;
                    *)
                        echo "$f: .ignore" >> $Headers
                        ;;
                esac
        esac
    done
    chmod a-w $Distrib
    chmod a-w $Headers
    if [ "$repo" != "." ]
    then
        echo "include ivette/$Distrib" >> Makefile.plugins
    fi
}

Distribute .
rm -f Makefile.plugins
for rgit in $(find src -type d -name ".git")
do
    Distribute $(dirname $rgit)
done
chmod -f a-w Makefile.plugins
