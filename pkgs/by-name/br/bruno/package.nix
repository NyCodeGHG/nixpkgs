{ lib

, fetchFromGitHub
, buildNpmPackage
, nix-update-script
, electron_25-bin
}:

buildNpmPackage rec {
  pname = "bruno";
  version = "0.20.0";

  src = fetchFromGitHub {
    owner = "usebruno";
    repo = "bruno";
    rev = "276c9ce1b011576b6a849f5fd31338f821e571bc";
    hash = "sha256-qGI+d9GsDuuq7xm7zhZo/hSg6f0NLaBCg+xCzAhsq9k=";
    # rev = "v${version}";
    # hash = "sha256-NaA7WO/DfETnFEDKRdojcZgSgNrNTbFFIffSxXxbBG4=";
  };

  buildInputs = [
    electron_25-bin
  ];

  npmDepsHash = "sha256-qf7GB9a0X073CMgbxqmXkfggwdjAA06jH0xa3ma7wUs=";
  # npmDepsHash = "sha256-s/BqHfpZJu1kB8FCXcPTyUCeduaFbt0Tuk959YL4mvA=";
  npmWorkspace = "packages/bruno-electron";
  # npmPackFlags = [ "--ignore-scripts" ];

  # installPhase = ''
  #   runHook preInstall
  #   mkdir -p "$out/bin"
  #   cp -R opt $out
  #   cp -R "usr/share" "$out/share"
  #   ln -s "$out/opt/Bruno/bruno" "$out/bin/bruno"
  #   chmod -R g-w "$out"
  #   runHook postInstall
  # '';

  postFixup = ''
    substituteInPlace "$out/share/applications/bruno.desktop" \
      --replace "/opt/Bruno/bruno" "$out/bin/bruno"
  '';

  passthru.updateScript = nix-update-script { };

  meta = with lib; {
    description = "Open-source IDE For exploring and testing APIs.";
    homepage = "https://www.usebruno.com";
    license = licenses.mit;
    maintainers = with maintainers; [ water-sucks lucasew ];
    platforms = [ "x86_64-linux" ];
  };
}
