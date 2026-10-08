module callback_escape;
struct View { const(ubyte)* ptr; }
View escaped;
@safe void withBorrow(scope const(ubyte)[] input, scope void delegate(View) visitor)
{
    visitor(View(input.ptr));
}
@safe void testEscape(scope const(ubyte)[] input)
{
    withBorrow(input, (View v) { escaped = v; });
}
