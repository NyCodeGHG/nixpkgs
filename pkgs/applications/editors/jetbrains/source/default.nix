{ callPackage
}:

{
  idea-community = callPackage ./build.nix {
    buildVer = "241.17011.79";
    buildType = "idea";
    ideaHash = "sha256-uHo3WV3EcD/tkdmNytCCa3D+M/MLLSZhJoR1gkpwRTU=";
    androidHash = "sha256-hX2YdRYNRg0guskNiYfxdl9osgZojRen82IhgA6G0Eo=";
    jpsHash = "sha256-Abr7L1FyqzRoUSDtsJs3cTEdkhORY5DzsQnOo5irVRI=";
    restarterHash = "sha256-VhSZHiOSJB4VlGVi+sV1hMj2QNYDFaz5L8WDQZQWW04=";
    mvnDeps = ./idea_maven_artefacts.json;
  };
  pycharm-community = callPackage ./build.nix {
    buildVer = "241.17011.84";
    buildType = "pycharm";
    ideaHash = "";
    androidHash = "";
    jpsHash = "";
    restarterHash = "";
    mvnDeps = ./idea_maven_artefacts.json;
  };
}
