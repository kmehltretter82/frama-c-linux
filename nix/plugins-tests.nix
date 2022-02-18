{ lib
, stdenv
, frama-c
, alt-ergo
, perl
, time
, which
}:

# TODO: SPLIT THIS
stdenv.mkDerivation rec {
  pname = "plugins-tests";
  version = frama-c.version;
  slang = frama-c.slang;

  build_dir = frama-c.build_dir;
  src = build_dir + "/dir.tar";
  wp_cache = fetchGit "git@git.frama-c.com:frama-c/wp-cache.git"; # only for WP qualif
  sourceRoot = ".";

  buildInputs = frama-c.buildInputs ++ [
    alt-ergo
    frama-c
    perl
    time
    which
  ];

  postPatch = ''
    find . \( -name "Makefile*" -or -name ".depend" -o -name "ptests_config" -o -name "config.status" \) -exec bash -c "t=\$(stat -c %y \"\$0\"); sed -i -e \"s&$(cat $build_dir/old_pwd)&$(pwd)&g\" \"\$0\"; touch -d \"\$t\" \"\$0\"" {} \;
    patchShebangs .
  '';

  # Keep main configuration
  configurePhase = ''
    mkdir home
    HOME=$(pwd)/home
    why3 config detect
  '';

  buildPhase = ''
    export FRAMAC_WP_CACHEDIR=$wp_cache
    make ptests/ptests.exe
    make ptests/wtests.exe
    dune exec --root ptests -- frama-c-ptests src/plugins/*/tests
    dune build --display short @src/plugins/ptests
  '';

  # No installation required
  installPhase = ''
    touch $out
  '';
}
