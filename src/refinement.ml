open Core
open Tlex
open Trex
open Erex

module Interval = MFOTL_lib.Interval
module Enftype = MFOTL_lib.Enftype

let debug_refinement = ref true
let debug msg = if !debug_refinement then Errors.debug_print ~f_name:(Some "refinement.ml") msg

(* Visitors *)

let type_trrule : trrule -> errule = function
  | TRefine (pos', pf, g) -> ERefine (pos', Elex.epf_of_tpf pf, Eformula.of_tformulas g)

let type_estmt erule_map : trtmt -> ertmt = function
  | TRStmt tstmt ->
    ERStmt (Enforceability.type_tstmt erule_map tstmt)
  | TRRule (pos, i, label, type_fixes, trrule, doc_string) ->
    ERRule (pos, i, label, type_fixes, type_trrule trrule, doc_string)
  | TRType (pos, name, typ, doc_string) ->
    ERType (pos, name, typ, doc_string)
  | TRReplace (pos, kind, refs1, refs2, doc_string) ->
    ERReplace (pos, kind, refs1, refs2, doc_string)
  | TRAssume (pos, name, b, doc_string) ->
    ERAssume (pos, name, b, doc_string)

let insert_refinement_rules (trefi: trefi) (tprog: tprog) : tprog Errors.OrErrors.t =
  let open Errors.OrErrors in
  let rule_ctxts = List.fold_left trefi.trvars_to_add
                      ~init:tprog.rule_ctxts
                      ~f:(fun m (key, data) -> Map.add_exn m ~key ~data) in
  let* rule_tree = fold_best_effort trefi.trrules_to_add
                     ~init:tprog.rule_tree
                     ~f:(fun s (pos, ri, label) -> Label.RuleTree.add_rule pos ri label s) in
  let tstmts     = trefi.tprog.tstmts @ trefi.trstmts_to_add in
  ok { trefi.tprog with rule_ctxts; rule_tree; tstmts }
  
let update_types (trefi: trefi) (tprog: tprog) : tprog =
  let f ~key ~data taliases = Map.update taliases key ~f:(fun _ -> data) in
  let taliases = Map.fold trefi.traliases ~init:tprog.taliases ~f in
  { tprog with taliases }

let insert_assumed_event_rules (trefi: trefi) (tprog: tprog) : tprog =
  let make_tsrule b (pos, name, label) =
    let (_, vars, _, _) = Map.find_exn tprog.tevents name in
    let f (x, typ) = TTerm.make (TTerm.var x) { pos; typ } in
    let pred = Tformula.make_dummy (Tformula.Predicate (name, List.map ~f vars)) in
    let idx = Typing.fresh () in
    let fb = if b then Tformula.TT else Tformula.FF in
    let trule = TConstitutive (
                    pos,
                    Tlex.Pattern.make PPresent [Tformula.make_dummy fb],
                    [pred]
                  ) in
    TSRule (pos, idx, label, [], trule, None) in
  let f tprog (pos, name, b, label) =
    let tsrule = make_tsrule b (pos, name, label) in
    (*print_endline ("insert_assumed_event_rules");
      print_endline (LexingInfo.to_string pos);
      print_endline (string_of_tstmt tsrule);*)
    { tprog with tstmts = tprog.tstmts @ [tsrule] } in
  List.fold_left ~init:tprog ~f trefi.trassumed

let internalize_events (trefi: trefi) (tprog: tprog) : tprog =
  let internalize_event name tprog =
    let update_event (event_type, params, (enftype, _), doc_string) =
      (event_type, params, (enftype, true), doc_string) in
    let tevents = 
      Map.update tprog.tevents name
        ~f:(function None -> assert false | Some ev -> update_event ev) in
    { tprog with tevents }
  in List.fold_right ~init:tprog ~f:internalize_event (Set.elements trefi.trrefined)

let replace_rules (trefi: trefi) (tprog: tprog) : tprog Errors.OrErrors.t =
  let open Errors.OrErrors in
  let refs = List.concat_map trefi.trreplacements ~f:(fun (_, _, refs1, _) -> refs1) in
  let rtref_exprs = List.map ~f:Ref.to_rtref_expr refs in
  let* rules_idx_to_replace =
    all (List.map rtref_exprs ~f:(fun ref ->
             Label.RuleTree.find_rules_in_tree ref.pos ref.label tprog.rule_tree.tree))
    >| List.concat in
  let f = function
    | TSRule (_, idx, _, _, _, _) -> not (List.mem rules_idx_to_replace idx ~equal:Int.equal)
    | _ -> true in
  let tstmts = List.filter ~f tprog.tstmts in
  ok { tprog with tstmts }

