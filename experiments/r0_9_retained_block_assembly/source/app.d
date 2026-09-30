module app;

import raster : Region2D;
import e9_2_retained_assembly : runE92;
import e9_3_retention_failure : runE93;


private struct BlockGridPolicy
{
    size_t blockWidth;

    size_t blockHeight;

    size_t anchorX;

    size_t anchorY;
}


private bool tryEnd(
    Region2D region,
    out size_t endX,
    out size_t endY
)
@safe
pure
nothrow
@nogc
{
    endX = 0;
    endY = 0;

    if (
        region.width > size_t.max - region.x
        || region.height > size_t.max - region.y
    )
    {
        return false;
    }

    endX = region.x + region.width;
    endY = region.y + region.height;

    return true;
}


private bool containsRegion(
    Region2D outer,
    Region2D inner
)
@safe
pure
nothrow
@nogc
{
    size_t outerEndX;
    size_t outerEndY;
    size_t innerEndX;
    size_t innerEndY;

    if (
        !tryEnd(
            outer,
            outerEndX,
            outerEndY
        )
        || !tryEnd(
            inner,
            innerEndX,
            innerEndY
        )
    )
    {
        return false;
    }

    return
        inner.x >= outer.x
        && inner.y >= outer.y
        && innerEndX <= outerEndX
        && innerEndY <= outerEndY;
}


private bool tryBlockStart(
    size_t coordinate,
    size_t anchor,
    size_t blockSize,
    out size_t start
)
@safe
pure
nothrow
@nogc
{
    start = 0;

    if (
        blockSize == 0
        || coordinate < anchor
    )
    {
        return false;
    }

    const offset =
        coordinate - anchor;

    const blockIndex =
        offset / blockSize;

    if (
        blockIndex
        > (size_t.max - anchor) / blockSize
    )
    {
        return false;
    }

    start =
        anchor
        + blockIndex * blockSize;

    return true;
}


private bool tryIntersect(
    Region2D lhs,
    Region2D rhs,
    out Region2D result
)
@safe
pure
nothrow
@nogc
{
    result = Region2D.init;

    size_t lhsEndX;
    size_t lhsEndY;
    size_t rhsEndX;
    size_t rhsEndY;

    if (
        !tryEnd(lhs, lhsEndX, lhsEndY)
        || !tryEnd(rhs, rhsEndX, rhsEndY)
    )
    {
        return false;
    }

    const startX =
        lhs.x > rhs.x
        ? lhs.x
        : rhs.x;

    const startY =
        lhs.y > rhs.y
        ? lhs.y
        : rhs.y;

    const endX =
        lhsEndX < rhsEndX
        ? lhsEndX
        : rhsEndX;

    const endY =
        lhsEndY < rhsEndY
        ? lhsEndY
        : rhsEndY;

    if (
        endX <= startX
        || endY <= startY
    )
    {
        result =
            Region2D(
                startX,
                startY,
                0,
                0
            );

        return true;
    }

    result =
        Region2D(
            startX,
            startY,
            endX - startX,
            endY - startY
        );

    return true;
}


private bool appendCoveringBlocks(
    Region2D logicalExtent,
    Region2D request,
    BlockGridPolicy policy,
    ref Region2D[] blocks
)
{
    blocks.length = 0;

    if (
        policy.blockWidth == 0
        || policy.blockHeight == 0
        || request.empty()
        || !containsRegion(
            logicalExtent,
            request
        )
    )
    {
        return false;
    }

    size_t requestEndX;
    size_t requestEndY;

    if (
        !tryEnd(
            request,
            requestEndX,
            requestEndY
        )
    )
    {
        return false;
    }

    size_t firstX;
    size_t firstY;

    if (
        !tryBlockStart(
            request.x,
            policy.anchorX,
            policy.blockWidth,
            firstX
        )
        || !tryBlockStart(
            request.y,
            policy.anchorY,
            policy.blockHeight,
            firstY
        )
    )
    {
        return false;
    }

    size_t blockY =
        firstY;

    while (blockY < requestEndY)
    {
        size_t blockX =
            firstX;

        while (blockX < requestEndX)
        {
            Region2D rawBlock =
                Region2D(
                    blockX,
                    blockY,
                    policy.blockWidth,
                    policy.blockHeight
                );

            /*
             * A raw block near size_t.max may not have a representable full
             * end. Clip its width/height against the logical extent first.
             */
            size_t extentEndX;
            size_t extentEndY;

            if (
                !tryEnd(
                    logicalExtent,
                    extentEndX,
                    extentEndY
                )
            )
            {
                return false;
            }

            const rawWidth =
                blockX >= extentEndX
                ? 0
                : (
                    policy.blockWidth
                    > extentEndX - blockX
                    ? extentEndX - blockX
                    : policy.blockWidth
                );

            const rawHeight =
                blockY >= extentEndY
                ? 0
                : (
                    policy.blockHeight
                    > extentEndY - blockY
                    ? extentEndY - blockY
                    : policy.blockHeight
                );

            rawBlock.width =
                rawWidth;

            rawBlock.height =
                rawHeight;

            Region2D clipped;

            if (
                !tryIntersect(
                    rawBlock,
                    logicalExtent,
                    clipped
                )
            )
            {
                return false;
            }

            Region2D overlap;

            if (
                !tryIntersect(
                    clipped,
                    request,
                    overlap
                )
            )
            {
                return false;
            }

            if (!overlap.empty())
            {
                blocks ~=
                    clipped;
            }

            if (
                policy.blockWidth
                > size_t.max - blockX
            )
            {
                break;
            }

            blockX +=
                policy.blockWidth;
        }

        if (
            policy.blockHeight
            > size_t.max - blockY
        )
        {
            break;
        }

        blockY +=
            policy.blockHeight;
    }

    return blocks.length != 0;
}


