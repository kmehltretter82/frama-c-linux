(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2024                                               *)
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

let repair_word s = Str.global_replace (Str.regexp_string "\\") "" s

let index_entry = Str.regexp {|^\\indexentry{\(.*\)}{[0-9]*}|}

let index_subentry = Str.regexp {|^.*@texttt *{\(fontsize  {8}{10}selectfont  \)?\([A-Za-z0-9_]+\)}$|}

let all_caps = Str.regexp "^[A-Z0-9_]+$"

let is_lower s = 'a' <= s.[0] && s.[0] <= 'z'
let is_upper s = 'A' <= s.[0] && s.[0] <= 'Z'

(* We have a prefix composed of module names, then maybe a lower case
   symbol, possibly followed by a single symbol (in the case of a
   type constructor or record field).
*)
let is_ocaml_symbol l =
  let rec aux = function
    | [] | [_] -> true
    | [ t; _ ] when is_lower t -> true
    | x :: l -> is_upper x && aux l
  in
  match l with
  | [] -> false
  | x :: l -> is_upper x && aux l

let inspect_subentry l =
  let check_one_entry e =
    let e = repair_word e in
    if Str.string_match index_subentry e 0 then begin
      let word = Str.matched_group 2 e in
      if Str.string_match all_caps word 0 then raise Exit else word
    end else raise Exit
  in
  try
    let l = List.map check_one_entry l in
    if is_ocaml_symbol l then
      (String.concat "." l)  ^ "\n"
    else ""
  with Exit -> ""

let inspect_entry line =
  if Str.string_match index_entry line 0 then begin
    let content = Str.matched_group 1 line in
    match Str.split (Str.regexp_string "|") content with
    | [ entry; _ ] -> inspect_subentry (Str.split (Str.regexp_string "!") entry)
    | _ -> ""
  end else ""

let external_names = [ "Landmarks"; "Makefile" ]

(** [fill_tbl] takes a file containing data which is
    as "element_name/type/comment/" or "element_name".
    It fills the hashtable [tbl]
    with all the element [type;comment] or [] recorded
    with the key "element_name". *)
let fill_tbl tbl file_name =
  try
    let c = open_in file_name in
    let add_if_needed name infos =
      if not (Hashtbl.mem tbl name || List.mem name external_names) then
        Hashtbl.add tbl name infos
    in
    try
      while true do
        let s = input_line c in
        match (Str.split (Str.regexp "/") s) with
        | []    -> ()
        | h::[] -> add_if_needed h []
        | h::q  -> add_if_needed h q
      done
    with End_of_file -> close_in c
  with Sys_error _ as exn ->
    Format.eprintf "cannot handle file %s: %s" file_name
      (Printexc.to_string exn)

(** [run_oracle] takes two hashtables [t1] and [t2] when called.
    It first tests if the file "run.oracle" is already existing.
    If this file exists, it uses the function [w_tbl] and creates
    [tbl] a hashtable that contains the information found in "run.oracle".
    It first looks for all the elements in common in [t1] and [t2] and then
    compares the corresponding pieces of information of [t1] and [tbl]
    If the pieces of information are different, it writes this difference.
    It eventually overwrites the "run.oracle" file with
    the pieces of information of the common elements of [t1] and [t2].
    If the file "run.oracle" does not exit, it only fills this file with
    the pieces of information in common using the function [wo_tbl]. *)
