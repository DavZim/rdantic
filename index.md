A proof-of-concept port of pydantic's central idea to R. Types are
ordinary values built from operators R already has: 'int\[1\]' is one
integer, 'num\[. \> 0\]' is a positive double, 'A \| B' is a union.
Structs validate records, typed functions validate their arguments and
their result, and JSON is parsed, validated and written with the
declared types in hand. Coercion happens only where nothing can be lost,
and every problem is reported with the path where it occurred.