private bool coverageIsExact(
    Region2D request,
    const(Region2D)[] blocks
)
{
    if (request.empty())
    {
        return blocks.length == 0;
    }

    foreach (logicalY; request.y .. request.y + request.height)
    {
        foreach (logicalX; request.x .. request.x + request.width)
        {
            size_t coverage;

            foreach (block; blocks)
            {
                if (
                    logicalX >= block.x
                    && logicalY >= block.y
                    && logicalX < block.x + block.width
                    && logicalY < block.y + block.height
                )
                {
                    ++coverage;
                }
            }

            if (coverage != 1)
            {
                return false;
            }
        }
    }

    return true;
}


private bool runAnchorComparison()
{
    const extent =
        Region2D(
            1_003,
            2_007,
            101,
            83
        );

    const request =
        Region2D(
            1_013,
            2_011,
            23,
            13
        );

    const globalZero =
        BlockGridPolicy(
            12,
            10,
            0,
            0
        );

    const extentOrigin =
        BlockGridPolicy(
            12,
            10,
            extent.x,
            extent.y
        );

    Region2D[] zeroBlocks;
    Region2D[] extentBlocks;

    assert(
        appendCoveringBlocks(
            extent,
            request,
            globalZero,
            zeroBlocks
        )
    );

    assert(
        appendCoveringBlocks(
            extent,
            request,
            extentOrigin,
            extentBlocks
        )
    );

    assert(
        coverageIsExact(
            request,
            zeroBlocks
        )
    );

    assert(
        coverageIsExact(
            request,
            extentBlocks
        )
    );

    /*
     * Both policies are correct but produce different block regions.
     */
    assert(zeroBlocks != extentBlocks);

    foreach (block; zeroBlocks)
    {
        assert(
            containsRegion(
                extent,
                block
            )
        );
    }

    foreach (block; extentBlocks)
    {
        assert(
            containsRegion(
                extent,
                block
            )
        );
    }

    return true;
}


private bool runPartialEdgeBlocks()
{
    const extent =
        Region2D(
            1_003,
            2_007,
            25,
            19
        );

    const request =
        Region2D(
            1_003,
            2_007,
            25,
            19
        );

    const globalZero =
        BlockGridPolicy(
            12,
            10,
            0,
            0
        );

    Region2D[] blocks;

    assert(
        appendCoveringBlocks(
            extent,
            request,
            globalZero,
            blocks
        )
    );

    assert(
        coverageIsExact(
            request,
            blocks
        )
    );

    bool sawPartialWidth;
    bool sawPartialHeight;

    foreach (block; blocks)
    {
        assert(
            containsRegion(
                extent,
                block
            )
        );

        if (block.width < 12)
        {
            sawPartialWidth = true;
        }

        if (block.height < 10)
        {
            sawPartialHeight = true;
        }
    }

    assert(sawPartialWidth);
    assert(sawPartialHeight);

    return true;
}


private bool runHugeOrigin()
{
    const extent =
        Region2D(
            size_t.max - 1_000,
            size_t.max - 2_000,
            900,
            1_500
        );

    const request =
        Region2D(
            extent.x + 17,
            extent.y + 29,
            127,
            113
        );

    const extentOrigin =
        BlockGridPolicy(
            31,
            29,
            extent.x,
            extent.y
        );

    Region2D[] blocks;

    assert(
        appendCoveringBlocks(
            extent,
            request,
            extentOrigin,
            blocks
        )
    );

    assert(
        coverageIsExact(
            request,
            blocks
        )
    );

    foreach (block; blocks)
    {
        assert(
            containsRegion(
                extent,
                block
            )
        );
    }

    return true;
}


private bool runProviderIndependence()
{
    enum size_t providerBlockWidth = 16;
    enum size_t providerBlockHeight = 8;

    const extent =
        Region2D(
            0,
            0,
            96,
            80
        );

    const request =
        Region2D(
            13,
            11,
            23,
            13
        );

    const cachePolicy =
        BlockGridPolicy(
            12,
            10,
            0,
            0
        );

    static assert(
        providerBlockWidth != 12
        && providerBlockHeight != 10
    );

    Region2D[] blocks;

    assert(
        appendCoveringBlocks(
            extent,
            request,
            cachePolicy,
            blocks
        )
    );

    assert(
        coverageIsExact(
            request,
            blocks
        )
    );

    return true;
}


void main()
{
    assert(runAnchorComparison());
    assert(runPartialEdgeBlocks());
    assert(runHugeOrigin());
    assert(runProviderIndependence());
    assert(runE92());
    assert(runE93());

    import std.stdio : writeln;

    writeln(
        "E9.1 PASS: cache-block grid anchor is policy, not raster semantics"
    );

    writeln(
        "E9.2 PASS: retained cold warm overlap assembly matches direct materialization"
    );

    writeln(
        "E9.3 PASS: retention failure degrades reuse without breaking request correctness"
    );
}
