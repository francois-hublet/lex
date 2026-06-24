# BGG

## Background
The Swiss Federal Supreme Court Act (BGG) serves as the primary legal framework governing the organization and procedure of the highest court in Switzerland. It defines the jurisdiction of the Federal Supreme Court, establishing the requirements for filing appeals against rulings from lower cantonal and federal authorities. A central purpose of the BGG is to ensure the uniform application of federal law and the protection of constitutional rights across the country. It outlines specific types of appeals, such as the civil, criminal, and public law appeals, each with distinct admissibility criteria like the "amount in dispute." Ultimately, the act functions as the procedural gatekeeper, determining which legal disputes qualify for final review at the national level.

The chapter we have chosen to formalize is [Chapter 3](https://www.fedlex.admin.ch/eli/cc/2006/218/de#chap_3). In general Chapter 3 establishes the specific procedural requirements and types of appeals available for bringing a case before the high court. It categorizes the primary legal remedies into distinct tracks, namely the unified appeal in civil, criminal, and public law matters, alongside the subsidiary constitutional appeal. This chapter dictates the strict admissibility criteria, such as the required "amount in dispute" and the standing of the parties involved. Furthermore, it outlines the formal grounds upon which a lower court's decision can be challenged, primarily focusing on violations of federal or international law. Essentially, it serves as the procedural roadmap for navigating the final stage of Swiss litigation.

---

## Formalization

### Types and Imports

Explanation:

At the beginning, we define all the imports, the name of the law, and all the types that we will need to define later on in order to define the events/predicates. First, we <span class="code-hover" data-line="1" data-block="1">import akomaNtoso BGG</span> it is a standard XML format for machine-readable legal documents. When importing such files, the text of the law is imported (as comments) to the corresponding parts of the legal formalization by the Lex compiler. The Lex documentation files of the formalization then show both the formalization and the original legal text imported from the XML files. Further information about imports and how to declare them can be found [here](../syntax/1_Imports.md). After we declared all imports, we start with the naming of the formalisation. One can see that the declaration follows the typical structure of law. We start with the <span class="code-hover" data-line="3" data-block="1">general name 'BGG' </span>. All <span class="code-hover" data-line="4" data-block="1">subsequent names</span> declare which part of the law we consider. Lastly, we need to declare certain types, we start by declaring the <span class="code-hover" data-line="6" data-block="1">type beschwerde</span> as int (1, 2, ...). Which means complaint. The text in triple quotes is the description in natural language. Similarly, we define the next <span class="code-hover" data-line="7" data-block="1">type akt</span>, which is also an int. The last two types are a bit different. Instances of those types are strings ("Alice", "Bob", ...). <span class="code-hover" data-line="8" data-block="1">Gericht</span> translated to english means court and <span class="code-hover" data-line="9" data-block="1">gegenstand</span> translates to subject matter. All details about types can be found [here](../syntax/3_Types.md).

```mylang {title="Link to source code", data-url="https://gitlab.inf.ethz.ch/OU-BASIN/lex/-/blob/new-typing/example/BGG/BGG.lex?ref_type=heads#L1-9"}
import akomaNtoso BGG

law "BGG"
chapter "3"

type beschwerde is int """eine Beschwerde"""
type akt is int """ein Akt"""
type gericht is string
type gegenstand is string
```

---

### Events and Predicates 

Explanation:

When we declare the events/predicates we essentially declare two things, describing how the types from above are connected and assigning the [behavior (internal, observable, etc.)](../syntax/5_Events.md). The <span class="code-hover" data-line="1" data-block="2"><span class="code-hover" data-line="2" data-block="2"><span class="code-hover" data-line="3" data-block="2"><span class="code-hover" data-line="4" data-block="2">first predicate</span></span></span></span> we define has default behavior because it has no keyword. It caputres the complaint about an action. Next we have an <span class="code-hover" data-line="6" data-block="2"><span class="code-hover" data-line="7" data-block="2"><span class="code-hover" data-line="8" data-block="2"><span class="code-hover" data-line="9" data-block="2">event</span></span></span></span> with key word "suppressable". Which will later be important for the behavior of the oblige rule. This event formalizes that the court will rule on an appeal. After that we again have a <span class="code-hover" data-line="11" data-block="2"><span class="code-hover" data-line="12" data-block="2"><span class="code-hover" data-line="13" data-block="2"><span class="code-hover" data-line="14" data-block="2">predicate</span></span></span></span> with the sepcial keyword "internal". This declares that the event is not happening in the real world, but rather used to refer to the fact that an appeal is admissible at a certain court. The rest are simple predicates that define facts, which will be later used to define the rules.

```mylang {.start-10, title="Link to source code", data-url="https://gitlab.inf.ethz.ch/OU-BASIN/lex/-/blob/new-typing/example/BGG/BGG.lex?ref_type=heads#L17-58"}
predicate anfechtungsObjekt
  """Beschwerde {b} fechtet Akt {a} an"""
  b: beschwerde
  a: akt

suppressable event beurteilt
  """Gericht {g} beurteilt Beschwerde {b}"""
  g: gericht
  b: beschwerde

internal predicate zulaessig
  """Beschwerde {b} ist bei Gericht {g} zulässig"""
  g: gericht
  b: beschwerde

predicate oeffentlichesRecht
  """Akt {a} ist ein Entscheid in Angelegenheiten des öffentlichen Rechts"""
  a: akt

predicate kantonalerErlass
  """Akt {a} ist ein kantonaler Erlass"""
  a: akt

predicate betrifft
  """Akt {a} betrifft {bet}"""
  a: akt
  bet: gegenstand
```

---

### Rules

Explanation:

To capture certain facts we need to be able to define rules. Lex supports three different rule types which aim to be similar to the rules we find in laws. All information about the types of rules and their syntax/semantics can be found in [this](../syntax/6_Rules.md) section of syntax reference. This fundamental rule defines the core procedural requirement of Article 82. It states that whenever a court evaluates a complaint, that complaint is legally required (oblige) to be admissible. The condition <span class="code-hover" data-line="10" data-block="3">"transparently enforceable suppressing condition[0]"</span> requires that the event beurteilt is declared with the keyword "suppressing". The behavior of the rules is the following. Whenever an appeal is not <span class="code-hover" data-line="9" data-block="3">admissible at a certain court</span> then the event that <span class="code-hover" data-line="7" data-block="3">the court will rule on an appeal</span> cannot hold. 

```mylang {.start-37, title="Link to source code", data-url="https://gitlab.inf.ethz.ch/OU-BASIN/lex/-/blob/new-typing/example/BGG/BGG.lex?ref_type=heads#L84-93"}
section "3"

article "82"

rule "principle"
  whenever
    beurteilt(g, b)
  oblige
    zulaessig(g, b)
  transparently enforceable suppressing condition[0]
```

Explanation:

This rule formalizes Article 82, Paragraph 1, Point a. It establishes that a complaint is admissible before the Federal Supreme Court if the challenged action is a decision concerning public law matters. In Lex such a fact can be captured by a constitute rule. Therefore, if all events/predicates in the whenever block hold. We can trigger the events/predicates in the constitute block. In other words, whenever the <span class="code-hover" data-line="6" data-block="4">challenged action</span> is a <span class="code-hover" data-line="7" data-block="4">decision concerning public law matters</span>, then the complaint is <span class="code-hover" data-line="9" data-block="4">admissible before the Federal Supreme Court</span>.

```mylang {.start-47, title="Link to source code", data-url="https://gitlab.inf.ethz.ch/OU-BASIN/lex/-/blob/new-typing/example/BGG/BGG.lex?ref_type=heads#L95-103"}
paragraph "1"
point "a"

rule
  whenever
    anfechtungsObjekt(b, a)
    oeffentlichesRecht(a)
  constitute
    zulaessig("Bundesgericht", b)
```

Explanation:

This rule formalizes Article 82, Paragraph 1, Point b. It specifies that a complaint to the Federal Supreme Court is admissible if the targeted object of challenge is a cantonal decree. We again use a constitute rule to formalize the fact. Whenever the <span class="code-hover" data-line="5" data-block="5">targeted object of challenge</span> is a <span class="code-hover" data-line="6" data-block="5">cantonal decree</span>, then the complaint is <span class="code-hover" data-line="8" data-block="5">admissible before the Federal Supreme Court</span>.

```mylang {.start-56, title="Link to source code", data-url="https://gitlab.inf.ethz.ch/OU-BASIN/lex/-/blob/new-typing/example/BGG/BGG.lex?ref_type=heads#L105-112"}
point "b"

rule
  whenever
    anfechtungsObjekt(b, a)
    kantonalerErlass(a)
  constitute
    zulaessig("Bundesgericht", b)
```

Explanation:

This rule formalizes Article 82, Paragraph 1, Point c. It grants admissibility before the Federal Supreme Court if the challenged act concerns political rights, popular elections, or referendums. We again use a constitute rule to formalize the fact. This example additionaly illustrates how we can use [logical operators](../syntax/6_Rules.md) in Lex. The formalization uses the OR operator to allow multiple instances of "betrifft" to trigger the constitute block. Whenever the <span class="code-hover" data-line="5" data-block="6">targeted object of challenge</span> concerns <span class="code-hover" data-line="6" data-block="6">political rights, popular elections, or referendums</span>, then the complaint is <span class="code-hover" data-line="8" data-block="6">admissible before the Federal Supreme Court</span>.

```mylang {.start-64, title="Link to source code", data-url="https://gitlab.inf.ethz.ch/OU-BASIN/lex/-/blob/new-typing/example/BGG/BGG.lex?ref_type=heads#L114-121"}
point "c"

rule
  whenever
    anfechtungsObjekt(b, a)
    betrifft(a, "politische Stimmberechtigung") OR betrifft(a, "Volkswahlen") OR betrifft(a, "Volksabstimmungen")
  constitute
    zulaessig("Bundesgericht", b)
```

---