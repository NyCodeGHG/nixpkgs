{ lib }:

let
  inherit (lib)
    mkOption
    types
    ;
in

mkOption {
  type = types.listOf (
    types.submodule {
      options.from = mkOption {
        type = types.enum [
          "host"
          "guest"
        ];
        default = "host";
        description = ''
          Controls the direction in which the ports are mapped:

          - `"host"` means traffic from the host ports
            is forwarded to the given guest port.
          - `"guest"` means traffic from the guest ports
            is forwarded to the given host port.
        '';
      };
      options.proto = mkOption {
        type = types.enum [
          "tcp"
          "udp"
        ];
        default = "tcp";
        description = "The protocol to forward.";
      };
      options.host.address = mkOption {
        type = types.str;
        default = "";
        description = "The IPv4 address of the host.";
      };
      options.host.port = mkOption {
        type = types.port;
        description = "The host port to be mapped.";
      };
      options.guest.address = mkOption {
        type = types.str;
        default = "";
        description = "The IPv4 address on the guest VLAN.";
      };
      options.guest.port = mkOption {
        type = types.port;
        description = "The guest port to be mapped.";
      };
    }

  );
  default = [ ];
  example = lib.literalExpression ''
    [ # forward local port 2222 -> 22, to ssh into the VM
      { from = "host"; host.port = 2222; guest.port = 22; }

      # forward local port 80 -> 10.0.2.10:80 in the VLAN
      { from = "guest";
        guest.address = "10.0.2.10"; guest.port = 80;
        host.address = "127.0.0.1"; host.port = 80;
      }
    ]
  '';
  description = ''
    ::: {.warning}
    If the NixOS firewall on the virtual machine is enabled, you also
    have to open the guest ports to enable the traffic between host and
    guest.
    :::

    ::: {.note}
    Currently QEMU supports only IPv4 forwarding.
    :::
  '';
}
