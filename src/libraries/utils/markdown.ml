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

type align = Left | Center | Right

type href =
  | URL of string
  | Page of string
  | Section of string * string

type inline =
  | Plain of string
  | Emph of string
  | Bold of string
  | Inline_code of string
  | Link of text * href (** [Link(text,url)] *)
  | Image of string * string (** [Image(alt,location)] *)

and text = inline list

type block_element =
  | Text of text (** single paragraph of text. *)
  | Block_quote of element list
  | UL of block list
  | OL of block list
  | DL of (text * text) list (** definition list *)
  | EL of (string option * text) list (** example list *)
  | Code_block of string * string list

and block = block_element list

and element =
  | Block of block
  | Raw of string list
  (** non-markdown. Each element of the list is printed as-is on its own line.
      A blank line separates the [Raw] node from the next one. *)
  | Comment of string (** markdown comment, printed <!-- like this --> *)
  | H1 of text * string option (** optional label. *)
  | H2 of text * string option
  | H3 of text * string option
  | H4 of text * string option
  | H5 of text * string option
  | H6 of text * string option
  | Table of { caption: text option; header: (text * align) list;
               content: text list list; }

type elements = element list

type pandoc_markdown =
  { title: text;
    authors: text list;
    date: text;
    elements: elements
  }

let plain s = [ Plain s]

let plain_format txt = Format.kasprintf plain txt

let link_current_page sec = Section("", sec)

let plain_link h =
  let s = match h with
    | URL url -> url
    | Page p -> p
    | Section (_,s) -> s
  in
  Link ([Inline_code s], h)

let codelines lang pp code =
  let s = Format.asprintf "@[%a@]" pp code in
  let lines = String.split_on_char '\n' s in
  Code_block (lang, lines)

let raw_markdown filename =
  let chan = open_in filename in
  let res = ref [] in
  try
    while true do
      res := input_line chan :: !res;
    done;
    assert false
  with End_of_file ->
    close_in chan;
    Raw (List.rev !res)

let glue ?(sep=[]) texts =
  let rec aux = function
    | [] -> []
    | [t] -> t
    | hd::tl -> hd @ sep @ aux tl
  in
  aux texts

let id m =
  let buffer = Buffer.create (String.length m) in
  let lowercase = Char.lowercase_ascii in
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

let section ?name ~title elements =
  let anchor =
    match name with
    | None -> id title
    | Some n -> n
  in
  (H1 (plain title, Some anchor)) :: elements

let subsections header body =
  let body =
    List.map
      (function
        | H1(t,h) -> H2(t,h)
        | H2(t,h) -> H3(t,h)
        | H3(t,h) -> H4(t,h)
        | H4(t,h) -> H5(t,h)
        | e -> e)
      (List.concat body)
  in
  header @ body

let mk_date () =
  let tm = Unix.gmtime (Unix.time()) in
  plain
    (Printf.sprintf "%d-%02d-%02d"
       (1900 + tm.Unix.tm_year) (1 + tm.Unix.tm_mon) tm.Unix.tm_mday)

let pandoc ?(title=plain "") ?(authors=[]) ?(date=mk_date()) elements =
  { title; authors; date; elements }

let relativize page target =
  let page_dir = String.split_on_char '/' page in
  let target_dir = String.split_on_char '/' target in
  let go_up l = List.map (fun _ -> "..") l in
  let rec remove_common l1 l2 =
    match l1 with
    | [] -> assert false (* split on char is always non-empty *)
    | [_f1] -> l2
    | d1 :: p1 ->
      match l2 with
      | [] -> assert false
      | [_f2 ] ->
        (* it's the length of the argument to go_up that matters, not
           its exact content *)
        go_up p1 @ l2
      | d2 :: p2 when d2 = d1 -> remove_common p1 p2
      | _ -> go_up p1 @ l2
  in
  let relative = remove_common page_dir target_dir in
  String.concat "/" relative

let pp_href ?(page="") fmt = function
  | URL s -> Format.pp_print_string fmt s
  | Page s -> Format.pp_print_string fmt (relativize page s)
  | Section (p,s) -> Format.fprintf fmt "%s#%s" (relativize page p) (id s)

