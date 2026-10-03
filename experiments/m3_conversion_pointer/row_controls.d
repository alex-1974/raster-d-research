// Isolated actual helper: empty and short/tail widths, every input byte,
// complete destination/source guards. No production fixture internals needed.
import std.stdio : writeln;
void main() @safe
{
    foreach(width; [0UL,1UL,15UL,16UL,17UL,31UL,255UL,256UL,257UL]){
        ubyte[273] source;float[273] target;
        foreach(i;0..source.length)source[i]=cast(ubyte)(i*37+11);
        target[]=-17.0f;const before=source;
        convertApprovedRow(source[8..8+width],target[8..8+width]);
        assert(source==before);
        foreach(i;0..target.length)
            assert(target[i]==(i>=8 && i<8+width ? cast(float)source[i] : -17.0f));
    }
    writeln("PASS narrow helper: 9 widths, all-256 corpus, complete guards");
}
