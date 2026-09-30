module app;

import raster : Region2D;
import e7_2_retained_cache : runE72;


private struct CacheKey
{
    size_t sourceId;
    Region2D logicalRegion;
    size_t schemaId;
}


private struct CacheEntry
{
    bool occupied;
    CacheKey key;
    size_t retainedBytes;
    ulong lastUse;
    size_t pinCount;
}


private struct CacheStats
{
    size_t hits;
    size_t misses;
    size_t evictions;
}


private struct SemanticCache(size_t SlotCount)
{
    size_t budgetBytes;
    size_t retainedBytes;
    ulong clock;
    CacheStats stats;
    CacheEntry[SlotCount] entries;


    bool lookup(CacheKey key, out size_t slot)
    {
        foreach (i, ref entry; entries)
        {
            if (
                entry.occupied
                && entry.key == key
            )
            {
                ++clock;
                entry.lastUse = clock;
                ++stats.hits;
                slot = i;
                return true;
            }
        }

        ++stats.misses;
        slot = size_t.max;
        return false;
    }


    bool pin(size_t slot)
    {
        if (
            slot >= SlotCount
            || !entries[slot].occupied
        )
        {
            return false;
        }

        ++entries[slot].pinCount;
        return true;
    }


    bool unpin(size_t slot)
    {
        if (
            slot >= SlotCount
            || !entries[slot].occupied
            || entries[slot].pinCount == 0
        )
        {
            return false;
        }

        --entries[slot].pinCount;
        return true;
    }


    private ptrdiff_t findFreeSlot() const
    {
        foreach (i, ref const entry; entries)
        {
            if (!entry.occupied)
            {
                return cast(ptrdiff_t) i;
            }
        }

        return -1;
    }


    private ptrdiff_t findEvictionVictim() const
    {
        ptrdiff_t victim = -1;
        ulong oldestUse = ulong.max;

        foreach (i, ref const entry; entries)
        {
            if (
                entry.occupied
                && entry.pinCount == 0
                && (
                    victim < 0
                    || entry.lastUse < oldestUse
                )
            )
            {
                victim = cast(ptrdiff_t) i;
                oldestUse = entry.lastUse;
            }
        }

        return victim;
    }


    private bool evictOne()
    {
        const victim = findEvictionVictim();

        if (victim < 0)
        {
            return false;
        }

        const index = cast(size_t) victim;

        assert(entries[index].occupied);
        assert(entries[index].pinCount == 0);
        assert(retainedBytes >= entries[index].retainedBytes);

        retainedBytes -= entries[index].retainedBytes;
        entries[index] = CacheEntry.init;
        ++stats.evictions;

        return true;
    }


    bool insert(
        CacheKey key,
        size_t retainedByteCount,
        out size_t slot
    )
    {
        slot = size_t.max;

        if (
            retainedByteCount > budgetBytes
            || retainedByteCount > size_t.max - retainedBytes
        )
        {
            return false;
        }

        size_t existing;

        if (lookupWithoutStats(key, existing))
        {
            return false;
        }

        while (
            retainedBytes
            > budgetBytes - retainedByteCount
        )
        {
            if (!evictOne())
            {
                return false;
            }
        }

        ptrdiff_t freeSlot = findFreeSlot();

        if (freeSlot < 0)
        {
            if (!evictOne())
            {
                return false;
            }

            freeSlot = findFreeSlot();
        }

        assert(freeSlot >= 0);

        const index = cast(size_t) freeSlot;

        ++clock;

        entries[index] = CacheEntry(
            true,
            key,
            retainedByteCount,
            clock,
            0
        );

        retainedBytes += retainedByteCount;
        assert(retainedBytes <= budgetBytes);

        slot = index;
        return true;
    }


    private bool lookupWithoutStats(
        CacheKey key,
        out size_t slot
    ) const
    {
        foreach (i, ref const entry; entries)
        {
            if (
                entry.occupied
                && entry.key == key
            )
            {
                slot = i;
                return true;
            }
        }

        slot = size_t.max;
        return false;
    }


    bool contains(CacheKey key) const
    {
        size_t slot;
        return lookupWithoutStats(key, slot);
    }
}


private CacheKey key(
    size_t sourceId,
    size_t x,
    size_t y,
    size_t width,
    size_t height,
    size_t schemaId = 1
)
{
    return CacheKey(
        sourceId,
        Region2D(
            x,
            y,
            width,
            height
        ),
        schemaId
    );
}


