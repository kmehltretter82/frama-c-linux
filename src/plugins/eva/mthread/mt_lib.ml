(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

(* -------------------------------------------------------------------------- *)
(* --- Misc                                                               --- *)
(* -------------------------------------------------------------------------- *)

type 'a conversion_with_warning = [
  | `Success of 'a
  | `WithWarning of (Format.formatter -> unit) * 'a
]

type 'a conversion = [
  | `Success of 'a
  | `Failure of (Format.formatter -> unit)
]


let escape_char c =
  if c = '"' then "\\\"" else Char.escaped c

let escape_non_utf8 s =
  let buffer = Buffer.create (String.length s) in
  let rec aux i =
    if i < String.length s then
      let uchar = String.get_utf_8_uchar s i in
      let len = Uchar.utf_decode_length uchar in
      if len = 1
      then escape_char s.[i] |> Buffer.add_string buffer
      else Uchar.utf_decode_uchar uchar |> Buffer.add_utf_8_uchar buffer;
      aux (i + len)
  in
  aux 0;
  Buffer.contents buffer

let clear_value_results () =
  Project.clear ~selection:(State_selection.with_dependencies
                              Analysis.self) ();
;;

let mthread_h () =
  Mt_self.Share.get_file "mthread.h";;


let sanitize_filename ?(char='_') s =
  let is_invalid c =
    match c with
    | '&' | '+' | '[' | ']' | '.' -> true
    | _ -> false
  in
  String.map (fun c -> if is_invalid c then char else c) s

type threads_lib =
  | BuiltinsOnly
  | Pthreads

let pp_threads_lib fmt lib =
  match lib with
  | BuiltinsOnly -> Format.pp_print_string fmt "builtins only"
  | Pthreads -> Format.pp_print_string fmt "lib pthreads"

let threads_lib_files lib =
  let mthread_c = Mt_self.Share.get_file "mthread.c" in
  match lib with
  | BuiltinsOnly ->
    Filepath.Set.singleton mthread_c
  | Pthreads ->
    let mthread_pthread_c = Mt_self.Share.get_file "mthread_pthread.c" in
    Filepath.Set.of_list [ mthread_c ; mthread_pthread_c ]

let load_threads_library lib =
  Mt_self.feedback "Preparing sources for Mthread with %a" pp_threads_lib lib;

  (* Add MThread folder to the include path. *)
  let mt_include_dir =
    Format.asprintf "-I%a"
      Filepath.pretty_abs (Mt_self.Share.get_dir ".")
  in
  Kernel.CppExtraArgs.add mt_include_dir;

  (* Add the stubbed library files to the list of files to parse. *)
  threads_lib_files lib
  |> Filepath.Set.iter
    (fun f ->
       let f = File.from_filename f in
       File.pre_register f)
