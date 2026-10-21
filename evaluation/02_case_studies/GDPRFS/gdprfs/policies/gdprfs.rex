refine gdpr

# 2. the type is either already defined in gdpr.lex or should be defined in this rex file.
type user_id  is string
type file_id  is string
#for the GDPR rules (gdpr.lex) art5
type activity_id is string
type decl_id     is string
type request_id  is string


# 1. observable, suppressable or causable events, defined in .sig file
#observable := The system sees this event, logs it, but it cannot block or create it.
#suppressable := If a rule is violated, then Lex can suppress (block) this event.
#causable := If system does not do this event, then the monitor can CAUSE (emit) it.

observable event StartSession
  inUid  : user_id
  p      : purpose
  reason : string

observable event StopSession
  inUid  : user_id

suppressable event Use
  fid   : file_id
  exUid : user_id

suppressable event Write
  fid : file_id
  p     : purpose

observable event Consent
  exUid : user_id
  p     : purpose

observable event Collect
  fid   : file_id
  exUid : user_id

observable event Revoke
  exUid : user_id
  p     : purpose

observable event SpecialData
  fid : file_id
  spCat : special_data_category

observable event SpecialConsent
    exUid : user_id
    p : purpose
    spCat : special_data_category

observable event RevokeSpecialConsent
    exUid : user_id
    p : purpose
    spCat : special_data_category

observable event RequestAccess
  exUid : user_id

observable event RequestErasure
  exUid : user_id
  fid   : file_id

observable event RequestRectification
  exUid : user_id
  fid_old : file_id
  fid_new : file_id

observable event UseNonPII
  fid   : file_id
  exUid : user_id

#3. refine the types of events in order to connect to GDPR rules (gdpr.lex)
refine type data_subject  is user_id
refine type data          is file_id #.sig file's fid is considered as `data` in gdpr.lex art5 
#for the GDPR rules (gdpr.lex) art5
refine type activity      is activity_id
refine type entity        is string # controller/processor are both string constants in gdpr.lex
refine type declaration  is decl_id
refine type criteria     is string
refine type request      is request_id
refine type interest     is string
refine type special_data_category is string

#4. define refinement rules
#The refinement can only use the variables used in `whenever` part.
# refine := replace an abstract event of the GDPR law (eg: DataProcessing event) by a concrete event of the system (Use event).

#for art5a's obligations
rule "r_PersonalData_Use"
  whenever
    Use(d, ds) #or Collect(d, ds)
  refine
    PersonalData(d, ds) 

rule "r_PersonalData_Collect"
  whenever
    Collect(d, ds)
  refine
    PersonalData(d, ds)

assume true IsFair
  """data is processed fairly whenever it is used by an activity/event (art5a)"""

assume true IsTransparent
  """the way data is processed/used is transparent to the ds (art5a)"""

#a read and a write are both DataProcessing
#art5a(l159) is triggered by both DataProcessing(l39) and PersonalData(l34) events
rule "r_DataProcessing_Use"
  whenever
    Use(d, _)
  refine
    DataProcessing("GDPRFS", "GDPRFS", "Use", d) #l39 #"Use" activity because gdpr.lex l42: Data d is processed by processor "GDPRFS" on behalf of controller "GDPRFS" as part of data processing activity "Use"
#or
rule "r_DataProcessing_Write"
  whenever
    Write(d, _)
  refine
    DataProcessing("GDPRFS", "GDPRFS", "Use", d) #l39 #Write also counts as data processing

#Use refines to DataProcessing. i.e. Use replaces DataProcessing event.
#this rule is a translator from the system events of FS (computer) to the GDPR law (juridical). 
#Whenever the system sees a `Use` event, it is translated to a `DataProcessing` event in the GDPR sense.

#art5b rule "must_have_purpose" (l157)
#DataProcessing event has been refined; PersonalData predicate is assumed; HasPurpose predicate is refined.

