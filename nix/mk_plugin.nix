# This template is meant to build external plugins

{ lib
, stdenv
, alt-ergo
, frama-c
, time
}:

{ plugin-name
, plugin-src
, additional-build-inputs ? []
, additional-check-inputs ? []
, has-wp-proofs ? false
, install-opam ? true
}:

stdenv.mkDerivation {
  name = plugin-name;
  src = plugin-src;

  buildInputs = frama-c.buildInputs ++ [
    frama-c
  ]
  ++ additional-build-inputs ;

  checkInputs = [
    time
  ]
  ++ (if has-wp-proofs then [ alt-ergo ] else [])
  ++ additional-check-inputs ;

  # Note: no check is performed, it is just used to show dependencies
  configurePhase = ''
    dune build @frama-c-configure
  '';

  # Do not use default parallel building, but allow 2 cores for Frama-C build
  enableParallelBuilding = false;

  # Some plugins have sh scripts during build
  preBuild  = ''
    patchShebangs .
  '';
  buildPhase = ''
    runHook preBuild
    dune build -j2 --display short @install
  '';

  wp_cache =
    if has-wp-proofs
    then fetchGit "git@git.frama-c.com:frama-c/wp-cache.git"
    else "" ;

  doCheck = true;

  # Some plugins have sh scripts during check
  preCheck = ''
    patchShebangs .
  '' + (if has-wp-proofs then ''
    mkdir home
    HOME=$(pwd)/home
    why3 config detect
    export FRAMAC_WP_CACHEDIR=$wp_cache
    ''
  else "") ;

  checkPhase = ''
    runHook preCheck
    make run-ptests
    dune build -j1 --display short @tests/ptests
  '';

  installFlags = [
    "FRAMAC_INSTALLDIR=$(out)"
  ];

  postInstall = if install-opam then ''
    cp frama-c-$name.opam $out/lib/frama-c-$name/opam
  '' else "" ;

  # Required so that tests of external plugins can be excuted
  postFixup = ''
    cp -r $out/share/doc $out/doc
  '';
}
