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
    set-and-setting.lib.mkConsumerFlake {
      inherit self nixpkgs set-and-setting;
      fragments = [
        "base"
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
      };
      # set-and-setting's actionlint helper passes a string to
      # nixpkgs.lib.sources.sourceByRegex, whose current API requires a list.
      # Keep the actionlint guardrail local until that pinned helper is fixed.
      extraChecks = pkgs: {
        actionlint =
          let
            workflowFiles = pkgs.lib.sources.sourceByRegex
              (pkgs.lib.sources.sourceFilesBySuffices ./. [ ".yml" ".yaml" ])
              [ "^.github/workflows/.*" ];
          in
          pkgs.runCommand "actionlint-check" { nativeBuildInputs = [ pkgs.findutils pkgs.actionlint ]; } ''
            cd ${workflowFiles}
            mapfile -t matches < <(find . -type f | sort)
            if [ ''${#matches[@]} -eq 0 ]; then
              touch $out
              exit 0
            fi
            actionlint "''${matches[@]}"
            touch $out
          '';
      };
      src = ./.;
    };
}
