{
  pkgs,
  lib,
  qemuValue,
}:
let
  inherit (lib)
    mkOption
    mkPackageOption
    types
    ;
in
{ name }:
{
  slirp = mkOption {
    type = types.submodule {
      options = {
        settings = mkOption {
          type = types.submodule {
            freeformType = types.attrsOf qemuValue;
            config.id = name;
          };
        };
      };
    };
  };
  passt = mkOption {
    type = types.submodule (
      { config, ... }: {
        options = {
          package = mkPackageOption pkgs "passt" { };
          settings = mkOption {
            type = types.submodule {
              freeformType = types.attrsOf qemuValue;
              options = {
                path = mkOption {
                  type = types.path;
                  default = lib.getExe config.package;
                  description = "Path to the passt executable.";
                };
              };
              config.id = name;
            };
          };
        };
      }
    );
  };
}
