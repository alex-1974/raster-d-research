# R0.9 Retained Block Assembly

Issue: raster-d-research #7

Status: E9.1 block-grid policy boundary.

## E9.1

Compare fixed cache-block grids anchored at:

- global logical zero;
- logical-extent origin.

The experiment proves exact request coverage, partial-edge behavior and
overflow-safe huge-origin behavior.

Expected final line:

```text
E9.1 PASS: cache-block grid anchor is policy, not raster semantics
```
