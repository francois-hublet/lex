open Core
open Lex_lib

module Time = MFOTL_lib.Time

let debug_main = ref false
let debug msg = if !debug_main then Errors.debug_print ~f_name:(Some "main.ml") msg

let modes = "mfotl (default), doc, owl, owlgraph, template"
let input_formats = "formex (default), akomaNtoso"

(* Keeps only the declarations of one section, e.g. "article 6" *)
let restrict section eprog =
  match section with
  | None -> eprog, ""
  | Some spec ->
     (try Owl.restrict_to_section spec eprog with
      | Owl.Section_error msg ->
         print_endline ("Cannot restrict to section: " ^ msg);
         exit (-1)),
     Owl.section_suffix spec

let loop filename mode f o b to_ unroll label ns section () =
  let open Errors.OrErrors in
  let lexpath = Filename.dirname (Sys.get_argv()).(0) in
  let filepath = Filename.dirname filename
  and basename = Filename.basename filename in
  Util.z3_to := Option.value ~default:"1000" to_;
  let b = match b with (* TODO: check if this way of extracting an upper bound b make sense? *)
    | None -> Time.Span.zero
    | Some b -> Time.Span.of_string b in
  match mode with
  | None | Some "mfotl" -> begin
      match Modules.do_type [lexpath] b filepath basename with
      | Ok (_, eprog) ->
         let cprog = Compiler.compile eprog unroll label in
         begin match o with
         | None -> print_endline (Clex.to_string cprog)
         | Some out_fn -> let sig_fn = out_fn ^ ".sig" in
                          let formula_fn = out_fn ^ ".mfotl" in
                          Clex.to_files cprog sig_fn formula_fn
         end
      | Errors errs ->
         print_string (Errors.to_string_multiple errs);
         exit (-1)
    end
  | Some "doc" -> begin
      match Modules.do_type [lexpath] b filepath basename with
      | Ok (_, eprog) -> 
         let outname = Option.fold o ~init:(filename ^ "_doc.html") ~f:(fun _ x -> x) in
         Doc.to_file basename outname eprog
      | Errors errs ->
         print_string (Errors.to_string_multiple errs);
         exit (-1)
    end
  | Some "owl" -> begin
      match Modules.do_type [lexpath] b filepath basename with
      | Ok (_, eprog) ->
         let name = Filename.chop_extension basename in
         let base = Option.value ns ~default:(Owl.default_ontology_iri name) in
         let eprog, suffix = restrict section eprog in
         let source = basename ^ Option.value_map section ~default:"" ~f:(Printf.sprintf ", %s") in
         let outname = Option.value o ~default:(filename ^ suffix ^ ".owl") in
         Owl.to_file ~source ~base outname eprog
      | Errors errs ->
         print_string (Errors.to_string_multiple errs);
         exit (-1)
    end
  | Some "owlgraph" -> begin
      match Modules.do_type [lexpath] b filepath basename with
      | Ok (_, eprog) ->
         let eprog, suffix = restrict section eprog in
         let outname = Option.value o ~default:(filename ^ suffix ^ ".png") in
         (try Owl.to_png outname eprog with
          | Owl.Graphviz_error msg ->
             print_endline ("Cannot draw the ontology: " ^ msg);
             exit (-1))
      | Errors errs ->
         print_string (Errors.to_string_multiple errs);
         exit (-1)
    end
  | Some "template" -> begin
      let format, xml = match f with
        | Some "akomaNtoso" -> Lex.IAkomaNtoso, AkomaNtoso.read_file filepath basename
        | _ -> Lex.IFormex, Formex.read_file filepath basename in (*TODO [JD]: actively check if the input format is 'formex' and give an error if it is an unkown format*)
      let name = Filename.chop_extension basename in
      let lex = LegalXml.to_lex format [name] xml in
      let outname = Option.fold o ~init:(filename ^ "_lex.lex") ~f:(fun _ x -> x) in
      Lex.prog_to_file outname lex
    end
  | Some m ->
    print_string ("Unknown mode: " ^ m ^ "\nAvailable modes: " ^ modes);
    exit (-1)

let () =
  (*Printf.printf "HELP";*)
  debug "entered main";
  Command.basic_spec ~summary:"Parse Lex"
    Command.Spec.(empty
                  +> anon ("filename" %: string)
                  +> flag "-mode" (optional string) ~doc:("mode options: " ^ modes)
                  +> flag "-f" (optional string) ~doc:("input format options: " ^ input_formats)
                  +> flag "-o" (optional string) ~doc:"output file"
                  +> flag "-b" (optional string) ~doc:"upper bound for the time interval"
                  +> flag "-to" (optional string) ~doc:"Z3 timeout"
                  +> flag "-unroll" no_arg ~doc:"unroll let bindings in output"
                  +> flag "-label" no_arg ~doc:"label obligations with position in file"
                  +> flag "-ns" (optional string) ~doc:"ontology IRI used by -mode owl"
                  +> flag "-section" (optional string)
                       ~doc:"restrict -mode owl and -mode owlgraph to a section, e.g. \"article 6\""
                  )
    loop
  |> Command_unix.run
     
