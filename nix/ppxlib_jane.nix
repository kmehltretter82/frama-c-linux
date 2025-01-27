{ lib, ocaml, janePackage, ppxlib }:
janePackage (
  {
    pname = "ppxlib_jane";
    meta.description = "A library for use in ppxes for constructing and matching on ASTs corresponding to the augmented parsetree";
    propagatedBuildInputs = [ ppxlib ];
  }
  // (
  if lib.versionAtLeast ocaml.version "5.3" then
    {
      version = "0.17.2";
      hash = "sha256-AQJSdKtF6p/aG5Lx8VHVEOsisH8ep+iiml6DtW+Hdik=";
    }
  else
    {
      version = "0.17.0";
      hash = "sha256-8NC8CHh3pSdFuRDQCuuhc2xxU+84UAsGFJbbJoKwd0U=";
    }
  )
)
