module e8_2_key_ownership;

import raster : Region2D;


/++
    Deliberately semantics-blind research cache.

    It knows only:
    - Key equality;
    - Value storage;
    - fixed slot count.

    It does not know source identity, source generation, schema, Region2D,
    provider blocks or resident layout.
+/
private struct GenericIdentityCache(
    Key,
    Value,
    size_t SlotCount
)
{
private:
    struct Entry
    {
        bool occupied;

        Key key;

        Value value;
    }

    Entry[SlotCount] entries_;

public:
    size_t hits;

    size_t misses;


    bool tryGet(
        ref const Key key,
        out Value value
    )
    {
        foreach (ref entry; entries_)
        {
            if (
                entry.occupied
                && entry.key == key
            )
            {
                value = entry.value;
                ++hits;
                return true;
            }
        }

        value = Value.init;
        ++misses;
        return false;
    }


    bool insert(
        Key key,
        Value value
    )
    {
        foreach (ref entry; entries_)
        {
            if (
                entry.occupied
                && entry.key == key
            )
            {
                entry.value = value;
                return true;
            }
        }

        foreach (ref entry; entries_)
        {
            if (!entry.occupied)
            {
                entry.occupied = true;
                entry.key = key;
                entry.value = value;
                return true;
            }
        }

        return false;
    }
}


private struct ProceduralKey
{
    size_t algorithmId;

    size_t configurationId;

    size_t generation;

    Region2D logicalRegion;

    size_t schemaId;
}


private struct InMemoryKey
{
    size_t storageIdentity;

    size_t generation;

    Region2D logicalRegion;

    size_t schemaId;
}


private struct ScientificKey
{
    size_t datasetIdentity;

    size_t generation;

    Region2D logicalRegion;

    size_t fieldSchemaId;
}


private struct BlockBackedKey
{
    size_t datasetIdentity;

    size_t generation;

    Region2D logicalRegion;

    size_t schemaId;
}


private struct OpaqueCallerKey
{
    ulong high;

    ulong low;
}


private struct InstanceAssignedKey
{
    size_t sourceInstanceId;

    size_t generation;

    Region2D logicalRegion;

    size_t schemaId;
}


private struct ResidentLayout
{
    size_t rowStrideBytes;

    size_t planeCount;
}


private bool runProceduralSemanticIdentity()
{
    GenericIdentityCache!(
        ProceduralKey,
        int,
        8
    ) cache;

    const region =
        Region2D(
            13,
            17,
            23,
            11
        );

    /*
     * Two separately constructed procedural source objects may have identical
     * semantics. The caller can deliberately give them the same semantic key.
     */
    const sourceInstanceA =
        ProceduralKey(
            4,
            99,
            1,
            region,
            7
        );

    const sourceInstanceB =
        ProceduralKey(
            4,
            99,
            1,
            region,
            7
        );

    assert(sourceInstanceA == sourceInstanceB);

    assert(
        cache.insert(
            sourceInstanceA,
            1234
        )
    );

    int value;

    assert(
        cache.tryGet(
            sourceInstanceB,
            value
        )
    );

    assert(value == 1234);

    /*
     * Same logical extent but different procedural behavior must not hit.
     */
    const differentBehavior =
        ProceduralKey(
            5,
            99,
            1,
            region,
            7
        );

    assert(
        !cache.tryGet(
            differentBehavior,
            value
        )
    );

    return true;
}


private bool runGenerationAndSchemaInvalidation()
{
    GenericIdentityCache!(
        InMemoryKey,
        int,
        8
    ) cache;

    const region =
        Region2D(
            100,
            200,
            16,
            8
        );

    const original =
        InMemoryKey(
            71,
            3,
            region,
            1
        );

    assert(cache.insert(original, 10));

    int value;

    const nextGeneration =
        InMemoryKey(
            71,
            4,
            region,
            1
        );

    assert(
        !cache.tryGet(
            nextGeneration,
            value
        )
    );

    const incompatibleSchema =
        InMemoryKey(
            71,
            3,
            region,
            2
        );

    assert(
        !cache.tryGet(
            incompatibleSchema,
            value
        )
    );

    assert(
        cache.tryGet(
            original,
            value
        )
    );

    assert(value == 10);

    return true;
}


