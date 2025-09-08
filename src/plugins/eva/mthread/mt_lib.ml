(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

(** Variables from mthread.c used by the cvalue domain to represent
    threads, mutexes and queues during the analysis. *)

let find_mthread_global_var name =
  try Globals.Vars.find_from_astinfo name Global
  with Not_found ->
    let mthread_c = Mt_self.Share.get_file "mthread.c" in
    Mt_self.abort
      "Variable %S not found. \
       It should be in file %a, required for the Mthread analysis. \
       Use parameter -mt-threads-lib to include this file in the parsing phase."
      name Filepath.pretty mthread_c

let mthread_global_var name =
  let module Info = struct
    let name = "Eva.Mt_lib." ^ name
    let dependencies = [ Ast.self ]
  end in
  let module Ref = State_builder.Option_ref (Cil_datatype.Varinfo) (Info) in
  fun () -> Ref.memo (fun () -> find_mthread_global_var name)

let array_threads = mthread_global_var "__fc_mthread_threads"
let array_mutexes = mthread_global_var "__fc_mthread_mutexes"
let array_queues = mthread_global_var "__fc_mthread_queues"
let var_thread_created = mthread_global_var "__fc_mthread_threads_running"

let check_mthread_library () =
  ignore (array_threads ());
  ignore (array_mutexes ());
  ignore (array_queues ());
  ignore (var_thread_created ());


  (** Load files used to stub threads library. *)

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
