#! /usr/bin/env bash

set -u

# Search "BEGIN SCRIPT" to skip functions

# Set it to "no" in order to really execute the commands.
# Otherwise, they are only printed.
DEBUG=no

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

function run {
    cmd=$1
    echo "$cmd"
    if test "$DEBUG" == "no"; then
        sh -c "$cmd" || { echo "Aborting step ${STEP}."; exit "${STEP}"; }
    fi
}

function step {
    STEP=$1
    echo
    echo "Step $1: $2"
}

# find_repository path url
# - path: path to the directory
# - url: URL of the repository
# Checks:
# - master branch
# Sets:
# DIRECTORY: path to the directory
function find_repository_DIRECTORY_BRANCH {
    name=$1
    url=$2
    if test \! -d $name/.git ; then
        echo "### WARNING: $name/.git directory not found; do you want to clone it? (y/n)"
        read CHOICE
        case "${CHOICE}" in
            "Y"|"y")
                run "git clone $url $name"
                ;;
            *)
                echo "The Github Website repository must be linked at $name (clone or symbolic link)"
                exit 1
                ;&
        esac
    fi
    DIRECTORY=$name
    BRANCH=`git --git-dir=$name/.git rev-parse --abbrev-ref HEAD`
    if [ "$BRANCH" != "master" ]; then
        echo "### WARNING: $name repository is on branch $BRANCH"
        proceed_anyway "Reset the branch to 'master', then run the script again."
    fi
}

# proceed_anyway message
# - message: text to display if we have to stop
# Ask if the user want to continue and display the message if not (then exit)
function proceed_anyway {
    message=$1
    echo "Proceed anyway? [y/N]"
    read CHOICE
    case "${CHOICE}" in
        "Y"|"y")
            ;;
        *)
            echo "$message"
            exit 1
    esac
}

function look_for_uncommited_changes {
    run "git update-index --refresh"
    if ! git diff-index HEAD --; then
        echo ""
        echo "### WARNING: uncommitted git changes will be discarded when creating archive!"
        proceed_anyway "Stash or commit local changes, then run the script again."
    fi
}

function look_for_frama_c_dev {
    rgrep -i "frama-c+dev" src &> /dev/null
    if [ "$?" == "0" ]; then
        echo "### WARNING: Remaing frama-c+dev occurrences in 'src'"
        proceed_anyway "Update API, then run the script again"
    fi
}

function assert_build_dir {
    if test \! -d "$BUILD_DIR" ; then
        echo "ERROR: $BUILD_DIR does not exist, possibly removed by another step"
        exit 1
    fi
}

# diff_validation repository file
# - repository: target repository
# - file: target file
# Ask for user validation before staging changes in [file] on the [repository].
# Stops the script if the user refuses the changes
function diff_validation {
    repo=$1
    file=$2
    run "git -C $repo diff $file"
    echo
    echo "Is the above diff correct for $file? [y/N]"
    read CHOICE
    case "${CHOICE}" in
        "Y"|"y")
            ;;
        *)
            echo "Something went wrong, you may want to clean $repo"
            exit 1
    esac
    run "git -C $repo add $file"
}

# WIKI generation

