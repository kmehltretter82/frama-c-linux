{ lib
, stdenv
, camomile
, dune_3
, findlib
, gitignoreSource
, ocaml
, ocp-indent
} :

stdenv.mkDerivation rec {
  pname = "frama-c-lint";
  version =
    lib.strings.replaceStrings ["~"] ["-"]
      (lib.strings.removeSuffix "\n"
        (builtins.readFile ../VERSION));
  slang = lib.strings.removeSuffix "\n" (builtins.readFile ../VERSION_CODENAME);

  src = gitignoreSource ./../tools/lint ;

  buildInputs = [
    camomile
    dune_3
    findlib
    ocaml
    ocp-indent
  ];

  configurePhase = ''
    true
  '';

  buildPhase = ''
    dune build --root .
  '';

  installPhase = ''
    dune install --prefix $out --root .
  '';
}
