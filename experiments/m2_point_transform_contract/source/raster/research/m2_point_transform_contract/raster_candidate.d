module raster.research.m2_point_transform_contract.raster_candidate;

import raster.descriptor : PlaneDescriptor;
import raster.internal.affine_relation :
    AffineByteOverlapRelation,
    affine2DMappingIsInjective,
    classifySameTypeAffine2DByteOverlap;
import raster.region : Region2D;
import raster.resource : ResourceAccess, ResourceEntry;
import raster.validation :
    BackingValidationResult,
    WritableBackingCertificationResult;
import raster.view :
    RasterView,
    makeRasterViewAssumeValidated;
import raster.writable_view :
    WritableRasterView,
    tryMakeWritableRasterView;


enum CandidateTransformError : ubyte
{
    none,
    invalidSourcePlane,
    invalidDestinationPlane,
    shapeMismatch,
    nonInjectiveDestination,
    sourceDestinationOverlap
}


private
T applyPureTransform(alias transform, T)(
    T value
)
@safe
pure
nothrow
@nogc
{
    return transform(value);
}


CandidateTransformError tryCandidatePointTransform(alias transform, T)(
    scope RasterView!T source,
    size_t sourcePlaneIndex,
    scope ref WritableRasterView!T destination,
    size_t destinationPlaneIndex
)
@safe
nothrow
@nogc
{
    ptrdiff_t sourceRowStride;
    ptrdiff_t sourceSampleStride;

    if (
        !source.tryExecutionPlaneStrides(
            sourcePlaneIndex,
            sourceRowStride,
            sourceSampleStride
        )
    )
    {
        return CandidateTransformError.invalidSourcePlane;
    }


    ptrdiff_t destinationRowStride;
    ptrdiff_t destinationSampleStride;

    if (
        !destination.tryExecutionPlaneStrides(
            destinationPlaneIndex,
            destinationRowStride,
            destinationSampleStride
        )
    )
    {
        return CandidateTransformError.invalidDestinationPlane;
    }


    if (
        source.width != destination.width
        || source.height != destination.height
    )
    {
        return CandidateTransformError.shapeMismatch;
    }


    if (source.empty)
        return CandidateTransformError.none;


    if (
        !affine2DMappingIsInjective(
            destination.width,
            destination.height,
            destinationRowStride,
            destinationSampleStride
        )
    )
    {
        return CandidateTransformError.nonInjectiveDestination;
    }


    const sourceBase =
        source.executionRegionBase(
            sourcePlaneIndex
        );

    auto destinationBase =
        destination.executionRegionBase(
            destinationPlaneIndex
        );

    assert(sourceBase !is null);
    assert(destinationBase !is null);


    const overlap =
        classifySameTypeAffine2DByteOverlap(
            source.width,
            source.height,

            cast(size_t) sourceBase,
            sourceRowStride,
            sourceSampleStride,

            cast(size_t) destinationBase,
            destinationRowStride,
            destinationSampleStride,

            T.sizeof
        );


    if (overlap != AffineByteOverlapRelation.disjoint)
    {
        return CandidateTransformError.sourceDestinationOverlap;
    }


    foreach (y; 0 .. source.height)
    {
        foreach (x; 0 .. source.width)
        {
            T value;

            const readOk =
                source.trySample(
                    sourcePlaneIndex,
                    x,
                    y,
                    value
                );

            assert(readOk);

            const transformed =
                applyPureTransform!transform(
                    value
                );

            const writeOk =
                destination.trySetSample(
                    destinationPlaneIndex,
                    x,
                    y,
                    transformed
                );

            assert(writeOk);
        }
    }


    return CandidateTransformError.none;
}


private
WritableRasterView!T makeWritable(T)(
    return scope const(ResourceEntry)[] resources,
    return scope const(PlaneDescriptor)[] descriptors,
    Region2D region
)
@safe
nothrow
@nogc
{
    BackingValidationResult validation;
    WritableBackingCertificationResult certification;

    auto result =
        tryMakeWritableRasterView!T(
            resources,
            descriptors,
            region,
            validation,
            certification
        );

    assert(validation.ok);
    assert(certification.ok);

    return result;
}


@safe
pure
nothrow
@nogc
private
float plusTen(float value)
{
    return value + 10.0f;
}


