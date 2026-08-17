#!/usr/bin/env bats

setup() {
    load "$BATS_LIB_PATH/bats-support/load"
    load "$BATS_LIB_PATH/bats-assert/load"
    load "$BATS_LIB_PATH/bats-file/load"

    TEST_TEMP="$(mktemp -d)"
}

@test "flake has a project description" {
    run grep -F 'description = "Lefthook guardrail that rejects embedded shell in justfile recipes";' flake.nix
    assert_success
}

teardown() {
    rm -rf "$TEST_TEMP"
}

@test "exits 0 with no arguments" {
    run lefthook-justfile-no-embedded-shell
    assert_success
}

@test "exits 0 when no justfiles in arguments" {
    touch "$TEST_TEMP/file.txt"
    run lefthook-justfile-no-embedded-shell "$TEST_TEMP/file.txt"
    assert_success
}

@test "skips missing files silently" {
    run lefthook-justfile-no-embedded-shell "/nonexistent/justfile"
    assert_success
}

@test "accepts recipe calling bash scripts/" {
    cat > "$TEST_TEMP/justfile" << 'EOF'
build:
    bash scripts/build.sh
EOF
    run lefthook-justfile-no-embedded-shell "$TEST_TEMP/justfile"
    assert_success
}

@test "rejects shell chaining after an allowed command" {
    cat > "$TEST_TEMP/justfile" << 'EOF'
build:
    bash scripts/build.sh && echo "unexpected inline shell"
EOF
    run lefthook-justfile-no-embedded-shell "$TEST_TEMP/justfile"
    assert_failure
    assert_output --partial "embedded shell"
}

@test "accepts recipe calling bats tests/" {
    cat > "$TEST_TEMP/justfile" << 'EOF'
test:
    bats tests/unit/test.bats
EOF
    run lefthook-justfile-no-embedded-shell "$TEST_TEMP/justfile"
    assert_success
}

@test "accepts recipe calling just --list" {
    cat > "$TEST_TEMP/justfile" << 'EOF'
help:
    @just --list
EOF
    run lefthook-justfile-no-embedded-shell "$TEST_TEMP/justfile"
    assert_success
}

@test "detects inline echo command" {
    cat > "$TEST_TEMP/justfile" << 'EOF'
greet:
    echo "hello world"
EOF
    run lefthook-justfile-no-embedded-shell "$TEST_TEMP/justfile"
    assert_failure
    assert_output --partial "embedded shell"
}

@test "detects inline variable assignment" {
    cat > "$TEST_TEMP/justfile" << 'EOF'
build:
    FOO=bar && echo $FOO
EOF
    run lefthook-justfile-no-embedded-shell "$TEST_TEMP/justfile"
    assert_failure
    assert_output --partial "embedded shell"
}

@test "accepts empty justfile" {
    touch "$TEST_TEMP/justfile"
    run lefthook-justfile-no-embedded-shell "$TEST_TEMP/justfile"
    assert_success
}

@test "skips comment lines in recipe body" {
    cat > "$TEST_TEMP/justfile" << 'EOF'
build:
    # this is a comment
    bash scripts/build.sh
EOF
    run lefthook-justfile-no-embedded-shell "$TEST_TEMP/justfile"
    assert_success
}

@test "attribute lines clear recipe state" {
    cat > "$TEST_TEMP/justfile" << 'EOF'
first:
    bash scripts/first.sh
[private]
    echo "not part of a recipe"
EOF
    run lefthook-justfile-no-embedded-shell "$TEST_TEMP/justfile"
    assert_success
}

@test "accepts recipe calling expect tests/" {
    cat > "$TEST_TEMP/justfile" << 'EOF'
interact:
    expect tests/login.exp
EOF
    run lefthook-justfile-no-embedded-shell "$TEST_TEMP/justfile"
    assert_success
}

@test "accepts recipe calling ssh -t" {
    cat > "$TEST_TEMP/justfile" << 'EOF'
deploy:
    ssh -t deploy@prod.example.com bash scripts/deploy.sh
EOF
    run lefthook-justfile-no-embedded-shell "$TEST_TEMP/justfile"
    assert_success
}

@test "scans subdirectory justfile" {
    mkdir -p "$TEST_TEMP/sub"
    cat > "$TEST_TEMP/sub/justfile" << 'EOF'
build:
    echo "violation"
EOF
    run lefthook-justfile-no-embedded-shell "$TEST_TEMP/sub/justfile"
    assert_failure
    assert_output --partial "embedded shell"
}
