{
  lib,
  stdenv,
  fetchFromGitHub,
  cmake,
  enableAvx2 ? false,
}:

stdenv.mkDerivation (final: {
  pname = "glaze";
  version = "5.0.1";

  src = fetchFromGitHub {
    owner = "stephenberry";
    repo = "glaze";
    rev = "v${final.version}";
    hash = "sha256-9ru8T0xUmkKBg6rNg+myzU8bjqWkQGG2B0APPHjyAAE=";
  };

  nativeBuildInputs = [ cmake ];
  cmakeFlags = [ (lib.cmakeBool "glaze_ENABLE_AVX2" enableAvx2) ];

  meta = with lib; {
    description = "Extremely fast, in memory, JSON and interface library for modern C++";
    platforms = platforms.all;
    maintainers = with maintainers; [ moni ];
    license = licenses.mit;
  };
})
