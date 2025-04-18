{
  lib,
  buildDunePackage,
  ocaml,
  bitstring,
  ppxlib,
  ounit,
}:

if lib.versionOlder ppxlib.version "0.18.0" then
  throw "ppx_bitstring is not available with ppxlib-${ppxlib.version}"
else

  buildDunePackage {
    pname = "ppx_bitstring";
    inherit (bitstring) version src;

    duneVersion = "3";

    buildInputs = [
      bitstring
      ppxlib
    ];

    doCheck = lib.versionAtLeast ocaml.version "4.08";
    checkInputs = [ ounit ];

    meta = bitstring.meta // {
      description = "Bitstrings and bitstring matching for OCaml - PPX extension";
    };
  }
