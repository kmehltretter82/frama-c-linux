#! /usr/bin/env bash

set -u

# Executing this script requires bash 4.0 or higher
# (special use of the 'case' construct)
if test `echo $BASH_VERSION | sed "s/\([0-9]\).*/\1/" ` -lt 4; then
  echo "bash version >= 4 is required."
  exit 99
fi

# git-lfs needs to be installed
if ! command -v git-lfs >/dev/null 2>/dev/null; then
  echo "git-lfs is required"
  exit 99
fi

# Set it to "no" in order to really execute the commands.
# Otherwise, they are only printed.
DEBUG=no
if test \! -e .git ; then
    echo "ERROR: .git directory not found"
    echo "This script must be run at the root of a Frama-C repository"
    exit 1
fi
FRAMAC_BRANCH=`git --git-dir=.git rev-parse --abbrev-ref HEAD`

if test \! -f VERSION ; then
    echo "ERROR: VERSION file not found"
    echo "This script must be run at the root of a Frama-C repository"
    exit 1
fi
FRAMAC_VERSION=$(cat VERSION)
FRAMAC_TAG=$(git describe --tag)
FRAMAC_VERSION_CODENAME=$(cat VERSION_CODENAME)
FRAMAC_VERSION_AND_CODENAME="${FRAMAC_VERSION}-${FRAMAC_VERSION_CODENAME}"
TARGZ_FILENAME=frama-c-${FRAMAC_VERSION_AND_CODENAME}.tar.gz

VERSION_MODIFIER=$(cat VERSION | sed -e s/[A-Za-z]*-[0-9]*\\\(.*\\\)/\\1/)

if test -n "$VERSION_MODIFIER"; then FINAL_RELEASE=no; else FINAL_RELEASE=yes; fi

if test "$FRAMAC_VERSION" != "$FRAMAC_TAG"; then
    echo "WARNING: The current commit is not tagged with the current version:"
    echo "Frama-C Version: $FRAMAC_VERSION"
    echo "Frama-C Tag    : $FRAMAC_TAG"
fi

run () {
  cmd=$1
  echo "$cmd"
  if test "$DEBUG" == "no"; then
    sh -c "$cmd" || { echo "Aborting step ${STEP}."; exit "${STEP}"; }
  fi
}

EACSL_GIT="git@git.frama-c.com:frama-c/e-acsl.git"
EACSL_DIR="./src/plugins/e-acsl"
if test \! -d $EACSL_DIR/.git ; then
    echo "WARNING: $EACSL_DIR/.git directory not found; do you want to clone it? (y/n)"
    read CHOICE
    case "${CHOICE}" in
        "Y"|"y")
            pushd "./src/plugins"
            run "git clone $EACSL_GIT"
            popd
            ;;
        *)
            echo "The E-ACSL repository must be linked at $EACSL_DIR (clone or symbolic link)"
            exit 1
            ;&
    esac
fi
EACSL_BRANCH=`git --git-dir=$EACSL_DIR/.git rev-parse --abbrev-ref HEAD`

GITHUB_DIR=./Frama-C-snapshot
GITHUB_GIT="git@github.com:Frama-C/Frama-C-snapshot.git"

if test ! -d $GITHUB_DIR/.git; then
    echo "WARNING: $GITHUB_DIR/.git directory not found; do you want to clone it? (y/n)"
    read CHOICE
    case "${CHOICE}" in
        "Y"|"y")
            run "git clone $GITHUB_GIT"
            ;;
        *)
            echo "github's Frama-C-snapshot project must be linked at $GITHUB_DIR \
                 (clone or symbolic link)"
            exit 1
            ;&
    esac
fi
GITHUB_BRANCH=$(git --git-dir=$GITHUB_DIR/.git rev-parse --abbrev-ref HEAD)

if test "$FINAL_RELEASE" = "yes" -a "$GITHUB_BRANCH" != "master"; then
    echo "WARNING: your setup will commit (locally) a final release on a non-master branch of Frama-C-snapshot";
fi

if test "$FINAL_RELEASE" = "no" -a "$GITHUB_BRANCH" = "master";
then
    echo "WARNING: your setup will commit (locally) an intermediate release on the master branch of Frama-C-snapshot"
