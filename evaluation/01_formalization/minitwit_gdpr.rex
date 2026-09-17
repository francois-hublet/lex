refine gdpr

type activity_id is string
type user_id     is string
type data_type   is string
type data_id     is string
type request_id  is string
type file_id     is string
type decl_id     is string

suppressable event Read
    """Data {id}, which is personal data of {owner}, is read for purpose {purpose} in the context of activity {activity} while building a webpage for user {user}."""
    id      : data_id
    owner   : user_id
    activity: activity_id
    purpose : purpose
    user    : user_id

suppressable event Write
    """Data {id}, which is personal data of {owner}, is written for purpose {purpose} in the context of activity {activity} while building a webpage for user {user}."""
    id      : data_id
    owner   : user_id
    activity: activity_id	
    purpose : purpose
    user    : user_id

suppressable event Collect
    """Data {data}, which is personal data of {owner}, is collected in the context of activity {activity} for purpose {purpose}."""
    activity: activity_id
    data    : data_id
    owner   : user_id
    purpose : purpose

causable observable event DailyErasureReview
    """Data {d} is reviewed for potential deletion, which happens at least once daily."""
    data    : data_id

suppressable event Consent
    """User {user} gives consent for their data to be used for purpose {purpose}."""
    user    : user_id
    purpose : purpose

suppressable event Revoke
    """User {user} revokes consent for their data to be used for purpose {purpose}."""
    user    : user_id
    purpose : purpose

suppressable event SpecialConsent
    """User {user} gives consent for their data of special data category {sp} to be used for purpose {purpose}."""
    user    : user_id
    purpose : purpose
    sp      : special_data_category

observable event SpecialRevoke
    """User {user} revokes consent for their data of special data category {sp} to be used for purpose {purpose}."""
    user    : user_id
    purpose : purpose
    sp      : special_data_category

observable event ContestAccuracy
    """User {user} challenges the accuracy of data {data}, claiming that it should be {data'} instead."""
    user    : user_id
    data    : data_id
    data'   : data_id

observable event RequestRectification
    """User {user} requests rectification of data {data}, to be updated to {data'}, via request {request}"""
    user    : user_id
    data    : data_id
    data'   : data_id
    request : request_id

observable event RequestAccess
    """User {user} requests access to their data via request {request}."""
    user    : user_id
    request : request_id

observable event RequestErasure
    """User {user} requests erasure to their data {data} via request {request}."""
    user    : user_id
    data    : data_id
    request : request_id

observable event RequestRecipientInformation
    """User {user} requests information about recipients of their data via request {request}."""
    user    : user_id
    request : request_id

causable observable event Declaration
    """Declaration {de} exists in the current context."""
    de      : decl_id

causable observable event HasText
    """Declaration {de} contains (at least) text {text}."""
    de      : decl_id
    text    : string

causable observable event NotifyErasure
    """Erasure of data {data} is notified to entity {entity}."""
    entity  : string
    data    : data_id

causable observable event NotifyRectification
    """Rectification of data {data} to {data'} is notified to entity {entity}."""
    entity  : string
    data    : data_id
    data'   : data_id

causable observable event NotifyRestriction
    """Restriction on the use of data {data} for purpose {purpose} is notified to entity {entity}."""
    entity  : string
    data    : data_id
    purpose : purpose

observable event RequestObjection
    """User {user_id} objects to the processing of their data for purpose {purpose}, making declaration {de}, via request {request}."""
    user    : user_id
    purpose : purpose
    de      : decl_id
    request : request_id

causable observable event ActivityRecord
    """An entry with property {property} and value {value} is added to the record of processing activities to document activity {activity}."""
    activity: activity_id
    property: string
    value   : string

observable event Send
    """Data {data} is sent to entity {entity}."""
    entity  : string
    data    : data_id

causable observable event SendFile
    """File {data} is sent to entity {entity}."""
    entity  : string
    file    : file_id

refine type activity     is activity_id
refine type data         is data_id
refine type data_subject is user_id
refine type entity       is string
refine type interest     is string
refine type declaration  is decl_id
refine type request      is request_id
refine type criteria     is string
refine type file         is file_id

note "### Events that are not taking place ###"

assume false AdequacyDecision  # legal
    """No transfers are taking place."""
    
assume false AssessTransfer  # legal
    """No transfers are taking place."""

assume false AuthorizeConsent  # legal
    """No delegation of consent in our model."""

assume false ChargeForRequest  # functional
    """We are never charging users for requests."""

