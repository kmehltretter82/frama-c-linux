(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

(* -------------------------------------------------------------------------- *)
(* --- Rich Messages                                                      --- *)
(* -------------------------------------------------------------------------- *)

type tag = {
  p : int ; (* first position *)
  q : int ; (* last position (excluded) *)
  tag : Format.stag ;
  children : tag list ;
}

type message = {
  plain : string;
  tags : tag list;
}

let size message = String.length message.plain
let char_at message k = String.get message.plain k
let string message = message.plain
let substring message k n = String.sub message.plain k n

let rec lookup acc k = function
  | [] -> acc
  | { p ; q ; tag ; children } :: tags ->
    if k < p then lookup acc k tags else
    if q < k then acc else
      lookup ((tag,p,q+1-p)::acc) k children

let tags_at message k = lookup [] k message.tags

let pretty fmt message =
  let output p q =
    Format.pp_print_string fmt (String.sub message.plain p (q + 1 - p))
  in
  let rec aux fmt p q = function
    | [] -> output p q
    | { tag ; p=tp ; q=tq ; children } :: tags ->
      if q < tp then output p q else
      if tq < q then aux fmt p q tags else
        begin
          if tp>p then output p (tp-p) ;
          Format.pp_open_stag fmt tag ;
          aux fmt tp tq children ;
          Format.pp_close_stag fmt () ;
          aux fmt (succ tq) q tags ;
        end
  in
  aux fmt 0 (String.length message.plain) message.tags


(* -------------------------------------------------------------------------- *)
(* --- Extended Buffer with Tags                                          --- *)
(* -------------------------------------------------------------------------- *)

let min_buffer = 128    (* initial size of buffer *)

type buffer = {
  mutable formatter : Format.formatter ; (* formatter on self (recursive) *)
  content : Buffer.t ;
  mutable revtags : tag list ; (* in reverse order *)
  mutable stack : (int * tag list) list ; (* opened tag positions *)
}

let is_blank = function
  | ' ' | '\t' | '\r' | '\n' -> true
  | _ -> false

let trim_begin buffer =
  let rec lookup_fwd text k n =
    if k < n && is_blank (Buffer.nth text k) then
      lookup_fwd text (succ k) n else k
  in lookup_fwd buffer.content 0 (Buffer.length buffer.content)

let trim_end buffer =
  let rec lookup_bwd text k =
    if k >= 0 && is_blank (Buffer.nth text k) then
      lookup_bwd text (pred k) else k
  in lookup_bwd buffer.content (pred (Buffer.length buffer.content))

let shrink buffer =
  if Buffer.length buffer.content > min_buffer then
    Buffer.reset buffer.content

let truncate buffer size =
  let truncated = ref false in
  if Buffer.length buffer.content > size then
    begin
      let p = trim_begin buffer in
      let q = trim_end buffer in
      let n = q+1-p in
      if n <= 0 then
        shrink buffer
      else if n <= size then
        Buffer.blit buffer.content p (Buffer.to_bytes buffer.content) 0 n
      else
        let n_left = size / 2 - 3 in
        let n_right = size - n_left - 5 in
        if p > 0 then
          Buffer.blit buffer.content p (Buffer.to_bytes buffer.content) 0 n_left;
        let buf_right = Buffer.sub buffer.content (q-n_right+1) n_right in
        Buffer.truncate buffer.content n_left;
        Buffer.add_string buffer.content "[...]";
        Buffer.add_string buffer.content buf_right;
        truncated := true;
    end;
  !truncated

let push_tag buffer _tag =
  let p = Buffer.length buffer.content in
  buffer.stack <- ( p , buffer.revtags ) :: buffer.stack ;
  buffer.revtags <- []

let pop_tag buffer tag =
  match buffer.stack with
  | [] -> ()
  | (p,tags)::stack ->
    let q = Buffer.length buffer.content in
    buffer.stack <- stack ;
    let children = List.rev buffer.revtags in
    buffer.revtags <- { p ; q ; tag ; children } :: tags

(* -------------------------------------------------------------------------- *)
(* --- External API                                                       --- *)
(* -------------------------------------------------------------------------- *)

let create ?indent ?margin () =
  let buffer = {
    formatter = Format.err_formatter ;
    content = Buffer.create min_buffer ;
    revtags = [] ;
    stack = [] ;
  } in
  let fmt = Format.formatter_of_buffer buffer.content in
  buffer.formatter <- fmt ;
  begin match indent , margin with
    | None , None -> ()
    | Some k , None ->
      let m = Format.pp_get_margin fmt () in
      Format.pp_set_max_indent fmt (max 0 (min k m))
    | None , Some m ->
      Format.pp_set_margin fmt (max 0 m) ;
      let k = Format.pp_get_max_indent fmt () in
      if k < m-10 then Format.pp_set_max_indent fmt (max 0 (m-10))
    | Some k , Some m ->
      Format.pp_set_margin fmt (max 0 m) ;
      Format.pp_set_max_indent fmt (max 0 (min k (m-10)))
  end ;
  let open Format in
  Format.pp_set_formatter_stag_functions fmt {
    Format.print_open_stag = ignore ;
    print_close_stag = ignore ;
    mark_open_stag = (fun stag -> push_tag buffer stag; "") ;
    mark_close_stag = (fun stag -> pop_tag buffer stag; "") ;
  } ;
  pp_set_mark_tags fmt true ;
  buffer

let trim buffer =
  let p = trim_begin buffer in
  let q = trim_end buffer in
  p , q

let contents ?(trim=true) buffer =
  if trim then
    let p = trim_begin buffer in
    let q = trim_end buffer in
    if p <= q
    then Buffer.sub buffer.content p (q+1-p)
    else ""
  else
    Buffer.contents buffer.content

let rec offset_tag n tag =
  { p = tag.p - n;
    q = tag.q - n;
    tag = tag.tag;
    children = offset_tags n tag.children
  }
and offset_tags n tags =
  List.map (offset_tag n) tags

let message ?trim buffer =
  let plain = contents ?trim buffer in
  let tags = List.rev buffer.revtags |> offset_tags (trim_begin buffer) in
  { plain ; tags }

let sub buffer p n = Buffer.sub buffer.content p n
let range buffer p q = Buffer.sub buffer.content p (q+1-p)

let add_char buffer c = Format.pp_print_char buffer.formatter c
let add_string buffer s = Format.pp_print_string buffer.formatter s
let add_substring buffer s k n =
  Format.pp_print_string buffer.formatter (String.sub s k n)

let formatter buffer = buffer.formatter
let bprintf buffer text = Format.fprintf buffer.formatter text
let kprintf kjob buffer text = Format.kfprintf kjob buffer.formatter text

let to_string ?(indent=20) ?(margin=40) ?(trim=true) pp data =
  let buffer = create ~indent ~margin () in
  let fmt = formatter buffer in
  pp fmt data ;
  Format.pp_print_flush fmt () ;
  if trim then
    let p = trim_begin buffer in
    let q = trim_end buffer in
    Buffer.sub buffer.content p (q+1-p)
  else
    Buffer.contents buffer.content

(* -------------------------------------------------------------------------- *)