function fill_wiki {
    PAGE_NAME=Frama-C-${FRAMAC_VERSION_AND_CODENAME}.md
    WIKI_PAGE=$WIKI_DIR/$PAGE_NAME
    run "mkdir -p $WIKI_DIR/manuals"
    run "sed -i -e '/<!-- LAST RELEASE -->/a \
- [${FRAMAC_VERSION} (${FRAMAC_VERSION_CODENAME})](Frama-C-${FRAMAC_VERSION_AND_CODENAME})' $WIKI_DIR/Home.md"
    if test "$FINAL_RELEASE" = "yes"; then
        release_type="FINAL"
    else
        release_type="BETA"
    fi
    run "sed -i -e '/<!-- LAST ${release_type} RELEASE -->/a \
- [${FRAMAC_VERSION} (${FRAMAC_VERSION_CODENAME})](Frama-C-${FRAMAC_VERSION_AND_CODENAME})' $WIKI_DIR/_sidebar.md"
    echo "# Frama-C release ${FRAMAC_VERSION} (${FRAMAC_VERSION_CODENAME})" > $WIKI_PAGE
    echo "## Sources" >> $WIKI_PAGE
    run "cp $OUT_DIR/$TARGZ_FILENAME $WIKI_DIR/downloads"
    run "git -C $WIKI_DIR add downloads/$TARGZ_FILENAME"
    echo " - [$TARGZ_FILENAME](downloads/$TARGZ_FILENAME)" >> $WIKI_PAGE
    echo "" >> $WIKI_PAGE
    echo "## Manuals" >> $WIKI_PAGE
    for fpath in $OUT_DIR/manuals/* ; do
        f=$(basename $fpath)
        f_no_ext=${f%.*}
        f_no_pdf_ext="${f%.pdf}"
        echo "- [${f_no_pdf_ext%-${FRAMAC_VERSION_AND_CODENAME}}](manuals/$f)" >> $WIKI_PAGE
        run "cp $fpath $WIKI_DIR/manuals/"
        run "git -C $WIKI_DIR add manuals/$f"
    done
    echo "" >> $WIKI_PAGE
    echo "## Main changes" >> $WIKI_PAGE
    sed 's/\(\#.*\)/##\1/' $CHANGES >> $WIKI_PAGE
    run "git -C $WIKI_DIR add $PAGE_NAME"
    diff_validation $WIKI_DIR "Home.md"
    diff_validation $WIKI_DIR "_sidebar.md"
}

# WEBSITE pages generation

function add_install_page {
    INSTALL_WEBPAGE=html/installations/$FRAMAC_VERSION_CODENAME_LOWER.md
    INSTALL_WEBPAGE_PATH=$WEBSITE_DIR/$INSTALL_WEBPAGE
    echo "---" > $INSTALL_WEBPAGE_PATH
    echo "layout: doc_page" >> $INSTALL_WEBPAGE_PATH
    echo "title: Installation instructions for $FRAMAC_VERSION_CODENAME" >> $INSTALL_WEBPAGE_PATH
    echo "---" >> $INSTALL_WEBPAGE_PATH
    echo >> $INSTALL_WEBPAGE_PATH
    cat ./INSTALL.md >> $INSTALL_WEBPAGE_PATH

    run "git -C $WEBSITE_DIR add $INSTALL_WEBPAGE"
}

function add_event_page {
    EVENT_WEBPAGE=_events/framac-$FRAMAC_VERSION.md
    EVENT_WEBPAGE_PATH=$WEBSITE_DIR/$EVENT_WEBPAGE

    if [ "$VERSION_MINOR" != 0 ]; then
        PREVIOUS=$VERSION_MAJOR
    else
        PREVIOUS=$(( $VERSION_MAJOR-1 ))
    fi
    PREVIOUS_NAME=$(git show $PREVIOUS.0:VERSION_CODENAME)

    TEXTUAL_VERSION="Frama-C $FRAMAC_VERSION ($FRAMAC_VERSION_CODENAME)"
    TEXTUAL_PREVIOUS="Frama-C $PREVIOUS ($PREVIOUS_NAME)"

    echo "---" > $EVENT_WEBPAGE_PATH
    echo "layout: default" >> $EVENT_WEBPAGE_PATH
    echo "date: $(date +\"%d-%m-%Y\")" >> $EVENT_WEBPAGE_PATH
    echo "event: $TEXTUAL_VERSION" >> $EVENT_WEBPAGE_PATH
    echo -n "title: " >> $EVENT_WEBPAGE_PATH
    if [ "$FINAL_RELEASE" = "no" ]; then
        echo -n "Beta release " >> $EVENT_WEBPAGE_PATH
    else
        echo -n "Release " >> $EVENT_WEBPAGE_PATH
    fi
    echo "of $TEXTUAL_VERSION" >> $EVENT_WEBPAGE_PATH
    VERSION_PAGE="/fc-versions/$FRAMAC_VERSION_CODENAME_LOWER.html"
    echo "link: $VERSION_PAGE" >> $EVENT_WEBPAGE_PATH
    echo "---" >> $EVENT_WEBPAGE_PATH
    echo >> $EVENT_WEBPAGE_PATH
    echo "$TEXTUAL_VERSION is out. Download it [here]($VERSION_PAGE)." >> $EVENT_WEBPAGE_PATH
    echo >> $EVENT_WEBPAGE_PATH
    echo "Main changes with respect to $TEXTUAL_PREVIOUS include:" >> $EVENT_WEBPAGE_PATH
    echo >> $EVENT_WEBPAGE_PATH
    sed 's/\(\#.*\)/###\1/' $CHANGES >> $EVENT_WEBPAGE_PATH

    run "git -C $WEBSITE_DIR add $EVENT_WEBPAGE"
}

function add_version_page {
    VERSION_WEBPAGE="_fc-versions/$FRAMAC_VERSION_CODENAME_LOWER.md"
    VERSION_WEBPAGE_PATH=$WEBSITE_DIR/$VERSION_WEBPAGE
    if [ "$FINAL_RELEASE" = "no" ]; then
        REMOVE="^acsl\| acsl\|/acsl"
        ACSL_VERSION=0
    else
        REMOVE="beta"
        ACSL_VERSION=$(ls $OUT_DIR/manuals | sed -n 's/^acsl-1.\([0-9][0-9]\).pdf/\1/p')
    fi
    sed -e "s/ACSL_VERSION/$ACSL_VERSION/" \
        -e "s/MAJOR_VERSION/$VERSION_MAJOR/" \
        -e "s/MINOR_VERSION/$VERSION_MINOR/" \
        -e "s/VERSION_CODENAME/$FRAMAC_VERSION_CODENAME/" \
        -e "s/LOWER_CODENAME/$FRAMAC_VERSION_CODENAME_LOWER/" \
        -e "s/COMP_VERSION/$FRAMAC_VERSION/" \
        ./bin/version_template.md \
        | grep -vi "$REMOVE" > $VERSION_WEBPAGE_PATH
    run "git -C $WEBSITE_DIR add $VERSION_WEBPAGE"
}

function add_downloads {
    DOWNLOAD_DIR="$WEBSITE_DIR/download"
    DOWNLOAD_PATH="download"
    for fpath in $OUT_DIR/manuals/* ; do
        f=$(basename $fpath)
        f_no_ext=${f%.*}

        if [[ $f_no_ext =~ ^e-acsl.*$ ]]; then
            BASE="e-acsl/$f"
        else
            BASE="$f"
        fi

        if   [[ $f_no_ext =~ ^(e-)?acsl-[0-9].[0-9][0-9]$ ]]; then
            REPL=$(echo $BASE | sed -e "s/-[0-9].[0-9][0-9]//")
        elif [[ $f_no_ext =~ ^e-acsl-* ]]; then
            REPL=$(echo $BASE | sed -e "s/-$FRAMAC_VERSION_AND_CODENAME//")
        else
            REPL=$(echo $BASE | sed -e "s/\(.*\)-$FRAMAC_VERSION_AND_CODENAME/frama-c-\1/")
        fi

        run "cp $fpath $DOWNLOAD_DIR/$BASE"
        run "git -C $WEBSITE_DIR add $DOWNLOAD_PATH/$BASE"
        run "cp $fpath $DOWNLOAD_DIR/$REPL"
        run "git -C $WEBSITE_DIR add $DOWNLOAD_PATH/$REPL"
    done
    # Particular case for the value analysis manual:
    EVA_FILE="$OUT_DIR/manuals/eva-manual-$FRAMAC_VERSION_AND_CODENAME.pdf"
    VALUE_PATH="$DOWNLOAD_DIR/frama-c-value-analysis.pdf"
    VALUE_GIT_PATH="$DOWNLOAD_PATH/frama-c-value-analysis.pdf"
    run "cp $EVA_FILE $VALUE_PATH"
    run "git -C $WEBSITE_DIR add $VALUE_GIT_PATH"

    # Examples:
    HELLO="hello-$FRAMAC_VERSION_AND_CODENAME.tar.gz"
    run "cp $OUT_DIR/$HELLO $DOWNLOAD_DIR"
    run "git -C $WEBSITE_DIR add $DOWNLOAD_PATH/$HELLO"
    run "cp $OUT_DIR/$HELLO $DOWNLOAD_DIR"
    run "git -C $WEBSITE_DIR add $DOWNLOAD_PATH/hello.tar.gz"
    
    # Source distribution:
    run "cp $OUT_DIR/$TARGZ_FILENAME $DOWNLOAD_DIR"
    run "git -C $WEBSITE_DIR add $DOWNLOAD_PATH/$TARGZ_FILENAME"

    # API
    run "cp $OUT_DIR/frama-c-api.tar.gz $DOWNLOAD_DIR/frama-c-api-$FRAMAC_VERSION_AND_CODENAME.tar.gz"
    run "git -C $WEBSITE_DIR add $DOWNLOAD_PATH/frama-c-api-$FRAMAC_VERSION_AND_CODENAME.tar.gz"
}

function fill_website {
    add_install_page
    add_event_page
    add_version_page
    add_downloads
}

# Commit changes

function create_website_branch {
    if test "$FINAL_RELEASE" = "yes"; then
        BRANCH_NAME="release/stable-$FRAMAC_VERSION-$FRAMAC_VERSION_CODENAME_LOWER"
    else
        BRANCH_NAME="release/beta-$FRAMAC_VERSION-$FRAMAC_VERSION_CODENAME_LOWER"
    fi
    # Chech whether release/<release> exists on the website
    git -C $WEBSITE_DIR show-ref --verify --quiet refs/heads/$BRANCH_NAME
    if [[ "$?" == "0" ]]; then
        echo "### Warning: branch $BRANCH_NAME already exists in $WEBSITE_DIR"
        echo "The script will ERASE this branch"
        proceed_anyway "Rename or erase the branch, then run the script again."
        run "git -C $WEBSITE_DIR branch -D $BRANCH_NAME"
    fi

    # Set release/<release> and displays changes to be committed
    run "git -C $WEBSITE_DIR checkout --quiet -b $BRANCH_NAME"
    run "git -C $WEBSITE_DIR status"

    echo "Commit locally the previous changes on $WEBSITE_DIR:$BRANCH_NAME? [y/N]"
    read CHOICE
    case "${CHOICE}" in
        "Y"|"y")
            ;;
        *)
            echo "Abort website branch creation, reset to master."
            run "git -C $WEBSITE_DIR checkout master"
            exit 1
    esac
    run "git -C $WEBSITE_DIR commit -m \"Prepare pages for the release of Frama-C $FRAMAC_VERSION\""
}

function commit_wiki {
    run "git -C $WIKI_DIR status"

    echo "Commit locally the previous changes on $WIKI_DIR? [y/N]"
    read CHOICE
    case "${CHOICE}" in
        "Y"|"y")
            ;;
        *)
            echo "Abort wiki update."
            exit 1
    esac
    run "git -C $WIKI_DIR commit -m \"Prepare pages for the release of Frama-C $FRAMAC_VERSION\""
}


function propagate_changes {
    create_website_branch
    commit_wiki
}

function last_step_validation {
    # if test "$FRAMAC_VERSION" != "$FRAMAC_TAG"; then
    #     echo "To go further, the last commit must be tagged with the right version"
    #     exit 1
    # fi
    echo "
    This step will:

      - ask for a validation of the changes to website
      - create a NEW branch on for the website

      - ask for a validation of the changes to wiki
      - commit changes to the wiki MASTER branch

    If you want to perform some additional checks it is probably time to stop.

    Generated files are available in: $OUT_DIR.
    "
    echo -n "If you are ready to continue, type exactly \"RELEASE\": "
    read CHOICE
    case "${CHOICE}" in
        "RELEASE")
            ;;
        *)
            echo "Aborting"
            exit 1
    esac
}


# BEGIN SCRIPT
GITLAB_FRAMA_C_PUBLIC="git@git.frama-c.com:pub"
GITLAB_WIKI="$GITLAB_FRAMA_C_PUBLIC/frama-c.wiki.git"
GITLAB_WEBSITE="$GITLAB_FRAMA_C_PUBLIC/pub.frama-c.com.git"
GITLAB_ACSL="git@github.com:acsl-language/acsl.git"
GITLAB_FRAMA_C_PRIVATE="git@git.frama-c.com:frama-c/frama-c.git"

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
FRAMAC_VERSION_CODENAME_LOWER=$(echo "$FRAMAC_VERSION_CODENAME" | tr '[:upper:]' '[:lower:]')
FRAMAC_VERSION_AND_CODENAME="${FRAMAC_VERSION}-${FRAMAC_VERSION_CODENAME}"
TARGZ_FILENAME=frama-c-${FRAMAC_VERSION_AND_CODENAME}.tar.gz

VERSION_MODIFIER=$(cat VERSION | sed -e s/[0-9.]*\\\(.*\\\)/\\1/)
VERSION_MAJOR=$(cat VERSION | sed -e s/\\\([0-9]*\\\).[0-9]*.*/\\1/)
VERSION_MINOR=$(cat VERSION | sed -e s/[0-9]*.\\\([0-9]*\\\).*/\\1/)

