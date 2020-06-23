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
(* --- Main Generator                                                     --- *)
(* -------------------------------------------------------------------------- *)

let makePackage pkg name fmt =
  begin
    let open Pkg in
    Format.fprintf fmt "/* --- Generated Frama-C Server API --- */@\n" ;
    Format.fprintf fmt "/**@\n%a@\n" pp_descr pkg.p_descr ;
    Format.fprintf fmt "  @@packageDocumentation@\n" ;
    Format.fprintf fmt "  @@module frama-c/%s@\n" name ;
    Format.fprintf fmt "*/@\n" ;
    let names = Pkg.resolve ~keywords pkg in
    Format.fprintf fmt "import * as Json from 'dome/data/json'@\n" ;
    Pkg.IdMap.iter
      (fun id name ->
         let pkg = Pkg.name_of_pkg ~sep:"/" id.plugin id.package in
         if id.name = name then
           Format.fprintf fmt "import { %s } from '%s';@\n"
             name pkg
         else
           Format.fprintf fmt "import { %s: %s } from '%s';@\n"
             id.name name pkg
      ) names ;
    List.iter
      (fun d ->
         Format.fprintf fmt "// Declare '%a'@\n" Pkg.pp_ident d.d_ident
      ) pkg.p_content
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
        Format.eprintf "DIR %S@." dir ;
        if not (Sys.file_exists dir && Sys.is_directory dir) then
          Extlib.mkdir ~parents:true dir 0o755 ;
        Command.print_file file (makePackage pkg name) ;
      end
  end


let () = Db.Main.extend generate

(* -------------------------------------------------------------------------- *)
