# GDPR

## Background
GDPR stands for General Data Protection Regulation. It is a comprehensive privacy and security law passed by the European Union (EU) that imposes strict obligations on organizations anywhere, so long as they target or collect data related to people in the EU.

Here you can see the original laws we formalize throughout this tutorial. For the purpose of illustration we show the formalization of ==Article 5(1)(a)==, ==Article 6(1)(a)== and ==Article 6(1)(f)==.

!!! info "Art. 5 GDPR Principles relating to processing of personal data"

    1. Personal data shall be:

        - ==(a) processed lawfully, fairly and in a transparent manner in relation to the data subject (‘lawfulness, fairness and transparency’);==

        - (b) collected for specified, explicit and legitimate purposes and not further processed in a manner that is incompatible with those purposes; further processing for archiving purposes in the public interest, scientific or historical research purposes or statistical purposes shall, in accordance with Article 89(1), not be considered to be incompatible with the initial purposes (‘purpose limitation’);

        - (c) adequate, relevant and limited to what is necessary in relation to the purposes for which they are processed (‘data minimisation’);

        - (d) accurate and, where necessary, kept up to date; every reasonable step must be taken to ensure that personal data that are inaccurate, having regard to the purposes for which they are processed, are erased or rectified without delay (‘accuracy’);

        - (e) kept in a form which permits identification of data subjects for no longer than is necessary for the purposes for which the personal data are processed; personal data may be stored for longer periods insofar as the personal data will be processed solely for archiving purposes in the public interest, scientific or historical research purposes or statistical purposes in accordance with Article 89(1) subject to implementation of the appropriate technical and organisational measures required by this Regulation in order to safeguard the rights and freedoms of the data subject (‘storage limitation’);

        - (f) processed in a manner that ensures appropriate security of the personal data, including protection against unauthorised or unlawful processing and against accidental loss, destruction or damage, using appropriate technical or organisational measures (‘integrity and confidentiality’).

!!! info "Art. 6 GDPR Lawfulness of processing"

    1. Processing shall be lawful only if and to the extent that at least one of the following applies:

        - ==(a) the data subject has given consent to the processing of his or her personal data for one or more specific purposes;==

        - (b) processing is necessary for the performance of a contract to which the data subject is party or in order to take steps at the request of the data subject prior to entering into a contract;

        - (c) processing is necessary for compliance with a legal obligation to which the controller is subject;

        - (d) processing is necessary in order to protect the vital interests of the data subject or of another natural person;

        - (e) processing is necessary for the performance of a task carried out in the public interest or in the exercise of official authority vested in the controller;

        - ==(f) processing is necessary for the purposes of the legitimate interests pursued by the controller or by a third party, except where such interests are overridden by the interests or fundamental rights and freedoms of the data subject which require protection of personal data, in particular where the data subject is a child.==

        Point (f) of the first subparagraph shall not apply to processing carried out by public authorities in the performance of their tasks.

---
## Formalization 
In the following section we will formalize all of the above laws step-by-step. We provide the exact law as reference and highlight the words, sentences that are important for the formalization.

### First Step: Types
First we need to establish what kinds of persons or objects the law talks about. If we have done that we can start writing the Lex formalization. At the very top we define the types and imports. Each type corresponds to exactly one data type (by default int). 

Explanation:

To formalize Article 5, we first declare types capturing data processing activities, data, data subjects, legal bases, purposes, and entities. The legal_basis and purpose types are subtypes of string. The bold words below correspond to the defined types above. Supported types can be found in [this](../syntax/3_Types.md) section of the syntax reference section. In Lex, we define each person/object as a type. Also the <span class="code-hover" data-line="1" data-block="1">name of the law</span> is defined at the very top. Naming of certain parts of the program is designed to follow the structure of laws in general. Further information on how labels are defined and which labels can be used, you can find [here](../syntax/2_Labels.md).

```mylang {title="Link to source code", data-url="https://gitlab.inf.ethz.ch/OU-BASIN/lex/-/blob/new-typing/example/GDPR/gdpr.lex?ref_type=heads#L1-32"}
law "GDPR"

article "5" "Principles relating to processing of personal data"

type activity
type data
type data_subject
type legal_basis is string
type purpose is string
type entity
type interest

```
Reference: 

Art. 5(1): Personal <span class="code-hover" data-line="6" data-block="1">data</span> shall be:
(a) processed lawfully, fairly and in a transparent manner in relation to the <span class="code-hover" data-line="7" data-block="1">data subject</span>;

