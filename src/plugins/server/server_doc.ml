(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2020                                               *)
(*    CEA (Commissariat à l'énergie atomique et aux énergies              *)
(*         alternatives)                                                  *)
(*                                                                        *)
(*  you can redistribute it and/or modify it under the terms of the GNU   *)
(*  Lesser General Public License as published by the Free Software       *)
(*  Foundation, version 2.1.                                              *)
(*                                                                        *)
(*  It is distributed in the hope that it will be useful,                 *)
(*  but WITHOUT ANY WARRANTY; without even the implied warranty of        *)
(*  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         *)
(*  GNU Lesser General Public License for more details.                   *)
(*                                                                        *)
(*  See the GNU Lesser General Public License version 2.1                 *)
(*  for more details (enclosed in the file licenses/LGPLv2.1).            *)
(*                                                                        *)
(**************************************************************************)

(* -------------------------------------------------------------------------- *)
(* --- Server Documentation                                               --- *)
(* -------------------------------------------------------------------------- *)

open Markdown
type json = Yojson.Basic.t
module Senv = Server_parameters
module Pages = Map.Make(String)

type chapter = [ `Protocol | `Kernel | `Plugin of string ]

(* Section contents can be generated statically or dynamically.
   Typically, general kernel dictionary entries can be extended by plugins.
   The general case is to have a function that builds the (final) content
   on demand. *)
type section = (unit -> Markdown.elements)

type page = {
  path : string ;
  rootdir : string ; (* path to document root *)
  chapter : chapter ;
  title : string ;
  order : int ;
  intro : Markdown.elements ;
  mutable sections : section list ;
}

let order = ref 0
let pages : page Pages.t ref = ref Pages.empty
let plugins : string list ref = ref []
let entries : (string * Markdown.href) list ref = ref []
let path page = page.path
let href page name : Markdown.href = Section( page.path , name )

(* -------------------------------------------------------------------------- *)
(* --- Page Collection                                                    --- *)
(* -------------------------------------------------------------------------- *)

let chapter pg = pg.chapter

let path_for chapter filename =
  match chapter with
  | `Protocol -> "." , filename
  | `Kernel -> ".." , Printf.sprintf "kernel/%s" filename
  | `Plugin name -> "../.." , Printf.sprintf "plugins/%s/%s" name filename

let page chapter ~title ?(descr=[]) ~filename () =
  let rootdir , path = path_for chapter filename in
  try
    let other = Pages.find path !pages in
    Senv.failure "Duplicate page '%s' path@." path ; other
  with Not_found ->
    let intro = match chapter with
      | `Protocol ->
        Printf.sprintf "%s/server/protocol/%s" Fc_config.datadir filename
      | `Kernel ->
        Printf.sprintf "%s/server/kernel/%s" Fc_config.datadir filename
      | `Plugin name ->
        if not (List.mem name !plugins) then plugins := name :: !plugins ;
        Printf.sprintf "%s/%s/server/%s" Fc_config.datadir name filename in
    let intro =
      if Sys.file_exists intro
      then descr @ Markdown.rawfile intro
      else Markdown.(section ~title descr) in
    let order = incr order ; !order in
    let page = { order ; rootdir ; path ;
                 chapter ; title ; intro ;
                 sections=[] } in
    pages := Pages.add path page !pages ; page

let static () = []

let publish ~page ?name ?(index=[]) ~title
    ?(contents=[])
    ?(generated=static)
    () =
  let id = match name with Some id -> id | None -> title in
  let href = Section( page.path , id ) in
  let section () = Markdown.section ?name ~title (contents @ generated ()) in
  List.iter (fun entry -> entries := (entry , href) :: !entries) index ;
  page.sections <- section :: page.sections ; href

let protocole ~title ~filename =
  ignore (page `Protocol ~title ~filename ())

let () = protocole ~title:"Architecture" ~filename:"server.md"

(* -------------------------------------------------------------------------- *)
(* --- Package Publication                                                --- *)
(* -------------------------------------------------------------------------- *)

let page_of_package pkg =
  let open Package in
  let chapter = match pkg.d_plugin with
    | Kernel -> `Kernel | Plugin p -> `Plugin p in
  let filename = String.concat "_" pkg.d_package ^ ".md" in
  try
    let _,path = path_for chapter filename in
    Pages.find path !pages
  with Not_found ->
    let path = match pkg.d_plugin with
      | Kernel -> pkg.d_package
      | Plugin p -> p :: pkg.d_package in
    let title = Printf.sprintf "Package %s" (String.concat "." path) in
    page chapter ~title ~descr:pkg.d_userdoc ~filename ()

let declaration page links decl =
  let open Package in
  let name = decl.d_ident.name in
  let contents = block decl.d_descr in
  let href = publish ~page ~name ~contents () in
  links := IdMap.add decl.d_ident href !links

let package pkg =
  begin
    let page = page_of_package pkg in
    let links = ref Package.IdMap.empty in
    List.iter (declaration page links) pkg.Package.d_content ;
  end

(* -------------------------------------------------------------------------- *)
(* --- Tables of Content                                                  --- *)
(* -------------------------------------------------------------------------- *)

let title_of_chapter = function
  | `Protocol -> "Server Protocols"
  | `Kernel -> "Kernel Services"
  | `Plugin name -> "Plugin " ^ String.capitalize_ascii name

let pages_of_chapter c =
  let w = ref [] in
  Pages.iter
    (fun _ p -> if p.chapter = c then w := p :: !w) !pages ;
  List.sort (fun p q -> p.order - q.order) !w

let table_of_chapter c =
  [H2 (Markdown.plain (title_of_chapter c), None);
   Block (list (List.map
                  (fun p -> text (link ~text:(plain p.title) ~page:p.path ()))
                  (pages_of_chapter c)))]

let table_of_contents () =
  table_of_chapter `Protocol @
  table_of_chapter `Kernel @
  List.concat
    (List.map
       (fun p -> table_of_chapter (`Plugin p))
       (List.sort String.compare !plugins))

