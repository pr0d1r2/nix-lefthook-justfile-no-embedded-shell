# SPEC — nix-lefthook-justfile-no-embedded-shell

## §G Goal

Lefthook-compatible enforcer that bans embedded shell from `justfile` recipe bodies. Every recipe line must invoke an extracted script (`bash scripts/…`, `bats tests/…`, `expect tests/…`), `just --list`, or a whitelisted `ssh -t` form — anything else is flagged as embedded shell, pushing logic out of the justfile and into testable scripts. Packaged as a Nix flake. Opensource-safe: zero credentials, zero local paths, zero private refs.

## §C Constraints

- C1: Pure bash — no Python/Ruby/etc runtime deps; the check is a single sourced bash script with no `runtimeInputs`
- C2: Nix flake — `writeShellApplication` pkg, devShells as plain `mkShell` (flattened: no `nix-dev-shell-agentic` input)
- C3: MIT license
- C4: Multi-platform: `aarch64-darwin`, `x86_64-darwin`, `x86_64-linux`, `aarch64-linux`
- C5: Detached from parent project — no credential leaks, no hardcoded local paths, no private repo refs
- C6: All config via env vars — no config files beyond baseline (timeout only)
- C7: Exit non-zero on violations — hard enforcement, blocks commit
- C8: Flattened flake inputs — `nixpkgs-lock` + 15 `flake = false` `-src` leaves, no flake input dep-tree explosion

## §I Interfaces

- I.cli: `lefthook-justfile-no-embedded-shell <files…>` — main binary; scans each arg that is a `justfile` (or `*/justfile`), exit 1 if any recipe body contains embedded shell, exit 0 on pass
- I.env: `LEFTHOOK_JUSTFILE_NO_EMBEDDED_SHELL_TIMEOUT` (seconds, default `30`) — wraps the binary via `timeout` in `lefthook.yml` / `lefthook-remote.yml`
- I.remote: `lefthook-remote.yml` — consumers add as a lefthook remote; provides `pre-commit` + `pre-push` commands globbed to `justfile`
- I.flake: `packages.${system}.default` — Nix pkg output named `lefthook-justfile-no-embedded-shell`
- I.devshell: `devShells.${system}.default` + `.#ci` — dev/CI shells; both expose the package, `bats` + libs, lefthook wrappers, and tooling
- I.ci: `.github/workflows/ci.yml` — linux + macos via `nix-lefthook-ci-action`

## §V Invariants

- V1: A non-blank, non-comment line indented under a recipe header is a *recipe body* line; if it does not match the allow-list regex it is reported (`file:line: embedded shell in recipe body: …`) and the run exits 1
- V2: Allowed recipe bodies match `ALLOW_RE`: `@?just --list[ …]`, `bash scripts/…`, `bats tests/…`, `expect tests/…`, `ssh -t user@host …` — everything else (inline `echo`, var assignment, pipes, loops) is a violation
- V3: Only files named `justfile` or `*/justfile` are scanned; all other args are skipped silently
- V4: Recipe headers (`name:` / `name args:`), attribute lines (`[…]`), and top-level non-recipe lines reset/clear *in-recipe* state so their contents are never treated as recipe bodies
- V5: Blank lines and `#` comment lines inside a recipe body are skipped, never flagged
- V6: No arguments → exit 0; no `justfile` among args → exit 0; missing files → skipped silently (exit 0 if none remain)
- V7: Leading whitespace distinguishes body (indented) from header (column 0); body text is left-trimmed before matching
- V8: Pure bash check — no `runtimeInputs`; package text is `./lefthook-justfile-no-embedded-shell.sh` read verbatim
- V9: Timeout-wrapped in hook configs via `LEFTHOOK_JUSTFILE_NO_EMBEDDED_SHELL_TIMEOUT` (default 30s)
- V10: No credentials, secrets, tokens, API keys, or private paths in any tracked file
- V11: No hardcoded local filesystem paths (enforced by `nix-lefthook-git-no-local-paths` hook)
- V12: `dev.sh` sets `BATS_LIB_PATH` (from `@BATS_LIB_PATH@` placeholder) and auto-installs lefthook when `.git/hooks/pre-commit` is missing
- V13: CI runs lefthook install / pre-commit / pre-push `--all-files` on linux + macos via `nix-lefthook-ci-action`
- V14: All linters pass: shellcheck, shfmt (`-i 2 -ci`), nixfmt, statix, deadnix, nix-no-embedded-shell, yamllint, typos, editorconfig-checker, bats-parse, bats-unit, trailing-whitespace, missing-final-newline, git-conflict-markers, git-no-local-paths, file-size-check
- V15: Flattened flake — devShells are plain `mkShell`; lefthook wrappers built via `lefthookWrappersFor` helper from 15 `flake = false` `-src` leaves; `lefthook-nix-no-embedded-shell` injects `SCANNER="${src}/scan-nix-no-embedded-shell.sh"` ahead of its sourced body
- V16: `config/lefthook/file_size_limits.yml` sets `nix: 10240` — the flattened `flake.nix` (15 inline wrappers) exceeds the default 4096-byte cap

## §T Tasks

| id | status | task | cites |
|----|--------|------|-------|
| T1 | x | core check script: scan justfiles, allow-list recipe bodies, exit 1 on embedded shell | V1,V2,V3,I.cli |
| T2 | x | recipe-state machine: headers/attrs/comments/blanks skipped, body lines trimmed + matched | V4,V5,V7 |
| T3 | x | no-op exits: no args, no justfile, missing files | V6 |
| T4 | x | Nix flake pkg (`writeShellApplication`, pure bash, no runtimeInputs) | C1,C2,V8,I.flake |
| T5 | x | flattened inputs: nixpkgs-lock + 15 flake=false `-src` leaves, no agentic input | C8,V15 |
| T6 | x | devShells ci + default via plain mkShell + lefthookWrappersFor helper | C2,V15,I.devshell |
| T7 | x | nix-no-embedded-shell wrapper with SCANNER inject | V15 |
| T8 | x | lefthook.yml + lefthook-remote.yml: pre-commit + pre-push, timeout-wrapped | I.remote,V9 |
| T9 | x | env var timeout config | C6,V9,I.env |
| T10 | x | dev.sh — BATS_LIB_PATH placeholder + lefthook auto-install | V12 |
| T11 | x | unit tests: lefthook-justfile-no-embedded-shell.bats (13 tests, assert_failure for embedded shell) | V1-V7 |
| T12 | x | unit tests: dev.bats (3 tests) | V12 |
| T13 | x | GitHub Actions CI: linux + macos | V13,I.ci |
| T14 | - | update-pins workflow: dropped (pin refresh handled externally) | I.ci |
| T15 | x | linter suite via lefthook remotes | V14 |
| T16 | x | file_size_limits.yml: nix 4096 → 10240 for flattened flake.nix | V16 |
| T17 | x | opensource audit: no credentials/local-paths/private-refs in git history | V10,V11,C5 |

## §B Bugs

| id | date | cause | fix |
|----|------|-------|-----|
| B1 | 2026-08-17 | Shared guardrails actionlint fragment passed a string path regex to a nixpkgs API requiring a list, breaking flake evaluation | Pin the compatible set-and-setting revision and remove the unsupported actionlint fragment |
