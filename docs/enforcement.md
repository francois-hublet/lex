# Enforcement

This guide directs developers through the entire lifecycle of implementing privacy compliance. It breaks down the process into six distinct phases: 

- Formalization (translate law into abstract logic)
- Refinement (map abstract logic to concrete system events)
- Compilation (transform definitions into executable policy) 
- Instrumentation (connect the policy to the application code)
- Test/Run the System (To verify the correctness)
- Auditing (verify accuracy of the process)

This structured approach ensures that every legal requirement is traceable to specific code implementations, facilitating robust compliance and accountability.

--- 

## Phase 1: Formalization

Law articles are first translated into Lex Code by defining types which describe objects (people, entities, activities etc.) and events (legal concepts) involved. Using these definitions, we construct rules that can describe the law. The formalization can be stored and reused since it is not specific to any system. Because this process involves interpretations of the law, legal and technical experts must revisit the formalization and adjust as needed. Below is a non-exhaustive checklist:

- All the parties, activities and objects have been formalized.
- Exceptions are explicitly stated.
- If an event is observable, it means that the system considers it but does not modify it.
- If an event is suppressable, it means that under certain conditions the system must stop it from occurring.
- For each declaration, state which legal ground(s) can justify it and how that is evidenced in events; include contrary-to-duty structure if the primary ground is missing.
- Make the temporal conditions explicit (e.g., within the end of contract, within a month).
- Define every type, event, and term with precise, non-overlapping meanings; record all interpretations and domain-specific choices in a glossary linked to article/point/paragraph identifiers (e.g., how “undue delay” is interpreted).

At the end of this step, a Lex file with proper formalization needs to be produced. More details on Lex files can be found in the [tutorials](tutorials/gdpr.md).

---

## Phase 2: Refinement

This step is called the refinement phase, where we map abstract legal concepts to concrete, observable events and objects. For example, if in Phase 1 a suppressable event DataProcessing has been introduced, we can concretize it with suppressable event ReadData or suppressable event WriteData, which represent operations in the system. 

Deliverables

- refinement.rex – Refinement mappings with comprehensive docstrings
- refinement_justifications.md – Justifications in plain text
- refinement_justifications.html – Documentation for auditing

Before starting this step, ensure to have the following files:

Prerequisites:

- Completed formalization (formalization.lex)
- Deep understanding of system functionality (read models.py, views.py, data flow documentation)
- Understanding of the legal requirements

Then follow the workflow:

1. **Analyze System Functionality**

    - Review all models in app/models.py to understand data structures
    - Review all views in app/views.py to understand data operations
    - Identify which operations process personal data

2. **Determine Relevant Legal Types and Events**

    - Identify events that correspond to actual system operations
    - Map each system operation to a legal event

3. **Define Type Refinements**

    We need to specify how the types defined in step 1 are implemented in the system. For example, an article specifies a general concept of data subject, but different systems might have different ways to identify a data subject, such as by name, session ID, or social security number. Justifications must be provided as docstrings. For example, if user_id is used to identify the user, a justification such as

    ```
    A data subject is always associated with a user_id. There is no case where 
    a data subject exists but a user_id  is not created (which would mean that 
    the system contains data of a natural person who is not a user, and this 
    should not be possible). Across all activities, the user_id is the same.
    ```

    must be included.

    Provide a justification by considering

    - Why it makes sense to represent the objects with such specifications in the system? Mention the workflow and any relevant code snippets.
    - If an object has no corresponding concept in the system’s specification, consider adding it.

4. **Determine System Events and Types**

    - Identify and declare relevant system events that correspond to legal events.
    - Match legal–system event types: observable → observable, suppressable → suppressable.
    - Write comprehensive docstrings citing specific law articles.

    For example, if an observable event GiveConsent is defined in step 1, we can map it to
    the system event GrantConsent, we create a refinement event:

    ```mylang
    observable event GrantConsent ### Monotonic 
    """Data subject {ds} grants consent for purpose {p}. Per GDPR Art. 4(11), consent means any freely given, specific, 
     informed and unambiguous indication of wishes. Per Art. 7(2), the request must be clearly distinguishable from other 
     matters. Per Art. 7(4), consent is not freely given if performance of a contract is conditional on consent."""
    ds: data_subject
    p: purpose
    ```

