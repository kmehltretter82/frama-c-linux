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

open Filesystem

let dkey = Kernel.dkey_pp_keep_temp_files

let cleanup_at_exit f = Extlib.safe_at_exit (fun () -> remove_file f)

let should_keep_temp_file = function
  | None -> Kernel.is_debug_key_enabled dkey
  | Some b -> b

let file ?keep ~prefix ~suffix () =
  let file =
    try
      temp_file ~prefix ~suffix
    with Filesystem.Temp_file_error s ->
      Kernel.abort "Cannot open temporary file: %s" s
  in
  Extlib.safe_at_exit
    begin fun () ->
      if not (should_keep_temp_file keep) then
        remove_file file
      else if exists file then
        Kernel.debug ~dkey "Not removing file %a@." Filepath.pretty file
    end;
  file

let dir ?keep ~prefix ~suffix () =
  let dir =
    try
      temp_dir ~prefix ~suffix
    with Filesystem.Temp_file_error s ->
      Kernel.abort "Cannot create temporary dir: %s" s
  in
  Extlib.safe_at_exit
    begin fun () ->
      if not (should_keep_temp_file keep) then
        remove_dir dir
      else if exists dir then
        Kernel.debug ~dkey  "Not removing dir %a@." Filepath.pretty dir;
    end;
  dir