rule "r_HasPurpose" #gdpr.lex l67: Data processing activity a has purpose p
  whenever
    Use(d, ds) #see rule "r_DataProcessing": Data processing = Use event
    NOT StopSession(inUid) SINCE (EXISTS p, reason. StartSession(inUid, p, reason)) #must use StartSession event in order to have the purpose `p` in the refinement of HasPurpose predicate.
    ONCE (EXISTS reason. StartSession (inUid, p, reason))
    #a session has started, and not yet stopped. := the same session
    # this session has this event Use.
  refine
    HasPurpose("Use", p) #"Use" activity because gdpr.lex l67: Data processing activity "Use" has purpose p

# r_HasPurpose is also for art5b rule "purpose_conditions" (l183)
#because gdpr.lex's rule "purpose_conditions" is triggered by HasPurpose event, i.e.
#"Whenever HasPurpose exists => check these (gdpr.lex l187-189) obligations."

#for art5b rule "purpose_conditions"'s obligations (l183)
assume true IsSpecified
  """Purpose is specified whenever a data d is processed/used (art5b rule purpose_conditions)"""

assume true IsExplicit
  """Purpose is explicit whenever a data d is processed/used (art5b rule purpose_conditions)"""

#Purpose is legitimate if it is marketing, service or analytics
rule "r_IsLegitimate"
    whenever
        p = "marketing" OR p = "service" OR p = "analytics"
    refine
        IsLegitimate(p)

#art5b rule "purpose_limitation" (l192)
#l60 so we use a Collect event
rule "r_IsCollection"
    whenever
        Collect(d, ds)
    refine
        IsCollection("Collect", ds) #"Collect" activity because gdpr.lex l63: """Data processing activity Collect collects personal data from data subject {ds}"""
# Collect event refines to IsCollection event. i.e. Collect replaces IsCollection event.

#art5b rule "general_purpose"
assume true IsCompatibleWithPurpose
  """The data processing activity is compatible with purpose """

#art5b rule "archiving_purpose"
assume false IsArchival
  """No archiving purposes in the public interest (eg: long‑term preservation for public‑interest, historical or scientific research) is performed."""

#art5c 
assume true IsAdequate
  """Data d processed or collected is enough in quantity and quality to fulfil purpose p, but not more than that."""

assume true IsRelevant
  """Only data d that is relevant to purpose p are processed."""

assume true IsLimitedToWhatIsNecessary
  """The system must not process or collect more personal data than is strictly needed to achieve purpose p."""

#art5d rule "accurate_and_up_to_date"

#Write event but not Use event, because "Data must be accurate and, where necessary, kept up to date." i.e. "If data is inaccurate, Then we must correct it."
#it's an limitation: no Writes yet when we first Read the files
assume true IsAccurate
assume true IsUpToDate

#art5d rule "accuracy_deletion"
assume false UndueDataDelay
    """We do not wait to delete data."""

#Whenever a file fid is written (i.e. updated),
#the old data in `fid` is rectified to the new data in `fid`.

#so every write operation counts as correcting the data.

### unrefine Rectify ###

#art5e rule "temporal_storage_limitation"

#Data is stored when: it exists on disk, and it has not been deleted.
# so treat `Write(d,p)` as implying data is stored
rule "r_Stored"
  whenever
    Write(d, p)
    NOT Delete(d) SINCE Write(d, p) #Delete(d) is used as a condition check, not as a trigger for a request.
  refine
    Stored(d)

assume true IsNecessary

#art5e rule "storage_limitation_exception"
assume false TechnicalAndOrganisationalMeasures
    """We do not claim any technical and organizational measures for archival purposes."""

assume false JustifiesStorage
    """No archiving is performed."""

#art5f
assume true EnsuresAppropriateSecurity
  """We protect personal data d when processing it by appropriate technical and organisational security measures"""

#art6.1.a
rule "r_GiveConsent"
    whenever
        Consent(ds, p)
    refine
        GiveConsent(ds, p, "GDPRFS")
# Consent event refines to GiveConsent event. i.e. Consent replaces GiveConsent event.

#art6.1.b
assume false EndContract
    """No contracts are being concluded."""
assume false PrepareContract
    """No contracts are being concluded."""
