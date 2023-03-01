{ lib, fetchurl, buildDunePackage
, dune-configurator
, bos, ctypes, fmt, logs
, mdx, alcotest, crowbar, junit_alcotest, ezjsonm
}:

buildDunePackage rec {
  pname = "yaml";
  version = "3.0.1";

  src = fetchurl {
    url = "https://github.com/avsm/ocaml-yaml/releases/download/v${version}/yaml-${version}.tbz";
    sha256 = "ku0bpClVmhS2tF4XDzSCGReR+ZrFGJpfIGEuFb+99pU=";
  };

  minimalOCamlVersion = "4.05.0";

  buildInputs = [ dune-configurator ];
  propagatedBuildInputs = [ bos ctypes ];

  doCheck = true;
  nativeCheckInputs = [ mdx.bin ];
  checkInputs = [ fmt logs alcotest crowbar junit_alcotest ezjsonm ];

  meta = {
    description = "Parse and generate YAML 1.1 files";
    homepage = "https://github.com/avsm/ocaml-yaml";
    license = lib.licenses.isc;
    maintainers = [ lib.maintainers.vbgl ];
  };

}
