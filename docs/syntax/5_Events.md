Together with type declarations, event declarations form the backbone of of a legal ontology. There are two kinds of events: *events proper*,  introduced with the keyword `event`, that denote real-world actions, and *predicates*, introduced with the keyword `predicate`, that denote relationships between entities.

The syntax of event declarations is
```
[capability] event_kind ident
[<indentation> doc_string]
    ident `:` ident
    ...
    ident `:` ident

event_kind := `event` | `predicate`

capability := `causable` | `causable` `observable` 
            | `causable` `suppressable` | `suppressable` 
			| `observable` | `internal`
```
where identifiers  separated by a colon denote `(arg_type, arg_name)` pairs. Event name identifiers usually use title case while event argument identifiers are lower-case. In documentation strings, one can refer to the value of argument `arg` using the syntax `{arg}`. Documentation strings should describe what concrete fact is being captured by the event declaration.

In an event declaration, the *capability* denotes what we assume to be able to do with the action encoded by the event at runtime in order to ensure compliance. The `observable` capability means that we can only observe the corresponding action, but not prevent it or force it to happen. The `causable` capability means that we can cause, i.e., force the action to be performed for any choice of its parameters. The `suppressable` capability means that we can suppress the action. This requires us to observe the action in the first place, and hence `suppressable` is stronger than `observable`. Causing and observing/suppressing are distinct capabilities, allowing for the combinations `causable observable` and `causable suppressable`. If no capability is specified, then the corresponding action might not even be observable. This is called a *non-observable* event. As a rule of thumb, we can assume most actions to be observable.

A special class of events are *internal events* (and, similarly, *internal predicates*), which are identified by the capability `internal`. An internal event is an event that is not happening in the real-world, but rather used to refer to a certain fact *defined in terms of concrete actions*.  For example, *fulfilling a legal requirement* is a legal fact that is typically defined in terms of certain tangible, more concrete actions. Such a legal fact would typically be defined as an internal event.

#### Examples

Assuming types

```mylang
type data
    """a piece of data"""
    
type data_subject
    """an identified or identifiable natural person"""
```

then the definition

>‘personal data’ means any information relating to an identified or identifiable natural person (‘data subject’);

is reflected into the predicate declaration

```mylang
observable predicate PersonalData
    """data {d} is personal data of data subject {ds}"""
    d : data
    ds : data_subject
```

---

To define data processing of a certain data by a company for a given purpose, one can use the event declaration

```mylang
suppressable event ProcessesData
    """company {c} processes data {d} for purpose {p} 
	   as part of data processing activity {a}"""
    c : company
    d : data
    p : purpose
    a : activity
```

The capability `suppressable` means that we assume to be able to prevent data processing if this would become necessary to guarantee legal compliance. This can be meaningful in the context of privacy law.

----

To define a data subject giving consent to a company to use their data for a given purpose, one can use the event declaration

```mylang
observable event GivesConsent
    """data subject {ds} gives consent to company {c} 
	   to use their data for purpose {p}"""
    ds : data_subject
    c : company
    p : purpose
```

Note that in this context, it would likely make little sense to make `GiveConsent` causable or suppressable, since causing or suppressing user consent would defy the purpose of data protection.
