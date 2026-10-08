module callback_closure_capture;
struct View { const(ubyte)[] data; }
View escaped;
@safe void withBorrow(scope const(ubyte)[] input, scope void delegate(scope View) @safe visitor)
{
    visitor(View(input));
}
@safe void leakViaNestedCallback(scope const(ubyte)[] input)
{
    void capture(scope View v) @safe
    {
        escaped = v;
    }
    withBorrow(input, &capture);
}
