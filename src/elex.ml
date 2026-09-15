open Core

module Patt = Pattern

open Lex
open Tlex

let debug_elex = ref true
let debug msg = if !debug_elex then Errors.debug_print ~f_name:(Some "elex.ml") msg
 
(* Temporal patterns *)

module Pattern = Patt.Make(Eformula.Info)(Term.StringVar)(Dom)(ETerm)

let epatt_of_tpatt = function
  | Tlex.Pattern.PPresent -> Pattern.PPresent
  | PEventually i         -> PEventually i
  | PAlways i             -> PAlways i
  | PUntil (i, f)         -> PUntil (i, Eformula.of_tformula f)
  | POnce i               -> POnce i
  | PHistorically i       -> PHistorically i
  | PSince (i, f)         -> PSince (i, Eformula.of_tformula f)

let epf_of_tpf (tpf: Tlex.Pattern.t): Pattern.t =
  { fs   = List.map tpf.fs ~f:Eformula.of_tformula;
    patt = epatt_of_tpatt tpf.patt }

(* Rule declarations *)

type erule =
  | EObligation   of LexingInfo.t * int
  | EPermission   of LexingInfo.t * int
  | EConstitutive of LexingInfo.t * (int * int) list
  | EException    of LexingInfo.t * int
  | EScope        of LexingInfo.t * int
  | EExceptionC   of LexingInfo.t * int * (int * int) list

type edisjunct = {
  rule_id:         int;
  rule_type:       trule_type;
  rule_pos:        LexingInfo.t;
  def_pos:         LexingInfo.t;
  pf:              Pattern.t;
  exceptions:      Eformula.t list;                                   (* list of predicates *)
  scopes:          Eformula.t list;                                   (* list of predicates *)
  fv_renaming:     (string, string, String.comparator_witness) Map.t; (* renaming of free variables *)
  params_original: ETerm.t list;                                      (* list of the original terms*)
  params_new:      ETerm.t list;                                      (* list of the new terms*)
}

let edisjunct_of_tdisjunct (td: tdisjunct) = {
  rule_id         = td.rule_id;
  rule_type       = td.rule_type;
  rule_pos        = td.rule_pos;
  def_pos         = td.def_pos;
  pf              = epf_of_tpf td.pf;
  exceptions      = List.map td.exceptions ~f:Eformula.of_tformula;
  scopes          = List.map td.scopes ~f:Eformula.of_tformula;
  fv_renaming     = td.fv_renaming;
  params_original = ETerm.of_tterms td.params_original;
  params_new      = ETerm.of_tterms td.params_new;
}

type enf_pformula_sup =
  | ESpfFormula  of int
  | ESpfPformula of int (* for until and since, if both sides must be used for enforcement *)
  | ESpfPattern         (* for until and since, if it suffices to use the formula in the pattern for enforcement *)

type enf_pformula_cau =
  | ECpfFormulas
  | ECpfPformula        (* for until and since, if the formula of the pattern must also be used for enforcement *)
  | ECpfPattern         (* for until and since, if it suffices to enforce the formula in the pattern *)

(* A 'lhs' (left-hand side) consists of exception predicates, scope predicates, and a pformula (pattern + formulas) *)
type enf_sup_lhs =
  | ESlhsSPformula  of enf_pformula_sup
  | ESlhsCException of int (* leads to suppressing the constitution of an event *)
  | ESlhsSScope     of int

type enf_cau_lhs =
  | EClhsAll of enf_pformula_cau

type enf_pformula =
  | EpfSup of enf_pformula_sup
  | EpfCau of enf_pformula_cau

type enf_ecimplication =
  | ESciLhs of enf_sup_lhs
  | ECciRhs of enf_pformula_cau

type enf_ecdefinition =
  | ESd of enf_sup_lhs
  | ECd of enf_cau_lhs

type enf_ecdefinition_dis =
  | ESdd of enf_sup_lhs list
  | ECdd of int * enf_cau_lhs

type ecrule =
  | ECImplication   of int * trule_type * LexingInfo.t * Pattern.t * Eformula.t list * Eformula.t list * Pattern.t * rule_type * rule_constr list * enf_ecimplication option
  | ECDefinitionRef of int * trule_type * LexingInfo.t * Pattern.t * Eformula.t list * Eformula.t list * Ref.t list * Eformula.t * Enftype.t * enf_ecdefinition option
  | ECDefinitionDis of (int, edisjunct, Int.comparator_witness) Map.t * Eformula.t * Enftype.t * enf_ecdefinition_dis option

(* Statements and programs *)

