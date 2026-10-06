{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    attrNames
    attrValues
    concatMap
    concatMapAttrsStringSep
    concatMapStringsSep
    concatStringsSep
    filter
    mkEnableOption
    mkOption
    typeOf
    types
    mkRenamedOptionModule
    ;

  qemuValue =
    with types;
    oneOf [
      bool
      int
      str
      path
      (listOf (oneOf [
        bool
        int
        str
        path
      ]))
    ];

  networkBackends = import ./network-backends.nix { inherit pkgs lib qemuValue; };

  attrsToCommandLine = concatMapAttrsStringSep "," (
    name: value:
    concatMapStringsSep "," (value: "${name}=${toString value}")
      {
        bool = [ (if value then "on" else "off") ];
        list = value;
      }
      .${typeOf value} or [ value ]
  );

  getBackendType =
    value:
    let
      type = builtins.elemAt (attrNames value) 0;
    in
    {
      inherit type;
      backend = value.${type};
    };

  toNetworkOption =
    value:
    let
      inherit (getBackendType value.backend) backend type;
      name = if type == "slirp" then "user" else type;
    in
    [
      "-netdev ${
        concatStringsSep "," [
          name
          (attrsToCommandLine backend.settings)
        ]
      }"
      "-device ${value.device},id=${backend.settings.id}"
    ];
in
{
  imports = [
    (mkRenamedOptionModule
      [ "virtualisation" "qemu" "networkingOptions" ]
      [ "virtualisation" "qemu" "networking" "options" ]
    )
    (mkRenamedOptionModule
      [ "virtualisation" "restrictNetwork" ]
      [
        "virtualisation"
        "qemu"
        "networking"
        "devices"
        "default"
        "backend"
        "slirp"
        "settings"
        "restrict"
      ]
    )
  ];
  options.virtualisation.qemu.networking = {
    options = mkOption {
      type = types.listOf types.str;
      example = [
        "-net nic,netdev=user.0,model=virtio"
        "-netdev user,id=user.0,\${QEMU_NET_OPTS:+,$QEMU_NET_OPTS}"
      ];
      description = ''
        Networking-related command-line options that should be passed to qemu.
        These contain the options generated from {option}`virtualisation.qemu.networking.devices`.
        See the [QEMU Wiki on Networking](https://wiki.qemu.org/Documentation/Networking) for details.

        If you override this option, be advised to keep
        `''${QEMU_NET_OPTS:+,$QEMU_NET_OPTS}` (as seen in the example)
        to keep the default runtime behaviour.
      '';
    };

    devices = mkOption {
      default = {
        default.backend.passt = { };
      };
      type = types.attrsOf (
        types.submodule (
          { name, ... }: {
            options = {
              enable = mkEnableOption "this network device" // {
                default = true;
              };
              device = mkOption {
                # Taken from `qemu-system-x86_64 -device help` from section "Network devices"
                type = types.enum [
                  "e1000"
                  "e1000-82544gc"
                  "e1000-82545em"
                  "e1000e"
                  "i82550"
                  "i82551"
                  "i82557a"
                  "i82557b"
                  "i82557c"
                  "i82558a"
                  "i82558b"
                  "i82559a"
                  "i82559b"
                  "i82559c"
                  "i82559er"
                  "i82562"
                  "i82801"
                  "igb"
                  "ne2k_isa"
                  "ne2k_pci"
                  "pcnet"
                  "rocker"
                  "rtl8139"
                  "tulip"
                  "usb-net"
                  "virtio-net-device"
                  "virtio-net-pci"
                  "virtio-net-pci-non-transitional"
                  "virtio-net-pci-transitional"
                  "vmxnet3"
                  "xen-net-device"
                ];
                description = "The qemu device to use for this network device.";
                default = "virtio-net-pci";
              };
              backend = mkOption {
                type = types.attrTag (networkBackends {
                  inherit name;
                });
              };
            };
          }
        )
      );
    };
  };
  config = {
    virtualisation.qemu.networking.options = lib.pipe config.virtualisation.qemu.networking.devices [
      attrValues
      (filter (device: device.enable))
      (concatMap toNetworkOption)
    ];
  };
}
