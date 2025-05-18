{
  description = "Flake for editing my piano videos";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
  };

  outputs = {
    self,
    nixpkgs,
  }: let
    pkgs = import nixpkgs {
      system = system;
      # config.allowUnfreePredicate = pkg:
      #   builtins.elem (lib.getName pkg) [
      #     "faac" # cinelerra
      #   ];
    };
    lib = nixpkgs.lib;
    system = "x86_64-linux";
    myfonts = [
      (pkgs.stdenv.mkDerivation rec {
        pname = "gsfonts";
        version = "20200910";

        src = pkgs.fetchzip {
          url = "${meta.homepage}/archive/${version}/${pname}-${version}.zip";
          sha512 = "sha512-pK8jLhi68WjyV89rbPhyjHbsliehOsLQBncSvaR39lzW4MjHTN1IR1YGNvOvhcfmLuroRhtq7J6nqzu6+X+rhQ==";
          stripRoot = true;
        };

        installPhase = ''
          install -vDm 644 fonts/* -t "$out/share/fonts"
          install -vDm 644 appstream/*.xml -t "$out/share/metainfo"
          install -vdm 755 "$out/share/fontconfig/conf.default/"
          for _config in fontconfig/*.conf; do
            _config_path="$out/share/fontconfig/conf.avail/69-''${_config##*/}"
            install -vDm 644 "$_config" "$_config_path"
            ln -srt "$out/share/fontconfig/conf.default/" "$_config_path"
          done
        '';

        meta = with lib; {
          description = "(URW)++ base 35 font set";
          homepage = "https://github.com/ArtifexSoftware/urw-base35-fonts";
          license = licenses.agpl3Only;
          platforms = platforms.all;
        };
      })
    ];
    myscripts = [
      (pkgs.stdenv.mkDerivation rec {
        pname = "maketitle";
        version = "1.0.0";

        src = ./scripts;

        runtimeDependencies =
          (with pkgs; [
            imagemagick
            ffmpeg
            optipng
            libnotify
            getoptions
            coreutils
            parallel
          ])
          ++ myfonts;

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
      (pkgs.stdenvNoCC.mkDerivation rec {
        pname = "make_transparent_score.py";
        version = "1.0.0";

        src = ./scripts/${pname};
        unpackPhase = ":";

        buildInputs = [pkgs.makeWrapper];
        installPhase = ''
          install -Dm755 ${src} $out/bin/${pname}
        '';
        postFixup = ''
          wrapProgram $out/bin/${pname} --set PATH ${lib.makeBinPath [
            (pkgs.python3.withPackages (python-pkgs: [
              python-pkgs.coloredlogs
              python-pkgs.numpy
              python-pkgs.pillow
            ]))
          ]}
        '';

        meta = {
          description = "Create suitable video overlay for individual music systems";
        };
      })
    ];
  in {
    devShells.${system}.default = pkgs.mkShell {
      packages =
        (with pkgs; [
          shfmt
          shellcheck
          ltex-ls
          basedpyright

          blender
          # olive-editor
          # cinelerra
          krita
          inkscape
          imagemagick
          audacity
          # tenacity

          feh
          asciidoctor
        ])
        ++ myscripts
        ++ myfonts;
    };
  };
}
