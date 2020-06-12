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

VERSION_MODIFIER=$(cat VERSION | sed -e s/[0-9.]*\\\(.*\\\)/\\1/)

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

GITLAB_DIR=./pub-frama-c
GITLAB_GIT="git@git.frama-c.com:pub/frama-c.git"

if test ! -d $GITLAB_DIR/.git; then
    echo "WARNING: $GITLAB_DIR/.git directory not found; do you want to clone it? (y/n)"
    read CHOICE
    case "${CHOICE}" in
        "Y"|"y")
            run "git clone $GITLAB_GIT $GITLAB_DIR"
            ;;
        *)
            echo "gitlab's public Frama-C project must be linked at $GITLAB_DIR \
                 (clone or symbolic link)"
            exit 1
            ;&
    esac
fi
GITLAB_BRANCH=$(git --git-dir=$GITLAB_DIR/.git rev-parse --abbrev-ref HEAD)
if test "$FRAMAC_BRANCH" != "$GITLAB_BRANCH"; then
    echo "WARNING: switching pub-frama-c to current branch $FRAMAC_BRANCH"
    run "git -C $GITLAB_DIR checkout -b $FRAMAC_BRANCH"
fi
GITLAB_WIKI_GIT="git@git.frama-c.com:pub/frama-c.wiki"
GITLAB_WIKI=./frama-c.wiki
if test ! -d $GITLAB_WIKI/.git; then
    echo "WARNING: $GITLAB_WIKI/.git directory not found; do you want to clone it? (y/n)"
    read CHOICE
    case "${CHOICE}" in
        "Y"|"y")
            run "git clone $GITLAB_WIKI_GIT"
            ;;
        *)
            echo "pub/frama-c wiki must be linked at $GITLAB_WIKI \
                 (clone or symbolic link)"
            exit 1
            ;&
    esac
fi
GITLAB_WIKI_BRANCH=$(git --git-dir=$GITLAB_WIKI/.git rev-parse --abbrev-ref HEAD)

if test "$GITLAB_WIKI_BRANCH" != "master"; then
    echo "WARNING: pub/frama-c's wiki is not on the master branch";
fi

ACSL_GIT="git@gitlab.com:acsl-language/acsl.git"
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
echo "pub/frama-c dir         : $GITLAB_DIR"
echo "pub/frama-c branch      : $GITLAB_BRANCH"
echo "pub/frama-c wiki        : $GITLAB_WIKI"
echo "Manuals Dir             : $MANUALS_DIR"
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
    run "git -C $GITLAB_DIR reset --hard"
    run "git -C $GITLAB_WIKI reset --hard"
    if test "$FINAL_RELEASE" = "yes"; then
       run "git -C $WEBSITE_DIR reset --hard"
    fi
    ;&
  2)
    step 2 "BUILDING THE SOURCE DISTRIBUTION"
    # WARNING! MUST RUN git update-index BEFORE git diff-index!
    # See: https://stackoverflow.com/questions/36367190/git-diff-files-output-changes-after-git-status
    run "git update-index --refresh"
    if ! git diff-index HEAD --; then
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
    run "git worktree add -f --detach $BUILD_DIR $FRAMAC_BRANCH"
    run "cd $BUILD_DIR; autoconf"
    run "cd $BUILD_DIR; ./configure"
    run "cd $BUILD_DIR; make -j OPEN_SOURCE=yes src-distrib"
    # sanity check: markdown-report must be distributed
    run "tar tf $BUILD_DIR/$TARGZ_FILENAME | grep -q src/plugins/markdown-report"
    # populate release assets in wiki
    run "mkdir -p $GITLAB_WIKI/downloads"
    run "cp $BUILD_DIR/$TARGZ_FILENAME $GITLAB_WIKI/downloads/"
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
      WIKI_PAGE=$GITLAB_WIKI/$PAGE_NAME
      run "mkdir -p $GITLAB_WIKI/manuals"
      run "sed -i -e '/<!-- LAST RELEASE -->/a \
- [${FRAMAC_VERSION} (${FRAMAC_VERSION_CODENAME})](Frama-C-${FRAMAC_VERSION_AND_CODENAME})' $GITLAB_WIKI/Home.md"
      if test "$FINAL_RELEASE" = "yes"; then
          release_type="FINAL"
      else
          release_type="BETA"
      fi
      run "sed -i -e '/<!-- LAST ${release_type} RELEASE -->/a \
- [${FRAMAC_VERSION} (${FRAMAC_VERSION_CODENAME})](Frama-C-${FRAMAC_VERSION_AND_CODENAME})' $GITLAB_WIKI/_sidebar.md"
      echo "# Frama-C release ${FRAMAC_VERSION} (${FRAMAC_VERSION_CODENAME})" > $WIKI_PAGE
      echo "## Sources" >> $WIKI_PAGE
      echo " - [$TARGZ_FILENAME](downloads/$TARGZ_FILENAME)" >> $WIKI_PAGE
      echo "" >> $WIKI_PAGE
      echo "## Manuals" >> $WIKI_PAGE
      for fpath in $MANUALS_DIR/*; do
          f=$(basename $fpath)
          f_no_ext=${f%.*}
          # E-ACSL-related files are stored in subdirectory e-acsl
          if [[ $f_no_ext =~ ^e-acsl.*$ ]]; then
              destdir="$WEBSITE_DIR/$DOWNLOAD_DIR/e-acsl"
          else
              destdir="$WEBSITE_DIR/$DOWNLOAD_DIR"
          fi
          if [[ -L $fpath ]]; then
              # symbolic links are copied to the website and prepended with 'frama-c-'
              # (except for acsl.pdf, which is copied as is)
              if [[ $f_no_ext =~ ^(e-)?acsl$ ]]; then
                  ln="$f"
              else
                  ln="frama-c-$f"
              fi
              run "rm -f $destdir/$ln"
              run "cp -P $fpath $destdir/$ln"
              run "git -C $destdir add $ln"
          else
              # non-symbolic links are copied as-is to the website, and also to
              # the Gitlab wiki, where they are also added as links
              f_no_pdf_ext="${f%.pdf}"
              echo "- [${f_no_pdf_ext%-${FRAMAC_VERSION_AND_CODENAME}}](manuals/$f)" >> $WIKI_PAGE
              run "cp $fpath $GITLAB_WIKI/manuals/"
              run "git -C $GITLAB_WIKI add manuals/$f"
              run "cp $fpath $destdir/$f"
              run "git -C $destdir add $f"
          fi
      done

    run "git -C $GITLAB_WIKI add $PAGE_NAME"
    ;;
  *)
    echo "Bad entry: ${STEP}"
    echo "Exiting without doing anything.";
    exit 31
    ;;
esac

exit 0