assume false StartContract
    """No contracts are being concluded."""
assume false IsContractParty
    """No contracts are being concluded."""
assume false IsNecessaryForContract
    """No contracts are being concluded."""

#art6.1.c
assume false IsNecessaryForLegalObligation
    """This FileSystem does not process data due to legal obligations."""

#art6.1.d
assume false IsNecessaryForVitalInterests
    """This FileSystem does not process data to protect the vital interests of data subjects. 
    vital interests := medical data in an emergency to save someone's life.
    This FileSystem only have p = "marketing", "service" or "analytics" purposes, but no p = "emergency"."""

#art6.1.e
assume false IsNecessaryForPublicInterest
    """No public interest is involved in the data processing activities of this FileSystem."""
assume false IsPerformanceOfPublicAuthorityTask
    """Data processing activities of this FileSystem are not part of the performance of a public authority task."""
assume false IsPublicAuthority
    """This FileSystem is not a public authority."""

#art6.1.f
rule "r_LegitimateInterest"
  whenever
    Use(d, ds)
    NOT StopSession(inUid) SINCE StartSession(inUid, p, reason)
    p = "service"
  refine
    IsNecessaryForLegitimateInterest("Use", "GDPRFS", "Providing the service and performing the filesystem's normal operations.")

rule "r_IsOverriddenByDataSubjectInterests"
    whenever
        Use(d, ds)
        NOT StopSession(inUid) SINCE StartSession(inUid, p, reason)
        NOT (p = "service")
    refine
        IsOverriddenByDataSubjectInterests("GDPRFS", "ds's interests", ds)

#art6.2
#already refined previously.

#art9
#para1
rule "r_IsSpecialData"
  whenever
    SpecialData(d, spCat)
  refine
    IsSpecialData(d, spCat)

#para2a
rule "r_GiveSpecialConsent"
    whenever
        NOT RevokeSpecialConsent(ds, p, spCat) SINCE SpecialConsent(ds, p, spCat)
    refine
        GiveSpecialConsent(ds, p, "GDPRFS", spCat)

#para2b
assume false IsNecessaryForEmploymentLaw
    """We do not consider this legal basis."""

#para2c
assume false IsUnableToConsent
    """Users (data subjects) can explicitly give consent, so is able to consent."""

#para2d
#The file system has safeguards (stripping data of a file) to protect the fundamental rights and interests of data subjects.
#safeguard in this FS := If ds doesn’t consent, and file contains multiple data subjects including this ds', Then strip data of the one who hasn't consented yet.

#Whenever we process data of ds AND ds has consented and hasn't revoked consent,
# so safeguards are in place.
rule "r_Safeguards"
  whenever
    Use(d, ds)
    NOT Revoke(ds, p) SINCE Consent(ds, p)
  refine
    ImplementFundamentalRightsSafeguards("Use", ds)

# legitimate activities := normal operations directly tied to the organisation's political, philosophical, religious, or trade union aims
assume false IsLegitimateActivity
    """We never claim a legitimate activity with respect to a controller with a political, philosophical, religious, or trade union aim."""

assume false HasRegularContact
    """We do not have regular contact with data subjects in relation to our legitimate activities."""

assume false IsNonProfit
    """No non-profit controller is involved."""

assume false HasPoliticalAim
    """No controller has a political aim."""

assume false HasPhilosophicalAim
    """No controller has a philosophical aim."""

assume false HasReligiousAim
    """No controller has a religious aim."""

assume false HasTradeUnionAim
    """No controller has a trade union aim."""

assume false IsMember
    """No membership of a political party, a philosophical organization, a religious organization or a trade union."""

assume false IsOutsideDisclosure
    """We do not share or transmit data to entities or people outside the controller GDPRFS's organisation without the data subject's consent."""

#para2e
assume false MakePublic
    """We never assume that a data subject makes their data public."""

#para2f
assume false IsNecessaryForJudicialClaims
    """processing activity is not necessarily required for legal proceedings, court cases, or judicial functions."""

#para2g
assume false IsNecessaryForSubstantialPublicInterest
    """processing activity is not necessarily required for reasons of substantial public interest, on the basis of Union or Member State law."""

