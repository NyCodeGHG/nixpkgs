{
  bootstrapTools = import <nix/fetchurl.nix> {
    url = "https://bootstrap-files.s3.marie.cologne/stdenv/powerpc-unknown-linux-gnu/hixzv290rwqf9l5ynqxb1qc9cg6a5r54/bootstrap-tools.tar.xz";
    hash = "sha256-M4TnHrnHVPjMCh7sEurGwr1ROANrWvdQlMsw/jaVZek=";
  };
  busybox = import <nix/fetchurl.nix> {
    url = "https://bootstrap-files.s3.marie.cologne/stdenv/powerpc-unknown-linux-gnu/hixzv290rwqf9l5ynqxb1qc9cg6a5r54/busybox";
    hash = "sha256-AR9DM3vMvI9a43HmOKq3nCUa8qbGf5x3IHwzRVeVNWw=";
    executable = true;
  };
}
