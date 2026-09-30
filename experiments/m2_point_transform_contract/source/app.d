module app;

import std.math : fma;
import std.stdio : writeln;

import raster.research.m2_point_transform_contract.raster_candidate :
    runRasterCandidateMatrix;


/*
 * This experiment deliberately isolates semantic questions from raster-d
 * production implementation.
 *
 * Candidate point operation:
 *
 *     y = op(x)
 *
 * The affine helper is only a diagnostic representative:
 *
 *     y = x * gain + bias
 */

@safe
pure
nothrow
@nogc
float affineExpression(
    float x,
    float gain,
    float bias
)
{
    return x * gain + bias;
}


pragma(inline, false)
@safe
pure
nothrow
@nogc
float roundedMultiply(
    float x,
    float gain
)
{
    return x * gain;
}


@safe
pure
nothrow
@nogc
float affineSeparate(
    float x,
    float gain,
    float bias
)
{
    /*
     * The no-inline call boundary forces the multiply result through the
     * declared float return value before the later addition.
     */
    return roundedMultiply(x, gain) + bias;
}


@safe
pure
nothrow
@nogc
float affineFused(
    float x,
    float gain,
    float bias
)
{
    return fma(x, gain, bias);
}


@safe
pure
nothrow
@nogc
float plusOne(float x)
{
    return x + 1.0f;
}


@safe
pure
nothrow
@nogc
void transformDisjoint(
    scope const(float)[] source,
    scope float[] destination
)
{
    assert(source.length == destination.length);

    foreach (i; 0 .. source.length)
        destination[i] = plusOne(source[i]);
}


@safe
pure
nothrow
@nogc
void transformInPlace(
    scope float[] samples
)
{
    foreach (i; 0 .. samples.length)
        samples[i] = plusOne(samples[i]);
}


@safe
pure
nothrow
@nogc
void transformForwardShiftedOverlap(
    scope float[] storage
)
{
    /*
     * Source:      storage[0 .. $-1]
     * Destination: storage[1 .. $]
     *
     * Forward execution overwrites the next unread source sample.
     * This intentionally demonstrates why arbitrary overlap cannot share the
     * same semantic contract as disjoint execution.
     */
    foreach (i; 0 .. storage.length - 1)
        storage[i + 1] = storage[i] + 10.0f;
}


@safe
pure
nothrow
@nogc
void transformCollapsedDestination(
    scope const(float)[] source,
    ref float destinationSample
)
{
    /*
     * Models a non-injective destination where all logical coordinates map to
     * one physical sample start.
     *
     * For a non-idempotent point transform the final result depends on logical
     * traversal/order, so a generic transform cannot treat this like fill.
     */
    foreach (value; source)
        destinationSample = plusOne(value);
}


void main()
{
    assert(runRasterCandidateMatrix());

    {
        const float[4] source =
            [1.0f, 2.0f, 3.0f, 4.0f];

        float[4] destination;

        transformDisjoint(
            source[],
            destination[]
        );

        assert(
            destination
            == [2.0f, 3.0f, 4.0f, 5.0f]
        );
    }


    {
        float[4] samples =
            [1.0f, 2.0f, 3.0f, 4.0f];

        transformInPlace(samples[]);

        assert(
            samples
            == [2.0f, 3.0f, 4.0f, 5.0f]
        );
    }


    {
        float[4] storage =
            [1.0f, 2.0f, 3.0f, 4.0f];

        transformForwardShiftedOverlap(storage[]);

        /*
         * A mathematically independent point transform would have produced:
         *
         *     [1, 2, 3, 4] -> destination [11, 12, 13]
         *
         * but forward overlap changes later inputs and instead produces:
         *
         *     [1, 11, 21, 31]
         *
         * This is intentionally not accepted point-transform semantics.
         */
        assert(
            storage
            == [1.0f, 11.0f, 21.0f, 31.0f]
        );
    }


    {
        const float[3] source =
            [10.0f, 20.0f, 30.0f];

        float collapsed = -1.0f;

        transformCollapsedDestination(
            source[],
            collapsed
        );

        assert(collapsed == 31.0f);

        /*
         * Reverse logical traversal would produce 11 instead. A generic point
         * transform therefore requires an injective destination unless its
         * operation has stronger idempotence semantics such as fill.
         */
        float reverseCollapsed = -1.0f;

        foreach_reverse (value; source)
            reverseCollapsed = plusOne(value);

        assert(reverseCollapsed == 11.0f);
        assert(reverseCollapsed != collapsed);
    }


    /*
     * FMA discriminator.
     *
     * x and gain are both exactly representable float values:
     *
     *     x    = 1 + 2^-23
     *     gain = 1 - 2^-23
     *
     * Their exact product is:
     *
     *     1 - 2^-46
     *
     * A separately rounded float multiply becomes exactly 1, then adding -1
     * produces +0. A fused operation can retain the residual -2^-46.
     *
     * The experiment records what ordinary compiler expression semantics do;
     * it does not assume the answer in advance.
     */
    const float x =
        1.00000011920928955078125f;

    const float gain =
        0.99999988079071044921875f;

    const float bias =
        -1.0f;

    const ordinary =
        affineExpression(
            x,
            gain,
            bias
        );

    const separate =
        affineSeparate(
            x,
            gain,
            bias
        );

    const fused =
        affineFused(
            x,
            gain,
            bias
        );

    assert(fused != separate);

    writeln(
        "M2 point-transform contract probe PASS"
    );

    writeln(
        "ordinary=", ordinary,
        " separate=", separate,
        " fused=", fused
    );

    writeln(
        "decision evidence: arbitrary shifted overlap corrupts point semantics"
    );

    writeln(
        "decision evidence: non-injective destination is traversal-order dependent"
    );
}