if test -n "$VERSION_MODIFIER"; then FINAL_RELEASE=no; else FINAL_RELEASE=yes; fi
if [ "$VERSION_MODIFIER" == "+dev" ]; then
    echo "### WARNING: The VERSION is a development version"
    proceed_anyway "Update VERSION and run the script again"
fi

if test "$FRAMAC_VERSION" != "$FRAMAC_TAG"; then
    echo "### WARNING: The current commit is not tagged with the current version:"
    echo "Frama-C Version: $FRAMAC_VERSION"
    echo "Frama-C Tag    : $FRAMAC_TAG"
fi

# Find specific repositories

find_repository_DIRECTORY_BRANCH "./frama-c.wiki" $GITLAB_WIKI
WIKI_DIR=$DIRECTORY
WIKI_BRANCH=$BRANCH

find_repository_DIRECTORY_BRANCH "./website" $GITLAB_WEBSITE
WEBSITE_DIR=$DIRECTORY
WEBSITE_BRANCH=$BRANCH

find_repository_DIRECTORY_BRANCH "./doc/acsl" $GITLAB_ACSL
ACSL_DIR=$DIRECTORY

CHANGES="./main_changes.md"
if test \! -f $CHANGES ; then
    echo "### WARNING: The $CHANGES file is missing"
    echo "Do you want to create an empty one? [y/N]"
    read CHOICE
    case "${CHOICE}" in
        "Y"|"y")
            touch $CHANGES;;
        *)
            echo "Create a changes file and run the script again"
            exit 1
    esac
