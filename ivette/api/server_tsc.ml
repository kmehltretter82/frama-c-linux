(* -------------------------------------------------------------------------- *)
(* --- Frama-C TypeScript API Generator                                   --- *)
(* -------------------------------------------------------------------------- *)

module Self = Plugin.Register
  (struct
    let name = "Server TypeScript API"
    let shortname = "server-tsc"
    let help = "Generate TypeScript API for Server"
  end)

module TSC = Self.Action
    (struct
      let option_name = "-server-tsc"
      let help = "Generate TypeScript API"
    end)

module OUT = Self.String
    (struct
      let option_name = "-server-tsc-out"
      let arg_name = "dir"
      let default = "api"
      let help = "Output directory (default is './api')"
    end)

module Md = Markdown
module Pkg = Server.Package

(* -------------------------------------------------------------------------- *)
(* --- TS Utils                                                           --- *)
(* -------------------------------------------------------------------------- *)

let keywords = [
  "break"; "case"; "catch"; "class"; "const"; "continue"; "debugger";
  "default"; "delete"; "do"; "else"; "enum"; "export"; "extends"; "false";
  "finally"; "for"; "function"; "if"; "import"; "in"; "instanceof"; "new";
  "null"; "return"; "super"; "switch"; "this"; "throw"; "true"; "try";
  "typeof"; "var"; "void"; "while"; "with"; "as"; "implements"; "interface";
  "let"; "package"; "private"; "protected"; "public"; "static"; "yield"; "any";
  "boolean"; "constructor"; "declare"; "get"; "module"; "require"; "number";
  "set"; "string"; "symbol"; "type"; "from"; "of";
  "Json";
]

let pp_descr = Md.pp_text ?page:None

(* -------------------------------------------------------------------------- *)
(* --- Jtype Generator                                                    --- *)
(* -------------------------------------------------------------------------- *)

let makeJtype ~self ~names =
  let open Pkg in
  let pp_ident fmt id =
    match IdMap.find id names with
    | name -> Format.pp_print_string fmt name
    | exception Not_found -> Self.abort "Undefined '%a'" pp_ident id in
  let rec pp fmt = function
    | Jany -> Format.pp_print_string fmt "Json.json"
    | Jself -> Format.pp_print_string fmt self
    | Jnull -> Format.pp_print_string fmt "null"
    | Jnumber -> Format.pp_print_string fmt "number"
    | Jboolean -> Format.pp_print_string fmt "boolean"
    | Jstring -> Format.pp_print_string fmt "string"
    | Jtag tag -> Format.fprintf fmt "'%s'" tag
    | Jkey kd -> Format.fprintf fmt "Json.Key<'%s'>" kd
    | Jindex kd -> Format.fprintf fmt "Json.Index<'%s'>" kd
    | Jdata id -> pp_ident fmt id
    | Joption js -> Format.fprintf fmt "%a |@ undefined" pp js
    | Jtuple js ->
      Pretty_utils.pp_list ~pre:"@[<hov 2>[ " ~sep:",@ " ~suf:"@ ]@]" pp fmt js
    | Junion js ->
      Pretty_utils.pp_list ~pre:"@[<hov 0>" ~sep:" |@ " ~suf:"@]" protect fmt js
    | Jrecord fjs ->
      Pretty_utils.pp_list ~pre:"@[<hov 2>{ " ~sep:",@ " ~suf:"@ }@]" field fmt fjs
    | Jarray js -> Format.fprintf fmt "%a[]" protect js
    | Jassoc (kd,js) -> Format.fprintf fmt "Json.Dict<'%s',%a>" kd pp js
  and protect fmt js = match js with
    | Junion _ | Joption _ -> Format.fprintf fmt "@[<hov 2>(%a)@]" pp js
    | _ -> pp fmt js
  and field fmt (fd,js) = Format.fprintf fmt "@[<hov 4>%s:@ %a@]" fd pp js
  in pp

