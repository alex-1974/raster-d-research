#!/usr/bin/env bash

run_m3_codegen() {
    ROOT="$(git rev-parse --show-toplevel 2>/dev/null)"

    if [[ -z "$ROOT" ]]; then
        echo 'ERROR: run inside raster-d-research checkout.'
        return
    fi

    EXPECTED_BRANCH='research/m3-production-neighbourhood'
    BRANCH="$(git -C "$ROOT" branch --show-current)"

    printf 'branch:   %s\nexpected: %s\n' "$BRANCH" "$EXPECTED_BRANCH"

    if [[ "$BRANCH" != "$EXPECTED_BRANCH" ]]; then
        echo 'STOP: wrong research branch.'
        return
    fi

    OUT='/tmp/raster-m3-codegen'
    rm -rf "$OUT"
    mkdir -p "$OUT"

    SRC="$ROOT/experiments/m3_production_neighbourhood/codegen_probe.d"
    ASM="$OUT/m3-neighbourhood.s"
    REPORT="$OUT/report.txt"

    {
        echo '=== RESEARCH HEAD ==='
        git -C "$ROOT" rev-parse HEAD

        echo
        echo '=== MACHINE ==='
        uname -a
        lscpu | grep -E \
            'Architecture|Model name|CPU\(s\)|Thread|Core|Socket'

        echo
        echo '=== LDC ==='
        ldc2 --version

        echo
        echo '=== COMPILE ==='
        echo 'ldc2 -O3 -release -enable-inlining -boundscheck=off -mcpu=native -output-s ...'

        ldc2 \
            -O3 \
            -release \
            -enable-inlining \
            -boundscheck=off \
            -mcpu=native \
            -output-s \
            -of="$ASM" \
            "$SRC"

        STATUS=$?
        echo "compile_status=$STATUS"

        if [[ "$STATUS" -ne 0 ]]; then
            return
        fi

        echo
        echo '=== SYMBOLS ==='
        grep -nE \
            'm3_codegen_integrated:|m3_codegen_noinline:|m3RowNoInline' \
            "$ASM"

        echo
        echo '=== INTEGRATED ASSEMBLY ==='
        awk '
            /^m3_codegen_integrated:/ {show=1}
            show {print}
            show && /^[[:space:]]*\.Lfunc_end[0-9]+:/ {show=0}
        ' "$ASM"

        echo
        echo '=== NOINLINE OUTER ASSEMBLY ==='
        awk '
            /^m3_codegen_noinline:/ {show=1}
            show {print}
            show && /^[[:space:]]*\.Lfunc_end[0-9]+:/ {show=0}
        ' "$ASM"

        echo
        echo '=== NOINLINE ROW KERNEL ASSEMBLY ==='
        LINE="$(grep -n 'm3RowNoInline' "$ASM" | head -1 | cut -d: -f1)"
        if [[ -n "$LINE" ]]; then
            START_LINE="$((LINE > 5 ? LINE - 5 : 1))"
            END_LINE="$((LINE + 260))"
            sed -n "$START_LINE,$END_LINE p" "$ASM"
        else
            echo 'm3RowNoInline symbol not found'
        fi

        echo
        echo '=== VECTOR / VERSIONING INDICATORS ==='
        grep -nE \
            'ymm|xmm|vmov|vadd|vmul|vfmadd|cmp|test|j[a-z]+|m3RowNoInline' \
            "$ASM" \
            | head -320
    } >"$REPORT" 2>&1

    cat "$REPORT"

    echo
    echo "full report: $REPORT"
    echo "full assembly: $ASM"
}

run_m3_codegen
