{ lib
, stdenv
, frama-c
, odoc
} :

stdenv.mkDerivation rec {
  pname = "api-doc";
  version = frama-c.version;
  slang = frama-c.slang;

  src = frama-c.src;

  nativeBuildInputs = frama-c.nativeBuildInputs;

  buildInputs = frama-c.buildInputs ++ [
    odoc
  ];

  preConfigure = frama-c.preConfigure;

  buildPhase = ''
    dune build -j1 @doc

    cp -r _build/default/_doc/_html frama-c-api

    echo ".dummy" > excluded
    tar czf frama-c-api.tar.gz -X excluded frama-c-api
  '';

  installPhase = ''
    mkdir -p $out
    cp frama-c-api.tar.gz $out
  '';
}
