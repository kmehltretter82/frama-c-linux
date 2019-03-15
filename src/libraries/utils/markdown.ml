(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2019                                               *)
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
(* --- Markdown Documentation Generation Utility                          --- *)
(* -------------------------------------------------------------------------- *)

type md = Format.formatter -> unit
type text = md
type block = md
type section = md

let pretty fmt w = w fmt
let pp_text = pretty
let pp_block = pretty
let pp_section = pretty

(* -------------------------------------------------------------------------- *)
(* --- Context                                                            --- *)
(* -------------------------------------------------------------------------- *)

type toc = level:int -> name:string -> title:string -> unit

type context = {
  page: string ;
  path: string list ;
  names: bool ;
  level: int ;
  toc: toc option ;
}

let context = ref {
    page = "" ;
    path = [] ;
    names = false ;
    level = 0 ;
    toc = None ;
  }

let local ctxt job data =
  let current = !context in
  try context := ctxt ; job data ; context := current
  with err -> context := current ; raise err

(* -------------------------------------------------------------------------- *)
(* --- Combinators                                                        --- *)
(* -------------------------------------------------------------------------- *)

let nil _fmt = ()
let empty= nil
let space fmt = Format.pp_print_space fmt ()
let newline fmt = Format.pp_print_newline fmt ()

let merge sep ds fmt =
  match List.filter (fun d -> d != nil) ds with
  | [] -> ()
  | d::ds -> d fmt ; List.iter (fun d -> sep fmt ; d fmt) ds

let glue ?sep ds fmt =
  match sep with
  | None -> List.iter (fun d -> d fmt) ds
  | Some s -> merge s ds fmt

let (<@>) a b =
  if a == empty then b else
  if b == empty then a else
    fun fmt -> a fmt ; b fmt

let (<+>) a b =
  if a == empty then b else
  if b == empty then a else
    fun fmt -> a fmt ; space fmt ; b fmt

let (</>) a b =
  if a == empty then b else
  if b == empty then a else
    fun fmt -> a fmt ; newline fmt ; b fmt

let fmt_text k fmt = Format.fprintf fmt "@[<h 0>%t@]" k
let fmt_block k fmt = Format.fprintf fmt "@[<v 0>%t@]@\n" k

(* -------------------------------------------------------------------------- *)
(* --- Elementary Text                                                    --- *)
(* -------------------------------------------------------------------------- *)

let raw s fmt = Format.pp_print_string fmt s
let rm s fmt = Format.pp_print_string fmt s
let it s fmt = Format.fprintf fmt "_%s_" s
let bf s fmt = Format.fprintf fmt "**%s**" s
let tt s fmt = Format.fprintf fmt "`%s`" s
let text = merge space
let praw s = fmt_block (raw s)

(* -------------------------------------------------------------------------- *)
(* --- Links                                                              --- *)
(* -------------------------------------------------------------------------- *)

type href = [
  | `URL of string
  | `Page of string
  | `Name of string
  | `Section of string * string
]

let filepath m = Transitioning.String.split_on_char '/' m

let rec relative source target =
  match source , target with
  | p::ps , q::qs when p = q -> relative ps qs
  | [] , _ -> target
  | _::d , _ -> List.map (fun _ -> "..") d @ target

let lnk target =
  String.concat "/" (relative !context.path (filepath target))

let id m =
  let buffer = Buffer.create (String.length m) in
  let lowercase = Transitioning.Char.lowercase_ascii in
  let dash = ref false in
  let emit c =
    if !dash then (Buffer.add_char buffer '-' ; dash := false) ;
    Buffer.add_char buffer c in
  String.iter
    (function
      | '0'..'9' as c -> emit c
      | 'a'..'z' as c -> emit c
      | 'A'..'Z' as c -> emit (lowercase c)
      | '.' | '_' as c -> emit c
      | ' ' | '\t' | '\n' | '-' -> dash := (Buffer.length buffer > 0)
      | _ -> ()) m ;
  Buffer.contents buffer

let href ?title (h : href) fmt =
  match title , h with
  | None , `URL url -> Format.fprintf fmt "%s" url
  | Some w , `URL url -> Format.fprintf fmt "[%s](%s)" w url
  | None , `Page p -> Format.fprintf fmt "[%s](%s)" p (lnk p)
  | Some w , `Page p -> Format.fprintf fmt "[%s](%s)" w (lnk p)
  | None , `Section(p,s) -> Format.fprintf fmt "[%s](%s#%s)" s (lnk p) (id s)
  | Some w , `Section(p,s) -> Format.fprintf fmt "[%s](%s#%s)" w (lnk p) (id s)
  | None , `Name a -> Format.fprintf fmt "[%s](#%s)" a (id a)
  | Some w , `Name a -> Format.fprintf fmt "[%s](#%s)" w (id a)

(* -------------------------------------------------------------------------- *)
(* --- Blocks                                                             --- *)
(* -------------------------------------------------------------------------- *)

let aname anchor fmt =
  Format.fprintf fmt "<a name=\"%s\"></a>@\n" (id anchor)