assume false ConcernsCriminalRegister  # functional
    """We are never storing criminal register data."""

assume false DisproportionateEffortToInform  # functional
    """We never consider that it requires a disproportionate effort to inform third-parties."""

assume false EndContract  # functional
    """No contracts are being concluded."""

assume false FulfillsConsultationConditions  # functional
    """No transfers are taking place."""

assume false HasEnforceableRights  # functional
    """No transfers are taking place."""
    
assume false HasIntendedTransfer  # legal
    """No transfers are taking place."""

assume false HasPhilosophicalAim  # functional
    """No controller has a philosophical aim."""

assume false HasPoliticalAim  # functional
    """No controller has a political aim."""

assume false HasReligiousAim  # functional
    """No controller has a religious aim."""

assume false HasSupervisoryApproval  # legal
    """No transfers are taking place."""

assume false HasTradeUnionAim  # functional
    """No controller has a trade union aim."""

assume false ImplementFundamentalRightsSafeguards  # functional
    """We do not claim the impementation of fundamental rights safeguards for the processing of special data categories."""

assume false IsApprovedCertificationMechanism  # functional
    """No transfers are taking place."""

assume false IsApprovedCodeOfConduct  # functional
    """No transfers are taking place."""

assume false IsArchival  # legal
    """No archiving is performed."""

assume false IsBindingCorporateRules  # functional
    """No transfers are taking place."""

assume false IsCommissionStandardClauses  # functional
    """No transfers are taking place."""

assume true IsCommonlyUsedFormat  # legal
    """We only use structured file formats (JSON) for output."""

assume false IsContractParty  # functional
    """No contracts are being concluded."""

assume true IsElectronicDeclaration  # legal
    """All declarations are electronic."""
    
assume true IsElectronicRequest  # legal
    """All requests are electronic."""

assume false IsImpossibleElectronic  # functional
    """All requests are electronic."""

assume false IsInInterestOf  # functional
    """No contracts are being concluded."""

assume false IsJointController  # legal
    """There are no joint controllers."""

assume false IsLegallyBindingInstrument  # functional
    """No transfers are taking place."""

assume false IsLegitimateInterestRegister  # legal
    """No transfers are taking place."""

assume false IsLimitedDSTransfer  # legal
    """No transfers are taking place."""

assume false IsLimitedRegisterData  # legal
    """No transfers are taking place."""

assume true IsMachineReadableFormat  # legal
    """We only use structured file formats (JSON) for output."""

assume false IsMember  # legal
    """No membership in organizations is considered."""

assume false IsNecessaryForArchivalPurposes  # functional
    """No archiving is performed."""

assume false IsNecessaryForContract  # functional
    """No contracts are being concluded."""

assume false IsNecessaryForEmploymentLaw  # functional
    """We do not consider this legal basis."""

assume false IsNecessaryForFreedomOfExpression  # functional
    """We do not consider this legal basis."""

assume false IsNonProfit  # legal
    """No non-profit controller is involved."""

assume false IsNotRepetitiveTransfer  # legal
    """No transfers are taking place."""

assume false IsOccasionalProcessing  # functional
    """All processing is habitual, not occasional."""

assume false IsPublicAuthority  # functional
    """No public authority is involved."""

assume false IsOpenRegisterData  # functional
    """No open register is involved."""

assume true IsOutsideDisclosure  # legal
    """Data is generally disclosed to outsiders."""

assume false IsPerformanceOfPublicAuthorityTask  # functional
    """No public authority is involved."""

assume false IsReasonableFee  # legal
    """We generally do not impose fees."""

assume false IsReasonablePeriod  # functional
    """We do not wait to inform users."""

assume false IsReception  # legal
    """We do not receive data from other entities."""

assume false IsRisksOfTransfer  # legal
    """No transfers are taking place."""

assume false IsRiskyProcessing  # legal
    """None of the activities performed is likely to result to a high risk to the rights and freedoms of individual persons."""

assume false IsSpecialAuthorizedCriminalProcessing  # legal
    """We do not process criminal data."""

assume true IsStructuredFormat  # legal
    """We only use structured file formats (JSON) for output."""

assume false IsSubjectToProfessionalSecrecy  # functional
    """No entity is subject to the obligation of professional secrecy."""

assume false IsSupervisoryAuthorityStandardClauses  # functional
    """No transfers are taking place."""

assume false IsUnfoundedOrExcessive  # legal
    """We never qualify user requests as unfounded or excessive."""

