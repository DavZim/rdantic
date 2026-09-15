# Turn a list of row records into a data frame

jsonlite parses `[{...}, {...}]` as a list of records. An empty array
becomes a zero-row frame with columns of the declared types.

## Usage

``` r
.rows_to_df(rows, cols, path, name, extra)
```

## Arguments

- rows:

  The list of records.

- cols:

  The named list of column types.

- path:

  The path prefix for problem records.

- name:

  The frame type's name.

- extra:

  `"ignore"` or `"forbid"`, for row keys that were not declared.

## Value

A data frame, or a `typed_problems` object.

## Examples

``` r
rdantic:::.rows_to_df(list(list(a = 1), list(a = 2)), list(a = int), "", "frame(a)", "ignore")
#>   a
#> 1 1
#> 2 2
```