(* -------------------------------------------------------------------------- *)
(* --- Declaration Generator                                              --- *)
(* -------------------------------------------------------------------------- *)

let makeDeclaration fmt names d =
  let open Pkg in
  Format.fprintf fmt "@\n@\n/** %a */@\n" pp_descr d.d_descr ;
  let self = d.d_ident.name in
  let jtype = makeJtype ~self ~names in
  match d.d_kind with
  | D_type js ->
    Format.fprintf fmt "@[<hv 2>export type %s =@ %a;@]@\n" self jtype js
  | D_record fjs ->
    Format.fprintf fmt "export interface %s {@\n" self ;
    List.iter
      (fun { fd_name = fd ; fd_type = js ; fd_descr = doc } ->
         if doc<>[] then Format.fprintf fmt "  /** %a */@\n" pp_descr doc ;
         match js with
         | Joption js ->
           Format.fprintf fmt "  @[<hov 2>%s?: %a;@]@\n" fd jtype js
         | _ ->
           Format.fprintf fmt "  @[<hov 2>%s: %a;@]@\n" fd jtype js
      ) fjs ;
    Format.fprintf fmt "}@\n" ;
  | D_enum tgs ->
    Format.fprintf fmt "export enum %s {@\n" self ;
    List.iter
      (fun { tg_name = tag ; tg_descr = doc } ->
         if doc<>[] then Format.fprintf fmt "  /** %a */@\n" pp_descr doc ;
         Format.fprintf fmt "  %s = '%s';@\n" tag tag ;
      ) tgs ;
    Format.fprintf fmt "}@\n" ;
  | _ -> ()

(* -------------------------------------------------------------------------- *)
(* --- Package Generator                                                  --- *)
(* -------------------------------------------------------------------------- *)

let makePackage pkg name fmt =
  begin
    let open Pkg in
    Format.fprintf fmt "/* --- Generated Frama-C Server API --- */@\n@\n" ;
    Format.fprintf fmt "/** %s@\n" pkg.p_title ;
    if pkg.p_descr <> [] then
      Format.fprintf fmt "@\n@\n%a@\n" pp_descr pkg.p_descr ;
    Format.fprintf fmt "   @@packageDocumentation@\n" ;
    Format.fprintf fmt "   @@module frama-c/%s@\n" name ;
    Format.fprintf fmt "*/@\n@\n" ;
    let names = Pkg.resolve ~keywords pkg in
    Format.fprintf fmt "import * as Json from 'dome/data/json'@\n" ;
    Pkg.IdMap.iter
      (fun id name ->
         if id.plugin <> pkg.p_plugin ||
            id.package <> pkg.p_package
         then
           let pkg = Pkg.name_of_pkg ~sep:"/" id.plugin id.package in
           if id.name = name then
             Format.fprintf fmt "import { %s } from 'api/%s';@\n"
               name pkg
           else
             Format.fprintf fmt "import { %s: %s } from 'api/%s';@\n"
               id.name name pkg
      ) names ;
    List.iter (makeDeclaration fmt names) pkg.p_content
  end

(* -------------------------------------------------------------------------- *)
(* --- Main Generator                                                     --- *)
(* -------------------------------------------------------------------------- *)

let generate () =
  begin
    Pkg.iter
      begin fun pkg ->
        Self.feedback "Package %a" Pkg.pp_pkgname pkg ;
        let name = Pkg.name_of_pkginfo ~sep:"/" pkg in
        let file = Printf.sprintf "%s/%s.ts" (OUT.get ()) name in
        let dir = Filename.dirname file in
        if not (Sys.file_exists dir && Sys.is_directory dir) then
          Extlib.mkdir ~parents:true dir 0o755 ;
        Command.print_file file (makePackage pkg name) ;
      end
  end

let () = Db.Main.extend generate

(* -------------------------------------------------------------------------- *)
