open Cil_types

let add_headers tbl id headers =
  try
    let old_headers = Hashtbl.find tbl id in
    Hashtbl.replace tbl id (old_headers @ headers)
  with Not_found ->
    Hashtbl.replace tbl id headers

class stdlib_visitor = object
  inherit Visitor.frama_c_inplace
  val in_stdlib = ref false
  val idents : (string, string list) Hashtbl.t = Hashtbl.create 500

  method! vglob_aux g =
    match Cil.findAttribute "fc_stdlib" (Cil.global_attributes g) with
    | [] ->
      in_stdlib := false;
      Cil.SkipChildren
    | attrparams ->
      let headers =
        Extlib.filter_map' (fun ap ->
            match ap with
            | AStr s -> s
            | _ -> assert false
          ) (Extlib.string_suffix ".h") attrparams
      in
      in_stdlib := true;
      begin
        match g with
        | GEnumTag ({eorig_name = id}, _loc) | GEnumTagDecl ({eorig_name = id}, _loc)
        | GCompTag ({corig_name = id}, _loc) | GCompTagDecl ({corig_name = id}, _loc)
        | GVar ({vorig_name = id}, _, _loc) | GVarDecl ({vorig_name = id}, _loc)
        | GFunDecl (_, {vorig_name = id}, _loc)
        | GFun ({svar = {vorig_name = id}}, _loc) ->
          add_headers idents id headers
        | _ -> ()
      end;
      Cil.DoChildren

  method get_idents = idents
end

let run_once = ref false

module StringSet = Set.Make(String)

let set_of_data_from_list dir f =
  let file = Filename.concat dir f in
  let open Yojson.Basic.Util in
  Kernel.feedback "parsing %s" f;
  let json = Yojson.Basic.from_file file in
  let elements = json |> member "data" |> to_list in
  List.fold_left (fun acc e ->
      StringSet.add (e |> to_string) acc
    ) StringSet.empty elements


let set_of_data_from_assoc dir f =
  let file = Filename.concat dir f in
  let open Yojson.Basic.Util in
  Kernel.feedback "parsing %s" f;
  let json = Yojson.Basic.from_file file in
  let elements = json |> member "data" |> to_assoc in
  List.fold_left (fun acc (ident, _) ->
      StringSet.add ident acc
    ) StringSet.empty elements

let hashtable_of_ident_headers dir f =
  let file = Filename.concat dir f in
  let idents = Hashtbl.create 500 in
  let open Yojson.Basic.Util in
  Kernel.feedback "parsing %s" f;
  let json = Yojson.Basic.from_file file in
  let elements = json |> member "data" |> to_assoc in
  List.iter (fun (ident, values) ->
      let header = values |> member "header" |> to_string in
      Hashtbl.replace idents ident header
    ) elements;
  idents

let hashtable_of_ident_headers_and_extensions dir f =
  let file = Filename.concat dir f in
  let idents = Hashtbl.create 500 in
  let open Yojson.Basic.Util in
  Kernel.feedback "parsing %s" f;
  let json = Yojson.Basic.from_file file in
  let elements = json |> member "data" |> to_assoc in
  List.iter (fun (ident, values) ->
      let header = values |> member "header" |> to_string in
      let extensions = values |> member "extensions" |> to_list in
      Hashtbl.replace idents ident (header, extensions)
    ) elements;
  idents

let () =
  Db.Main.extend (fun () ->
      if not !run_once then begin
        run_once := true;
        let vis = new stdlib_visitor in
        ignore (Visitor.visitFramacFile (vis :> Visitor.frama_c_visitor) (Ast.get ()));
        let fc_stdlib_idents = vis#get_idents in
        let dir = Filename.concat Fc_config.datadir "compliance" in
        let c11_idents = hashtable_of_ident_headers dir "c11_functions.json" in
        let c11_headers = set_of_data_from_list dir "c11_headers.json" in
        let glibc_idents = set_of_data_from_list dir "glibc_functions.json" in
        let posix_idents = hashtable_of_ident_headers_and_extensions dir "posix_identifiers.json" in
        let nonstandard_idents = set_of_data_from_assoc dir "nonstandard_identifiers.json" in
        Hashtbl.iter (fun id headers ->
            if not (Extlib.string_prefix "__" id) &&
               not (Extlib.string_prefix "Frama_C" id) &&
               List.filter (fun h -> not (Extlib.string_prefix "__fc" h))
                 headers <> []
            then
              let id_in_c11 = Hashtbl.mem c11_idents id in
              let id_in_posix = Hashtbl.mem posix_idents id in
              let id_in_glibc = StringSet.mem id glibc_idents in
              let id_in_nonstd = StringSet.mem id nonstandard_idents in
              let header_in_c11 h = StringSet.mem h c11_headers in
              if id_in_c11 then begin
                (* Check that the header is the expected one.
                   Note that some symbols may appear in more than one header,
                   possibly due to collisions
                   (e.g. 'flock' as type and function). *)
                let h = Hashtbl.find c11_idents id in
                if not (header_in_c11 h) then
                  Kernel.warning "<%a>:%s : C11 says %s"
                    (Pretty_utils.pp_list ~sep:"," Format.pp_print_string) headers
                    id h
              end
              else if id_in_posix then begin
                (* check the header is the expected one *)
                let (h, _) = Hashtbl.find posix_idents id in
                (* arpa/inet.h and netinet/in.h are special cases: due to mutual
                   inclusion, there are always issues with their symbols;
                   also, timezone is a special case, since it is a type in
                   sys/time.h, but a variable in time.h in POSIX. However, its
                   declaration as extern is erased by rmtmps, since it is
                   unused. *)
                if not (List.mem h headers) &&
                   not (List.mem "arpa/inet.h" headers && h = "netinet/in.h" ||
                        List.mem "netinet/in.h" headers && h = "arpa/inet.h") &&
                   id <> "timezone"
                then
                  Kernel.warning "<%a>:%s : POSIX says %s"
                    (Pretty_utils.pp_list ~sep:"," Format.pp_print_string) headers
                    id h
              end
              else if not (id_in_glibc || id_in_nonstd) then
                Kernel.warning "<%a>:%s : unknown identifier"
                  (Pretty_utils.pp_list ~sep:"," Format.pp_print_string) headers
                  id
          ) fc_stdlib_idents;
      end)
