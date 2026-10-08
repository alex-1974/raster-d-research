module borrowed_escape;
struct BorrowView { const(ubyte)* ptr; }
@safe BorrowView returnBorrow(scope const(ubyte)[] input)
{
    return BorrowView(input.ptr);
}
