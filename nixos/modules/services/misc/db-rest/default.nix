{ config, lib, options, pkgs, utils, ... }:
let
  inherit (lib) mdDoc mkEnableOption mkIf mkMerge mkOption types literalExpression;
  cfg = config.services.db-rest;
  redisService = "redis-db-rest.service";
in {
  options = {
    services.db-rest = {
      enable = mkEnableOption (mdDoc "db-rest API Server");

      package = mkOption {
        type = types.package;
        default = pkgs.db-rest;
        defaultText = literalExpression "pkgs.db-rest";
        description = mdDoc "db-rest package to use";
      };

      openFirewall = mkOption {
        type = types.bool;
        default = false;
        description = mdDoc "Open the configured port in the firewall";
      };

      redis.createLocally = mkEnableOption
        (mdDoc "a local Redis database using UNIX socket authentication")
        // {
          default = true;
        };

      address = mkOption {
        type = types.str;
        description = mdDoc "The IP to bind on.";
        default = "[::]";
        example = "127.0.0.1";
      };

      port = mkOption {
        description = mdDoc "Port for db-rest to run on";
        type = types.port;
        default = 3000;
      };

      user = mkOption {
        type = types.str;
        default = "db-rest";
        description = lib.mdDoc ''
          User account under which db-rest runs.

          ::: {.note}
          If left as the default value this user will automatically be created
          on system activation, otherwise you are responsible for
          ensuring the user exists before the db-rest application starts.
          :::
        '';
      };

      group = mkOption {
        type = types.str;
        default = "db-rest";
        description = lib.mdDoc ''
          Group account under which db-rest runs.

          ::: {.note}
          If left as the default value this group will automatically be created
          on system activation, otherwise you are responsible for
          ensuring the group exists before the db-rest application starts.
          :::
        '';
      };
    };
  };

  config = mkIf cfg.enable {
    users.users.db-rest = mkIf (cfg.user == "db-rest") {
      isSystemUser = true;
      group = cfg.group;
      extraGroups = lib.optional cfg.redis.createLocally "redis-db-rest";
    };
    users.groups.db-rest = mkIf (cfg.group == "db-rest") { };

    services.redis.servers.db-rest.enable = lib.mkIf cfg.redis.createLocally true;
    systemd.services.db-rest = {
      description = "Deutsche Bahn REST API Wrapper";
      after = [ "network.target" ];
      requires = lib.optional cfg.redis.createLocally redisService;
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "simple";
        ExecStart = "${cfg.package}/bin/db-rest";
        User = cfg.user;
        Group = cfg.group;
        Restart = "on-failure";

        ProtectSystem = "strict";
        PrivateHome = true;
        PrivateTmp = true;
        RestrictAddressFamilies = [ "AF_INET" "AF_INET6" "AF_UNIX" ];
        RestrictNamespaces = true;
        RestrictRealtime = true;
        RestrictSUIDSGID = true;
      };
      environment = mkMerge [
        {
          PORT = builtins.toString cfg.port;
          HOSTNAME = cfg.address;
        }
        (mkIf (cfg.redis.createLocally) {
          REDIS_URL = "redis+unix://${config.services.redis.servers.db-rest.unixSocket}";
        })
      ];
    };
    networking.firewall.allowedTCPPorts = mkIf (cfg.openFirewall) [ cfg.port ];
  };

  meta.maintainers = with lib.maintainers; [ marie ];
}
