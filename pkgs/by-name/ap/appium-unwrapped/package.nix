{ fetchFromGitHub, buildNpmPackage, yq-go, nodePackages, lib }:
let
  version = "2.4.1";
in buildNpmPackage {
  pname = "appium";
  inherit version;

  # patches = [ ./Disable-writable.patch ];

  src = fetchFromGitHub {
    owner = "appium";
    repo = "appium";
    rev = "6365189b729548fe0e1591000634291c7e7a126c";
    hash = "sha256-j+cInTPz2uFzHGsOVMstt5RfOE47RFlFdbYWjwN6X1I=";
  };

  npmDepsHash = "sha256-tsUYGeFE4CE4RAeQlIu8seo+j3oXt+oAq5slMvGwd8U=";

  nativeBuildInputs = [ yq-go ];

  npmFlags = [ "--ignore-script" ];

  makeCacheWritable = true;

  preConfigure = ''
    yq -iPo json '. +  {"bin": {"appium":"packages/appium/index.js"}}' ./package.json
  '';
}
