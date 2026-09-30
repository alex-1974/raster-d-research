#!/usr/bin/env python3
"""Generate research-only consumers from exact pinned production source.

Only module/symbol identity, shared error import, and relation import change.
Validation, exact arithmetic-failure fallback and execution remain untouched.
"""
import hashlib
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parent
PRODUCTION = ROOT.parents[2] / "raster-d"
OUT = ROOT / "source/raster/research/m3_affine_consumer/generated"
BASELINE = "252bc9ab0c868820a9dc5b2432119d8ac0f15903"
SOURCES = [
    ("transform", "b0333bc92e13d00193af8acb26c44e4b1c89e306e28c6c2846c474d610da2d01",
     "RasterTransformError", "tryTransformRasterPlane", "tryBoundedTransform",
     "classifySameTypeAffine2DByteOverlap", "classifyEqual"),
    ("neighbourhood", "c9999fe36394a14092493172188b66e9b73d89399444a0d6a714db92776885fa",
     "RasterNeighbourhood3x3Error", "tryApplyRasterNeighbourhood3x3", "tryBoundedNeighbourhood",
     "classifySameTypeAffine2DRectanglesByteOverlap", "classifyRectangles"),
]
OUT.mkdir(parents=True, exist_ok=True)
for module, digest, error, operation, candidate, relation, wrapper in SOURCES:
    raw = (PRODUCTION / f"source/raster/{module}.d").read_bytes()
    if hashlib.sha256(raw).hexdigest() != digest:
        raise SystemExit(f"Production {module} differs from pinned {BASELINE}")
    text = raw.decode()
    text = text.replace(f"module raster.{module};",
                        f"module raster.research.m3_affine_consumer.generated.{module};", 1)
    # Preserve the same public error type, including values and precedence.
    text, count = re.subn(rf"enum {error} : ubyte\n\{{.*?\n\}}",
                         f"import raster.{module} : {error};", text, count=1, flags=re.S)
    if count != 1:
        raise SystemExit("Missing error declaration")
    old = f"    {relation};"
    if text.count(old) != 1:
        raise SystemExit("Unexpected relation import")
    text = text.replace(old, f"    affineRelationUnused = {relation};", 1)
    text += f"\nimport raster.research.m3_affine_consumer.relation : {relation} = {wrapper};\n"
    text = text.replace(operation, candidate)
    (OUT / f"{module}.d").write_text(
        f"// Generated from raster-d {BASELINE}; source SHA256 {digest}.\n" + text)
    print(f"generated {module}: retained {len(re.findall(r'^unittest$', text, re.M))} unittest blocks")
