(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2022                                               *)
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

module StringSet = Set.Make(String)

(* returns true for empty files *)
let is_last_byte_newline filename =
  try
    let ic = open_in filename in
    try
      let fd = Unix.descr_of_in_channel ic in
      ignore (Unix.lseek fd (-1) Unix.SEEK_END);
      let buf = Bytes.create 1 in
      let n_bytes_read = Unix.read fd buf 0 1 in
      close_in ic;
      n_bytes_read <= 0 || Bytes.get buf 0 = '\n'
    with
    | Unix.Unix_error _ ->
      (* probably an empty file; ignoring *)
      close_in ic;
      true
  with
  | Sys_error msg ->
    (* possibly a non-existing file (e.g. with spaces); ignoring *)
    Format.printf "check_newlines: cannot open, ignoring file: %s (%s)@."
      filename msg;
    true

(* usage: first argument is a file name containing a list of files
   (one per line) to be checked; the remaining arguments are a list of
   files to be ignored during checking
   (i.e. they do not terminate with newlines). *)
let () =
  if Array.length Sys.argv < 2 then begin
    Format.printf "usage: %s file_list.txt [ignore1 ignore2 ...]@." Sys.argv.(0);
    exit 0
  end;
  let errors = ref 0 in
  let file_list_ic = open_in Sys.argv.(1) in
  let to_ignore = StringSet.of_list (List.tl (Array.to_list Sys.argv)) in
  begin
    try
      while true; do
        let filename = input_line file_list_ic in
        if not (StringSet.mem filename to_ignore) &&
           not (is_last_byte_newline filename) then begin
          incr errors;
          Format.printf "error: no newline at end of file: %s@." filename
        end
      done
    with End_of_file ->
      close_in file_list_ic
  end;
  if !errors > 0 then begin
    Format.printf "Found %d file(s) with errors.@." !errors;
    exit 1
  end else
    exit 0