fi

GITHUB_WIKI_GIT="git@github.com:Frama-C/Frama-C-snapshot.wiki.git"
GITHUB_WIKI=./Frama-C-snapshot.wiki
if test ! -d $GITHUB_WIKI/.git; then
    echo "WARNING: $GITHUB_WIKI/.git directory not found; do you want to clone it? (y/n)"
    read CHOICE
    case "${CHOICE}" in
        "Y"|"y")
            run "git clone $GITHUB_WIKI_GIT"
            ;;
        *)
            echo "Frama-C-snapshot wiki must be linked at $GITHUB_WIKI \
                 (clone or symbolic link)"
            exit 1
            ;&
    esac
fi
GITHUB_WIKI_BRANCH=$(git --git-dir=$GITHUB_WIKI/.git rev-parse --abbrev-ref HEAD)

if test "$GITHUB_WIKI_BRANCH" != "master"; then
    echo "WARNING: Frama-C-snapshot's wiki is not on the master branch";
fi

ACSL_GIT="git@github.com:acsl-language/acsl.git"
ACSL_DIR="./doc/acsl"
if test \! -d $ACSL_DIR/.git ; then
    echo "WARNING: $ACSL_DIR/.git directory not found; do you want to clone it? (y/n)"
    read CHOICE
    case "${CHOICE}" in
        "Y"|"y")
            pushd "./doc"
            run "git clone $ACSL_GIT"
            popd
            ;;
        *)
            echo "The Github ACSL repository must be linked at $ACSL_DIR (clone or symbolic link)"
            exit 1
            ;&
    esac
fi



MANUALS_DIR="./doc/manuals"
#if test \! -d $MANUALS_DIR/.git ; then
#    echo "ERROR: $MANUALS_DIR/.git directory not found"
#    echo "The Frama-C manuals repository must linked at $MANUALS_DIR (clone or symbolic link)"
#    exit 1
#fi
#MANUALS_BRANCH=`git --git-dir=$MANUALS_DIR/.git rev-parse --abbrev-ref HEAD`

# push on frama-c.com only for final releases
if test "$FINAL_RELEASE" = "yes"; then
WEBSITE_DIR="./website"
if test \! -d $WEBSITE_DIR/.git ; then
    echo "ERROR: $WEBSITE_DIR/.git directory not found"
    echo "The Frama-C website repository must be linked at $WEBSITE_DIR (clone or symbolic link)"
    exit 1
fi
WEBSITE_BRANCH=`git --git-dir=$WEBSITE_DIR/.git rev-parse --abbrev-ref HEAD`
fi # FINAL_RELEASE == yes

BUILD_DIR_ROOT="/tmp/release"
BUILD_DIR="$BUILD_DIR_ROOT/frama-c"

echo "Frama-C Version         : $FRAMAC_VERSION"
echo "Frama-C Branch          : $FRAMAC_BRANCH"
echo "Final release           : $FINAL_RELEASE"
echo "E-ACSL Dir              : $EACSL_DIR"
echo "E-ACSL Branch           : $EACSL_BRANCH"
echo "Frama-C-snapshot dir    : $GITHUB_DIR"
echo "Frama-C-snapshot branch : $GITHUB_BRANCH"
echo "Frama-C-snapshot wiki   : $GITHUB_WIKI"
echo "Manuals Dir             : $MANUALS_DIR"
#echo "Manuals Branch          : $MANUALS_BRANCH"
if test "$FINAL_RELEASE" = "yes"; then
echo "Website Dir             : $WEBSITE_DIR"
echo "Website Branch          : $WEBSITE_BRANCH"
else
echo "Intermediate release: website not updated"
fi
echo "Build Dir      : $BUILD_DIR"

DOWNLOAD_DIR="www/download"

step () {
  STEP=$1
  echo
  echo "Step $1: $2"
}

export LC_CTYPE=en_US.UTF-8

echo -n "Steps are:
  N) previous information is wrong, STOP the script
  0) compile PDF manuals (will ERASE $MANUALS_DIR!)
  1) reset local copy of target repositories
  2) build the source distribution
  3) build API bundle
  4) build documentation companions
  5) copy and stage locally the distributed manuals
