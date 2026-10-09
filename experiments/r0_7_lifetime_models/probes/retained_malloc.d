module retained_malloc;

// Research-only, malloc-backed reference-counted storage.
// Deliberately @system pending a full @trusted proof audit.
import core.stdc.stdlib : malloc, free;
import core.lifetime : move;

private __gshared size_t finalReleases;

private struct Control {
    size_t references;
    size_t length;
    ubyte* data;
}

struct RetainedStorage {
private:
    Control* control;

public:
    static RetainedStorage allocate(size_t length) @system {
        auto p = cast(Control*) malloc(Control.sizeof);
        assert(p !is null);
        p.references = 1;
        p.length = length;
        // This prototype supports nonempty payloads only; failure handling
        // must dispose of the control block before reporting OOM.
        assert(length > 0);
        p.data = cast(ubyte*) malloc(length);
        if (p.data is null) {
            free(p);
            assert(0, "payload malloc failed");
        }
        RetainedStorage result;
        result.control = p;
        return result;
    }

    this(this) @system {
        if (control !is null) {
            assert(control.references != size_t.max);
            ++control.references;
        }
    }

    ~this() @system {
        auto p = control;
        control = null;
        if (p is null) return;
        assert(p.references > 0);
        if (--p.references == 0) {
            free(p.data);
            free(p);
            ++finalReleases;
        }
    }

    // By-value copy/retain + swap: rhs's destructor releases the old lhs.
    void opAssign(RetainedStorage rhs) @system {
        import std.algorithm.mutation : swap;
        swap(control, rhs.control);
    }

    ubyte read(size_t index) const @system nothrow @nogc {
        assert(control !is null && index < control.length);
        return control.data[index];
    }

    // Research-only unchecked accessor: caller must validate index and owner.
    ubyte readUnchecked(size_t index) const @system nothrow @nogc {
        return control.data[index];
    }

    // Research-only pointer borrowed while this owner stays alive.
    const(ubyte)* rawPointer() const @system nothrow @nogc {
        return control.data;
    }

    void write(size_t index, ubyte value) @system nothrow @nogc {
        assert(control !is null && index < control.length);
        control.data[index] = value;
    }
}

struct RetainedView {
    RetainedStorage owner;
    size_t first;
    size_t length;

    ubyte read(size_t index) const @system nothrow @nogc {
        assert(index < length);
        return owner.read(first + index);
    }
}

// Returning this view is lifetime-correct by structural ownership, even
// without lexical escape analysis: returning a value retains the control.
RetainedView makeEscapingView() @system {
    auto storage = RetainedStorage.allocate(4);
    storage.write(0, 13);
    auto view = RetainedView(storage, 0, 4);
    return move(view);
}

unittest {
    const before = finalReleases;
    {
        auto view = makeEscapingView();
        assert(view.read(0) == 13);
        auto copy = view;
        assert(copy.read(0) == 13);
    }
    assert(finalReleases == before + 1);
}

unittest {
    const before = finalReleases;
    {
        auto first = RetainedStorage.allocate(8);
        auto second = RetainedStorage.allocate(8);
        first.write(0, 17);
        second.write(0, 29);
        auto aliasOfFirst = first;
        first = second;
        assert(first.read(0) == 29);
        assert(aliasOfFirst.read(0) == 17);
        auto moved = move(first);
        assert(moved.read(0) == 29);
    }
    assert(finalReleases == before + 2);
}
