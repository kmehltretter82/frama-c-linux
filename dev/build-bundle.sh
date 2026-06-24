#! /bin/bash
##########################################################################
#                                                                        #
#  SPDX-License-Identifier LGPL-2.1                                      #
#  Copyright (C)                                                         #
#  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  #
#                                                                        #
##########################################################################

NOGUI=""
OUI_FILE="oui.json"

if [ "${1:-}" = "--no-gui" ]; then
  NOGUI=true
  OUI_FILE="oui-no-gui.json"
  shift
fi

# Reset bundle

rm -rf bundle
mkdir  bundle

# _opam

OPAM="$(pwd)/_opam"
rm -rf "$OPAM"
opam switch create --empty .
eval $(opam env)

opam pin add -n \
  https://github.com/Frama-C/ocaml-universal-installer.git#reference

opam install -y --confirm-level=unsafe-yes \
  dune \
  dune-configurator \
  dune-site \
  camlzip \
  menhir \
  ocaml."$BUNDLE_OCAML" \
  ocamlgraph \
  oui \
  unionFind \
  yaml \
  yojson \
  zarith \
  ppx_deriving \
  ppx_deriving_yojson \
  ppx_deriving_yaml \
  ppx_inline_test

# build why3 relocatable

WHY3_VERSION="$(grep '^- why3' reference-configuration.md | sed 's/^- why3\.//' | sed 's/ (.*)//')"
WHY3="why3-$WHY3_VERSION"

rm -rf "$WHY3*"
curl "https://why3.gitlabpages.inria.fr/releases/$WHY3.tar.gz" -o "$WHY3.tar.gz"
tar xzf "$WHY3.tar.gz"

cd "$WHY3" || exit 1 ;

./configure \
  --enable-relocation \
  --disable-frama-c \
  --disable-coq-libs \
  --disable-js-of-ocaml \
  --disable-re \
  --enable-ocamlfind \
  --disable-mpfr \
  --disable-zip \
  --disable-hypothesis-selection \
  --disable-stackify \
  --disable-ide \
  --prefix="$OPAM"
make -j
make install install-lib

cd ..

# build Frama-C

git clone \
  https://git-token:$FRAMA_CI_BOT_API_TOKEN@git.frama-c.com/frama-c/meta.git \
  -b stable/arsenic \
  src/plugins/meta

dune build --release --promote-install-files=false @install
dune install --root . --prefix "./bundle" --relocatable

# copy dependencies

cp -r "$OPAM/lib/unionFind" ./bundle/lib
cp -r "$OPAM/lib/store" ./bundle/lib
cp -r "$OPAM/lib/ppx_deriving_yojson" ./bundle/lib
cp -r "$OPAM/lib/ocamlgraph" ./bundle/lib
cp -r "$OPAM/lib/why3" ./bundle/lib
cp -r "$OPAM/share/why3" bundle/share

# Setup NVM

if [ ! -n "$NOGUI" ]; then
  NODE=24

  export NVM_DIR="$HOME/.nvm"
  . "$NVM_DIR/nvm.sh"
  nvm install $NODE
  nvm use node $NODE
  npm install -g yarn

  # build Ivette

  cd ivette || exit ;

  ../bundle/bin/frama-c -load-plugin api_generator -server-tsc src

  node ./configure.js \
    src/renderer/loader.ts \
    src/frama-c/pkg.json \
    src/frama-c/plugins/callgraph/pkg.json \
    src/frama-c/plugins/studia/pkg.json \
    src/frama-c/plugins/wp/pkg.json \
    src/frama-c/plugins/impact/pkg.json \
    src/frama-c/plugins/region/pkg.json \
    src/frama-c/plugins/slicing/pkg.json \
    src/frama-c/plugins/dive/pkg.json \
    src/frama-c/plugins/eva/pkg.json

  node ./sandboxer.js \
    src/renderer/sandbox.ts \
    src/sandbox/dotdiagram.tsx \
    src/sandbox/usednd.tsx \
    src/sandbox/icons.tsx \
    src/sandbox/panel.tsx \
    src/sandbox/tree.tsx \
    src/sandbox/text.tsx \
    src/sandbox/help.tsx \
    src/sandbox/forcegraph.tsx \
    src/sandbox/qsplit.tsx

  yarn install
  yarn run build
  yarn run electron-builder build --dir

  cp -r ./dist/linux-*unpacked ../bundle/lib/frama-c/gui

  cd ..
fi

# Finalize bundle

./dev/clean-bundle.sh --quiet bundle

oui build "dev/$OUI_FILE" -o "frama-c-$BUNDLE_ARCH.$BUNDLE_EXT" bundle

if [ -f "frama-c-$BUNDLE_ARCH.pkg" ]; then # sign macOS bundle
  xattr -dr com.apple.quarantine "frama-c-$BUNDLE_ARCH.pkg"
  codesign -s - --deep --force ./"frama-c-$BUNDLE_ARCH.pkg"
fi
