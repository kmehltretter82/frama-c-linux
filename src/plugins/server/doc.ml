(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2018                                               *)
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

module Senv = Server_parameters
module Pages = Map.Make(String)

type chapter = [ `Protocol | `Kernel | `Plugin of string ]

type page = {
  path : string ;
  rootdir : string ; (* path to document root *)
  chapter : chapter ;
  title : string ;
  order : int ;
  intro : Markdown.section ;
  mutable sections : Markdown.section list ;
}

let order = ref 0
let pages : page Pages.t ref = ref Pages.empty
let plugins : string list ref = ref []
let entries : (string * Markdown.href) list ref = ref []
let path page = page.path
let href page name : Markdown.href = `Section( page.path , name )

(* -------------------------------------------------------------------------- *)
(* --- Page Collection                                                    --- *)
(* -------------------------------------------------------------------------- *)

let chapter pg = pg.chapter

let page chapter ~title ~filename =
  let rootdir,path = match chapter with
    | `Protocol -> "." , filename
    | `Kernel -> ".." , Printf.sprintf "kernel/%s" filename
    | `Plugin name -> "../.." , Printf.sprintf "plugins/%s/%s" name filename
  in
  try Pages.find path !pages
  with Not_found ->
    let intro = match chapter with
      | `Protocol ->
        Printf.sprintf "%s/server/protocol/%s" Config.datadir filename
      | `Kernel ->
        Printf.sprintf "%s/server/kernel/%s" Config.datadir filename
      | `Plugin name ->
        if not (List.mem name !plugins) then plugins := name :: !plugins ;
        Printf.sprintf "%s/%s/server/%s" Config.datadir name filename in
    let intro =
      if Sys.file_exists intro
      then Markdown.read_section intro
      else Markdown.(section ~title empty []) in
    let order = incr order ; !order in
    let page = { order ; rootdir ; path ;
                 chapter ; title ; intro ;
                 sections=[] } in
    pages := Pages.add path page !pages ; page

let publish page ?name ?(index=[]) ~title content sections =
  let id = match name with Some id -> id | None -> title in
  let href = `Section( page.path , id ) in
  let section = Markdown.section ?name ~title content sections in
  List.iter (fun entry -> entries := (entry , href) :: !entries) index ;
  page.sections <- section :: page.sections ; href

let _ = page `Protocol ~title:"Architecture" ~filename:"server.md"

(* -------------------------------------------------------------------------- *)
(* --- Tables of Content                                                  --- *)
(* -------------------------------------------------------------------------- *)

let title_of_chapter = function
  | `Protocol -> "Server Protocols"
  | `Kernel -> "Kernel Services"
  | `Plugin name -> "Plugin " ^ Transitioning.String.capitalize_ascii name

let pages_of_chapter c =
  let w = ref [] in
  Pages.iter
    (fun _ p -> if p.chapter = c then w := p :: !w) !pages ;
  List.sort (fun p q -> p.order - q.order) !w

let table_of_chapter c fmt =
  begin
    Format.fprintf fmt "## %s@\n@." (title_of_chapter c) ;
    List.iter
      (fun p -> Format.fprintf fmt "   - [%s](%s)@." p.title p.path)
      (pages_of_chapter c) ;
    Format.pp_print_newline fmt () ;
  end

let table_of_contents fmt =
  begin
    table_of_chapter `Protocol fmt ;
    table_of_chapter `Kernel fmt ;
    List.iter
      (fun p -> table_of_chapter (`Plugin p) fmt)
      (List.sort String.compare !plugins)
  end

let index () =
  List.map
    (fun (title,entry) -> Markdown.href ~title entry)
    (List.sort (fun (a,_) (b,_) -> String.compare a b) !entries)

type json = Yojson.Basic.json

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

let maindata : Yojson.Basic.json =
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

let dump ~root ?(meta=true) () =
  begin
    Pages.iter
      (fun path page ->
         Senv.feedback "[doc] Page: '%s'" path ;
         let body = Markdown.subsections page.intro (List.rev page.sections) in
         Markdown.dump ~root ~page:path (Markdown.document body) ;
         if meta then
           let path = Printf.sprintf "%s/%s.json" root path in
           Yojson.Basic.to_file path (metadata page) ;
      ) !pages ;
    Senv.feedback "[doc] Page: 'readme.md'" ;
    if meta then
      let path = Printf.sprintf "%s/readme.md.json" root in
      Yojson.Basic.to_file path maindata ;
      Markdown.(dump ~root ~page:"readme.md"
                  begin
                    h1 "Documentation" </>
                    par (bf "Version" <+> rm Config.version) </>
                    fmt_block table_of_contents </>
                    h2 "Index" </>
                    list (index ())
                  end) ;
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