type estmt =
  | ESImport  of LexingInfo.t * string list * import_format
  | ESSection of section_kind * Label.t * string * string tannot option
  | ESRule    of LexingInfo.t * int * Label.t * (ident * TypeTerm.t) list * erule * string tannot option
  | ESEvent   of event_type * ident * (ident * TypeTerm.t) list * (Enftype.t * bool) * string option
  | ESType    of ident * TypeTerm.t option * string option
  | ESFunction of ident * (ident * TypeTerm.t) list * TypeTerm.t * string option
  | ESNote    of string

type eprog =
  {
    estmts:            estmt list;
    ealiases:          (ident, TypeTerm.t option * string option, Base.String.comparator_witness) Map.t;
    (* maps type aliases to their underlying type *)
    esubtypes:         (ident, TypeTerm.ttt, Base.String.comparator_witness) Map.t;
    (* maps subtypes to their supertypes *)
    eevents:           (ident, tevent, Base.String.comparator_witness) Map.t;
    (* maps event names to their definitions *)
    efunctions:        (ident, tfunction, Base.String.comparator_witness) Map.t;
    (* maps function names to their definitions *)
    rule_ctxts:        (int, ctxt, Int.comparator_witness) Map.t;
    (* maps rule labels to variables used in section *)
    rule_tree:         Label.RuleTree.s;
    ecrules:           (int, ecrule, Int.comparator_witness) Map.t;
    compilation_order: int list;
    pols:              (string, Enftype.t, Base.String.comparator_witness) Map.t;
    eassumed:          (ident, bool, Base.String.comparator_witness) Map.t;
    (* maps the events a refinement assumes to the value it assumes for them *)
  }

let eempty =
  {
    estmts            = [];
    ealiases          = Map.empty (module String);
    esubtypes         = Map.empty (module String);
    eevents           = Map.empty (module String);
    efunctions        = Map.empty (module String);
    rule_ctxts        = Map.empty (module Int); 
    rule_tree         = Label.RuleTree.empty;
    ecrules           = Map.empty (module Int);
    compilation_order = [];
    pols              = Map.empty (module String);
    eassumed          = Map.empty (module String);
  }

(* Importation helpers *)

