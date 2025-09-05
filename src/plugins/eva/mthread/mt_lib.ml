(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

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
