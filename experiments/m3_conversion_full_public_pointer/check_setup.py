#!/usr/bin/env python3
"""Validate generated isolation and challenge the new pointer trust boundary."""
from pathlib import Path
import os
import subprocess
import tempfile

import prepare

ROOT = Path(__file__).resolve().parent
GENERATED = ROOT / "generated"


def compile_probe(compiler, source, output):
    return subprocess.run(
        [compiler, "-preview=dip1000", "-c", "-of=" + str(output), str(source)],
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
    )


def main():
    prepare.main()

    dispatch = (
        GENERATED / "raster/variant_full_public_pointer_dispatch.d"
    ).read_text()
    public = (
        GENERATED / "raster/variant_full_public_pointer.d"
    ).read_text()

    if dispatch.count("researchExecutionForm") < 3:
        raise ValueError("Research selector missing")
    if dispatch.count("convertResearchPointerRow") != 2:
        raise ValueError("pointer helper/call isolation changed")
    if dispatch.count("width >= 64") != 1:
        raise ValueError("width gate changed")
    if "module raster.variant_full_public_pointer;" not in public:
        raise ValueError("generated public module missing")
    if (
        "import raster.variant_full_public_pointer_dispatch :" not in public
    ):
        raise ValueError("generated public dispatch import missing")

    helper_start = dispatch.index("private void convertResearchPointerRow(")
    helper_end = dispatch.index("\n\nprivate void executeApprovedRows", helper_start)
    helper = dispatch[helper_start:helper_end]

    compiler = os.environ.get("DC", "dmd")
    with tempfile.TemporaryDirectory(prefix="full-public-pointer-trust-") as tmp:
        tmp = Path(tmp)
        positive = tmp / "positive.d"
        negative = tmp / "negative.d"
        positive.write_text("module probe;\n" + helper + "\n")
        negative.write_text(
            "module probe;\n" + helper.replace("@trusted", "@safe") + "\n"
        )

        pos = compile_probe(compiler, positive, tmp / "positive.o")
        (tmp / "positive.txt").write_text(pos.stdout)
        if pos.returncode != 0:
            raise ValueError("trusted pointer helper failed:\n" + pos.stdout)

        neg = compile_probe(compiler, negative, tmp / "negative.o")
        (tmp / "negative.txt").write_text(neg.stdout)
        if neg.returncode == 0:
            raise ValueError("pointer helper unexpectedly compiles as @safe")
        lower = neg.stdout.lower()
        if "@safe" not in lower or not any(
            word in lower for word in ("pointer", "index", "slice", "ptr")
        ):
            raise ValueError(
                "negative trust challenge failed for unexpected reason:\n"
                + neg.stdout
            )

    print("PASS pinned Production generation and source isolation")
    print("PASS isolated pointer helper: @trusted required; @safe rejected")


if __name__ == "__main__":
    main()
