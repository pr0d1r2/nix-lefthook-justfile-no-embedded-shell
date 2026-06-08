# Flatten SPEC — nix-lefthook-justfile-no-embedded-shell

## Goal
Remove the `nix-dev-shell-agentic` flake input (and its transitive
explosion) from `flake.nix`, preserving the
`lefthook-justfile-no-embedded-shell` package output and keeping CI
(`nix develop .#ci` + remote lefthook hooks) and bats green.

## Before
- flake.lock: 59 nodes.
- Inputs: nixpkgs-lock, nixpkgs(follows), nix-dev-shell-agentic(flake).
- Outputs: packages.<sys>.default = lefthook-justfile-no-embedded-shell;
  devShells ci/default via nix-dev-shell-agentic.lib.mkShells.

## Consumption of the agentic devShell here
- `.envrc` = `use flake` → devShells.<sys>.default.
- CI (nix-lefthook-ci-action, default devshell=ci) enters
  `nix develop .#ci --ignore-environment` and runs lefthook install /
  pre-commit / pre-push --all-files.
- lefthook.yml `remotes:` invoke wrapper binaries that must be on PATH in
  the ci shell: lefthook-{nixfmt,shellcheck,shfmt,statix,deadnix,
  nix-no-embedded-shell,bats-unit,yamllint,typos,trailing-whitespace,
  missing-final-newline,git-conflict-markers,editorconfig-checker,
  git-no-local-paths,file-size-check}; bare `bats` (bats-parse), bare
  `nix flake check` (nix-flake-check); plus lefthook, git, coreutils,
  parallel.
- bats unit tests need BATS_LIB_PATH + lefthook-justfile-no-embedded-shell
  on PATH.

## Changes
### Inputs
Remove nix-dev-shell-agentic. Add `flake = false` `-src` inputs for each
sibling wrapper the remotes invoke (14 leaves). Result inputs: nixpkgs-lock,
nixpkgs(follows), + 14 flake=false leaves. No flake input → no dep-tree
explosion.

Extra leaf vs the statix template: `nix-lefthook-nix-no-embedded-shell-src`
(this repo's remotes invoke `lefthook-nix-no-embedded-shell`, statix does
not). That wrapper readFiles a companion `scan-nix-no-embedded-shell.sh`
shipped inside its own source tree — injected as `SCANNER="${src}/scan-...sh"`,
mirroring how nix-lefthook-nix-no-embedded-shell's own (already flattened)
flake builds it. No vendoring; the companion travels with the flake=false
source leaf.

### packages (UNCHANGED logic)
packages.<sys>.default = writeShellApplication {
name="lefthook-justfile-no-embedded-shell";
text=readFile ./lefthook-justfile-no-embedded-shell.sh; } — no runtimeInputs
(pure bash check), preserved verbatim.

### devShells (plain mkShell)
lefthookWrappersFor helper (copied from proven statix template:
bats-unit + file-size-check get special multi-input handling, rest via
`wrap`) + extra `lefthook-nix-no-embedded-shell` wrapper with SCANNER inject.
batsWithLibsFor helper. ciCommon = [self pkg, batsWithLibs, bats, coreutils,
git, lefthook, nix, parallel] ++ wrappers.
- ci = mkShell { packages = ciCommon; BATS_LIB_PATH = "${batsWithLibs}/share/bats"; }
- default = mkShell { packages = ciCommon; shellHook = dev.sh expanded; }

### Side changes required to land a flattened flake green
1. config/lefthook/file_size_limits.yml: nix 4096 → 10240. The flattened
  flake.nix grows past 4096 bytes (14 inline wrappers); the proven
  template repos use nix:10240 for the same reason. Pure config, no logic.
2. shfmt (remote, ref: main) now defaults to `-i 2 -ci`. Reformat the bash
  scripts via `shfmt -w -i 2 -ci` (whitespace only, wrapper behavior
  identical) so the shfmt remote stays green.

## Validation gate (all must pass)
1. nix flake check — PASS.
2. nix flake show — packages.<sys>.default =
  lefthook-justfile-no-embedded-shell; devShells ci+default. UNCHANGED set.
3. nix build .#default + smoke (no-arg → 0, clean justfile → 0, bad → 1).
4. bats tests/unit/ inside nix develop .#ci — PASS.
5. lefthook run pre-commit --all-files inside .#ci — PASS.
6. lock nodes << 59.

## Then
Branch flatten-drop-agentic, commit, push, DRAFT PR.
Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
