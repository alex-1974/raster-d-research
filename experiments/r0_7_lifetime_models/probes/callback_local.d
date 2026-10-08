module callback_local;
struct View { const(ubyte)* ptr; }
@safe void withBorrow(scope const(ubyte)[] input, scope void delegate(View) visitor)
{
    visitor(View(input.ptr));
}
@safe void useLocally(scope const(ubyte)[] input)
{
    withBorrow(input, (View v) { auto pointer = v.ptr; });
}
