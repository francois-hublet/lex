law "GDPR"

note "This is a draft formalization of GDPR Articles 5-10, 12-22, 30, 45(1), 46(1), 49"
note "Author: XXX"
note "Date: 29 April 2026"
note "Status: Tested"

import formex GDPR

type activity
type data
type data_subject
type purpose is string
type entity
type interest
type contract
type legal_basis is string
type legal_obligation is string
type public_interest is string
type vital_interests is string
type declaration
type special_data_category is string
type request
type country_or_international_organisation
type criteria
type requirement is string
type file
type country_io
type safeguards
type register

article "5" "Principles relating to processing of personal data"

observable predicate PersonalData
    """Data {d} is personal data of data subject {ds}"""
    d : data
    ds : data_subject

suppressable event DataProcessing
    """Data {d} is processed by processor {p} on behalf of controller {c} as part of data processing activity {a}"""
    p : entity
    c : entity
    a : activity
    d : data

internal predicate IsLawful 
    """Data processing activity {a} is lawful with legal basis {b}"""
    a : activity
    b : legal_basis

observable predicate IsFair
    """Data processing activity {a} is fair"""
    a : activity

observable predicate IsTransparent
    """Data processing activity {a} is transparent in relation to data subject {ds}"""
    a : activity
    ds : data_subject

observable event IsCollection
    """Data processing activity {a} collects personal data from data subject {ds}"""
    a : activity 
    ds : data_subject

suppressable predicate HasPurpose
    """Data processing activity {a} has purpose {p}"""
    a : activity
    p : purpose

internal predicate CompatibleWithPurpose
    """Purpose {p'} is compatible with purpose {p}, taking into account ... (see Art. 6(4))"""
    p' : purpose
    p  : purpose

observable predicate IsCompatibleWithPurpose
    """Purpose {p'} is compatible with purpose {p}"""
    p' : purpose
    p  : purpose

observable predicate IsSpecified
    """Purpose {p} is specified"""
    p : purpose

observable predicate IsExplicit
    """Purpose {p} is explicit"""
    p : purpose

observable predicate IsLegitimate
    """Purpose {p} is legitimate"""
    p : purpose

observable predicate IsArchival
    """Purpose {p} is one of the purposes described in Article 89(1)"""
    p : purpose

observable predicate IsAdequate
    """Data {d} is adequate in relation to purpose {p}"""
    d : data
    p : purpose

observable predicate IsRelevant
    """Data {d} is relevant in relation to purpose {p}"""
    d : data
    p : purpose

observable predicate IsLimitedToWhatIsNecessary
    """Data {d} is limited to what is necessary in relation to purpose {p}"""
    d : data
    p : purpose

observable predicate IsInaccurate
    """Data {d} is inaccurate in relation to purpose {p}"""
    d : data
    p : purpose

observable predicate IsUpToDate
    """Data {d} is up to date in relation to purpose {p}, where necessary"""
    d : data
    p : purpose

observable predicate UndueDataDelay
    """Data {d} is not deleted or rectified with undue delay"""
    d : data

causable observable event Delete
    """Data {d} is deleted"""
    d : data

internal predicate IsObligedToDelete
    """Controller {c} is obliged to delete data {d}."""
    c : entity
    d : data

observable event DataReview
    """Controller {c} reviews data {d} for the purpose of erasure. Must occur regularly to comply with the
       storage limitation principle."""
    c : entity
    d : data

causable observable event Rectify
    """Data {d_old} is rectified into {d_new}"""
    d_old : data
    d_new : data

observable predicate EnsuresAppropriateSecurity
    """Activity {a} ensures appropriate security of data {d}, including ... (see Art. 5(1)(f))"""
    a : activity
    d : data

suppressable event Stored
    """Data {d} is stored"""
    d : data

observable predicate IsNecessary
    """Data {d} is necessary to fulfill purpose {p}"""
    d : data
    p : purpose

observable predicate TechnicalAndOrganisationalMeasures
    """Appropriate technical and organisational measures have been taken to justify an exception to storage limiation requirements for activity {a} as by Article 89(1)"""
    a : activity

observable predicate JustifiesStorage
    """Activity {a} justifies the storage of data {d}"""
    a : activity
    d : data

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

point "b"

rule "must_have_purpose"
    whenever
        DataProcessing(pr, c, a, d)
        PersonalData(d, ds)
    oblige 
        EXISTS p. HasPurpose(a, p)
    transparently enforceable suppressing condition[0]

rule "purpose_conditions"
    whenever
        HasPurpose(a, p)
    oblige
        IsSpecified(p)
        IsExplicit(p)
        IsLegitimate(p)
    transparently enforceable suppressing condition[0]

rule "purpose_limitation"
    whenever
        DataProcessing(pr, co, a, d)
        PersonalData(d, ds)
        HasPurpose(a, p)
    oblige
        ONCE (EXISTS col_pr, col_co, c, col_ds, col_p. DataProcessing(col_pr, col_co, c, d) AND IsCollection(c, col_ds) AND HasPurpose(c, col_p) AND CompatibleWithPurpose(p, col_p))
    transparently enforceable suppressing condition[0]

rule "general_purpose"
    whenever
        IsCompatibleWithPurpose(a, p)
    constitute
        CompatibleWithPurpose(a, p)
  
rule "archiving_purpose"
    whenever
        IsArchival(p)
    constitute
        CompatibleWithPurpose(p, "Archiving")

point "c"

rule
    whenever
        DataProcessing(pr, co, a, d)
        PersonalData(d, ds)
        HasPurpose(a, p)
    oblige 
        IsAdequate(d, p)
        IsRelevant(d, p)
        IsLimitedToWhatIsNecessary(d, p)
    transparently enforceable suppressing condition[0]

point "d"

rule "accurate_and_up_to_date"
    whenever
        DataProcessing(pr, co, a, d)
        HasPurpose(a, p)
    oblige
        NOT IsInaccurate(d, p)
        IsUpToDate(d, p)
    transparently enforceable suppressing condition[0]

rule "accuracy_deletion"
    whenever
        IsInaccurate(d, p)
        EXISTS c, ds'. ONCE (DataProcessing(pr, co, c, d) AND IsCollection(c, ds') AND HasPurpose(c, p))
    oblige
        (NOT UndueDataDelay(d)) UNTIL (Delete(d) OR EXISTS d'. Rectify(d, d'))
    transparently enforceable causing effects

point "e"

rule "temporal_storage_limitation"
    whenever
        Stored(d)
        PersonalData(d, ds)
        EXISTS c, ds'. ONCE (DataProcessing(pr, co, c, d) AND IsCollection(c, ds') AND HasPurpose(c, p))
    oblige
        IsNecessary(d, p)
    transparently enforceable suppressing condition[0]
rule "storage_limitation_exception"
    whenever
        EXISTS p. HasPurpose(a, p) AND IsArchival(p) AND TechnicalAndOrganisationalMeasures(a) AND JustifiesStorage(a, d)
    except
        rule "temporal_storage_limitation"

point "f"

rule
    whenever
        DataProcessing(p, c, a, d)
    oblige
        EnsuresAppropriateSecurity(a, d)
    transparently enforceable suppressing condition[0]

article "6" "Lawfulness of processing"

suppressable event GiveConsent
    """Data subject {ds} gives consent to processor {c} to use their data for purpose {p}.
       Per Art. 4(11), consent means 'any freely given, specific, informed and unambiguous indication of the data subject's wishes by which they, 
       by a statement or by a clear affirmative action, signifies agreement to the processing of personal data relating to them.'
       Per Art. 7(4), 'when assessing whether consent is freely given, utmost account shall be taken of whether, inter alia, the performance of a contract,
       including the provision of a service, is conditional on consent to the processing of personal data that is not necessary for the performance of that contract.'"""
    ds : data_subject
    p : purpose
    c : entity

observable predicate IsNecessaryForLegitimateInterest
    """Data processing activity {a} is necessary to protect the interest {i} of party {e}"""
    a : activity
    e : entity
    i : interest

observable predicate IsOverriddenByDataSubjectInterests
    """Interest {i} of entity {e} is overriden by the interests of data subject {ds}, in particular when {ds} is a child"""
    e : entity
    i : interest
    ds : data_subject

observable predicate IsPublicAuthority
    """Entity {e} is a public authority"""
    e : entity

observable predicate IsPerformanceOfPublicAuthorityTask
    """Data processing activity {a} is part of the performance of a public authority task"""
    a : activity

observable event StartContract
    """The period of effect of contract {co} starts"""
    co : contract

observable predicate PrepareContract
    """The contract {co} is being prepared"""
    co : contract

observable event EndContract
    """The period of effect of contract {co} ends"""
    co : contract

observable predicate IsNecessaryForContract
    """Data processing activity {a} is necessary for the performance of contract {co}"""
    a : activity
    co : contract

observable predicate IsContractParty
    """Data subject {ds} is a party to contract {co}"""
    ds : data_subject
    co : contract

observable predicate IsNecessaryForLegalObligation
    """Data processing activity {a} is necessary for the performance of legal obligation {l}"""
    a : activity
    l : legal_obligation

observable predicate IsNecessaryForVitalInterests
    """Data processing activity {a} is necessary to protect the vital interests {v} of person {ds'}"""
    a : activity
    ds' : data_subject
    v : vital_interests

observable predicate IsNecessaryForPublicInterest
    """Data processing activity {a} is necessary for the performance of a task carried out in the public interest
       or in the exercise of official authority, with {pi} being the specific public interest"""
    a : activity
    pi : public_interest

paragraph "1"

paragraph[1] "1"

point "a"

rule
    whenever
        DataProcessing(pr, c, a, d)
        PersonalData(d, ds)
        NOT (EXISTS p. HasPurpose(a, p) AND NOT (ONCE GiveConsent(ds, p, c)))
    constitute
        IsLawful(a, "6(1)(a)")

point "b"

rule
    whenever
        DataProcessing(pr, c, a, d)
        PersonalData(d, ds)
        (NOT EndContract(co)) SINCE (PrepareContract(co) OR StartContract(co))
        ONCE (StartContract(co) AND IsContractParty(ds, co))
        IsNecessaryForContract(a, co)
    constitute
        IsLawful(a, "6(1)(b)")

point "c"

rule
    whenever
        DataProcessing(pr, c, a, d)
        PersonalData(d, ds)
        IsNecessaryForLegalObligation(a, l)
    constitute
        IsLawful(a, "6(1)(c)")

point "d"

