module owned_return;
// GC-owned analogy only. Not a malloc-backed retained RasterLease implementation.
class Storage { ubyte[4] data; }
struct OwningView { Storage storage; }
@safe OwningView returnOwned()
{
    return OwningView(new Storage());
}
