(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2020                                               *)
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

module Filename = struct
  include Filename
  let concat =
    if Sys.os_type = "Win32" then fun a b -> a ^ "/" ^ b else concat

  let cygpath r =
    let cmd =
      Format.sprintf
        "bash -c \"cygpath -m %s\""
        (String.escaped (String.escaped r))
    in
    let in_channel  = Unix.open_process_in cmd in
    let result = input_line in_channel in
    ignore(Unix.close_process_in in_channel);
    result

  let temp_file =
    if Sys.os_type = "Win32" then
      fun a b -> cygpath (temp_file a b)
    else
      fun a b -> temp_file a b

  let sanitize f = String.escaped f
end

module Env = struct
  let default_env = ref []

  let add_default_env x y = default_env:=(x,y)::!default_env

  let add_env var value =
    add_default_env var value;
    Unix.putenv var value

  let print_default_env fmt =
    match !default_env with
    | [] -> ()
    | l ->
      Format.fprintf fmt "@[Env:@\n";
      List.iter (fun (x,y) -> Format.fprintf fmt "%s = \"%s\"@\n"  x y) l;
      Format.fprintf fmt "@]"

  let default_env var value =
    try
      let v = Unix.getenv var in
      add_default_env (var ^ " (set from outside)") v
    with Not_found -> add_env var value

end

(** the files in [suites] whose name matches
    the pattern [test_file_regexp] will be considered as test files *)
let test_file_regexp = ".*\\.\\(c\\|i\\)$"

(** the pattern that ends the parsing of options in a test file *)
let end_comment = Str.regexp ".*\\*/"

let regex_cmxs = Str.regexp ("\\([^/]+\\)[.]cmxs\\($\\|[ \t]\\)")

let output_unix_error (exn : exn) =
  match exn with
  | Unix.Unix_error (error, _function, arg) ->
    let message = Unix.error_message error in
    if arg = "" then
      Format.eprintf "%s@." message
    else
      Format.eprintf "%s: %s@." arg message
  | _ -> assert false

let mv src dest =
  try
    Unix.rename src dest
  with Unix.Unix_error _ as e ->
    output_unix_error e

let unlink ?(silent = true) file =
  let open Unix in
  try
    Unix.unlink file
  with
  | Unix_error _ when silent -> ()
  | Unix_error (ENOENT,_,_) -> () (* Ignore "No such file or directory" *)
  | Unix_error _ as e -> output_unix_error e

let is_file_empty_or_nonexisting filename =
  let open Unix in
  try
    (Unix.stat filename).st_size = 0
  with
  | Unix_error (UnixLabels.ENOENT, _, _) -> (* file does not exist *)
    true
  | Unix_error _ as e ->
    output_unix_error e;
    raise e

let base_path = Filename.current_dir_name

(** Command-line flags *)

let verbosity = ref 0
let do_make = ref "make"
let suites = ref []
let add_test_suite s = suites := s :: !suites

(** special configuration, with associated oracles *)
let special_config = ref ""

let () =
  Unix.putenv "LC_ALL" "C" (* some oracles, especially in Jessie, depend on the
                              locale *)

let macro_default_options = "-journal-disable -check -no-autoload-plugins"
let macro_frama_c_only = "frama-c @DEFAULT_OPTIONS@"
let macro_frama_c_cmd = "frama-c @DEFAULT_OPTIONS@ @PLUGIN_OPTIONS@"
let macro_frama_c = "frama-c @DEFAULT_OPTIONS@ @PLUGIN_OPTIONS@ @PTEST_FILE@"

let example_msg =
  Format.sprintf
    "@.@[<v 0>\
     Build the dune files allowing running the test suite contained into a directory (defaults to ./tests).@ @ \
     @[<v 1>\
     Some variables can be used in test directives:@  \
     @@PTEST_CONFIG@@    \
     # test configuration suffix@  \
     @@PTEST_FILE@@      \
     # substituted by the test filename@  \
     @@PTEST_DIR@@       \
     # dirname of the test file@  \
     @@PTEST_NAME@@      \
     # basename of the test file@  \
     @@PTEST_NUMBER@@    \
     # test command number@  \
     @@DEFAULT_OPTIONS@@ \
     # the default option list: %s@  \
     @@PLUGIN@@          \
     # the current list of plugins set by the PLUGIN directive@]@.@.\
     @[<v 1>\
     Other variables can only be used in test commands (CMD and EXECNOW directives):@  \
     @@PLUGIN_OPTIONS@@          \
     # the current list of options related to PLUGIN, MODULE and LIBS to load@  \
     @@OPTIONS@@      \
     # the current list of options related to OPT and STDOPT directives (for CMD directives)@  \
     @@frama-c-only@@ \
     # shortcut defined as follow: %s@  \
     @@frama-c@@      \
     # shortcut defined as follow: %s@  \
     @@frama-c-cmd@@  \
     # shortcut defined as follow: %s@  \
     @]@ @]"
    macro_default_options
    macro_frama_c_only
    macro_frama_c
    macro_frama_c_cmd

