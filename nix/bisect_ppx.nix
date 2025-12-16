{
  lib,
  fetchFromGitHub,
  fetchpatch,
  buildDunePackage,
  cmdliner,
  ppxlib,
}:

buildDunePackage rec {
  pname = "bisect_ppx";
  version = "2.8.3+dev";

  src = fetchFromGitHub {
    owner = "frama-ci-bot";
    repo = "bisect_ppx";
    rev = "ocaml-5.4";
    hash = "sha256-XrM3Ka/u9D1xcsAbL7QogVl8z+XLY7muHVuRpX6XgKo=";
  };

  minimalOCamlVersion = "4.11";

  buildInputs = [
    cmdliner
    ppxlib
  ];

  meta = {
    description = "Bisect_ppx is a code coverage tool for OCaml and Reason. It helps you test thoroughly by showing what's not tested";
    homepage = "https://github.com/aantron/bisect_ppx";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ momeemt ];
    mainProgram = "bisect-ppx-report";
  };
}