module Cmap = Map.Make
    (struct
      type t = string list
      let compare = Transitioning.Stdlib.compare
    end)

let index_entry (title,href) =
  text @@ Markdown.href ~text:(plain title) href

let index () =
  let category name =
    match List.rev (String.split_on_char '.' name) with
    | [] -> []
    | _::rpath -> List.rev rpath in
  let cmap =
    List.fold_left
      (fun cs entry ->
         let c = category (fst entry) in
         let es = try Cmap.find c cs with Not_found -> [] in
         Cmap.add c (entry :: es) cs)
      Cmap.empty !entries in
  let by_name (a,_) (b,_) = String.compare a b in
  let categories = Cmap.fold
      (fun c es ces -> ( c , List.sort by_name es ) :: ces)
      cmap [] in
  begin
    List.fold_left
      (fun elements (c,es) ->
         let entries = Block (list @@ List.map index_entry es) :: elements in
         if c = [] then entries
         else
           let cname = String.concat "." c in
           let title = Printf.sprintf "Index of `%s`" cname in
           H3(plain title,None) :: entries
      ) [] categories
  end

let link ~toc ~title ~href : json =
  let link = [ "title" , `String title ; "href" , `String href ] in
  `Assoc (if not toc then link else ( "toc" , `Bool true ) ::  link)

let link_page page : json list =
  List.fold_right
    (fun p links ->
       if p.chapter = page.chapter then
         let toc = (p.path = page.path) in
         let href = Filename.basename p.path in
         link ~toc ~title:p.title ~href :: links
       else links
    ) (pages_of_chapter page.chapter) []

let maindata : json =
  `Assoc [
    "document", `String "Frama-C Server" ;
    "title",`String "Documentation" ;
    "root", `String "." ;
  ]

let metadata page : json =
  `Assoc [
    "document", `String "Frama-C Server" ;
    "chapter", `String (title_of_chapter page.chapter) ;
    "title", `String page.title ;
    "root", `String page.rootdir ;
    "link",`List (link_page page) ;
  ]

(* -------------------------------------------------------------------------- *)
(* --- Dump Documentation                                                 --- *)
(* -------------------------------------------------------------------------- *)

let pp_one_page ~root ~page ~title body =
  let full_path = Filepath.normalize (root ^ "/" ^ page) in
  let dir = Filename.dirname full_path in
  if not (Sys.file_exists dir) then Extlib.mkdir ~parents:true dir 0o755;
  try
    let chan = open_out full_path in
    let fmt = Format.formatter_of_out_channel chan in
    let title = plain title in
    Markdown.(pp_pandoc ~page fmt (pandoc ~title body))
  with Sys_error e ->
    Senv.fatal "Could not open file %s for writing: %s" full_path e

(* Build section contents in reverse order *)
let build d s = List.fold_left (fun d s -> s() :: d) d s

let dump ~root ?(meta=true) () =
  begin
    Pages.iter
      (fun path page ->
         Senv.feedback "[doc] Page: '%s'" path ;
         let body = Markdown.subsections page.intro (build [] page.sections) in
         let title = page.title in
         pp_one_page ~root ~page:path ~title body ;
         if meta then
           let path = Printf.sprintf "%s/%s.json" root path in
           Yojson.Basic.to_file path (metadata page) ;
      ) !pages ;
    Senv.feedback "[doc] Page: 'readme.md'" ;
    if meta then
      let path = Printf.sprintf "%s/readme.md.json" root in
      Yojson.Basic.to_file path maindata ;
      let body =
        [ H1 (plain "Documentation", None);
          Block (text (format "Version %s" Fc_config.version))]
        @
        table_of_contents ()
        @
        [H2 (plain "Index", None)]
        @
        index ()
      in
      let title = "Documentation" in
      pp_one_page ~root ~page:"readme.md" ~title body
  end

let () =
  Db.Main.extend begin
    fun () ->
      let root = Senv.Doc.get () in
      if root <> "" then
        if Sys.file_exists root && Sys.is_directory root then
          begin
            Senv.feedback "[doc] Root: '%s'" root ;
            dump ~root () ;
          end
        else
          Senv.error "[doc] File '%s' is not a directory" root
  end

(* -------------------------------------------------------------------------- *)