private bool runIdentityCase()
{
    enum size_t providerWidth = 16;
    enum size_t providerHeight = 8;

    const request =
        Region2D(
            13,
            11,
            23,
            13
        );

    const cacheBlockA =
        key(
            7,
            8,
            8,
            12,
            10
        );

    const cacheBlockB =
        key(
            7,
            20,
            8,
            12,
            10
        );

    assert(request.x % providerWidth != 0);
    assert(request.y % providerHeight != 0);
    assert(cacheBlockA.logicalRegion.width != providerWidth);
    assert(cacheBlockA.logicalRegion.height != providerHeight);
    assert(cacheBlockA.logicalRegion != request);
    assert(cacheBlockB.logicalRegion != request);

    SemanticCache!4 cache;
    cache.budgetBytes = 256;

    size_t slotA;
    size_t slotB;

    assert(cache.insert(cacheBlockA, 96, slotA));
    assert(cache.insert(cacheBlockB, 96, slotB));
    assert(cache.retainedBytes == 192);

    size_t found;

    assert(cache.lookup(cacheBlockA, found));
    assert(found == slotA);
    assert(cache.stats.hits == 1);

    const absent =
        key(
            7,
            32,
            8,
            12,
            10
        );

    assert(!cache.lookup(absent, found));
    assert(cache.stats.misses == 1);

    return true;
}


private bool runEvictionAndPinCase()
{
    SemanticCache!3 cache;
    cache.budgetBytes = 200;

    const a = key(1, 0, 0, 10, 10);
    const b = key(1, 10, 0, 10, 10);
    const c = key(1, 20, 0, 10, 10);

    size_t aSlot;
    size_t bSlot;
    size_t cSlot;

    assert(cache.insert(a, 80, aSlot));
    assert(cache.insert(b, 80, bSlot));
    assert(cache.retainedBytes == 160);

    assert(cache.pin(aSlot));

    /*
     * Adding C requires one eviction. A is older than B, but pinned, so B must
     * be evicted instead.
     */
    assert(cache.insert(c, 80, cSlot));

    assert(cache.contains(a));
    assert(!cache.contains(b));
    assert(cache.contains(c));
    assert(cache.retainedBytes == 160);
    assert(cache.stats.evictions == 1);

    assert(cache.unpin(aSlot));

    /*
     * Touch C, making A the least recently used unpinned entry.
     */
    size_t found;
    assert(cache.lookup(c, found));

    const d = key(1, 30, 0, 10, 10);
    size_t dSlot;

    assert(cache.insert(d, 80, dSlot));
    assert(!cache.contains(a));
    assert(cache.contains(c));
    assert(cache.contains(d));
    assert(cache.stats.evictions == 2);
    assert(cache.retainedBytes <= cache.budgetBytes);

    return true;
}


private bool runOversizedCase()
{
    SemanticCache!2 cache;
    cache.budgetBytes = 128;

    size_t slot;

    assert(
        !cache.insert(
            key(9, 1_000_000, 2_000_000, 64, 64),
            129,
            slot
        )
    );

    assert(cache.retainedBytes == 0);
    assert(cache.stats.evictions == 0);

    return true;
}


private bool runPinnedBudgetFailureCase()
{
    SemanticCache!2 cache;
    cache.budgetBytes = 128;

    const a = key(4, 100, 100, 8, 8);
    const b = key(4, 108, 100, 8, 8);

    size_t aSlot;
    size_t bSlot;

    assert(cache.insert(a, 96, aSlot));
    assert(cache.pin(aSlot));

    /*
     * B fits individually, but cannot be admitted while A is pinned because
     * the strict cache budget would be exceeded.
     */
    assert(!cache.insert(b, 64, bSlot));

    assert(cache.contains(a));
    assert(!cache.contains(b));
    assert(cache.retainedBytes == 96);
    assert(cache.stats.evictions == 0);

    return true;
}


void main()
{
    assert(runIdentityCase());
    assert(runEvictionAndPinCase());
    assert(runOversizedCase());
    assert(runPinnedBudgetFailureCase());
    assert(runE72());

    import std.stdio : writeln;

    writeln(
        "E7.1 PASS: cache identity, byte budget, pinning and deterministic eviction"
    );

    writeln(
        "E7.2 PASS: RasterLease retention, eviction survival and physical-byte accounting"
    );
}