let umsg = "Usage: ptests [options] [names of test suites]"

let rec argspec =
  [
    "-v", Arg.Unit (fun () -> incr verbosity),
    " Increase verbosity (up to  twice)" ;
    "-make", Arg.String (fun s -> do_make := s;),
    "<command> Use command instead of make";
    "-config", Arg.Set_string special_config,
    " <name> Use special configuration and oracles";
  ]
and help_msg () = Arg.usage (Arg.align argspec) umsg

let () =
  Arg.parse
    ((Arg.align
        (List.sort
           (fun (optname1, _, _) (optname2, _, _) ->
              compare optname1 optname2
           ) argspec)
     ) @ ["", Arg.Unit (fun () -> ()), example_msg;])
    add_test_suite
    umsg


let fail s =
  Format.printf "Error: %s@.Aborting (CWD=%s).@." s (Sys.getcwd());
  exit 2

module PtestsConfig = struct
  (** split the filename into before including "tests" dir and after including "tests" dir
    NOTA: both part contains "tests" (one as suffix the other as prefix).
*)
  let rec get_upper_test_dir initial dir =
    let tests = Filename.dirname dir in
    if tests = dir then
      (* root directory *)
      (fail (Printf.sprintf "Can't find a tests directory below %s" initial))
    else
      let base = Filename.basename dir in
      if base = "tests" then
        dir, "tests"
      else
        let tests, suffix = get_upper_test_dir initial tests in
        tests, Filename.concat suffix base

  let rec get_test_path = function
    | [] ->
      if Sys.file_exists "tests" && Sys.is_directory "tests" then "tests", []
      else begin
        Format.eprintf "No test path found. Aborting (CWD=%s).@." (Sys.getcwd());
        exit 1
      end
    | [f] -> let tests, suffix = get_upper_test_dir f f in
      tests, [suffix]
    | a::l ->
      let tests, l = get_test_path l in
      let a_tests, a = get_upper_test_dir a a in
      if a_tests <> tests
      then fail (Printf.sprintf "All the tests should be inside the same tests directory")
      else tests, a::l

  let test_path =
    let files, names = List.partition Sys.file_exists !suites in
    let tests, l = get_test_path files in
    let names = List.map (Filename.concat tests) names in
    suites := names@l;
    Sys.chdir (Filename.dirname tests);
    "tests"

  (* Those variables are read from a ptests_config file *)
  let default_suites = ref []

  let parse_config_line =
    let split_blank s = Str.split (Str.regexp "[ ]+") s in
    fun (key, value) ->
    match key with
    | "DEFAULT_SUITES" ->
      let l = split_blank value in
      default_suites := List.map (Filename.concat test_path) l
    | _ -> Env.default_env key value (* Environnement variable that Frama-C reads*)

  (** parse config files *)
  let () =
    let config = "tests/ptests_config" in
    if Sys.file_exists config then begin
      try
        (*Parse the plugin configuration file for tests. Format is 'Key=value' *)
        let ch = open_in config in
        let regexp = Str.regexp "\\([^=]+\\)=\\(.*\\)" in
        let regexp_comment = Str.regexp " *#" in
        while true do
          let line = input_line ch in
          if Str.string_match regexp line 0 then
            let key = Str.matched_group 1 line in
            let value = Str.matched_group 2 line in
            parse_config_line (key, value)
          else if not (Str.string_match regexp_comment line 0) then begin
            Format.eprintf "Cannot interpret line '%s' in file %s. Aborting (CWD=%s).@." line config (Sys.getcwd());
            exit 1
          end
        done
      with
      | End_of_file -> ()
    end
    else begin
      Format.eprintf
        "Cannot find configuration file %s. Aborting (CWD=%s).@." config (Sys.getcwd()) ;
      exit 1
    end

end

(* redefine name if special configuration expected *)
let config_name name =
  if !special_config = "" then name else name ^ "_" ^ !special_config

(** the name of the directory-wide configuration file*)
let dir_config_file = "test_config"
let dir_config_file = config_name dir_config_file

let gen_make_file s _dir file = Filename.concat s file

