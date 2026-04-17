# nix-lefthook-justfile-no-embedded-shell

[![CI](https://github.com/pr0d1r2/nix-lefthook-justfile-no-embedded-shell/actions/workflows/ci.yml/badge.svg)](https://github.com/pr0d1r2/nix-lefthook-justfile-no-embedded-shell/actions/workflows/ci.yml)

> This code is LLM-generated and validated through an automated integration process using [lefthook](https://github.com/evilmartians/lefthook) git hooks, [bats](https://github.com/bats-core/bats-core) unit tests, and GitHub Actions CI.

Lefthook-compatible [justfile no-embedded-shell](https://github.com/casey/just) wrapper, packaged as a Nix flake.

Enforces that justfile recipe bodies only call extracted scripts or well-known commands. Detects inline shell to promote modularity. Exits 0 when no justfiles are found.

## Usage

### Option A: Lefthook remote (recommended)

Add to your `lefthook.yml` — no flake input needed, just the wrapper binary in your devShell:

```yaml
remotes:
  - git_url: https://github.com/pr0d1r2/nix-lefthook-justfile-no-embedded-shell
    ref: main
    configs:
      - lefthook-remote.yml
```

### Option B: Flake input

Add as a flake input:

```nix
inputs.nix-lefthook-justfile-no-embedded-shell = {
  url = "github:pr0d1r2/nix-lefthook-justfile-no-embedded-shell";
  inputs.nixpkgs.follows = "nixpkgs";
};
```

Add to your devShell:

```nix
nix-lefthook-justfile-no-embedded-shell.packages.${pkgs.stdenv.hostPlatform.system}.default
```

Add to `lefthook.yml`:

```yaml
pre-commit:
  commands:
    justfile-no-embedded-shell:
      glob: "justfile"
      run: timeout ${LEFTHOOK_JUSTFILE_NO_EMBEDDED_SHELL_TIMEOUT:-30} lefthook-justfile-no-embedded-shell {staged_files}
```

### Configuring timeout

The default timeout is 30 seconds. Override per-repo via environment variable:

```bash
export LEFTHOOK_JUSTFILE_NO_EMBEDDED_SHELL_TIMEOUT=60
```

## Development

The repo includes an `.envrc` for [direnv](https://direnv.net/) — entering the directory automatically loads the devShell with all dependencies:

```bash
cd nix-lefthook-justfile-no-embedded-shell  # direnv loads the flake
bats tests/unit/
```

If not using direnv, enter the shell manually:

```bash
nix develop
bats tests/unit/
```

## License

MIT