#para2h
assume false IsNecessaryForSpecialMedicalReasons
    """processing activity is not necessarily required for the purposes of preventive or occupational medicine, 
       for the assessment of the working capacity of the employee, medical diagnosis, the provision
       of health or social care or treatment or the management of health or social care systems and 
       services on the basis of Union or Member State law or pursuant to contract with a health professional."""

#para2i
assume false IsHealthRelated
    """Public interest pi is not specifically related to the public health protection, and is not necessarily backed by EU or Member State law that mandates professional secrecy and data subject safeguards."""

#para2j
assume false IsNecessaryForArchivalPurposes
    """No archiving is performed."""

#para3
assume false IsSubjectToProfessionalSecrecy
    """No entity is subject to the obligation of professional secrecy."""

#art15
#para1

rule "r_IsAccessRequest"
  whenever
    RequestAccess(ds)
  refine
    Request(ds, "access", "GDPRFS")
    IsAccessRequest("access")

note "### unrefine RequestResponse and Contains ###"
assume true IsDataProcessingOngoing
    """IsDataProcessingOngoing is a causable event"""

assume true IsDataProcessingNotOngoing
    """IsDataProcessingNotOngoing is a causable event"""

assume true IsPurposeOfProcessing
    """IsPurposeOfProcessing is a causable event"""

assume false HasCategory 
    """No data categories are tracked by this FileSystem."""

#IsCategory unrefined
# create Category event, then refine IsCategory event

assume false HasIntendedRecipient

# a declaration := a formal statement included in the controller’s response to a request.
assume true IsRecipient
    """IsRecipient is a causable event. The declaration always declares the intended recipient of the data."""

assume false HasIntendedRecipientCategory
    """no recipient category"""

assume true IsRecipientCategory
    """IsRecipientCategory is a causable event. The declaration always declares the category of the intended recipient of the data."""

assume false HasStoragePeriod
    """No storage period is defined. Data is kept until users request to erase their data (RequestErasure)."""

assume true IsStoragePeriod
    """IsStoragePeriod is a causable event. The declaration always declares the storage period of the data."""

rule "r_HasStorageCriteria"
    whenever
        true
    refine
        HasStorageCriteria(d, "Data is stored until the user requests to erase their data (RequestErasure).")

assume true IsStorageCriteria
    """IsStorageCriteria is a causable event. The declaration always declares the storage criteria of the data."""

#art15.e
assume true IsRights
    """IsRights is a causable event."""

#art15.f
assume true IsComplaintStatement
    """IsComplaintStatement is a causable event. The declaration always declares the statement of the data subject's right to lodge a complaint with a supervisory authority regarding the access request."""

assume false IsReception
    """We do not receive data from other entities."""

assume true IsReceptionSource
    """Irrelevant since we never receive data from other sources."""

assume true IsDSSource
    """The data subject source is declared in the response to data subject's access request, if applicable."""

#art15.h
rule "r_HasIntendedAutomatedDecision"
    whenever
        Collect(d, ds)
    refine
        HasIntendedAutomatedDecision(d, "We use user data to have personalized advertisement to them.")

assume true IsAutomatedDecision
    """IsAutomatedDecision is a causable event."""

#para2
assume false HasIntendedTransfer
    """We do not transfer data to other entities."""

assume true IsTransfer
    """Irrelevant since no transfers are taking place."""

assume true IsTransferBasis
    """Irrelevant since no transfers are taking place."""

#para3
assume true ContainsData
    """Declaration contains data file."""

assume true PersonalDataCopy
    """PersonalDataCopy is a causable event."""

assume true IsCommonlyUsedFormat
    """We use structured file formats (txt, pdf, odt)."""

assume false IsFurtherCopy
    """No request is considered a further copy request."""

assume true IsPurposeOfProcessing
    """The declaration always declares the purpose of processing."""

#art15 linked to art12 
#art12 has art7's events
assume true IsEasilyAccessible
    """The text of all declarations is contained in this refinement file. They are easily accessible."""