Start at which step? (default is N, which cancels everything)
- If this is the first time running this script, start at 0
- Otherwise, start at the latest step before failure
"
read STEP

case "${STEP}" in
  ""|"N")
    echo "Exiting without doing anything.";
    exit 0;
    ;&
  0)
      step 0 "COMPILING PDF MANUALS"
      run "rm -rf $MANUALS_DIR"
      run "mkdir -p $MANUALS_DIR"
      run "doc/build-manuals.sh"
    ;&
  1)
    run "git -C $GITHUB_DIR reset --hard"
    run "git -C $GITHUB_WIKI reset --hard"
    if test "$FINAL_RELEASE" = "yes"; then
       run "git -C $WEBSITE_DIR reset --hard"
    fi
    ;&
  2)
    step 2 "BUILDING THE SOURCE DISTRIBUTION"
    if ! git diff-index --quiet HEAD --; then
        echo ""
        echo "### WARNING: uncommitted git changes will be discarded when creating archive!"
        echo "Proceed anyway? [y/N]"
        read CHOICE
        case "${CHOICE}" in
            "Y"|"y")
                ;;
            *)
                echo "Stash or commit local changes, then run the script again."
                exit 1
        esac
    fi
    run "mkdir -p $BUILD_DIR_ROOT"
    run "rm -rf $BUILD_DIR"
    run "git worktree add --detach $BUILD_DIR $FRAMAC_BRANCH"
    run "cd $EACSL_DIR; git worktree add --detach $BUILD_DIR/src/plugins/e-acsl $EACSL_BRANCH"
    run "cd $BUILD_DIR; autoconf"
    run "cd $BUILD_DIR; ./configure"
    run "cd $BUILD_DIR; make -j OPEN_SOURCE=yes src-distrib"
    # cleanup Frama-C-snapshot
    for file in $(git -C $GITHUB_DIR ls-files); do
        run "rm $GITHUB_DIR/$file";
    done
    run "git -C $GITHUB_DIR clean -fx"
    run "cd $GITHUB_DIR; tar --strip-components=1 -xzvf $BUILD_DIR/$TARGZ_FILENAME"
    run "git -C $GITHUB_DIR add -A"
    run "mkdir -p $GITHUB_WIKI/downloads"
    run "cp $BUILD_DIR/$TARGZ_FILENAME $GITHUB_WIKI/downloads/"
    if test "$FINAL_RELEASE" = "yes"; then
        SPEC_FILE="$DOWNLOAD_DIR/$TARGZ_FILENAME"
        run "rm -f $WEBSITE_DIR/$SPEC_FILE"
        run "cp $BUILD_DIR/$TARGZ_FILENAME $WEBSITE_DIR/$SPEC_FILE"
        run "git -C $WEBSITE_DIR add $SPEC_FILE"
        run "cp Changelog $WEBSITE_DIR/src/last-release/Changelog"
        run "cp src/plugins/wp/Changelog $WEBSITE_DIR/src/wpChangelog"
        run "cp src/plugins/wp/Changelog $WEBSITE_DIR/src/last-release/wpChangelog"
    fi
    ;&
  3)
    #note: this step may fail if step 4 was performed,
    #      because it will erase BUILD_DIR
    step 3 "BUILDING THE API BUNDLE"
    if test \! -d "$BUILD_DIR" ; then
        echo "ERROR: $BUILD_DIR does not exist, possibly removed by another step"
        exit 1
    fi
    run "cd $BUILD_DIR; make -j doc-distrib"
    if test "$FINAL_RELEASE" = "yes"; then
        SPEC_FILE="$DOWNLOAD_DIR/frama-c-${FRAMAC_VERSION_AND_CODENAME}-api.tar.gz"
        run "rm -f $WEBSITE_DIR/$SPEC_FILE"
        run "cp $BUILD_DIR/frama-c-api.tar.gz $WEBSITE_DIR/$SPEC_FILE"
        run "git -C $WEBSITE_DIR add $SPEC_FILE"
    fi
    ;&
  4)
    step 4 "BUILDING THE DOCUMENTATION COMPANIONS"
    if test \! -d "$BUILD_DIR" ; then
        echo "ERROR: $BUILD_DIR does not exist, possibly removed by another step"
        exit 1
    fi
    run "cd $BUILD_DIR; make -j doc-companions"
    if test "$FINAL_RELEASE" = "yes"; then
        SPEC_FILE="$DOWNLOAD_DIR/hello-${FRAMAC_VERSION_AND_CODENAME}.tar.gz"
        RELE_FILE="$DOWNLOAD_DIR/hello.tar.gz"
        run "rm -f $WEBSITE_DIR/$SPEC_FILE $WEBSITE_DIR/$RELE_FILE"
        run "cp $BUILD_DIR/hello-${FRAMAC_VERSION_AND_CODENAME}.tar.gz $WEBSITE_DIR/$SPEC_FILE"
        run "git -C $WEBSITE_DIR add $SPEC_FILE"
        run "ln -s hello-${FRAMAC_VERSION_AND_CODENAME}.tar.gz $WEBSITE_DIR/$RELE_FILE";
        run "git -C $WEBSITE_DIR add $RELE_FILE"
        run "rm -rf $BUILD_DIR"
        run "git worktree prune"
    fi
    ;&
  5)
    step 5 "COPYING AND STAGING THE DISTRIBUTED MANUALS"
      PAGE_NAME=Frama-C-${FRAMAC_VERSION_AND_CODENAME}.md
      WIKI_PAGE=$GITHUB_WIKI/$PAGE_NAME
      run "mkdir -p $GITHUB_WIKI/manuals"
      run "sed -i -e '/<!-- LAST RELEASE -->/a \
- [${FRAMAC_VERSION} (${FRAMAC_VERSION_CODENAME})](Frama-C-${FRAMAC_VERSION_AND_CODENAME})' $GITHUB_WIKI/Home.md"
      echo "# Frama-C release ${FRAMAC_VERSION} (${FRAMAC_VERSION_CODENAME})" > $WIKI_PAGE
      echo "## Sources" >> $WIKI_PAGE
      echo " - [$TARGZ_FILENAME](downloads/$TARGZ_FILENAME)" >> $WIKI_PAGE
      echo "" >> $WIKI_PAGE
      echo "## Manuals" >> $WIKI_PAGE
    for f in "user-manual" "acsl-implementation" "value-analysis" "plugin-development-guide" "rte-manual" "wp-manual" "metrics-manual" "aorai-manual"; do
        echo "- [$f](manuals/$f-${FRAMAC_VERSION_AND_CODENAME}.pdf)" >> $WIKI_PAGE
        run "cp $MANUALS_DIR/$f.pdf $GITHUB_WIKI/manuals/$f-${FRAMAC_VERSION_AND_CODENAME}.pdf"
        run "git -C $GITHUB_WIKI add manuals/$f-${FRAMAC_VERSION_AND_CODENAME}.pdf"
        if test "$FINAL_RELEASE" = "yes"; then
            SPEC_FILE="$DOWNLOAD_DIR/$f-${FRAMAC_VERSION_AND_CODENAME}.pdf"
            RELE_FILE="$DOWNLOAD_DIR/frama-c-$f.pdf"
            run "rm -f $WEBSITE_DIR/$SPEC_FILE $WEBSITE_DIR/$RELE_FILE"
            run "cp $MANUALS_DIR/$f.pdf $WEBSITE_DIR/$SPEC_FILE";
            run "ln -s $f-${FRAMAC_VERSION_AND_CODENAME}.pdf $WEBSITE_DIR/$RELE_FILE";
            run "git -C $WEBSITE_DIR add $SPEC_FILE"
            run "git -C $WEBSITE_DIR add $RELE_FILE"
        fi
    done
    for f in "aorai-example"; do
        if test "$FINAL_RELEASE" = "yes"; then
            SPEC_FILE="$DOWNLOAD_DIR/$f-${FRAMAC_VERSION_AND_CODENAME}.tgz"
            RELE_FILE="$DOWNLOAD_DIR/frama-c-$f.tgz"
            run "rm -f $WEBSITE_DIR/$SPEC_FILE $WEBSITE_DIR/$RELE_FILE"
            run "cp $MANUALS_DIR/$f.tgz $WEBSITE_DIR/$SPEC_FILE";
            run "ln -s $f-${FRAMAC_VERSION_AND_CODENAME}.tgz $WEBSITE_DIR/$RELE_FILE";
            run "git -C $WEBSITE_DIR add $SPEC_FILE"
            run "git -C $WEBSITE_DIR add $RELE_FILE"
        fi
    done

    for f in "acsl"; do
      ACSL_VERSION=`cat doc/acsl/ACSL_VERSION`
      if test "$FINAL_RELEASE" = "yes"; then
          SPEC_FILE="$DOWNLOAD_DIR/${f}-${ACSL_VERSION}.pdf"
          RELE_FILE="$DOWNLOAD_DIR/$f.pdf"
          run "rm -f $WEBSITE_DIR/$SPEC_FILE $WEBSITE_DIR/$RELE_FILE"
          run "cp $MANUALS_DIR/$f.pdf $WEBSITE_DIR/$SPEC_FILE";
          run "ln -s ${f}-${ACSL_VERSION}.pdf $WEBSITE_DIR/$RELE_FILE";
          run "git -C $WEBSITE_DIR add $SPEC_FILE"
          run "git -C $WEBSITE_DIR add $RELE_FILE"
      fi
    done
    for f in "e-acsl-manual" "e-acsl-implementation"; do
        echo "- [$f](manuals/${f}-${FRAMAC_VERSION_AND_CODENAME}.pdf)" >> $WIKI_PAGE
        run "cp $EACSL_DIR/doc/manuals/$f.pdf $GITHUB_WIKI/manuals/${f}-${FRAMAC_VERSION_AND_CODENAME}.pdf"
        run "git -C $GITHUB_WIKI add manuals/${f}-${FRAMAC_VERSION_AND_CODENAME}.pdf"
        if test "$FINAL_RELEASE" = "yes"; then
            SPEC_FILE="$DOWNLOAD_DIR/e-acsl/${f}-${FRAMAC_VERSION_AND_CODENAME}.pdf"
            RELE_FILE="$DOWNLOAD_DIR/e-acsl/$f.pdf"
            run "rm -f $WEBSITE_DIR/$SPEC_FILE $WEBSITE_DIR/$RELE_FILE"
            run "cp $EACSL_DIR/doc/manuals/$f.pdf $WEBSITE_DIR/$SPEC_FILE"
            run "ln -s ${f}-${FRAMAC_VERSION_AND_CODENAME}.pdf $WEBSITE_DIR/$RELE_FILE";
            run "git -C $WEBSITE_DIR add $SPEC_FILE"
            run "git -C $WEBSITE_DIR add $RELE_FILE"
        fi
    done
    # E-ACSL manuals based on ACSL version number
    for f in "e-acsl"; do
        echo "- [$f](manuals/${f}-${ACSL_VERSION}.pdf)" >> $WIKI_PAGE
        run "cp $EACSL_DIR/doc/manuals/$f.pdf $GITHUB_WIKI/manuals/${f}-${ACSL_VERSION}.pdf"
        run "git -C $GITHUB_WIKI add manuals/${f}-${ACSL_VERSION}.pdf"
        if test "$FINAL_RELEASE" = "yes"; then
            SPEC_FILE="$DOWNLOAD_DIR/e-acsl/${f}-${ACSL_VERSION}.pdf"
            RELE_FILE="$DOWNLOAD_DIR/e-acsl/$f.pdf"
            run "rm -f $WEBSITE_DIR/$SPEC_FILE $WEBSITE_DIR/$RELE_FILE"
            run "cp $EACSL_DIR/doc/manuals/$f.pdf $WEBSITE_DIR/$SPEC_FILE"
            run "ln -s ${f}-${ACSL_VERSION}.pdf $WEBSITE_DIR/$RELE_FILE";
            run "git -C $WEBSITE_DIR add $SPEC_FILE"
            run "git -C $WEBSITE_DIR add $RELE_FILE"
        fi
    done
    run "git -C $GITHUB_WIKI add $PAGE_NAME"
    ;;
  *)
    echo "Bad entry: ${STEP}"
    echo "Exiting without doing anything.";
    exit 31
    ;;
esac

exit 0
