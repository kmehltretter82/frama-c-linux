(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2025                                               *)
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

open Filepath

(* -------------------------------------------------------------------------- *)
(* --- File system                                                        --- *)
(* -------------------------------------------------------------------------- *)

let exists (s : t) =
  Sys.file_exists (s :> string)

let is_file (fp : t) =
  try
    (Unix.stat (fp :> string)).Unix.st_kind = Unix.S_REG
  with _ -> false

let is_dir (s : t) = Sys.is_directory (s :> string)

let readdir (s : t) = Sys.readdir (s :> string)

let remove (s : t) = Sys.remove (s :> string)

let safe_remove_file f = try Unix.unlink f with Unix.Unix_error _ -> ()

let rec safe_remove_dir d =
  try
    Array.iter
      (fun a ->
         let f = Printf.sprintf "%s/%s" d a in
         if Sys.is_directory f then safe_remove_dir f else safe_remove_file f
      ) (Sys.readdir d) ;
    Unix.rmdir d
  with Unix.Unix_error _ | Sys_error _ -> ()

let rename (s : t) (t : t) = Sys.rename (s :> string) (t :> string)

let rec make_dir ?(parents=false) (name: t) perm =
  if exists name then
    if not (is_dir name) then
      failwith (Format.asprintf "mkdir: %a exists but is not a directory"
                  Filepath.pretty name)
    else false
  else begin
    begin
      try Unix.mkdir (name:>string) perm
      with
      | Unix.Unix_error (Unix.ENOENT,_,_) when parents ->
        let parent_name = Filepath.dirname name in
        if name <> parent_name then
          begin
            ignore (make_dir ~parents parent_name perm);
            Unix.mkdir (name:>string) perm
          end
      | e -> raise e
    end;
    true
  end


(* -------------------------------------------------------------------------- *)
(* --- Temporary files                                                    --- *)
(* -------------------------------------------------------------------------- *)

let cleanup_at_exit f = Extlib.safe_at_exit (fun () -> safe_remove_file f)

exception Temp_file_error of string

let temp_file_cleanup_at_exit ?(debug=false) s1 s2 =
  let file, out =
    try Filename.open_temp_file s1 s2
    with Sys_error s -> raise (Temp_file_error s)
  in
  (try close_out out with Unix.Unix_error _ -> ());
  Extlib.safe_at_exit
    begin fun () ->
      if debug then
        begin
          if Sys.file_exists file then
            Format.printf
              "Debug: not removing dir %s@." file;
        end
      else
        safe_remove_file file
    end ;
  file

let temp_dir_cleanup_at_exit ?(debug=false) base =
  let rec try_dir_cleanup_at_exit limit base =
    let file = Filename.temp_file base ".tmp" in
    let dir = Filename.chop_extension file ^ ".dir" in
    safe_remove_file file;
    try
      Unix.mkdir dir 0o700 ;
      Extlib.safe_at_exit
        begin fun () ->
          if debug then
            begin
              if Sys.file_exists dir then
                Format.printf
                  "Debug: not removing dir %s@." dir;
            end
          else
            safe_remove_dir dir
        end ;
      Filepath.of_string dir
    with Unix.Unix_error(err,_,_) ->
      if limit < 0 then
        raise (Temp_file_error (Unix.error_message err))
      else
        try_dir_cleanup_at_exit (pred limit) base
  in
  try_dir_cleanup_at_exit 10 base


(* -------------------------------------------------------------------------- *)
(* --- Low level Input/Output                                            --- *)
(* -------------------------------------------------------------------------- *)

type action_if_missing = Create of int | DoNotCreate
type action_if_exists = Error | Append | Truncate

type ('ch,'a) safe_processor = ('ch -> 'a) -> ('a,string) result
type ('ch,'a) exn_processor = ('ch -> 'a) -> 'a

let flags_and_perm ?if_exists ~if_missing ~binary ~blocking default =
  let l =
    default ::
    (if binary then [Open_binary] else [Open_text]) @
    (if blocking then [] else [Open_nonblock]) @
    match if_exists with
    | Some Error -> [Open_excl]
    | Some Append ->  [Open_append]
    | Some Truncate -> [Open_trunc]
    | None -> []
  in
  match if_missing with
  | DoNotCreate -> l, 0 (* perm is ignored when Open_creat is not set *)
  | Create mode -> Open_creat :: l, mode

(* We don't directly use Fun.protect as it catches exceptions in [finally]
   and reraise them as [Finally_raised exn]. However, a [Sys_error] can be
   raised by {!close_out} (and {!close_in} but it should not happen).
*)
let protect_file_op ~(close: 'ch -> unit) (job: 'ch -> 'a) (channel: 'ch) =
  let r =
    try job channel with
    | exn ->
      try
        close channel;
        raise exn
      with
      | Sys_error _ ->
        raise exn (* re-raise the first exception, do not erase it *)
  in
  close channel;
  r

let check_nonempty p =
  if is_empty p then
    invalid_arg "path should not be empty"

let with_open_in_exn
    ?(if_missing=DoNotCreate)
    ?(binary=false)
    ?(blocking=true)
    (p: t)
    (job: in_channel -> 'a): 'a =
  check_nonempty p;
  let flags, perm =
    flags_and_perm ~if_missing ~binary ~blocking Open_rdonly
  in
  open_in_gen flags perm (p :> string) |> protect_file_op ~close:close_in job

let with_open_in ?if_missing ?binary ?blocking p job =
  try Ok (with_open_in_exn ?if_missing ?binary ?blocking p job)
  with Sys_error s -> Error s

let with_open_out_exn
    ?(if_missing=Create 0o666)
    ?(if_exists=Truncate)
    ?(binary=false)
    ?(blocking=true)
    (p: t)
    (job: out_channel -> 'a): 'a =
  check_nonempty p;
  let flags, perm =
    flags_and_perm ~if_exists ~if_missing ~binary ~blocking Open_wronly
  in
  open_out_gen flags perm (p :> string) |> protect_file_op ~close:close_out job

let with_open_out ?if_missing ?if_exists ?binary ?blocking p job =
  try Ok (with_open_out_exn ?if_missing ?if_exists ?binary ?blocking p job)
  with Sys_error s -> Error s

module Operators =
struct
  let (let+) with_open job = with_open job
  let (let*) with_open job = with_open job |> Result.join
  let (let$) with_open job = with_open job
end


(* -------------------------------------------------------------------------- *)
(* --- High level Input/Output                                            --- *)
(* -------------------------------------------------------------------------- *)

open Operators

let with_formatter_exn p job =
  let$ out_channel = with_open_out_exn p in
  let fmt = Format.formatter_of_out_channel out_channel in
  let finally = Format.pp_print_flush fmt in
  Fun.protect ~finally (fun () -> job fmt)

let with_formatter p job =
  try Ok (with_formatter_exn p job)
  with Sys_error s -> Error s

let rec bincopy buffer in_channel out_channel =
  let s = Bytes.length buffer in
  let n = input in_channel buffer 0 s in
  if n > 0 then
    ( output out_channel buffer 0 n ; bincopy buffer in_channel out_channel )
  else
    ( flush out_channel )

let copy_file src tgt =
  let$ in_channel = with_open_in_exn src in
  let$ out_channel = with_open_out_exn tgt in
  bincopy (Bytes.create 2048) in_channel out_channel

let iter_lines p job =
  let$ in_channel = with_open_in_exn p in
  try
    while true do
      job (input_line in_channel) ;
    done
  with End_of_file -> ()
