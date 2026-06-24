# IRC

## Background

IRC stands for 'Internal Revenue Code'. It is the primary statutory body of federal tax law in the U.S.. It fundamentally covers income, estate and gift, and employment taxes, as well as administrative procedures. This tutorial provides the formalisation of IRC § 121(a). You can see the exact wording of the law below for reference.

!!! info "26 U.S. Code § 121 - Exclusion of gain from sale of principal residence"

    (a) Exclusion
    
    Gross income shall not include gain from the sale or exchange of property if, during the 5-year period ending on the date of the sale or exchange, such property has been owned and used by the taxpayer as the taxpayer’s principal residence for periods aggregating 2 years or more.

---

## Formalization

The formilzation of IRC should illustrate more involved capabilities of Lex. The parts that were already explain in the tutorials for [GDPR](../tutorials/gdpr.md) and [BGG](../tutorials/bgg.md) are omitted and we provide only the explanations for functions. More information about functions can be found [here](../syntax/4_Functions.md).

### Types and Imports

```mylang {title="Link to source code", data-url="https://gitlab.inf.ethz.ch/OU-BASIN/lex/-/blob/new-typing/example/IRC/tax.lex?ref_type=heads#L1-16"}
law "U.S. Code"

title "26"

title[1] "A"

chapter "1"

chapter[1] "B"

section "III"

article "121"

type individual
type property
```

---

### Functions

Explanation: 

When we declare the events/functions we essentially declare two things, describing how the types from above are connected and assigning the behavior with a certain keyword (internal, functional, etc.). The <span class="code-hover" data-line="1" data-block="2"><span class="code-hover" data-line="2" data-block="2"><span class="code-hover" data-line="3" data-block="2">first function</span></span></span> we define captures the calculation of a day from a specific time. Next we have an event <span class="code-hover" data-line="5" data-block="2"><span class="code-hover" data-line="6" data-block="2"><span class="code-hover" data-line="7" data-block="2"><span class="code-hover" data-line="8" data-block="2"><span class="code-hover" data-line="9" data-block="2">"amount_excluded_from_gross_income_by_property"</span></span></span></span></span> with the keywords "internal functional". The special keyword "internal" declares that the event is not happening in the real world, while "functional" implies it returns a specific value (in this case, a USD currency amount). This specific event calculates the tax exclusion amount for a specific property transaction. After that we have another <span class="code-hover" data-line="11" data-block="2"><span class="code-hover" data-line="12" data-block="2"><span class="code-hover" data-line="13" data-block="2"><span class="code-hover" data-line="14" data-block="2">internal functional event</span></span></span></span> that aggregates these exclusions into a total dollar amount per individual across all their properties. The last <span class="code-hover" data-line="16" data-block="2"><span class="code-hover" data-line="17" data-block="2"><span class="code-hover" data-line="18" data-block="2"><span class="code-hover" data-line="19" data-block="2"><span class="code-hover" data-line="20" data-block="2">internal functional</span></span></span></span></span> event calculates a count (an integer value) to track residency duration, creating the factual conditions that will later be used to define the tax exemption rules.

```mylang {.start-17, title="Link to source code", data-url="https://gitlab.inf.ethz.ch/OU-BASIN/lex/-/blob/new-typing/example/IRC/tax.lex?ref_type=heads#L19-38"}
function day (
  t: time
) -> int
  
internal functional event amount_excluded_from_gross_income_by_property (
  p: property
  i: individual
) -> money USD
  """the amount excluded from gross income of individual {i} due to sale or exchange of property {p}"""

internal functional event amount_excluded_from_gross_income (
  i: individual
) -> money USD
  """the total amount excluded from gross income of individual {i} due to sale or exchange of properties"""

internal functional event time_in_principal_residence (
  i: individual
  p: property
) -> int
  """the number of days that individual {i} used property {p} as their principal residence"""
```

---

### Events and Predicates

```mylang {.start-37, title="Link to source code", data-url="https://gitlab.inf.ethz.ch/OU-BASIN/lex/-/blob/new-typing/example/IRC/tax.lex?ref_type=heads#L40-58"}
observable event uses_property_as_principal_residence
  """individual {i} uses property {p} as their principal residence"""
  i: individual
  p: property

observable event owns_property
  """individual {i} owns property {p}"""
  i: individual
  p: property

observable event gain_from_sale_or_exchange_of_property
  """individual {i} gains {g} from sale or exchange of their property {p}"""
  i: individual
  p: property
  g: money USD

observable event tax_day
  """it is tax day for individual {i}"""
  i: individual
```

---

### Rules

Explanation: 

This rule acts as a constitutive rule calculating the total days of primary residency. It states that whenever there is a capital gain from a property sale, a counter variable t aggregates unique days d within a 5 year window (ONCE[0, 5y]) where an individual concurrently owned and lived in the property as their principal residence. This accumulated count t is then used to constitute the final value of the <span class="code-hover" data-line="8" data-block="4">time_in_principal_residence event</span>.


```mylang {.start-56, title="Link to source code", data-url="https://gitlab.inf.ethz.ch/OU-BASIN/lex/-/blob/new-typing/example/IRC/tax.lex?ref_type=heads#L60-74"}
paragraph "a"

rule "time_in_principal_residence"
  whenever
    gain_from_sale_or_exchange_of_property(i, p, gain)
    t <- CNT (d; i, p; ONCE[0, 5y] uses_property_as_principal_residence(i, p) AND owns_property(i, p) AND ts(cur_time) AND (day(cur_time) = d))
  constitute
    time_in_principal_residence(i, p) = t
```

Explanation: 

The second rule evaluates the threshold for the tax exclusion on that specific property. If the previously calculated residency time t is greater than or equal to 730 days, it constitutes that the <span class="code-hover" data-line="7" data-block="5">amount_excluded_from_gross_income_by_property</span> matches the total capital gain realized from the sale.

```mylang {.start-64, title="Link to source code", data-url="https://gitlab.inf.ethz.ch/OU-BASIN/lex/-/blob/new-typing/example/IRC/tax.lex?ref_type=heads#L76-82"}
rule "amount_excluded_by_property"
  whenever
    gain_from_sale_or_exchange_of_property(i, p, gain)
    time_in_principal_residence(i, p) = t
    t >= 730
  constitute
    amount_excluded_from_gross_income_by_property(p, i) = gain
```

Explanation: 

Finally, the third rule introduces a local variable declaration using the fix keyword to define a currency type. On a designated tax day, this rule uses a summation aggregation (SUM) to safely combine all single-property exclusion amounts generated within the past year (ONCE[0, 1y)). The resulting sum a constitutes the total <span class="code-hover" data-line="8" data-block="6">amount_excluded_from_gross_income</span> across all properties for that individual.
  
```mylang {.start-71, title="Link to source code", data-url="https://gitlab.inf.ethz.ch/OU-BASIN/lex/-/blob/new-typing/example/IRC/tax.lex?ref_type=heads#L84-91"}
rule "amount_excluded"
  fix
    amount : money USD
  whenever
    tax_day(i)
    a <- SUM (amount; p, i; ONCE[0, 1y) amount_excluded_from_gross_income_by_property(p, i) = amount)
  constitute
    amount_excluded_from_gross_income(i) = a
```

---