Art. 6(1): Processing shall be lawful only if and to the extent that at least one of the following applies:
(a) the <span class="code-hover" data-line="7" data-block="1" >data subject</span> has given consent to the processing of his or her personal data for one or more specific <span class="code-hover" data-line="9" data-block="1">purposes</span>;

Art. 6(1): Processing shall be lawful only if and to the extent that at least one of the following applies:
(f) processing is necessary for the purposes of the legitimate interests pursued by the controller or by a third party, except where such interests are overridden by the interests or fundamental rights and freedoms of the data subject which require protection of personal data, in particular where the data subject is a child.

---

### Second Step: Events and Predicates

Next we need to define the relevant events/predicates. In other words, what does the law say about these above-defined persons/objects. For this purpose Lex has so-called events/predicates. The law discusses some events (= actions, verbs) as well as predicates (= relations, adjectives). All information on the difference between event and predicate and all the keywords (internal, observable, ...) can be found [here](../syntax/5_Events.md).

Explanation:

Next, we need to declare events. The <span class="code-hover" data-line="1" data-block="2" ><span class="code-hover" data-line="2" data-block="2" ><span class="code-hover" data-line="3" data-block="2" ><span class="code-hover" data-line="4" data-block="2" ><span class="code-hover" data-line="5" data-block="2" ><span class="code-hover" data-line="6" data-block="2" >DataProcessing</span></span></span></span></span></span> event encodes data processing by a processor on behalf of a controller for a given purpose. It is marked as suppressable, e.g., the PEP can prevent data processing to avoid violations. The documentation string (docstring) in triple quotes describes the event’s legal meaning. The <span class="code-hover" data-line="8" data-block="2" ><span class="code-hover" data-line="9" data-block="2" ><span class="code-hover" data-line="10" data-block="2" ><span class="code-hover" data-line="11" data-block="2" >PersonalData</span></span></span></span> event encodes that data is personal to a data subject. The keyword observable indicates that we can only observe the corresponding action, but not prevent it or force it to happen. The <span class="code-hover" data-line="13" data-block="2" ><span class="code-hover" data-line="14" data-block="2" ><span class="code-hover" data-line="15" data-block="2" ><span class="code-hover" data-line="16" data-block="2" >IsLawful</span></span></span></span>, <span class="code-hover" data-line="18" data-block="2" ><span class="code-hover" data-line="19" data-block="2" ><span class="code-hover" data-line="20" data-block="2" >IsFair</span></span></span>, and <span class="code-hover" data-line="22" data-block="2" ><span class="code-hover" data-line="23" data-block="2" ><span class="code-hover" data-line="24" data-block="2" ><span class="code-hover" data-line="25" data-block="2" >IsTransparent</span></span></span></span> events denote that an activity is lawful, fair, and transparent, respectively. IsLawful is marked as internal as Article 6 defines ‘lawfulness.’ An internal event is an event that is not happening in the real-world, but rather used to refer to a certain fact defined in terms of concrete actions.

```mylang {.start-13, title="Link to source code", data-url="https://gitlab.inf.ethz.ch/OU-BASIN/lex/-/blob/new-typing/example/GDPR/gdpr.lex?ref_type=heads#L34-166"}
suppressable event DataProcessing
    """Data {d} is processed by processor {p} on behalf of controller {c} as part of data processing activity {a}"""
    p : entity
    c : entity
    a : activity
    d : data

observable event PersonalData
    """Data {d} is personal data of {ds}"""
    d : data
    ds : data_subject

internal event IsLawful
    """Activity {a} is lawful with legal basis {b}"""
    a : activity
    b : legal_basis

observable event IsFair
    """Activity {a} is fair """
    a : activity

observable event IsTransparent
    """Activity {a} is transparent in relation to data subject {ds}"""
    a : activity
    ds : data_subject
```
Reference: 

Art. 5(1): <span class="code-hover" data-line="8" data-block="2">Personal</span> data shall be:
(a) <span class="code-hover" data-line="1" data-block="2">processed</span> <span class="code-hover" data-line="13" data-block="2">lawfully</span>, <span class="code-hover" data-line="18" data-block="2">fairly</span> and <span class="code-hover" data-line="22" data-block="2">in a transparent manner</span> in relation to the data subject;

