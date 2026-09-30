# Cache Identity Experiments

Status: E8.1 semantic false-hit matrix.

Issue: raster-d-research #5

## E8.1

The first experiment separates semantic raster identity from resident
representation compatibility.

Research-local semantic key:

```text
source identity
+ source generation
+ logical region
+ schema identity
```

Deliberately absent:

- provider block/tile coordinates;
- resident row stride;
- padding;
- allocation address;
- cache replacement metadata.

Expected final line:

```text
E8.1 PASS: semantic identity prevents false hits without resident-layout coupling
```