let rec pp_inline ?page fmt =
  function
  | Plain s -> Format.pp_print_string fmt s
  | Emph s -> Format.fprintf fmt "_%s_" (String.trim s)
  | Bold s -> Format.fprintf fmt "**%s**" (String.trim s)
  | Inline_code s -> Format.fprintf fmt "`%s`" (String.trim s)
  | Link (text,url) ->
    Format.fprintf fmt "@[<h>[%a](%a)@]@ "
      (pp_text ?page) text (pp_href ?page) url
  | Image (alt,url) -> Format.fprintf fmt "@[<h>![%s](%s)@]@ " alt url

and pp_text ?page fmt l =
  match l with
  | [] -> ()
  | [ elt ] -> pp_inline ?page fmt elt
  | elt :: text ->
    Format.fprintf fmt "%a@ %a" (pp_inline ?page) elt (pp_text ?page) text

let pp_lab fmt = function
  | None -> ()
  | Some lab -> Format.fprintf fmt " {#%s}" lab

let test_size txt =
  (* get rid of ?page *)
  let pp_text fmt = pp_text fmt in
  String.length (Format.asprintf "%a" pp_text txt)

let pp_dashes fmt size =
  let dashes = String.make (size + 2) '-' in
  Format.fprintf fmt "%s+" dashes

let pp_sep_line fmt sizes =
  Format.fprintf fmt "@[<h>+";
  List.iter (pp_dashes fmt) sizes;
  Format.fprintf fmt "@]@\n"

let pp_header ?page fmt (t,_) size =
  let real_size = test_size t in
  let spaces = String.make (size - real_size) ' ' in
  Format.fprintf fmt " %a%s |" (pp_text ?page) t spaces

let pp_headers ?page fmt l sizes =
  Format.fprintf fmt "@[<h>|";
  List.iter2 (pp_header ?page fmt) l sizes;
  Format.fprintf fmt "@]@\n"

let compute_sizes headers contents =
  let check_line i m line =
    try max m (test_size (List.nth line i) + 2)
    with Failure _ -> m
  in
  let column_size (i,l) (h,_) =
    let max = List.fold_left (check_line i) (test_size h) contents in
    (i+1, max :: l)
  in
  let (_,sizes) = List.fold_left column_size (0,[]) headers in
  List.rev sizes

let pp_align fmt align size =
  let sep = String.make size '=' in
  match align with
  | (_,Left) -> Format.fprintf fmt ":%s=+" sep
  | (_,Center) -> Format.fprintf fmt ":%s:+" sep
  | (_,Right) -> Format.fprintf fmt "%s=:+" sep

let pp_aligns fmt headers sizes =
  Format.fprintf fmt "@[<h>+";
  List.iter2 (pp_align fmt) headers sizes;
  Format.fprintf fmt "@]@\n"

let pp_table_cell ?page fmt size t =
  let real_size = test_size t in
  let spaces = String.make (size - real_size) ' ' in
  Format.fprintf fmt " %a%s |" (pp_text ?page) t spaces

let pp_table_line ?page fmt sizes l =
  Format.fprintf fmt "@[<h>|";
  List.iter2 (pp_table_cell ?page fmt) sizes l;
  Format.fprintf fmt "@]@\n";
  pp_sep_line fmt sizes

let pp_table_content ?page fmt l sizes =
  Format.fprintf fmt "@[<v>";
  List.iter (pp_table_line ?page fmt sizes) l;
  Format.fprintf fmt "@]"

