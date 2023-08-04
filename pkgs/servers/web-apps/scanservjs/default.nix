{ fetchFromGitHub
, buildNpmPackage
, fetchpatch
, nodejs
, lib
, imagemagick
, sane-backends
, tesseract
, nix-update-script
, stdenvNoCC
, makeWrapper
}:
buildNpmPackage rec {
  pname = "scanservjs";
  version = "3.0.0-SNAPSHOT";

  src = fetchFromGitHub {
    owner = "sbs20";
    repo = pname;
    rev = "625d94444dd88a3fa89b9aa462e3b6887766c33f";
    hash = "sha256-h0d+fsbh2TJaqsicSgkeQ6JTbw5QsnstRlrfSgX8Avw=";
  };

  client = buildNpmPackage rec {
    pname = "${pname}-client";
    inherit version src npmDepsHash;

    npmWorkspace = "app-ui";

    installPhase = ''
      runHook preInstall

      cp -r app-ui/dist $out

      runHook postInstall
    '';
  };

  npmWorkspace = "app-server";
  npmDepsHash = "sha256-gXLMv9yqKc/jSfjkOoB4leUdzXDdri3qHCrnP7Hf7Lo=";

  nativeBuildInputs = [ makeWrapper ];

  prePatch = ''
    substituteInPlace app-server/src/express-configurer.js \
      --replace "express.static('client')" "express.static('${client}')"

    substituteInPlace app-server/src/classes/config.js \
      --replace "/usr/bin/scanimage" "${sane-backends}/bin/scanimage" \
      --replace "/usr/bin/convert" "${imagemagick}/bin/convert" \
      --replace "/usr/bin/tesseract" "${tesseract}/bin/tesseract"
  '';

  installPhase = ''
    runHook preInstall

    cp -r app-server/dist $out
    # Only install runtime dependencies needed for the server to reduce package size.
    npm ci --offline \
      --omit dev \
      --workspace app-server \
      --ignore-scripts

    cp -r node_modules $out

    makeWrapper ${nodejs}/bin/node $out/bin/scanservjs \
      --add-flags "$out/server/server.js" \
      --prefix PATH : ${lib.makeBinPath [ sane-backends imagemagick tesseract nodejs ]} # scanservjs expects these in its path

    mv $out/config $out/config-static
    mv $out/data $out/data-static

    runHook postInstall
  '';

  passthru.updateScript = nix-update-script { };

  meta = {
    description = "A web UI frontend for your scanner";
    homepage = "https://github.com/sbs20/scanservjs";
    changelog = "https://github.com/sbs20/scanservjs/releases/tag/v${version}";
    license = lib.licenses.gpl2;
    maintainers = with lib.maintainers; [ marie ];
    platforms = lib.platforms.unix;
  };
}
