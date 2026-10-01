#!/usr/bin/env bash
# Run every Shader Playground test. Usage: bash tests/run_all.sh
# Set LOVE=/path/to/lovec if it isn't on PATH.
cd "$(dirname "$0")/.." || exit 1
LOVE="${LOVE:-lovec}"
if ! command -v "$LOVE" >/dev/null 2>&1; then
    for c in "/c/Program Files/LOVE/lovec.exe" "/Applications/love.app/Contents/MacOS/love" "love"; do
        if command -v "$c" >/dev/null 2>&1 || [ -x "$c" ]; then LOVE="$c"; break; fi
    done
fi

status=0
run() {
    echo "== $*"
    local out code
    out=$("$LOVE" . "$@" 2>&1)
    code=$?
    echo "$out" | grep -v "^AL lib" | grep -E "FAIL|OK|warn"
    [ "$code" -eq 0 ] || { echo "   (exit code $code)"; status=1; }
}

run --selftest
run --fresh --preset 02_neon_noir --script tests/ui_smoke.lua
run --fresh --script tests/hot_reload.lua
run --fresh --preset 05_deep_field --script tests/capture.lua
run --fresh --preset 06_watercolor_dream --script tests/preview.lua

[ $status -eq 0 ] && echo "ALL PASSED" || echo "SOME TESTS FAILED"
exit $status
