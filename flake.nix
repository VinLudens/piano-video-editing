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
    lib = nixpkgs.lib;
    system = "x86_64-linux";
    myscripts = [
      (pkgs.stdenv.mkDerivation rec {
        pname = "maketitle";
        version = "1.0.0";

        src = ./scripts;

        runtimeDependencies = with pkgs; [
          imagemagick
          ffmpeg
          optipng
          libnotify
          getoptions
          coreutils
        ];

        buildInputs = [pkgs.makeWrapper];
        installPhase = ''
          install -Dm755 ./maketitle.sh $out/bin/maketitle
        '';
        postFixup = ''
          wrapProgram $out/bin/maketitle --set PATH ${lib.makeBinPath runtimeDependencies}
        '';

        meta = {
          description = "Create a title screen for my piano videos";
        };
      })
    ];
  in {
    devShells.${system}.default = pkgs.mkShell {
      packages = with pkgs;
        [
          shfmt
          blender
          # olive-editor
          audacity
          # tenacity
          feh
        ]
        ++ myscripts;
    };
  };
}
