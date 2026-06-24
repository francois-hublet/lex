The syntax of type declarations is
```
`type` ident [`is` (ident | atomic_type)]
[<identation> doc_string] 

atomic_type := `bool` | `int` | `float` | `string` 
             | `span` | `time` | `money` ident
```
where `ident` is an identifier and `doc_string` is an optional string in triple double quotes (`"""string"""`) giving a high-level description of objects of the given type. Type identifiers are usually lower-case.

The `is` clause specifies a base type for the new type. All constants from the base type can then be embedded in the new type, but elements belonging to the new type are still considered a separated sort. 

Lex's atomic types are:

* `bool` for Booleans;

* `int` for integers;

* `float` for floating-point numbers;

* `string` for strings;

* `span` for time spans;

* `time` for timestamps;

* `money c` for money in currency `c`.

#### Examples

One can declare the type of user IDs, represented as integers in a real-world system, as

```mylang
type user_id is int
    """a user identifier"""
```

---

One can declare the types of purposes of processing, represented as strings, as

```mylang
type purpose is string
    """a purpose of processing"""
```

---

One can declare the type of user consent actions, without a concrete base type, as

```mylang
type user_consent_action
```

Recall that both the `is` clause and the documentation string are optional.