let title h ?name title fmt =
  begin
    let { level ; names ; toc } = !context in
    let level = max 0 (min 5 (level + h - 1)) in
    Format.fprintf fmt "%s %s" (String.make level '#') title ;
    if names || name <> None || toc <> None then
      begin
        let anchor = match name with None -> title | Some a -> a in
        Format.fprintf fmt " {#%s}" (id anchor) ;
        (match toc with
         | None -> ()
         | Some callback ->
           callback ~level ~name:anchor ~title) ;
      end ;
    Format.pp_print_newline fmt () ;
  end

let h1 = title 1
let h2 = title 2
let h3 = title 3
let h4 = title 4

let indent h w fmt = local { !context with level = !context.level + h } w fmt

let in_h1 = indent 1
let in_h2 = indent 2
let in_h3 = indent 3
let in_h4 = indent 4

let hrule fmt = Format.pp_print_string fmt "-------------------------@."

let par w fmt = Format.fprintf fmt "@[<hov 0>%t@]@." w

let list ws fmt =
  List.iter
    (fun w -> Format.fprintf fmt "@[<hov 2>- %t@]@." w) ws

let enum ws fmt =
  let k = ref 0 in
  List.iter
    (fun w -> incr k ; Format.fprintf fmt "@[<hov 3>%d. %t@]@." !k w) ws

let description items fmt =
  List.iter
    (fun (a,w) -> Format.fprintf fmt "@[<hov 2>- **%s** %t@]@." a w) items

let code ?(lang="") pp fmt =
  begin
    Format.fprintf fmt "@[<v 0>```%s" lang ;
    let buffer = Buffer.create 80 in
    let bfmt = Format.formatter_of_buffer buffer in
    pp bfmt ; Format.pp_print_flush bfmt () ;
    let content = Buffer.contents buffer in
    let lines = Transitioning.String.split_on_char '\n' content in
    let rec clean = function [] -> [] | ""::w -> clean w | w -> w in
    List.iter
      (fun l -> Format.fprintf fmt "@\n%s" l)
      (List.rev (clean (List.rev (clean lines)))) ;
    Format.fprintf fmt "@\n```@]@."
  end

type column = [
  | `Left of string
  | `Right of string
  | `Center of string
]

let table columns rows fmt =
  begin
    Format.fprintf fmt "@[<v 0>" ;
    List.iter
      (function `Left h | `Right h | `Center h -> Format.fprintf fmt "| %s " h)
      columns ;
    Format.fprintf fmt "|@\n" ;
    List.iter (fun column ->
        let dash h k = String.make (max 3 (String.length h + k)) '-' in
        match column with
        | `Left h -> Format.fprintf fmt "|:%s" (dash h 1)
        | `Right h -> Format.fprintf fmt "|%s:" (dash h 1)
        | `Center h -> Format.fprintf fmt "|:%s:" (dash h 0)
      ) columns ;
    Format.fprintf fmt "|@\n" ;
    List.iter (fun row ->
        List.iter (fun col -> Format.fprintf fmt "| @[<h 0>%t@] " col) row ;
        Format.fprintf fmt "|@\n" ;
      ) rows ;
    Format.fprintf fmt "@]@." ;
  end

let concat ps = merge newline (List.filter (fun p -> p != empty) ps)

(* -------------------------------------------------------------------------- *)
(* --- Refs                                                               --- *)
(* -------------------------------------------------------------------------- *)

let mk f fmt = (f ()) fmt
let mk_text = mk
let mk_block = mk

(* -------------------------------------------------------------------------- *)
(* --- Sections                                                           --- *)
(* -------------------------------------------------------------------------- *)

let document s = s

let subsections section subsections = section </> in_h1 (merge newline subsections)

let section ?name ~title content subsections =
  h1 ?name title </> content </> in_h1 (merge newline subsections)

(* -------------------------------------------------------------------------- *)
(* --- Include File                                                       --- *)
(* -------------------------------------------------------------------------- *)

let from_file path fmt =
  let inc = open_in path in
  try
    while true do
      let line = input_line inc in
      Format.pp_print_string fmt line ;
      Format.pp_print_newline fmt () ;
    done
  with
  | End_of_file -> close_in inc
  | exn -> close_in inc ; raise exn

let read_block = from_file
let read_section = from_file
let read_text path fmt = Format.fprintf fmt "@[<h 0>%t@]" (from_file path)

(* -------------------------------------------------------------------------- *)
(* --- Dump to File                                                       --- *)
(* -------------------------------------------------------------------------- *)

let rec mkdir root page =
  let dir = Filename.dirname page in
  if dir <> "." && dir <> ".." then
    let path = Printf.sprintf "%s/%s" root dir in
    if not (Sys.file_exists path) then
      begin
        mkdir root dir ;
        try Unix.mkdir path 0o755
        with Unix.Unix_error _ ->
          failwith (Printf.sprintf "Can not create direcoty '%s'" dir)
      end

let dump ~root ~page ?(names=false) ?toc doc =
  local
    { page ; path = filepath page ; level = 1 ; toc ; names = names }
    begin fun () ->
      mkdir root page ;
      let out = open_out (Printf.sprintf "%s/%s" root page) in
      let fmt = Format.formatter_of_out_channel out in
      try
        doc fmt ;
        Format.pp_print_newline fmt () ;
        close_out out ;
      with err ->
        Format.pp_print_newline fmt () ;
        close_out out ;
        raise err
    end ()

(* -------------------------------------------------------------------------- *)