Art. 6(1): <span class="code-hover" data-line="1" data-block="2">Processing</span> shall be <span class="code-hover" data-line="13" data-block="2">lawful</span> only if and to the extent that at least one of the following applies:
(a) the data subject has <span class="code-hover" data-line="22" data-block="2">given consent to the processing of his or her personal data</span> for <span class="code-hover" data-line="1" data-block="3">one or more specific purposes</span>;

Below we define events that are only used in Art. 6(1)(a) and Art. 6(1)(f). 

```mylang {.start-38, title="Link to source code", data-url="https://gitlab.inf.ethz.ch/OU-BASIN/lex/-/blob/new-typing/example/GDPR/gdpr.lex?ref_type=heads#L34-166"}
suppressable event HasPurpose
    """Data processing activity {a} has purpose {p}"""
    a : activity
    p : purpose

observable event GiveConsent
    """Data subject {ds} gives consent to processor {c} to use their data for purpose {p}"""
    ds : data_subject
    p : purpose
    c : entity

observable event IsNecessaryForLegitimateInterest
    """Data processing activity {a} is necessary to protect the interest {i} of party {e}"""
    a : activity
    e : entity
    i : interest

observable event IsOverridenByDataSubjectInterests
    """Interest {i} of entity {e} is overriden by the interests of data subject {ds}, in particular when {ds} is a child """
    e : entity
    i : interest
    ds : data_subject
```
Reference:

Art. 6(1): Processing shall be lawful only if and to the extent that at least one of the following applies:
(f) processing is necessary <span class="code-hover" data-line="6" data-block="3">for the purposes of the legitimate interests pursued by the controller or by a third party</span>, except where such <span class="code-hover" data-line="12" data-block="3">interests are overridden by the interests or fundamental rights and freedoms of the data subject</span> which require protection of personal data, in particular where the data subject is a child.

---

### Third Step: Rules

The events/predicates defined above are combined to serve as the underlying law. We show the formalizations of the laws one-by-one because each of them illustrates a different rule type. Further reference on the exact syntax and semantics of rules can be found in [this](../syntax/6_Rules.md) section of syntax reference. Below we illustrate the concepts by providing an example for each rule type.

#### Obligation Rule

An obligation rule is a logical directive that mandates a specific action must be taken when certain conditions are met. It essentially functions as a "must-do" requirement, often defining the timeline, the actor responsible, and the consequences if the action is not performed. These rules are common in legal, regulatory, and automated compliance systems to ensure that necessary tasks are triggered by specific events.

Explanation:

We can now state the regulative rule in Article 5(1)(a). This rule expresses that whenever personal data is processed, processing must be lawful, fair, and transparent. The annotation <span class="code-hover" data-line="13" data-block="4"> transparently enforceable suppressing condition[0]</span> instructs Lex to suppress the first premise, i.e., <span class="code-hover" data-line="7" data-block="4">DataProcessing</span>, whenever needed. In other words whenever there <span class="code-hover" data-line="10" data-block="4">EXISTS</span> a legal basis where activity a is lawful, activity a is fair and  activity a is transparent in relation to data subject ds, then the events defined in the <span class="code-hover" data-line="6" data-block="4"><span class="code-hover" data-line="7" data-block="4"><span class="code-hover" data-line="8" data-block="4">whenever block</span></span></span> also hold. DataProcessing gets prevented whenever an event in the <span class="code-hover" data-line="9" data-block="4"><span class="code-hover" data-line="10" data-block="4"><span class="code-hover" data-line="11" data-block="4"><span class="code-hover" data-line="12" data-block="4">oblige block</span></span></span></span> gets violated. Note that more information about the keywords (EXISTS, ONCE, FORALL, ...) can be found [here](../syntax/6_Rules.md).

```mylang {.start-60, title="Link to source code", data-url="https://gitlab.inf.ethz.ch/OU-BASIN/lex/-/blob/new-typing/example/GDPR/gdpr.lex?ref_type=heads#L168-180"}
paragraph "1"

point "a"

rule 
    whenever
        DataProcessing(p, c, a, d)
        PersonalData(d, ds)
    oblige
        EXISTS b. IsLawful(a, b)
        IsFair(a)
        IsTransparent(a, ds)
    transparently enforceable suppressing condition[0]
```
Reference:

Art. 5(1): <span class="code-hover" data-line="8" data-block="4">Personal</span> data shall be:
(a) <span class="code-hover" data-line="7" data-block="4">processed</span> <span class="code-hover" data-line="10" data-block="4">lawfully</span>, <span class="code-hover" data-line="11" data-block="4">fairly</span> and <span class="code-hover" data-line="12" data-block="4">in a transparent manner</span> in relation to the data subject (‘lawfulness, fairness and transparency’);

