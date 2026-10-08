module callback_local;
struct View { const(ubyte)[] data; }
@safe void withBorrow(scope const(ubyte)[] input, scope void delegate(View) visitor)
{
    visitor(View(input));
}
@safe void useLocally(scope const(ubyte)[] input)
{
    withBorrow(input, (View v) { auto length = v.data.length; assert(length <= input.length); });
}