private bool runScientificAndBlockBackedShapes()
{
    GenericIdentityCache!(
        ScientificKey,
        int,
        4
    ) scientificCache;

    const scientificRegion =
        Region2D(
            1_000_000,
            2_000_000,
            9,
            7
        );

    const uvFields =
        ScientificKey(
            9001,
            12,
            scientificRegion,
            44
        );

    const temperatureField =
        ScientificKey(
            9001,
            12,
            scientificRegion,
            45
        );

    assert(scientificCache.insert(uvFields, 81));

    int value;

    assert(
        scientificCache.tryGet(
            uvFields,
            value
        )
    );

    assert(value == 81);

    assert(
        !scientificCache.tryGet(
            temperatureField,
            value
        )
    );


    GenericIdentityCache!(
        BlockBackedKey,
        int,
        4
    ) blockCache;

    enum size_t providerBlockWidth = 16;
    enum size_t providerBlockHeight = 8;

    const requestRegion =
        Region2D(
            13,
            11,
            23,
            13
        );

    static assert(
        providerBlockWidth == 16
        && providerBlockHeight == 8
    );

    const blockKey =
        BlockBackedKey(
            500,
            1,
            requestRegion,
            6
        );

    assert(blockCache.insert(blockKey, 99));

    assert(
        blockCache.tryGet(
            blockKey,
            value
        )
    );

    assert(value == 99);

    /*
     * Provider block geometry is fixture detail only; it is not represented in
     * BlockBackedKey.
     */
    assert(
        requestRegion.x % providerBlockWidth
        != 0
    );

    assert(
        requestRegion.y % providerBlockHeight
        != 0
    );

    return true;
}


private bool runLayoutOutsideSemanticKey()
{
    GenericIdentityCache!(
        OpaqueCallerKey,
        int,
        4
    ) cache;

    const semanticKey =
        OpaqueCallerKey(
            0x1234,
            0x5678
        );

    const compact =
        ResidentLayout(
            23,
            1
        );

    const padded =
        ResidentLayout(
            64,
            1
        );

    assert(compact != padded);

    assert(cache.insert(semanticKey, 77));

    int value;

    /*
     * The same semantic key can identify reusable source data independent of
     * the representation currently chosen for the consumer.
     *
     * Whether direct reuse is possible is a separate representation-
     * compatibility question.
     */
    assert(
        cache.tryGet(
            semanticKey,
            value
        )
    );

    assert(value == 77);

    return true;
}


private bool runOpaqueCallerOwnedIdentity()
{
    GenericIdentityCache!(
        OpaqueCallerKey,
        size_t,
        4
    ) cache;

    const first =
        OpaqueCallerKey(
            0xAABBCCDD,
            0x01020304
        );

    const same =
        OpaqueCallerKey(
            0xAABBCCDD,
            0x01020304
        );

    const different =
        OpaqueCallerKey(
            0xAABBCCDD,
            0x01020305
        );

    assert(cache.insert(first, 444));

    size_t value;

    assert(cache.tryGet(same, value));
    assert(value == 444);

    assert(
        !cache.tryGet(
            different,
            value
        )
    );

    /*
     * The cache implementation never decomposes the key.
     */
    return true;
}


private bool runInstanceIdentityOverDiscrimination()
{
    GenericIdentityCache!(
        InstanceAssignedKey,
        int,
        4
    ) cache;

    const region =
        Region2D(
            10,
            20,
            12,
            10
        );

    /*
     * Imagine two separately constructed source objects that are semantically
     * identical but received different automatic instance IDs.
     */
    const sourceA =
        InstanceAssignedKey(
            1001,
            1,
            region,
            3
        );

    const sourceB =
        InstanceAssignedKey(
            1002,
            1,
            region,
            3
        );

    assert(cache.insert(sourceA, 55));

    int value;

    /*
     * Safe from false hits, but unnecessarily misses semantically equivalent
     * data.
     */
    assert(
        !cache.tryGet(
            sourceB,
            value
        )
    );

    return true;
}


private bool runCompileTimeValueTypeSeparation()
@safe
pure
nothrow
@nogc
{
    alias UbyteSemanticCache =
        GenericIdentityCache!(
            OpaqueCallerKey,
            ubyte,
            4
        );

    alias FloatSemanticCache =
        GenericIdentityCache!(
            OpaqueCallerKey,
            float,
            4
        );

    /*
     * Sample/value type is already part of D template identity for a typed
     * cache instantiation. A mandatory duplicate runtime sample-type token is
     * therefore not justified by this experiment.
     */
    static assert(
        !is(
            UbyteSemanticCache
            == FloatSemanticCache
        )
    );

    return true;
}


bool runE82()
{
    assert(runProceduralSemanticIdentity());
    assert(runGenerationAndSchemaInvalidation());
    assert(runScientificAndBlockBackedShapes());
    assert(runLayoutOutsideSemanticKey());
    assert(runOpaqueCallerOwnedIdentity());
    assert(runInstanceIdentityOverDiscrimination());
    assert(runCompileTimeValueTypeSeparation());

    return true;
}
