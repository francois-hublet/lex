Labels define the structure of the law, dividing it into chapters, articles, paragraphs, etc.

The syntax of labels is as follows:
```
label_kind [`[` num `]`] quoted_string [quoted_string]

label_kind := `law` | `title` | `chapter` | `section` 
            | `article` | `paragraph` | `point` | `subpoint`
```
where `num`denotes an integer $\geq 1$ and `quoted_string` denotes a string in double quoted.

Each label defines  a part of the corresponding law; depending on the `label_kind`, it can be a full law, a title, a chapter, a section, and article, a paragraph, a  point, or a subpoint. This order is fixed (i.e., a title is always a sub-part of a law, a chapter is always a sub-part of a title, etc.). To define intermediate levels in the hierarchy (e.g., subchapters, subparagraphs...) , a positive number can be specified in square brackets after the `label_kind`.

Each label can contain two quoted strings. The first quoted string is compulsory and constitutes the label's identifier, often a number or letter. The second quoted string is optional and specifies the label's title.

In Lex, as in the law, there are no explicit markers for ends of laws, articles, etc. The part of the law covered by a label starts with this label and ends when a label of the same or a higher level is reached.

Lex enforces the followings constraints on labels:
* Every label other than `law` must be defined within the scope of a `law`.
* Every rule must be defined within a `law` and an `article`.
* Every identifier at a given level must be unique among the identifiers of the next-higher level.
* Identifiers of `article` must be unique within the scope of a `law`.

#### Examples

> Article 6. Lawfulness of processing

is formalized as

```mylang 
article "6" "Lawfulness of processing"
```

---

> 1. Processing shall be lawful only if...
>    (a)
>    ...
>    (f) ...
> Point (f) of the first subparagraph shall not apply... 

is formalized as
```mylang
paragraph "1"
paragraph[1] "1"
point "a"
...
point "f"
...
paragraph[1] "2"
...
```
with `paragraph[1]` introducing subparagraphs.
