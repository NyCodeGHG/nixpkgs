{ lib, ... }:
{
  name = "qemu-vm-networking-options";
  meta.maintainers = [ lib.maintainers.marie ];

  nodes = {


    none =
      { pkgs, ... }:
      {
        virtualisation = {
          qemu.networking.devices = { };
          interfaces = { };
          vlans = [ ];
        };
        environment.systemPackages = [ pkgs.iproute2 ];
      };

    passt =
      { pkgs, ... }:
      {
        virtualisation = {
          qemu.networking.devices.default.backend.passt = { };
          interfaces = { };
          vlans = [ ];
        };
        environment.systemPackages = [ pkgs.iproute2 ];
      };

    slirp =
      { pkgs, ... }:
      {
        virtualisation = {
          qemu.networking.devices.default.backend.slirp = { };
          interfaces = { };
          vlans = [ ];
        };
        environment.systemPackages = [ pkgs.iproute2 ];
      };
  };

  testScript = ''
    import json

    start_all()

    with subtest("`none` has only a loopback interface"):
      links = json.loads(none.succeed("ip --json link"))
      t.assertEqual(len(links), 1, f"`none` has wrong amount of network interface: {links}")
      t.assertEqual(links[0]['ifname'], "lo")

    with subtest("`passt` has 2 network interfaces"):
      links = json.loads(passt.succeed("ip --json link"))
      t.assertEqual(len(links), 2, f"`passt` has wrong amount of network interface: {links}")

    with subtest("`slirp` has 2 network interfaces"):
      links = json.loads(slirp.succeed("ip --json link"))
      t.assertEqual(len(links), 2, f"`slirp` has wrong amount of network interface: {links}")
  '';
}
