# Parse and validate JSON in one step

JSON arrays come back as R vectors and arrays of objects as data frames,
because the declared types accept those shapes – there is no separate
JSON mode. Reshaping happens only here and in
[`from_list()`](https://davzim.github.io/rdantic/reference/from_list.md),
never when a value is handed straight to a type.

## Usage

``` r
from_json(t, txt)
```

## Arguments

- t:

  A type, or anything
  [`as_type()`](https://davzim.github.io/rdantic/reference/as_type.md)
  accepts.

- txt:

  A JSON string, or anything
  [`jsonlite::fromJSON()`](https://jeroen.r-universe.dev/jsonlite/reference/fromJSON.html)
  reads.

## Value

The validated value.

## See also

[`to_json()`](https://davzim.github.io/rdantic/reference/to_json.md),
[`from_list()`](https://davzim.github.io/rdantic/reference/from_list.md),
[`try_parse()`](https://davzim.github.io/rdantic/reference/try_parse.md)

## Examples

``` r
Reading <- struct("Reading", station = chr[1], celsius = num[1], at = datetime[1])
from_json(Reading, '{"station": "KOA", "celsius": 21.5, "at": "2024-05-17T09:30:00"}')
#> <Reading>
#>   station : "KOA"
#>   celsius : 21.5
#>   at      : 2024-05-17 09:30:00

from_json(map_of(int[1]), '{"cpu": 4, "memory": 16}')
#> $cpu
#> [1] 4
#> 
#> $memory
#> [1] 16
#> 
from_json(frame(id = int, nm = chr), '[{"id": 1, "nm": "a"}]')
#>   id nm
#> 1  1  a

try(from_json(Reading, '{"station": ["a", "b"], "celsius": 21.5, "at": "nope"}'))
#> Error : 2 validation problems in Reading
#>   $station  expected chr[1], got list[2]  -- length is 2, not 1
#>   $at       expected datetime[1], got chr[1] "nope"  -- expected YYYY-MM-DDThh:mm:ss
```
