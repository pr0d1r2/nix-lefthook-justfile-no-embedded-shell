{
  description = "Lefthook guardrail that rejects embedded shell in justfile recipes";

  nixConfig = {
    extra-substituters = [ "https://pr0d1r2.cachix.org" ];
    extra-trusted-public-keys = [ "pr0d1r2.cachix.org-1:NfWjbhgAj41byXhCKiaE+av3Vnphm1fTezHXEGsiQIM=" ];
  };

  inputs = {
    nixpkgs-lock.url = "github:pr0d1r2/nixpkgs-lock/efe144236bdd27523c162ea8ab97d7ada904edf2";
    nixpkgs.follows = "nixpkgs-lock/nixpkgs";

    set-and-setting.url = "github:pr0d1r2/set-and-setting/c24625688c1b0ea29eb84ed22ac87dab18f01fea";
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
      src = ./.;
    };
}
