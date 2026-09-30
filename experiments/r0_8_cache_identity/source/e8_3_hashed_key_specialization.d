module e8_3_hashed_key_specialization;


/++
    Fixed-capacity open-addressed research cache.

    Identity semantics remain entirely caller-provided through compile-time
    hash/equality functions.
+/
private struct HashedIdentityCache(
    Key,
    Value,
    size_t SlotCount,
    alias hashKey,
    alias sameKey
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
    @safe
    pure
    nothrow
    @nogc
    {
        const start =
            hashKey(key) % SlotCount;

        foreach (probe; 0 .. SlotCount)
        {
            const index =
                (start + probe) % SlotCount;

            ref entry =
                entries_[index];

            if (!entry.occupied)
            {
                value = Value.init;
                ++misses;
                return false;
            }

            if (sameKey(entry.key, key))
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
    @safe
    pure
    nothrow
    @nogc
    {
        const start =
            hashKey(key) % SlotCount;

        foreach (probe; 0 .. SlotCount)
        {
            const index =
                (start + probe) % SlotCount;

            ref entry =
                entries_[index];

            if (!entry.occupied)
            {
                entry.occupied = true;
                entry.key = key;
                entry.value = value;
                return true;
            }

            if (sameKey(entry.key, key))
            {
                entry.value = value;
                return true;
            }
        }

        return false;
    }
}


private struct OpaqueKey
{
    ulong high;

    ulong low;
}


private size_t opaqueHash(
    ref const OpaqueKey key
)
@safe
pure
nothrow
@nogc
{
    return
        cast(size_t)(
            key.high
            ^ (key.low * 0x9E3779B97F4A7C15UL)
        );
}


private bool opaqueEqual(
    ref const OpaqueKey a,
    ref const OpaqueKey b
)
@safe
pure
nothrow
@nogc
{
    return a == b;
}


private struct CompositeKey
{
    size_t source;

    size_t generation;

    size_t regionX;

    size_t regionY;

    size_t regionWidth;

    size_t regionHeight;

    size_t schema;
}


private size_t mix(
    size_t state,
    size_t value
)
@safe
pure
nothrow
@nogc
{
    return
        state
        ^ (
            value
            + cast(size_t) 0x9E3779B9U
            + (state << 6)
            + (state >> 2)
        );
}


private size_t compositeHash(
    ref const CompositeKey key
)
@safe
pure
nothrow
@nogc
{
    size_t state =
        0x811C9DC5U;

    state = mix(state, key.source);
    state = mix(state, key.generation);
    state = mix(state, key.regionX);
    state = mix(state, key.regionY);
    state = mix(state, key.regionWidth);
    state = mix(state, key.regionHeight);
    state = mix(state, key.schema);

    return state;
}


private bool compositeEqual(
    ref const CompositeKey a,
    ref const CompositeKey b
)
@safe
pure
nothrow
@nogc
{
    return a == b;
}


private struct CollisionKey
{
    size_t id;
}


private size_t constantHash(
    ref const CollisionKey key
)
@safe
pure
nothrow
@nogc
{
    return 3;
}


private bool collisionEqual(
    ref const CollisionKey a,
    ref const CollisionKey b
)
@safe
pure
nothrow
@nogc
{
    return a == b;
}


private bool runOpaqueSpecialization()
@safe
pure
nothrow
@nogc
{
    HashedIdentityCache!(
        OpaqueKey,
        size_t,
        8,
        opaqueHash,
        opaqueEqual
    ) cache;

    const keyA =
        OpaqueKey(
            0x11223344UL,
            0x55667788UL
        );

    const keyB =
        OpaqueKey(
            0x11223344UL,
            0x55667789UL
        );

    assert(cache.insert(keyA, 91));

    size_t value;

    assert(cache.tryGet(keyA, value));
    assert(value == 91);

    assert(!cache.tryGet(keyB, value));

    return true;
}


private bool runCompositeSpecialization()
@safe
pure
nothrow
@nogc
{
    HashedIdentityCache!(
        CompositeKey,
        int,
        16,
        compositeHash,
        compositeEqual
    ) cache;

    const base =
        CompositeKey(
            7,
            3,
            1_000_000,
            2_000_000,
            23,
            13,
            4
        );

    assert(cache.insert(base, 700));

    int value;

    assert(cache.tryGet(base, value));
    assert(value == 700);

    auto nextGeneration =
        base;

    ++nextGeneration.generation;

    assert(
        !cache.tryGet(
            nextGeneration,
            value
        )
    );

    auto differentSchema =
        base;

    ++differentSchema.schema;

    assert(
        !cache.tryGet(
            differentSchema,
            value
        )
    );

    return true;
}


private bool runCollisionQualification()
@safe
pure
nothrow
@nogc
{
    HashedIdentityCache!(
        CollisionKey,
        int,
        8,
        constantHash,
        collisionEqual
    ) cache;

    foreach (i; 0 .. 6)
    {
        assert(
            cache.insert(
                CollisionKey(i),
                cast(int) (i * 10)
            )
        );
    }

    foreach (i; 0 .. 6)
    {
        int value;

        assert(
            cache.tryGet(
                CollisionKey(i),
                value
            )
        );

        assert(
            value
            == cast(int) (i * 10)
        );
    }

    int missing;

    assert(
        !cache.tryGet(
            CollisionKey(99),
            missing
        )
    );

    return true;
}


private bool runNoRuntimeIdentityObjectRequirement()
@safe
pure
nothrow
@nogc
{
    alias OpaqueCache =
        HashedIdentityCache!(
            OpaqueKey,
            ubyte,
            4,
            opaqueHash,
            opaqueEqual
        );

    alias CompositeCache =
        HashedIdentityCache!(
            CompositeKey,
            ubyte,
            4,
            compositeHash,
            compositeEqual
        );

    /*
     * Different key domains produce different specialized cache types.
     * There is no universal boxed/runtime key carrier in this experiment.
     */
    static assert(
        !is(
            OpaqueCache
            == CompositeCache
        )
    );

    return true;
}


bool runE83()
@safe
pure
nothrow
@nogc
{
    assert(runOpaqueSpecialization());
    assert(runCompositeSpecialization());
    assert(runCollisionQualification());
    assert(runNoRuntimeIdentityObjectRequirement());

    return true;
}
