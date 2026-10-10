module borrowed_escape;
struct BorrowView { const(ubyte)[] data; }
@safe BorrowView returnBorrow(scope const(ubyte)[] input)
{
    return BorrowView(input);
}
