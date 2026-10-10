module callback_escape;
struct View { const(ubyte)[] data; }
View escaped;
@safe void withBorrow(scope const(ubyte)[] input, scope void delegate(scope View) @safe visitor)
{
    visitor(View(input));
}
@safe void testEscape(scope const(ubyte)[] input)
{
    withBorrow(input, (View v) { escaped = v; });
}