assume false JustifiesStorage  # legal
    """No archiving is performed."""

assume false MakePublic  # functional
    """We never assume that a data subject makes their data public."""

assume false PrepareContract  # functional
    """No contracts are being concluded."""

assume false RefuseRequest  # functional
    """We never refuse requests."""

assume false RequestContractPreparation  # functional
    """No contracts are being concluded."""

assume false RequestExtension  # functional
    """We never request an extension."""

assume false RequestsNonElectronic  # functional
    """All requests are electronic."""

assume false StartContract  # functional
    """No contracts are being concluded."""

assume false Transfer  # legal
    """No transfers are taking place."""

assume true UndueDataDelay  # functional
    """We do not wait to delete data."""

assume true UndueDelay  # functional
    """We do not wait to inform users."""

assume false ValidRegisterConsultationRequest  # legal
    """No transfers are taking place."""

assume true DataIsNecessaryForJudicialClaims  # legal
    """We always take claims citing judicial reasons at face value."""

assume false DemonstrateOverridingCompellingGrounds  # functional
    """We never claim compelling groups that override the interests, rights, and freedoms of the data subject."""

assume false HasDataSubjectCategory  # legal
    """No activities are specific to a particular data subject category."""

assume false HasIntendedRecipientCategory  # legal
    """We have no intended recipient categories -- recipients are specified individually."""

assume false HasStatutoryContractualRequirement  # legal
    """No contracts are being concluded."""

assume false HasStoragePeriod  # legal
    """No storage period is defined. Data is kept until users delete their account."""

assume false HoldParentalResponsibility  # legal
    """Minors are not allowed to register to the service."""

assume false IsChild  # legal
    """Minors are not allowed to register to the service."""

assume true IsClearAndPlainLanguage  # legal
    """The text of all declarations is contained in this refinement file. They use clear and plain language."""

assume true IsConcise  # legal
    """The text of all declarations is contained in this refinement file. They are concise."""

assume true IsTransparentDeclaration  # legal
    """The text of all declarations is contained in this refinement file. They are transparent."""

assume false IsControllerRepresentative  # legal
    """We do not need controller representatives since all controllers considered are based in the Union."""

assume true IsDistinguishableFromOtherMatters  # legal
    """The text of all declarations is contained in this refinement file. They are independent and clearly distinguishable from other."""

assume true IsEasilyAccessible  # legal
    """The text of all declarations is contained in this refinement file. They are easily accessible."""

assume true IsIntelligible  # legal
    """The text of all declarations is contained in this refinement file. They are intelligible."""

assume true IsExplicit  # legal
    """The purposes (service, statistics, personalized_ad) are explicitly listed in the declaration at collection."""

assume false IsExtensionNecessary  # functional
    """We never claim that we need a time extension to process user requests."""

assume false IsLegitimateActivity  # legal
    """We never claim a legitimate activity with respect to a controller with a political, philosophical, religious, or trade union aim."""

assume true IsOfferOfInformationSocietyServices  # functional
    """GDPRSocial, Inc. provides information society services."""

assume true IsReasonForRequestExtension  # functional
    """Irrelevant since we never extend requests."""
    
assume true IsReasonForRequestRefusal  # functional
    """Irrelevant since we never refuse requests."""

assume true IsReceptionSource  # legal
    """Irrelevant since we never receive data from other sources."""

assume true IsRespected  # legal
    """The storage criteria are respected as users' data is deleted when their accounts are."""

assume true IsRisksOfTransfer  # legal
    """Irrelevant since no transfers are taking place."""

assume true IsSpecified  # legal
    """The purposes (service, statistics, personalized_ad) are specified in the declaration at collection."""

assume true IsTransfer  # legal
    """Irrelevant since no transfers are taking place."""

assume true IsTransferBasis  # legal
    """Irrelevant since no transfers are taking place."""
    
assume false IsUnableToConsent  # functional
    """When creating an account, users must self-certify that they are physically and legally able to consent."""

assume true ReportLastResortTransfer  # legal
    """Irrelevant since no transfers are taking place."""

assume false Stored  # legal
    """Irrelevant since IsNecessary is true."""

assume false TechnicalAndOrganisationalMeasures  # legal
    """We do not claim any technical and organizational measures for archival purposes."""

assume false UseForCommunication  # functional
    """Irrelevant since we never delay informing users."""

assume false ConsentDeclarationContainsOtherMatters  # legal
    """Consent declarations never contain other matters."""

