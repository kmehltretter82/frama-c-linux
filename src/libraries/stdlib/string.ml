(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

include Stdlib.String

let compare_ignore_case s1 s2 =
  compare (lowercase_ascii s1) (lowercase_ascii s2)

let strip_prefix ?(strict=false) prefix s =
  if starts_with ~prefix s then
    let n = length s in
    let p = length prefix in
    if not strict || n > p then Some (sub s p (n-p)) else None
  else None

let strip_suffix ?(strict=false) suffix s =
  if ends_with ~suffix s then
    let n = length s in
    let p = length suffix in
    if not strict || n > p then Some (sub s 0 (n-p)) else None
  else None

let strip_underscores s =
  let l = length s in
  let rec start i =
    if i >= l then l
    else if get s i = '_' then start (i + 1) else i
  in
  let st = start 0 in
  if st = l then ""
  else begin
    let rec finish i =
      (* We know that we will stop at >= st >= 0 *)
      if get s i = '_' then finish (i - 1) else i
    in
    let fin = finish (l - 1) in
    sub s st (fin - st + 1)
  end

let utf8_escaped s =
  let escape_char c =
    if c = '"' then "\\\"" else Char.escaped c
  in
  let buffer = Buffer.create (length s) in
  let rec aux i =
    if i < length s then
      let uchar = get_utf_8_uchar s i in
      let len = Uchar.utf_decode_length uchar in
      if len = 1
      then escape_char (get s i) |> Buffer.add_string buffer
      else Uchar.utf_decode_uchar uchar |> Buffer.add_utf_8_uchar buffer;
      aux (i + len)
  in
  aux 0;
  Buffer.contents buffer

let html_escape s =
  let buf = Buffer.create (length s) in
  iter
    (function
      | '<' -> Buffer.add_string buf "&lt;"
      | '>' -> Buffer.add_string buf "&gt;"
      | '&' -> Buffer.add_string buf "&amp;"
      | c -> Buffer.add_char buf c
    ) s ;
  Buffer.contents buf

let percent_encode s =
  let buf = Buffer.create (length s) in
  iter
    (function
      | 'a' .. 'z' | 'A' .. 'Z' | '0' .. '9'
      | '-' | '.' | '_' | '~' as c ->
        Buffer.add_char buf c
      | c ->
        let code = Char.code c in
        let percent_code = Format.asprintf "%%%2X" code in
        Buffer.add_string buf percent_code)
    s;
  Buffer.contents buf
