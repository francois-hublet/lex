The core of a Lex formalization is a sequence of rules. We first present the general syntax of rules (a) and discuss the three different types or rules (b). Then, we give a more complete reference of Lex's expression syntax (c) and the optional patterns syntax (d).

### (a) Lex rules: General syntax

The general syntax of Lex rules is
```
`rule` [string]
[<indentation> doc_string]
    `whenever`
        expression
        ...
        expression
    verb 
        expression | reference
        ...
        expression | reference
[[[`transparently`] `enforceable`] 
[(`suppressing` | `causing`) ident, ..., ident]*]

verb := `oblige` | `constitute` | `except`
```

Each rule can be decomposed into five parts:

* The keyword `rule` followed by an optional string giving a name to the rule. Note: a unique for the rule name is **required** as soon as at least two rules are under the same lowest-level label. 

* An optional documentation string.

* The keyword `whenever` followed by a sequence of expressions (one by line) that describe the rule's premisses.

* A verb in `oblige`, `constitute` or `except` followed by a sequence of expressions or references (one by line, see the difference between expressions and references below) that describe the rule's conclusions.

* If the verb was `oblige`, an optional clause `transparently enforceable`... or `enforceable`... where the chosen keyword is followed by a list of statements of the form `suppressing Event_1, ..., Event_n`  or `causing Event_1, ..., Event_n`. The `enforceable` clause states that the obligation can always be fulfilled by causing or suppressing the corresponding events.  The `transparently enforceable` clause additionally states that the obligation is enforceable *and* that causing or suppressing events is only ever necessary when it is certain that the rule will be violated (i.e., enforcement is *precise*).

#### (b) Rule types

There are three types of rules in Lex: obligation rules, constitutive rules, and exception rules. Each rule type defines a different type of requirement:
* Obligation rules define a requirement of the form "if X is the case, then Y **shall** be the case".
* Constitutive rules introduce a definition of the form "X **counts as** Y".
* Exception rules state "if X is the case, then rules R **shall not be applicable**".

##### (i) Obligation rules

Obligation rules are introduced by the verb `oblige`. In an obligation rule, each line after `oblige` contains an expression denoting a fact.

If `premiss_1` to `premiss_m` are the premisses of an obligation rule and `conclusion_1` to `conclusion_n` its conclusions, then the rule means "whenever all of `premiss_1` to `premiss_m` are the case, then all of `conclusion_1` to `conclusion_n` must be the case".

