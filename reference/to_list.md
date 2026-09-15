# Convert an instance to plain lists

Recursively, so nested structs come back as nested named lists.

## Usage

``` r
to_list(x)
```

## Arguments

- x:

  An instance, a list, or any other value.

## Value

The same shape with every instance replaced by a named list.

## Examples

``` r
Pin <- struct("Pin", lat = num[1], lon = num[1])
Trip <- struct("Trip", from = Pin, to = Pin)
str(to_list(Trip(from = Pin(lat = 1, lon = 2), to = Pin(lat = 3, lon = 4))))
#> List of 2
#>  $ from:List of 2
#>   ..$ lat: num 1
#>   ..$ lon: num 2
#>  $ to  :List of 2
#>   ..$ lat: num 3
#>   ..$ lon: num 4
```