let run_oracle t1 t2 =
  let to_fill = ref ""
  in
  let fill_oracle s =
    try let chan_out = open_out "run.oracle"
      in
      output_string chan_out s;
      close_out chan_out
    with Sys_error _ as exn ->
      Format.eprintf "cannot handle file %s: %s" "run.oracle"
        (Printexc.to_string exn)
  in
  let rec string_of_list l = match l with
    | []    -> ""
    | h::[] -> h ^"/"
    | h::q  -> h ^"/"^ (string_of_list q)
  in
  let rec string_of_info_list l = match l with
    | [] -> ""
    | h::[] -> h
    | h::q  ->
      if not (h="")
      then h ^ "\n" ^ (string_of_info_list q)
      else (string_of_info_list q)
  in
  let wo_tbl t k _d =
    try let element_info = Hashtbl.find t k
      in
      to_fill :=
        !to_fill ^ "\n" ^ k ^ "/" ^ (string_of_list element_info)
    with Not_found -> ()
  in
  let w_tbl t k _d =
    let tbl: (string,string list) Hashtbl.t = Hashtbl.create 197
    in
    fill_tbl tbl "run.oracle";
    try
      let element_info = Hashtbl.find t k
      in
      to_fill :=
        !to_fill ^ "\n" ^ k ^ "/"^ string_of_list element_info;
      let previous_element_info = Hashtbl.find tbl k
      in
      if not (element_info = previous_element_info) then
        Format.printf " \n \n ----%s---- \n\n ** Information \
                       previously registered in 'run.oracle' :\n %s \n\n ** Information in \
                       the current API :\n %s \n "
          k (string_of_info_list previous_element_info)
          (string_of_info_list element_info)
    with Not_found ->
      (* element not previously registered *)
      ()
  in
  Format.printf "%s" " \n \n*****************************\
                      *************************************\
                      \nELEMENTS OF THE INDEX OF THE DEVELOPER GUIDE EXISTING \
                      IN THE CODE: \n*****************************************\
                      *************************\n\n";
  if (Sys.file_exists "run.oracle")
  then (Hashtbl.iter (w_tbl t2) t1;
        fill_oracle !to_fill)
  else (Hashtbl.iter (wo_tbl t2) t1 ;
        fill_oracle !to_fill)


(** [compare] takes two lists and returns the elements
    of the first list not in the second list and then the elements
    of the second list not in the first list.
    The two names are corresponding (same order) to the two tables
    and are used in the introduction sentences. *)
let compare t1 t2 name1 name2 =
  let compare_aux t k =
    if not(List.mem k t) then Format.printf "%s" (k ^ "\n") in
  Format.printf " \n \n*****************************************\
                 *******************\
                 \nELEMENTS OF %s NOT IN %s: \n***********************************\
                 *************************\
                 \n\n"
    name1 name2;
  List.iter (compare_aux t2) t1;
  Format.printf " \n \n*******************************************\
                 *****************\
                 \nELEMENTS OF %s NOT IN %s: \n************************************\
                 ************************\
                 \n\n"
    name2 name1;
  List.iter (compare_aux t1) t2

let sort_keys tbl =
  let l = Hashtbl.fold (fun k _ l -> k :: l) tbl [] in
  List.sort String.compare l

(** here are used the lexer and parser "check_index_lexer" and
    "check_index_grammar" to create the file "index_file".
    The files "main.idx" and "code_file" must already exist. *)
let () =
  let index_hstbl: (string,string list) Hashtbl.t = Hashtbl.create 197 in
  let code_hstbl: (string,string list) Hashtbl.t = Hashtbl.create 197 in
  try
    let chan_out = open_out ( "index_file") in
    try
      let chan_in = open_in ( "main.idx") in
      try
        while true do
          let line = input_line chan_in in
          let res = inspect_entry line in
          output_string chan_out res;
        done
      with End_of_file -> ();
        close_out chan_out ; close_in chan_in;
        fill_tbl code_hstbl "code_file";
        fill_tbl index_hstbl "index_file";
        let code_list = sort_keys code_hstbl in
        let index_list = sort_keys index_hstbl in
        compare index_list code_list "THE INDEX \
                                      OF THE DEVELOPER GUIDE" "THE CODE";
        run_oracle index_hstbl code_hstbl ;
    with Sys_error _ as exn ->
      Format.eprintf "cannot handle file %s: %s" "index_file"
        (Printexc.to_string exn)
  with Sys_error _ as exn ->
    Format.eprintf "cannot handle file %s: %s" "main.idx"
      (Printexc.to_string exn)
