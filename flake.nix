{
  description = "Flake for editing my piano videos";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
  };

  outputs = {
    self,
    nixpkgs,
  }: let
    pkgs = nixpkgs.legacyPackages.${system};
    system = "x86_64-linux";
  in {
    devShells.${system}.default = pkgs.mkShell {
      packages = with pkgs; [
        blender
        # olive-editor
        ffmpeg
        audacity
        # tenacity
        imagemagick
        optipng
        libnotify
      ];
    };
  };
}