fi

MANUALS_DIR="./doc/manuals"

BUILD_DIR_ROOT="/tmp/release"
BUILD_DIR="$BUILD_DIR_ROOT/frama-c"

OUT_DIR="./distributed"

echo "Frama-C Version      : $FRAMAC_VERSION"
echo "Final release        : $FINAL_RELEASE"
echo "Frama-C Branch       : $FRAMAC_BRANCH"
echo "Manuals Dir          : $MANUALS_DIR"
echo "ACSL Dir             : $ACSL_DIR"
echo "Frama-C Wiki Dir     : $WIKI_DIR"
echo "Website Dir          : $WEBSITE_DIR"
echo "Changes file         : $CHANGES"
echo "Build Dir            : $BUILD_DIR"
echo "Output Dir           : $OUT_DIR"

export LC_CTYPE=en_US.UTF-8

echo -n "Steps are:

  N) previous information is wrong, STOP the script
  0) ERASE $OUT_DIR
  1) compile PDF manuals (will ERASE $MANUALS_DIR!)
  2) build the source distribution
  3) build API bundle
  4) build documentation companions
  5) clean $BUILD_DIR
  6) prepare wiki (will RESET HARD $WIKI_DIR:$WIKI_BRANCH)
  7) prepare website (will RESET HARD $WEBSITE_DIR:$WEBSITE_BRANCH)
  8) check generated distribution
  9) generate opam file
  10) commit changes

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
        step 0 "PREPARE DISTRIBUTION DIRECTORY"
        run "rm -rf $OUT_DIR"
        run "mkdir -p $OUT_DIR"
        ;&

    1)
        step 1 "COMPILING PDF MANUALS"
        run "rm -rf $MANUALS_DIR"
        run "mkdir -p $MANUALS_DIR"
        run "doc/build-manuals.sh"
        run "rm -rf $OUT_DIR/manuals"
        run "mkdir -p $OUT_DIR/manuals"
        run "cp $MANUALS_DIR/* $OUT_DIR/manuals"
        ;&
    2)
        step 2 "BUILDING THE SOURCE DISTRIBUTION"
        look_for_uncommited_changes
        look_for_frama_c_dev
        run "mkdir -p $BUILD_DIR_ROOT"
        run "rm -rf $BUILD_DIR"
        run "git worktree add -f --detach $BUILD_DIR $FRAMAC_BRANCH"
        run "cd $BUILD_DIR; autoconf"
        run "cd $BUILD_DIR; ./configure"
        run "cd $BUILD_DIR; make -j OPEN_SOURCE=yes src-distrib"
        # sanity check: markdown-report must be distributed
        run "tar tf $BUILD_DIR/$TARGZ_FILENAME | grep -q src/plugins/markdown-report"
        run "cp $BUILD_DIR/$TARGZ_FILENAME $OUT_DIR"
        ;&
    3)
        step 3 "BUILDING THE API BUNDLE"
        assert_build_dir
        run "cd $BUILD_DIR; make -j doc-distrib"
        run "cp $BUILD_DIR/frama-c-api.tar.gz $OUT_DIR"
        ;&
    4)
        step 4 "BUILDING THE DOCUMENTATION COMPANIONS"
        assert_build_dir
        run "cd $BUILD_DIR; make -j doc-companions"
        run "cp $BUILD_DIR/hello-${FRAMAC_VERSION_AND_CODENAME}.tar.gz $OUT_DIR"
        ;&
    5)
        step 5 "CLEAN $BUILD_DIR"
        run "rm -rf $BUILD_DIR"
        run "git worktree prune"
        ;&
    6)
        step 6 "PREPARE WIKI"
        run "git -C $WIKI_DIR reset --hard"
        fill_wiki
        ;&
    7)
        step 7 "PREPARE WEBSITE"
        run "git -C $WEBSITE_DIR reset --hard"
        fill_website
        ;&
    8)
        step 8 "CHECK GENERATED DISTRIBUTION"
        TEST_DIR="$BUILD_DIR_ROOT/frama-c-$FRAMAC_VERSION-$FRAMAC_VERSION_CODENAME"
        run "mkdir -p $BUILD_DIR_ROOT"
        run "rm -rf $TEST_DIR"
        run "cp $OUT_DIR/$TARGZ_FILENAME $BUILD_DIR_ROOT"
        run "cd $BUILD_DIR_ROOT ; tar xzf $TARGZ_FILENAME"
        run "./doc/release/checktar.sh $TEST_DIR"
        run "cd $TEST_DIR ; ./configure && make -j && make tests"
        run "rm -rf $TEST_DIR"
        ;&
    9)
        step 9 "GENERATE OPAM FILE"
        run "cp opam/opam $OUT_DIR/opam"
        echo >> "$OUT_DIR/opam"
        echo "url {" >> "$OUT_DIR/opam"
        echo "  src: \"https://git.frama-c.com/pub/frama-c/-/wikis/downloads/$TARGZ_FILENAME\"" >> "$OUT_DIR/opam"
        echo "  checksum: \"md5=$(md5sum $OUT_DIR/$TARGZ_FILENAME | cut -d" " -f1)\"" >> "$OUT_DIR/opam"
        echo "}" >> "$OUT_DIR/opam"
        ;&
    10)
        step 10 "COMMIT CHANGES"
        last_step_validation
        propagate_changes
        ;;
    *)
        echo "Bad entry: ${STEP}"
        echo "Exiting without doing anything.";
        exit 31
        ;;
esac

exit 0
