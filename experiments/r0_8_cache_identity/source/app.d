module app;

import raster : Region2D;
import e8_2_key_ownership : runE82;
import e8_3_hashed_key_specialization : runE83;
import e8_4_retained_identity_integration : runE84;
import e8_5_identity_contract_failure : runE85;


private struct SourceIdentity
{
    size_t id;
}


private struct SourceGeneration
{
    size_t value;
}


private struct SchemaIdentity
{
    size_t id;
}


private struct SemanticRasterKey
{
    SourceIdentity source;

    SourceGeneration generation;

    Region2D logicalRegion;

    SchemaIdentity schema;
}


private struct ResidentRepresentation
{
    size_t width;

    size_t height;

    size_t rowStrideBytes;

    size_t planeCount;
}


private SemanticRasterKey key(
    size_t sourceId,
    size_t generation,
    Region2D region,
    size_t schemaId
)
@safe
pure
nothrow
@nogc
{
    return
        SemanticRasterKey(
            SourceIdentity(sourceId),
            SourceGeneration(generation),
            region,
            SchemaIdentity(schemaId)
        );
}


private bool runEqualityMatrix()
@safe
pure
nothrow
@nogc
{
    const region =
        Region2D(
            1_000_003,
            2_000_007,
            23,
            13
        );

    const baseline =
        key(
            7,
            41,
            region,
            3
        );

    assert(
        baseline
        == key(
            7,
            41,
            region,
            3
        )
    );

    assert(
        baseline
        != key(
            8,
            41,
            region,
            3
        )
    );

    assert(
        baseline
        != key(
            7,
            42,
            region,
            3
        )
    );

    assert(
        baseline
        != key(
            7,
            41,
            Region2D(
                region.x + 1,
                region.y,
                region.width,
                region.height
            ),
            3
        )
    );

    assert(
        baseline
        != key(
            7,
            41,
            region,
            4
        )
    );

    return true;
}


private bool runLayoutIndependence()
@safe
pure
nothrow
@nogc
{
    const region =
        Region2D(
            123,
            77,
            23,
            13
        );

    const semantic =
        key(
            11,
            2,
            region,
            9
        );

    const compact =
        ResidentRepresentation(
            region.width,
            region.height,
            region.width,
            1
        );

    const padded =
        ResidentRepresentation(
            region.width,
            region.height,
            region.width + 17,
            1
        );

    assert(compact != padded);

    /*
     * Representation differences do not alter semantic source identity.
     */
    const semanticAgain =
        key(
            11,
            2,
            region,
            9
        );

    assert(semantic == semanticAgain);

    return true;
}


private bool runProviderIndependence()
@safe
pure
nothrow
@nogc
{
    enum size_t providerBlockWidth = 16;
    enum size_t providerBlockHeight = 8;

    const region =
        Region2D(
            13,
            11,
            23,
            13
        );

    static assert(
        providerBlockWidth != 12
        && providerBlockHeight != 10
    );

    assert(region.x % providerBlockWidth != 0);
    assert(region.y % providerBlockHeight != 0);

    const semantic =
        key(
            101,
            1,
            region,
            5
        );

    /*
     * Provider block coordinates are not fields of SemanticRasterKey.
     */
    assert(semantic.logicalRegion == region);

    return true;
}


private bool runHugeOrigin()
@safe
pure
nothrow
@nogc
{
    const region =
        Region2D(
            size_t.max - 100,
            size_t.max - 200,
            17,
            9
        );

    const semantic =
        key(
            1,
            size_t.max,
            region,
            1
        );

    assert(
        semantic.logicalRegion
        == region
    );

    return true;
}


private bool runGenerationInvalidation()
@safe
pure
nothrow
@nogc
{
    const region =
        Region2D(
            400,
            500,
            12,
            10
        );

    const beforeMutation =
        key(
            77,
            9,
            region,
            1
        );

    const afterMutation =
        key(
            77,
            10,
            region,
            1
        );

    assert(
        beforeMutation
        != afterMutation
    );

    return true;
}


void main()
{
    assert(runEqualityMatrix());
    assert(runLayoutIndependence());
    assert(runProviderIndependence());
    assert(runHugeOrigin());
    assert(runGenerationInvalidation());
    assert(runE82());
    assert(runE83());
    assert(runE84());
    assert(runE85());

    import std.stdio : writeln;

    writeln(
        "E8.1 PASS: semantic identity prevents false hits without resident-layout coupling"
    );

    writeln(
        "E8.2 PASS: caller-owned generic keys preserve semantics without raster-d source knowledge"
    );

    writeln(
        "E8.3 PASS: compile-time hash/equality specialization keeps identity lookup @nogc"
    );

    writeln(
        "E8.4 PASS: caller-owned identity integrates with retained RasterLease and source generations"
    );

    writeln(
        "E8.5 PASS: identity correctness is an explicit caller contract"
    );
}