assume true IsNewPurpose  # legal
    """Irrelevant since Article 13(3) is replaced by rule no_new_purpose."""

assume false IsStorage  # legal
    """We never assume that an activity is only a storage activity."""

assume false IsFurtherCopy  # functional
    """We always assume that copies are not duplicates. As a result, no fee is to be paid."""

assume true IsFair  # legal
    """The automated enforcement of the GDPR requirements ensures fairness with respect to the user. Only strictly necessary data is used for each purpose."""

assume true IsTransparent  # legal
    """The automated enforcement of the GDPR requirements, in particular the ROPA logging mechanism, ensures transparency with respect to the user."""

assume true EnsuresAppropriateSecurity  # legal
    """GDPRSocial, Inc. uses a safe software stack to guarantee personal data security."""

assume true IsAdequate  # legal
    """The personal data processed by GDPRSocial, Inc. is adequate for each declared purpose: (1) for the 'service' purpose, user profile data (name, email), twits, replies, direct messages, follows, likes, and reposts are adequate to provide core social-networking functionality; (2) for the 'personalized_ad' purpose, twit content and page visit data are adequate to select relevant advertisements via TF-IDF content matching; (3) for the 'statistics' purpose, page visit timestamps and anonymised interaction counts are adequate to generate website analytics."""

assume true IsLimitedToWhatIsNecessary  # legal
    """Data collection is limited to what is strictly necessary for each purpose: (1) for the 'service' purpose, only the minimal profile fields (username, first name, last name, email) and user-generated content (twits of at most 140 characters, replies, direct messages) are collected; (2) for the 'personalized_ad' purpose, only the textual content of the currently displayed page is used for TF-IDF similarity matching — no browsing history, location data, or third-party tracking is employed; (3) for the 'statistics' purpose, only page visit records (URL, timestamp) are collected. No surplus personal data is gathered beyond what each purpose requires."""

assume true IsNecessary  # legal
    """Each category of personal data processed is necessary for its declared purpose: (1) user profile data is necessary to authenticate users and display authored content; (2) twit content, replies, reposts, likes, and follows are necessary to deliver the core social-networking service; (3) direct messages are necessary to enable private communication between users; (4) page visit data is necessary to compute website usage statistics; (5) twit content exposure to the ad recommender is necessary to select contextually relevant advertisements. None of these purposes can be fulfilled without processing the respective data."""

assume true IsRelevant  # legal
    """All personal data processed is directly relevant to its declared purpose: profile fields are relevant to user identification and account management; user-generated content (twits, replies, reposts, direct messages) is relevant to providing the social-networking service; textual content shown on pages is relevant to selecting personalized advertisements; and page visit records are relevant to generating website usage statistics. No data is collected that lacks a direct relationship to one of the declared purposes."""

assume true IsUpToDate  # legal
    """Personal data is kept up to date through the following mechanisms: (1) users can edit their profile information (name, email) at any time via the account settings page; (2) twit content can be edited by its author, which updates the 'updated_on' timestamp; (3) users may request rectification of any inaccurate data under Article 16 GDPR, which is enforced automatically by the system; (4) ad recommendations are recomputed on each page load using the latest content, ensuring no stale data influences personalisation; (5) every reasonable step is taken to ensure that inaccurate data is erased or rectified without delay."""

note "### Refinement to system events ###"