#### Constitutive Rule

A constitutive rule serves as a functional definition that creates or constitutes a new form of behavior or institutional status. Unlike rules that merely regulate existing activities, these rules establish the very possibility of the activity itself. For instance, in a legal or technical framework, a specific event like GiveConsent does not just describe an action, but actually brings the status of "Lawfulness" into existence within that system. Without such rules, the institutional facts they define—such as legal validity, a scored point in a game, or a binding contract—would have no meaning or existence.

Explanation: Point 6(1)(a) constitutes lawfulness when consent has been given by the data subject, in the past or present, to process their data. This translates to the constitutive rule. Since consent may be given at any point prior to processing, we use the temporal keyword <span class="code-hover" data-line="11" data-block="5">ONCE</span> before GiveConsent on. In other words, a data processing activity is only legally or systemically permissible if the person whose data is being used has already given their consent for that specific reason. 

```mylang {.start-73, title="Link to source code", data-url="https://gitlab.inf.ethz.ch/OU-BASIN/lex/-/blob/new-typing/example/GDPR/gdpr.lex?ref_type=heads#L352-364"}
article "6" "Lawfulness of processing"

paragraph "1"

point "a"

rule
    whenever
        DataProcessing(pr, c, a, d)
        PersonalData(d, ds)
        FORALL p. HasPurpose(a, p) IMPLIES ONCE GiveConsent(ds, p, c)
    constitute
        IsLawful(a, "6(1)(a)")

```
Reference: 

Art. 6(1): <span class="code-hover" data-line="9" data-block="5">Processing</span> shall be <span class="code-hover" data-line="13" data-block="5">lawful</span> only if and to the extent that at least one of the following applies:
(a) the data subject has <span class="code-hover" data-line="11" data-block="5">given consent to the processing of his or her personal data</span> for one or more specific purposes;

#### Exception Rule

An exception rule is a logical mechanism that restricts or overrides the application of a primary rule under specific conflicting conditions. It functions by identifying a subset of circumstances—such as when a data subject's fundamental rights outweigh a processor's interests—where the typical legal or technical consequence is nullified. In the provided logic, while a "legitimate interest" would normally constitute lawfulness, the exception rule intervenes to prevent that status from being granted.

Explanation: 

Point 6(1)(f) contains an exception to processing based on “legitimate interest” when “such interests are overridden by the interests [...] of the data subject.” We formalize this with two rules. The <span class="code-hover" data-line="3" data-block="6"><span class="code-hover" data-line="4" data-block="6"><span class="code-hover" data-line="5" data-block="6"><span class="code-hover" data-line="6" data-block="6"><span class="code-hover" data-line="7" data-block="6"><span class="code-hover" data-line="8" data-block="6">first rule</span></span></span></span></span></span>  constitutes lawfulness when legitimate interest is claimed. The <span class="code-hover" data-line="10" data-block="6"><span class="code-hover" data-line="11" data-block="6"><span class="code-hover" data-line="12" data-block="6"><span class="code-hover" data-line="13" data-block="6"><span class="code-hover" data-line="14" data-block="6"><span class="code-hover" data-line="15" data-block="6">second rule</span></span></span></span></span></span> creates an exception to the first rule when the interests of the data subject prevail.

```mylang {.start-87, title="Link to source code", data-url="https://gitlab.inf.ethz.ch/OU-BASIN/lex/-/blob/new-typing/example/GDPR/gdpr.lex?ref_type=heads#L408-422"}
point "f"

rule "legitimate_interest"
    whenever
        DataProcessing(p, c, a, d)
        IsNecessaryForLegitimateInterest(a, e, i)
    constitute
        IsLawful(a, "6(1)(f)")

rule
    whenever
        PersonalData(d, ds)
        IsOverridenByDataSubjectInterests(e, i, ds)
    except
        rule "legitimate_interest"
```
Reference: 

Art. 6(1): Processing shall be lawful only if and to the extent that at least one of the following applies:
(f) processing is necessary for the purposes of the legitimate interests pursued by the controller or by a third party,<span class="code-hover" data-line="14" data-block="6"><span class="code-hover" data-line="15" data-block="6">except where such interests are overridden by the interests or fundamental rights and freedoms of the data subject which require protection of personal data</span></span>, in particular where the data subject is a child.

---