Note that all obligation rules defined in a Lex program are by default cumulative, i.e., they must all hold at all times. An example can be found [here](../tutorials/gdpr.md#obligation-rule).

##### (ii) Constitutive rules

Constitutive rules are introduced by the verb `constitute`. In a constitutive rule, each line after `oblige` contains **a single `internal` event or predicate**.

If `premiss_1` to `premiss_m` are the premisses of a constitutive rule and `conclusion_1` to `conclusion_n` its conclusions, then the rule means "whenever all of `premiss_1` to `premiss_m` are the case, then `conclusion_1`to `conclusion_n` hold".

Note that such a constitutive rule generally does not introduce a necessary reason for the conclusions to hold, but only a sufficient condition. There may exist other rules in the code that define other conditions for the same conclusions to hold. An example can be found [here](../tutorials/gdpr.md#constitutive-rule).

##### (iii) Exception rules

Exception rules are introduced by the verb `except`. In an exception rule, each line after `except` contains a reference to a single rule name or label. If the  reference contains a rule name, then an exception is introduced only for the corresponding rule. If the reference contains a label, then an exception is introduced for each rule under this label (e.g., for a full chapter, article, point, etc.). Exceptions can be introduced for obligation rules, but also for constitutive rules and other exception rules.

If `premiss_1` to `premiss_m` are the premisses of an exception rule and `conclusion_1` to `conclusion_n` its conclusions, then the rule means "whenever all of `premiss_1` to `premiss_m` are the case, then rules in `conclusion_1`to `conclusion_n` shall not apply".

Note that such an exception rule generally does not introduce a necessary reason for the conclusions to hold, but only a sufficient condition. There may exist other rules in the code that define other conditions under which the referenced rules shall not hold.

References to a rule have the form

```mylang
rule "name_of_rule"
```

while references to a label have the form, e.g.,

```mylang
law "name_of_law"
chapter "number_of_chapter"
article "1" 
paragraph "2"
paragraph "6"
```
The current position in the law is used as root when resolving the labels: e.g., in the above example, `paragraph "6"` would automatically match article 6 *of the current article*. An example can be found [here](../tutorials/gdpr.md#exception-rule).

#### (c) Expressions

The syntax of expressions is

```
expr := ident `(` term `,` ... `,` term `)` 
                                       # Event / predicate
      | term `=` term                  # Equality
      | unop expr                      # Unary operator
      | expr binop expr                # Binary operator
      | untop [itv] expr               # Unary temporal operator
      | expr bintop [itv] expr         # Binary temporal operator
      | quant ident. expr              # Quantifier
      | ident `<-` agg `(`ident`;` ident`,` ...`,` ident`;` expr`)` 
	                                   # Aggregation

term := const                          # Constant
      | ident                          # Variable
      | term_unop term                 # Unary operator
      | term term_binop term           # Binary operator
      | ident `(` term `,` ... `,` term `)` 
	                                   # Function application

unop := `NOT`
binop := `OR` | `AND` | `IMPLIES` | `IFF`
untop := `PREVIOUS` | `NEXT` | `ONCE` | `EVENTUALLY` 
       | `HISTORICALLY` | `ALWAYS`
bintop := `SINCE` | `UNTIL`
quant := `EXISTS` | `FORALL`
agg := `CNT` | `MIN` | `MAX` | `AVG` | `MED` | `SUM` | `STD`

term_unop := `-`
term_binop := `+` | `-` | `*` | `/` | `^` | `=` 
            | `<>` | `<` | `>` | `<=` | `>=`

itv := (`[` | `)`) span `,` (span | `*`) (`]` | `)`)

const := `true` | `false` | int | float | string 
       | time | span | money
num := (`0`-`9`)+
int := [-] num
float := [-] num+ `.` num*
string := `"` .* `"`
time := `<backquote>` .* `<backquote>`
span := num [`s` | `m` | `h` | `d` | `M` | `y`]
money := `|` <currency_symbol> float `|`
```

Expressions combine events/predicates of the form `Event(term_1, ..., term_n)` and equations of the form `term_1 = term_2` to describe a combination of facts.

To create expressions, Lex provide standard logical operators (`NOT`, `OR`, `AND`, `IMPLIES`, `IFF`) and quantifiers (`EXISTS`, `FORALL`), but also
* Temporal operators: These describe sequences of events over time, as in temporal logic. Each temporal operator can be followed by an optional interval of the form `[a,b]`, `(a,b)`, `[a,b)`, `(a,b]`, `(a,*)`, or `[a,*)` (`*` stands for $\infty$). The available temporal operators are

`PREVIOUS expr`: Denotes that in this instant *immediately preceding the present*, `expr` was the case.
	
`NEXT expr`: Denotes that in this instant *immediately following the present*, `expr` will be the case.
	
`ONCE expr`: Denotes that *at some point in the past*, `expr` was the case.
	
`EVENTUALLY expr`: Denotes that *at some point in the future*, `expr` will be the case.

`HISTORICALLY expr`: Denotes that *at all instants in the past*, `expr` was the case.

`ALWAYS expr`: Denotes that *at all instants in the future*, `expr` will be the case.
	
`expr_1 SINCE expr_2`: Denotes that *at some point in the past*, `expr_2` was the case, and since that point, `expr_1` has been the case uninterruptedly until the present (included).
	
`expr_1 UNTIL expr_2`: Denotes that *at some point in the future*, `expr_2` will be the case, and until that point, `expr_1` will be the case uninterruptedly from the present (included).
	
The interval placed after the operator restricts the time distance between the `expr` (binary: `expr_2`) fact and the present. For instance, `ONCE[0,2d) expr` is true if, and only if, `expr` was true between 0 and 2 days in the past. See below for the description of the time spans used in interval bounds (such as `2d`).

Aggregations: These allow for computing the maximum, the minimum, the average... of a variable whenever some fact is the case, as in SQL. For example, `x <- MAX(a; ; E(a))` sets `x` to be the maximum of the variable `a` such that the event `E(a)` is the case in the present. In an aggregation of the form `x <- agg (y; z_1, ..., z_n; expr)`, `x`is the variable containing the aggregate value, `y` is the variable on which aggregation is performed, `z_1` to `z_n` are optional grouping variables, and `expr` is an expression used to filter relevant values of `y`.

Terms used in event/predicate arguments and equations can be:

* Constants:

	- Integer constants;
	
	- Float constants (must contain a `.`symbol);
	
	- String constants (in double quotes);
	
	- Time constants (in YYYY-MM-dd hh-mm-ss format, between back quotes);
	
	- Time span constants of the form `num [unit]` where `num` is an unsigned integer constant and unit is an optional time unit in `s` (seconds), `m` (minutes), `h` (hours), `d` (days), `M` (months), `y` (years). Absence of a time unit is interpreted as seconds;
	
	* Money constants (in `|` , unsigned int preceded by a currency symbol).
	
* Unary (`-`) or binary (`+`,  `-`, `*`, `/`,`^`, `=`,`<>`, `<`, `>`, `<=`, `>=`) operators.

* Function applications.

#### (d) Patterns

When all premisses or all conclusions of a rule should happen at the same time in the past or the future, a more natural, optional pattern syntax can be used. Patterns can be used after `whenever` and `oblige`, on the same line. Patterns cannot be used after `constitute` and `except`.

The syntax of patterns is

```
pattern := `eventually` [long_future_itv]
         | `once` [long_past_itv]
         | `always` `in` `the` `future` [long_future_itv]
         | `always` `in` `the` `past` [long_past_itv]
         | `eventually` `delaying` `if` expr [long_future_itv]
         | `always` `since` expr [long_past_itv]

long_past_itv := long_itv
               | `before` span
               | `strictly` `before` span

long_future_itv := long_itv
                 | `after` span
                 | `strictly` `after` span

long_itv := `within` span
          | `between` span `and` span
          | `strictly` `between` span `and` span
          | `between` span `and` span `excluded`
          | `between` span `excluded` `and` span
```

##### Example

>Whenever consent is given by a user, that user's personal data shall be processed at least once within a day

can be formalized as

```mylang
rule
    whenever
        GivesConsent(ds, c, p)
    oblige eventually within 1d
        DataProcessing(c, d, p, a)
        PersonalData(d, ds)
```
