The syntax of function declarations is
```
`function` ident
    ident `:` ident
    ident `:` ident
    ...
    ident `:` ident
`->` ident
[<identation> doc_string]
```
where identifiers  separated by a colon denote `(arg_type, arg_name)` pairs and the final identifier denotes the output type of the function. Function and argument identifiers are usually lower-case.

Note that Lex function declaration do not have to have an executable body. They merely declare function symbols that can be used within rules.

#### Examples

Assume two types

```mylang
type individual
type company
```

One can declare a function that returns the age of an individual as
``
```mylang
function age
    i : individual
-> int
    """the age of individual {i}"""
```

One can declare the company that an individual works for at a given date (assuming there is only one) as

```mylang
function employer
    i : individual
    d : time
-> company
    """the company employing individual {i} at date {d}"""
```