let import eprog eprog' =
  let f ~key:_ = function `Both (x, _) | `Left x | `Right x -> Some x in
  { eprog with ealiases   = Map.merge eprog.ealiases eprog'.ealiases ~f;
               eevents    = Map.merge eprog.eevents eprog'.eevents ~f;
               efunctions = Map.merge eprog.efunctions eprog'.efunctions ~f;
               eassumed   = Map.merge eprog.eassumed eprog'.eassumed ~f }

let tprog_import tprog eprog' =
  let f ~key:_ = function `Both (x, _) | `Left x | `Right x -> Some x in
  { tprog with taliases   = Map.merge tprog.taliases eprog'.ealiases ~f;
               tevents    = Map.merge tprog.tevents eprog'.eevents ~f;
               tfunctions = Map.merge tprog.tfunctions eprog'.efunctions ~f }

(* Deconstructors for rules *)

let get_obligation_params ecrules = function
  | EObligation (_, c_idx) ->
    (match Map.find_exn ecrules c_idx with
      | ECImplication (_, _, _, pf1, _, _, pf2, rt, rcs, _) -> (pf1, pf2, rt, rcs)
      | _ -> assert false)
  | _ -> assert false

let get_permission_params ecrules = function
  | EPermission (_, c_idx) ->
    (match Map.find_exn ecrules c_idx with
      | ECImplication (_, _, _, pf1, _, _, pf2, rt, rcs, _) -> (pf1, pf2, rt, rcs)
      | _ -> assert false)
  | _ -> assert false

let get_constitutive_params ecrules = function
  | EConstitutive (_, cs) ->
    let c_rules = List.map cs ~f:(fun (c_idx,_) -> Map.find_exn ecrules c_idx) in
    let d_indices = List.map cs ~f:(fun (_,d_idx) -> d_idx) in
    let g = List.map c_rules ~f:(fun r -> match r with
              | ECDefinitionDis (_, g, _, _) -> g
              | _ -> assert false)
    in
    let aux = function
      | ECDefinitionDis (disjuncts, _, _, _), d_idx -> Map.find_exn disjuncts d_idx
      | _ -> assert false
    in
    let disjuncts = List.zip_exn c_rules d_indices |> List.map ~f:aux in
    let g = List.map2_exn disjuncts g ~f:(fun d g -> match g.form with
      | Predicate (e, _) -> { g with form = Predicate (e, d.params_original) }
      | _ -> assert false)
    in
    let d = List.hd_exn disjuncts in
    let pf = d.pf in
    (pf, g)
  | _ -> assert false

let get_exception_params ecrules = function
  | EException (_, c_idx) ->
    (match Map.find_exn ecrules c_idx with
      | ECDefinitionRef (_, _, _, pf, _, _,  erefs, _, _, _) -> (pf, erefs)
      | _ -> assert false)
  | _ -> assert false

let get_scope_params ecrules = function
  | EScope (_, c_idx) ->
    (match Map.find_exn ecrules c_idx with
      | ECDefinitionRef (_, _, _, pf, _, _, erefs, _, _, _) -> (pf, erefs)
      | _ -> assert false)
  | _ -> assert false

let get_exceptionc_params ecrules = function
  | EExceptionC (_, c_idx_ex, cs) ->
    let c_rule_ex = Map.find_exn ecrules c_idx_ex in
    let c_rules = List.map cs ~f:(fun (c_idx,_) -> Map.find_exn ecrules c_idx) in
    let pf, erefs = (match c_rule_ex with
      | ECDefinitionRef (_, _, _, pf, _, _, erefs, _, _, _) -> (pf, erefs)
      | _ -> assert false)
    in (* TODO: check that f is the same collection of formulas as in the constitutive rules, and don't just assume so *)
    let g = List.map c_rules ~f:(fun r -> match r with
              | ECDefinitionDis (_, g, _, _) -> g
              | _ -> assert false)
    in
    (pf, erefs, g)
  | _ -> assert false

(* Signature *)

module Sig : MFOTL_lib.Modules.S = struct

  type term

  type pred_kind = Trace | Predicate | External | Builtin | Let
                   [@@deriving compare, sexp_of, hash, equal]

  let prog = ref (eempty: eprog) 
  (*let set_prog p = prog := p*)
  
  let rank_of_pred p_name =
    let _, args, _, _ = Map.find_exn !prog.eevents p_name in
    List.length args
    
  let mem p_name =
    Map.mem !prog.eevents p_name

  let enftype_of_pred p_name =
    let _, _, (enftype, _), _ = Map.find_exn !prog.eevents p_name in
    enftype

  let kind_of_pred p_name =
    let event_type, _, _, _ = Map.find_exn !prog.eevents p_name in
    match event_type with
    | Event _ | Exception -> Trace
    | Predicate -> Predicate

  let pred_enftype_map () =
    Map.map !prog.eevents
      ~f:(fun data -> let _, args, (enftype, _), _ = data in
                      (enftype, List.init (List.length args) ~f:(fun x -> x)))

  let strict_of_func _ = false
  
  let add_letpred_empty _ = assert false
  
  let update_enftype p_name enftype =
    prog := {
        !prog with
        eevents = Map.update !prog.eevents p_name
                    ~f:(function
                      | Some data -> let event_type, args, (_, itl), ds = data in
                                     (event_type, args, (enftype, itl), ds)
                      | None -> assert false)
      }

end

(* Printing functions *)

let verb_of_erule = function
  | EObligation _ -> "oblige"
  | EPermission _ -> "permit"
  | EConstitutive _ -> "constitute"
  | EException _ 
    | EExceptionC _ -> "except"
  | EScope _ -> "scope"

let string_of_erule ecrules i erule =
  let open Pattern in 
  let to_string f = Util.tabs (i+1) ^ Eformula.to_string f in
  let reference_to_string ref_ = Util.tabs (i+1) ^ Lex.Ref.to_string ref_ in
  let string_of_formula_list f =
    String.concat ~sep:"\n" (List.map ~f:to_string f) ^ "\n" in
  let string_of_reference_list refs =
    String.concat ~sep:"\n" (List.map ~f:reference_to_string refs) ^ "\n" in
  (*let string_of_formula_list_list fs =
    String.concat ~sep:("\n" ^ Util.tabs i ^ "or\n") (List.map ~f:string_of_formula_list fs) in*)
  let string_of_imp_rule verb pf1 pf2 rcs rt =
    Util.tabs i     ^ "whenever" ^ Pattern.patt_to_string pf1.patt ^ "\n"
    ^ string_of_formula_list pf1.fs                         
    ^ Util.tabs i   ^ verb       ^ Pattern.patt_to_string pf2.patt ^ "\n"
    ^ string_of_formula_list pf2.fs
    ^ Util.tabs i ^ string_of_rule_type rt (* TODO: check that this prints the rule_type correctly *)
    ^ (if List.is_empty rcs then "" (* TODO: check that this prints the rule_constr list correctly *)
      else Util.tabs i ^ (string_of_rule_constrs rcs))
  in
  let string_of_cons_rule verb pf g =
    Util.tabs i     ^ "whenever" ^ Pattern.patt_to_string pf.patt ^ "\n"
    ^ string_of_formula_list pf.fs  ^ Util.tabs i   ^ verb        ^ "\n"
    ^ string_of_formula_list g
  in
  let string_of_ref_rule verb pf refs =
    Util.tabs i     ^ "whenever" ^ Pattern.patt_to_string pf.patt ^ "\n"
    ^ string_of_formula_list pf.fs                                ^ "\n"
    ^ Util.tabs i   ^ verb                                        ^ "\n"
    ^ string_of_reference_list refs
  in
  let string_of_refc_rule verb pf refs g =
    Util.tabs i     ^ "whenever"  ^ Pattern.patt_to_string pf.patt ^ "\n"
    ^ string_of_formula_list pf.fs
    ^ Util.tabs i   ^ verb                                         ^ "\n"
    ^ string_of_reference_list refs                     
    ^ Util.tabs i   ^ "constitute"                                 ^ "\n"
    ^ string_of_formula_list g
  in
  match erule with
  | EObligation _ ->
    let pf1, pf2, rt, rcs = get_obligation_params ecrules erule in
    string_of_imp_rule (verb_of_erule erule) pf1 pf2 rcs rt
  | EPermission _ ->
    let pf1, pf2, rt, rcs = get_obligation_params ecrules erule in
    string_of_imp_rule (verb_of_erule erule) pf1 pf2 rcs rt
  | EConstitutive _ ->
    let pf, g = get_constitutive_params ecrules erule in
    string_of_cons_rule (verb_of_erule erule) pf g
  | EException _ ->
    let pf, erefs = get_exception_params ecrules erule in
    string_of_ref_rule (verb_of_erule erule) pf (List.map ~f:Tlex.Ref.to_lex_ref erefs)
  | EExceptionC _ ->
    let pf, erefs, g = get_exceptionc_params ecrules erule in
    string_of_refc_rule (verb_of_erule erule) pf (List.map ~f:Tlex.Ref.to_lex_ref erefs) g
  | EScope _ ->
    let pf, erefs = get_exception_params ecrules erule in
    string_of_ref_rule (verb_of_erule erule) pf (List.map ~f:Tlex.Ref.to_lex_ref erefs)

let string_of_estmt ecrules ?(i=0) =
  function
  | ESImport (_, idents, _) ->
     Printf.sprintf "import %s"
       (String.concat ~sep:"." idents)
  | ESSection (section_kind, _, label, title) ->
     Printf.sprintf "%s%s \"%s\"%s"
       (Util.tabs i)
       (string_of_section_kind section_kind)
       label
       (match title with Some title -> Printf.sprintf ": \"%s\"" (of_annot title) | None -> "")
  | ESRule (_, _, label, type_fixes, rule, doc_string) ->
     let description =
          match doc_string with
          | Some s -> "\n" ^ make_doc_string (of_annot s) i
          | None -> ""
      in
      Printf.sprintf "%srule %s\n%s%s\n%s"
        (Util.tabs i)
        (Label.qualified_name label)
        (string_of_type_fixes (i+1) type_fixes)
        (try string_of_erule ecrules (i+1) rule with _ -> "")
       description
  | ESEvent (event_type, name, typed_args, (enftype, itl), doc_string) ->
      let description =
          match doc_string with
          | Some s -> make_doc_string s i
          | None -> ""
      in
      Printf.sprintf "%s%s%s %s %s\n%s%s"
          (Util.tabs i)
          (Enftype.to_string enftype)
          (if itl then " internal" else "")
          (string_of_event_type event_type)
          name
          description
          (string_of_args typed_args i)
  | ESType (name, typ, doc_string) ->
      let description =
          match doc_string with
          | Some s -> make_doc_string s i
          | None -> "" in
      let typ_string =
       match typ with
       | Some tt -> " is " ^ TypeTerm.to_string tt
       | None -> "" in
     Printf.sprintf "%stype %s%s%s"
       (Util.tabs i) name typ_string description
  | ESFunction (name, typed_args, return_typ, doc_string) ->
     let description =
          match doc_string with
          | Some s -> "\n" ^ make_doc_string s i
          | None -> ""
     in
     let f (ident, typ) =
       Printf.sprintf "%s : %s" ident (TypeTerm.to_string typ) in
     Printf.sprintf "%sfunction %s(%s) -> %s%s"
       (Util.tabs i)
       name
       (String.concat ~sep:", " (List.map typed_args ~f))
       (TypeTerm.to_string return_typ)
       description
  | ESNote text -> "note \"" ^ text ^ "\""
    
let string_of_eprog eprog =
  String.concat ~sep:"\n" (List.map eprog.estmts ~f:(string_of_estmt eprog.ecrules))

let print_eprog eprog =
  Stdio.printf "%s\n" (string_of_eprog eprog)
    
