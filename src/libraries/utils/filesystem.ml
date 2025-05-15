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

let exists (p : t) =
  Sys.file_exists (p :> string)

let is_file (p : t) =
  try
    (Unix.stat (p :> string)).Unix.st_kind = Unix.S_REG
  with _ -> false

let is_dir (p : t) = Sys.is_directory (p :> string)

let readdir (p : t) =
  Sys.readdir (p :> string)

let list_dir (p : t) =
  Sys.readdir (p :> string)
  |> Array.to_list

let iter_dir (f : string -> unit) (p : t) : unit =
  Sys.readdir (p :> string)
  |> Array.iter (fun s -> f s)

let fold_dir (f : string -> 'a -> 'a) (p : t) (acc : 'a) : 'a =
  Sys.readdir (p :> string)
  |> Array.fold_left (fun acc s ->  f s acc) acc

let remove_file (p : t) =
  try
    Unix.unlink (p :> string)
  with Unix.Unix_error _ -> ()

let rec remove_dir (p : t) =
  try
    Array.iter
      (fun a ->
         let f = p / a in
         if is_dir f then remove_dir f else remove_file f
      ) (readdir p) ;
    Unix.rmdir (p :> string)
  with Unix.Unix_error _ | Sys_error _ -> ()

let rename (s : t) (t : t) = Sys.rename (s :> string) (t :> string)

let rec make_dir ?(parents=false) (p: t) perm =
  if exists p then
    if not (is_dir p) then
      failwith (Format.asprintf "mkdir: %a exists but is not a directory"
                  Filepath.pretty p)
    else false
  else begin
    begin
      try Unix.mkdir (p :> string) perm
      with
      | Unix.Unix_error (Unix.ENOENT,_,_) when parents ->
        let parent = Filepath.dirname p in
        if p <> parent then
          begin
            ignore (make_dir ~parents parent perm);
            Unix.mkdir (p :> string) perm
          end
      | e -> raise e
    end;
    true
  end


(* -------------------------------------------------------------------------- *)
(* --- Temporary files                                                    --- *)
(* -------------------------------------------------------------------------- *)

exception Temp_file_error of string

let temp_file ~prefix ~suffix =
  try
    Filename.temp_file prefix suffix |> Filepath.of_string
  with Sys_error s ->
    raise (Temp_file_error s)

let temp_dir ~prefix ~suffix =
  (* temp_dir is introduced in Ocaml 5.1 *)
  let rec one_try limit =
    let dir = Filename.temp_file prefix suffix in
    try
      Unix.unlink dir;
      Unix.mkdir dir 0o700 ;
      Filepath.of_string dir
    with Unix.Unix_error(err,_,_) ->
      if limit < 0 then
        raise (Temp_file_error (Unix.error_message err))
      else
        one_try (pred limit)
  in
  one_try 10


(* -------------------------------------------------------------------------- *)
(* --- File comparison                                                    --- *)
(* -------------------------------------------------------------------------- *)

let digest_raw (p : t) =
  Digest.file (p :> string)

let digest (p : t) =
  digest_raw p |> Digest.to_hex

let same_digest (p1 : t) (p2 : t) =
  String.equal (digest_raw p1) (digest_raw p2)


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

module Compressed : sig
  val with_open_in_exn :
    Filepath.t ->
    (Channel.input, 'a) exn_processor
  val with_open_out_exn :
    ?compress:bool ->
    Filepath.t ->
    (Channel.output, 'a) exn_processor
end = struct
  let with_open_in_exn (p : t) job =
    Channel.open_in_bin (p :> string)
    |> protect_file_op ~close:Channel.close_in job

  let with_open_out_exn ?compress (p : t) job =
    Channel.open_out_bin ?compress (p :> string)
    |> protect_file_op ~close:Channel.close_out job
end

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
