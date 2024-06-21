{
  buildNpmPackage,
  fetchFromGitHub,
  lib,
}:

buildNpmPackage rec {
  pname = "appium";
  version = "2.10.3";

  src = fetchFromGitHub {
    owner = "appium";
    repo = "appium";
    rev = "refs/tags/appium@${version}";
    hash = "sha256-BtaRfg5dUmvNPdANhCR9fzx14dapL3SHm5jQIdaM5jk=";
  };

  npmDepsHash = "sha256-T1EbmRR9dUNMKe0S0XKjRTjzM6z2M4dPBThGvoP+9nc=";
  checkMissingLockfileFields = true;
  npmLockOverrides = lib.importJSON ./lockfile-fixes.json;
}
