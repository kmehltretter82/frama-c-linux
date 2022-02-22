{ callPackage
, fetchzip
, lib
, stdenv
, ocaml
, findlib
, menhir
, autoreconfHook
, which
}:

stdenv.mkDerivation rec {
  pname = "psmt2-frontend";
  version = "0.1";

  src =
    fetchzip {
      url = "https://github.com/Coquera/psmt2-frontend/archive/0.1.zip";
      sha256 = "0k7jlsbkdyg7hafmvynp0ik8xk7mfr00wz27vxn4ncnmp20yz4vn";
    };

  nativeBuildInputs = [
    autoreconfHook
    which
  ];

  buildInputs = [
    ocaml
    findlib
    menhir
  ];

  enableParallelBuilding = true;

  configureFlags = [ "--enable-verbose-make" ];

  createFindlibDestdir = true;

  installFlags = "LIBDIR=$(OCAMLFIND_DESTDIR)";

  installTargets = [ "install" ];

  meta = {
    description = "A simple parser and type-checker for polomorphic extension of the SMT-LIB 2 language";
    license = lib.licenses.asl20;
    maintainers = [ lib.maintainers.vbgl ];
    inherit (src.meta) homepage;
  };
}
