
(*******************************************************************)
(*     This is part of WhyEnf, and it is distributed under the     *)
(*     terms of the GNU Lesser General Public License version 3    *)
(*           (see file LICENSE for more details)                   *)
(*                                                                 *)
(*  Copyright 2024:                                                *)
(*  François Hublet (ETH Zurich)                                   *)
(*******************************************************************)

open Base
open Core

open Tformula
open Tlex
open Elex

module Interval = MFOTL_lib.Interval
module Enftype = MFOTL_lib.Enftype

let debug_enforceability = ref false
let debug msg = if !debug_enforceability then Errors.debug_print ~f_name:(Some "enforceability.ml") msg

(* Generators *)

let c1 = ref 0
let fresh_param () = incr c1; "_p" ^ string_of_int !c1

let c2 = ref 0
let fresh_free_var () = incr c2; "_fv" ^ string_of_int !c2

let b_ref = ref MFOTL_lib.Time.Span.zero

(* Topological sort *)

let def_sets (rules: (int, tcrule, 'a) Map.t) (events: (string, tevent, 'b) Map.t) : (int, string list, 'a) Map.t Errors.OrErrors.t =
  let open Errors.WithErrors in
  let rules_list = Map.to_alist rules in
  let aux (rule_id, tcrule) = match tcrule with
    | TCImplication _ -> ok (rule_id, [])
    | TCDefinitionRef (_, _, _, _, _, _, _, {form=Tformula.Predicate (name, _); _}) -> ok (rule_id, [name])
    | TCDefinitionRef _ -> assert false
    | TCDefinitionDis (disjuncts, {form=Tformula.Predicate (name, _); _}) ->
       let positions = Map.map disjuncts ~f:(fun d -> d.rule_pos) |> Map.data in
       let* _ =
         (match Map.find events name with
          | Some (_, _, (_, true), _) -> ok ()
          | Some (_, _, (pol, false), _) ->
             let err_msg =
               Printf.sprintf "Can only constitute 'Internal' events, but \"%s\" is \"%s\"\nat locations:\n%s"
                 name (Enftype.to_string pol) (List.map positions ~f:LexingInfo.to_string |> Util.string_of_string_list_new_line) in
             let pos = LexingInfo.union_all positions in
             error () (Errors.enforceability_error err_msg pos)
          | None -> (* TODO: is this even possible, i.e. could/should this be an `assert false` instead? *)
             let err_msg =
               Printf.sprintf "Unknown event \"%s\"\nat locations:\n%s"
                 name (List.map positions ~f:LexingInfo.to_string |> Util.string_of_string_list_new_line) in
             let pos = LexingInfo.union_all positions in
             error () (Errors.enforceability_error err_msg pos)
         ) in
       ok (rule_id, [name])
    | TCDefinitionDis _ -> assert false
  in
  let sets = all (List.map ~f:aux rules_list) in
  Errors.OrErrors.(of_witherror sets >>= (fun sets -> ok (Map.of_alist_exn (module Int) sets)))

let use_sets (rules: (int, tcrule, Int.comparator_witness) Map.t) (events: (string, tevent, Base.String.comparator_witness) Map.t) : (int, string list, 'a) Map.t =
  let use_formula (f: Tformula.t) =
    List.map ~f:fst (Tformula.predicates f)
    |> List.dedup_and_sort ~compare:String.compare 
    |> List.filter ~f:(fun name ->
           match Map.find events name with
           | Some (_, _, (_, true), _) -> true
           | _ -> false) in
  let use_formulas (fs: Tformula.t list) = List.concat_map fs ~f:use_formula in
  let use_pformulas pf = List.concat_map ~f:use_formula (Tlex.Pattern.formulas pf) in
  let use_disjunct (d: tdisjunct) = use_pformulas d.pf @ use_formulas (d.exceptions@d.scopes) in
  let use_disjuncts disjuncts = Map.map disjuncts ~f:use_disjunct |> Map.data |> List.concat in
  let aux = function
    | TCImplication (_, _, _, pf1, exceptions, scopes, pf2, _, _) ->
       use_pformulas pf1 @ use_pformulas pf2 @ use_formulas (exceptions@scopes) |> List.dedup_and_sort ~compare:String.compare
    | TCDefinitionRef (_, _, _, pf, exceptions, scopes, _, _) ->
      use_pformulas pf @ use_formulas (exceptions@scopes) |> List.dedup_and_sort ~compare:String.compare
    | TCDefinitionDis (disjuncts, _) ->
       use_disjuncts disjuncts |> List.dedup_and_sort ~compare:String.compare
  in
  Map.map rules ~f:aux

let collect_rule_indices (tprog: Tlex.tprog) =
  let aux l stmt =
    match stmt with
    | TSRule (_, idx, _, _, _, _) -> idx::l
    | _ -> l
  in
  List.fold tprog.tstmts ~f:aux ~init:[]

let topological_sort (rule_indices: int list) (def: (int, string list, 'a) Map.t) (use: (int, string list, 'a) Map.t) : int list Errors.OrErrors.t =
  let open Errors.OrErrors in
  (*debug (Printf.sprintf "topological_sort:\n\tdef: %s\n\tuse: %s"
           (Util.string_of_int_string_multimap def) (Util.string_of_int_string_multimap use));*)
  let def_inv = Util.invert_int_string_multimap def in
  let init, rest = List.partition_tf rule_indices ~f:(fun r -> not (Map.mem use r)) in
  (*all rules that do not 'use' any internal events*)
  let rec aux visited rest =
    match rest with
      | [] -> ok visited
      | _ ->
        let partition_function r1 =
          let condition_for_used_event e =
            let rules_defining_e = Map.find_multi def_inv e in
            let condition_for_rule_defining_e r2 =
              List.mem visited r2 ~equal:Int.equal
            in
            List.for_all rules_defining_e ~f:condition_for_rule_defining_e
          in
          let used_events_in_r1 = Map.find_multi use r1 in
          List.for_all used_events_in_r1 ~f:condition_for_used_event
          (* If all event used by rule r1 have been defined by rules already visited, then we can add r1 to the visited rules *)
        in
        let fully_defined, rest = List.partition_tf rest ~f:partition_function in
        let* _ = 
          begin match fully_defined with
          (* TODO: improve this error reporting, maybe report the actual cycle *)
          | [] -> error (Errors.enforceability_error "Circular dependency between events" LexingInfo.dummy)
          | _ -> ok ()
          end in
        (*debug ("visited:" ^ Util.string_of_int_list visited);
        debug ("fully_defined:" ^ Util.string_of_int_list fully_defined);
        debug ("rest:" ^ Util.string_of_int_list rest);*)
        aux (visited @ fully_defined) rest
    in
    let* order = aux init rest in
    debug (Printf.sprintf "topological_sort result: %s" (Util.string_of_int_list order));
    ok order

let check_used_events_are_defined (_: Tlex.tprog) def use : unit =
  let all_defined_events = List.concat (Map.data def)
                           |> List.dedup_and_sort
                              ~compare:String.compare in
  let check_used_are_defined idx =
    let used = Map.find_exn use idx in
    (*let pos = Map.find_exn tprog.rule_tree.label_of_rule idx |> snd in*)
    List.iter used ~f:(fun name ->
      if not (List.mem all_defined_events name ~equal:String.equal) then
        let warning = Printf.sprintf
            "Internal event \"%s\" is never constituted" name in
        Errors.warn warning None) in
  (*print_endline (String.concat ~sep:"\n" (List.map ~f:(fun (k, _) -> Int.to_string k) (Map.to_alist use)));*)
  Map.iter_keys use ~f:check_used_are_defined

let topological_rule_order (tprog:Tlex.tprog) (tcrules: (int, tcrule, 'a) Map.t) : int list Errors.OrErrors.t =
  let open Errors.OrErrors in
  let* def_internal = def_sets tcrules tprog.tevents in
  let use_internal = use_sets tcrules tprog.tevents in
  check_used_events_are_defined tprog def_internal use_internal;
  topological_sort (Map.keys tcrules) def_internal use_internal 

(* Computing tcrules *)

let get_exception_predicates ?(negated=false) (s: Tlex.tprog) (rule_idx: int) : t list =
  let exception_idxs = Map.find_multi s.rule_tree.exceptions rule_idx in
  let exception_predicates = List.map exception_idxs ~f:(try Map.find_exn s.exception_predicates with _ -> assert false) in
  if negated then
    List.map exception_predicates ~f:(fun f -> Tformula.make (Tformula.neg f) ({ Tformula.Info.dummy with pos = f.info.pos }))
  else exception_predicates

let get_scope_predicates (s: Tlex.tprog) (rule_idx: int) : t list = 
  let scope_idxs = Map.find_multi s.rule_tree.scopes rule_idx in
  List.map scope_idxs ~f:(try Map.find_exn s.scope_predicates with _ -> assert false)

let collect_constitutive_rules (tprog: Tlex.tprog) : (LexingInfo.t * int * trule * Tformula.t list * Tformula.t list) list =
  List.filter_map tprog.tstmts ~f:(function
    | TSRule (pos, idx, _, _, trule, _) ->
      let exceptions = get_exception_predicates ~negated:false tprog idx in
      let scopes = get_scope_predicates tprog idx in
      begin match trule with
        | TConstitutive _
        | TExceptionC _ ->
          Some (pos, idx, trule, exceptions, scopes)
        | _ -> None
      end
    | _ -> None)

let combine_constitutive_rules rules: tcrule list * 'params_map =
  let collect_and_separate_event_definitions (params_map, m) (rule_pos, rule_id, rule, exceptions, scopes) =
    let rule_type = match rule with
      | TConstitutive _ -> TRTConstitutive
      | TExceptionC _ -> TRTExceptionC
      | _ -> assert false
    in
    let separate_event_definitions pf ((params_map, m'): 'params_map * (string, 'a, 'b) Map.t) (f: Tformula.t) =
      match f.form with
      | Tformula.Predicate (name, terms) ->
         let fvs = Set.union_list (module String)
                     [fv f; Tformula.fvs (exceptions @ scopes); Tlex.Pattern.fv pf] in
         let params_new = match Map.find params_map name with
           | Some params -> params
           | None -> List.map terms
                       ~f:(fun trm -> let p = fresh_param () in
                                      TTerm.{ trm = (Var p); info = { typ = trm.info.typ; pos = LexingInfo.dummy } });
         in
         let params_map = Map.update params_map name ~f:(function
                              | Some params -> params
                              | None -> params_new)
         in
         let disjunct: tdisjunct =
           { rule_id; rule_type; rule_pos;
             def_pos = f.info.pos;
             pf; exceptions; scopes;
             fv_renaming     = Map.of_alist_exn (module String) (List.map (Set.elements fvs) ~f:(fun x -> (x, fresh_free_var ())));
             params_original = terms;
             params_new      = params_new 
           }
         in
        params_map, Map.add_multi m' ~key:name ~data:disjunct
      | _ -> assert false
    in
    match rule with
    | TConstitutive (_, pf1, f2)
    | TExceptionC (_, pf1, _, _, f2) ->
      List.fold f2 ~init:(params_map, m) ~f:(separate_event_definitions pf1)
    | _ -> assert false
  in
  let params_map, event_def_map =
    List.fold rules ~init:((Map.empty (module String)), (Map.empty (module String)))
      ~f:collect_and_separate_event_definitions in
  let to_tr_def_dis ((name, definitions): (string * 'defs)) =
    let disjunction =
      let f (m, k) (d: tdisjunct) = Map.add_exn m ~key:k ~data:d, k+1 in
      List.fold definitions ~init:(Map.empty (module Int), 0) ~f |> fst in
    let positions: (string, LexingInfo.t, 'string_comp) Map.t =
      let aux (d: tdisjunct) = d.def_pos in
      Map.map event_def_map ~f:(fun ds -> LexingInfo.union_all (List.map ~f:aux ds)) in
    let params = Map.find_exn params_map name in
    let pos = Map.find_exn positions name in
    let eg = make (predicate name params) { pos; event_type_opt = Some Lex.Predicate } in
    TCDefinitionDis (disjunction, eg)
  in
  Map.to_alist event_def_map |> List.map ~f:to_tr_def_dis, params_map

let create_def_dis_rules tprog =
  let constitutive_rules = collect_constitutive_rules tprog in
  combine_constitutive_rules constitutive_rules

let create_def_rules tprog =
  List.filter_map tprog.tstmts ~f:(function
    | TSRule (pos, idx, _, _, trule, _) ->
      let exceptions = get_exception_predicates ~negated:false tprog idx in
      let scopes = get_scope_predicates tprog idx in
      begin match trule with
        | TScope (_, pf1, r, f2)
          -> Some (TCDefinitionRef (idx, TRTScope, pos, pf1, exceptions, scopes, r, f2))
        | TException (_, pf1, r, f2)
          -> Some (TCDefinitionRef (idx, TRTException, pos, pf1, exceptions, scopes, r, f2))
        | TExceptionC (_, pf1, r, f2, _)
          -> Some (TCDefinitionRef (idx, TRTExceptionC, pos, pf1, exceptions, scopes, r, f2))
        | _ -> None
      end
    | _ -> None)

let create_imp_rules tprog =
  List.filter_map tprog.tstmts ~f:(function
    | TSRule (pos, idx, _, _, trule, _) ->
      let ex = get_exception_predicates ~negated:false tprog idx in
      let sc = get_scope_predicates tprog idx in
      begin match trule with
        | TObligation (_, pf1, pf2, rt, rcs)
          -> Some (TCImplication (idx, TRTObligation, pos, pf1, ex, sc, pf2, rt, rcs))
        | TPermission (_, pf1, pf2, rt, rcs)
          -> Some (TCImplication (idx, TRTPermission, pos, pf1, ex, sc, pf2, rt, rcs))
        | _ -> None
      end 
   | _ -> None)

let create_tcrules (tprog: Tlex.tprog) : (int, tcrule, Int.comparator_witness) Map.t =
  let def_dis_rules, _ = create_def_dis_rules tprog in
  let def_rules = create_def_rules tprog in
  let imp_rules = create_imp_rules tprog in
  (*debug (Printf.sprintf "DefDis rules: %d" (List.length def_dis_rules));
  debug (Printf.sprintf "DefRef rules: %d" (List.length def_rules));
  debug (Printf.sprintf "Imp rules: %d" (List.length imp_rules));*)
  List.fold (def_dis_rules @ def_rules @ imp_rules)
            ~init:((Map.empty (module Int), 0))
            ~f:(fun (m,i) r -> (Map.add_exn m ~key:i ~data:r, i+1))
  |> fst


(* Visitors: computing a verdict *)

module Err = Errors

open Tformula.MFOTL_Enforceability(Tlex.Sig)
open Constraints

let types_transparent (f: Tformula.typed_t) : verdict =
  if is_transparent f then
    Impossible (Errors.EFormula
                  (Some "this formula is not transparently enforceable",
                   Tformula.untyped f, f.info.enftype))
  else
    Possible CTT

let get_types_fun itl_srp (enftype: Enftype.t) (pg_map: pg_map) (f: Tformula.t) : verdict =
  match itl_srp with
  | Some (itl_itvs, itl_strict, itl_observable) ->
     types ~itl_itvs ~itl_strict ~itl_observable enftype pg_map f
  | None ->
     types enftype pg_map f

let type_tformulas_conj (pg_map: pg_map) itl_srp (fs: Tformula.t list) (enftype: Enftype.t) : verdict =
  let types_fun = get_types_fun itl_srp in
  (*debug ("type_tformulas: (formulas: " ^ String.concat ~sep:", " (List.map ~f:Tformula.to_string fs) ^ ") type: " ^ Enftype.to_string enftype);*)
  match Enftype.is_causable enftype, Enftype.is_suppressable enftype, itl_srp with
  | true, _, _ ->
     List.map fs ~f:(types_fun enftype pg_map)
    |> List.fold ~f:conj ~init:(Possible CTT)
  | _, true, Some (itl_itvs, itl_strict, itl_observable) ->
    (* transparency requires that other formulas are SRP *)
    let srp = strictly_relative_past ~itl_itvs ~itl_strict ~itl_observable in
    let are_others_srp = Util.lists_with_one_removed fs |> List.map ~f:(List.for_all ~f:srp) in
    let is_srp_to_verdict f = function
      | true -> Possible CTT
      | false ->
        let msg = Printf.sprintf "the conjunction of exception predicates is transparently enforceable when all predicates besides the one used for enforcement (%s) are transparently enforceable, but at least one of them is not transparently enforceable" (Tformula.to_string f) in
        Impossible (EFormula (Some msg, f, enftype))
    in
    let types_and_srp f srp = conj (types_fun enftype pg_map f) (is_srp_to_verdict f srp) in
    let vs = List.map2_exn fs are_others_srp ~f:types_and_srp in
    Constraints.disjs vs
  | _, true, None -> disjs (List.map fs ~f:(types_fun enftype pg_map))
  | _ -> Possible CTT

let type_pattern itl_srp pos (pg_map: pg_map) enftype (tpf: Tlex.Pattern.t) : verdict =
  let types_fun = get_types_fun itl_srp in
  let err s =
    Impossible (Errors.ERule (Printf.sprintf s (Tlex.Pattern.to_string tpf) (LexingInfo.to_string pos))) in
  let is_cau = Enftype.is_causable enftype in
  let is_sup = Enftype.is_suppressable enftype in
  match is_cau, is_sup with
  | true, _ ->
    begin match tpf.patt with
    | PPresent -> type_tformulas_conj pg_map itl_srp tpf.fs enftype
    | PEventually _ -> type_tformulas_conj pg_map itl_srp tpf.fs enftype
    | PAlways _ -> type_tformulas_conj pg_map itl_srp tpf.fs enftype
    | PUntil (i, _) when Interval.is_bounded i && Interval.has_zero i ->
       type_tformulas_conj pg_map itl_srp tpf.fs enftype
    | PUntil (i, g) when Interval.is_bounded i ->
       conj (types enftype pg_map g) (type_tformulas_conj pg_map itl_srp tpf.fs enftype) 
    | PUntil _ -> err "for causability the interval in pattern %s at %s must be bounded"
    | POnce i when Interval.has_zero i ->
       type_tformulas_conj pg_map itl_srp tpf.fs enftype
    | POnce _ -> err "for causability the interval in pattern %s at %s must contain zero"
    | PHistorically _ -> err "the pattern %s at %s can never be made causable"
    | PSince (i, g) when Interval.has_zero i -> types_fun enftype pg_map g
    | PSince _ -> err "for causability the interval in pattern %s at %s must contain zero"
    end
  | _, true ->
    begin match tpf.patt with
    | PPresent -> type_tformulas_conj pg_map itl_srp tpf.fs enftype
    | PEventually _ -> type_tformulas_conj pg_map itl_srp tpf.fs enftype
    | PAlways _ -> type_tformulas_conj pg_map itl_srp tpf.fs enftype
    | PUntil _ -> type_tformulas_conj pg_map itl_srp tpf.fs enftype
    | POnce _ -> err "the pattern %s at %s can never be made suppressable"
    | PHistorically _ -> type_tformulas_conj pg_map itl_srp tpf.fs enftype
    | PSince (i, g) when Interval.has_zero i ->
       type_tformulas_conj pg_map itl_srp tpf.fs enftype |> conj (types_fun Enftype.causable pg_map g)
    | PSince _ -> type_tformulas_conj pg_map itl_srp tpf.fs enftype (* when not (Interval.has_zero i) *)
    end
  | _ -> Possible CTT

let pols_from_rule_constraints pos (rcs: Lex.rule_constr list) : 'pols option Err.WithErrors.t =
  let open Err.WithErrors in
  let add_policy_constraint (enftype: Enftype.t) (pols: 'pols) : Lex.rule_constr_kind -> 'pols Err.WithErrors.t =
    function
    | Lex.CEvent id -> begin
      match Map.find pols id with
        | Some enftype' when Enftype.equal enftype enftype' ->
          let warning = Printf.sprintf "Event \"%s\" is marked as \"%s\" multiple times" id (Enftype.to_string enftype) in
          Err.warn warning (Some pos);
          ok pols
        | _ when Enftype.is_causable enftype && Enftype.is_suppressable enftype ->
          let err_msg = Printf.sprintf "Cannot mark event \"%s\" as both suppressing and causing" id in
          error pols (Err.enforceability_error err_msg pos)
        | Some _ -> assert false
        | None -> ok (Map.add_exn pols ~key:id ~data:enftype)
      end
    | _ -> ok pols
  in
  let aux (pols: 'pols) : Lex.rule_constr -> 'pols Err.WithErrors.t = function
    | Lex.Suppressing constr_kind ->
       fold constr_kind ~f:(add_policy_constraint Enftype.suppressable) ~init:pols
    | Lex.Causing constr_kind ->
       fold constr_kind ~f:(add_policy_constraint Enftype.causable) ~init:pols
  in
  let make_option (pols: 'pols) : 'pols option =
    if Map.is_empty pols then None
    else Some pols in
  fold rcs ~f:aux ~init:(Map.empty (module String))
  >| make_option

let causing_effects pos rcs =
  let open Err.WithErrors in
  let filter_effects = function
    | Lex.CEffects -> true
    | _ -> false
  in
  let aux = function
    | Lex.Causing constr_kind ->
       ok (List.filter constr_kind ~f:filter_effects)
    | Lex.Suppressing constr_kind ->
      if List.exists constr_kind ~f:filter_effects then
        let err_msg = "Cannot enforce (cause) a rule by suppressing its effects"  in
        error [] (Err.enforceability_error err_msg pos)
      else
        ok []
  in
  all (List.map rcs ~f:aux) >| List.concat >>=
    (function
     | [Lex.CEffects] -> ok true
     | Lex.CEffects::_ ->
        let warning = "\"causing effects\" is specified multiple times" in
        Err.warn warning (Some pos);
        ok true
     | [] -> ok false
     | _ -> assert false)

let suppressing_conditions pos rcs =
  let open Err.WithErrors in
  let filter_conditions = function
    | Lex.CConditions -> true
    | _ -> false
  in
  let aux = function
    | Lex.Suppressing constr_kind ->
       ok (List.filter constr_kind ~f:filter_conditions)
    | Lex.Causing constr_kind ->
      if List.exists constr_kind ~f:filter_conditions then
        let err_msg = "Cannot enforce (cause) a rule by causing its conditions"  in
        error [] (Err.enforceability_error err_msg pos)
      else
        ok []
  in
  all (List.map rcs ~f:aux) >| List.concat >>=
    (function
     | [Lex.CConditions] -> ok true
     | Lex.CConditions::_ ->
        let warning = "\"suppressing conditions\" is specified multiple times" in
        Err.warn warning (Some pos);
        ok true
     | [] -> ok false
     | _ -> assert false)

let causing_exceptions pos rcs : bool Err.WithErrors.t =
  let open Err.WithErrors in
  let filter_exceptions = function
    | Lex.CExceptions -> true
    | _ -> false
  in
  let aux = function
    | Lex.Causing constr_kind ->
       ok (List.filter constr_kind ~f:filter_exceptions)
    | Lex.Suppressing constr_kind ->
      if List.exists constr_kind ~f:filter_exceptions then
        let err_msg = "Cannot enforce (cause) a rule by suppressing its exceptions"  in
        error [] (Err.enforceability_error err_msg pos)
      else
        ok []
  in
  all (List.map rcs ~f:aux) >| List.concat >>=
    (function
     | [Lex.CExceptions] -> ok true
     | Lex.CExceptions::_ ->
        let warning = "\"causing exceptions\" is specified multiple times" in
        Err.warn warning (Some pos);
        ok true
     | [] -> ok false
     | _ -> assert false)

let suppressing_scopes pos rcs =
  let open Err.WithErrors in
  let filter_scopes = function
    | Lex.CScopes -> true
    | _ -> false
  in
  let aux = function
    | Lex.Suppressing constr_kind ->
       ok (List.filter constr_kind ~f:filter_scopes)
    | Lex.Causing constr_kind ->
      if List.exists constr_kind ~f:filter_scopes then
        let err_msg = "Cannot enforce (cause) a rule by causing its scopes"  in
        error [] (Err.enforceability_error err_msg pos)
      else
        ok []
  in
  all (List.map rcs ~f:aux) >| List.concat >>=
    (function
     | [Lex.CScopes] -> ok true
     | Lex.CScopes::_ ->
        let warning = "\"suppressing scopes\" is specified multiple times" in
        Err.warn warning (Some pos);
        ok true
     | [] -> ok false
     | _ -> assert false)

let collect_suppressing_indices pos rcs =
  let open Err.WithErrors in
  let filter_indices = function
    | Lex.CCondition id -> Some id
    | _ -> None
  in
  let aux = function
    | Lex.Suppressing constr_kind ->
       ok (List.filter_map constr_kind ~f:filter_indices)
    | Lex.Causing constr_kind -> begin
      match List.filter_map constr_kind ~f:filter_indices with
        | [] -> ok []
        | ids ->
           let err_msg =
             Printf.sprintf
               "Cannot enforce (cause) a rule by causing a condition (conditions: \"%s\" are marked as causing)"
               (Util.string_of_int_list ids) in
           error [] (Err.enforceability_error err_msg pos)
      end
  in
  let* ids = all (List.map rcs ~f:aux) >| List.concat in
  let sorted_ids = List.dedup_and_sort ~compare:Int.compare ids in
  if List.length ids <> List.length sorted_ids then
    let warning = "Some condition(s) are marked as suppressing multiple times" in
    Err.warn warning (Some pos)
  else
    ();
  if List.is_empty sorted_ids then ok None
  else ok (Some sorted_ids)

let suppress_indices_are_in_range pos suppress_indices num_conditions =
  let open Err.WithErrors in
  match suppress_indices with
  | Some indices ->
    let index_out_of_range idx = num_conditions <= idx in
    let indices_out_of_range = List.filter indices ~f:index_out_of_range in
    if not (List.is_empty indices_out_of_range) then
      let err_msg = Printf.sprintf
        "Some condition indices are out of range: %s. There are only %d conditions, indices must be strictly less than that"
          (Util.string_of_int_list indices_out_of_range)
          num_conditions
      in
      error () (Err.enforceability_error err_msg pos)
    else
      ok ()
  | None -> ok ()

let update_suppress_indices_with_suppress_conditions pos suppress_indices suppress_conditions =
  if suppress_conditions && (Option.is_some suppress_indices) then
    let warning = Printf.sprintf
      "When \"suppressing conditions\" is used, \"suppressing condition[i]\" is redundant, but conditions: %s are explicitly marked as suppressing"
        (Util.string_of_int_list (Option.value_exn suppress_indices))
    in
    Err.warn warning (Some pos);
    None
  else suppress_indices

let vanilla_rule_constraints_warning pos rcs =
  if not (List.is_empty rcs) then
    let warning = "rule constraints (\"suppressing ...\" or \"causing ...\") are ignored for rules not marked as \"(transparently) enforceable" in
    Err.warn warning (Some pos)

let combine_cause_effects_and_suppress_conditions pos cause_effects suppress_conditions =
  match cause_effects, suppress_conditions with
    | true, true ->
      let warning = "Using both \"causing effects\" and \"suppressing conditions\" is redundant" in
      Err.warn warning (Some pos);
      true, true
    | true, false -> true, false
    | false, true -> false, true
    | false, false -> true, true (* if no constraints are given, the compiler will infer how to enforce a rule during typing *)

let string_of_suppressing_or_causing = function
  | enftype when Enftype.is_suppressable enftype -> "suppressing"
  | enftype when Enftype.is_causable enftype -> "causing"
  | _ -> assert false

let check_pol_constrs pos pol_constrs =
  let open Err.WithErrors in
  let check_pol_constr (id, enftype) = 
    match Tlex.Sig.mem id with
    | true ->
       let enftype' = Tlex.Sig.enftype_of_pred id in
       if not (Enftype.leq enftype enftype') then
         let err_msg = Printf.sprintf "Event \"%s\" is marked as \"%s\", but is defined as \"%s\"" id (string_of_suppressing_or_causing enftype) (Enftype.to_string enftype') in
         error () (Err.enforceability_error err_msg pos)
       else
         ok ()
    | false ->
        let err_msg = Printf.sprintf "Event \"%s\" is marked as \"%s\", but is not defined" id (string_of_suppressing_or_causing enftype) in
        error () (Err.enforceability_error err_msg pos)
  in
  all (List.map (Map.to_alist pol_constrs) ~f:check_pol_constr) >| (fun _ -> ())

let type_exceptions itl_srp (pg_map: pg_map) (exceptions: Tformula.t list) enftype : verdict =
  let exceptions_neg =
    List.map exceptions ~f:(
        fun f -> Tformula.make (Tformula.neg f) { Tformula.Info.dummy with pos = f.info.pos }) in
  type_tformulas_conj pg_map itl_srp exceptions_neg (Enftype.neg enftype)

let type_scopes itl_srp (pg_map: pg_map) scopes enftype : verdict =
  type_tformulas_conj pg_map itl_srp scopes enftype

type enforce_rule_by = {
  enf_by_fixed_pols: (string, Enftype.t, String.comparator_witness) Base.Map.t option;
  enf_by_sup_conditions_by_index: int list option;
  enf_by_sup_conditions_all: bool;
  enf_by_cau_effects_all: bool;
  enf_by_sup_scopes_all: bool;
  enf_by_cau_exceptions_all: bool;
}

let parse_rule_constraints pos n rcs : enforce_rule_by Err.WithErrors.t =
  let open Err.WithErrors in
  let* pol_constrs = pols_from_rule_constraints pos rcs in
  let* _ = 
    (match pol_constrs with
     | Some pol_constrs -> check_pol_constrs pos pol_constrs
     | _ -> ok ()) in
  let* cause_exceptions = causing_exceptions pos rcs in
  let* suppress_scopes = suppressing_scopes pos rcs in
  let* cause_effects = causing_effects pos rcs in
  let* suppress_conditions = suppressing_conditions pos rcs in
  let* suppress_indices = collect_suppressing_indices pos rcs in
  let* _ = suppress_indices_are_in_range pos suppress_indices n in
  let suppress_indices =
    update_suppress_indices_with_suppress_conditions pos suppress_indices suppress_conditions in
  let cause_effects, suppress_conditions =
    combine_cause_effects_and_suppress_conditions pos cause_effects suppress_conditions in
  ok {
    enf_by_fixed_pols = pol_constrs;
    enf_by_sup_conditions_by_index = suppress_indices;
    enf_by_sup_conditions_all = suppress_conditions;
    enf_by_cau_effects_all = cause_effects;
    enf_by_sup_scopes_all = suppress_scopes;
    enf_by_cau_exceptions_all = cause_exceptions;
  }

let update_pols_with_transparency_conditions pols pols_tr =
  Map.merge pols pols_tr ~f:(fun ~key:_ -> function
    | `Left enftype -> Some (enftype, false)
    | `Right _ -> assert false
    | `Both (enftype, (_, tr)) -> Some (enftype, tr)
    )

let is_past_guarded_tformulas ?(pg_map: pg_map=Map.empty (module String)) x p fs =
  match p with
  | true -> List.exists fs ~f:(is_past_guarded ~ts:pg_map x true)
  | false -> List.for_all fs ~f:(is_past_guarded ~ts:pg_map x false)

let is_past_guarded_tpformula = Tlex.Pattern.is_past_guarded (module Tlex.Sig)

let is_past_guarded_tcrule_exn ?(pg_map: pg_map=Map.empty (module String)) rule var : unit Err.WithErrors.t =
  let open Err.WithErrors in
  let make_neg f = Tformula.make (Tformula.neg f) { Tformula.Info.dummy with pos = f.info.pos } in
  match rule with
  | TCImplication (_, _, pos, pf1, ex, sc, pf2, _, _) ->
     let ex_neg = List.map ex ~f:make_neg in
     (if not (
             is_past_guarded_tpformula ~pg_map var true pf1 ||
               is_past_guarded_tformulas ~pg_map var true ex_neg ||
                 is_past_guarded_tformulas ~pg_map var true sc ||
                   is_past_guarded_tpformula ~pg_map var false pf2
           ) then
        let err_msg = Printf.sprintf "Variable \"%s\" is not past-guarded in rule" var in
        error () (Err.enforceability_error err_msg pos)
      else
        ok ())
  | TCDefinitionRef (_, _, pos, pf, ex, sc, _, _) ->
     (* TCDefinitionRef is only used for scope/except rules and
        those should not have any 'fully' unbound variables *)
     (* assert false *)
     let ex_neg = List.map ex ~f:make_neg in
     (if not (
            is_past_guarded_tpformula ~pg_map var true pf ||
              is_past_guarded_tformulas ~pg_map var true ex_neg ||
            is_past_guarded_tformulas ~pg_map var true sc
           ) then
        let err_msg = Printf.sprintf "Variable \"%s\" is not past-guarded in rule" var in
        error () (Err.enforceability_error err_msg pos)
      else
        ok ())
  | TCDefinitionDis (disjuncts, _) ->
     let aux (disjunct: tdisjunct) =
       let ex_neg = List.map disjunct.exceptions ~f:make_neg in
       if is_past_guarded_tpformula ~pg_map var true disjunct.pf ||
            is_past_guarded_tformulas ~pg_map var true ex_neg ||
              is_past_guarded_tformulas ~pg_map var true disjunct.scopes
       then ok ()
       else let err_msg = Printf.sprintf "Variable \"%s\" is not past-guarded in rule" var in
            error () (Err.enforceability_error err_msg disjunct.def_pos)
     in
     let* _ = all (List.map ~f:aux (Map.data disjuncts)) in
     ok ()
(* TODO: print out other locations where the given event is constituted *)

let fv_of_tcrule = function
  | TCImplication (_, _, _, pf1, _, _, pf2, _, _) ->
     Set.union_list (module String) Tlex.Pattern.[fv pf1; fv pf2](*; fvs ex; fvs sc]*)
  | TCDefinitionRef (_, _, _, pf, _, _, _, _) ->
     Set.union_list (module String) Tlex.Pattern.[fv pf](*; fvs ex; fvs sc]*)
  | TCDefinitionDis (disjuncts, _) ->
     Set.union_list (module String)
       (List.concat_map (Map.data disjuncts) ~f:(
            fun disjunct ->
            Tlex.Pattern.[fv disjunct.pf](*; fvs disjunct.exceptions; fvs disjunct.scopes]*)))

let vars_are_past_guarded_tcrule_exn ?(pg_map: pg_map = Map.empty (module String)) vars rule : unit Err.WithErrors.t =
  (* will throw an enforcement error if some variable is not past-guarded *)
  let open Err.WithErrors in
  all (List.map (Set.elements vars) ~f:(is_past_guarded_tcrule_exn ~pg_map rule)) >| (fun _ -> ())

let past_guarded_of_tcrule pg_map rule ~key:x ~data:_ : bool =
  match rule with
  | TCDefinitionRef (_, _, _, pf, ex, sc, _, _) ->
    debug "past_guarded_of_tcrule: TCDefinitionRef";
    let ex_neg = List.map ex ~f:(fun f -> make (neg f) { Tformula.Info.dummy with pos = f.info.pos }) in
    is_past_guarded_tpformula ~pg_map x true pf ||
    is_past_guarded_tformulas ~pg_map x true ex_neg ||
    is_past_guarded_tformulas ~pg_map x true sc
  | TCDefinitionDis (disjuncts, _) ->
    debug "past_guarded_of_tcrule: TCDefinitionDis";
    let aux (disjunct: tdisjunct) =
      let ex_neg = List.map disjunct.exceptions ~f:(fun f -> make (neg f) { Tformula.Info.dummy with pos = f.info.pos }) in
      is_past_guarded_tpformula ~pg_map x true disjunct.pf ||
      is_past_guarded_tformulas ~pg_map x true ex_neg ||
      is_past_guarded_tformulas ~pg_map x true disjunct.scopes
    in
    Map.for_all disjuncts ~f:aux
  | _ -> assert false

(* let update_pg_map s pg_map e vars rule =
  debug (Printf.sprintf "Updating pg_map for event \"%s\"" e);
  if Map.is_empty vars then debug "No (free) variables to check for past-guardedness for this event";
  let data = Map.mapi vars ~f:(past_guarded_of_tcrule s pg_map rule) in
  let pg_map = Map.add_exn pg_map ~key:e ~data:data in
  debug (Printf.sprintf "updated pg_map: %s" (string_of_pg_map pg_map));
  pg_map *)

let tformula_term_equalities (ts1: TTerm.t list) (c: Dom.t) =
  List.map ts1 ~f:(fun t1 -> make (eqconst t1 c) { Tformula.Info.dummy with pos = t1.info.pos })

let get_trm_name (t: TTerm.t) = match t.trm with
  | TTerm.Var x -> x
  | _ -> assert false

let get_trm_name_exn (t: TTerm.t) = match t.trm with
  | TTerm.Var x -> x
  | _ -> assert false

let get_predicate_name_exn (f: Tformula.t) = match f.form with
  | Predicate (n, _) -> n
  | _ -> assert false

let get_predicate_params_exn f = match f.form with
  | Predicate (_, ts) -> ts
  | _ -> assert false

let type_tdisjunct itl_srp (pg_map: pg_map) (t: Enftype.t) (rule: tcrule) (d: tdisjunct) : verdict Err.WithErrors.t =
  let open Err.WithErrors in
  debug (Printf.sprintf "type_tdisjunct: %s to %s" (Tlex.Pattern.to_string d.pf) (Enftype.to_string t));
  let params = match rule with TCDefinitionDis (_, g) -> get_predicate_params_exn g | _ -> assert false in
  let pg_map = List.fold_left (TTerm.fv_list d.params_original) ~init:pg_map
      ~f:(fun m x -> Map.update m x ~f:(fun _ -> [Set.empty (module String)])) in
  let v_ex = type_exceptions itl_srp pg_map d.exceptions (Enftype.neg t) in
  let v_sc = type_scopes itl_srp pg_map d.scopes t in
  let v_pf = type_pattern itl_srp d.rule_pos pg_map t d.pf in
  debug (Printf.sprintf "v_ex = %s\nv_sc = %s\nv_pf = %s"
           (verdict_to_string v_ex) (verdict_to_string v_sc) (verdict_to_string v_pf));
  debug (Printf.sprintf "pg_map = %s" (String.concat ~sep:"," (Map.keys pg_map)));
  (*debug (Printf.sprintf "type_tdisjunct (event: %s)" e);*)
  let param_names = List.map params ~f:get_trm_name in
  let* v = match Enftype.is_causable t, Enftype.is_suppressable t with
    | true, _ -> ok (conjs [v_pf; v_ex; v_sc])
    | _, true ->
      let _, fv_unbound = Set.partition_tf (fv_of_tcrule rule) ~f:(fun x -> List.mem param_names x ~equal:String.equal) in
      let* _ = vars_are_past_guarded_tcrule_exn ~pg_map fv_unbound rule in
      ok (disjs [v_pf; v_ex; v_sc])
    | _ -> ok (Possible CTT)
  in 
  debug (Printf.sprintf "type_tdisjunct verdict: %s" (verdict_to_string v));
  ok v

let srp_if_transparent_else_true transparent is_srp =
  if transparent then is_srp else true

let solve_past_guarded_of_pattern_exceptions_scopes tpf ex sc x pg_map =
  (Tlex.Pattern.solve_past_guarded (module Tlex.Sig) ~pg_map x true tpf)
    @ solve_past_guarded_multiple pg_map x false ex
    @ solve_past_guarded_multiple pg_map x true sc

let pg_map_of_pattern_exceptions_scope_fv tpf ex sc fv pg_map =
  let f ts x = Map.update ts x ~f:(fun _ -> solve_past_guarded_of_pattern_exceptions_scopes tpf ex sc x pg_map)
  in Set.fold fv ~init:pg_map ~f

let type_rule_by
      (pg_map: pg_map)
      (enforcement_constrs: enforce_rule_by)
      (srp_exceptions: bool)
      (srp_scopes: bool)
      (srp_conditions: bool)
      (srp_effects: bool)
      (exceptions: t list)
      (scopes: t list)
      (pf_conditions: Tlex.Pattern.t)
      (pf_effects: Tlex.Pattern.t)
      srp_of_pattern tr pos
    : verdict =
  match enforcement_constrs.enf_by_cau_exceptions_all,
        enforcement_constrs.enf_by_sup_scopes_all,
        enforcement_constrs.enf_by_sup_conditions_all,
        enforcement_constrs.enf_by_sup_conditions_by_index,
        enforcement_constrs.enf_by_cau_effects_all with
  | true, _, _, _, _ ->
     (if srp_scopes && srp_conditions && srp_effects then
        type_exceptions None pg_map exceptions Enftype.causable
      else
        let not_srp = Util.combine_string_descriptors
                        ["scopes"; "conditions"; "effects"]
                        [srp_scopes; srp_conditions; srp_effects] in
        Impossible (ERule ("make " ^ not_srp ^ " observable to allow for exceptions to be transparently caused")))
  | _, true, _, _, _ ->
     (if srp_exceptions && srp_conditions && srp_effects then
        type_scopes None pg_map scopes Enftype.suppressable
      else
        let not_srp = Util.combine_string_descriptors
                        ["exceptions"; "conditions"; "effects"]
                        [srp_exceptions; srp_conditions; srp_effects] in
        Impossible (ERule ("make " ^ not_srp ^ " observable to allow for scopes to be transparently suppressed")))
  | _, _, _, Some indices, _ ->
     let pf_conditions_used =
       { pf_conditions with fs = List.filteri pf_conditions.fs ~f:(fun i _ -> List.mem indices i ~equal:Int.equal) } in
     let pf_conditions_unused =
       { pf_conditions with fs = List.filteri pf_conditions.fs ~f:(fun i _ -> List.mem indices i ~equal:(fun x y -> Int.equal x y |> not)) } in
     let srp_conditions_unused = srp_of_pattern pf_conditions_unused in
     if srp_conditions_unused && srp_scopes && srp_exceptions && srp_effects then
       type_pattern tr pos pg_map Enftype.suppressable pf_conditions_used
     else
       let not_srp = Util.combine_string_descriptors
                       ["unused conditions"; "scopes"; "exceptions"; "effects"]
                       [srp_conditions_unused; srp_scopes; srp_exceptions; srp_effects] in
       Impossible (ERule ("make " ^ not_srp ^ " observable to allow for conditions to be transparently suppressed"))
  | _, _, true, _, _ ->
     (if srp_scopes && srp_exceptions && srp_effects then
        type_pattern tr pos pg_map Enftype.suppressable pf_conditions
      else
        let not_srp = Util.combine_string_descriptors
                        ["scopes"; "exceptions"; "effects"]
                        [srp_scopes; srp_exceptions; srp_effects] in
        Impossible (ERule ("make " ^ not_srp ^ " observable to allow for conditions to be transparently suppressed")))
  | _, _, _, _, true ->
     (if srp_scopes && srp_exceptions && srp_conditions then
        type_pattern tr pos pg_map Enftype.causable pf_effects
      else
        let not_srp = Util.combine_string_descriptors
                        ["exceptions"; "scopes"; "conditions"]
                        [srp_exceptions; srp_scopes; srp_conditions] in
        Impossible (ERule ("make " ^ not_srp ^ " observable to allow for effects to be transparently caused")))
  | _ -> Impossible (ERule ("you must specify an enforcement strategy"))

let type_fixed_pols (events: string list) (enforcement_constrs: enforce_rule_by) : verdict =
  match enforcement_constrs.enf_by_fixed_pols with
  | Some fixed_pols ->
    let f (e: string) =
      match Map.find fixed_pols e with
      | Some t -> Possible (CLeq (e, t))
      | None -> Possible CTT
    in
    let fixed_pols_events = List.map events ~f in
    List.fold fixed_pols_events ~init:(Possible CTT) ~f:conj    
  | None -> Possible CTT

let type_tcrule (s: tprog) itl_srp (pg_map: pg_map) (verdict: verdict) (rule: tcrule) : verdict Err.OrErrors.t =
  let open Err.OrErrors in
  debug (Printf.sprintf "type_tcrule at %s current verdict: %s" (LexingInfo.to_string (pos_of_tcrule rule))  (verdict_to_string verdict));
  let itl_itvs, itl_strict, itl_observable = match itl_srp with
    | Some (i, s, o) -> i, s, o
    | _ -> Map.empty (module String), Map.empty (module String), Map.empty (module String) in
  let* solution = match verdict with
    | Possible c when not (List.is_empty (solve c)) -> ok (solve c)
    | _ ->
      debug ("Constraint system is unsolvable. Skipping rule.");
      let err_msg = "Constraint system is unsolvable. Skipping rule." in
      error (Err.enforceability_error err_msg (Tlex.pos_of_tcrule rule))
  in
  match rule with
  | TCImplication (_, _, pos, _, _, _, _, Assumed, rcs)
  | TCImplication (_, _, pos, _, _, _, _, Vanilla, rcs) ->
    debug "typing TCImplication (Vanilla)";
    vanilla_rule_constraints_warning pos rcs;
    ok verdict (* do not add any typing constraints in regards to this rule *)
  | TCImplication (_, _, pos, pf1, exceptions, scopes, pf2, (Enforceable as rt), rcs) 
  | TCImplication (_, _, pos, pf1, exceptions, scopes, pf2, (Transparent as rt), rcs) ->

    (* SRP + Transparency *)
    let transparent    = Lex.equal_rule_type rt Transparent in
    let tr             = if transparent then itl_srp else None in
    let srp            = strictly_relative_past ~itl_itvs ~itl_strict ~itl_observable in
    let srp_of_pattern = Tlex.Pattern.strictly_relative_past (module Tlex.Sig) ~itl_itvs ~itl_strict ~itl_observable in
    let srp_exceptions = List.for_all exceptions ~f:srp |> srp_if_transparent_else_true transparent in
    let srp_scopes     = List.for_all scopes ~f:srp     |> srp_if_transparent_else_true transparent in
    let srp_conditions = srp_of_pattern pf1 |> srp_if_transparent_else_true transparent in
    let srp_effects    = srp_of_pattern pf2 |> srp_if_transparent_else_true transparent in

    (* Checking past-guardedness *)
    let* _ =  of_witherror (vars_are_past_guarded_tcrule_exn ~pg_map (fv_of_tcrule rule) rule) in
    let pg_map = pg_map_of_pattern_exceptions_scope_fv pf1 exceptions scopes (fv_of_tcrule rule) pg_map in

    (* Enforcement constraints *)
    let* enforcement_constrs = of_witherror (parse_rule_constraints pos (List.length pf1.fs) rcs) in

    (* Verdict according to enforcement stategy *)
    let verdict_by = type_rule_by pg_map enforcement_constrs 
        srp_exceptions srp_scopes srp_conditions srp_effects
        exceptions scopes pf1 pf2 srp_of_pattern tr pos in

    (* Add constraints corresponding to the "suppressing Event" or "causing Event" annotations *)
    let events_conditions = Tlex.Pattern.predicates pf1 |> List.map ~f:fst |> List.dedup_and_sort ~compare:String.compare in
    let events_effects =    Tlex.Pattern.predicates pf2 |> List.map ~f:fst |> List.dedup_and_sort ~compare:String.compare in
    let verdict_fixed_pols_conditions = type_fixed_pols events_conditions enforcement_constrs in
    let verdict_fixed_pols_effects    = type_fixed_pols events_effects enforcement_constrs in

    (* Finally, conjoin with previously known verdict *)
    let verdict_rule_implication =
      verdict_by
      |> conj verdict_fixed_pols_conditions
      |> conj verdict_fixed_pols_effects
      |> conj verdict in
    (*debug (Printf.sprintf "verdict_fixed_pols_conditions: %s" (Constraints.verdict_to_string verdict_fixed_pols_conditions));
      debug (Printf.sprintf "verdict_fixed_pols_effects: %s" (Constraints.verdict_to_string verdict_fixed_pols_effects));
      debug (Printf.sprintf "verdict_conditions: %s" (Constraints.verdict_to_string verdict_conditions));
      debug (Printf.sprintf "verdict: %s" (Constraints.verdict_to_string verdict_rule_implication));*)
    begin match verdict_rule_implication, transparent with
      | Possible _, _ -> ok verdict_rule_implication
      | Impossible e, true ->
        let err_msg = Printf.sprintf "This rule is not transparently enforceable.\nTo make it transparently enforceable, %s" (Errors.to_string (Errors.ac_simplify e)) in
        error (Err.enforceability_error err_msg pos)
      | Impossible e, false ->
        let err_msg = Printf.sprintf "This rule is not enforceable.\nTo make it enforceable, %s" (Errors.to_string (Errors.ac_simplify e)) in
        error (Err.enforceability_error err_msg pos)
    end
  | TCDefinitionRef (idx, _, _, pf1, ex, sc, _, f2) ->
    let e = get_predicate_name_exn f2 in
    (*debug (Printf.sprintf "typing TCDefinitionRef: %s" e);*)
    let params = get_predicate_params_exn f2 in
    (* f2 is an except/scope predicate and parameters should be exclusively variable whose name can be extracted *)
    let get_trm_name (t: TTerm.t) = match t.trm with
      | TTerm.Var x -> x
      | _ -> assert false in
    let param_names = List.map params ~f:get_trm_name in
    let fv = fv_of_tcrule rule in
    let _, fv_unbound =
      Set.partition_tf fv ~f:(fun x -> List.mem param_names x ~equal:String.equal) in
    let pos = try snd (Map.find_exn s.rule_tree.label_of_rule idx) with _ -> assert false in
    let f _  v_pols =
      let enftype, itl_srp =
        begin match Map.find v_pols e with
          | Some constr ->
            let enftype = Enftype.Constraint.solve constr in
            enftype, if Enftype.is_transparent enftype then itl_srp else None
          | None ->
            match Map.find itl_observable e with
            | Some true -> Enftype.obs, None
            | _ -> Enftype.bot, None
        end in
      let v_ex = type_exceptions itl_srp pg_map ex (Enftype.neg enftype) in
      let v_sc = type_scopes itl_srp pg_map sc enftype in
      let v_pf1 = type_pattern itl_srp pos pg_map enftype pf1 in
      match Enftype.is_causable enftype, Enftype.is_suppressable enftype with
      | true, _ ->
        (* all parts of the definition must be Cau *)
        let verdict_references = conj v_ex v_sc in
        ok (conj (conj v_pf1 verdict_references) verdict)
      | _, true ->
        (* only one part of the definition must be Sup *)
        let* _ = of_witherror (vars_are_past_guarded_tcrule_exn ~pg_map fv_unbound rule) in
        let verdict_references = disj v_ex v_sc in
        ok (conj (disj v_pf1 verdict_references) verdict)
      | _ -> ok verdict in
    begin match solution with
      | [] -> ok (Possible CTT)
      | _ -> let* verdicts = all (List.mapi solution ~f) in
        ok (Constraints.disjs verdicts) end
  | TCDefinitionDis (disjuncts, g) ->
    let e = get_predicate_name_exn g in
    let f v_pols =
      let enftype, itl_srp =
        begin match Map.find v_pols e with
          | Some constr ->
            let enftype = Enftype.Constraint.solve constr in
            debug (Printf.sprintf "solve(%s,%s)=%s" e (Enftype.Constraint.to_string constr) (Enftype.to_string enftype));
            enftype, if Enftype.is_transparent enftype then itl_srp else None
          | None ->
            match Map.find itl_observable e with
            | Some true -> Enftype.obs, None
            | _ -> Enftype.bot, None
        end in
      (*print_endline ("TCDefinitionDis g=" ^ Tformula.to_string g ^ " enftype=" ^ Enftype.to_string enftype);*)
      let type_tdisjunct = type_tdisjunct itl_srp pg_map enftype rule in
      disjuncts
      |> Map.data
      |> List.map ~f:type_tdisjunct
      |> Err.WithErrors.all
      |> of_witherror
      >| Constraints.disjs
      >| conj verdict in
    begin match solution with
      | [] -> ok (Possible CTT)
      | _ ->
        let* verdicts = all (List.map solution ~f) in
        ok (Constraints.disjs verdicts) end

let relative_interval_of_disjunct itl_itvs (d: tdisjunct) =
  (* The relative interval of the "variable renaming conditions" will always be 0 and is thus ignored *)
  let conditions_itv = Tlex.Pattern.relative_interval ~itl_itvs d.pf in
  let exceptions_itv = Tformula.relative_intervals ~itl_itvs d.exceptions in
  let scopes_itv = Tformula.relative_intervals ~itl_itvs d.scopes in
  Zinterval.lub conditions_itv exceptions_itv |> Zinterval.lub scopes_itv

let relative_interval_itl itl_itvs = function
  (* requires that all relative intervals of events used in the given rule have already been computed *)
  | TCDefinitionRef (_, _, _, pf, e, s, _, {form=Tformula.Predicate (name, _); _}) ->
     let conditions_itv = Tlex.Pattern.relative_interval ~itl_itvs pf in
     let exceptions_itv = Tformula.relative_intervals ~itl_itvs e in
     let scopes_itv = Tformula.relative_intervals ~itl_itvs s in
     let itv = Zinterval.lub conditions_itv exceptions_itv |> Zinterval.lub scopes_itv in
     Map.add_exn itl_itvs ~key:name ~data:itv
  | TCDefinitionRef _ -> assert false (* final formula must be a predicate *)
  | TCDefinitionDis (disjuncts, {form=Tformula.Predicate (name, _); _}) ->
     let relative_itvs_disjuncts = List.map (Map.data disjuncts) ~f:(relative_interval_of_disjunct itl_itvs) in
     let itv = List.fold relative_itvs_disjuncts ~init:(Zinterval.singleton 0) ~f:Zinterval.lub in
     Map.add_exn itl_itvs ~key:name ~data:itv
  | TCDefinitionDis _ -> assert false (* final formula must be a predicate *)
  | _ -> itl_itvs


let strict_of_disjunct itl_strict (d: tdisjunct) =
  (* The "variable renaming conditions" will always be strict and are thus ignored *)
  let conditions_strict = Tlex.Pattern.strict ~itl_strict d.pf in
  let exceptions_strict = Tformula.stricts ~itl_strict d.exceptions in
  let scopes_itv = Tformula.stricts ~itl_strict d.scopes in
  conditions_strict && exceptions_strict && scopes_itv

let strict_itl itl_strict = function
  (* requires that all "strictness"-constraints of events used in the given rule have already been computed *)
  | TCDefinitionRef (_, _, _, pf, e, s, _, {form=Tformula.Predicate (name, _); _}) ->
     let conditions_strict = Tlex.Pattern.strict ~itl_strict pf in
     let exceptions_strict = Tformula.stricts ~itl_strict e in
     let scopes_itv = Tformula.stricts ~itl_strict s in
     let is_strict = conditions_strict && exceptions_strict && scopes_itv in
     Map.add_exn itl_strict ~key:name ~data:is_strict
  | TCDefinitionRef _ -> assert false
  | TCDefinitionDis (disjuncts, {form=Tformula.Predicate (name, _); _}) ->
     let is_strict = List.for_all (Map.data disjuncts) ~f:(strict_of_disjunct itl_strict) in
     Map.add_exn itl_strict ~key:name ~data:is_strict
  | TCDefinitionDis _ -> assert false
  | _ -> itl_strict

let observable_itl itl_observable = function
  (* requires that all "strictness"-constraints of events used in the given rule have already been computed *)
  | TCDefinitionRef (_, _, _, pf, e, s, _, {form=Tformula.Predicate (name, _); _}) ->
    let conditions_observable = Tlex.Pattern.observable (module Tlex.Sig) ~itl_observable pf in
    let exceptions_observable = observable_multiple ~itl_observable e in
    let scopes_observable = observable_multiple ~itl_observable s in
    let is_observable = conditions_observable && exceptions_observable && scopes_observable in
    Map.add_exn itl_observable ~key:name ~data:is_observable
  | TCDefinitionRef _ -> assert false
  | TCDefinitionDis (disjuncts, {form=Tformula.Predicate (name, _); _}) ->
    let is_observable = List.for_all (Map.data disjuncts) ~f:(strict_of_disjunct itl_observable) in
    Map.add_exn itl_observable ~key:name ~data:is_observable
  | TCDefinitionDis _ -> assert false
  | _ -> itl_observable

let pg_map_of_tcrule pg_map: tcrule -> pg_map =
  function
  | TCImplication _ -> pg_map
  | TCDefinitionRef (_, _, _, tpf, ex, sc, _, g) ->
     let args = get_predicate_params_exn g in
     let arg_names = List.map args ~f:get_trm_name_exn in
     List.fold_left arg_names ~init:pg_map
       ~f:(fun pg_map key ->
         let f _ = solve_past_guarded_of_pattern_exceptions_scopes tpf ex sc key pg_map in
         Map.update pg_map key ~f)
  | TCDefinitionDis (tdisjuncts, g) ->
     let args = get_predicate_params_exn g in
     let arg_names = List.map args ~f:get_trm_name_exn in
     let f x =
       List.map (Map.data tdisjuncts)
         ~f:(fun d ->
           solve_past_guarded_of_pattern_exceptions_scopes d.pf d.exceptions d.scopes x pg_map) in
     let sols_list = List.map arg_names ~f in
     let f pg_map key sols =
       Map.update pg_map key ~f:(fun _ -> MFOTL_lib.Etc.inter_string_set_list sols) in
     List.fold2_exn arg_names sols_list ~init:pg_map ~f

let pg_map_of_tcrules tcrules: pg_map =
  List.fold tcrules ~init:(Map.empty (module String)) ~f:pg_map_of_tcrule

let type_tcrules
    (tprog: Tlex.tprog)
    (tcrules: (int, tcrule, 'a) Map.t)
    (rule_order: int list) :
  ((string, Enftype.Constraint.t, 'string_comp) Map.t list * 'itl_srp * pg_map) Err.OrErrors.t =
  let open Err.OrErrors in
  (*debug (Printf.sprintf "Sorted rule indices: %s" (Util.string_of_int_list rule_order));*)
  let tcrules_sorted = List.map rule_order ~f:(fun idx -> Map.find_exn tcrules idx) in
  let itl_itvs = List.fold (List.rev tcrules_sorted) ~f:relative_interval_itl ~init:(Map.empty (module String)) in
  let itl_strict = List.fold (List.rev tcrules_sorted) ~f:strict_itl ~init:(Map.empty (module String)) in
  let itl_observable = List.fold (List.rev tcrules_sorted) ~f:observable_itl ~init:(Map.empty (module String)) in
  let pg_map = pg_map_of_tcrules (Map.data tcrules) in
  let f verdict rule =
    let* verdict' = type_tcrule tprog (Some (itl_itvs, itl_strict, itl_observable)) pg_map verdict rule in
    debug (Printf.sprintf "Verdict: %s" (verdict_to_string verdict'));
    match verdict' with
    | Possible c when not (List.is_empty (solve c)) -> ok verdict'
    | Possible c ->
       let err_msg = Printf.sprintf "Constraint system is unsolvable: %s" (Constraints.to_string c) in
       debug ("Unsolvable constraint system");
       error (Err.enforceability_error err_msg (pos_of_tcrule rule))
    | Impossible e ->
       let err_msg = Printf.sprintf "Constraints are unsolvable. To solve them, %s" (Errors.to_string (Errors.ac_simplify e)) in
       debug ("Unsolvable constraints");
       error (Err.enforceability_error err_msg (pos_of_tcrule rule)) in
  let* verdict = fold_best_effort (List.rev tcrules_sorted) ~f ~init:(Possible CTT) in
  let* constraints = match verdict with
    | Possible c -> ok c
    | Impossible _ ->
      let err_msg = "Overall constraint system is unsolvable" in 
      error (Err.enforceability_error err_msg LexingInfo.dummy)
  in
  let possible_policies = Constraints.solve constraints in
  debug (Printf.sprintf "type_tcrules verdict: %s" (verdict_to_string verdict));
  (* let found_pol_constraints = match possible_policies with
    | c::_ -> c
    | [] -> Map.empty (module String)
  in *)
  ok (possible_policies, (itl_itvs, itl_strict, itl_observable), pg_map)

(* Conversion to erules *)

let convert enftype (f: Tformula.t) : Eformula.t =
  match convert !b_ref enftype f with
  | Some ef -> Eformula.of_typed_tformula ef
  | None ->
     let err_msg =
      Printf.sprintf
      "(type checking implementation error) Impossible to convert enforceable (%s) formula: %s"
      (Enftype.to_string enftype)
      (Tformula.to_string f)
    in
    debug err_msg;
    assert false

let convert_enforceable_tformulas ?(combination_type=`Conj) (enftype: Enftype.t) pols (fs: Tformula.t list) : Eformula.t list * int option =
  (*print_endline ("convert_enforceable_tformulas " ^ String.concat ~sep:", " (List.map ~f:Tformula.to_string fs));*)
  let convert enftype f = convert enftype f in
  match Enftype.is_causable enftype, Enftype.is_suppressable enftype, combination_type with
  | true, _, `Conj -> List.map fs ~f:(convert enftype), None
  | _, true, `Disj -> List.map fs ~f:(convert enftype), None
  | _, true, `Conj ->
    let find_first_possible _ f =
      match types enftype pols f with
      | Possible _ -> true
      | Impossible _ -> false
    in
    let idx = List.findi_exn ~f:find_first_possible fs |> fst in (* there must exist at least one formula which types correctly, otherwise the enforcement checking is wrong *)
    let aux i f = if i = idx then convert Enftype.suppressable f else Eformula.of_tformula f in
    List.mapi fs ~f:aux, Some idx
  | true, _, `Disj ->
    let find_first_possible _ f =
       match types enftype pols f with
       | Possible _ -> true
       | Impossible _ -> false
     in
    let idx = List.findi_exn ~f:find_first_possible fs |> fst in (* there must exist at least one formula which types correctly, otherwise the enforcement checking is wrong *)
    let aux i f = if i = idx then convert Enftype.causable f else Eformula.of_tformula f in
    List.mapi fs ~f:aux, Some idx
  | _ -> List.map fs ~f:(convert enftype), None

let convert_enforceable_pattern (enftype: Enftype.t) pols (tpf: Tlex.Pattern.t) : Pattern.t * enf_pformula option =
  let convert enftype f = convert enftype f in
  match Enftype.is_causable enftype, Enftype.is_suppressable enftype with
  | true, _ ->
    begin match tpf.patt with
      | PPresent
      | PEventually _
      | PAlways _
      | POnce _
      | PHistorically _ ->
        let fs, _ = convert_enforceable_tformulas Enftype.causable pols tpf.fs in
        let patt = Elex.epatt_of_tpatt tpf.patt  in
        let enf_constr = EpfCau ECpfFormulas in
        Pattern.make patt fs, Some enf_constr
      | PUntil (i, _) when Interval.has_zero i ->
        let fs, _ = convert_enforceable_tformulas Enftype.causable pols tpf.fs in
        let patt = Elex.epatt_of_tpatt tpf.patt in
        let enf_constr = EpfCau ECpfFormulas in
        Pattern.make patt fs, Some enf_constr
      | PUntil (i, g) ->
        let fs, _ = convert_enforceable_tformulas Enftype.causable pols tpf.fs in
        let eg = convert Enftype.causable g in
        let patt = Pattern.PUntil (i, eg) in
        let enf_constr = EpfCau ECpfPformula in
        Pattern.make patt fs, Some enf_constr
      | PSince (i, g) when Interval.has_zero i ->
        let eg = convert Enftype.causable g in
        let fs = List.map tpf.fs ~f:Eformula.of_tformula in
        let patt = Pattern.PSince (i, eg) in
        let enf_constr = EpfCau ECpfPformula in
        Pattern.make patt fs, Some enf_constr
      | _ -> assert false
    end
  | _, true ->
    begin match tpf.patt with
      | PPresent
      | PEventually _
      | PAlways _
      | POnce _
      | PHistorically _
      | PUntil _ ->
        let fs, i_opt = convert_enforceable_tformulas Enftype.suppressable pols tpf.fs in
        let patt = Elex.epatt_of_tpatt tpf.patt  in
        let enf_constr = EpfSup (ESpfFormula (Option.value_exn i_opt)) in
        Pattern.make patt fs, Some enf_constr
      | PSince (i, g) when Interval.has_zero i ->
        let eg = convert Enftype.suppressable g in
        let fs = List.map tpf.fs ~f:Eformula.of_tformula in
        let patt = Pattern.PSince (i, eg) in
        let enf_constr = EpfSup ESpfPattern in
        Pattern.make patt fs, Some enf_constr
      | PSince _ ->
        let fs, i_opt = convert_enforceable_tformulas Enftype.suppressable pols tpf.fs in
        let patt = Elex.epatt_of_tpatt tpf.patt  in
        let enf_constr = EpfSup (ESpfFormula (Option.value_exn i_opt)) in
        Pattern.make patt fs, Some enf_constr
    end
  | _ -> epf_of_tpf tpf, None

let update_enf_pformula indices constr =
  match constr with
    | Some (EpfSup (ESpfPformula i)) -> Some (EpfSup (ESpfPformula (List.nth_exn indices i)))
    | Some (EpfSup (ESpfFormula i)) -> Some (EpfSup (ESpfFormula (List.nth_exn indices i)))
    | _ -> constr

let  merge_used_and_unused used_idx used unused =
  let rec merge i used unused =
    match used, unused with
    | [], [] -> []
    | h::used, _ when List.mem used_idx i ~equal:Int.equal -> h :: merge (i+1) used unused
    | _, h::unused -> h :: merge (i+1) used unused
    | _ -> assert false
  in
  merge 0 used unused

let convert_enforceable_tdisjunct itl_srp pols t (td: tdisjunct):
    (edisjunct * enf_ecdefinition option) =
  debug ("convert_enforceable_tdisjunct: " ^ Tlex.Pattern.to_string td.pf ^ " " ^ Enftype.to_string t);
  match Enftype.is_causable t, Enftype.is_suppressable t with
  | true, _ ->
    (* Cause conditions, suppress exceptions, cause scopes *)
    let exceptions, _ = convert_enforceable_tformulas ~combination_type:`Disj Enftype.suppressable pols td.exceptions in
    let scopes, _ = convert_enforceable_tformulas Enftype.causable pols td.scopes in
    let pf, constr_opt = convert_enforceable_pattern Enftype.causable pols td.pf in
    let enf_constr = match constr_opt with
      | Some (EpfCau c) -> ECd (EClhsAll c)
      | _ -> assert false
    in
    { rule_id         = td.rule_id;
      rule_type       = td.rule_type;
      rule_pos        = td.rule_pos;
      def_pos         = td.def_pos;
      pf; exceptions; scopes;
      fv_renaming     = td.fv_renaming;
      params_original = ETerm.of_tterms td.params_original;
      params_new      = ETerm.of_tterms td.params_new;
    }, Some enf_constr
  | _, true -> (* Make Suppressable *)
    (* Idea:
       - check if exceptions can be caused, thus suppressing the disjunct
       - check if scopes can be suppressed, thus suppressing the disjunct
       - check if the formula (pattern) itself can be suppressed, thus suppressing the disjunct
    *)
    let v_ex = type_exceptions itl_srp pols td.exceptions (Enftype.neg t) in
    let v_sc = type_scopes itl_srp pols td.scopes t in
    let v_pf = type_pattern itl_srp td.rule_pos pols t td.pf in
    begin match v_ex, v_sc, v_pf with
      | Possible _, _, _ ->
        (* Cause exceptions *)
        debug ("v_ex: "^ verdict_to_string v_ex);
        let pf = epf_of_tpf td.pf in
        let exceptions, i_opt =
          convert_enforceable_tformulas ~combination_type:`Disj Enftype.causable pols td.exceptions in
        let scopes = List.map td.scopes ~f:Eformula.of_tformula in
        let enf_constr = ESd (ESlhsCException (Option.value_exn i_opt)) in
        { rule_id         = td.rule_id;
          rule_type       = td.rule_type;
          rule_pos        = td.rule_pos;
          def_pos         = td.def_pos;
          pf; exceptions; scopes;
          fv_renaming     = td.fv_renaming;
          params_original = ETerm.of_tterms td.params_original;
          params_new      = ETerm.of_tterms td.params_new;
        }, Some enf_constr
      | _, Possible _, _ ->
        (* Suppress scopes *)
        let pf = epf_of_tpf td.pf in
        let exceptions = List.map td.exceptions ~f:Eformula.of_tformula in
        let scopes, i_opt = convert_enforceable_tformulas Enftype.causable pols td.scopes in
        let enf_constr = ESd (ESlhsSScope (Option.value_exn i_opt)) in
        { rule_id         = td.rule_id;
          rule_type       = td.rule_type;
          rule_pos        = td.rule_pos;
          def_pos         = td.def_pos;
          pf; exceptions; scopes;
          fv_renaming     = td.fv_renaming;
          params_original = ETerm.of_tterms td.params_original;
          params_new      = ETerm.of_tterms td.params_new;
        }, Some enf_constr
      | _, _, Possible _ ->
        (* Suppress pattern *)
        let pf, constr_opt = convert_enforceable_pattern Enftype.suppressable pols td.pf in
        let exceptions = List.map td.exceptions ~f:Eformula.of_tformula in
        let scopes = List.map td.scopes ~f:Eformula.of_tformula in
        let enf_constr = match constr_opt with
          | Some (EpfSup c) -> ESd (ESlhsSPformula c)
          | _ -> assert false
        in
        { rule_id         = td.rule_id;
          rule_type       = td.rule_type;
          rule_pos        = td.rule_pos;
          def_pos         = td.def_pos;
          pf; exceptions; scopes;
          fv_renaming     = td.fv_renaming;
          params_original = ETerm.of_tterms td.params_original;
          params_new      = ETerm.of_tterms td.params_new;
        }, Some enf_constr
      | _, _, _ -> assert false
    end
  | _  -> edisjunct_of_tdisjunct td, None

let erules_from_tcrules (tcrules: (int, tcrule, Int.comparator_witness) Map.t) : (int, erule, Int.comparator_witness) Map.t =
  let c_rules = Map.to_alist tcrules in
  let aux erules (c_idx, c_rule) = match c_rule with
    | TCImplication (r_idx, trt, pos, _, _, _, _, _, _) ->
       begin match trt with
       | TRTObligation -> Map.add_exn erules ~key:r_idx ~data:(EObligation (pos, c_idx))
       | TRTPermission -> Map.add_exn erules ~key:r_idx ~data:(EPermission (pos, c_idx))
       | _ -> assert false
       end
    | TCDefinitionRef (r_idx, trt, pos, _, _, _, _, _) ->
       begin match trt with
       | TRTException -> Map.add_exn erules ~key:r_idx ~data:(EException (pos, c_idx))
       | TRTExceptionC -> Map.update erules r_idx ~f:(function
                              | Some (EExceptionC (pos, -1, constitutives)) -> EExceptionC (pos, c_idx, constitutives)
                              | Some _ -> assert false (* not -1: exception cannot be defined already *)
                              | None -> EExceptionC (pos, c_idx, []))
       | TRTScope -> Map.add_exn erules ~key:r_idx ~data:(EScope (pos, c_idx))
       | _ -> assert false
       end
    | TCDefinitionDis (disjunct_map, _) ->
       let add_disjuncts_to_map m (d_idx, (disjunct: tdisjunct)) =
         let trt = disjunct.rule_type in
         let r_idx = disjunct.rule_id in
         let pos = disjunct.rule_pos in
         begin match trt with
         | TRTConstitutive ->
            Map.update m r_idx ~f:(function
                | Some (EConstitutive (pos, ds)) -> EConstitutive (pos, (c_idx, d_idx)::ds)
                | Some _ -> assert false
                | None -> EConstitutive (pos, [(c_idx, d_idx)]))
         | TRTExceptionC ->
            Map.update m r_idx ~f:(function
                | Some (EExceptionC (pos, c_idx_ex, constitutives)) -> EExceptionC (pos, c_idx_ex, (c_idx, d_idx)::constitutives)
                | Some _ -> assert false
                | None -> EExceptionC (pos, -1, [(c_idx, d_idx)]))
         | _ -> assert false
         end
       in
       Map.to_alist disjunct_map |> List.fold ~init:erules ~f:add_disjuncts_to_map
  in
  List.fold c_rules ~f:aux ~init:(Map.empty (module Int))

(* Conversion to ecrules *)

let ecrule_from_tcrule (pg_map: pg_map) itl_srp (pols: (string, Enftype.t, 'string_comp) Map.t) (tcrule: tcrule) : ecrule Err.OrErrors.t  =
  let open Err.OrErrors in
  let (_, _, itl_observable) = itl_srp in
  let ecrule = match tcrule with
    | TCImplication (idx, ert, pos, pf1, ex, sc, pf2, rt, rcs) ->
       let pg_map = pg_map_of_pattern_exceptions_scope_fv pf1 ex sc (fv_of_tcrule tcrule) pg_map in
       debug (Printf.sprintf "ecrule_from_tcrule (%s, %s)"
                (Tlex.Pattern.to_string pf1) (Tlex.Pattern.to_string pf2));
       begin match rt with
       | Vanilla | Assumed ->
          let ex' = List.map ex ~f:Eformula.of_tformula in
          let sc' = List.map sc ~f:Eformula.of_tformula in
          let epf1 = epf_of_tpf pf1 in
          let epf2 = epf_of_tpf pf2 in
          ok (ECImplication (idx, ert, pos, epf1, ex', sc', epf2, rt, rcs, None))
       | Enforceable
       | Transparent ->
          let* enforcement_constrs = of_witherror (parse_rule_constraints pos (List.length pf1.fs) rcs) in
          let c_ex     = enforcement_constrs.enf_by_cau_exceptions_all in
          let s_sc     = enforcement_constrs.enf_by_sup_scopes_all in
          let s_co     = enforcement_constrs.enf_by_sup_conditions_all in
          let s_co_ids = enforcement_constrs.enf_by_sup_conditions_by_index in
          let c_ef     = enforcement_constrs.enf_by_cau_effects_all in
          begin match c_ex, s_sc, s_co, c_ef, s_co_ids with
            | true, _, _, _, _ ->
              (* Enforce by causing an exception *)
              let epf1 = epf_of_tpf pf1 in
              let ex', i_opt = convert_enforceable_tformulas ~combination_type:`Disj Enftype.causable pg_map ex in
              let sc' = List.map sc ~f:Eformula.of_tformula in
              let epf2 = epf_of_tpf pf2 in
              let enf_constr = ESciLhs (ESlhsCException (Option.value_exn i_opt)) in
              ok (ECImplication (idx, ert, pos, epf1, ex', sc', epf2, rt, rcs, Some enf_constr))
            | _, true, _, _, _ ->
              (* Enforce by suppressing a scope *)
              let epf1 = epf_of_tpf pf1 in
              let ex' = List.map ex ~f:Eformula.of_tformula in
              let sc', i_opt = convert_enforceable_tformulas Enftype.suppressable pg_map sc in
              let epf2 = epf_of_tpf pf2 in
              let enf_constr = ESciLhs (ESlhsSScope (Option.value_exn i_opt)) in
              ok (ECImplication (idx, ert, pos, epf1, ex', sc', epf2, rt, rcs, Some enf_constr))
            | _, _, _, _, Some ids ->
              (* Enforce by suppressing any of the conditions specified by ids *)
              let pf1_used = { pf1 with fs = List.filteri pf1.fs ~f:(fun i _ -> List.mem ids i ~equal:Int.equal) } in
              let f1s_unused = List.filteri pf1.fs ~f:(fun i _ -> List.mem ids i ~equal:(fun x y -> not (Int.equal x y))) in
              let epf1_used, constr_opt = convert_enforceable_pattern Enftype.suppressable pg_map pf1_used in
              let f1s_unused = List.map f1s_unused ~f:Eformula.of_tformula in
              let fs1 = merge_used_and_unused ids epf1_used.fs f1s_unused in
              let constr_opt = update_enf_pformula ids constr_opt in
              let epf1 = { epf1_used with fs = fs1 } in
              let ex' = List.map ex ~f:Eformula.of_tformula in
              let sc' = List.map sc ~f:Eformula.of_tformula in
              let epf2 = epf_of_tpf pf2 in
              let enf_constr = match constr_opt with
                | Some (EpfSup c) -> ESciLhs (ESlhsSPformula c)
                | _ -> assert false
              in
              ok (ECImplication (idx, ert, pos, epf1, ex', sc', epf2, rt, rcs, Some enf_constr))
            | _, _, true, _, _ ->
              (* Enforce by suppressing an arbitrary condition *)
              let epf1, constr_opt = convert_enforceable_pattern Enftype.suppressable pg_map pf1 in
              let ex' = List.map ex ~f:Eformula.of_tformula in
              let sc' = List.map sc ~f:Eformula.of_tformula in
              let epf2 = epf_of_tpf pf2 in
              let enf_constr = match constr_opt with
                | Some (EpfSup c) -> ESciLhs (ESlhsSPformula c)
                | _ -> assert false
              in
              ok (ECImplication (idx, ert, pos, epf1, ex', sc', epf2, rt, rcs, Some enf_constr))
            | _, _, _, true, _ ->
              (* Enforce by causing all effects *)
              let epf1 = epf_of_tpf pf1 in
              let ex' = List.map ex ~f:Eformula.of_tformula in
              let sc' = List.map sc ~f:Eformula.of_tformula in
              let epf2, constr_opt = convert_enforceable_pattern Enftype.causable pg_map pf2 in
              let enf_constr = match constr_opt with
                | Some (EpfCau c) -> ECciRhs c
                | _ -> assert false
              in
              ok (ECImplication (idx, ert, pos, epf1, ex', sc', epf2, rt, rcs, Some enf_constr))
            | _ -> assert false
          end
       end
    | TCDefinitionRef (idx, ert, pos, pf1, ex, sc, refs, f2) ->
      let e = get_predicate_name_exn f2 in
      let ef2 = Eformula.of_tformula f2 in
      begin match Map.find pols e with
        | Some t when Enftype.is_causable t ->
          (* Cause by causing all conditions, suppressing all exceptions, and causing all scopes  *)
          let ex', _ = convert_enforceable_tformulas ~combination_type:`Disj Enftype.suppressable pg_map ex in
          let sc', _ = convert_enforceable_tformulas Enftype.causable pg_map sc in
          let epf1, constr_opt = convert_enforceable_pattern Enftype.causable pg_map pf1 in
          let enf_constr = match constr_opt with
            | Some (EpfCau c) -> ECd (EClhsAll c)
            | _ -> assert false in
          ok (ECDefinitionRef (idx, ert, pos, epf1, ex', sc', refs, ef2, t, Some enf_constr))
        | Some t when Enftype.is_suppressable t->
          let itl_srp = if Enftype.is_transparent t then Some itl_srp else None in
          let v_ex = type_exceptions itl_srp pg_map ex (Enftype.neg t) in
          let v_sc = type_scopes itl_srp pg_map sc t in
          let v_pf = type_pattern itl_srp pos pg_map Enftype.suppressable pf1 in
          begin match v_ex, v_sc, v_pf with
            | Possible constraints, _, _ ->
              (* Suppress by causing an exception *)
              let _ = solve constraints |> List.hd_exn in
              let epf1 = epf_of_tpf pf1 in
              let ex', i_opt = convert_enforceable_tformulas ~combination_type:`Disj Enftype.causable pg_map ex in
              let sc' = List.map sc ~f:Eformula.of_tformula in
              let enf_constr = ESd (ESlhsCException (Option.value_exn i_opt)) in
              ok (ECDefinitionRef (idx, ert, pos, epf1, ex', sc', refs, ef2, t, Some enf_constr))
            | _, Possible constraints, _ ->
              (* Suppress by suppressing a scope *)
              let _ = solve constraints |> List.hd_exn in
              let epf1 = epf_of_tpf pf1 in
              let ex' = List.map ex ~f:Eformula.of_tformula in
              let sc', i_opt = convert_enforceable_tformulas Enftype.causable pg_map sc in
              let enf_constr = ESd (ESlhsSScope (Option.value_exn i_opt)) in
              ok (ECDefinitionRef (idx, ert, pos, epf1, ex', sc', refs, ef2, t, Some enf_constr))
            | _, _, Possible _ ->
              (* Suppress by suppressing a condition *)
              let epf1, constr_opt = convert_enforceable_pattern Enftype.causable pg_map pf1 in
              let ex' = List.map ex ~f:Eformula.of_tformula in
              let sc' = List.map sc ~f:Eformula.of_tformula in
              let enf_constr = match constr_opt with
                | Some (EpfSup c) -> ESd (ESlhsSPformula c)
                | _ -> assert false
              in
              ok (ECDefinitionRef (idx, ert, pos, epf1, ex', sc', refs, ef2, t, Some enf_constr))
            | _ -> assert false 
          end
        | t -> 
          let epf1 = epf_of_tpf pf1 in
          let ex' = List.map ex ~f:Eformula.of_tformula in
          let sc' = List.map sc ~f:Eformula.of_tformula in
          let ef2 = Eformula.of_tformula f2 in
          let enftype = Option.value t ~default:(match Map.find itl_observable e with
              | Some true -> Enftype.obs | _ -> Enftype.bot) in
          ok (ECDefinitionRef (idx, ert, pos, epf1, ex', sc', refs, ef2, enftype, None))
      end
    | TCDefinitionDis (tdisjuncts, g) as rule ->
      let e = get_predicate_name_exn g in
      let eg = Eformula.of_tformula g in
      begin match Map.find pols e with
        | Some t when Enftype.is_causable t ->
          (* Cause by causing one disjunct  *)
          let itl_srp = if Enftype.is_transparent t then Some itl_srp else None in
          let* typed_tdisjuncts =
            let f (k, td) = Err.WithErrors.(type_tdisjunct itl_srp pg_map t rule td >| (fun v -> (k, td, v))) in
            of_witherror (Err.WithErrors.all (List.map (Map.to_alist tdisjuncts) ~f)) in
          let* k, tdisjunct =
            match List.find typed_tdisjuncts ~f:(function (_, _, Possible _) -> true | _ -> false) with
            | Some (c, td, _) -> ok (c, td)
            | None -> error (Err.enforceability_error "no disjuncts can be made enforceable" LexingInfo.dummy) in
          let edisjunct, constr = convert_enforceable_tdisjunct itl_srp pg_map t tdisjunct in
          let edisjuncts =
            let f (k', td, _) = (k', if k = k' then edisjunct else edisjunct_of_tdisjunct td) in
            Map.of_alist_exn (module Int) (List.map ~f typed_tdisjuncts) in
          let constr = match constr with Some (ECd c) -> c | _ -> assert false in
          ok (ECDefinitionDis (edisjuncts, eg, t, Some (ECdd (k, constr))))
        | Some t when Enftype.is_suppressable t ->
          (* Suppress by suppressing all disjuncts *)
          let itl_srp = if Enftype.is_transparent t then Some itl_srp else None in
          let edisjuncts_and_constrs =
            let f td = convert_enforceable_tdisjunct itl_srp pg_map t td in
            Map.map ~f tdisjuncts in
          let edisjuncts = Map.map ~f:fst edisjuncts_and_constrs in
          let constrs =
            List.map ~f:(function (_, Some (ESd c)) -> c | _ -> assert false)
              (Map.data edisjuncts_and_constrs) in
          ok (ECDefinitionDis (edisjuncts, eg, t, Some (ESdd constrs)))
        | t ->
          let edisjuncts = Map.map tdisjuncts ~f:edisjunct_of_tdisjunct in
          let enftype = Option.value t ~default:(match Map.find itl_observable e with
              | Some true -> Enftype.obs | _ -> Enftype.bot) in
          ok (ECDefinitionDis (edisjuncts, eg, enftype, None))
      end
  in ecrule

let ecrules_from_tcrules (pg_map: pg_map) itl_srp pols rules :
    (int, ecrule, Int.comparator_witness) Base.Map.t Err.OrErrors.t =
  let open Err.OrErrors in
  debug (Printf.sprintf
          "ecrules_from_tcrules: pols: %s"
          (Util.string_of_pols ~f:Enftype.to_string pols));
  let rules_list = Map.to_alist rules in
  let* rules_list = all (List.map ~f:(fun (k, v) ->
                        ecrule_from_tcrule pg_map itl_srp pols v
                        >| (fun v -> (k, v))) rules_list) in
  ok (Map.of_alist_exn (module Int) rules_list)

(* Visitors for statements *)

let type_tsrule erule_map =
  function
  | TSRule (pos, idx, label, type_fixes, _, doc_string) -> begin
      let rule = Map.find_exn erule_map idx in
      ESRule (pos, idx, label, type_fixes, rule, doc_string)
    end
  | _ -> assert false

let type_tstmt erule_map = function
  | TSImport (pos, idents, import_format) ->
     ESImport (pos, idents, import_format)
  | TSSection (section_kind, full_label, label, title) -> 
     ESSection (section_kind, full_label, label, title)
  | TSRule _ as trule -> type_tsrule erule_map trule
  | TSEvent (event_type, name, typed_args, pol, doc_string) ->
     ESEvent (event_type, name, typed_args, pol, doc_string)
  | TSType (name, typ, doc_string) -> ESType (name, typ, doc_string)
  | TSFunction (name, arg_types, return_type, doc_string) ->
     ESFunction (name, arg_types, return_type, doc_string)
  | TSNote text -> ESNote text

(* Monotonicity - used for refinement *)

let pos_from_infos infos =
  List.fold infos ~init:LexingInfo.dummy ~f:(fun pos info -> LexingInfo.union_all [pos; info.pos])

let combine_str_info_maps m1 m2 =
  Map.merge m1 m2 ~f:(fun ~key:_ -> function
      | `Both (v1, v2) -> Some (List.dedup_and_sort (v1 @ v2) ~compare:compare_tinfo_type)
      | `Left v -> Some v
      | `Right v -> Some v)

let two_empty_maps = 
  Map.empty (module String), Map.empty (module String)

let four_empty_maps = 
  Map.empty (module String), Map.empty (module String),
  Map.empty (module String), Map.empty (module String)

let not_monotone_formulas ?(init=four_empty_maps) fs =
  let let_ctxt_mon, let_ctxt_anti_mon, init_mon, init_anti_mon = init in
  let non_monotones = List.map fs ~f:(fun f -> Tformula.non_monotone_predicates ~let_ctxt_mon ~let_ctxt_anti_mon ~init_mon ~init_anti_mon f) in
  let non_mons, non_anti_mons = List.unzip non_monotones in
  let mon = List.fold non_mons ~init:init_mon ~f:(fun mon f -> combine_str_info_maps mon f) in
  let anti_mon = List.fold non_anti_mons ~init:init_anti_mon ~f:(fun anti_mon f -> combine_str_info_maps anti_mon f) in
  mon, anti_mon

let not_monotone_pattern ?(init=four_empty_maps) (tpf: Tlex.Pattern.t) =
  let let_ctxt_mon, let_ctxt_anti_mon, init_mon, init_anti_mon = init in 
  let mon_fs, anti_mon_fs = not_monotone_formulas ~init tpf.fs in
  match tpf.patt with
  | PUntil (_, f) | PSince (_, f) ->
    let mon_f, anti_mon_f = Tformula.non_monotone_predicates ~let_ctxt_mon ~let_ctxt_anti_mon ~init_mon ~init_anti_mon f in
    let mon = combine_str_info_maps mon_fs mon_f in
    let anti_mon = combine_str_info_maps anti_mon_fs anti_mon_f in
    mon, anti_mon
  | _ -> mon_fs, anti_mon_fs


let not_monotone_disjunct ?(init=four_empty_maps) (disjunct: Tlex.tdisjunct) =
  (* let let_ctxt_mon, let_ctxt_anti_mon, init_mon, init_anti_mon = init in  *)
  let mon_pf, anti_mon_pf = not_monotone_pattern ~init disjunct.pf in
  let mon_ex, anti_mon_ex = not_monotone_formulas ~init disjunct.exceptions in
  let mon_sc, anti_mon_sc = not_monotone_formulas ~init disjunct.scopes in
  let mon = combine_str_info_maps mon_pf (combine_str_info_maps anti_mon_ex mon_sc) in
  let anti_mon = combine_str_info_maps anti_mon_pf (combine_str_info_maps mon_ex anti_mon_sc) in
  mon, anti_mon

let not_monotone_tcrule ?(init =four_empty_maps)  tcrule =
  (** computes the predicates that appear none-(anti)-monotonely in a rule `rule`
      along with information such as a which occurrence of a predicate is none-(anti)-monotone *)
  let let_ctxt_mon, let_ctxt_anti_mon, init_mon, init_anti_mon = init in
  match tcrule with
  (* TODO[JD]: implement monotonicity check for rules *)
  (* | TCImplication (i, tr_ty, info, p, fs, gs, q, t_ty, constrs) -> *)
  | TCImplication (_, _, _, pf1, ex, sc, pf2, _, _) ->
    let mon1, anti_mon1 = not_monotone_pattern ~init pf1 in
    let mon2, anti_mon2 = not_monotone_pattern ~init pf2 in
    let mon_ex, anti_mon_ex = not_monotone_formulas ~init ex in
    let mon_sc, anti_mon_sc = not_monotone_formulas ~init sc in
    let mon = combine_str_info_maps (combine_str_info_maps mon1 mon2) (combine_str_info_maps anti_mon_ex mon_sc) in
    let anti_mon = combine_str_info_maps (combine_str_info_maps anti_mon1 anti_mon2) (combine_str_info_maps mon_ex anti_mon_sc) in
    let_ctxt_mon, let_ctxt_anti_mon, mon, anti_mon
  (* | TCDefinitionRef (i, tr_ty, info, p, fs, gs, refs, h) -> *)
  (* | TCDefinitionRef (_, _, _, pf1, ex, sc, refs, f2) -> *)
  | TCDefinitionRef (_, _, _, pf1, ex, sc, _, f2) ->
    let mon1, anti_mon1 = not_monotone_pattern ~init pf1 in
    let mon_ex, anti_mon_ex = not_monotone_formulas ~init ex in
    let mon_sc, anti_mon_sc = not_monotone_formulas ~init sc in
    let mon = combine_str_info_maps mon1 (combine_str_info_maps anti_mon_ex mon_sc) in
    let anti_mon = combine_str_info_maps anti_mon1 (combine_str_info_maps mon_ex anti_mon_sc) in
    let predicate_name = get_predicate_name_exn f2 in
    let let_ctxt_mon = Map.update let_ctxt_mon predicate_name ~f:(fun _ -> mon) in
    let let_ctxt_anti_mon = Map.update let_ctxt_anti_mon predicate_name ~f:(fun _ -> anti_mon) in
    let_ctxt_mon, let_ctxt_anti_mon, init_mon, init_anti_mon
  | TCDefinitionDis (discuncts, f) ->
    let predicate_name = get_predicate_name_exn f in
    let disjuncts_mons = Map.map discuncts ~f:(not_monotone_disjunct ~init) in
    let mon_disjuncts = Map.fold disjuncts_mons ~init:init_mon ~f:(fun ~key:_ ~data:(mon, _) acc -> combine_str_info_maps acc mon) in
    let anti_mon_disjuncts = Map.fold disjuncts_mons ~init:init_anti_mon ~f:(fun ~key:_ ~data:(_, anti_mon) acc -> combine_str_info_maps acc anti_mon) in
    let let_ctxt_mon = Map.update let_ctxt_mon predicate_name ~f:(fun _ -> mon_disjuncts) in
    let let_ctxt_anti_mon = Map.update let_ctxt_anti_mon predicate_name ~f:(fun _ -> anti_mon_disjuncts) in
    let_ctxt_mon, let_ctxt_anti_mon, init_mon, init_anti_mon

let check_mon_constrs (order: int list) tcrules (mon_constrs: ('str_map * 'str_map) option) : unit Err.OrErrors.t =
  let open Err.OrErrors in
  match mon_constrs with
  | None -> ok ()
  (* | Some (req_mon, req_anti_mon) when Map.is_empty req_mon && Map.is_empty req_anti_mon ->
    ok () *) 
  | Some (req_mon, req_anti_mon) ->
    (* if Option.is_some mon_constrs then (Err.print_mem_stat (); debug (Printf.sprintf "mono: %d, anti mono: %d" (Map.length req_mon) (Map.length req_anti_mon)); assert false); *)
    (* TODO[JD] example/GDPR/ref-debug/gdpr_mgow.rex runs out of memory here *)
    let _, _, not_mon, not_anti_mon = 
      List.fold order
      ~init:four_empty_maps
      ~f:(fun init idx -> not_monotone_tcrule ~init (Map.find_exn tcrules idx))
    in
    if Option.is_some mon_constrs then (
      debug (Printf.sprintf "mono: %d, anti mono: %d" (Map.length req_mon)
               (Map.length req_anti_mon)));
    let not_mon = Map.map not_mon ~f:(fun v -> pos_from_infos v) in
    let not_anti_mon = Map.map not_anti_mon ~f:(fun v -> pos_from_infos v) in
    let mon_err = Map.filter_keys not_mon ~f:(fun k -> Map.mem req_mon k) in
    let anti_mon_err = Map.filter_keys not_anti_mon ~f:(fun k -> Map.mem req_anti_mon k) in
    let monotone_error pred (pos1: LexingInfo.t) =
      let pos2 = Map.find_exn req_mon pred in
      let pos1_str = LexingInfo.to_string pos1 in
      let msg = if List.length pos1.ranges > 1 then
        Printf.sprintf "Predicate \"%s\" must be monotone, but appears in non-monotone ways at %s" pred pos1_str
      else
        Printf.sprintf "Predicate \"%s\" must be monotone, but appears in a non-monotone way at %s" pred pos1_str in
      Err.refinement_error msg pos2 in
    let anti_monotone_error pred (pos1: LexingInfo.t) =
      let pos2 = Map.find_exn req_mon pred in
      let pos1_str = LexingInfo.to_string pos1 in
      let msg = if List.length pos1.ranges > 1 then
        Printf.sprintf "Predicate \"%s\" must be anti-monotone, but appears in non-anti-monotone ways at %s" pred pos1_str
      else
        Printf.sprintf "Predicate \"%s\" must be anti-monotone, but appears in a non-anti-monotone way at %s" pred pos1_str in
      Err.refinement_error msg pos2 in
    match Map.is_empty mon_err, Map.is_empty anti_mon_err with
    | true, true -> ok ()
    | _, _ ->
      let _, monotonicity_errors = Map.mapi mon_err
        ~f:(fun ~key ~data -> monotone_error key data)
        |> Map.to_alist |> List.unzip in
      let _, anti_monotonicity_errors = Map.mapi anti_mon_err
        ~f:(fun ~key ~data -> anti_monotone_error key data)
        |> Map.to_alist |> List.unzip in
      errors (monotonicity_errors @ anti_monotonicity_errors)

(* Main typing function *)

let do_type
    ?(mon_constrs: ('str_map * 'str_map) option)
    (tprog: Tlex.tprog)
    (b: Interval.v)
  : Elex.eprog Err.OrErrors.t =
  
  let open Err.OrErrors in

  (* Create tcrules *)
  let tcrules = create_tcrules tprog in

  (* Initialize signature, set reference to b *)
  Tlex.Sig.set_prog tprog;
  b_ref := b;
  
  (* Order tcrules topologically *)
  let* rule_order = topological_rule_order tprog tcrules in
  let* _ = check_mon_constrs rule_order tcrules mon_constrs in (* Only relevant for refinement *)
  
  (* Compute verdict, solve constraints *)
  let* constraints_list, itl_srp, pg_map = type_tcrules tprog tcrules rule_order in
  let possible_pols = List.map ~f:(Map.map ~f:Enftype.Constraint.solve) constraints_list in
 
  (* Convert tcrules to erules and ecrules *)
  let erules = erules_from_tcrules tcrules in
  let f pols =
    match ecrules_from_tcrules pg_map itl_srp pols tcrules with
      | Ok ecrules -> Some (ecrules, pols)
      | Errors _ -> None
  in
  let possible_ecrules = List.filter_map possible_pols ~f in
  let* ecrules, pols = match possible_ecrules with
    | [] -> error (Err.enforceability_error "No policies found that allow to type the program" LexingInfo.dummy)
    | (ecrules, pols)::_ -> ok (ecrules, pols) in
  let estmts = List.map tprog.tstmts ~f:(type_tstmt erules) in
  
  ok {
    estmts;
    ealiases          = tprog.taliases;
    esubtypes         = tprog.tsubtypes;
    eevents           = tprog.tevents;
    efunctions        = tprog.tfunctions;
    rule_ctxts        = tprog.rule_ctxts;
    rule_tree         = tprog.rule_tree;
    ecrules;
    compilation_order = rule_order;
    pols;
    eassumed          = Map.empty (module String)
  }
