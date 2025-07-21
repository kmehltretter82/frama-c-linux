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

let pretty ?truncate ?(ellipsis="[...]") fmt message =
  (* Compute buffer length *)
  let length = String.length message.plain in
  (* Truncate the buffer if requested *)
  let truncate_start, truncate_end =
    match truncate with
    | Some size when size < length ->
      let ellipsis_length = String.length ellipsis in
      if ellipsis_length >= size
      then (0, length)
      else
        let size_left = (size - ellipsis_length) / 2 in
        let size_right = ((size - ellipsis_length) - size_left) in
        (size_left, length - size_right)
    | _ ->
      max_int, max_int (* Do not truncate until max_int, hopefully never *)
  in
  (* Output of a substring of the buffer from p (included) to q (excluded) *)
  (* Do replace by Format.pp_print_substring_as as soon as OCaml 5.1 is
     the minimal version supported by Frama-C *)
  let output_sub p q =
    if p < q then
      let s = String.sub message.plain p (q - p) in
      Format.pp_print_string fmt s
  in
  (* Output of a substring of the buffer, but with truncated contents if
     required. *)
  let output_truncated ~force_ellipsis p q =
    (* Is there no untersection between [p..q[ and
       [truncate_start..truncate_end[ ? *)
    if p >= truncate_end || q <= truncate_start then
      output_sub p q
    else begin
      output_sub p truncate_start;
      if force_ellipsis || p <= truncate_start && q >= truncate_end then
        Format.pp_print_string fmt ellipsis;
      output_sub truncate_end q;
    end
  in
  (* Iteration over the semantic tags of the buffer *)
  (* [with_ellipsis] tells whether to output ellpsis when truncating *)
  let rec aux ~force_ellipsis p q =
    function
    | [] -> output_truncated ~force_ellipsis p q
    | { tag ; p=tp ; q=tq ; children } :: tags ->
      if tp >= truncate_start && tq <= truncate_end then
        aux ~force_ellipsis p q tags
      else if q < tp then
        output_truncated ~force_ellipsis p q
      else if tq < p then
        aux ~force_ellipsis p q tags
      else begin
        output_truncated ~force_ellipsis p tp;
        Format.pp_open_stag fmt tag;
        aux ~force_ellipsis:false tp tq children;
        Format.pp_close_stag fmt ();
        let force_ellipsis =
          force_ellipsis || p <= truncate_start && q >= truncate_end
        in
        aux ~force_ellipsis tq q tags;
      end
  in
  aux ~force_ellipsis:true 0 (String.length message.plain) message.tags


(* -------------------------------------------------------------------------- *)
(* --- Extended Buffer with Tags                                          --- *)
(* -------------------------------------------------------------------------- *)

let min_buffer = 128    (* initial size of buffer *)

type buffer = {
  mutable formatter : Format.formatter ; (* formatter on self (recursive) *)
  content : Buffer.t ;
  mutable revtags : tag list ; (* in reverse order *)
  mutable stack : (int * Format.stag * tag list) list ; (* opened tag positions *)
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

let reset buffer =
  Buffer.reset buffer.content;
  buffer.revtags <- [];
  buffer.stack <- []

let truncate buffer size =
  let truncated = ref false in
  if Buffer.length buffer.content > size then
    begin
      let p = trim_begin buffer in
      let q = trim_end buffer in
      let n = q+1-p in
      if n <= 0 then
        reset buffer
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

let push_tag buffer tag =
  let p = Buffer.length buffer.content in
  buffer.stack <- ( p , tag, buffer.revtags ) :: buffer.stack ;
  buffer.revtags <- []

let pop_tag buffer tag =
  match buffer.stack with
  | [] -> ()
  | (p,tag',tags)::stack ->
    assert (tag = tag');
    let q = Buffer.length buffer.content in
    buffer.stack <- stack ;
    let children = List.rev buffer.revtags in
    buffer.revtags <- { p ; q ; tag ; children } :: tags

let rec pop_all buffer =
  match buffer.stack with
  | [] -> ()
  | (_,tag,_) :: _ ->
    pop_tag buffer tag;
    pop_all buffer

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
  Format.pp_print_flush buffer.formatter ();
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
  let plain = contents ?trim buffer in (* flushes the formatter *)
  (* The following lines requires that the formatter have been flushed *)
  pop_all buffer;
  let tags = List.rev buffer.revtags |> offset_tags (trim_begin buffer) in
  { plain ; tags }

let sub buffer p n = Buffer.sub buffer.content p n
let range buffer p q = Buffer.sub buffer.content p (q+1-p)

let add_char buffer c = Format.pp_print_char buffer.formatter c
let add_string buffer s = Format.pp_print_string buffer.formatter s
let add_substring buffer s k n =
  Format.pp_print_string buffer.formatter (String.sub s k n)

let formatter buffer = buffer.formatter

let bprintf buffer format =
  Format.fprintf buffer.formatter format
let kbprintf kjob buffer format =
  Format.kfprintf kjob buffer.formatter format
let sprintf ?prefix ?suffix ?indent ?margin ?trim ?truncate ?ellipsis format =
  let buffer = create ?indent ?margin () in
  let to_string _fmt =
    let message = message ?trim buffer in
    let length = Option.value ~default:(size message) truncate in
    let string_buffer = Buffer.create length in
    let fmt = Format.formatter_of_buffer string_buffer in
    Option.iter (fun f -> f fmt) prefix;
    pretty ?truncate ?ellipsis fmt message;
    Option.iter (fun f -> f fmt) suffix;
    Format.pp_print_flush fmt ();
    Buffer.contents string_buffer
  in
  kbprintf to_string buffer format

let to_string ?(indent=20) ?(margin=40) ?(trim=true) pp data =
  sprintf ~indent ~margin ~trim "%a" pp data

(* -------------------------------------------------------------------------- *)
(* --- Tests                                                              --- *)
(* -------------------------------------------------------------------------- *)

let test_pretty ?(truncate=12) format output =
  let prefix fmt = Format.pp_set_mark_tags fmt true in
  let result = sprintf ~prefix ~truncate format in
  let success = result = output in
  if not success then
    Format.eprintf "wrong output: '%s' given, '%s' expected@."
      result output;
  success

(* Test empty format *)
let%test _ = test_pretty "" ""

(* Basic test *)
let%test _ = test_pretty "01234" "01234"

(* Truncate size < ellipsis length *)
let%test _ = test_pretty ~truncate:2 "0123456789" "[...]"

(* truncation basic test *)
let%test _ = test_pretty "01234567890123456789" "012[...]6789"

(* Blank string *)
let%test _ = test_pretty " \t\r\n " ""

(* Basic trim *)
let%test _ = test_pretty "   01234  " "01234"

(* Basic trim and truncation *)
let%test _ = test_pretty "   01234567890123456789  " "012[...]6789"

(* Basic stag usage *)
let%test _ = test_pretty "0@{<a>12345678@}9" "0<a>12345678</a>9"

(* Missing closing stag *)
let%test _ = test_pretty "0@{<a>123456789" "0<a>123456789</a>"

(* Truncation with stags *)
let%test _ = test_pretty "0@{<a>123456789012345678@}9" "0<a>12[...]678</a>9"
let%test _ =
  test_pretty "0@{<a>123456@{<b>7890@}12345678@}9" "0<a>12[...]678</a>9"
let%test _ =
  test_pretty "012345@{<a>6@{<b>7890@}1@}23456789" "012[...]6789"
let%test _ =
  test_pretty "0@{<a>123456@}78901@{<b>2345678@}9" "0<a>12</a>[...]<b>678</b>9"
let%test _ =
  test_pretty ~truncate:17
    "0@{<a>1@{<b>2@{<c>3@{<d>4@}5@}6@}789012@{<e>3@{<f>4@{<g>5@}6@}7@}8@}9"
    "0<a>1<b>2<c>3<d>4</d>5</c></b>[...]<e><f>4<g>5</g>6</f>7</e>8</a>9"
let%test _ =
  test_pretty ~truncate:17
    "0@{<a>1@{<b>2@{<c>3@{<d>4@}5@}6@}789012@{<e>@{<f>@{<g>345@}6@}7@}8@}9"
    "0<a>1<b>2<c>3<d>4</d>5</c></b>[...]<e><f><g>45</g>6</f>7</e>8</a>9"
let%test _ =
  test_pretty ~truncate:17
    "0@{<a>1@{<b>2@{<c>3@{<d>456@}@}@}789012@{<e>3@{<f>4@{<g>5@}6@}7@}8@}9"
    "0<a>1<b>2<c>3<d>45</d></c></b>[...]<e><f>4<g>5</g>6</f>7</e>8</a>9"

(* Trim with stags *)
let%test _ = test_pretty "  0@{<a>12345678@}9   " "0<a>12345678</a>9"

(* Trim and truncate with stags *)
let%test _ = test_pretty "0@{<a>123456789012345678@}9" "0<a>12[...]678</a>9"
