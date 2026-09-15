(* Compilation of the declarations (types and events) of a Lex/Rex program to an
   OWL ontology, serialized in RDF/XML (MIME type application/rdf+xml, cf.
   https://www.w3.org/TR/owl-ref/#MIMEType).

   Rules and functions are not part of the output: only the vocabulary declared
   by the program is.

   Encoding:
   - every declared type becomes an owl:Class, whether or not it has a base
     type: in Lex, 'type purpose is string' is a sort of its own and not the
     type of strings, so the base type is recorded as an annotation only;
   - a type whose base type is another declared type becomes a subclass of it;
   - a record type becomes an owl:Class with one functional property per field;
   - an event or predicate becomes an owl:Class (a reified n-ary relation, cf.
     https://www.w3.org/TR/swbp-n-aryRelations/) with one functional property
     per argument, restricted to exactly one value. *)

open Core

open Elex

module Enftype = MFOTL_lib.Enftype

(* Namespaces *)

let lex_ns   = "https://lex-lang.org/ontology/core#"
let rdf_ns   = "http://www.w3.org/1999/02/22-rdf-syntax-ns#"
let rdfs_ns  = "http://www.w3.org/2000/01/rdf-schema#"
let owl_ns   = "http://www.w3.org/2002/07/owl#"
let xsd_ns   = "http://www.w3.org/2001/XMLSchema#"

let default_ontology_iri name = "https://lex-lang.org/ontology/" ^ name

(* XML and IRI helpers *)

let escape s =
  String.concat_map s ~f:(function
      | '&'  -> "&amp;"
      | '<'  -> "&lt;"
      | '>'  -> "&gt;"
      | '"'  -> "&quot;"
      | '\r' -> "&#13;"
      | c    -> String.of_char c)

(* Turns an arbitrary Lex identifier into a valid XML NCName *)
let ncname s =
  let ok c = Char.is_alphanum c || Char.equal c '_' || Char.equal c '-' in
  let s = String.map s ~f:(fun c -> if ok c then c else '_') in
  match String.to_list s with
  | []                             -> "_"
  | c :: _ when Char.is_digit c    -> "_" ^ s
  | _                              -> s

(* Types *)

type type_kind =
  | KDatatype of Dom.tt
  | KClass
  | KRecord   of (string * TypeTerm.ttt) list

let xsd_of_tt = function
  | Dom.TInt     -> xsd_ns ^ "integer"
  | Dom.TStr     -> xsd_ns ^ "string"
  | Dom.TFloat   -> xsd_ns ^ "double"
  | Dom.TBool    -> xsd_ns ^ "boolean"
  | Dom.TTime    -> xsd_ns ^ "dateTime"
  | Dom.TSpan    -> xsd_ns ^ "duration"
  | Dom.TMoney _ -> xsd_ns ^ "decimal"

(* A declared type is a sort of its own — only its fields, if it has any, say
   anything about its shape. *)
let kind_of_name aliases tn =
  match Map.find aliases tn with
  | Some (Some (TypeTerm.TSum kvs), _) -> KRecord kvs
  | _                                  -> KClass

let kind_of_ttt aliases = function
  | TypeTerm.TConst tt -> KDatatype tt
  | TypeTerm.TNamed tn -> kind_of_name aliases tn
  | TypeTerm.TSum  kvs -> KRecord kvs
  | TypeTerm.TVar    _ -> KClass

(* The IRI a type term is mapped to, if any: named types get their own IRI,
   atomic types the corresponding XML Schema datatype, and anonymous record
   types and type variables no IRI at all. *)
let iri_of_ttt base = function
  | TypeTerm.TConst tt -> Some (xsd_of_tt tt)
  | TypeTerm.TNamed tn -> Some (base ^ "#" ^ ncname tn)
  | TypeTerm.TSum    _
    | TypeTerm.TVar  _ -> None

(* Sanitizing identifiers may make two distinct arguments or fields collide;
   disambiguate by appending their position. *)
let ncnames_of names =
  let rec aux seen i = function
    | [] -> []
    | name :: names ->
       let n = ncname name in
       let n = if Set.mem seen n then n ^ "_" ^ Int.to_string i else n in
       n :: aux (Set.add seen n) (i+1) names in
  aux (Set.empty (module String)) 0 names

(* Emission *)

let buf_add = Buffer.add_string

let resource b tag iri =
  buf_add b (Printf.sprintf "  <%s rdf:resource=\"%s\"/>\n" tag (escape iri))

let literal b tag ?datatype text =
  let dt = match datatype with
    | None    -> ""
    | Some dt -> Printf.sprintf " rdf:datatype=\"%s\"" (escape dt) in
  buf_add b (Printf.sprintf "  <%s%s>%s</%s>\n" tag dt (escape text) tag)

let comment b = function
  | None   -> ()
  | Some s -> literal b "rdfs:comment" s

(* A property of [domain_iri] holding the value of an event argument or of a
   record field. *)
let property b aliases base ~iri ~label ~domain_iri ~ttt ~extra =
  let tag = match kind_of_ttt aliases ttt with
    | KDatatype _ -> "owl:DatatypeProperty"
    | KClass | KRecord _ -> "owl:ObjectProperty" in
  buf_add b (Printf.sprintf "<%s rdf:about=\"%s\">\n" tag (escape iri));
  resource b "rdf:type" (owl_ns ^ "FunctionalProperty");
  literal b "rdfs:label" label;
  resource b "rdfs:domain" domain_iri;
  Option.iter (iri_of_ttt base ttt) ~f:(resource b "rdfs:range");
  literal b "lex:type" (TypeTerm.to_string ttt);
  List.iter extra ~f:(fun f -> f ());
  buf_add b (Printf.sprintf "</%s>\n\n" tag)

(* An 'exactly one' restriction on [prop_iri], to be used inside a class *)
let cardinality_restriction b prop_iri =
  buf_add b "  <rdfs:subClassOf>\n    <owl:Restriction>\n";
  buf_add b (Printf.sprintf "      <owl:onProperty rdf:resource=\"%s\"/>\n" (escape prop_iri));
  buf_add b (Printf.sprintf
               "      <owl:cardinality rdf:datatype=\"%snonNegativeInteger\">1</owl:cardinality>\n"
               xsd_ns);
  buf_add b "    </owl:Restriction>\n  </rdfs:subClassOf>\n"

let owl_of_type b aliases base name (ty, doc_string) =
  let iri = base ^ "#" ^ ncname name in
  let props = match ty with
    | Some (TypeTerm.TSum kvs) ->
       List.map2_exn (ncnames_of (List.map kvs ~f:fst)) kvs
         ~f:(fun n (f, ttt) -> (iri ^ "_" ^ n, f, ttt))
    | _ -> [] in
  buf_add b (Printf.sprintf "<owl:Class rdf:about=\"%s\">\n" (escape iri));
  literal b "rdfs:label" name;
  comment b doc_string;
  (match ty with
   (* A declared base type is a supertype of the declared type *)
   | Some (TypeTerm.TNamed _ as ttt) ->
      Option.iter (iri_of_ttt base ttt) ~f:(resource b "rdfs:subClassOf")
   (* An atomic base type says how the values of the type are written down, not
      what they are: it is an annotation rather than a datatype definition. *)
   | Some (TypeTerm.TConst tt) -> literal b "lex:baseType" (Dom.tt_to_string tt)
   | Some (TypeTerm.TSum _) | Some (TypeTerm.TVar _) | None -> ());
  List.iter props ~f:(fun (prop_iri, _, _) -> cardinality_restriction b prop_iri);
  buf_add b "</owl:Class>\n\n";
  List.iter props ~f:(fun (prop_iri, f, ttt) ->
      property b aliases base ~iri:prop_iri ~label:f ~domain_iri:iri ~ttt ~extra:[])

(* [Lex.string_of_enftype] is partial: an event may carry an enforcement type
   that has no surface syntax in Lex, in which case nothing is emitted. *)
let string_of_enftype enftype =
  try Some (Lex.string_of_enftype enftype) with _ -> None

let owl_of_event b aliases base name (event_type, args, (enftype, itl), doc_string) =
  let iri = base ^ "#" ^ ncname name in
  let syntax = match event_type with
    | Lex.Event (_, sy) -> sy
    | Lex.Predicate | Lex.Exception -> Lex.Standard in
  (* For functional and variable events, the last argument is the value of the
     event rather than one of its parameters. *)
  let n_args = List.length args in
  let is_value i = match syntax with
    | Lex.Functional | Lex.Variable -> i = n_args - 1
    | Lex.Standard -> false in
  let props =
    List.mapi (List.zip_exn (ncnames_of (List.map args ~f:fst)) args)
      ~f:(fun i (n, (a, ttt)) -> (iri ^ "_" ^ n, i, a, ttt)) in
  buf_add b (Printf.sprintf "<owl:Class rdf:about=\"%s\">\n" (escape iri));
  literal b "rdfs:label" name;
  comment b doc_string;
  resource b "rdfs:subClassOf" (lex_ns ^ "Declaration");
  Option.iter (string_of_enftype enftype) ~f:(literal b "lex:enforcementType");
  (match event_type with
   | Lex.Event (true, _) -> literal b "lex:external" ~datatype:(xsd_ns ^ "boolean") "true"
   | _ -> ());
  if itl then literal b "lex:internal" ~datatype:(xsd_ns ^ "boolean") "true";
  List.iter props ~f:(fun (prop_iri, _, _, _) -> cardinality_restriction b prop_iri);
  buf_add b "</owl:Class>\n\n";
  List.iter props ~f:(fun (prop_iri, i, a, ttt) ->
      let extra =
        [ (fun () -> literal b "lex:argumentIndex"
                       ~datatype:(xsd_ns ^ "nonNegativeInteger") (Int.to_string i)) ]
        @ (if is_value i then
             [ (fun () -> literal b "lex:isValue" ~datatype:(xsd_ns ^ "boolean") "true") ]
           else []) in
      property b aliases base ~iri:prop_iri ~label:a ~domain_iri:iri ~ttt ~extra)

(* The few terms of the Lex vocabulary used above are declared here, so that the
   generated file is self-contained. *)
let owl_of_lex_vocabulary b =
  let class_ name comment_ =
    buf_add b (Printf.sprintf "<owl:Class rdf:about=\"%s%s\">\n" lex_ns name);
    literal b "rdfs:label" name;
    literal b "rdfs:comment" comment_;
    buf_add b "</owl:Class>\n\n" in
  let annotation name comment_ =
    buf_add b (Printf.sprintf "<owl:AnnotationProperty rdf:about=\"%s%s\">\n" lex_ns name);
    literal b "rdfs:label" name;
    literal b "rdfs:comment" comment_;
    buf_add b "</owl:AnnotationProperty>\n\n" in
  class_ "Declaration" "An instance of a relation declared by the Lex program.";
  annotation "baseType"        "The atomic Lex type the values of a type are written as.";
  annotation "enforcementType" "The enforcement type of a Lex declaration.";
  annotation "external"        "Whether the declaration is external in Lex.";
  annotation "internal"        "Whether the declaration is internal in Lex.";
  annotation "argumentIndex"   "The position of an argument in a Lex declaration.";
  annotation "isValue"         "Whether the argument is the value of a functional or variable declaration.";
  annotation "type"            "The Lex type of an argument or field."

let is_builtin_event name = Map.mem Builtin.events_map name

(* The declarations of the program that are part of its vocabulary: exception
   predicates are generated by the compiler, and builtin events are not declared
   by the program at all. *)
let declared_events eprog =
  List.filter (Map.to_alist eprog.eevents)
    ~f:(fun (name, (event_type, _, _, _)) ->
      not (is_builtin_event name)
      && (match event_type with Lex.Exception -> false | _ -> true))

(* Restriction to a section

   A section such as "article 6" is given as a sequence of section kinds and
   names. A declaration occurs in that section when one of the rules under it
   mentions it: the events and predicates of those rules, the types their
   arguments range over, and the types fixed by the rules themselves.

   Note that the section a declaration is written under is not usable here:
   statements do not carry their position, and their order in [estmts] does not
   follow the order of the source. This is no loss — a declaration that no rule
   of the section mentions does not occur in it. *)

exception Section_error of string

(* "article[1]" is the second nesting level of articles, and is still an article *)
let section_kind_name sk =
  String.take_while (Lex.string_of_section_kind sk) ~f:(fun c -> not (Char.equal c '['))

(* "article 6 paragraph 1" -> [("article", "6"); ("paragraph", "1")] *)
let parse_section spec =
  let words = List.filter (String.split_on_chars spec ~on:[' '; '\t'])
                ~f:(fun s -> not (String.is_empty s)) in
  let rec aux = function
    | []                   -> []
    | kind :: name :: rest -> (String.lowercase kind, name) :: aux rest
    | [kind]               ->
       raise (Section_error
                (Printf.sprintf "'%s' is not followed by the name of a section" kind)) in
  match aux words with
  | []    -> raise (Section_error "no section given")
  | pairs -> pairs

(* Whether the section [path] of a statement lies under the requested section *)
let rec is_under pairs path =
  match pairs, path with
  | [], _ -> true
  | _, [] -> false
  | (kind, name) :: pairs', (sk, n) :: path' ->
     if String.equal (String.lowercase (section_kind_name sk)) kind && String.equal n name
     then is_under pairs' path'
     else is_under pairs path'

let path_of_label label = Lex.Ref.((Label.reference_of_label label LexingInfo.dummy).sks)

(* Every event and predicate occurring in a rule *)
let events_of_erule ecrules erule =
  let of_pattern (pf: Pattern.t) = Pattern.predicates pf in
  let of_formulas fs = List.concat_map fs ~f:Eformula.predicates in
  let ps = match erule with
    | EObligation _ | EPermission _ ->
       let pf1, pf2, _, _ = get_obligation_params ecrules erule in
       of_pattern pf1 @ of_pattern pf2
    | EConstitutive _ ->
       let pf, g = get_constitutive_params ecrules erule in
       of_pattern pf @ of_formulas g
    | EException _ ->
       let pf, _ = get_exception_params ecrules erule in of_pattern pf
    | EScope _ ->
       let pf, _ = get_scope_params ecrules erule in of_pattern pf
    | EExceptionC _ ->
       let pf, _, g = get_exceptionc_params ecrules erule in
       of_pattern pf @ of_formulas g in
  List.map ps ~f:fst

(* A type drags in the types it is built from, so that base types stay resolvable *)
let rec close_type aliases acc tn =
  if Set.mem acc tn || not (Map.mem aliases tn) then acc
  else
    let acc = Set.add acc tn in
    match Map.find_exn aliases tn with
    | (Some ttt, _) -> close_ttt aliases acc ttt
    | (None, _)     -> acc

and close_ttt aliases acc = function
  | TypeTerm.TNamed tn -> close_type aliases acc tn
  | TypeTerm.TSum  kvs -> List.fold kvs ~init:acc ~f:(fun acc (_, v) -> close_ttt aliases acc v)
  | TypeTerm.TConst _
    | TypeTerm.TVar _  -> acc

(* "article 6" -> "-article-6", to keep the output of a restricted run apart *)
let section_suffix spec = "-" ^ Util.sanitize_string (String.lowercase (String.strip spec))

(* Keeps [events] and every type they need, dropping all other declarations *)
let restrict_to_events ?(types = Set.empty (module String)) events eprog =
  let events = Set.filter events ~f:(Map.mem eprog.eevents) in
  let types =
    Set.fold events ~init:types ~f:(fun acc name ->
        let _, args, _, _ = Map.find_exn eprog.eevents name in
        List.fold args ~init:acc ~f:(fun acc (_, ttt) -> close_ttt eprog.ealiases acc ttt)) in
  let types = Set.fold types ~init:types ~f:(close_type eprog.ealiases) in
  { eprog with
    ealiases = Map.filter_keys eprog.ealiases ~f:(Set.mem types);
    eevents  = Map.filter_keys eprog.eevents  ~f:(Set.mem events) }

let restrict_to_section spec eprog =
  let pairs = parse_section spec in
  let found = ref false in
  let events = ref (Set.empty (module String)) in
  let types = ref (Set.empty (module String)) in
  List.iter eprog.estmts ~f:(function
      | ESSection (_, label, _, _) ->
         if is_under pairs (path_of_label label) then found := true
      | ESRule (_, _, label, type_fixes, erule, _) ->
         if is_under pairs (path_of_label label) then begin
             found := true;
             (* A rule may fail to be reconstructed; take the events it does yield *)
             let names = try events_of_erule eprog.ecrules erule with _ -> [] in
             events := List.fold names ~init:!events ~f:Set.add;
             types := List.fold type_fixes ~init:!types
                        ~f:(fun acc (_, ttt) -> close_ttt eprog.ealiases acc ttt)
           end
      | ESImport _ | ESEvent _ | ESType _ | ESFunction _ | ESNote _ -> ());
  if not !found then
    raise (Section_error (Printf.sprintf "there is no section '%s' in this program" spec));
  restrict_to_events ~types:!types !events eprog

(* Hiding a kind of declaration

   Every event a refinement assumes is also internalized by it, so hiding the
   internal declarations hides the assumed ones along with them. *)

(* Drops every declaration [f] rejects, and the types only it needed *)
let hide ~f eprog =
  restrict_to_events
    (Set.of_list (module String)
       (List.filter_map (declared_events eprog)
          ~f:(fun (name, data) -> if f name data then Some name else None)))
    eprog

let hide_internal eprog =
  hide eprog ~f:(fun _ (_, _, (_, itl), _) -> not itl)

let hide_assumed eprog =
  hide eprog ~f:(fun name _ -> not (Map.mem eprog.eassumed name))

let owl_of_eprog ~source ~base eprog =
  let b = Buffer.create 4096 in
  let aliases = eprog.ealiases in
  buf_add b "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n";
  buf_add b (Printf.sprintf
               "<rdf:RDF xmlns=\"%s#\"\n         xml:base=\"%s\"\n         xmlns:rdf=\"%s\"\n         xmlns:rdfs=\"%s\"\n         xmlns:owl=\"%s\"\n         xmlns:xsd=\"%s\"\n         xmlns:lex=\"%s\">\n\n"
               (escape base) (escape base) rdf_ns rdfs_ns owl_ns xsd_ns lex_ns);
  buf_add b (Printf.sprintf "<owl:Ontology rdf:about=\"%s\">\n" (escape base));
  literal b "rdfs:comment"
    (Printf.sprintf "Declarations of the Lex program %s. Generated by the Lex compiler." source);
  buf_add b "</owl:Ontology>\n\n";
  owl_of_lex_vocabulary b;
  Map.iteri aliases ~f:(fun ~key ~data -> owl_of_type b aliases base key data);
  List.iter (declared_events eprog) ~f:(fun (name, data) ->
      owl_of_event b aliases base name data);
  buf_add b "</rdf:RDF>\n";
  Buffer.contents b

let to_file ~source ~base filename eprog =
  Out_channel.write_all filename ~data:(owl_of_eprog ~source ~base eprog)

(* Graphical rendering

   The ontology is also rendered as a class diagram: every event and predicate
   becomes a box listing its literal-valued arguments, and every argument
   ranging over a declared type becomes an edge to that type. The diagram is
   laid out by Graphviz, which is expected to be on the PATH. *)

let engine = "sfdp"

(* Fill and stroke of a declaration box, by enforcement type *)
let colors_of_enftype = function
  | Some "observable"            -> ("#e8f0fe", "#4a6fa5")
  | Some "causable"
    | Some "causable observable" -> ("#e6f4ea", "#3d7a4f")
  | Some "suppressable"          -> ("#fdecea", "#a4433a")
  | Some "causable suppressable" -> ("#f3e8fd", "#7a4aa5")
  | Some "internal"              -> ("#f1f3f4", "#5f6368")
  | _                            -> ("#ffffff", "#5f6368")

let type_id name  = "\"t_" ^ ncname name ^ "\""
let event_id name = "\"e_" ^ ncname name ^ "\""

(* A box with a title and one row per literal-valued field *)
let dot_table b ~id ~title ~subtitle ~fill ~border ~rows =
  buf_add b (Printf.sprintf
               "  %s [label=<<TABLE BORDER=\"0\" CELLBORDER=\"1\" CELLSPACING=\"0\" COLOR=\"%s\">"
               id border);
  buf_add b (Printf.sprintf
               "<TR><TD BGCOLOR=\"%s\" ALIGN=\"CENTER\"><B>%s</B>%s</TD></TR>"
               fill (escape title)
               (match subtitle with
                | "" -> ""
                | s  -> Printf.sprintf "<BR/><FONT POINT-SIZE=\"8\">%s</FONT>" (escape s)));
  List.iter rows ~f:(fun (field, ty) ->
      buf_add b (Printf.sprintf
                   "<TR><TD ALIGN=\"LEFT\"><FONT POINT-SIZE=\"9\">%s : %s</FONT></TD></TR>"
                   (escape field) (escape ty)));
  buf_add b "</TABLE>>];\n"

(* Splits the fields of a declaration into the ones shown inside its box and the
   ones shown as an edge to the type they range over *)
let split_fields aliases fields =
  let f (field, ttt) = match kind_of_ttt aliases ttt with
    | KDatatype _ -> First (field, TypeTerm.to_string ttt)
    | KClass | KRecord _ ->
       (match ttt with
        | TypeTerm.TNamed tn when Map.mem aliases tn -> Second (field, tn)
        | _ -> First (field, TypeTerm.to_string ttt)) in
  List.partition_map fields ~f

let dot_edge b ~src ~dst ~label =
  buf_add b (Printf.sprintf "  %s -> %s [label=\"%s\"];\n" src dst (escape label))

let dot_of_type b aliases name (ty, _) =
  let id = type_id name in
  match kind_of_name aliases name with
  | KRecord kvs ->
     let rows, refs = split_fields aliases kvs in
     dot_table b ~id ~title:name ~subtitle:"type" ~fill:"#fff4d6" ~border:"#b58900" ~rows;
     List.iter refs ~f:(fun (field, tn) ->
         dot_edge b ~src:id ~dst:(type_id tn) ~label:field)
  | KClass | KDatatype _ ->
     (* An atomic base type is written under the name of the type; a declared
        base type is drawn as a generalization instead. *)
     let base = match ty with
       | Some (TypeTerm.TConst tt) -> Printf.sprintf "\\n(%s)" (escape (Dom.tt_to_string tt))
       | _ -> "" in
     buf_add b (Printf.sprintf
                  "  %s [shape=ellipse, style=filled, fillcolor=\"#fff4d6\", color=\"#b58900\", label=\"%s%s\"];\n"
                  id (escape name) base);
     (match ty with
      | Some (TypeTerm.TNamed tn) when Map.mem aliases tn ->
         buf_add b (Printf.sprintf
                      "  %s -> %s [style=dashed, arrowhead=onormal, color=\"#b58900\"];\n"
                      id (type_id tn))
      | _ -> ())

let dot_of_event b aliases name (event_type, args, (enftype, itl), _) =
  let id = event_id name in
  let enf = string_of_enftype enftype in
  let fill, border = colors_of_enftype enf in
  let internal = String.equal (Option.value enf ~default:"") "internal" in
  (* Whether a declaration is an event or a predicate is not shown: the diagram
     says how it may be enforced, not how it is written. *)
  let subtitle =
    String.concat ~sep:" "
      (List.filter_opt [ enf;
                         (match event_type with
                          | Lex.Event (true, _) -> Some "external"
                          | _ -> None);
                         (if itl && not internal then Some "internal" else None) ]) in
  let rows, refs = split_fields aliases args in
  dot_table b ~id ~title:name ~subtitle ~fill ~border ~rows;
  List.iter refs ~f:(fun (field, tn) ->
      dot_edge b ~src:id ~dst:(type_id tn) ~label:field)

let dot_of_eprog eprog =
  let b = Buffer.create 4096 in
  let aliases = eprog.ealiases in
  buf_add b "digraph ontology {\n";
  buf_add b "  graph [overlap=prism, splines=true, sep=\"+8\", dpi=96, bgcolor=\"white\"];\n";
  buf_add b "  node [shape=plaintext, fontname=\"Helvetica\", fontsize=11];\n";
  buf_add b "  edge [fontname=\"Helvetica\", fontsize=9, color=\"#8a8a8a\", fontcolor=\"#5f6368\"];\n";
  Map.iteri aliases ~f:(fun ~key ~data -> dot_of_type b aliases key data);
  List.iter (declared_events eprog) ~f:(fun (name, data) ->
      dot_of_event b aliases name data);
  buf_add b "}\n";
  Buffer.contents b

exception Graphviz_error of string

(* Pipes the diagram through Graphviz, which writes the PNG itself *)
let to_png filename eprog =
  let cmd = Printf.sprintf "%s -Tpng -o %s" engine (Filename.quote filename) in
  let oc = try Core_unix.open_process_out cmd with
           | Core_unix.Unix_error (e, _, _) ->
              raise (Graphviz_error (Core_unix.Error.message e)) in
  Out_channel.output_string oc (dot_of_eprog eprog);
  match Core_unix.close_process_out oc with
  | Ok ()      -> ()
  | Error _ ->
     raise (Graphviz_error
              (Printf.sprintf
                 "'%s' failed. Is Graphviz (https://graphviz.org) installed and on the PATH?"
                 engine))