module SubDir: sig
  type t

  val get: t -> string

  val create: ?with_subdir:bool -> string (** dirname *) -> t
  (** By default, creates the needed subdirectories if absent.
      Anyway, fails if the given dirname doesn't exists *)

  val make_oracle_file: t -> string -> string
  val make_result_file: t -> string -> string
  val make_file: t -> string -> string
  val oracle_dirname: string
  val result_dirname: string
end = struct
  type t = string

  let get s = s

  let create_if_absent dir =
    if not (Sys.file_exists dir)
    then Unix.mkdir dir 0o750 (* rwxr-w--- *)
    else if not (Sys.is_directory dir)
    then fail (Printf.sprintf "the file %s exists but is not a directory" dir)

  let oracle_dirname = config_name "oracle"
  let result_dirname = config_name "result"

  let make_result_file _ x = x
  let make_oracle_file = gen_make_file oracle_dirname
  let make_file = Filename.concat

  let create ?(with_subdir=true) dir =
    if not (Sys.file_exists dir && Sys.is_directory dir)
    then fail (Printf.sprintf "the directory %s must be an existing directory" dir);
    if (with_subdir) then begin
      create_if_absent (Filename.concat dir result_dirname);
      create_if_absent (Filename.concat dir oracle_dirname)
    end;
    dir

end

type execnow =
  { ex_cmd: string;      (** command to launch *)
    ex_log: string list; (** log files *)
    ex_bin: string list; (** bin files *)
    ex_dir: SubDir.t;    (** directory of test suite *)
    ex_once: bool;       (** true iff the command has to be executed only once
                             per config file (otherwise it is executed for
                             every file of the test suite) *)
    ex_done: bool ref;   (** has the command been already fully executed.
                             Shared between all copies of this EXECNOW. Do
                             NOT use a mutable field here, as execnows
                             are duplicated using OCaml 'with' syntax. *)
    ex_timeout: string;
  }


module Macros = struct
  module StringMap = Map.Make (String)
  open StringMap

  type t = string StringMap.t

  let empty = StringMap.empty

  let macro_regex = Str.regexp "\\([^@]*\\)@\\([^@]*\\)@\\(.*\\)"

  let does_expand macros s =
    if !verbosity >=3 then begin
      Format.printf "looking for macros in string %s\n%!" s;
      Format.printf "Existing macros:\n%!";
      iter (fun s1 s2 -> Format.printf "%s => %s\n%!" s1 s2) macros;
      Format.printf "End macros\n%!";
    end;
    let rec aux n (ptest_file_matched,s as acc) =
      if Str.string_match macro_regex s n then begin
        let macro = Str.matched_group 2 s in
        let ptest_file_matched = ptest_file_matched || macro = "PTEST_FILE" in
        let start = Str.matched_group 1 s in
        let rest = Str.matched_group 3 s in
        let new_n = Str.group_end 1 in
        let n, new_s =
          if macro = "" then begin
            new_n + 1, String.sub s 0 new_n ^ "@" ^ rest
          end else begin
            try
              if !verbosity >= 3 then Format.printf "macro is %s\n%!" macro;
              let replacement =  find macro macros in
              if !verbosity >= 2 then
                Format.printf "replacement for %s is %s\n%!" macro replacement;
              new_n,
              String.sub s 0 n ^ start ^ replacement ^ rest
            with
            | Not_found -> Str.group_end 2 + 1, s
          end
        in
        if !verbosity >= 3 then Format.printf "new string is %s\n%!" new_s;
        let new_acc = ptest_file_matched, new_s in
        if n <= String.length new_s then aux n new_acc else new_acc
      end else acc
    in
    try
      aux 0 (false,s)
    with e ->
      Format.eprintf "Uncaught exception %s\n%!" (Printexc.to_string e);
      raise e

  let expand macros s =
    snd (does_expand macros s)

  let get ?(default="") name macros =
    try find name macros with Not_found -> default

  let add_list l map =
    List.fold_left (fun acc (k,v) -> add k v acc) map l

  let add_expand name def macros =
    add name (expand macros def) macros

  let append_expand name def macros =
    add name (get name macros ^ expand macros def) macros

  let default_macros () = add_list
    [ "PLUGIN", "" ;
      "DEFAULT_OPTIONS", macro_default_options;
      "OPTIONS", "";
      "frama-c-only", macro_frama_c_only;
      "frama-c-cmd", macro_frama_c_cmd;
      "frama-c",     macro_frama_c;
    ] empty

end

(** configuration of a directory/test. *)
type cmd = { toplevel:string ; opts:string ; macros: Macros.t ; logs:string list ; timeout:string }
type config =
  {
    dc_test_regexp: string; (** regexp of test files. *)
    dc_execnow    : execnow list; (** command to be launched before
                                       the toplevel(s)
                                  *)
    dc_libs    : string list; (** libraries to compile *)
    dc_cmxs    : string list; (** cmxs to compile *)
    dc_deps    : string list; (** deps *)
    dc_plugins : string list; (** only plugins to load *)
    dc_load_module : string list; (** module to load *)
    dc_macros: Macros.t; (** existing macros. *)
    dc_default_toplevel   : string;
    (** full path of the default toplevel. *)
    dc_filter     : string option; (** optional filter to apply to
                                       standard output *)
    dc_commands    : cmd list;
    (** toplevel full path, options to launch the toplevel on, and list
        of output files to monitor beyond stdout and stderr. *)
    dc_dont_run   : bool;
    dc_framac     : bool;
    dc_default_log: string list;
    dc_timeout: string
  }

let default_toplevel = "@frama-c@ @OPTIONS@"
let default_command = {toplevel=default_toplevel; opts=""; logs=[]; macros=Macros.empty; timeout=""}
let default_config () =
  { dc_test_regexp = test_file_regexp ;
    dc_macros = Macros.default_macros ();
    dc_execnow = [];
    dc_libs = [];
    dc_cmxs = [];
    dc_deps = [];
    dc_plugins = [];
    dc_load_module = [];
    dc_filter = None ;
    dc_default_toplevel = default_toplevel;
    dc_commands = [ default_command ];
    dc_dont_run = false;
    dc_framac = true;
    dc_default_log = [];
    dc_timeout = "";
  }

let scan_execnow ~once dir ex_timeout (s:string) =
  let rec aux (s:execnow) =
    try
      Scanf.sscanf s.ex_cmd "%_[ ]LOG%_[ ]%[-A-Za-z0-9_',+=:.\\@@]%_[ ]%s@\n"
        (fun name cmd ->
           aux { s with ex_cmd = cmd; ex_log = name :: s.ex_log })
    with Scanf.Scan_failure _ ->
    try
      Scanf.sscanf s.ex_cmd "%_[ ]BIN%_[ ]%[A-Za-z0-9_.\\-@@]%_[ ]%s@\n"
        (fun name cmd ->
           aux { s with ex_cmd = cmd; ex_bin = name :: s.ex_bin })
    with Scanf.Scan_failure _ ->
    try
      Scanf.sscanf s.ex_cmd "%_[ ]make%_[ ]%s@\n"
        (fun cmd ->
           let s = aux ({ s with ex_cmd = cmd; }) in
           { s with ex_cmd = !do_make^" "^cmd; } )
    with Scanf.Scan_failure _ ->
      s
  in
  aux
    { ex_cmd = s;
      ex_log = [];
      ex_bin = [];
      ex_dir = dir;
      ex_once = once;
      ex_done = ref false;
      ex_timeout;
    }

(* the default toplevel for the current level of options. *)
let current_default_toplevel = ref default_toplevel
let current_default_log = ref []
let current_default_cmds = ref [ default_command ]

let make_custom_opts =
  let space = Str.regexp " " in
  fun stdopts s ->
    let rec aux opts s =
      try
        Scanf.sscanf s "%_[ ]%1[+#\\-]%_[ ]%S%_[ ]%s@\n"
          (fun c opt rem ->
             match c with
             | "+" -> aux (opt :: opts) rem
             | "#" -> aux (opts @ [ opt ]) rem
             | "-" -> aux (List.filter (fun x -> x <> opt) opts) rem
             | _ -> assert false (* format of scanned string disallow it *))
      with
      | Scanf.Scan_failure _ ->
        if s <> "" then
          Format.eprintf "unknown STDOPT configuration string: %s\n%!" s;
        opts
      | End_of_file -> opts
    in
    (* NB: current settings does not allow to remove a multiple-argument
       option (e.g. -verbose 2).
    *)
    (* revert the initial list, as it will be reverted back in the end. *)
    let opts = aux (List.rev (Str.split space stdopts)) s in
    (* preserve options ordering *)
    List.fold_right (fun x s -> s ^ " " ^ x) opts ""


(* how to process options *)
let config_exec ~once dir s current =
  { current with
    dc_execnow =
      scan_execnow ~once dir current.dc_timeout s :: current.dc_execnow }

let split_list s = Str.split (Str.regexp "[ ,]+") s
let config_deps _dir s current =
  { current with dc_deps = (split_list s) @ current.dc_deps }

let config_cmxs _dir s current =
  let l = List.map (fun s -> Filename.remove_extension s) (split_list s) in
  { current with dc_cmxs = l @ current.dc_cmxs }

let config_libs _dir s current =
  let l = List.map (fun s -> Filename.remove_extension s) (split_list s) in
  { current with dc_libs = l @ current.dc_libs ;
    dc_deps = (List.map (fun s -> s^".cmxs") l) @ current.dc_deps }

let config_plugin _dir s current =
  let s = Macros.expand current.dc_macros s in
  { current with dc_plugins = split_list s ;
                 dc_macros = Macros.add_list ["PLUGIN", s] current.dc_macros }

let config_module _dir s current =
  let l = List.map (fun s -> Filename.remove_extension s) (split_list s) in
  let deps = List.map (fun s -> s ^ ".cmxs") l in
  { current with
    dc_cmxs = l @ current.dc_cmxs;
    dc_deps = deps @ current.dc_deps;
    dc_load_module = deps @ current.dc_load_module;
  }

let config_macro _dir s current =
  let regex = Str.regexp "[ \t]*\\([^ \t@]+\\)\\([ \t]+\\(.*\\)\\|$\\)" in
  if Str.string_match regex s 0 then begin
    let name = Str.matched_group 1 s in
    let def =
      try Str.matched_group 3 s with Not_found -> (* empty text *) ""
    in
    if !verbosity >= 2 then
      Format.printf "new macro %s with definition %s\n%!" name def;
    { current with dc_macros = Macros.add_expand name def current.dc_macros }
  end else begin
    Format.eprintf "cannot understand MACRO definition: %s\n%!" s;
    current
  end

let config_options =
  [ "CMD",
    (fun _ s current ->
       { current with dc_default_toplevel = s});

    "OPT",
    (fun _ s current ->
       let t =
         { toplevel = current.dc_default_toplevel;
           opts = s;
           logs = current.dc_default_log;
           macros = current.dc_macros;
           timeout = current.dc_timeout }
       in
       { current with
         (*           dc_default_toplevel = !current_default_toplevel;*)
         dc_default_log = !current_default_log;
         dc_commands = t :: current.dc_commands });

    "STDOPT",
    (fun _ s current ->
       let new_top =
         List.map
           (fun command ->
              { command with opts= make_custom_opts command.opts s ;
                             macros = current.dc_macros;
                             timeout= current.dc_timeout})
           !current_default_cmds
       in
       { current with dc_commands = new_top @ current.dc_commands;
                      dc_default_log = !current_default_log @
                                       current.dc_default_log });

    "FILEREG",
    (fun _ s current -> { current with dc_test_regexp = s });

    "FILTER",
    (fun _ s current -> { current with dc_filter = Some s });

    "GCC",
    (fun _ _ acc -> acc);

    "COMMENT",
    (fun _ _ acc -> acc);

    "DONTRUN",
    (fun _ _ current -> { current with dc_dont_run = true });

    "EXECNOW", config_exec ~once:true;
    "EXEC", config_exec ~once:false;
    "CMXS", config_cmxs;
    "LIBS", config_libs;
    "DEPS", config_deps;
    "MACRO", config_macro;
    "MODULE", config_module;
    "PLUGIN", config_plugin;
    "LOG",
    (fun _ s current ->
       { current with dc_default_log = s :: current.dc_default_log });
    "TIMEOUT",
    (fun _ s current -> { current with dc_timeout = s });
    "NOFRAMAC",
    (fun _ _ current -> { current with dc_commands = []; dc_framac = false; });
  ]

let scan_options dir scan_buffer default =
  current_default_toplevel := default.dc_default_toplevel;
  current_default_log := default.dc_default_log;
  current_default_cmds := List.rev default.dc_commands;
  let r = ref { default with dc_commands = [] } in
  let treat_line s =
    try
      Scanf.sscanf s "%[ *]%[A-Za-z0-9]: %s@\n"
        (fun _ name opt ->
           try
             r := (List.assoc name config_options) dir opt !r
           with Not_found ->
             Format.eprintf "@[unknown configuration option: %s@\n%!@]" name)
    with
    | Scanf.Scan_failure _ ->
      if Str.string_match end_comment s 0
      then raise End_of_file
      else ()
    | End_of_file -> (* ignore blank lines. *) ()
  in
  try
    while true do
      if Scanf.Scanning.end_of_input scan_buffer then raise End_of_file;
      Scanf.bscanf scan_buffer "%s@\n" treat_line
    done;
    assert false
  with
  | End_of_file ->
    (match !r.dc_commands with
     | [] when !r.dc_framac -> { !r with dc_commands = default.dc_commands }
     | l -> { !r with dc_commands = List.rev l })

let split_config s = Str.split (Str.regexp ",[ ]*") s

let is_config name =
  let prefix = "run.config" in
  let len = String.length prefix in
  String.length name >= len && String.sub name 0 len = prefix

let scan_test_file default dir f =
  let f = SubDir.make_file dir f in
  let exists_as_file =
    try
      (Unix.lstat f).Unix.st_kind = Unix.S_REG
    with | Unix.Unix_error _ | Sys_error _ -> false
  in
  if exists_as_file then begin
    let scan_buffer = Scanf.Scanning.open_in f in
    let rec scan_config () =
      (* space in format string matches any number of whitespace *)
      Scanf.bscanf scan_buffer " /* %s@\n"
        (fun names ->
           let is_current_config name =
             name = "run.config*" ||
             name = "run.config" && !special_config = ""  ||
             name = "run.config_" ^ !special_config
           in
           let configs = split_config (String.trim names) in
           if List.exists is_current_config configs then
             (* Found options for current config! *)
             scan_options dir scan_buffer default
           else (* config name does not match: eat config and continue.
                   But only if the comment is still opened by the end of
                   the line and we are indeed reading a config
                *)
             (if List.exists is_config configs &&
                 not (Str.string_match end_comment names 0) then
                ignore (scan_options dir scan_buffer default);
              scan_config ()))
    in
    try
      let options =  scan_config () in
      Scanf.Scanning.close_in scan_buffer;
      options
    with End_of_file | Scanf.Scan_failure _ ->
      Scanf.Scanning.close_in scan_buffer;
      default
  end else
    (* if the file has disappeared, don't try to run it... *)
    { default with dc_dont_run = true }

type toplevel_command =
  { macros: Macros.t;
    mutable log_files: string list;
    file : string ;
    nb_files : int ;
    options : string ;
    toplevel: string ;
    filter : string option ;
    directory : SubDir.t ;
    n : int;
    execnow:bool;
    timeout: string;
    deps: string list;
    plugins: string list;
    load_module: string list;
  }

type command =
  | Toplevel of toplevel_command
  | Target of execnow * command Queue.t

type log = Err | Res

type diff =
  | Command_error of toplevel_command * log
  | Target_error of execnow
  | Log_error of SubDir.t (* directory *) * string (* file *)

type cmps =
  | Cmp_Toplevel of toplevel_command
  | Cmp_Log of SubDir.t (* directory *) * string (* file *)

let catenate_number nb_files prefix n =
  if nb_files > 1
  then prefix ^ "." ^ (string_of_int n)
  else prefix

let name_without_extension command =
  try
    Filename.chop_extension command.file
  with
    Invalid_argument _ ->
    fail ("this test file does not have any extension: " ^
          command.file)

let gen_prefix gen_file cmd =
  let prefix = gen_file cmd.directory (name_without_extension cmd) in
  catenate_number cmd.nb_files prefix cmd.n

let log_prefix = gen_prefix SubDir.make_result_file
let oracle_prefix = gen_prefix SubDir.make_oracle_file

let get_macros cmd =
  let ptest_config = config_name "" in
  let ptest_file = Filename.sanitize cmd.file in
  let ptest_name = Filename.remove_extension cmd.file in
  let macros =
    [ "PTEST_CONFIG", ptest_config;
      "PTEST_DIR", SubDir.get cmd.directory;
      "PTEST_RESULT",
      Filename.concat (SubDir.get cmd.directory) (config_name "result");
      "PTEST_FILE", ptest_file;
      "PTEST_NAME", ptest_name;
      "PTEST_NUMBER", string_of_int cmd.n;
    ]
  in
  Macros.add_list macros cmd.macros

let basic_command_string command =
  let macros = get_macros command in
  command.log_files <- List.map (Macros.expand macros) command.log_files;
  let expanded_plugins_options =
    let opt_plugin =  Printf.sprintf "-load-plugin=%s" (String.concat "," command.plugins) in
    let opt_modules = String.concat " "
        (List.map (fun s -> Printf.sprintf " -load-module %S" (Macros.expand macros s))
           command.load_module) in
    String.concat " " [opt_plugin;opt_modules]
  and expanded_options = Macros.expand macros command.options in
  let macros = (* set expanded macros that can be used into CMD directives *)
    Macros.add_list [
      "OPTIONS", expanded_options;
      "PLUGIN_OPTIONS", expanded_plugins_options;
    ] macros in
  let raw_command = Macros.expand macros command.toplevel in
  if command.timeout = "" then raw_command
  else "ulimit -t " ^ command.timeout ^ " && " ^ raw_command

(* Searches for executable [s] in the directories contained in the PATH
   environment variable. Returns [None] if not found, or
   [Some <fullpath>] otherwise. *)
(*
  let find_in_path s =
  let trim_right s =
    let n = ref (String.length s - 1) in
    let last_char_to_keep =
      try
        while !n > 0 do
          if String.get s !n <> ' ' then raise Exit;
          n := !n - 1
        done;
        0
      with Exit -> !n
    in
    String.sub s 0 (last_char_to_keep+1)
  in
  let s = trim_right s in
  let path_separator = if Sys.os_type = "Win32" then ";" else ":" in
  let re_path_sep = Str.regexp path_separator in
  let path_dirs = Str.split re_path_sep (Sys.getenv "PATH") in
  let found = ref "" in
  try
    List.iter (fun dir ->
        let fullname = dir ^ Filename.dir_sep ^ s in
        if Sys.file_exists fullname then begin
          found := fullname;
          raise Exit
        end
      ) path_dirs;
    None
  with Exit ->
    Some !found
*)

let print_list fmt l = List.iter (Format.fprintf fmt " %S") l
module Fmt = struct
  let plugin_as_package fmt s = Format.fprintf fmt "frama-c-%s" s
  let quote pr fmt s = Format.fprintf fmt "%S" (Format.asprintf "%a" pr s)
  let list pr fmt l = List.iter (fun s -> Format.fprintf fmt " %a" pr s) l
  let var_libavailable pr fmt s = Format.fprintf fmt "%%{lib-available:%a}" pr s
  let package_as_deps pr fmt s = Format.fprintf fmt "(package %a)" pr s
end

let command_string ~result_fmt ~oracle_fmt command =
  let log_prefix = log_prefix command in
  let errlog = log_prefix ^ ".err.log" in
  (* let stderr = match command.filter with
   *     None -> errlog
   *   | Some _ ->
   *     let stderr =
   *       Filename.temp_file (Filename.basename log_prefix) ".err.log"
   *     in
   *     at_exit (fun () ->  unlink stderr);
   *     stderr
   * in *)
  (* let filter = match command.filter with
   *   | None -> None
   *   | Some filter ->
   *     let len = String.length filter in
   *     let rec split_filter i =
   *       if i < len && filter.[i] = ' ' then split_filter (i+1)
   *       else
   *         try
   *           let idx = String.index_from filter i ' ' in
   *           String.sub filter i idx,
   *           String.sub filter idx (len - idx)
   *         with Not_found ->
   *           String.sub filter i (len - i), ""
   *     in
   *     let exec_name, params = split_filter 0 in
   *     let exec_name =
   *       if Sys.file_exists exec_name || not (Filename.is_relative exec_name)
   *       then exec_name
   *       else
   *         match find_in_path exec_name with
   *         | Some full_exec_name -> full_exec_name
   *         | None ->
   *           Filename.concat
   *             (Filename.dirname (Filename.dirname log_prefix))
   *             (Filename.basename exec_name)
   *     in
   *     Some (exec_name ^ params)
   * in *)
    let filter_stdout_begin,filter_stdout_end = match command.filter with
    | None -> "",""
    | Some filter ->
      "(pipe-stdout ",
      Format.sprintf "(system %S))" filter
  in
  let command_string = basic_command_string command in
  (* let command_string = match filter with
   *   | None -> command_string
   *   | Some filter -> command_string ^ " | " ^ filter
   * in *)
  let res = (log_prefix ^ ".res.log") in
  (* let command_string =
   *   match command.timeout with
   *   | "" -> command_string
   *   | s ->
   *     Format.sprintf
   *       "%s; if test $? -gt 127; then \
   *        echo 'TIMEOUT (%s); ABORTING EXECUTION' > %s; \
   *        fi"
   *       command_string s (Filename.sanitize stderr)
   * in *)
  (* let command_string = match filter with
   *   | None -> command_string
   *   | Some filter ->
   *     Format.sprintf "%s && %s < %s >%s && rm -f %s"
   *       command_string
   *       filter
   *       (Filename.sanitize stderr)
   *       (Filename.sanitize errlog)
   *       (Filename.sanitize stderr)
   * in *)
  let macros = get_macros command in
  let deps = List.map (Macros.expand macros) command.deps in
  Format.fprintf result_fmt
    "(rule\n  \
     (targets %S %S %a)\n  \
     (deps   %a %S (package frama-c)%a)\n  \
     (action (with-stderr-to %S (with-stdout-to %S %s(with-accepted-exit-codes (or 0 1 3 4 125 127) (system %S))%s)))\n\
     )@."
    errlog
    res
    print_list command.log_files
    print_list deps
    command.file
    Fmt.(list (package_as_deps (quote plugin_as_package))) command.plugins
    errlog
    res
    filter_stdout_begin
    command_string
    filter_stdout_end
  ;
    Format.fprintf result_fmt
    "(rule\n  \
     (alias %S)\n  \
     (deps  %a %S (package frama-c)%a (universe))\n  \
     (action (system %S))\n\
     )@."
    command.file
    print_list deps
    command.file
    Fmt.(list (package_as_deps (quote plugin_as_package))) command.plugins
    command_string;

  let oracle_prefix = oracle_prefix command in
  let diff_alias = log_prefix ^ ".diff" in
  (* diff with oracles *)
  Format.fprintf result_fmt
    "(rule\n  \
     (alias %S)\n  \
     (action (diff %S %S))\n\
     )@."
    diff_alias
    (Filename.concat ".." (oracle_prefix ^ ".res.oracle"))
    (log_prefix ^ ".res.log");
  Format.fprintf result_fmt
    "(rule\n  \
     (alias %S)\n  \
     (action (diff %S %S))\n\
     )@."
    diff_alias
    (Filename.concat ".." (oracle_prefix ^ ".err.oracle"))
    (log_prefix ^ ".err.log");
  Format.fprintf result_fmt
    "(alias (deps (alias %S)) (name ptests); (enabled_if (and true %a))\n\
     )@."
    diff_alias
    Fmt.(list (var_libavailable plugin_as_package )) command.plugins
  ;
  Format.fprintf oracle_fmt
    "(rule (target %S) (mode fallback) (action (write-file %S \"\")))\n"
    (Filename.basename (oracle_prefix ^ ".err.oracle"))
    (Filename.basename (oracle_prefix ^ ".err.oracle"));
  Format.fprintf oracle_fmt
    "(rule (target %S) (mode fallback) (action (write-file %S \"\")))\n"
    (Filename.basename (oracle_prefix ^ ".res.oracle"))
    (Filename.basename (oracle_prefix ^ ".res.oracle"));
  ()

(** process a test file *)
let dispatcher ~result_fmt ~oracle_fmt file directory config =
  let config = scan_test_file config directory file in
  if not config.dc_dont_run then
    let i = ref 0 in
    let e = ref 0 in
    let nb_files = List.length config.dc_commands in
    let make_toplevel_cmd {toplevel; opts=options; logs=log_files; macros; timeout} =
      let n = !i in
      { file; options; toplevel; nb_files; directory; n; log_files;
        filter = config.dc_filter; macros;
        execnow=false; timeout;
        deps = config.dc_deps;
        plugins = config.dc_plugins;
        load_module = config.dc_libs @ config.dc_load_module ;
      }
    in
    let mk_cmd (s, timeout) =
      { file = file;
        nb_files = nb_files;
        log_files = [];
        options = "";
        toplevel = s;
        n = !e;
        directory = directory;
        filter = config.dc_filter;
        macros = config.dc_macros;
        execnow = true;
        timeout;
        deps = config.dc_deps;
        plugins = config.dc_plugins;
        load_module = config.dc_libs @ config.dc_load_module;
      }
    in
    let macros = get_macros (mk_cmd ("/bin/true","")) in
    let make_execnow_cmd execnow =
      let res =
        { ex_cmd = basic_command_string (mk_cmd  (execnow.ex_cmd, execnow.ex_timeout));
          ex_log = List.map (Macros.expand macros) execnow.ex_log;
          ex_bin = List.map (Macros.expand macros) execnow.ex_bin;
          ex_dir = execnow.ex_dir;
          ex_once = execnow.ex_once;
          ex_done = execnow.ex_done;
          ex_timeout = execnow.ex_timeout;
        }
      in
      Format.fprintf result_fmt
       "(rule\n  \
        (alias ptests)\n  \
        (deps %a (package frama-c)%a)\n  \
        (targets %a %a)\n  \
        (action (system %S))\n\
        )\n"
       print_list config.dc_deps
       Fmt.(list (package_as_deps (quote plugin_as_package))) config.dc_plugins
       print_list res.ex_log
       print_list res.ex_bin
       res.ex_cmd
      ;
      List.iter (fun log ->
          Format.fprintf result_fmt
            "(rule\n  \
             (alias ptests)\n  \
             (action (diff %S %S))\n\
             )\n"
            (Filename.concat ".." (Filename.concat SubDir.oracle_dirname log))
            log
        ) res.ex_log;
      incr e
    in
    let treat_option option =
      let toplevel = make_toplevel_cmd option in
      command_string ~result_fmt ~oracle_fmt toplevel;
      incr i
    in
    List.iter (fun cmxs ->
        let file = Macros.expand macros cmxs in
        let libraries = Macros.expand macros (String.concat " " config.dc_libs) in
        Format.fprintf result_fmt
          "(executable\n  \
           (name %s)\n  \
           (modules %s)\n  \
           (modes plugin)\n  \
           (libraries frama-c.init.cmdline frama-c.boot frama-c.kernel %a %s)\n  \
           (flags -open Frama_c_kernel)\n\
           )"
          file file
          print_list (List.map (Format.sprintf "frama-c-%s.core") config.dc_plugins)
          libraries
      ) config.dc_cmxs;
    List.iter treat_option config.dc_commands;
    List.iter make_execnow_cmd config.dc_execnow

let test_pattern config =
  let regexp = Str.regexp config.dc_test_regexp in
  fun file -> Str.string_match regexp file 0

(* test for a possible toplevel configuration. *)
let default_config () =
  let general_config_file = Filename.concat PtestsConfig.test_path dir_config_file in
  if Sys.file_exists general_config_file
  then begin
    let scan_buffer = Scanf.Scanning.from_file general_config_file in
    scan_options
      (SubDir.create ~with_subdir:false Filename.current_dir_name)
      scan_buffer
      (default_config ())
  end
  else default_config ()

(* if we have some references to directories in the default config, they
   need to be adapted to the actual test directory. *)
let update_dir_ref dir config =
  let update_execnow e = { e with ex_dir = dir } in
  let dc_execnow = List.map update_execnow config.dc_execnow in
  { config with dc_execnow }

let () =
  (* enqueue the test files *)
  let suites =
    match !suites with
    | [] -> !PtestsConfig.default_suites
    | l ->
      List.fold_left (fun acc x ->
          if x = "tests"
          then !PtestsConfig.default_suites @ acc
          else x::acc
        ) [] l
  in
  List.iter
    (fun suite ->
       if !verbosity >= 1 then Format.printf "%% Test suite %s\n%!" suite;
       let directory = SubDir.create suite in
       let result_dune_file = Filename.concat (SubDir.make_file directory SubDir.result_dirname) "dune" in
       let result_cout = (open_out result_dune_file) in
       let result_fmt = Format.formatter_of_out_channel result_cout  in
       Format.fprintf result_fmt "(copy_files ../*.*)@.";
       let oracle_dune_file = Filename.concat (SubDir.make_file directory SubDir.oracle_dirname) "dune" in
       let oracle_cout = (open_out oracle_dune_file) in
       let oracle_fmt = Format.formatter_of_out_channel oracle_cout in
       let dir_config =
         let config = SubDir.make_file directory dir_config_file in
         let default = default_config () in
         let default = update_dir_ref directory default in
         if Sys.file_exists config
         then begin
           let scan_buffer = Scanf.Scanning.from_file config in
           scan_options directory scan_buffer default
         end
         else default
       in
       let dir_files = Sys.readdir (SubDir.get directory) in
       for i = 0 to pred (Array.length dir_files) do
         let file = dir_files.(i) in
         assert (Filename.is_relative file);
         if test_pattern dir_config file
         then begin
           dispatcher ~result_fmt ~oracle_fmt file directory dir_config;
         end;
       done;
       Format.fprintf result_fmt "@.";
       Format.fprintf oracle_fmt "@.";
       close_out result_cout;
       close_out oracle_cout;
    )
    suites

(*
Local Variables:
compile-command: "LC_ALL=C make -C .. ptests"
End:
*)
