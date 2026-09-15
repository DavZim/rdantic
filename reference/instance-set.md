# Set a field of an instance

The field's type runs on the way in, so an instance cannot become
invalid after it is built, and a field that was never declared cannot be
invented by a typo. Assignment returns a new value; instances are not
references.

## Usage

``` r
# S3 method for class 'typed_instance'
x$name <- value

# S3 method for class 'typed_instance'
x[[i]] <- value

# S3 method for class 'typed_instance'
x[i] <- value
```

## Arguments

- x:

  An instance.

- name, i:

  A field name.

- value:

  The new value.

## Value

A new instance.

## Examples

``` r
Job <- struct("Job", state = one_of("queued", "done"), tries = int[1])
j <- Job(state = "queued", tries = 0)
j$state <- "done"
j$state
#> [1] "done"
try(j$state <- "exploded")
#> Error : 1 validation problem in Job
#>   $state  expected one_of("queued", "done"), got chr[1] "exploded"
try(j$stat <- "done")
#> Error : 1 validation problem in Job
#>   $stat  expected <no such field>, got chr[1] "done"  -- did you mean `state`?
k <- Job(state = "queued", tries = 0)
k["tries"] <- 1
k$tries
#> [1] 1
try(k["state"] <- "exploded")
#> Error : 1 validation problem in Job
#>   $state  expected one_of("queued", "done"), got chr[1] "exploded"
```
