module e8_5_identity_contract_failure;


/++
    Minimal semantics-blind cache used to qualify caller responsibility.
+/
private struct IdentityCache(
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

            if (
                !entry.occupied
                || sameKey(
                    entry.key,
                    key
                )
            )
            {
                entry.occupied = true;
                entry.key = key;
                entry.value = value;
                return true;
            }
        }

        return false;
    }


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
                return false;
            }

            if (
                sameKey(
                    entry.key,
                    key
                )
            )
            {
                value = entry.value;
                return true;
            }
        }

        value = Value.init;
        return false;
    }
}


/++
    Incorrect caller key: behavior identity is missing.
+/
private struct IncompleteKey
{
    size_t logicalRegionId;

    size_t generation;
}


private size_t incompleteHash(
    ref const IncompleteKey key
)
@safe
pure
nothrow
@nogc
{
    return
        key.logicalRegionId
        ^ (key.generation << 1);
}


private bool incompleteEqual(
    ref const IncompleteKey a,
    ref const IncompleteKey b
)
@safe
pure
nothrow
@nogc
{
    return a == b;
}


/++
    Correct key for the same source model.
+/
private struct CompleteKey
{
    size_t behaviorId;

    size_t logicalRegionId;

    size_t generation;
}


private size_t completeHash(
    ref const CompleteKey key
)
@safe
pure
nothrow
@nogc
{
    return
        key.behaviorId
        ^ (key.logicalRegionId << 1)
        ^ (key.generation << 2);
}


private bool completeEqual(
    ref const CompleteKey a,
    ref const CompleteKey b
)
@safe
pure
nothrow
@nogc
{
    return a == b;
}


private struct UnstableKey
{
    size_t semanticId;

    size_t accidentalCounter;
}


private size_t unstableHash(
    ref const UnstableKey key
)
@safe
pure
nothrow
@nogc
{
    return
        key.semanticId
        ^ (key.accidentalCounter << 1);
}


private bool unstableEqual(
    ref const UnstableKey a,
    ref const UnstableKey b
)
@safe
pure
nothrow
@nogc
{
    return a == b;
}


private struct EqualityKey
{
    size_t semanticId;

    size_t irrelevantSalt;
}


/++
    Equality deliberately ignores irrelevantSalt.
+/
private bool semanticOnlyEqual(
    ref const EqualityKey a,
    ref const EqualityKey b
)
@safe
pure
nothrow
@nogc
{
    return
        a.semanticId
        == b.semanticId;
}


/++
    Incorrect hash: includes a field ignored by equality.
+/
private size_t inconsistentHash(
    ref const EqualityKey key
)
@safe
pure
nothrow
@nogc
{
    return
        key.semanticId
        ^ (key.irrelevantSalt * 17);
}


/++
    Correct hash matching semanticOnlyEqual.
+/
private size_t consistentHash(
    ref const EqualityKey key
)
@safe
pure
nothrow
@nogc
{
    return key.semanticId;
}


private bool runIncompleteIdentityFalseHit()
@safe
pure
nothrow
@nogc
{
    IdentityCache!(
        IncompleteKey,
        int,
        8,
        incompleteHash,
        incompleteEqual
    ) cache;

    /*
     * Two sources have different behavior but the incorrect caller key omits
     * that distinction.
     */
    const sourceAKey =
        IncompleteKey(
            55,
            1
        );

    const sourceBKey =
        IncompleteKey(
            55,
            1
        );

    static assert(
        sourceAKey == sourceBKey
    );

    assert(
        cache.insert(
            sourceAKey,
            100
        )
    );

    int reused;

    const hit =
        cache.tryGet(
            sourceBKey,
            reused
        );

    /*
     * The cache cannot detect that value 100 belongs to behavior A while
     * behavior B should have produced 200.
     */
    assert(hit);
    assert(reused == 100);

    enum int semanticallyCorrectB = 200;

    const falseHitObserved =
        reused
        != semanticallyCorrectB;

    assert(falseHitObserved);

    return true;
}


private bool runCompleteIdentityPreventsFalseHit()
@safe
pure
nothrow
@nogc
{
    IdentityCache!(
        CompleteKey,
        int,
        8,
        completeHash,
        completeEqual
    ) cache;

    const sourceAKey =
        CompleteKey(
            10,
            55,
            1
        );

    const sourceBKey =
        CompleteKey(
            11,
            55,
            1
        );

    assert(
        cache.insert(
            sourceAKey,
            100
        )
    );

    int reused;

    assert(
        !cache.tryGet(
            sourceBKey,
            reused
        )
    );

    return true;
}


private bool runUnstableIdentityCausesMiss()
@safe
pure
nothrow
@nogc
{
    IdentityCache!(
        UnstableKey,
        int,
        8,
        unstableHash,
        unstableEqual
    ) cache;

    const insertedKey =
        UnstableKey(
            77,
            1
        );

    assert(
        cache.insert(
            insertedKey,
            700
        )
    );

    /*
     * Same semantic data, but an accidental counter changed between calls.
     */
    const laterKey =
        UnstableKey(
            77,
            2
        );

    int value;

    assert(
        !cache.tryGet(
            laterKey,
            value
        )
    );

    return true;
}


private bool runHashEqualityConsistencyRequirement()
@safe
pure
nothrow
@nogc
{
    const a =
        EqualityKey(
            9,
            1
        );

    const b =
        EqualityKey(
            9,
            99
        );

    assert(
        semanticOnlyEqual(
            a,
            b
        )
    );

    /*
     * A correct identity policy must preserve the standard hash invariant:
     *
     *     sameKey(a, b) => hashKey(a) == hashKey(b)
     */
    assert(
        consistentHash(a)
        == consistentHash(b)
    );

    assert(
        inconsistentHash(a)
        != inconsistentHash(b)
    );

    return true;
}


bool runE85()
@safe
pure
nothrow
@nogc
{
    assert(runIncompleteIdentityFalseHit());
    assert(runCompleteIdentityPreventsFalseHit());
    assert(runUnstableIdentityCausesMiss());
    assert(runHashEqualityConsistencyRequirement());

    return true;
}