let rec pp_block_element ?page fmt e =
  let pp_text fmt = pp_text ?page fmt in
  match e with
  | Text t -> Format.fprintf fmt "@[<hov>%a@]@\n" pp_text t
  | Block_quote l -> pp_quote ?page fmt l
  | UL l -> pp_list "*" ?page fmt l
  | OL l -> pp_list "#." ?page fmt l
  | DL l ->
    List.iter
      (fun (term,def) ->
         Format.fprintf fmt "@[<h>%a@]@\n@\n@[<hov 2>: %a@]@\n@\n"
           pp_text term pp_text def)
      l
  | EL l ->
    List.iter
      (fun (lab,txt) ->
         match lab with
         | None -> Format.fprintf fmt "@[<hov 4>(@@) %a@]@\n" pp_text txt
         | Some s -> Format.fprintf fmt "@[<hov 4>(@@%s) %a@]@\n" s pp_text txt)
      l
  | Code_block (language, lines) ->
    Format.fprintf fmt "@[<h>```%s@]@\n" language;
    List.iter (fun line -> Format.fprintf fmt "@[<h>%s@]@\n" line) lines;
    Format.fprintf fmt "```@\n"

and pp_list ?page prefix fmt l =
  List.iter
    (fun item ->
       Format.fprintf fmt "@[<v 4>@[<hov>%s %a@]@]"
         prefix (pp_block ?page) item)
    l

and pp_block ?page fmt l =
  match l with
  | [ elt ] -> pp_block_element ?page fmt elt
  | _ ->
    Format.fprintf fmt "%a@\n"
      (Format.pp_print_list
         ~pp_sep:Format.pp_force_newline (pp_block_element ?page)) l

and pp_quote ?page fmt l =
  List.iter
    (fun elt -> Format.fprintf fmt "@[<v>> %a@]" (pp_element ?page) elt) l

and pp_element ?page fmt e =
  let pp_text fmt = pp_text ?page fmt in
  match e with
  | Block b -> Format.fprintf fmt "@[<v>%a@]" (pp_block ?page) b
  | Raw l ->
    Format.(
      fprintf fmt "%a"
        (pp_print_list ~pp_sep:pp_force_newline pp_print_string) l)
  | Comment s ->
    Format.fprintf fmt
      "@[<hv>@[<hov 5><!-- %a@]@ -->@]" Format.pp_print_text s
  | H1(t,lab) -> Format.fprintf fmt "@[<h># %a%a@]" pp_text t pp_lab lab
  | H2(t,lab) -> Format.fprintf fmt "@[<h>## %a%a@]" pp_text t pp_lab lab
  | H3(t,lab) -> Format.fprintf fmt "@[<h>### %a%a@]" pp_text t pp_lab lab
  | H4(t,lab) -> Format.fprintf fmt "@[<h>#### %a%a@]" pp_text t pp_lab lab
  | H5(t,lab) -> Format.fprintf fmt "@[<h>##### %a%a@]" pp_text t pp_lab lab
  | H6(t,lab) -> Format.fprintf fmt "@[<h>###### %a%a@]" pp_text t pp_lab lab
  | Table { caption; header; content } ->
    (match caption with
     | None -> ()
     | Some t -> Format.fprintf fmt "@[<h>Table: %a@]@\n@\n" pp_text t);
    let sizes = compute_sizes header content in
    pp_sep_line fmt sizes;
    pp_headers ?page fmt header sizes;
    pp_aligns fmt header sizes;
    pp_table_content ?page fmt content sizes

let pp_elements ?page fmt l =
  let pp_sep fmt () =
    Format.pp_print_newline fmt ();
    Format.pp_print_newline fmt ()
  in
  Format.pp_print_list ~pp_sep (pp_element ?page) fmt l

let pp_authors ?page fmt l =
  List.iter (fun t -> Format.fprintf fmt "@[<h>- %a@]@\n" (pp_text ?page) t) l

let pp_pandoc ?page fmt { title; authors; date; elements } =
  Format.fprintf fmt "@[<v>";
  if title <> [] || authors <> [] || date <> [] then begin
    Format.fprintf fmt "@[<h>---@]@\n";
    Format.fprintf fmt "@[<h>title: %a@]@\n" (pp_text ?page) title;
    Format.fprintf fmt "@[<h>author:@]@\n%a" (pp_authors ?page) authors;
    Format.fprintf fmt "@[<h>date: %a@]@\n" (pp_text ?page) date;
    Format.fprintf fmt "@[<h>...@]@\n";
    Format.pp_print_newline fmt ();
  end;
  pp_elements ?page fmt elements;
  Format.fprintf fmt "@]%!"