let inherit_ex_or_sc_trreplacement ref_kind
                                   (tprog: tprog)
                                   ((pos, _, old_refs, new_refs): LexingInfo.t * Rex.replace_kind * Tlex.Ref.t list * Tlex.Ref.t list)
                                   : tprog Errors.OrErrors.t =
  let open Errors.OrErrors in
  let trules_from_ids (tprog: tprog) (ids: int list) : trule list Errors.OrErrors.t =
    let open Errors.OrErrors in
    all (List.map ~f:(Tlex.find_trule_by_id tprog) ids) in
  let string_of_ref_kind = match ref_kind with
                            | `Exceptions -> "exceptions"
                            | `Scopes -> "scopes" in
  let old_ex_or_sc = match ref_kind with
                      | `Exceptions -> tprog.rule_tree.exceptions
                      | `Scopes -> tprog.rule_tree.scopes in
  let rule_ids_in_refs =
    let f (ref: Tlex.Ref.t) = Label.RuleTree.find_rules_in_tree ref.pos ref.label tprog.rule_tree.tree in
    List.map ~f in
  let* old_trule_ids = rule_ids_in_refs old_refs |> all in
  let old_trule_ids = List.concat old_trule_ids in
  let* new_trule_ids = rule_ids_in_refs new_refs |> all in
  let new_trule_ids = List.concat new_trule_ids in
  let* old_trules = trules_from_ids tprog old_trule_ids in
  let* new_trules = trules_from_ids tprog new_trule_ids in
  let string_of_old_trules = List.map ~f:(Label.RuleTree.string_of_rule_idx tprog.rule_tree) old_trule_ids in
  let ex_or_sc_of_old_trules = List.map ~f:(Map.find_multi old_ex_or_sc) old_trule_ids in
  let string_ex_or_sc_of_old_trules =
    List.map ~f:(List.map ~f:(Label.RuleTree.string_of_rule_idx tprog.rule_tree)) ex_or_sc_of_old_trules in
  let strings_of_ex_or_sc_of_old_trules =
    List.map ~f:(String.concat ~sep:"\t\n") string_ex_or_sc_of_old_trules in
  let strings_of_old_trules_with_ex_or_sc = 
    let f old_trule_string ex_or_sc_string =
      Printf.sprintf "The 'old' referenced rule %s has the %s:\n%s"
        string_of_ref_kind
        old_trule_string
        ex_or_sc_string in
    List.map2_exn string_of_old_trules strings_of_ex_or_sc_of_old_trules ~f in
  let* old_unified_ex_or_sc =
    match Util.all_int_lists_set_equality ex_or_sc_of_old_trules with
    | Some ex_or_sc -> ok ex_or_sc
    | None ->
      let msg =
        let s = String.concat ~sep:"\n" strings_of_old_trules_with_ex_or_sc in
        Printf.sprintf
        "Rules being replaced must have the same %s, but here we have the following rules with their respective exceptions:\n%s"
        string_of_ref_kind s
      in
      error (Errors.refinement_error msg pos)
  in
  let is_obligation = function
    | TObligation _ -> true
    | _ -> false in
  let old_only_obligation = List.for_all ~f:is_obligation old_trules in
  let new_trule_ids_filtered =
    if old_only_obligation then
      new_trule_ids
    else
      let f (id, trule) = if is_obligation trule then Some id else None in
      List.filter_map (List.zip_exn new_trule_ids new_trules) ~f (* TODO *)
  in
  let _ = if List.length new_trule_ids <> List.length new_trule_ids_filtered then
    let msg = Printf.sprintf "Note that the %s are only inherited for non-obligation rules, NO exceptions will apply to the new obligation(s) in this replacement" string_of_ref_kind in
    Errors.warn msg (Some pos)
  in
  let new_ex_or_sc = 
    List.fold ~init:old_ex_or_sc
      ~f:(fun ex_or_sc key ->
          List.fold old_unified_ex_or_sc ~init:ex_or_sc
            ~f:(fun ex_or_sc data -> Map.add_multi ex_or_sc ~key ~data))
      new_trule_ids_filtered in
  match ref_kind with
    | `Exceptions -> ok { tprog with rule_tree = { tprog.rule_tree with exceptions = new_ex_or_sc}}
    | `Scopes -> ok { tprog with rule_tree = { tprog.rule_tree with scopes = new_ex_or_sc }}

let inherit_reference_trreplacement (tprog: tprog)
                                    (replacement: LexingInfo.t * Rex.replace_kind * Tlex.Ref.t list * Tlex.Ref.t list)
                                    : tprog Errors.OrErrors.t =
  let open Errors.OrErrors in
  let* tprog' = inherit_ex_or_sc_trreplacement `Exceptions tprog replacement in
  let* tprog'' = inherit_ex_or_sc_trreplacement `Scopes tprog' replacement in
  ok tprog''

let inherit_references_trreplacements (trefi: trefi) (tprog: tprog) : tprog Errors.OrErrors.t =
  let open Errors.OrErrors in
  let* tprog' = Errors.OrErrors.fold trefi.trreplacements ~init:tprog ~f:inherit_reference_trreplacement in
  ok tprog'

(* Hide and replace *)

let hide_and_replace (trefi: trefi) (tprog: tprog) : tprog Errors.OrErrors.t =
  let open Errors.OrErrors in
  ok tprog
  >>= insert_refinement_rules trefi
  >| update_types trefi
  >| insert_assumed_event_rules trefi
  >| internalize_events trefi
  >>= inherit_references_trreplacements trefi
  >>= replace_rules trefi

(* Main typing function *)

let do_type (trefi: Trex.trefi) (b: Interval.v) : (Tlex.tprog * Erex.erefi) Errors.OrErrors.t =
  let open Errors.OrErrors in
  let* tprog = hide_and_replace trefi trefi.tprog in
  (*print_endline (Tlex.string_of_tprog tprog);*)
  let* eprog = Enforceability.do_type ~mon_constrs:(trefi.tr_mon, trefi.tr_anti_mon) tprog b in
  let erules = Enforceability.erules_from_tcrules (Enforceability.create_tcrules tprog) in
  (* The events whose value this refinement assumes, as opposed to the ones it
     merely internalizes. *)
  let eassumed =
    List.fold trefi.trassumed ~init:(Map.empty (module String))
      ~f:(fun m (_, name, b, _) -> Map.set m ~key:name ~data:b) in
  let erefi = {
    eprog = { eprog with eassumed };
    ertmts = List.map trefi.trtmts ~f:(type_estmt erules);
    lex_file = trefi.lex_file;
    base_file_type = trefi.base_file_type;
  } in
  ok (tprog, erefi)