rule "r_IsCompatibleWithPurpose"
    whenever
        (p = "service" AND p' = "service") OR (p = "personalized_ad" AND p' = "personalized_ad") OR (p = "statistics" AND p' = "statistics")
    refine
        IsCompatibleWithPurpose(p, p')

rule "r_AutomatedDecision"
    """The only form of automated decision-making / profiling taking place concerns the selection of personalized ads. Otherwise, no profiling occurs."""
    whenever
        Read(d, ds, a, "personalized_ad", ds') OR Write(d, ds, a, "personalized_ad", ds')
    refine
        AutomatedDecision(a, d, ds', "We use the content of the page shown to the user to display personalized advertisement")

rule "r_CheckNotChild"
    """Users must upload a copy of their ID when registering, which is then semi-automatically vetted. Users below the age of 16 are not allowed to register. Hence, any user in hte system is at least 16. This fulfills our due diligence obligation."""
    whenever
        true
    refine
        CheckNotChild("GDPRSocial, Inc.", ds)

rule "r_ContestsAccuracy"
    whenever
        ContestAccuracy(ds, d, d')
    refine
        Request(ds, "", "GDPRSocial, Inc.")
        ContestsAccuracy("", d, d')

rule "r_DataProcessing"
    whenever
        (EXISTS ds'. Read(d, ds, a, p, ds')) OR (EXISTS ds'. Write(d, ds, a, p, ds')) OR Collect(a, d, ds, p)
    refine
        DataProcessing("GDPRSocial, Inc.", "GDPRSocial, Inc.", a, d)

rule "r_DataReview"
    whenever
        DailyErasureReview(d)
    refine
        DataReview("GDPRSocial, Inc.", d)

rule "r_Disclose"
    whenever
        Read(d, ds, a, p, ds')
    refine
        Disclose(d, ds')

rule "r_GiveConsent"
    whenever
        Consent(ds, p) OR (EXISTS sp. SpecialConsent(ds, p, sp))
    refine
        GiveConsent(ds, p, "GDPRSocial, Inc.")

rule "r_GiveSpecialConsent"
    whenever
        SpecialConsent(ds, p, sp)
    refine
        GiveSpecialConsent(ds, p, "GDPRSocial, Inc.", sp)

rule "r_WithdrawSpecialConsent"
    whenever
        SpecialRevoke(ds, p, sp)
    refine
        WithdrawSpecialConsent(ds, p, "GDPRSocial, Inc.", sp)
	
rule "r_IsRectificationRequest"
    whenever
        RequestRectification(ds, d, d', rq)
    refine
        Request(ds, rq, "GDPRSocial, Inc.")
        IsRectificationRequest(rq, d, d')
        HasInaccuracy(d)

rule "r_IsErasureRequest"
    whenever
        RequestErasure(ds, d, rq)
    refine
        Request(ds, rq, "GDPRSocial, Inc.")
        IsErasureRequest(rq, d)

rule "r_HasIntendedAutomatedDecision"
    whenever
        Collect(a, d, ds, "personalized_ad")
    refine
        HasIntendedAutomatedDecision(d, "We use the content of the page shown to the user to display personalized advertisement")

rule "r_HasIntendedRecipient"
    whenever
        Collect(a, d, ds, "statistics")
    refine
        HasIntendedRecipientCategory(d, "Analytics, Inc.")

rule "r_HasPurpose"
    whenever
        (EXISTS ds'. Read(d, ds, a, p, ds')) OR (EXISTS ds'. Write(d, ds, a, p, ds')) OR Collect(a, d, ds, p)
    refine
        HasPurpose(a, p)

rule "r_HasRegularContact"
    whenever
        true
    refine
        HasRegularContact(d, "GDPRSocial, Inc.")

rule "r_HasSecurityMeasuresDeclaration"
    whenever
        true
    refine
        HasSecurityMeasuresDeclaration(a, "GDPRSocial, Inc. implements the following technical and organisational security measures: (1) all web traffic is served over HTTPS/TLS; (2) user passwords are stored using Django's PBKDF2-SHA256 hashing with per-user salts; (3) CSRF protection is enforced on all state-changing requests; (4) access control ensures users can only modify their own data; (5) the proactive GDPR enforcement engine automatically prevents policy-violating data processing at runtime; (6) personal data deletion is available on demand via the right-to-erasure mechanism.")
	
rule "r_HasStorageCriteria"
    whenever
        true
    refine
        HasStorageCriteria(d, "Your data is stored until you delete your account")

rule "r_IsAbleToDemonstrateConsent"
    """The presence of the Consent event in the trace demonstrates consent."""
    whenever
        (ONCE Consent(ds, p)) OR (EXISTS sp. ONCE SpecialConsent(ds, p, sp))
    refine
        IsAbleToDemonstrateConsent("GDPRSocial, Inc.", ds, p)

rule "r_IsAccessRequest"
    whenever
        RequestAccess(ds, rq)
    refine
        Request(ds, rq, "GDPRSocial, Inc.")
        IsAccessRequest(rq)

rule "r_IsInAccurate"
    """Data is assumed to be accurate unless their owner has contested its accuracy."""
    whenever
        RequestRectification(ds, d, d', rq)
    refine
        IsInaccurate(d, p)

rule "r_IsAutomatedDecision"
    whenever
        Declaration(d)
        HasText(d, "<h6>Automated decision-making</h6><p>We use the content of your latest posts to display personalized advertisement. No human review is involved in this decision.</p>")
    refine
        IsAutomatedDecision(d)

rule "r_IsAutomatedDecisionMakingPurpose"
    whenever
        true
    refine
        IsAutomatedDecisionMakingPurpose("personalized_ad")

observable causable event NoteCategory
    cat : special_data_category

rule "r_IsCategory"
    whenever
        Declaration(d)
        HasText(d, "<h6>Special categories of personal data</h6><p>Some of the personal data we process belongs to the following special category as defined in Article 9 GDPR: " + string_of_category(cat) + ".</p>")
        NoteCategory(cat)	
    refine
        IsCategory(d, cat)

rule "r_IsCollection"
    whenever
        Collect(a, d, ds, p)
    refine
        IsCollection(a, ds)

function string_of_request(
    c : request
) -> string

observable causable event NoteRequest
    rq : request

rule "r_IsComplaintStatement"
    whenever
        Declaration(d)
        HasText(d, "<h6>Right to lodge a complaint</h6><p>You have the right to lodge a complaint with the competent National Data Protection Authority regarding request " + string_of_request(rq) + ". You may do so without prejudice to any other administrative or judicial remedy.</p>")
        NoteRequest(rq)	
    refine
        IsComplaintStatement(d, rq)

observable causable event NoteEntity
    e : entity

rule "r_IsContactDetailsOfDataProtectionOfficer"
    whenever
        Declaration(d)
        HasText(d, "<h6>Contact details of the Data Protection Officer</h6><p>You can contact our Data Protection Officer at: " + string_of_entity(c) + ". The DPO can be reached for any queries related to the processing of your personal data or the exercise of your rights.</p>")
        NoteEntity(c)
    refine
        IsContactDetailsOfDataProtectionOfficer(d, c)

function string_of_ds(
    ds : data_subject
) -> string

observable causable event NoteDS
    ds : data_subject

rule "r_IsDSSource"
    whenever
        Declaration(d)
        HasText(d, "<h6>Source of your personal data</h6><p>We have collected this personal data from " + string_of_ds(ds) + ".</p>")
        NoteDS(ds)
    refine
        IsDSSource(d, ds)

rule "r_IsDataProcessingNotOngoing"
    whenever
        Declaration(d)
        HasText(d, "<h6>Processing status</h6><p>We are not currently processing your personal data.</p>")
    refine
        IsDataProcessingNotOngoing(d)
	
rule "r_IsDataProcessingOngoing"
    whenever
        Declaration(d)
        HasText(d, "<h6>Processing status</h6><p>We are currently processing your personal data. You may exercise your rights regarding this processing as described in the applicable privacy notice.</p>")
    refine
        IsDataProcessingOngoing(d)

rule "r_IsDataProcessingOfficer"
    whenever
        c = "GDPRSocial, Inc."
        c' = "dpo@gdprsocial-inc.com"
    refine
        IsDataProtectionOfficer(c, c')

rule "r_IsDirectMarketing"
    whenever
        p = "personalized_ad"
    refine
        IsDirectMarketing(p)

rule "r_IsDirectTransmissionFeasible"
    whenever
        true
    refine
        IsDirectTransmissionFeasible("GDPRSocial, Inc.", x)

rule "r_IsEffectiveRecipient"
    whenever
        Declaration(d)
        HasText(d, "<h6>Recipients of your personal data</h6><p>Your personal data has been shared with the following entity: " + string_of_entity(e) + ".</p>")
        NoteEntity(e)	
    refine
        IsEffectiveRecipient(d, e)

rule "r_IsIdentityOfControllerOrRepresentative"
    whenever
        Declaration(d)
        HasText(d, "<h6>Identity of the controller</h6><p>The controller responsible for the processing of your personal data is " + string_of_entity(c) + ".</p>")
        NoteEntity(c)
    refine
        IsIdentityOfControllerOrRepresentative(d, c)

function string_of_legal_basis(
    b : legal_basis
) -> string

causable observable event NoteLegalBasis
    b : legal_basis

observable causable event NotePurpose
    p : purpose

rule "r_IsLegalBasisOfProcessing"
    whenever
        Declaration(d)
        HasText(d, "<h6>Legal basis for the processing: Article " + string_of_legal_basis(b) + "</h6><p>We rely on Article " + string_of_legal_basis(b) + " of the General Data Protection Regulation (GDPR) as a legal basis to process your personal data.</p>")
        NoteLegalBasis(b)
    refine
        IsLegalBasisOfProcessing(d, b)

rule "r_IsPurposeOfProcessing"
    whenever
        Declaration(d)
        p = "service" IMPLIES HasText(d, "<h6>Processing for strictly necessary purposes</h6><p>We process your data to provide GDPRSocial's essential functionality.</p>")
        p = "personalized_ad" IMPLIES HasText(d, "<h6>Processing for advertisement purposes</h6><p>We process your data to show you personalized advertisement.</p>")
        p = "statistics" IMPLIES HasText(d, "<h6>Processing for statistical purposes</h6><p>We process your data to generate website statistics and analytics.</p>")
        NotePurpose(p)	
    refine
        IsPurposeOfProcessing(d, p)

rule "r_IsLegitimate"
    whenever
        p = "service" OR p = "personalized_ad" OR p = "statistics"
    refine
        IsLegitimate(p)

function string_of_interest(
    i : interest
) -> string

causable observable event NoteInterest
    i : interest

rule "r_IsLegitimateInterest"
    whenever
        Declaration(d)
        HasText(d, "<h6>Legitimate interest</h6><p>" + string_of_entity(e) + " relies on the following legitimate interest as the legal basis for processing your personal data: " + string_of_interest(i) + ". You have the right to object to processing based on legitimate interest at any time.</p>")
        NoteEntity(e)	
        NoteInterest(i)	
    refine
        IsLegitimateInterest(d, e, i)
	
rule "r_IsNecessaryForLegitimateInterest"
    whenever
        (EXISTS ds'. Read(d, ds, a, p, ds')) OR (EXISTS ds'. Write(d, ds, a, p, ds')) OR Collect(a, d, ds, p)
        p = "service"
    refine
        IsNecessaryForLegitimateInterest(a, "GDPRSocial, Inc.", "Providing the service and performing GDPRSocial's normal operations.")

rule "no_new_purpose"
    whenever
        EXISTS pr. DataProcessing(pr, c, a, d)
        PersonalData(d, ds)
        HasPurpose(a, p)
    oblige
        ONCE (EXISTS co, pr'. DataProcessing(pr', c, co, d) AND IsCollection(co, ds) AND HasPurpose(co, p))
    transparently enforceable suppressing condition[0]

replace
    strengthen
        article "13" paragraph "3"
    by
        rule "no_new_purpose"

rule "r_IsOverriddenByDataSubjectInterests"
    whenever
        (EXISTS ds'. Read(d, ds, a, p, ds')) OR (EXISTS ds'. Write(d, ds, a, p, ds')) OR Collect(a, d, ds, p)
        NOT (p = "service")
    refine
        IsOverriddenByDataSubjectInterests(c, i, ds)

rule "r_IsRecipient"
    whenever
        Declaration(d)
        HasText(d, "<h6>Recipients of your personal data</h6><p>We intend to share your personal data with the following entity: " + string_of_entity(e) + ".</p>")
        NoteEntity(e)	
    refine
        IsRecipient(d, e)

rule "r_IsRecipientCategory"
    whenever
        Declaration(d)
        HasText(d, "<h6>Categories of recipients</h6><p>We intend to share your personal data with the following categories of entities: " + string_of_entity(e) + ".</p>")
        NoteEntity(e)
    refine
        IsRecipientCategory(d, e)

rule "r_IsRecipientRequest"
    whenever
        RequestRecipientInformation(ds, rq)
    refine
        Request(ds, rq, "GDPRSocial, Inc.")
        IsRecipientRequest(rq)

function string_of_data(
    d : data_id
) -> string

observable causable event NoteData
    d : data_id

rule "r_IsRestrictionToBeLifted"
    whenever
        Declaration(d)
        HasText(d, "<h6>Lifting of processing restriction</h6><p>The restriction on the processing of data " + string_of_data(data) + ", imposed in response to request " + string_of_request(rq) + ", is to be lifted. Processing of the concerned data may resume from this point.</p>")
        NoteData(data)
        NoteRequest(rq)
    refine
        IsRestrictionToBeLifted(d, data, rq)

rule "r_IsRightToLodgeComplaint"
    whenever
        Declaration(d)
        HasText(d, "<h6>Right to lodge a complaint</h6><p>You have the right to lodge a complaint with the competent National Data Protection Authority if you consider that the processing of your personal data infringes the GDPR, without prejudice to any other administrative or judicial remedy.</p>")
    refine
        IsRightToLodgeComplaint(d)

rule "r_IsRightToWithdrawConsent"
    whenever
        Declaration(d)
        HasText(d, "<h6>Right to withdraw consent</h6><p>You have the right to withdraw consent for processing your data at any time.</p>")
    refine
        IsRightToWithdrawConsent(d)

rule "r_IsRights"
    whenever
        Declaration(d)
        HasText(d, "<h6>Your rights as a data subject</h6><ul><li>You have the right to request access to, rectification of, or erasure of your personal data, or restriction of processing (Articles 15–18 GDPR).</li><li>You have the right to receive your personal data in a structured, commonly used, and machine-readable format and to transmit it to another controller (right to data portability, Article 20 GDPR).</li><li>You have the right to object to automated decision-making, including profiling (Article 22 GDPR).</li></ul>")
    refine
        IsRights(d)

rule "r_IsSME"
    whenever
        true
    refine
        IsSME("GDPRSocial, Inc.")

function string_of_criteria(
    c : criteria
) -> string

observable causable event NoteCriteria
    c : criteria

rule "r_IsStorageCriteria"
    whenever
        Declaration(d)
        HasText(d, "<h6>Storage criteria</h6><p>The criteria used to determine the period for which your personal data will be stored are: " + string_of_criteria(c) + ".</p>")
        NoteCriteria(c)
    refine
        IsStorageCriteria(d, c)

observable causable event NoteSpan
    s : span

rule "r_IsStoragePeriod"
    whenever
        Declaration(d)
        HasText(d, "<h6>Storage period</h6><p>Your personal data will be stored for the following period: " + string_of_span(c) + ".</p>")
        NoteSpan(c)
    refine
        IsStoragePeriod(d, c)

# Note: The wildcard _ is used for the notification identifier, as notifications are not individually tracked.
rule "r_NotifyOfErasure"
    whenever
        NotifyErasure(e, d)
    refine
        NotifyOfErasure(_, e, d)

rule "r_NotifyOfRectification"
    whenever
        NotifyRectification(e, d, d')
    refine
        NotifyOfRectification(_, e, d, d')

rule "r_NotifyOfRestriction"
    whenever
        NotifyRestriction(e, d, p)
    refine
        NotifyOfRestriction(_, e, d, p)

rule "r_Object"
    whenever
        RequestObjection(ds, p, de, rq)
    refine
        Object(ds, "GDPRSocial, Inc.", p, de)

rule "r_Record"
    whenever
        ActivityRecord(a, p, v)
    refine
        Record(_, _, a, p, v)

rule "r_Share"
    whenever
        Send(e, d)
    refine
        Share("GDPRSocial, Inc.", e, d)

rule "r_Tranmit"
    whenever
        SendFile(e, f)
    refine
        Transmit(_, e, f)

rule "r_WithdrawConsent"
    whenever
        Revoke(ds, p)
    refine
        WithdrawConsent(ds, p, "GDPRSocial, Inc.")


rule "r_accuracy_deletion_new"
    whenever
        IsInaccurate(d, p)
        ONCE (EXISTS c, ds'. DataProcessing(pr, co, c, d) AND IsCollection(c, ds') AND HasPurpose(c, p))
    oblige
        (NOT UndueDataDelay(d)) UNTIL Delete(d)
    transparently enforceable causing effects

replace
    strengthen
        article "5" paragraph "1" point "d" rule "accuracy_deletion"
    by
        rule "r_accuracy_deletion_new"

rule "r_portability_new"
    whenever
        ONCE (Request(ds, rq, c) AND IsPortabilityRequest(rq) AND SpecifiesNewController(rq, c'))
        RequestResponse(ds, rq, rs)
        ContainsData(rs, f)
    oblige
        Transmit(c, c', f)
    enforceable causing effects

replace
    strengthen
        article "20" paragraph "2"
    by
        rule "r_portability_new"

note "### Not refined ###"
	        
# Contains
# ContainsData
# Delete
# HasCategory
# Inform
# Category
# IsConsentRequest
# IsErasureRequest
# IsFurtherCopy
# IsNecessaryForPublicInterest
# IsHealthRelated
# IsNecessaryForImportantPublicInterest
# IsNecessaryForJudicialClaims
# IsNecessaryForLegalObligation
# IsNecessaryForProtectionOfRights
# IsNecessaryForSpecialMedicalReasons
# IsNecessaryForSubstantialPublicInterest
# IsNecessaryForVitalInterests
# IsSpecialData
# LiftRestriction
# RelatesToCriminalConvictionsOrOffences
# SpecifiesNewController
# PersonalData
# PersonalDataCopy
# Rectify
# RequestResponse
# Stored
# TP

note "END."