assume true IsIntelligible
    """The text of all declarations is contained in this refinement file. They are intelligible."""

assume true IsClearAndPlainLanguage
    """The text of all declarations is contained in this refinement file. They use clear and plain language."""

assume true Inform
    """Inform is a causable event. The controller always informs the data subject about the declaration."""

#art12
assume false ChargeForRequest
    """We are never charging users for requests."""

assume true IsConcise
    """The text of all declarations is contained in this refinement file. They are concise."""

assume true IsElectronicDeclaration
    """All declarations are electronic."""
    
assume true IsElectronicRequest
    """All requests are electronic."""

assume false IsExtensionNecessary
    """We never claim that we need a time extension to process user requests."""

assume false IsImpossibleElectronic
    """All requests are electronic."""

assume true IsReasonForRequestExtension
    """Irrelevant since we never extend requests."""
    
assume true IsReasonForRequestRefusal
    """Irrelevant since we never refuse requests."""

assume false IsReasonableFee
    """We generally do not impose fees."""

assume true IsTransparentDeclaration
    """The text of all declarations is contained in this refinement file. They are transparent."""

assume false IsUnfoundedOrExcessive
    """We never qualify user requests as unfounded or excessive."""

assume false RefuseRequest
    """We never refuse requests."""

assume false RequestExtension
    """We never request an extension."""

assume false RequestsNonElectronic
    """All requests are electronic."""

assume false UndueDelay
    """We do not wait to inform users."""

#art16
rule "r_RectificationRequest"
  whenever
    RequestRectification(ds, d, d')
  refine
    Request(ds, "rectification", "GDPRFS")
    IsRectificationRequest("rectification", d, d')
    HasInaccuracy(d)

#art17
rule "r_ErasureRequest"
  whenever
    RequestErasure(ds, d)
  refine
    Request(ds, "erasure", "GDPRFS")
    IsErasureRequest("erasure", d)

rule "r_WithdrawConsent"
  whenever
    Revoke(ds, p)
  refine
    WithdrawConsent(ds, p, "GDPRFS")

assume false DataReview
    """We do not have a data review process in place, but we do have a data deletion process in place (Delete event)."""

assume false Share
    """We do not share data with other entities."""

assume true NotifyOfErasure
    """NotifyOfErasure is a causable event. The controller always notifies the data subject of the erasure of their data."""

assume false IsNecessaryForFreedomOfExpression
    """We do not consider this legal basis."""

#art21
assume false DemonstrateOverridingCompellingGrounds
    """We never claim compelling grounds that override the interests, rights, and freedoms of the data subject."""

rule "r_IsDirectMarketing"
    whenever
        p = "marketing"
    refine
        IsDirectMarketing(p)

assume false Object
    """No data subject objects to the processing of their data for direct marketing purposes by default."""

#art30
### unrefine Record ###

assume false IsJointController
    """There are no joint controllers."""

assume false IsControllerRepresentative
    """We do not need controller representatives since all controllers considered are based in the Union."""

assume false Transfer
    """No activities that involve a transfer are taking place."""

rule "r_IsDataProcessingOfficer"
    whenever
        c = "GDPRFS"
        c' = "dpo@gdprfs.com"
    refine
        IsDataProtectionOfficer(c, c')

assume false HasDataSubjectCategory
    """No activities are specific to a particular data subject category."""

rule "r_HasSecurityMeasuresDeclaration"
    whenever
        true
    refine
        HasSecurityMeasuresDeclaration(a, "Access control, consent-aware enforcement, purpose limitation")

rule "r_IsSME"
    whenever
        true
    refine
        IsSME("GDPRFS")

rule "r_IsRiskyProcessing"
    """Processing special category data is considered risky for SMEs (Art 30(5) counter-exception)."""
    whenever
        SpecialData(d, spCat)
    refine
        IsRiskyProcessing("Use")

assume false IsOccasionalProcessing
    """All processing is habitual, not occasional."""

assume false RelatesToCriminalConvictionsOrOffences
    """We do not process data relating to criminal convictions and offences or related security measures."""