rule
    whenever
        DataProcessing(pr, c, a, d)
        PersonalData(d, ds)
        IsNecessaryForVitalInterests(a, ds', v)
    constitute
        IsLawful(a, "6(1)(d)")

point "e"

rule 
    whenever
        DataProcessing(pr, c, a, d)
        PersonalData(d, ds)
        (EXISTS pi. IsNecessaryForPublicInterest(a, pi)) OR IsPerformanceOfPublicAuthorityTask(a) AND IsPublicAuthority(c)
    constitute
        IsLawful(a, "6(1)(e)")

point "f"

rule "legitimate_interest"
    whenever
        DataProcessing(pr, c, a, d)
        IsNecessaryForLegitimateInterest(a, e, i)
    constitute
        IsLawful(a, "6(1)(f)")

rule
    whenever
        PersonalData(d, ds)
        IsOverriddenByDataSubjectInterests(e, i, ds)
    except
        rule "legitimate_interest"

paragraph[1] "2"

rule
    whenever
        IsPublicAuthority(c)
        IsPerformanceOfPublicAuthorityTask(a)
    except
        paragraph[1] "1" point "f"

note "Skipped: OPENING CLAUSE in (2)-(3)."
note "Paragraph (4) provides condition to assess the compatibility of purposes. This is integrated in the docstring of CompatibleWithPurpose."

article "7" "Conditions for consent"

observable predicate IsAbleToDemonstrateConsent
    """Controller {c} is able to demonstrate that data subject {ds} has given consent for purpose {p}"""
    c : entity
    ds : data_subject
    p : purpose

observable predicate ConsentDeclarationContainsOtherMatters
    """The consent declaration {de} contains matters other than those related to consent."""
    de : declaration

causable observable predicate Contains
    """Written declaration {de} contains subdeclaration {de2}"""
    de : declaration
    de2 : declaration

causable observable predicate IsConsentRequest
    """Declaration {de} is a consent request"""
    de : declaration

causable observable predicate IsDistinguishableFromOtherMatters
    """Subdeclaration {de} is distinguishable from other matters within declaration {de2}"""
    de : declaration
    de2 : declaration

causable observable predicate IsIntelligible
    """Declaration {de} is intelligible"""
    de : declaration

causable observable predicate IsEasilyAccessible
    """Declaration {de} is easily accessible"""
    de : declaration

causable observable predicate IsClearAndPlainLanguage
    """Declaration {de} is written in clear and plain language"""
    de : declaration

causable observable predicate Inform
    """Controller {c} informs data subject {ds} about declaration {de}"""
    c : entity
    ds : data_subject
    de : declaration

paragraph "1"

rule
    whenever
        DataProcessing(pr, c, a, d)
        PersonalData(d, ds)
        ONCE GiveConsent(ds, p, c)
    oblige
        IsAbleToDemonstrateConsent(c, ds, p)
    transparently enforceable suppressing condition[0]

paragraph "2"

point "1"

rule
    whenever
        GiveConsent(ds, p, c)
        Inform(c, ds, de)       
        ConsentDeclarationContainsOtherMatters(de)
    oblige
        EXISTS cr. Contains(de, cr) AND IsConsentRequest(cr) AND IsDistinguishableFromOtherMatters(cr, de) AND IsIntelligible(cr) AND IsEasilyAccessible(cr) AND IsClearAndPlainLanguage(cr)
    transparently enforceable causing effects

point "2"

note "Skipped: Any part of such a declaration which constitutes an infringement of this Regulation shall not be binding (NO VIOLATIONS)."

paragraph "3"

point "1"

observable predicate WithdrawConsent
    """Data subject {ds} withdraws their consent previously given to controller {c} for purpose {p}. 
       Per Art. 7(3)(1), can be performed at any time. 
       Per Art. 7(3)(4), shall be as easy to withdraw as to give consent."""
    ds : data_subject
    p : purpose
    c : entity

point "2"

rule
    whenever
        DataProcessing(pr, c, a, d)
        PersonalData(d, ds)
        (NOT WithdrawConsent(ds, p, c)) SINCE GiveConsent(ds, p, c)
    scope
        article "6" paragraph "1" paragraph[1] "1" point "a"

point "3"

causable observable predicate IsRightToWithdrawConsent
    """Declaration {de} declares the existence of the right to withdraw consent at any time, without 
       affecting the lawfulness of processing based on consent before its withdrawal"""
    de : declaration

rule
    whenever
        GiveConsent(ds, p, c)
    oblige
        ONCE (EXISTS de, re. Inform(c, ds, de) AND Contains(de, re) AND IsRightToWithdrawConsent(re))
    transparently enforceable causing effects

point "4"

note "Skipped: integrated in the docstring of GiveConsent."

article "8" "Conditions applicable to child's consent in relation to information society services"

observable predicate IsOfferOfInformationSocietyServices
    """The activity {a} is performed in relation to the offer of information society services"""
    a : activity

observable predicate IsChild
    """The data subject {ds} is a child below the age of 16 years"""
    ds : data_subject

observable event HoldParentalResponsibility
    """The data subject {ds} holds parental responsibility over {ds'}"""
    ds : data_subject
    ds' : data_subject

observable event AuthorizeConsent
    """The data subject {ds} authorizes data subject {ds'} to give consent on their behalf to processor {c} for purpose {p}"""
    ds : data_subject
    ds' : data_subject
    p : purpose
    c : entity

paragraph "1"

paragraph[1] "1"

rule "minor_consent_exception"
    whenever
        IsOfferOfInformationSocietyServices(a)
        IsChild(ds)
    except
        article "6" paragraph "1" paragraph[1] "1" point "a"

rule "minor_consent_valid"
    whenever
        DataProcessing(pr, c, a, d)
        PersonalData(d, ds)
        ONCE (EXISTS ds2. HoldParentalResponsibility(ds2, ds) AND GiveConsent(ds2, p, c) OR (GiveConsent(ds, p, c) AND ONCE (HoldParentalResponsibility(ds2, ds) AND AuthorizeConsent(ds2, ds, p, c))))
        IsOfferOfInformationSocietyServices(a)
        IsChild(ds)
    constitute
        IsLawful(a, "8(1)")

note "Skipped: OPENING CLAUSE in subparagraph (2)."

paragraph "2"

observable event CheckNotChild
    """The controller {c} makes reasonable efforts to verify that data subject {ds} is not a child"""
    c : entity
    ds : data_subject

rule
    whenever
        GiveConsent(ds, p, c)
        NOT ONCE (EXISTS ds2. HoldParentalResponsibility(ds2, ds) AND AuthorizeConsent(ds2, ds, p, c))
    oblige
        CheckNotChild(c, ds)
    transparently enforceable suppressing condition[0]

note "Skipped: OPENING CLAUSE in (3)."

article "9" "Processing of special categories of personal data"

observable predicate IsSpecialData
    """The data {d} reveals information of special data category {sp}.
       Special data categories include personal data revealing racial or ethnic origin, political opinions, religious or philosophical beliefs,
       trade union membership, the processing of genetic data, biometric data for the purpose of uniquely identifying a natural person,
       data concerning health or data concerning a natural person's sex life or sexual orientation"""
    d : data
    sp : special_data_category

suppressable event GiveSpecialConsent
    """Data subject {ds} gives explicit consent to processor {c} to use data of special category {sp} for purpose {p}.
       Per Art. 4(11), consent means 'any freely given, specific, informed and unambiguous indication of the data subject's wishes by which they, 
       by a statement or by a clear affirmative action, signifies agreement to the processing of personal data relating to them.'
       Per Art. 9(2)(a), 'the data subject has given explicit consent to the processing of those personal data for one or more specified purposes,
       except where Union or Member State law provide that the prohibition referred to in paragraph 1 may not be lifted by the data subject.'"""
    ds : data_subject
    p : purpose
    c : entity
    sp : special_data_category

observable event WithdrawSpecialConsent
    """Data subject {ds} revokes  consent to processor {c} to use data of special category {sp} for purpose {p}."""
    ds : data_subject
    p : purpose
    c : entity
    sp : special_data_category
													
observable predicate IsNecessaryForEmploymentLaw
    """Processing activity {a} is necessary for the purposes of carrying out the obligations and exercising specific rights of the
       controller or of the data subject in the field of employment and social security and social protection law in so far as
       it is authorised by Union or Member State law or a collective agreement pursuant to Member State law providing for
       appropriate safeguards for the fundamental rights and the interests of the data subject."""
    a : activity

observable event ImplementFundamentalRightsSafeguards
    """Processing activity {a} provides for appropriate safeguards to protect the fundamental rights and interests of data subject {ds}."""
    a : activity
    ds : data_subject

observable predicate IsUnableToConsent
    """Data subject {ds} is physically or legally unable to give consent"""
    ds : data_subject

observable predicate IsLegitimateActivity
    """Processing activity {a} is legitimate in relation to controller {c}"""
    a : activity
    c : entity

observable predicate IsNonProfit
    """Controller {c} is a non-profit entity such as a foundation, association or any other not-for-profit body"""
    c : entity  

observable predicate HasPoliticalAim
    """Controller {c} has a political aim"""
    c : entity

observable predicate HasPhilosophicalAim
    """Controller {c} has a philosophical aim"""
    c : entity

observable predicate HasReligiousAim
    """Controller {c} has a religious aim"""
    c : entity

observable predicate HasTradeUnionAim
    """Controller {c} has a trade union aim"""
    c : entity

observable predicate IsMember
    """Data subject {ds} is a member of controller {c}"""
    ds : data_subject
    c : entity

observable predicate HasRegularContact
    """Data subject {ds} has regular contact with controller {c} in connection with the purposes of controller {c}'s legitimate activities"""  
    ds : data_subject
    c : entity

observable predicate IsOutsideDisclosure
    """Processing activity {a} involves disclosure of data {d} to outsiders of controller {c}"""
    a : activity
    c : entity
    d : data

observable predicate MakePublic
    """Data subject {ds} makes data {d} public"""
    ds : data_subject
    d : data

observable predicate IsNecessaryForJudicialClaims
    """Processing activity {a} is necessary for the establishment, exercise or defence of legal claims
       or whenever courts are acting in their judicial capacity"""
    a : activity

observable predicate IsNecessaryForSubstantialPublicInterest
    """Processing activity {a} is necessary for reasons of substantial public interest, on the basis of Union or Member State law which shall 
       be proportionate to the aim pursued, respect the essence of the right to data protection and provide for
       suitable and specific measures to safeguard the fundamental rights and the interests of the data subject"""
    a : activity

observable predicate IsNecessaryForSpecialMedicalReasons
    """Processing activity {a} is necessary for the purposes of preventive or occupational medicine, 
       for the assessment of the working capacity of the employee, medical diagnosis, the provision
       of health or social care or treatment or the management of health or social care systems and 
       services on the basis of Union or Member State law or pursuant to contract with a health professional"""
    a : activity

observable predicate IsHealthRelated
    """Public interest {pi} is related to the area of public health, such as protecting against 
       serious cross-border threats to health or ensuring high standards of quality and safety of 
       health care and of medicinal products or medical devicess, on the basis of Union or Member 
       State law which provides for suitable and specific measures to safeguard the rights and
       freedoms of the data subject, in particular professional secrecy"""
    pi : public_interest

observable predicate IsNecessaryForArchivalPurposes
    """Processing activity {a} is necessary for archiving purposes in the public interest, 
       scientific or historical research purposes or statistical purposes in accordance with 
       Article 89(1) based on Union or Member State law which shall be proportionate to the aim
       pursued, respect the essence of the right to data protection and provide for suitable and 
       specific measures to safeguard the fundamental rights and the interests of the data subject"""
    a : activity

observable predicate IsSubjectToProfessionalSecrecy
    """Entity {e} is subject to the obligation of professional secrecy under Union or Member
       State law or rules established by national competent bodies"""
    e : entity

paragraph "1"

rule
    whenever
        IsSpecialData(d, sp)
        PersonalData(d, ds)
        DataProcessing(pr, c, a, d)
    oblige
        false
    transparently enforceable suppressing condition[2]

paragraph "2"

point "a"

rule "special_data_consent_exception"
    whenever
        IsSpecialData(d, sp)
        PersonalData(d, ds)
        DataProcessing(pr, c, a, d)
        NOT (EXISTS p. HasPurpose(a, p) AND NOT ((NOT WithdrawSpecialConsent(ds, p, c, sp)) SINCE GiveSpecialConsent(ds, p, c, sp)))
    except
        paragraph "1"

rule "special_data_consent_valid"
    whenever
        IsSpecialData(d, sp)
        PersonalData(d, ds)
        DataProcessing(pr, c, a, d)
        NOT (EXISTS p. HasPurpose(a, p) AND NOT ((NOT WithdrawSpecialConsent(ds, p, c, sp)) SINCE GiveSpecialConsent(ds, p, c, sp)))
    constitute
        IsLawful(a, "9(2)(a)")

note "Skipped: except where Union or Member State law provide that the prohibition referred to in paragraph 1 may not be lifted by the data subject (OPENING CLAUSE)"

point "b"

rule
    whenever
        IsNecessaryForEmploymentLaw(a)
    except
        paragraph "1"
    
point "c"

rule
    whenever
        IsNecessaryForVitalInterests(a, ds', v)
        IsUnableToConsent(ds)
    except
        paragraph "1"

point "d"

rule
    whenever
        ImplementFundamentalRightsSafeguards(a, ds)
        IsLegitimateActivity(a, c)
        IsNonProfit(c)
        HasPoliticalAim(c) OR HasPhilosophicalAim(c) OR HasReligiousAim(c) OR HasTradeUnionAim(c)
        (ONCE IsMember(ds, c)) OR HasRegularContact(ds, c)
        NOT (EXISTS d. IsOutsideDisclosure(a, c, d))
    except
        paragraph "1"

point "e"

rule
    whenever
        ONCE MakePublic(ds, d)
    except
        paragraph "1"

point "f"

rule
    whenever
        IsNecessaryForJudicialClaims(a)
    except
        paragraph "1"

point "g"

rule "substantial_public_interest_exception"
    whenever
        IsNecessaryForSubstantialPublicInterest(a)
    except
        paragraph "1"

rule "substantial_public_interest_valid"
    whenever
        IsNecessaryForSubstantialPublicInterest(a)
    constitute
        IsLawful(a, "9(2)(g)")

point "h"

rule
    whenever
        IsNecessaryForSpecialMedicalReasons(a)
    except
        paragraph "1"

point "i"

rule
    whenever
        IsNecessaryForPublicInterest(a, pi)
        IsHealthRelated(pi)
    except
        paragraph "1"

point "j"

rule
    whenever
        IsNecessaryForArchivalPurposes(a)
    except
        paragraph "1"

paragraph "3"

rule
    whenever
        IsSubjectToProfessionalSecrecy(c)
        IsSubjectToProfessionalSecrecy(pr)
    scope
        paragraph "2" point "h"

note "Skipped: OPENING CLAUSE in (4)."

article "10" "Processing of personal data relating to criminal convictions and offences"

observable predicate RelatesToCriminalConvictionsOrOffences
    """Data {d} relates to criminal convictions and offences or related security measures"""
    d : data

observable predicate IsSpecialAuthorizedCriminalProcessing
    """Activity {a} is authorised by Union or Member State law providing for appropriate safeguards
       for the rights and freedoms of data subject to process data relating to criminal convictions
       and offences"""
    a : activity

observable predicate ConcernsCriminalRegister
    """Activity {a} concerns a criminal register"""
    a : activity

rule "criminal_data_prohibition_general"
    whenever
       DataProcessing(pr, c, a, d)
       RelatesToCriminalConvictionsOrOffences(d) IMPLIES (IsPublicAuthority(c) OR IsSpecialAuthorizedCriminalProcessing(a))
    scope
       article "6" paragraph "1"
    
rule "criminal_data_prohibition_register"
    whenever
        DataProcessing(pr, c, a, d)
        ConcernsCriminalRegister(a) IMPLIES IsPublicAuthority(c)
    scope
        article "6" paragraph "1"

article "12" "Transparent information, communication and modalities for the exercise of the rights of the data subject"

observable predicate IsConcise
    """Declaration {de} is concise"""
    de : declaration

observable predicate IsTransparentDeclaration
    """Declaration {de} is transparent"""
    de : declaration

observable event Request
    """Data subject {ds} performs request {rq} to controller {c}"""
    ds : data_subject
    rq : request
    c : entity

causable observable event RequestResponse
    """Controller {c} responds to data subject {ds}'s request {rq} with response {rs}"""
    ds : data_subject
    rq : request
    rs : declaration

observable predicate UndueDelay
    """Request {rq} is subject to undue delay"""
    rq : request

suppressable event RequestExtension
    """Controller {c} requests an extension for responding to request {rq}"""
    c : entity
    rq : request

observable predicate IsReasonForRequestExtension
    """Declaration {re} contains the reason for the request extension for request {rq}"""
    re : declaration
    rq : request

observable predicate IsElectronicRequest
    """Request {rq} is made by electronic means"""
    rq : request

observable predicate RequestsNonElectronic
    """Request {rq} requests a non-electronic response"""
    rq : request

observable predicate IsImpossibleElectronic
    """It is impossible to provide response to request {rq} by electronic means"""
    rq : request

observable predicate IsElectronicDeclaration
    """Declaration {de} is provided by electronic means"""
    de : declaration

suppressable event RefuseRequest
    """Controller {c} refuses to respond to request {rq} of user {ds}, e.g., because it is manifestly unfounded 
       or excessive (Article 12(5)(b))"""
    c : entity
    rq : request
    ds : data_subject

causable observable predicate IsReasonForRequestRefusal
    """Declaration {re} contains the reason for the refusal of request {rq}"""
    re : declaration
    rq : request

causable observable predicate IsComplaintStatement
    """Declaration {re} contains a statement informing the data subject of their right to lodge 
       a complaint with a supervisory authority regarding request {rq}"""
    re : declaration
    rq : request

suppressable event ChargeForRequest
    """A fee {fee} is charged for responding to request {rq}"""
    rq : request
    fee : money EUR

observable predicate IsUnfoundedOrExcessive
    """Request {rq} is unfounded or excessive, in particular because of its repetitive character"""
    rq : request

observable predicate IsReasonableFee
    """Fee {fee} is reasonable"""
    fee : money EUR

paragraph "1"

rule
    whenever
        Inform(c, ds, de)
    oblige
        IsConcise(de)
        IsTransparentDeclaration(de)
        IsIntelligible(de)
        IsEasilyAccessible(de)
        IsClearAndPlainLanguage(de)

note "Skipped: When requested by the data subject, the information may be provided orally, provided that... (MODEL)"

paragraph "2"

note "Skipped: facilitate the exercise of the rights, integrated in the MODEL's design"

paragraph "3"

observable predicate IsExtensionNecessary
    """Request extension for request {rq} is necessary due to the complexity of the request or 
       the number of requests"""
    rq : request

rule "request_response_standard"
    whenever
        Request(ds, rq, c)
    oblige
        (NOT UndueDelay(rq)) UNTIL[0, 1M] (RequestExtension(c, rq) OR (EXISTS rs. RequestResponse(ds, rq, rs)))
    transparently enforceable causing effects

rule "request_response_extension_condition"
    whenever
        RequestExtension(c, rq)
    oblige
        IsExtensionNecessary(rq)
    transparently enforceable suppressing conditions

rule "request_response_extended"
    whenever
        ONCE Request(ds, rq, c)
        RequestExtension(c, rq)
    oblige
        (NOT UndueDelay(rq)) UNTIL[0, 2M] (EXISTS rs. RequestResponse(ds, rq, rs))
    transparently enforceable causing effects

rule "request_response_extension_inform"
    whenever
        ONCE Request(ds, rq, c)
        RequestExtension(c, rq)
    oblige
        ONCE[1M, *] (EXISTS de. Request(ds, rq, c) UNTIL[0, 1M] (Inform(c, ds, de) AND (EXISTS re. Contains(de, re) AND IsReasonForRequestExtension(re, rq))))
    enforceable suppressing conditions

rule "request_response_electronic"
    whenever
        ONCE (Request(ds, rq, c) AND IsElectronicRequest(rq) AND NOT RequestsNonElectronic(rq))
        RequestResponse(ds, rq, rs)
        NOT IsImpossibleElectronic(rq)
    oblige
        IsElectronicDeclaration(rs)

paragraph "4"

note "The first rule is implicit in the formulation of (4)"

rule "refuse_request"
    whenever
        ONCE Request(ds, rq, c)
        RefuseRequest(c, rq, ds)
    except
        paragraph "3" rule "request_response_standard"
        paragraph "3" rule "request_response_extended"

rule "refusal_information"
    whenever
        ONCE Request(ds, rq, c)
        RefuseRequest(c, rq, ds)
    oblige
        ONCE[1M, *] (EXISTS de. Request(ds, rq, c) UNTIL[0, 1M] (Inform(c, ds, de) AND (EXISTS re. Contains(de, re) AND IsReasonForRequestRefusal(re, rq)) AND (EXISTS re. Contains(de, re) AND IsComplaintStatement(re, rq))))
    enforceable suppressing conditions

paragraph "5"

rule "free_of_charge"
    whenever
        ONCE Request(ds, rq, c)
    oblige
        NOT ChargeForRequest(rq, fee)    
    transparently enforceable causing effects

rule "unfounded_exception"
    whenever
        IsUnfoundedOrExcessive(rq)
    except
        rule "free_of_charge"

rule "charge_reasonable_fee"
    whenever
        ChargeForRequest(rq, fee)
    oblige
        IsReasonableFee(fee)
    transparently enforceable suppressing conditions

note "Skipped: (b) and second subparagraph integrated in the docstring of RefuseRequest."
note "Skipped: (6) as the MODEL assumes that ds is identified."
note "Skipped: The information to be provided to data subjects... may [use] standardised icons (PERMISSION)"
note "Skipped: OPENING CLAUSE in (8)."

article "13" "Information to be provided where personal data are collected from the data subject"

paragraph "1"

point "a"

observable predicate IsControllerRepresentative
    """Entity {c'} is the controller representative of controller {c}"""
    c : entity
    c' : entity

causable observable predicate IsIdentityOfControllerOrRepresentative
    """Declaration {de} contains the identity of the controller representative {c}"""
    de : declaration
    c : entity

rule
    whenever
        DataProcessing(pr, c, a, d)
        IsControllerRepresentative(c, c')
        IsCollection(a, ds)
        PersonalData(d, ds)
    oblige
        ONCE (EXISTS de, re. Inform(c, ds, de) AND Contains(de, re) AND IsIdentityOfControllerOrRepresentative(re, c'))
    transparently enforceable causing effects

point "b"

observable predicate IsDataProtectionOfficer
    """Entity {c'} is the data protection officer of controller {c}"""
    c : entity
    c' : entity

causable observable predicate IsContactDetailsOfDataProtectionOfficer
    """Declaration {de} contains the contact details of the data protection officer of {c}"""
    de : declaration
    c : entity

rule
    whenever
        DataProcessing(pr, c, a, d)
        IsDataProtectionOfficer(c, c')
        IsCollection(a, ds)
        PersonalData(d, ds)
    oblige
        ONCE (EXISTS de, re. Inform(c, ds, de) AND Contains(de, re) AND IsContactDetailsOfDataProtectionOfficer(re, c'))
    transparently enforceable causing effects

point "c"

causable observable predicate IsPurposeOfProcessing
    """Declaration {de} declares the purpose of processing {p}"""
    de : declaration
    p : purpose

causable observable predicate IsLegalBasisOfProcessing
    """Declaration {de} declares the legal basis {b}"""
    de : declaration
    b : legal_basis

rule
    whenever
        DataProcessing(pr, c, a, d)
        IsCollection(a, ds)
        HasPurpose(a, p)
        PersonalData(d, ds)
        IsLawful(a, b)
    oblige
        ONCE (EXISTS de, re. Inform(c, ds, de) AND Contains(de, re) AND IsPurposeOfProcessing(re, p))
        ONCE (EXISTS de, re. Inform(c, ds, de) AND Contains(de, re) AND IsLegalBasisOfProcessing(re, b))
    transparently enforceable causing effects

point "d"

causable observable predicate IsLegitimateInterest
    """Declaration {de} declares the legitimate interest {i} of entity {e}"""
    de : declaration
    e : entity
    i : interest

rule
    whenever
        DataProcessing(pr, c, a, d)
        IsCollection(a, ds)
        PersonalData(d, ds)
        IsLawful(a, "6(1)(f)")
        IsNecessaryForLegitimateInterest(a, e, i)
    oblige
        ONCE (EXISTS de, re. Inform(c, ds, de) AND Contains(de, re) AND IsLegitimateInterest(re, e, i))
    transparently enforceable causing effects

point "e"

observable predicate HasIntendedRecipient
    """The {d} is collected with the intent to share it with recipient {e}"""
    d : data
    e : entity

causable observable predicate IsRecipient
    """Declaration {de} declares intended recipient {e}"""
    de : declaration
    e : entity

observable predicate HasIntendedRecipientCategory
    """The {d} is collected with the intent to share it with recipient category {e}"""
    d : data
    e : entity

causable observable predicate IsRecipientCategory
    """Declaration {de} declares intended recipient category {e}"""
    de : declaration
    e : entity

rule "inform_recipient"
    whenever
        DataProcessing(pr, c, a, d)
        IsCollection(a, ds)
        HasIntendedRecipient(d, e)
        PersonalData(d, ds)
    oblige
        ONCE (EXISTS de, re. Inform(c, ds, de) AND Contains(de, re) AND IsRecipient(re, e))
    transparently enforceable causing effects

rule "inform_recipient_category"
    whenever
        DataProcessing(pr, c, a, d)
        IsCollection(a, ds)
        HasIntendedRecipientCategory(d, rc)
        PersonalData(d, ds)
    oblige
        ONCE (EXISTS de, re. Inform(c, ds, de) AND Contains(de, re) AND IsRecipientCategory(re, rc))
    transparently enforceable causing effects

point "f"

observable predicate HasIntendedTransfer
    """The {d} is collected with the intent to transfer it to country or international organisation {co}"""
    d : data
    co : country_or_international_organisation

causable observable predicate IsTransfer
    """Declaration {de} declares intended transfer to country or international organisation {co}"""
    de : declaration
    co : country_or_international_organisation

causable observable predicate IsTransferBasis
    """Declaration {de} declares the existence or absence of an adequacy decision by the Commission
       with respect to the country or international organisation {co} to which the personal data are
       intended to be transferred, or in the case of transfers referred to in Article 46 or 47, or 
       the second subparagraph of Article 49(1), reference to the appropriate or suitable safeguards 
       and the means by which to obtain a copy of them or where they have been made available."""
    de : declaration
    co : country_or_international_organisation

rule
    whenever
        DataProcessing(pr, c, a, d)
        IsCollection(a, ds)
        HasIntendedTransfer(d, co)
        PersonalData(d, ds)
    oblige
        ONCE (EXISTS de, re. Inform(c, ds, de) AND Contains(de, re) AND IsTransfer(re, co))
        ONCE (EXISTS de, re. Inform(c, ds, de) AND Contains(de, re) AND IsTransferBasis(re, co))
    transparently enforceable causing effects

paragraph "2"

point "a"

observable predicate HasStoragePeriod
    """Data {d} has a specified storage period {t}"""
    d : data
    t : span

observable predicate HasStorageCriteria
    """Data {d} has specified storage criteria {c}"""
    d : data
    c : criteria

observable event IsRespected
    """Storage criteria {c} of data {d} is respected"""
    d : data
    c : criteria

causable observable predicate IsStoragePeriod
    """Declaration {de} declares the storage period {t}"""
    de : declaration
    t : span

causable observable predicate IsStorageCriteria
    """Declaration {de} declares the storage criteria {c}"""
    de : declaration
    c : criteria

note "The first rule is implicit in the formulation of (2)(a)"

rule "has_storage_period_or_criteria"
    whenever
        DataProcessing(pr, c, a, d)
        IsCollection(a, ds)
        PersonalData(d, ds)
    oblige
        (EXISTS t. HasStoragePeriod(d, t)) OR (EXISTS cr. HasStorageCriteria(d, cr))
    transparently enforceable suppressing condition[0]

function add_time_span(
    t : time
    s : span
) -> time

rule "respect_storage_period"
    whenever
        ONCE (DataProcessing(pr, c, a, d) AND IsCollection(a, ds) AND PersonalData(d, ds)AND HasStoragePeriod(d, t) AND TP(t'))
        TP(t'')
        t'' >= add_time_span(t', t)
        DataReview(c, d)	    
    constitute
        IsObligedToDelete(c, d)

rule "respect_storage_criteria"
    whenever
        ONCE (DataProcessing(pr, c, a, d) AND IsCollection(a, ds) AND PersonalData(d, ds) AND HasStorageCriteria(d, cr))
        NOT IsRespected(d, cr)
        DataReview(c, d)
    constitute
        IsObligedToDelete(c, d)

rule "inform_storage_period"
    whenever
        DataProcessing(pr, c, a, d)
        IsCollection(a, ds)
        PersonalData(d, ds)
        HasStoragePeriod(d, t)		       
    oblige
        ONCE (EXISTS de, re. Inform(c, ds, de) AND Contains(de, re) AND IsStoragePeriod(re, t))
    transparently enforceable causing effects

rule "inform_storage_criteria"
    whenever
        DataProcessing(pr, c, a, d)
        IsCollection(a, ds)
        PersonalData(d, ds)
        HasStorageCriteria(d, cr)			  
    oblige
        ONCE (EXISTS de, re. Inform(c, ds, de) AND Contains(de, re) AND IsStorageCriteria(re, cr))
    transparently enforceable causing effects

point "b"

causable observable predicate IsRights
    """Declaration {de} declares the existence of the right to request from the controller access 
       to and rectification or erasure of personal data or restriction of processing concerning 
       the data subject or to object to processing as well as the right to data portability.
       The right to object (Article 21(1-2)) referred shall be explicitly brought to the attention 
       of the data subject and shall be presented clearly and separately from any other information."""
    de : declaration

rule
    whenever
        DataProcessing(pr, c, a, d)
        IsCollection(a, ds)
        PersonalData(d, ds)
    oblige
        ONCE (EXISTS de, re. Inform(c, ds, de) AND Contains(de, re) AND IsRights(re))
    transparently enforceable causing effects

point "c"

rule
    whenever
        DataProcessing(pr, c, a, d)
        IsCollection(a, ds)
        PersonalData(d, ds)
        IsLawful(a, "6(1)(a)") OR IsLawful(a, "9(2)(a)")
    oblige
        ONCE (EXISTS de, re. Inform(c, ds, de) AND Contains(de, re) AND IsRightToWithdrawConsent(re))
    transparently enforceable causing effects

point "d"

causable observable predicate IsRightToLodgeComplaint
    """Declaration {de} declares the existence of the right to lodge a complaint with a supervisory authority"""
    de : declaration

rule
    whenever
        DataProcessing(pr, c, a, d)
        IsCollection(a, ds)
        PersonalData(d, ds)
    oblige
        ONCE (EXISTS de, re. Inform(c, ds, de) AND Contains(de, re) AND IsRightToLodgeComplaint(re))
    transparently enforceable causing effects

point "e"

observable predicate HasStatutoryContractualRequirement
    """The provision of data {d} is a statutory or contractual requirement {r}, or a requirement necessary to enter
       into a contract"""
    d : data
    r : requirement

causable observable predicate IsStatutoryContractualRequirement
    """Declaration {de} declares the existence of a statutory or contractual requirement {r}, or a requirement 
       necessary to enter into a contract, of data subject {ds} with respect to data {d}, as well as the possible 
       consequences of failure to provide such data"""
    de : declaration
    ds : data_subject
    d : data
    r : requirement

rule
    whenever
        DataProcessing(pr, c, a, d)
        IsCollection(a, ds)
        PersonalData(d, ds)
        HasStatutoryContractualRequirement(d, r)
    oblige
        ONCE (EXISTS de, re, r. Inform(c, ds, de) AND Contains(de, re) AND IsStatutoryContractualRequirement(re, ds, d, r))
    transparently enforceable causing effects

point "f"

observable predicate HasIntendedAutomatedDecision
    """The {d} is collected with the intent to use it for automated decision-making, including profiling,
       which produces legal effects concerning the data subject or similarly significantly affects the data subject with
       meaningful information about the logic involved, as well as the significance and the envisaged consequences
       of such processing for the data subject, declared in {de}"""
    d : data    
    de : declaration

observable predicate AutomatedDecision
    """Activity {a} uses data {d} for automated decision-making, including profiling, with respect to data subject {ds},
       with meaningful information about the logic involved, as well as the significance and the envisaged consequences
       of such processing for the data subject, declared in {de}"""
    a : activity
    d : data
    ds : data_subject
    de : declaration

causable observable predicate IsAutomatedDecision
    """Declaration {de} declares that data is used for automated decision-making, including profiling, with meaningful
       information about the logic involved, as well as the significance and the envisaged consequences
       of such processing for the data subject"""
    de : declaration

note "The first rule is implicit in the formulation of (2)(f)"

rule "prior_declaration_of_automated_decision"
    whenever
        DataProcessing(pr, c, a, d)
        PersonalData(d, ds)
        AutomatedDecision(a, d, ds, de)
    oblige
        ONCE HasIntendedAutomatedDecision(d, de)
    transparently enforceable suppressing condition[0]

rule "inform_automated_decision"
    whenever
        DataProcessing(pr, c, a, d)
        IsCollection(a, ds)
        PersonalData(d, ds)
        HasIntendedAutomatedDecision(d, de)
    oblige
        ONCE (EXISTS de, re. Inform(c, ds, de) AND Contains(de, re) AND IsAutomatedDecision(re))
    transparently enforceable causing effects

paragraph "3"

causable observable predicate IsNewPurpose
    """Declaration {re} contains information about the new purpose {p} of processing and with any relevant 
       further information as referred to in paragraph 13(2)"""
    re : declaration
    p : purpose

rule
    whenever
        DataProcessing(pr, c, a, d)
        PersonalData(d, ds)
        HasPurpose(a, p)
        ONCE (EXISTS co, pr'. DataProcessing(pr', c, co, d) AND IsCollection(co, ds))
        NOT ONCE (EXISTS co, pr'. DataProcessing(pr', c, co, d) AND IsCollection(co, ds) AND HasPurpose(co, p))
    oblige
        ONCE (EXISTS de, re. Inform(c, ds, de) AND Contains(de, re) AND IsNewPurpose(re, p))
    transparently enforceable causing effects

paragraph "4"

note "Skipped: Integrated in the rules above as 'ONCE Inform'."

article "14" "Information to be provided where personal data have not been obtained from the data subject"

observable predicate IsReception
    """Activity {a} consists in reception of data from sender entity {e}"""
    a : activity
    e : entity

internal predicate CanDelayInform
    """Controller {c} can delay informing data subject {ds} about the collection activity {a}"""
    c : entity
    ds : data_subject
    a : activity

note "Define IsIndirectCollection as a shortcut. Note: IsIndirectCollection implies PersonalData"

internal predicate IsIndirectCollection
    a : activity
    d : data
    ds : data_subject

rule "indirect_collection_def_1"
    whenever
        DataProcessing(pr, c, a, d)
        PersonalData(d, ds)
        IsCollection(a, ds')
        ds <> ds'
    constitute
        IsIndirectCollection(a, d, ds)

rule "indirect_collection_def_2"
    whenever
        DataProcessing(pr, c, a, d)
        PersonalData(d, ds)
        IsReception(a, e)
    constitute
        IsIndirectCollection(a, d, ds)

paragraph "1"

point "a"

rule
    whenever
        DataProcessing(pr, c, a, d)
        IsIndirectCollection(a, d, ds)
    oblige
        CanDelayInform(c, ds, a) UNTIL[0, 1M] (ONCE (EXISTS de, re. Inform(c, ds, de) AND Contains(de, re) AND IsIdentityOfControllerOrRepresentative(re, c)))
    transparently enforceable causing effects

point "b"

rule
    whenever
        DataProcessing(pr, c, a, d)
        IsIndirectCollection(a, d, ds)
    oblige
        CanDelayInform(c, ds, a) UNTIL[0, 1M] (ONCE (EXISTS de, re. Inform(c, ds, de) AND Contains(de, re) AND IsContactDetailsOfDataProtectionOfficer(re, c)))
    transparently enforceable causing effects

point "c"

rule
    whenever
        DataProcessing(pr, c, a, d)
        IsIndirectCollection(a, d, ds)
        HasPurpose(a, p)
        IsLawful(a, b)
    oblige
        CanDelayInform(c, ds, a) UNTIL[0, 1M] (ONCE (EXISTS de, re. Inform(c, ds, de) AND Contains(de, re) AND IsPurposeOfProcessing(re, p)))
        CanDelayInform(c, ds, a) UNTIL[0, 1M] (ONCE (EXISTS de, re. Inform(c, ds, de) AND Contains(de, re) AND IsLegalBasisOfProcessing(re, b)))
    transparently enforceable causing effects

point "d"

observable predicate HasCategory
    """Data {d} belongs to category {cat}"""
    d : data
    cat : special_data_category

causable observable predicate IsCategory
    """Declaration {de} declares that the data belongs to category {cat}"""
    de : declaration
    cat : special_data_category

rule
    whenever
        DataProcessing(pr, c, a, d)
        IsIndirectCollection(a, d, ds)
        HasCategory(d, cat)
    oblige
        CanDelayInform(c, ds, a) UNTIL[0, 1M] (ONCE (EXISTS de, re. Inform(c, ds, de) AND Contains(de, re) AND IsCategory(re, cat)))
    transparently enforceable causing effects

point "e"

rule "inform_recipient"
    whenever
        DataProcessing(pr, c, a, d)
        IsIndirectCollection(a, d, ds)
        HasIntendedRecipient(d, e)
    oblige
        CanDelayInform(c, ds, a) UNTIL[0, 1M] (ONCE (EXISTS de, re. Inform(c, ds, de) AND Contains(de, re) AND IsRecipient(re, e)))
    transparently enforceable causing effects

rule "inform_recipient_category"
    whenever
        DataProcessing(pr, c, a, d)
        IsIndirectCollection(a, d, ds)
        HasIntendedRecipientCategory(d, rc)
    oblige
        CanDelayInform(c, ds, a) UNTIL[0, 1M] (ONCE (EXISTS de, re. Inform(c, ds, de) AND Contains(de, re) AND IsRecipientCategory(re, rc)))
    transparently enforceable causing effects

point "f"

rule
    whenever
        DataProcessing(pr, c, a, d)
        IsIndirectCollection(a, d, ds)
        HasIntendedTransfer(d, co)
    oblige
        CanDelayInform(c, ds, a) UNTIL[0, 1M] (ONCE (EXISTS de, re. Inform(c, ds, de) AND Contains(de, re) AND IsTransfer(re, co)))
        CanDelayInform(c, ds, a) UNTIL[0, 1M] (ONCE (EXISTS de, re. Inform(c, ds, de) AND Contains(de, re) AND IsTransferBasis(re, co)))
    transparently enforceable causing effects

paragraph "2"

point "a"

note "The first rule is implicit in the formulation of (2)(a)"

rule "has_storage_period_or_criteria"
    whenever
        DataProcessing(pr, c, a, d)
        IsIndirectCollection(a, d, ds)
    oblige
        (EXISTS t. HasStoragePeriod(d, t)) OR (EXISTS cr. HasStorageCriteria(d, cr))
    transparently enforceable suppressing condition[0]

rule "respect_storage_period"
    whenever
        ONCE (DataProcessing(pr, c, a, d) AND IsIndirectCollection(a, d, ds) AND PersonalData(d, ds) AND HasStoragePeriod(d, t) AND TP(t'))
        TP(t'')
        t'' >= add_time_span(t', t)
        DataReview(c, d)	    
    constitute
        IsObligedToDelete(c, d)

rule "respect_storage_criteria"
    whenever
        ONCE (DataProcessing(pr, c, a, d) AND IsIndirectCollection(a, d, ds) AND PersonalData(d, ds) AND HasStorageCriteria(d, cr))
        NOT IsRespected(d, cr)
        DataReview(c, d)
    constitute
        IsObligedToDelete(c, d)
			  
rule "inform_storage_period"
    whenever
        DataProcessing(pr, c, a, d)
        IsIndirectCollection(a, d, ds)
        HasStoragePeriod(d, t)    
    oblige
        CanDelayInform(c, ds, a) UNTIL[0, 1M] (ONCE (EXISTS de, re. Inform(c, ds, de) AND Contains(de, re) AND IsStoragePeriod(re, t)))
    transparently enforceable causing effects

rule "inform_storage_condition"
    whenever
        DataProcessing(pr, c, a, d)
        IsIndirectCollection(a, d, ds)
        HasStorageCriteria(d, cr)    
    oblige
        CanDelayInform(c, ds, a) UNTIL[0, 1M] (ONCE (EXISTS de, re. Inform(c, ds, de) AND Contains(de, re) AND IsStorageCriteria(re, cr)))
    transparently enforceable causing effects

point "b"

rule
    whenever
        DataProcessing(pr, c, a, d)
        IsIndirectCollection(a, d, ds)
        IsNecessaryForLegitimateInterest(a, e, i)
        IsLawful(a, "6(1)(f)")
    oblige
        CanDelayInform(c, ds, a) UNTIL[0, 1M] (ONCE (EXISTS de, re. Inform(c, ds, de) AND Contains(de, re) AND IsLegitimateInterest(re, e, i)))
    transparently enforceable causing effects

point "c"

rule
    whenever
        DataProcessing(pr, c, a, d)
        IsIndirectCollection(a, d, ds)
    oblige
        CanDelayInform(c, ds, a) UNTIL[0, 1M] (ONCE (EXISTS de, re. Inform(c, ds, de) AND Contains(de, re) AND IsRights(re)))
    transparently enforceable causing effects

point "d"

rule
    whenever
        DataProcessing(pr, c, a, d)
        IsIndirectCollection(a, d, ds)
        IsLawful(a, "6(1)(a)") OR IsLawful(a, "9(2)(a)")
    oblige
        CanDelayInform(c, ds, a) UNTIL[0, 1M] (ONCE (EXISTS de, re. Inform(c, ds, de) AND Contains(de, re) AND IsRightToWithdrawConsent(re)))
    transparently enforceable causing effects

point "e"

rule
    whenever
        DataProcessing(pr, c, a, d)
        IsIndirectCollection(a, d, ds)
    oblige
        CanDelayInform(c, ds, a) UNTIL[0, 1M] (ONCE (EXISTS de, re. Inform(c, ds, de) AND Contains(de, re) AND IsRightToLodgeComplaint(re)))
    transparently enforceable causing effects

point "f"

causable observable predicate IsReceptionSource
    """Declaration {re} declares the source {e} from which the personal data originate, and if applicable,
       whether it came from publicly accessible sources"""
    re : declaration
    e : entity

causable observable predicate IsDSSource
    """Declaration {re} declares the data subject {ds'} from which the personal data originate, and if applicable,
       whether it came from publicly accessible sources"""
    re : declaration
    ds' : data_subject

rule "inform_reception_source"
    whenever
        DataProcessing(pr, c, a, d)
        IsIndirectCollection(a, d, ds)
        IsReception(a, e)
    oblige
        CanDelayInform(c, ds, a) UNTIL[0, 1M] (ONCE (EXISTS de, re. Inform(c, ds, de) AND Contains(de, re) AND IsReceptionSource(re, e)))
    transparently enforceable causing effects

rule "inform_dssource"
    whenever
        DataProcessing(pr, c, a, d)
        IsIndirectCollection(a, d, ds')
        IsReception(a, e)
        PersonalData(d, ds)
        ds <> ds'
    oblige
        CanDelayInform(c, ds, a) UNTIL[0, 1M] (ONCE (EXISTS de, re. Inform(c, ds, de) AND Contains(de, re) AND IsDSSource(re, ds')))
    transparently enforceable causing effects

point "g"

rule 
    whenever
        DataProcessing(pr, c, a, d)
        IsIndirectCollection(a, d, ds)
        HasIntendedAutomatedDecision(d, de)
    oblige
        CanDelayInform(c, ds, a) UNTIL[0, 1M] (ONCE (EXISTS de, re. Inform(c, ds, de) AND Contains(de, re) AND IsAutomatedDecision(re)))
    transparently enforceable causing effects

paragraph "3"

observable predicate IsReasonablePeriod
    """The period from time {t} to time {t'} is a reasonable period, having regard to the specific circumstances in which the personal data
       are processed;"""
    t : time
    t' : time

observable event UseForCommunication
    """The data {d} are used for communication with the data subject {ds}"""
    d : data
    ds : data_subject

observable event Disclose
    """The data {d} are disclosed to data subject {ds}"""
    d : data
    ds : data_subject

rule
    whenever
        ONCE (DataProcessing(pr, c, a, d) AND TP(t))
        IsIndirectCollection(a, d, ds)
        TP(t')
        IsReasonablePeriod(t, t')
        NOT UseForCommunication(d, ds)
        NOT (EXISTS ds'. Disclose(d, ds') AND ds <> ds')
    constitute
        CanDelayInform(c, ds, a) 

paragraph "4"

rule
    whenever
        DataProcessing(pr, c, a, d)
        PersonalData(d, ds)
        HasPurpose(a, p)
        ONCE (EXISTS pr', co. DataProcessing(pr', c, co, d) AND IsIndirectCollection(co, d, ds))
        NOT ONCE (EXISTS pr', co. DataProcessing(pr', c, co, d) AND IsIndirectCollection(co, d, ds) AND HasPurpose(co, p))
    oblige
        ONCE (EXISTS de, re. Inform(c, ds, de) AND Contains(de, re) AND IsNewPurpose(re, p))
    transparently enforceable suppressing condition[0]

paragraph "5"

point "a"

note "Skipped: Integrated in the rules above as 'ONCE Inform'."

point "b"

observable predicate DisproportionateEffortToInform
    """It would involve a disproportionate effort for controller {c} to inform data subject {ds} about the collection activity {a},
       in particular for processing for archiving purposes in the public interest, scientific or historical research purposes or 
       statistical purposes, subject to the conditions and safeguards referred to in Article 89(1) or in so far as the obligation referred
       to in paragraph 1 of this Article is likely to render impossible or seriously impair the achievement of the objectives
       of that processing. In such cases the controller shall take appropriate measures to protect the data subject's rights
       and legitimate interests, including making the information publicly available"""
    c : entity
    ds : data_subject
    a : activity

rule
    whenever
        DisproportionateEffortToInform(c, ds, a)
    except
        paragraph "1"
        paragraph "2"
        paragraph "3"   
        paragraph "4"

note "Skipped: OPENING CLAUSE in (c)-(d)."

article "15" "Right of access by the data subject"

paragraph "1"

observable predicate IsAccessRequest
    """Request {rq} is an access request"""
    rq : request

causable observable predicate IsDataProcessingOngoing
    """Declaration {de} states the data subject's data is being processed"""
    de : declaration

causable observable predicate IsDataProcessingNotOngoing
    """Declaration {de} states the data subject's data is not being processed"""
    de : declaration

rule "data_processing_ongoing"
    whenever
        ONCE (Request(ds, rq, c) AND IsAccessRequest(rq))
        RequestResponse(ds, rq, rs)
        EXISTS pr, a, d. (ONCE (DataProcessing(pr, c, a, d) AND PersonalData(d, ds)))
    oblige
        EXISTS de. Contains(rs, de) AND IsDataProcessingOngoing(de)
    transparently enforceable causing effects

rule "data_processing_not_ongoing"
    whenever
        ONCE (Request(ds, rq, c) AND IsAccessRequest(rq))
        RequestResponse(ds, rq, rs)
        NOT (EXISTS pr, a, d. (ONCE (DataProcessing(pr, c, a, d) AND PersonalData(d, ds))))
    oblige
        EXISTS de. Contains(rs, de) AND IsDataProcessingNotOngoing(de) 
    transparently enforceable causing effects

point "a"

rule
    whenever
        ONCE (Request(ds, rq, c) AND IsAccessRequest(rq))
        RequestResponse(ds, rq, rs)
        EXISTS pr, a, d. ONCE (DataProcessing(pr, c, a, d) AND PersonalData(d, ds) AND HasPurpose(a, p))
    oblige
        EXISTS de. Contains(rs, de) AND IsPurposeOfProcessing(de, p)
    transparently enforceable causing effects

point "b"

rule
    whenever
        ONCE (Request(ds, rq, c) AND IsAccessRequest(rq))
        RequestResponse(ds, rq, rs)
        EXISTS pr, a, d. (ONCE DataProcessing(pr, c, a, d) AND PersonalData(d, ds) AND HasCategory(d, cat))
    oblige
        EXISTS de. Contains(rs, de) AND IsCategory(de, cat)
    transparently enforceable causing effects

point "c"

rule "access_request_recipient"
    whenever
        ONCE (Request(ds, rq, c) AND IsAccessRequest(rq))
        RequestResponse(ds, rq, rs)
        EXISTS pr, a, d. (ONCE DataProcessing(pr, c, a, d) AND PersonalData(d, ds) AND HasIntendedRecipient(d, e))
    oblige
        EXISTS de. Contains(rs, de) AND IsRecipient(de, e)
    transparently enforceable causing effects

rule "access_request_recipient_category"
    whenever
        ONCE (Request(ds, rq, c) AND IsAccessRequest(rq))
        RequestResponse(ds, rq, rs)
        EXISTS pr, a, d. (ONCE DataProcessing(pr, c, a, d) AND PersonalData(d, ds) AND HasIntendedRecipientCategory(d, cat))
    oblige
        EXISTS de. Contains(rs, de) AND IsRecipientCategory(de, cat)
    transparently enforceable causing effects

point "d"

rule "access_request_storage_period"
    whenever
        ONCE (Request(ds, rq, c) AND IsAccessRequest(rq))
        RequestResponse(ds, rq, rs)
        EXISTS pr, a, d. (ONCE DataProcessing(pr, c, a, d) AND PersonalData(d, ds) AND HasStoragePeriod(d, t))
    oblige
        EXISTS de. Contains(rs, de) AND IsStoragePeriod(de, t)
    transparently enforceable causing effects

rule "access_request_storage_criteria"
    whenever
        ONCE (Request(ds, rq, c) AND IsAccessRequest(rq))
        RequestResponse(ds, rq, rs)
        EXISTS pr, a, d. (ONCE DataProcessing(pr, c, a, d) AND PersonalData(d, ds) AND HasStorageCriteria(d, cr))
    oblige
        EXISTS de. Contains(rs, de) AND IsStorageCriteria(de, cr)
    transparently enforceable causing effects

point "e"

rule
    whenever
        ONCE (Request(ds, rq, c) AND IsAccessRequest(rq))
        RequestResponse(ds, rq, rs)
        EXISTS pr, a, d. (ONCE DataProcessing(pr, c, a, d) AND PersonalData(d, ds))
    oblige
        EXISTS de. Contains(rs, de) AND IsRights(de)
    transparently enforceable causing effects

point "f"

rule
    whenever
        ONCE (Request(ds, rq, c) AND IsAccessRequest(rq))
        RequestResponse(ds, rq, rs)
        EXISTS pr, a, d. (ONCE DataProcessing(pr, c, a, d) AND PersonalData(d, ds))
    oblige
        EXISTS de. Contains(rs, de) AND IsComplaintStatement(de, rq)
    transparently enforceable causing effects

point "g"

rule "access_request_reception_source"
    whenever
        ONCE (Request(ds, rq, c) AND IsAccessRequest(rq))
        RequestResponse(ds, rq, rs)
        EXISTS pr, a, d. (ONCE DataProcessing(pr, c, a, d) AND IsIndirectCollection(a, d, ds) AND IsReception(a, e))
    oblige
        EXISTS de. Contains(rs, de) AND IsReceptionSource(de, e)
    transparently enforceable causing effects

rule "access_request_dssource"
    whenever
        ONCE (Request(ds, rq, c) AND IsAccessRequest(rq))
        RequestResponse(ds, rq, rs)
        EXISTS pr, a, d. (ONCE DataProcessing(pr, c, a, d) AND IsIndirectCollection(a, d, ds) AND IsCollection(a, ds') AND ds <> ds')
    oblige
        EXISTS de. Contains(rs, de) AND IsDSSource(de, ds')
    transparently enforceable causing effects

point "h"

rule "access_request_automated_decision"
    whenever
        ONCE (Request(ds, rq, c) AND IsAccessRequest(rq))
        RequestResponse(ds, rq, rs)
        EXISTS pr, a, d. (ONCE (DataProcessing(pr, c, a, d) AND PersonalData(d, ds) AND HasIntendedAutomatedDecision(d, de)))
    oblige
        EXISTS de. Contains(rs, de) AND IsAutomatedDecision(de)
    transparently enforceable causing effects

paragraph "2"

rule
    whenever
        ONCE (Request(ds, rq, c) AND IsAccessRequest(rq))
        RequestResponse(ds, rq, rs)
        EXISTS pr, a, d. (ONCE (DataProcessing(pr, c, a, d) AND PersonalData(d, ds) AND HasIntendedTransfer(d, co)))
    oblige
        ONCE (EXISTS de. Contains(rs, de) AND IsTransfer(de, co))
        ONCE (EXISTS de. Contains(rs, de) AND IsTransferBasis(de, co))
    transparently enforceable causing effects

paragraph "3"

causable observable predicate ContainsData
    """Declaration {de} contains data file {f}"""
    de : declaration
    f : file

causable observable predicate PersonalDataCopy
    """File {f} is a copy of personal data of data subject {ds}, not adversely affecting the rights and freedoms of others."""
    f : file
    ds : data_subject

causable observable predicate IsCommonlyUsedFormat
    """File {f} is in a commonly used format"""
    f : file

observable predicate IsFurtherCopy
    """Request {rq} requests a further copy of the personal data undergoing processing"""
    rq : request

rule "data_copy"
    whenever
        ONCE (Request(ds, rq, c) AND IsAccessRequest(rq))
        RequestResponse(ds, rq, rs)
        EXISTS pr, a, d. (ONCE (DataProcessing(pr, c, a, d) AND PersonalData(d, ds)))
    oblige
        EXISTS f. ContainsData(rs, f) AND PersonalDataCopy(f, ds) AND IsCommonlyUsedFormat(f)
    transparently enforceable causing effects

rule "further_copy"
    whenever
        IsFurtherCopy(rq)
    except
        article "12" paragraph "5" rule "free_of_charge"

paragraph "4"

note "Skipped: Integrated in the docstring of PersonalDataCopy"

article "16" "Right to rectification"

internal predicate IsObligedToRectify
    """Controller {c} is obliged to rectify data {d} to data {d'}"""
    c : entity
    d : data
    d' : data

observable predicate IsRectificationRequest
    """Request {rq} is a rectification request, specifying that data {d} should be rectified to {d'}.
       This includes requests to have incomplete personal data completed, including by means of providing 
       a supplementary statement."""
    rq : request
    d : data
    d' : data

observable event HasInaccuracy
    """Data {d} has inaccuracy"""
    d : data

rule "rectification_obligation"
    whenever
        IsObligedToRectify(c, d, d')
    oblige
        (NOT UndueDataDelay(d)) UNTIL Rectify(d, d')
    transparently enforceable causing effects

rule "rectification_request_inaccuracy"
    whenever
        ONCE (Request(ds, rq, c) AND IsRectificationRequest(rq, d, d'))
        RequestResponse(ds, rq, rs)
        EXISTS pr, a, d. (ONCE (DataProcessing(pr, c, a, d) AND PersonalData(d, ds)))
        HasInaccuracy(d)
    constitute
        IsObligedToRectify(c, d, d')

article "17" "Right to erasure ('right to be forgotten')"

observable predicate IsErasureRequest
    """Request {rq} is an erasure request, specifying that data {d} should be deleted."""
    rq : request
    d : data

internal predicate ValidObjection
    """Data subject {ds} has objected to the processing of data {d}, and there are no overriding legitimate
       grounds for the processing, or the data subject has objected to the processing of data {d} for direct
       marketing purposes."""
    ds : data_subject
    d : data

paragraph "1"

rule
    whenever
        IsObligedToDelete(c, d)
    oblige
        NOT UndueDataDelay(d) UNTIL Delete(d)
    transparently enforceable causing effects

point "a"

rule
    whenever
        (ONCE (EXISTS rq. Request(ds, rq, c) AND IsErasureRequest(rq, d)) AND RequestResponse(ds, rq, rs)) OR (DataReview(c, d) AND PersonalData(d, ds))
        NOT (EXISTS pr, a, d, p. (ONCE (DataProcessing(pr, c, a, d) AND PersonalData(d, ds) AND HasPurpose(a, p))) AND IsNecessary(d, p))
    constitute
        IsObligedToDelete(c, d)
        
point "b"

rule
    whenever
        (ONCE (EXISTS rq. Request(ds, rq, c) AND IsErasureRequest(rq, d)) AND RequestResponse(ds, rq, rs)) OR (DataReview(c, d) AND PersonalData(d, ds))
        NOT (EXISTS pr, a, d, p. (NOT WithdrawConsent(ds, p, c)) SINCE (DataProcessing(pr, c, a, d) AND PersonalData(d, ds) AND (IsLawful(a, "6(1)(a)") OR IsLawful(a, "9(2)(a)"))) AND NOT (EXISTS ba. IsLawful(a, ba)))
    constitute
        IsObligedToDelete(c, d)

point "c"

internal event IsActiveObjection
    """Data subject {ds} has objected to processing of data by controller {c} for purpose {p} with justification {de},
       and there are no overriding legitimate grounds for the processing, or the data subject has objected to the
       processing of data for direct marketing purposes."""
    ds : data_subject
    c : entity
    p : purpose
    de : declaration

rule
    whenever
        IsActiveObjection(ds, c, p, de)
        EXISTS pr, a. (ONCE (DataProcessing(pr, c, a, d) AND PersonalData(d, ds)))
    constitute
        IsObligedToDelete(c, d)

point "d"

note "Skipped: personal data is never unlawfully processed (NO VIOLATION)."

point "e"

note "Skipped: OPENING CLAUSE."

point "f"

rule
    whenever
        DataProcessing(pr, c, a, d)
        PersonalData(d, ds)
        IsLawful(a, "8(1)")
    constitute
        IsObligedToDelete(c, d)

paragraph "2"

observable event Share
    """Controller {c} shares data {d} with entity {e}"""
    c : entity
    e : entity
    d : data

causable observable event NotifyOfErasure
    """The controller {c}, taking account of available technology and the cost of implementation, takes 
       reasonable steps, including technical measures, to inform {e} that the data subject has requested 
       the erasure of any links to, or copy or replication of, data {d}."""
    c : entity
    e : entity
    d : data

rule
    whenever
        IsObligedToDelete(c, d)
        ONCE Share(c, e, d)
    oblige
        NOT UndueDataDelay(d) UNTIL (NotifyOfErasure(c, e, d))
    transparently enforceable causing effects

paragraph "3"

point "a"

observable predicate IsNecessaryForFreedomOfExpression
    """Activity {a} is necessary for exercising the right to freedom of expression and information."""
    a : activity

rule
    whenever
        IsNecessaryForFreedomOfExpression(a)
    except
        paragraph "1"
        paragraph "2"

point "b" 

rule 
    whenever
        DataProcessing(pr, c, a, d)
        (EXISTS l. IsNecessaryForLegalObligation(a, l)) OR (EXISTS pi. IsNecessaryForPublicInterest(a, pi)) OR IsPerformanceOfPublicAuthorityTask(a) AND IsPublicAuthority(c)
    except
        paragraph "1"
        paragraph "2"   

point "c"

rule
    whenever
        DataProcessing(pr, c, a, d)
        IsNecessaryForPublicInterest(a, pi)
        IsHealthRelated(pi)
    except
        paragraph "1"
        paragraph "2"

point "d"

rule
    whenever
        DataProcessing(pr, c, a, d)
        IsNecessaryForArchivalPurposes(a)
    except
        paragraph "1"
        paragraph "2"

point "e"

rule
    whenever
        DataProcessing(pr, c, a, d)
        IsNecessaryForJudicialClaims(a)
    except
        paragraph "1"
        paragraph "2"

article "18" "Right to restriction of processing"

observable predicate IsRestrictionRequest
    """Request {rq} is a restriction request for data {d} and purpose {p}."""
    rq : request
    d : data
    p : purpose

observable predicate ContestsAccuracy
    """Request {rq} specifies that data {d} is contested to be inaccurate, and specifies the rectified data {d'}."""
    rq : request
    d : data
    d' : data

internal predicate Restricted
    """Processing of data {d} for purpose {p} is restricted."""
    d : data
    p : purpose

suppressable event LiftRestriction
    """Controller {c} lifts the restriction on data {d} due to request {rq}."""
    c : entity
    d : data
    rq : request

paragraph "1"

point "a"

rule
    whenever
        ONCE (Request(ds, rq, c) AND IsRestrictionRequest(rq, d, p) AND ContestsAccuracy(rq, d, d'))
        ((NOT EXISTS d''. Rectify(d, d'')) SINCE RequestResponse(ds, rq, rs)) OR NOT ONCE LiftRestriction(c, d, rq)
    constitute
        Restricted(d, p)

point "b"

note "Skipped: data is never unlawfully processed in this model (NO VIOLATION)."

point "c"

observable predicate DataIsNecessaryForJudicialClaims
    """Data {d} is necessary for the establishment, exercise or defence of legal claims."""
    d : data

rule
    whenever
        (NOT LiftRestriction(c, d, rq)) SINCE (Request(ds, rq, c) AND IsRestrictionRequest(rq, d, p) AND DataIsNecessaryForJudicialClaims(d))
    constitute
        Restricted(d, p)
    
point "d"

rule
    whenever
        PersonalData(d, ds)  
        IsActiveObjection(ds, c, p, de)
    constitute
        Restricted(d, p)

paragraph "2"

observable predicate IsStorage
    """Activity {a} consists in storing data."""
    a : activity

observable predicate IsNecessaryForProtectionOfRights
    """Activity {a} is necessary for the protection of the rights of another natural or legal person {e}."""
    a : activity
    e : entity

observable predicate IsNecessaryForImportantPublicInterest
    """Activity {a} is necessary for reasons of important public interest {pi}, on the basis of Union or Member State law."""
    a : activity
    pi : public_interest

rule
    whenever
        Restricted(d, p)
        DataProcessing(pr, c, a, d)
        HasPurpose(a, p)
        NOT IsStorage(a)
    oblige
        IsLawful(a, "6(1)(a)") OR IsLawful(a, "9(2)(a)") OR IsNecessaryForJudicialClaims(a) OR (EXISTS e. IsNecessaryForProtectionOfRights(a, e)) OR (EXISTS pi. IsNecessaryForImportantPublicInterest(a, pi))
    transparently enforceable suppressing condition[1]

paragraph "3"

observable predicate IsRestrictionToBeLifted
    """Declaration {re} declares that the restriction on data {d} due to request {rq} is to be lifted."""
    re : declaration
    d : data
    rq : request

rule
    whenever
        LiftRestriction(c, d, rq)
    oblige
        ONCE (EXISTS ds, de, re. Inform(c, ds, de) AND Contains(de, re) AND IsRestrictionToBeLifted(re, d, rq))
    transparently enforceable suppressing conditions

article "19" "Notification obligation regarding rectification or erasure of personal data or restriction of processing"

causable observable event NotifyOfRectification
    """The controller {c}, unless this proves impossible or involves disproportionate effort, communicates
       to {e} the rectification of data {d} to {d'}."""
    c : entity
    e : entity
    d : data
    d' : data

causable observable event NotifyOfRestriction
    """The controller {c}, unless this proves impossible or involves disproportionate effort, communicates
       to {e} the restriction of data {d} for purpose {p}."""
    c : entity
    e : entity
    d : data
    p : purpose

observable event IsRecipientRequest
    """Request {rq} is a request for information about the recipients to whom data has been disclosed."""
    rq : request

causable observable predicate IsEffectiveRecipient
    """Declaration {de} declares effective recipient {e}"""
    de : declaration
    e : entity
    
rule "notify_rectification"
    whenever
        IsObligedToRectify(c, d, d')
        ONCE Share(c, e, d)
    oblige
        NOT UndueDataDelay(d) UNTIL NotifyOfRectification(c, e, d, d')
    transparently enforceable causing effects

rule "notify_erasure"
    whenever
        IsObligedToDelete(c, d)
        ONCE Share(c, e, d)
    oblige
        NOT UndueDataDelay(d) UNTIL NotifyOfErasure(c, e, d)
    transparently enforceable causing effects

rule "notify_restriction"
    whenever
        Restricted(d, p) AND NOT PREVIOUS Restricted(d, p)
        ONCE Share(c, e, d)
    oblige
        NOT UndueDataDelay(d) UNTIL NotifyOfRestriction(c, e, d, p)
    transparently enforceable causing effects

rule "access_request_recipient"
    whenever
        ONCE (Request(ds, rq, c) AND IsRecipientRequest(rq))
        RequestResponse(ds, rq, rs)
        ONCE (EXISTS d. Share(c, e, d) AND PersonalData(d, ds))
    oblige
        EXISTS de. Contains(rs, de) AND IsEffectiveRecipient(de, e)
    transparently enforceable causing effects

article "20" "Right to data portability"

causable observable predicate IsPortabilityRequest
    """Request {rq} is a data portability request"""
    rq : request

causable observable predicate IsStructuredFormat
    """File {f} is in a structured format"""
    f : file

causable observable predicate IsMachineReadableFormat
    """File {f} is in a machine-readable format"""
    f : file

observable predicate SpecifiesNewController
    """Request {rq} specifies a new controller {c'} to which the data should be transmitted"""
    rq : request
    c' : entity

observable predicate IsDirectTransmissionFeasible
    """It is feasible for controller {c} to directly transmit data to controller {c'}"""
    c : entity
    c' : entity

causable observable predicate Transmit
    """Controller {c} transmits file {f} to controller {c'}"""
    c : entity
    c' : entity
    f : file

paragraph "1"

rule
    whenever
        ONCE (Request(ds, rq, c) AND IsPortabilityRequest(rq))
        RequestResponse(ds, rq, rs)
        EXISTS pr, d. (ONCE (DataProcessing(pr, c, a, d) AND PersonalData(d, ds) AND (IsLawful(a, "6(1)(a)") OR IsLawful(a, "6(1)(b)") OR IsLawful(a, "9(2)(a)"))))
    oblige
        EXISTS f. ContainsData(rs, f) AND PersonalDataCopy(f, ds) AND IsStructuredFormat(f) AND IsCommonlyUsedFormat(f) AND IsMachineReadableFormat(f)
    enforceable causing effects

note "Skip: the data subjects have the right to transmit those data to another controller (formalized in next paragraph)."
note "Skip: the processing is carried out by automated means (MODEL)."

paragraph "2"

rule
    whenever
        ONCE (Request(ds, rq, c) AND IsPortabilityRequest(rq) AND SpecifiesNewController(rq, c'))
        RequestResponse(ds, rq, rs)
        EXISTS pr, a, d. (ONCE (DataProcessing(pr, c, a, d) AND PersonalData(d, ds) AND (IsLawful(a, "6(1)(a)") OR IsLawful(a, "6(1)(b)") OR IsLawful(a, "9(2)(a)"))))
        IsDirectTransmissionFeasible(c, c')
        ContainsData(rs, f)
    oblige
        Transmit(c, c', f)
    enforceable causing effects

paragraph "3"

rule "public_interest"
    whenever
        IsNecessaryForPublicInterest(a, pi)
    except
        paragraph "1"

rule "performance_public_authority_task"
    whenever					      
        IsPerformanceOfPublicAuthorityTask(a)
        IsPublicAuthority(c)
    except					  
        paragraph "1"
					    
note "Skipped: without prejudice to Article 17 (taken into account in interpretation)."

paragraph "4"

note "Skipped: integrated in the docstring of PersonalDataCopy."

article "21" "Right to object"

observable event Object
    """Data subject {ds} objects to processing of data by controller {c} for purpose {p} with justification {de}."""
    ds : data_subject
    c : entity
    p : purpose
    de : declaration

observable predicate DemonstrateOverridingCompellingGrounds
    """Controller {c} demonstrates that there are overriding legitimate grounds for purpose {p} which
       override the interests, rights and freedoms of the data subject {ds} as stated in {de}, or for the
       establishment, exercise or defence of legal claims."""
    c : entity
    ds : data_subject
    p : purpose
    de : declaration

paragraph "1"

rule "object_ef_exception"
    whenever
        DataProcessing(pr, c, a, d)
        HasPurpose(a, p)
        (NOT DemonstrateOverridingCompellingGrounds(c, ds, p, de)) SINCE Object(ds, c, p, de)
    except
        article "6" paragraph "1" paragraph[1] "1" point "e"
        article "6" paragraph "1" paragraph[1] "1" point "f"

rule "object_ef_definition"
    whenever
        (NOT DemonstrateOverridingCompellingGrounds(c, ds, p, de)) SINCE Object(ds, c, p, de)
    constitute
        IsActiveObjection(ds, c, p, de)

paragraph "2"
paragraph "3"

observable predicate IsDirectMarketing
    """Purpose {p} is a direct marketing purpose."""
    p : purpose

rule "object_dm_exception"
    whenever
        DataProcessing(pr, c, a, d)
        HasPurpose(a, p)
        PersonalData(d, ds)
        IsDirectMarketing(p)
        ONCE Object(ds, c, p, de)
    except
        article "6" paragraph "1"

rule "object_dm_definition"
    whenever
        ONCE Object(ds, c, p, de)
        IsDirectMarketing(p)
    constitute
        IsActiveObjection(ds, c, p, de)

paragraph "4"

note "Skipped: integrated in the docstring of IsRights."
note "Skipped: PERMISSION in (5)"

paragraph "6"

rule "object_archiving_exception"
    whenever
        DataProcessing(pr, c, a, d)
        PersonalData(d, ds)
        HasPurpose(a, "Archiving")
        ONCE Object(ds, c, "Archiving", de)
    except
        article "6" paragraph "1"

rule "object_archiving_definition"
    whenever
        ONCE Object(ds, c, "Archiving", de)
    constitute
        IsActiveObjection(ds, c, "Archiving", de)

rule "object_archiving_override"
    whenever
        DataProcessing(pr, c, a, d)
        IsNecessaryForPublicInterest(a, pi)
    except
        rule "object_archiving_exception"
        rule "object_archiving_definition"

article "22" "Automated individual decision-making, including profiling"

paragraph "1"

observable predicate IsAutomatedDecisionMakingPurpose
    """Purpose {p} is a purpose that consists in making a decision based solely on automated processing,
       including profiling, which produces legal effects concerning the data subject or similarly significantly
       affects the data subject."""
    p : purpose

rule
    whenever
        DataProcessing(pr, c, a, d)
        PersonalData(d, ds)
    oblige
        NOT (EXISTS de. AutomatedDecision(a, d, ds, de))
    transparently enforceable suppressing condition[0]

paragraph "2"

point "a"

rule
    whenever
        DataProcessing(pr, c, a, d)
        IsNecessaryForContract(a, co)
        (NOT EndContract(co)) SINCE (PrepareContract(co) OR StartContract(co))
        ONCE (StartContract(co) AND IsContractParty(ds, co))
    except
        paragraph "1"

note "Skipped: OPENING CLAUSE in (b)"

point "c"

rule
    whenever
        DataProcessing(pr, c, a, d)
        (NOT WithdrawConsent(ds, p, c)) SINCE GiveConsent(ds, p, c)
        IsAutomatedDecisionMakingPurpose(p)
    except
        paragraph "1"

paragraph "3"

note "Skip: 'suitable measures' are implemented as part of the model"

paragraph "4"

rule "special_categories_decision_making_prohibition"
    whenever
        PersonalData(d, ds)
        IsSpecialData(d, sp)
        ImplementFundamentalRightsSafeguards(a, ds)
    except
        paragraph "2"

rule "special_categories_decision_making_exception"
    whenever
        IsLawful(a, "9(2)(a)") OR IsLawful(a, "9(2)(g)")
    except
        rule "special_categories_decision_making_prohibition"

article "30" "Records of processing activities"

causable observable event Record
    """A record in the record of processing activities of {pr} processing data on behalf of {c}, setting the property 
       {p} of data processing activity {a} to value {v}."""
    pr : entity
    c : entity
    a : activity
    p : string
    v : string

observable predicate IsJointController
    """Entity {jc} is a joint controller with controller {c} for data processing activity {a}."""
    a : activity
    c : entity
    jc : entity
    
suppressable event Transfer
    """Activity {a} involves a transfer whereby the data is transferred to controller {c'} with processor {pr'} in country or 
       international organisation {co} subject to safeguards {sg}."""
    a : activity
    c' : entity
    pr' : entity
    co : country_io
    sg : safeguards

function string_of_entity(
    c : entity
) -> string

function string_of_purpose(
    p : purpose
) -> string

function string_of_category(
    cat : special_data_category
) -> string

function string_of_country_io(
    co : country_io
) -> string

function string_of_safeguards(
    sg : safeguards
) -> string

function string_of_span(
    t : span
) -> string

function string_of_declaration(
    de : declaration
) -> string

paragraph "1"

point "a"

rule "controller_record"
    whenever
        DataProcessing(pr, c, a, d)
    oblige
        Record(pr, c, a, "Controller", string_of_entity(c))
    transparently enforceable causing effects

rule "controller_representative_record"
    whenever
        DataProcessing(pr, c, a, d)
        IsControllerRepresentative(c, cr)
    oblige
        Record(pr, c, a, "ControllerRepresentative", string_of_entity(cr))
    transparently enforceable causing effects

rule "joint_controller_record"
    whenever
        DataProcessing(pr, c, a, d)
        IsJointController(a, c, jc)
    oblige
        Record(pr, c, a, "JointController", string_of_entity(jc))
    transparently enforceable causing effects

rule "dpo_record"
    whenever
        DataProcessing(pr, c, a, d)
        IsDataProtectionOfficer(c, dpo)
    oblige
        Record(pr, c, a, "DPO", string_of_entity(dpo))
    transparently enforceable causing effects

point "b"

rule "purpose_record"
    whenever
        DataProcessing(pr, c, a, d)
        HasPurpose(a, p)
    oblige
        Record(pr, c, a, "Purpose", string_of_purpose(p))
    transparently enforceable causing effects

point "c"

observable predicate HasDataSubjectCategory
    """Activity {a} is performed with data from data subject category {cat}."""
    a : activity
    cat : special_data_category

rule "categories_of_data_subjects_record"
    whenever
        DataProcessing(pr, c, a, d)
        PersonalData(d, ds)
        HasDataSubjectCategory(a, cat)
    oblige
        Record(pr, c, a, "DataSubjectCategory", string_of_category(cat))
    transparently enforceable causing effects

rule "categories_of_data_record"
    whenever
        DataProcessing(pr, c, a, d)
        PersonalData(d, ds)
        HasCategory(d, cat)
    oblige
        Record(pr, c, a, "DataCategory", string_of_category(cat))
    transparently enforceable causing effects

point "d"

rule "recipients_record"
    whenever
        DataProcessing(pr, c, a, d)
        PersonalData(d, ds)
        HasIntendedRecipient(d, e)
    oblige
        Record(pr, c, a, "Recipient", string_of_entity(e))
    transparently enforceable causing effects

rule "recipient_categories_record"
    whenever
        DataProcessing(pr, c, a, d)
        PersonalData(d, ds)
        HasIntendedRecipientCategory(d, cat)
    oblige
        Record(pr, c, a, "RecipientCategory", string_of_entity(cat))
    transparently enforceable causing effects

point "e"

rule "transfer_record"
    whenever
        DataProcessing(pr, c, a, d)
        PersonalData(d, ds)
        Transfer(a, c', pr', co, sg)
    oblige
        Record(pr, c, a, "TransferRecipient", string_of_country_io(co))
        Record(pr, c, a, "TransferSafeguards", string_of_safeguards(sg))
    transparently enforceable causing effects

point "f"

rule "storage_period_record"
    whenever
        DataProcessing(pr, c, a, d)
        PersonalData(d, ds)
        HasStoragePeriod(d, t)
    oblige
        Record(pr, c, a, "StoragePeriod", string_of_span(t))
    transparently enforceable causing effects

point "g"

observable predicate HasSecurityMeasuresDeclaration
    """Activity {a} is performed with security measures declaration {de}."""
    a : activity
    de : declaration

rule "security_measures_record"
    whenever
        DataProcessing(pr, c, a, d)
        PersonalData(d, ds)
        HasSecurityMeasuresDeclaration(a, de)
    oblige
        Record(pr, c, a, "SecurityMeasures", string_of_declaration(de))
    transparently enforceable causing effects

paragraph "2" 

note "Skip: redundant with point (1) above."

paragraph "3"

note "Skip: all records are in electronic form in our model"

note "Skip (4): not a system property"

paragraph "5"

observable predicate IsSME
    """Controller {c} is a small or medium-sized enterprise (SME) with fewer than 250 employees."""
    c : entity

observable predicate IsRiskyProcessing
    """Activity {a} is likely to result in a high risk to the rights and freedoms of natural persons."""
    a : activity

observable predicate IsOccasionalProcessing
    """Activity {a} is occasional processing."""
    a : activity

rule "SME_exemption"
    whenever
        IsSME(c)
        IsSME(pr)
    except
        paragraph "1"
        paragraph "2"

rule
    whenever
        IsRiskyProcessing(a)
        NOT IsOccasionalProcessing(a)
        DataProcessing(pr, c, a, d') AND ((EXISTS sp. IsSpecialData(d', sp)) OR RelatesToCriminalConvictionsOrOffences(d'))
    except
        rule "SME_exemption"

article "44" "General principles for transfers"

rule 
    whenever
        DataProcessing(pr, c, a, d)
        PersonalData(d, ds)
        Transfer(a, c', pr', co, sg)
    oblige
        false
    enforceable suppressing condition[2]

article "45" "Transfers on the basis of an adequacy decision"

paragraph "1"

observable predicate AdequacyDecision
    """Country or international organisation {co} is subject to an adequacy decision by the Commission."""
    co : country_io

rule
    whenever
        AdequacyDecision(co)
    except
        article "44"

article "46" "Transfers subject to appropriate safeguards"

paragraph "1"

internal predicate IsAppropriateSafeguards
    """Safeguards {sg} are appropriate"""
    sg : safeguards

observable predicate HasEnforceableRights
    """Safeguards {sg} provide enforceable rights and effective legal remedies for data subjects."""
    sg : safeguards

rule
    whenever
        Transfer(a, c', pr', co, sg)
        IsAppropriateSafeguards(sg)
        HasEnforceableRights(sg)
    except
        article "44"

paragraph "2"

observable predicate IsLegallyBindingInstrument
    """Safeguards {sg} consist of a legally binding and enforceable instrument between public authorities or bodies"""
    sg : safeguards

observable predicate IsBindingCorporateRules
    """Safeguards {sg} consist of binding corporate rules in accordance with Article 47"""
    sg : safeguards

observable predicate IsCommissionStandardClauses
    """Safeguards {sg} consist of standard data protection clauses adopted by the Commission in accordance with the examination procedure referred to in Article 93(2)"""
    sg : safeguards

observable predicate IsSupervisoryAuthorityStandardClauses
    """Safeguards {sg} consist of standard data protection clauses adopted by a supervisory authority and approved by the Commission pursuant to the examination procedure referred to in Article 93(2)"""
    sg : safeguards

observable predicate IsApprovedCodeOfConduct
    """Safeguards {sg} consist of an approved code of conduct pursuant to Article 40 together with binding and enforceable commitments of the controller or processor in the third country to apply the appropriate safeguards, including as regards data subjects' rights"""
    sg : safeguards

observable predicate IsApprovedCertificationMechanism
    """Safeguards {sg} consist of an approved certification mechanism pursuant to Article 42 together with binding and enforceable commitments of the controller or processor in the third country to apply the appropriate safeguards, including as regards data subjects' rights"""
    sg : safeguards

point "a"

rule
    whenever
        IsLegallyBindingInstrument(sg)
    constitute
        IsAppropriateSafeguards(sg)

point "b"

rule
    whenever
        IsBindingCorporateRules(sg)
    constitute
        IsAppropriateSafeguards(sg)

point "c"

rule
    whenever
        IsCommissionStandardClauses(sg)
    constitute
        IsAppropriateSafeguards(sg)

point "d"

rule
    whenever
        IsSupervisoryAuthorityStandardClauses(sg)
    constitute
        IsAppropriateSafeguards(sg)

point "e"

rule
    whenever
        IsApprovedCodeOfConduct(sg)
    constitute
        IsAppropriateSafeguards(sg)

point "f"

rule
    whenever
        IsApprovedCertificationMechanism(sg)
    constitute
        IsAppropriateSafeguards(sg)

paragraph "3"

observable predicate HasSupervisoryApproval
    """Contract {ct} has obtained the approval of the competent supervisory authority for the safeguards {sg}."""
    ct : contract
    sg : safeguards

observable predicate IsContractualClauses
    """Contractual clauses {ct} between the controller {c} or processor {pr} and the controller {c'} or processor {pr'} 
       in the third country or international organisation provide the safeguards {sg}."""
    ct : contract
    c : entity
    pr : entity
    c' : entity
    pr' : entity
    sg : safeguards

observable predicate IsAdministrativeArrangement
    """Provisions {ct} to be inserted into administrative arrangements with the public authority {co}, including
       enforceable and effective data subject rights, provide the safeguards {sg}."""
    ct : contract
    co : country_io
    sg : safeguards

point "a"

rule
    whenever
        IsContractualClauses(ct, c, pr, c', pr', sg)
        HasSupervisoryApproval(ct, sg)
    constitute
        IsAppropriateSafeguards(sg)

point "b"

rule 
    whenever
        IsAdministrativeArrangement(ct, co, sg)
        HasSupervisoryApproval(ct, sg)
    constitute
        IsAppropriateSafeguards(sg)

article "49" "Derogations for specific situations"

paragraph "1"

paragraph[1] "1"

point "a"

observable predicate IsRisksOfTransfer
    """The declaration {re} identifies specific risks associated with the transfer to country or international organisation {co} 
       to controller {c'} with processor {pr'} in country or international organisation {co} subject to safeguards {sg}."""
    re : declaration
    c' : entity
    pr' : entity
    co : country_io
    sg : safeguards

rule
    whenever
        ONCE (Transfer(a, c', pr', co, sg) AND ONCE Inform(c, ds, de) AND Contains(de, re) AND IsRisksOfTransfer(re, c', pr', co, sg))
    except
        article "44"

point "b"

observable event RequestContractPreparation
    """Data subject {ds} requests the preparation of contract {co}."""
    ds : data_subject
    co : contract

rule
    whenever
        (NOT EndContract(con)) SINCE (PrepareContract(con) OR StartContract(con))
        ONCE (RequestContractPreparation(ds, con) AND IsContractParty(ds, con))
        IsNecessaryForContract(a, con)
    except
        article "44"

point "c"

observable predicate IsInInterestOf
    """The contract {co} is in the interest of data subject {ds}."""
    co : contract
    ds : data_subject

rule
    whenever
        (NOT EndContract(con)) SINCE ((PrepareContract(con) OR StartContract(con)) AND IsContractParty(ds, con))
        IsInInterestOf(con, ds)
        IsNecessaryForContract(a, con)
    except
        article "44"

point "d"

rule
    whenever
        IsNecessaryForImportantPublicInterest(a, pi)
    except
        article "44"

point "e"

rule
    whenever
        IsNecessaryForJudicialClaims(a)
    except
        article "44"

point "f"

rule
    whenever
        IsNecessaryForVitalInterests(a, ds', v)
        IsUnableToConsent(ds')
    except
        article "44"

point "g"

observable predicate IsOpenRegisterData
    """Data {d} is personal data contained in a public register {reg} which according to Union or Member State law is 
       intended to provide information to the public and which is open to consultation by the public or by any 
       person who can demonstrate a legitimate interest, but only to the extent that the conditions laid down in 
       Union or Member State law for consultation are fulfilled in the particular case."""
    d : data
    reg : register

observable predicate FulfillsConsultationConditions
    """The conditions laid down in Union or Member State law for consultation of data {d} are fulfilled in the particular case."""
    a : activity
    d : data

rule
    whenever
        IsOpenRegisterData(d, reg)
        FulfillsConsultationConditions(a, d)
    except
        article "44"

paragraph[1] "2"

observable predicate IsNotRepetitiveTransfer
    """The transfer to controller {c'} with processor {pr'} in country or international organisation {co} subject to safeguards {sg} 
       in the context of activity {a} is not a repetitive transfer."""
    a : activity
    c' : entity
    pr' : entity
    co : country_io
    sg : safeguards

observable predicate IsLimitedDSTransfer
    """The transfer to controller {c'} with processor {pr'} in country or international organisation {co} subject to safeguards {sg}
      in the context of activity {a} concerns only a limited set of data subjects."""
    a : activity
    c' : entity
    pr' : entity
    co : country_io
    sg : safeguards

observable predicate AssessTransfer
    """Controller {c} has assessed the transfer to controller {c'} with processor {pr'} in country or international organisation {co} 
       subject to safeguards {sg} in the context of activity {a}, resulting in declaration {de}."""
    c : entity
    a : activity
    c' : entity
    pr' : entity
    co : country_io
    sg : safeguards
    de : declaration

internal predicate LastResortTransfer
    """The transfer from controller {c} to controller {c'} with processor {pr'} in country or international organisation {co} subject to safeguards {sg} 
       in the context of activity {a} is a last resort transfer."""
    a : activity
    c : entity
    c' : entity
    pr' : entity
    co : country_io
    sg : safeguards
    i : interest

causable observable predicate ReportLastResortTransfer
    """Controller {c} reports to the DPA the last resort transfer to controller {c'} with processor {pr'} in country or international 
       organisation {co} subject to safeguards {sg} in the context of activity {a}, justified by legitimate interest {i}."""
    a : activity
    c : entity
    c' : entity
    pr' : entity
    co : country_io
    sg : safeguards
    i : interest

causable observable predicate IsLastResortTransfer
    """The declaration {re} reports that the transfer from controller {c} to controller {c'} with processor {pr'} in country 
       or international organisation {co} subject to safeguards {sg} 
       is a last resort transfer justified by legitimate interest {i}."""
    re : declaration
    c : entity
    c' : entity
    pr' : entity
    co : country_io
    sg : safeguards
    i : interest

rule "last_resort_transfer"
    whenever
        IsNotRepetitiveTransfer(a, c', pr', co, sg)
        IsLimitedDSTransfer(a, c', pr', co, sg)
        IsNecessaryForLegitimateInterest(a, c, i) AND NOT (EXISTS ds. IsOverriddenByDataSubjectInterests(c, i, ds))
        ONCE AssessTransfer(c, a, c', pr', co, sg, de)
        IsAppropriateSafeguards(sg)
    constitute
        LastResortTransfer(a, c, c', pr', co, sg, i)

rule "last_resort_transfer_exception"
    whenever
        LastResortTransfer(a, c, c', pr', co, sg, i)
    except
        article "44"

rule "last_resort_transfer_report"
    whenever
        DataProcessing(pr, c, a, d)
        LastResortTransfer(a, c, c', pr', co, sg, i)
        PersonalData(d, ds)
    oblige
        ReportLastResortTransfer(a, c, c', pr', co, sg, i)
        EXISTS de, re. Inform(c, ds, de) AND Contains(de, re) AND IsLastResortTransfer(re, c, c', pr', co, sg, i)
    transparently enforceable causing effects

paragraph "2"

observable predicate IsLimitedRegisterData
    """The data from register {reg} used in activity {a} is limited to what is necessary as per Art. 49(2)."""
    a : activity
    reg : register

observable predicate IsLegitimateInterestRegister
    """The register {reg} is intended for consultation by any person who can demonstrate a legitimate interest."""
    reg : register

observable event ValidRegisterConsultationRequest
    """A data subject {ds} with legitimate interest {i} makes a request to consult data {d} from register {reg} 
       based on legitimate interest {i}."""
    ds : data_subject
    d : data
    reg : register
    i : interest

rule
    whenever
        IsLimitedRegisterData(a, reg)
        IsLegitimateInterestRegister(reg) IMPLIES (EXISTS d, ds', i. ONCE ValidRegisterConsultationRequest(ds', d, reg, i))
    scope
        paragraph "1" paragraph[1] "1" point "g"

paragraph "3"

rule
    whenever
        IsPerformanceOfPublicAuthorityTask(a) AND IsPublicAuthority(c)
    except
        paragraph "1" paragraph[1] "1" point "a"
        paragraph "1" paragraph[1] "1" point "b"
        paragraph "1" paragraph[1] "1" point "c"
        paragraph "1" paragraph[1] "2"

note "Skipped the opening clause in paragraphs (4)-(5)."

paragraph "6"

note "First part (safeguards) already formalized in Art. 30"

rule
    whenever
        AssessTransfer(c, a, c', pr', co, sg, de)
    oblige
        Record(c, c, a, "TransferAssessment", string_of_declaration(de))
