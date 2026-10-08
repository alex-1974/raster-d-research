module retained_malloc;

// Research-only, malloc-backed reference-counted storage.
// Deliberately @system pending a full @trusted proof audit.
import core.stdc.stdlib : malloc, free;
import core.lifetime : move;

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
        p.data = cast(ubyte*) malloc(length);
        assert(p.data !is null);
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
        }
    }

    // This study intentionally avoids implicit assignment; the real raster-d
    // owner uses a reviewed by-value-swap assignment contract.
    @disable void opAssign(ref const RetainedStorage rhs);

    ubyte read(size_t index) const @system {
        assert(control !is null && index < control.length);
        return control.data[index];
    }

    void write(size_t index, ubyte value) @system {
        assert(control !is null && index < control.length);
        control.data[index] = value;
    }
}

struct RetainedView {
    RetainedStorage owner;
    size_t first;
    size_t length;

    ubyte read(size_t index) const @system {
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
    auto view = makeEscapingView();
    assert(view.read(0) == 13);
    auto copy = view;
    assert(copy.read(0) == 13);
}