@safe
pure
nothrow
@nogc
private
ubyte plusOneByte(ubyte value)
{
    return cast(ubyte)(value + 1);
}


private struct Pair
{
    ushort a;
    ushort b;
}


@safe
pure
nothrow
@nogc
private
Pair swapPair(Pair value)
{
    return Pair(value.b, value.a);
}


bool runRasterCandidateMatrix()
@system
nothrow
@nogc
{
    /*
     * Contiguous float -> float.
     */
    {
        float[6] sourceStorage =
            [1, 2, 3, 4, 5, 6];

        float[6] destinationStorage;

        const PlaneDescriptor[1] sourceDescriptors =
        [
            PlaneDescriptor(
                sourceStorage.ptr,
                3,
                1
            )
        ];

        const PlaneDescriptor[1] destinationDescriptors =
        [
            PlaneDescriptor(
                destinationStorage.ptr,
                3,
                1
            )
        ];

        const ResourceEntry[1] destinationResources =
        [
            ResourceEntry(
                destinationStorage.ptr,
                destinationStorage.sizeof,
                null,
                null,
                ResourceAccess.readWrite
            )
        ];

        scope auto source =
            makeRasterViewAssumeValidated!float(
                sourceDescriptors[],
                Region2D(0, 0, 3, 2)
            );

        scope auto destination =
            makeWritable!float(
                destinationResources[],
                destinationDescriptors[],
                Region2D(0, 0, 3, 2)
            );

        assert(
            tryCandidatePointTransform!plusTen(
                source,
                0,
                destination,
                0
            )
            == CandidateTransformError.none
        );

        assert(
            destinationStorage
            == [11, 12, 13, 14, 15, 16]
        );
    }


    /*
     * Padded source and destination rows preserve padding sentinels.
     */
    {
        ubyte[10] sourceStorage =
            [1, 2, 3, 90, 91, 4, 5, 6, 92, 93];

        ubyte[12] destinationStorage =
            [0, 0, 0, 80, 81, 82, 0, 0, 0, 83, 84, 85];

        const PlaneDescriptor[1] sourceDescriptors =
        [
            PlaneDescriptor(
                sourceStorage.ptr,
                5,
                1
            )
        ];

        const PlaneDescriptor[1] destinationDescriptors =
        [
            PlaneDescriptor(
                destinationStorage.ptr,
                6,
                1
            )
        ];

        const ResourceEntry[1] destinationResources =
        [
            ResourceEntry(
                destinationStorage.ptr,
                destinationStorage.sizeof,
                null,
                null,
                ResourceAccess.readWrite
            )
        ];

        scope auto source =
            makeRasterViewAssumeValidated!ubyte(
                sourceDescriptors[],
                Region2D(0, 0, 3, 2)
            );

        scope auto destination =
            makeWritable!ubyte(
                destinationResources[],
                destinationDescriptors[],
                Region2D(0, 0, 3, 2)
            );

        assert(
            tryCandidatePointTransform!plusOneByte(
                source,
                0,
                destination,
                0
            )
            == CandidateTransformError.none
        );

        assert(
            destinationStorage
            == [2, 3, 4, 80, 81, 82, 5, 6, 7, 83, 84, 85]
        );
    }


    /*
     * Arbitrary signed affine layouts.
     */
    {
        ubyte[8] sourceStorage =
            [1, 99, 2, 99, 3, 99, 4, 99];

        ubyte[8] destinationStorage =
            [0, 77, 0, 77, 0, 77, 0, 77];

        const PlaneDescriptor[1] sourceDescriptors =
        [
            PlaneDescriptor(
                sourceStorage.ptr + 6,
                -4,
                -2
            )
        ];

        const PlaneDescriptor[1] destinationDescriptors =
        [
            PlaneDescriptor(
                destinationStorage.ptr + 6,
                -4,
                -2
            )
        ];

        const ResourceEntry[1] destinationResources =
        [
            ResourceEntry(
                destinationStorage.ptr,
                destinationStorage.sizeof,
                null,
                null,
                ResourceAccess.readWrite
            )
        ];

        scope auto source =
            makeRasterViewAssumeValidated!ubyte(
                sourceDescriptors[],
                Region2D(0, 0, 2, 2)
            );

        scope auto destination =
            makeWritable!ubyte(
                destinationResources[],
                destinationDescriptors[],
                Region2D(0, 0, 2, 2)
            );

        assert(
            tryCandidatePointTransform!plusOneByte(
                source,
                0,
                destination,
                0
            )
            == CandidateTransformError.none
        );

        assert(destinationStorage[6] == 5);
        assert(destinationStorage[4] == 4);
        assert(destinationStorage[2] == 3);
        assert(destinationStorage[0] == 2);

        assert(destinationStorage[1] == 77);
        assert(destinationStorage[3] == 77);
        assert(destinationStorage[5] == 77);
        assert(destinationStorage[7] == 77);
    }


    /*
     * POD sample type remains generic.
     */
    {
        Pair[2] sourceStorage =
            [Pair(1, 2), Pair(3, 4)];

        Pair[2] destinationStorage;

        const PlaneDescriptor[1] sourceDescriptors =
        [
            PlaneDescriptor(
                sourceStorage.ptr,
                2,
                1
            )
        ];

        const PlaneDescriptor[1] destinationDescriptors =
        [
            PlaneDescriptor(
                destinationStorage.ptr,
                2,
                1
            )
        ];

        const ResourceEntry[1] destinationResources =
        [
            ResourceEntry(
                destinationStorage.ptr,
                destinationStorage.sizeof,
                null,
                null,
                ResourceAccess.readWrite
            )
        ];

        scope auto source =
            makeRasterViewAssumeValidated!Pair(
                sourceDescriptors[],
                Region2D(0, 0, 2, 1)
            );

        scope auto destination =
            makeWritable!Pair(
                destinationResources[],
                destinationDescriptors[],
                Region2D(0, 0, 2, 1)
            );

        assert(
            tryCandidatePointTransform!swapPair(
                source,
                0,
                destination,
                0
            )
            == CandidateTransformError.none
        );

        assert(destinationStorage[0] == Pair(2, 1));
        assert(destinationStorage[1] == Pair(4, 3));
    }


    /*
     * Non-injective destination is rejected before any write.
     */
    {
        ubyte[3] sourceStorage =
            [1, 2, 3];

        ubyte[1] destinationStorage =
            [44];

        const PlaneDescriptor[1] sourceDescriptors =
        [
            PlaneDescriptor(
                sourceStorage.ptr,
                3,
                1
            )
        ];

        const PlaneDescriptor[1] destinationDescriptors =
        [
            PlaneDescriptor(
                destinationStorage.ptr,
                0,
                0
            )
        ];

        const ResourceEntry[1] destinationResources =
        [
            ResourceEntry(
                destinationStorage.ptr,
                destinationStorage.sizeof,
                null,
                null,
                ResourceAccess.readWrite
            )
        ];

        scope auto source =
            makeRasterViewAssumeValidated!ubyte(
                sourceDescriptors[],
                Region2D(0, 0, 3, 1)
            );

        scope auto destination =
            makeWritable!ubyte(
                destinationResources[],
                destinationDescriptors[],
                Region2D(0, 0, 3, 1)
            );

        assert(
            tryCandidatePointTransform!plusOneByte(
                source,
                0,
                destination,
                0
            )
            == CandidateTransformError.nonInjectiveDestination
        );

        assert(destinationStorage[0] == 44);
    }


    /*
     * Exact in-place mapping is conservatively rejected by the first
     * out-of-place candidate contract.
     */
    {
        ubyte[3] storage =
            [1, 2, 3];

        const PlaneDescriptor[1] descriptors =
        [
            PlaneDescriptor(
                storage.ptr,
                3,
                1
            )
        ];

        const ResourceEntry[1] resources =
        [
            ResourceEntry(
                storage.ptr,
                storage.sizeof,
                null,
                null,
                ResourceAccess.readWrite
            )
        ];

        scope auto source =
            makeRasterViewAssumeValidated!ubyte(
                descriptors[],
                Region2D(0, 0, 3, 1)
            );

        scope auto destination =
            makeWritable!ubyte(
                resources[],
                descriptors[],
                Region2D(0, 0, 3, 1)
            );

        assert(
            tryCandidatePointTransform!plusOneByte(
                source,
                0,
                destination,
                0
            )
            == CandidateTransformError.sourceDestinationOverlap
        );

        assert(storage == [1, 2, 3]);
    }


    /*
     * Shifted overlap is likewise rejected before the first write.
     */
    {
        ubyte[4] storage =
            [1, 2, 3, 4];

        const PlaneDescriptor[1] sourceDescriptors =
        [
            PlaneDescriptor(
                storage.ptr,
                3,
                1
            )
        ];

        const PlaneDescriptor[1] destinationDescriptors =
        [
            PlaneDescriptor(
                storage.ptr + 1,
                3,
                1
            )
        ];

        const ResourceEntry[1] resources =
        [
            ResourceEntry(
                storage.ptr,
                storage.sizeof,
                null,
                null,
                ResourceAccess.readWrite
            )
        ];

        scope auto source =
            makeRasterViewAssumeValidated!ubyte(
                sourceDescriptors[],
                Region2D(0, 0, 3, 1)
            );

        scope auto destination =
            makeWritable!ubyte(
                resources[],
                destinationDescriptors[],
                Region2D(0, 0, 3, 1)
            );

        assert(
            tryCandidatePointTransform!plusOneByte(
                source,
                0,
                destination,
                0
            )
            == CandidateTransformError.sourceDestinationOverlap
        );

        assert(storage == [1, 2, 3, 4]);
    }


    /*
     * Invalid plane and shape mismatch are explicit and non-mutating.
     */
    {
        ubyte[2] sourceStorage =
            [1, 2];

        ubyte[3] destinationStorage =
            [8, 8, 8];

        const PlaneDescriptor[1] sourceDescriptors =
        [
            PlaneDescriptor(
                sourceStorage.ptr,
                2,
                1
            )
        ];

        const PlaneDescriptor[1] destinationDescriptors =
        [
            PlaneDescriptor(
                destinationStorage.ptr,
                3,
                1
            )
        ];

        const ResourceEntry[1] resources =
        [
            ResourceEntry(
                destinationStorage.ptr,
                destinationStorage.sizeof,
                null,
                null,
                ResourceAccess.readWrite
            )
        ];

        scope auto source =
            makeRasterViewAssumeValidated!ubyte(
                sourceDescriptors[],
                Region2D(0, 0, 2, 1)
            );

        scope auto destination =
            makeWritable!ubyte(
                resources[],
                destinationDescriptors[],
                Region2D(0, 0, 3, 1)
            );

        assert(
            tryCandidatePointTransform!plusOneByte(
                source,
                1,
                destination,
                0
            )
            == CandidateTransformError.invalidSourcePlane
        );

        assert(
            tryCandidatePointTransform!plusOneByte(
                source,
                0,
                destination,
                1
            )
            == CandidateTransformError.invalidDestinationPlane
        );

        assert(
            tryCandidatePointTransform!plusOneByte(
                source,
                0,
                destination,
                0
            )
            == CandidateTransformError.shapeMismatch
        );

        assert(destinationStorage == [8, 8, 8]);
    }


    /*
     * Matching empty planes succeed without pointer formation or callback
     * execution.
     */
    {
        ubyte[1] sourceStorage =
            [5];

        ubyte[1] destinationStorage =
            [9];

        const PlaneDescriptor[1] sourceDescriptors =
        [
            PlaneDescriptor(
                sourceStorage.ptr,
                1,
                1
            )
        ];

        const PlaneDescriptor[1] destinationDescriptors =
        [
            PlaneDescriptor(
                destinationStorage.ptr,
                1,
                1
            )
        ];

        const ResourceEntry[1] resources =
        [
            ResourceEntry(
                destinationStorage.ptr,
                destinationStorage.sizeof,
                null,
                null,
                ResourceAccess.readWrite
            )
        ];

        scope auto source =
            makeRasterViewAssumeValidated!ubyte(
                sourceDescriptors[],
                Region2D(0, 0, 0, 1)
            );

        scope auto destination =
            makeWritable!ubyte(
                resources[],
                destinationDescriptors[],
                Region2D(0, 0, 0, 1)
            );

        assert(
            tryCandidatePointTransform!plusOneByte(
                source,
                0,
                destination,
                0
            )
            == CandidateTransformError.none
        );

        assert(destinationStorage[0] == 9);
    }


    return true;
}
