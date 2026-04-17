# shellcheck shell=bash
# Lefthook-compatible justfile no-embedded-shell check.
# NOTE: sourced by writeShellApplication — no shebang or set needed.
# Recipe bodies may only invoke extracted scripts or well-known commands.

if [ $# -eq 0 ]; then
    exit 0
fi

files=()
for f in "$@"; do
    [ -f "$f" ] || continue
    case "$f" in
        justfile | */justfile) files+=("$f") ;;
    esac
done

if [ ${#files[@]} -eq 0 ]; then
    exit 0
fi

ALLOW_RE='^(@?just --list( .*)?|bash scripts/[^[:space:]]+.*|bats tests/[^[:space:]]+.*|expect tests/[^[:space:]]+.*|ssh -t [^[:space:]]+@[^[:space:]]+.*)$'

failed=0
for file in "${files[@]}"; do
    in_recipe=0
    lineno=0
    while IFS= read -r raw || [ -n "$raw" ]; do
        lineno=$((lineno + 1))

        if [[ "$raw" =~ ^[[:space:]]*$ ]]; then
            continue
        fi
        if [[ "$raw" =~ ^[[:space:]]*# ]]; then
            continue
        fi

        if [[ "$raw" =~ ^[^[:space:]] ]]; then
            if [[ "$raw" =~ ^\[ ]]; then
                continue
            fi
            if [[ "$raw" =~ ^[a-zA-Z_][a-zA-Z0-9_-]*(\ [^:]*)?: ]]; then
                in_recipe=1
                continue
            fi
            in_recipe=0
            continue
        fi

        [ "$in_recipe" -eq 1 ] || continue

        body="${raw#"${raw%%[![:space:]]*}"}"

        if [[ ! "$body" =~ $ALLOW_RE ]]; then
            printf '%s:%d: embedded shell in recipe body: %s\n' "$file" "$lineno" "$body" >&2
            failed=1
        fi
    done <"$file"
done

exit "$failed"