5. **Define Event Refinement Rules** Map system events to legal concepts using the refine keyword. For example:

    ```mylang 
    rule "refine_grant_consent"
    """System’s consent mechanism satisfies legal requirements"""
    whenever
    GrantConsent(ds, p)
    refine
    GiveConsent(ds, p, "OrderNow")
    ```

    **Assumptions** Certain legal events or concepts may not directly apply or may always be valid throughout the application lifecycle. For these cases
    explicitly state the assumptions and provide justifications for each.

    For example, considering GDPR Article 5.1(a):

    - assume true IsFair: because in our system, we treat the data in an equal, ethical way, since the data are only read from a database and then displayed without any manipulations.
    - assume false IsNecessaryForLegitimateInterest: We assume this to be false since data processing is only done for contractual purpose.

    **Justifications** For each refinement event, provide a justification specifying the reason why our system is compliant, mentioning any relevant code and describing the workflow, system components, and any other relevant information.

--- 

## Phase 3: Compilation

This step is straightforward: we compile the file .rex, together with the file .lex to produce a file containing MFOTL formulas and a file containing events signatures. These two files will be essential for the enforcer to carry out the execution of the runtime enforcement.

--- 

## Phase 4: Instrumentation

Instrumentation is a process of preparing the system for runtime enforcement. This phase connects the enforcement runtime to your application code by implementing two-way configuration of:

- **Handlers** (→): Responsible for taking suppressable or causable events and performing the corresponding actions
- **Mappings** (←): Log the events based on actions received

Deliverables:

- **enforcer.py** – Event schemas, mappings, middleware configuration
- **handlers.py** – Suppression and causation handlers
- **models.py** – Decorated with @InstrumentORM for personal data
- **instrumentation_justifications.md** – Generated from code comments
- **instrumentation_justifications.html** – Generated documentation

Prerequisites:

- Completed refinement (**refinement.rex**)
- System implementation (**models.py**, **views.py**)
- Understanding of enforcement library (**instrlib/**)

Workflow Steps:

1. Configure Event Schema (in **enforcer.py**)

    - Import all events from **refinement.rex** and define schema with event signatures.
    - We provided an automated script able to extract events and predicates defined in the refinement file, and output the Schema definition to be included in **enforcer.py**
    - Example: From **refinement.rex** we have:

    ```mylang
    suppressable event ReadData ### Antimonotonic
    """ Function {f} reads data {d} of the data subject {ds}. The system accesses stored data from 
    the database to retrieve and display information to users or for internal processing. """
    d: data_id
    ds: data_subject

    suppressable event WriteData ### Antimonotonic
    """ Function {f} writes data {d}. The system stores or updates data {d} in the database when 
    users submit forms or when data needs to be persisted. """
    f: fun_name
    d: data_id
    
    observable event GrantConsent ### Monotonic
    """ Data subject {ds} gives consent to process their data for purpose {p}. The system presents 
    the user with clear options to select specific purposes (functionalities, analytics, marketing,
    user experience) and records consent when the user clicks ’Grant’ button next to each purpose.
    Per GDPR Art. 4(11), consent means any freely given, specific, informed and unambiguous indication 
    of the data subject’s wishes. Per Art. 7(2), the request for consent must be clearly distinguishable,
    intelligible and in plain language. Per Art. 7(4), consent is not freely given if the performance of 
    a contract is conditional on consent for processing that is not necessary for contract performance. """
    ds: data_subject
    p: purpose
    ...
    ```

    Then in enforcer.py we define the schema:

    ```python
    from instrlib.schema import Schema, Event
        schema = Schema()
        schema.add_event(’ReadData’,[’fun_name’, ’data_id’, ’data_subject’, ’purpose’])
        schema.add_event(’WriteData’,[’fun_name’, ’data_id’])
        schema.add_event(’GrantConsent’, [’data_subject’, ’purpose’])
        ...
    ```

2. Annotate Personal Data Models (in models.py)

    - Apply @InstrumentORM decorator to all models containing personal data.
    - This enables automatic read/write events to be logged through read_mapping and write_mapping.
    - Use ‘‘ to add descriptions after each field explaining why they are personal data.
    - Example: 
    ```python
        from instrlib.django import InstrumentORM

        @InstrumentORM(
        logger,
        {
        ’Customer.email’, ### Email address that can directly identify 
        ’Customer.phone_number’, ### Phone number that can directly identify 
        ’Customer.external_id’ ### Unique identifier assigned to the user 
        },
        info=info_customer,
        events={’read’, ’write’},
        )
    ```

3. Define Handlers

    In handlers.py, define at least one suppression handler and one causation handler.
    In general, the default suppression handler is none_handler that replaces the
    output with None and a causation handler can be delete_handler that erases user
    data upon request.

    For each suppressable (respectively, causable) event defined in the schema, define a
    dictionary that maps each of the events to the corresponding handler. For each
    association, provide a description of the workflow using a comment starting with
    \#\#\# so that it can be included into the justification document by the automated
    parser.

4. Define read_mapping & write_mapping
    Define functions read_mapping and write_mapping that log read and write events in the system. 
    
    The InstrumentORM decorator automatically calls these mappings when personal data is accessed or modified.
    
    Example in handlers.py:

    ```python 
    def read_mapping(action):
        ### action: read(Model, field, id, caller, owner, purpose)
        ### action_description: An ORM read operation where the application reads a specific field of a model instance (e.g., reading Customer.email). The mapping extracts the data id, the data subject (owner).
        ### event: ReadData(data_id, data_subject)
        data_id = action.args[2] # id (pk)
        data_subject = action.args[4] # owner (user_id from info(self))
        return Event(’ReadData’, data_id, data_subject)

    def write_mapping(action):
        ### action: write(Model, field, value, caller, owner)
        ### action_description: An ORM write operation where the application writes a specific field of a model instance (e.g., writing Customer.email). The mapping extracts the data id, the data subject (owner).
        ### event: WriteData(data_id, data_subject)
        data_id = action.args[2] # id (pk)
        data_subject = action.args[4] # owner (user_id from info(self))
        return Event(’WriteData’, data_id, data_subject)
    ```

5. Define input_mapping

    First declare the url-input mapping in url.py by including all views that have actions associated with them, then in handlers.py declare the function input_mapping(action) which will take an action and log the corresponding event.

    For each of the action, add comments starting with ### to annotate the action signature, the action description and the corresponding event. An example is the following:

    ```python
    ### action: input("manage_consent_view", "analytics_consent", "on", "user_id", "service")
    ### action_description: User grants analytics consent by enabling the Analytics checkbox and confirming.
    ### event: GrantConsent(user_id, "analytics")
    if(action.args[0] == "manage_consent_view" 
    and action.args[1] == "analytics_consent"
    and action.args[2] == "on"
    and service == "service"):
    return Event(’GrantConsent’, user_id, "analytics")
    ...
    ```

    This would allow the document generation script to extract the text and put in the justification file.

--- 

## Phase 5: Artifacts Generation

The methodology provides automated documentation generation to maintain consistency between code and documentation.

### Generate Refinement Documentation

Generate Markdown Template:

python tools / generate _ docs .py --refinement -md

This creates refinement_justifications.md.

Generate HTML Documentation:

python tools / generate _ docs .py --refinement - html

This creates refinement_justifications.html with interactive navigation and code references.

### Generate Instrumentation Documentation

Generate Markdown from Code Comments:

python tools / generate _ docs .py -- instrumentation -md

This creates instrumentation_justifications.md.

Generate HTML Documentation:

python tools / generate _ docs .py -- instrumentation - html

This creates instrumentation_justifications.html with interactive navigation and code references.

### Generate Combined Documentation

Create a unified view with tabs for formalization, refinement, and instrumentation:

python tools / generate _ combined _ tabs .py

This creates combined_tabs.html – single page with all documentation.

### Automated Full Pipeline

The script generate_docs.py handles the complete generation workflow:

\# Check project structure
python tools / generate _ docs .py --check - structure

\# Generate markdown files
python tools / generate _ docs .py --refinement -md
python tools / generate _ docs .py -- instrumentation -md

\# Generate HTML documentation
python tools / generate _ docs .py --refinement - html
python tools / generate _ docs .py -- instrumentation - html
python tools / generate _ docs .py -- combined

\# Generate all documentation ( markdown + HTML )
python tools / generate _ docs .py --all

\# Clean generated files
python tools / generate _ docs .py --clean

### Documentation Structure

Generated HTML files include:

- Navigation: Click events/rules to jump to definitions
- Code Links: Click file references to see source code
- Search: Find events, rules, and justifications quickly
- Cross-References: Links between formalization, refinement, and instrumentation
- GDPR Articles: Direct references to legal objects
- Syntax Highlighting: Color-coded events, rules, and code

---