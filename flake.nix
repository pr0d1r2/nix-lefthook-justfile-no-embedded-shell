{
  description = "CHANGEME";

  nixConfig = {
    extra-substituters = [ "https://pr0d1r2.cachix.org" ];
    extra-trusted-public-keys = [ "pr0d1r2.cachix.org-1:NfWjbhgAj41byXhCKiaE+av3Vnphm1fTezHXEGsiQIM=" ];
  };

  inputs = {
    nixpkgs-lock.url = "github:pr0d1r2/nixpkgs-lock";
    nixpkgs.follows = "nixpkgs-lock/nixpkgs";

    set-and-setting.url = "github:pr0d1r2/set-and-setting";
    set-and-setting.inputs.nixpkgs-lock.follows = "nixpkgs-lock";
  };

  outputs =
    {
      self,
      nixpkgs,
      set-and-setting,
      ...
    }:
    let
      forAllSystems =
        f: nixpkgs.lib.genAttrs supportedSystems (system: f nixpkgs.legacyPackages.${system});
          batsWithLibs = batsWithLibsFor pkgs;
    in
    set-and-setting.lib.mkConsumerFlake {
      inherit self nixpkgs set-and-setting;
      fragments = [
        "base"
        "actions"
        "nix"
        "shell"
        "ascii"
        "markdown"
        "yaml"
      ];
      extraPackages = pkgs: {
          default = pkgs.writeShellApplication {
            name = "lefthook-justfile-no-embedded-shell";
            text = builtins.readFile ./lefthook-justfile-no-embedded-shell.sh;
          };
        devShells = forAllSystems (
          pkgs:
          let
            inherit (pkgs.stdenv.hostPlatform) system;
            batsWithLibs = batsWithLibsFor pkgs;
            ciCommon = [
              self.packages.${system}.default
              batsWithLibs
              pkgs.bats
              pkgs.coreutils
              pkgs.git
              pkgs.lefthook
              pkgs.nix
              pkgs.parallel
            ]
            ++ (lefthookWrappersFor pkgs);
          in
          {
            ci = pkgs.mkShell {
              BATS_LIB_PATH = "${batsWithLibs}/share/bats";
            };
            default = pkgs.mkShell {
              shellHook = builtins.replaceStrings [ "@BATS_LIB_PATH@" ] [ "${batsWithLibs}" ] (
                builtins.readFile ./dev.sh
              );
            };
          }
        );
      };
      src = ./.;
    };
}
