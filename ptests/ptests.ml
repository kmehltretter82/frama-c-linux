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

(** Command-line flags *)

let verbosity = ref 0
let check_oracles = ref false
let create_missing_oracles = ref false
let remove_empty_oracles = ref false
let nb_dune_files = ref 0
let nb_ignores = ref 0
let ignored_suites = ref []

(* Set to an empty string to use no wrapper *)
let wrapper_cmd = ref "frama-c-wtests -brief"

type env_t = {
  config: string
; dir: string
; dune_alias: string
}

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

(* removes first blanks *)
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

(** special configuration, with associated oracles *)
let config_name ~env name =
  if env.config = "" then name else name ^ "_" ^ env.config

let macro_default_options = ref "-journal-disable -check -no-autoload-plugins"
let macro_frama_c_exe = ref "frama-c"
let macro_frama_c_only = ref "@frama-c-exe@ @PTEST_DEFAULT_OPTIONS@"
let macro_frama_c_cmd = ref "@frama-c-exe@ @PTEST_DEFAULT_OPTIONS@ @PLUGIN_OPTIONS@"
let macro_frama_c = ref "@frama-c-exe@ @PTEST_DEFAULT_OPTIONS@ @PLUGIN_OPTIONS@ @PTEST_FILE@"
let macro_frama_c_share = ref "../../../../install/default/share/frama-c/share"

let default_toplevel = ref "@frama-c@ @PTEST_OPTIONS@"

(** the files in [suites] whose name matches
      the pattern [test_file_regexp] will be considered as test files *)
let test_file_regexp = ".*\\.\\(c\\|i\\)$"

let example_msg =
  Format.sprintf
    "@.@[<v 0>\
     Build the dune files allowing running the test suite contained into directories (defaults to ./tests).@ @ \
     @[<v 1>\
     Directives of the \"ptests_config\" files:@  \
     # <comment>                 @[<v 0># Just a comment line.@]@  \
     DEFAULT_SUITES = <suite>... @[<v 0># Cumulative list of subdirectories containing test suites (specified by \"test_config\" files).@]@  \
     <mode>_SUITES = <suite>...  @[<v 0># Cumulative list of subdirectories containing test suites (specified by \"test_config_<mode>\" files).@]@  \
     DUNE_ALIAS = <alias-name>   @[<v 0># The dune alias @@<alias-name> has to be used to executes the next defined suites (defaults to \"ptests\").@]@  \
     @]@ \
     @[<v 1>\
     Directives of \"test_config[_<mode>]\" files:@  \
     COMMENT: <comment>  @[<v 0># Just a comment line.@]@  \
     FILEREG: <regexp>   @[<v 0># Ignores the files in suites whose name doesn't matche the pattern.@]@  \
     DONTRUN:            @[<v 0># Ignores the file.@]@  \
     EXECNOW: ([LOG|BIN] <file>)+ <command>  @[<v 0># Defines the command to execute to build a 'LOG' (textual) 'BIN' (binary) targets.@ \
                                                    # Note: the textual targets are compared to oracles.@]@  \
     DEPS: <file>...     @[<v 0># Adds a dependency to all sub-test and execnow commands.@ \
                                # Notes: a dependency to the included file can be added with this directive.@ \
                                # That is not necessary for files mentioned into the command or options when using the %%{dep:<file>} feature of dune.@]@  \
     LOG: <file>...      @[<v 0># Defines dune targets built by the next sub-test command.@]@  \
     CMD: <command>      @[<v 0># Defines the command to execute for all tests in order to get results to be compared to oracles.@]@  \
     OPT: <options>      @[<v 0># Defines a sub-test using the 'CMD' definition: <command> <options>@]@  \
     STDOPT: +<extra>    @[<v 0># Defines a sub-test and append the extra to the current option.@]@  \
     STDOPT: #<extra>    @[<v 0># Defines a sub-test and prepend the extra to the current option.@]@  \
     PLUGIN: <plugin>... @[<v 0># Adds a dependency and set the macro @@PTEST_PLUGIN@@ defining the '-load-plugins' option used in the macro @@PLUGIN_OPTIONS@@.@]@  \
     CMXS: <module>...   @[<v 0># Defines dune targets without dependency to tests so use '-load-module %%{dep:<module>.cmxs}' into the test options.@]@  \
     MODULE: <module>... @[<v 0># Adds a dependency and adds the corresponding '-load-module' option into the macro @@PLUGIN_OPTIONS@@.@]@  \
     LIBS: <module>...   @[<v 0># Like 'MODULE' directive but for modules that can be shared between several test files.@]@  \
     EXIT: <number>      @[<v 0># Defines the exit code required for the next sub-test commands.@]@  \
     FILTER: <cmd>       @[<v 0># Performs a transformation on the test result files before the comparison from the oracles.@ \
     # The oracle will be compared from the standard output of the command: cat <test-output-file> | <cmd> .@ \
     # Chaining multiple filter commands is possible in defining several FILTER directives.@ \
     # An empty command drops the previous FILTER directives.@ \
     # Note: in such a command, the macro @@PTEST_ORACLE@@ is set to the basename of the oracle.@ \
     # This allows running a 'diff' command with the oracle of another test configuration:@ \
     #    FILTER: diff --new-file @@PTEST_DIR@@/oracle_configuration/@@PTEST_ORACLE@@ - @]@  \
     TIMEOUT: <delay>    @[<v 0># Set a timeout for all sub-test.@]@  \
     NOFRAMAC:           @[<v 0># Drops previous sub-test definitions and considers that there is no defined default sub-test.@]@  \
     GCC:                @[<v 0># Deprecated.@]@  \
     MACRO: <name> <def> @[<v 0># Set a definition to the macro @@<name>@@.@]@  \
     @]@ \
     @[<v 1>\
     Some predefined macros can be used in test directives:@  \
     @@PTEST_DIR@@             # Dirname of the test file.@  \
     @@PTEST_FILE@@            # Substituted by the test filename.@  \
     @@PTEST_NAME@@            # Basename of the test file.@  \
     @@PTEST_NUMBER@@          # Test command number.@  \
     @@PTEST_CONFIG@@          # Test configuration suffix.@  \
     @@PTEST_RESULT@@          # Shorthand alias to @@PTEST_DIR@@/result@@PTEST_CONFIG@@ (the result directory dedicated to the tested configuration).@  \
     @@PTEST_ORACLE@@          # Basename of the current oracle file (macro only usable in FILTER directives).@  \
     @@PTEST_DEFAULT_OPTIONS@@ # The default option list: %s@  \
     @@PTEST_PLUGIN@@          # The current list of plugins set by the PLUGIN directive.@  \
     @]@ \
     @[<v 1>\
     Other macros can only be used in test commands (CMD and EXECNOW directives):@  \
     @@PLUGIN_OPTIONS@@ # The current list of options related to PLUGIN, MODULE and LIBS to load.@  \
     @@PTEST_OPTIONS@@  # The current list of options related to OPT and STDOPT directives (for CMD directives).@  \
     @@frama-c-exe@@    # Shortcut defined as follow: %s@  \
     @@frama-c-only@@   # Shortcut defined as follow: %s@  \
     @@frama-c@@        # Shortcut defined as follow: %s@  \
     @@frama-c-cmd@@    # Shortcut defined as follow: %s@  \
     @@FRAMAC_SHARE@@   # Shortcut defined as follow: %s@  \
     @@DEV_NULL@@       # Set to 'NUL' for Windows platforms and to '/dev/null' otherwise.@  \
      @]@ \
     @[<v 1>\
     Default directive values:@  \
     FILEREG: %s@  \
     CMD:     %s@  \
     EXIT:    0@  \
     @]@ \
     @[<v 1>\
     Dune aliases related to the test:@  \
     @@<alias-name>                         # Tests all configurations related to the <alias-name>@  \
     @@<alias-name>_config                  # Tests only the default configuration.@  \
     @@<alias-name>_config_<configuration>  # Tests only the specified <configuration>.@  \
     @@<PTEST_NAME>.wtests                  # Tests the specified file.@  \
     @@<PTEST_NAME>.<PTEST_NUMBER>.exec.wtests     # Tests the specified sub-test comand.@  \
     @@<PTEST_NAME>.<PTEST_NUMBER>.execnow.wtests  # Tests the specified execnow command.@  \
     @@<PTEST_FILE>                         # Force to reproduce the corresponding test and prints the outputs.@  \
     @@<PTEST_NAME>.<PTEST_NUMBER>.exec.show     # Prints the related sub-test command.@  \
     @@<PTEST_NAME>.<PTEST_NUMBER>.execnow.show  # Prints the related execnow command.@  \
     @@<PTEST_NAME>.<PTEST_NUMBER>.diff          # Prints the difference from the related oracles.@  \
     Note: the <alias-name> defaults to 'ptests'. It can be specified in different ways:@  \
     - from the command line option '-dune-alias <alias-name>'@  \
     - from directives in 'ptests_config' files such as 'DUNE_ALIAS = <alias-name>'@  \
     Note: 'dune build @<alias-name>' can be restricted to a test subdirectory in using:@  \
     - 'dune build @<subdirectory>/<alias-name>'@  \
     @]@ \
     @]"
    !macro_default_options
    !macro_frama_c_exe
    !macro_frama_c_only
    !macro_frama_c
    !macro_frama_c_cmd
    !macro_frama_c_share
    test_file_regexp
    !default_toplevel

let umsg = "Usage: frama-c-ptests [options] [names of test suites]"

let default_dune_alias = ref "ptests"
let rec argspec =
  [
    ("-v", Arg.Unit (fun () -> incr verbosity),
     "Increase verbosity (up to  twice)") ;

    ("-check-oracles", Arg.Set check_oracles,
     " warn on missing or empty oracles") ;

    ("-create-missing-oracles", Arg.Set create_missing_oracles,
     " creates missing oracles to allow the use of dune promote") ;

    ("-remove-empty-oracles", Arg.Set remove_empty_oracles,
     " remove empty oracles") ;

    ("-wrapper" , Arg.String (fun s -> wrapper_cmd := s),
     " <command> Uses a wrapper to executes tests (defaults to "^ !wrapper_cmd ^")");

    ("-adds-default-options" , Arg.String (fun s -> macro_default_options := !macro_default_options ^ " " ^ s),
     " <options> Appends the <options> to the default value of the @PTEST_DEFAULT_OPTIONS@ macro");

    ("-macro-default-options" , Arg.String (fun s -> macro_default_options := s),
     " <value> Set the default value of the @PTEST_DEFAULT_OPTIONS@ macro (defaults to "^ !macro_default_options ^")");
    ("-macro-frama-c-exe", Arg.String (fun s -> macro_frama_c_exe := s),
     " <value> Set the default value of the @frama-c-exe@ macro (defaults to "^ !macro_frama_c_exe ^")");
    ("-macro-frama-c-only", Arg.String (fun s -> macro_frama_c_only := s),
     " <value> Set the default value of the @frama-c-only@ macro (defaults to "^ !macro_frama_c_only ^")");
    ("-macro-frama-c-cmd", Arg.String (fun s -> macro_frama_c_only := s),
     " <value> Set the default value of the @frama-c-cmd@ macro (defaults to "^ !macro_frama_c_cmd ^")");
    ("-macro-frama-c", Arg.String (fun s -> macro_frama_c_only := s),
     " <value> Set the @frama-c@ macro (defaults to "^ !macro_frama_c ^")");

    ("-dune-alias", Arg.String (fun s -> default_dune_alias := s),
     " <name> Use @<name> as dune alias to exectute tests (defaults to "^ !default_dune_alias ^")");
  ]
and help_msg () = Arg.usage (Arg.align argspec) umsg

let fail s =
  Format.printf "Error: %s@.Aborting (CWD=%s).@." s (Sys.getcwd());
  exit 2

module StringMap = Map.Make (String)
(* parses the [tests/ptests_config] file (prefers the one related to the expected configuration name*)
module Ptests_config: sig

  type alias = { alias : string }
  val parse: dir:string -> alias StringMap.t StringMap.t (* config_name -> suite_name -> dune_alias *)

end = struct

  type alias = { alias : string }

  (** parses the [dir/ptests_config] file  *)
  let parse =
    let split_blank = Str.split (Str.regexp "[ ]+") in
    let regexp = Str.regexp " *\\([^#=][^=]*\\)=\\(.*\\)" in
    let regexp_config = Str.regexp "\\([a-zA-Z_]+\\)_SUITES" in
    let regexp_comment = Str.regexp " *#" in
    fun ~dir ->
      let default_suites = ref StringMap.empty in
      let dune_alias = ref {alias = !default_dune_alias } in
      let ptests_config = Filename.concat dir "ptests_config" in
      let add_suite config map s =
        let add_to suites =
          Some (StringMap.update s (function | None -> Some !dune_alias
                                             | Some a ->
                                               if a.alias <> !dune_alias.alias then begin
                                                 Format.eprintf "ERROR: %s: %s_SUITES contains already %s suite (with %s as dune alias).@"
                                                   ptests_config config s !dune_alias.alias;
                                                 exit 2
                                               end;
                                               Some a) suites)
        in
        StringMap.update config (function | None -> Some (StringMap.singleton s !dune_alias)
                                          | Some suites -> add_to suites) map
      in
      let parse_config_line =
        fun (key, value) ->
          if Str.string_match regexp_config key 0 then
            let config = match Str.matched_group 1 key with
              | "DEFAULT" -> ""
              | s -> s
            in
            let l = split_blank value in
            default_suites := List.fold_left (add_suite config) !default_suites l
          else match key with
            | "DUNE_ALIAS" -> (match split_blank value with
                | [ alias ] -> dune_alias := { alias }
                | _  ->
                  Format.eprintf "ERROR: %s: %s=%s@." ptests_config key value;
                  exit 2)
            | "IGNORE" -> incr nb_ignores;
              ignored_suites := (ptests_config ^ ":" ^ value)::!ignored_suites;
              if !verbosity >=2 then Format.eprintf "%s: %s=%s@." ptests_config key value
            | _ ->  Format.eprintf "%s: setenv (DEPRECATED): %s=%s@." ptests_config key value;
      in
      if Sys.file_exists ptests_config then begin
        let ch = open_in ptests_config in
        try
          (*Parse the plugin configuration file for tests. Format is 'Key=value' *)
          while true do
            let line = input_line ch in
            if Str.string_match regexp line 0 then
              let key = Str.matched_group 1 line in
              let value = Str.matched_group 2 line in
              parse_config_line (key, value)
            else if not ((Str.string_match regexp_comment line 0) || (split_blank line = [])) then begin
              close_in ch;
              Format.eprintf "Cannot interpret line '%s' in file %s. Aborting (CWD=%s).@." line ptests_config (Sys.getcwd());
              exit 1
            end
          done
        with
        | End_of_file -> close_in ch ;
      end
      else begin
        Format.eprintf
          "Cannot find configuration file %s. Aborting (CWD=%s).@." ptests_config (Sys.getcwd()) ;
      end;
      !default_suites
end

module SubDir: sig
  type t

  val get: t -> string

  val create: with_subdir:bool -> env:env_t -> string (** dirname *) -> t
  (** creates the needed subdirectories if [with_subdir=true].
      Anyway, fails if the given dirname doesn't exists *)

  val make_file: t -> string -> string
  val make_subdir: t -> string -> t

  val oracle_subdir: env:env_t -> t -> t
  val result_subdir: env:env_t -> t -> t
  val upper_dir: t

  val pp_file: dir:t -> Format.formatter -> string -> unit
end = struct
  type t = string

  let get s = s

  let create_if_absent dir =
    if not (Sys.file_exists dir)
    then Unix.mkdir dir 0o750 (* rwxr-w--- *)
    else if not (Sys.is_directory dir)
    then fail (Printf.sprintf "the file %s exists but is not a directory" dir)

  let oracle_subdir ~env dir = Filename.concat dir (config_name ~env "oracle")
  let result_subdir ~env dir = Filename.concat dir (config_name ~env "result")

  let make_file = Filename.concat
  let make_subdir = Filename.concat
  let upper_dir = ".."

  let create ~with_subdir ~env dir =
    if not (Sys.file_exists dir && Sys.is_directory dir)
    then fail (Printf.sprintf "the directory %s must be an existing directory" dir);
    if (with_subdir) then begin
      create_if_absent (result_subdir ~env dir);
      create_if_absent (oracle_subdir ~env dir)
    end;
    dir

  let pp_file ~dir fmt s = Format.fprintf fmt "%s/%s" dir s
end

let dev_null = if Sys.os_type = "Win32" then "NUL" else "/dev/null"

module Macros = struct

  type t = string StringMap.t

  let empty = StringMap.empty

  let macro_regex = Str.regexp "\\([^@]*\\)@\\([^@]*\\)@\\(.*\\)"

  let pp_macros fmt macros =
    Format.fprintf fmt "Macros (%d):@."  (StringMap.cardinal macros);
    StringMap.iter (fun key data -> Format.fprintf fmt "- %s -> %s@." key data) macros;
    Format.fprintf fmt "End macros@."

  let does_expand macros s =
    if !verbosity >=5 then begin
      Format.printf "%%     - Looking for macros in string %s@. Existing %a@." s pp_macros macros;
    end;
    let nb_loops = ref 0 in
    let rec aux n (ptest_file_matched,s as acc) =
      incr nb_loops ;
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
              if !verbosity >= 5 then Format.printf "%%     - macro is %s@." macro;
              let replacement =  StringMap.find macro macros in
              if !verbosity >= 4 then
                Format.printf "%%     - replacement for %s is %s@." macro replacement;
              if !nb_loops > 100 then fail "Possible infinite recursivity in macro expands" ;
              new_n,
              String.sub s 0 n ^ start ^ replacement ^ rest
            with
            | Not_found -> Str.group_end 2 + 1, s
          end
        in
        if !verbosity >= 5 then Format.printf "%%    - New string is %s@." new_s;
        let new_acc = ptest_file_matched, new_s in
        if n <= String.length new_s then aux n new_acc else new_acc
      end else acc
    in
    try
      aux 0 (false,s)
    with e ->
      Format.eprintf "Uncaught exception %s@." (Printexc.to_string e);
      raise e

  let expand (macros:t) s =
    snd (does_expand macros s)

  let get ?(default="") name macros =
    try StringMap.find name macros with Not_found -> default

  let add_list l map =
    List.fold_left (fun acc (k,v) -> StringMap.add k v acc) map l

  let add_expand name def macros =
    StringMap.add name (expand macros def) macros

  let append_expand name def macros =
    StringMap.add name (get name macros ^ expand macros def) macros

  let default_macros = add_list
    [ "PTEST_PLUGIN", "" ;
      "PTEST_DEFAULT_OPTIONS", !macro_default_options;
      "frama-c-exe", !macro_frama_c_exe;
      "frama-c-only", !macro_frama_c_only;
      "frama-c-cmd", !macro_frama_c_cmd;
      "frama-c",     !macro_frama_c;
      "FRAMAC_SHARE",!macro_frama_c_share;
      "DEV_NULL",    dev_null;
    ] empty

end

module StringSet = Set.Make(String)
type deps =  {
  load_plugin: string list;
  load_module: string list;
  deps_cmd: string list;
}

type execnow =
  { ex_cmd: string;      (** command to launch *)
    ex_log: string list; (** log files *)
    ex_bin: string list; (** bin files *)
    ex_dir: SubDir.t;    (** directory of test suite *)
    ex_timeout: string;
    ex_deps: deps
  }


(** configuration of a directory/test. *)
type cmd = {
  toplevel: string;
  opts: string;
  macros: Macros.t;
  exit_code: string option;
  logs: string list;
  deps: deps;
  timeout: string
}

type config =
  {
    dc_subdir: SubDir.t ;
    dc_test_regexp: string; (** regexp of test files. *)
    dc_execnow    : execnow list; (** command to be launched before
                                       the toplevel(s)
                                  *)
    dc_libs : string list; (** libraries to compile *)
    dc_cmxs : string list; (** cmxs to compile *)
    dc_deps : string list; (** deps *)
    dc_plugin : string list; (** only plugins to load *)
    dc_module : string list; (** module to load *)
    dc_plugin_all : string list; (** all used plugins *)
    dc_macros: Macros.t; (** existing macros. *)
    dc_default_toplevel   : string;
    (** full path of the default toplevel. *)
    dc_filter     : string option; (** optional filter to apply to
                                       standard output *)
    dc_exit_code  : string option; (** required exit code *)
    dc_commands   : cmd list;
    (** toplevel full path, options to launch the toplevel on, and list
        of output files to monitor beyond stdout and stderr. *)
    dc_dont_run   : bool;
    dc_framac     : bool;
    dc_default_log: string list;
    dc_timeout: string
  }

(* Scans the test directives (from test_config or test files) and expands macros as soon as possible *)
module Test_config: sig

  (** The [test_config] filename related to the expected configuration name *)
  val filename: string
  val current_config: env:env_t -> SubDir.t -> config

  val scan_directives:  drop:bool ->
    SubDir.t -> file:string -> Scanf.Scanning.in_channel -> config -> config
  val scan_test_file: env:env_t -> SubDir.t -> file:string -> config -> config

  (* updates the configuration directives that do not depend of the test number and
     returns a getter of the PTEST_xxx variables including the one depending on the test number *)
  val ptest_vars: env:env_t -> SubDir.t -> file:string -> config -> string * config * (nth:int -> Macros.t -> Macros.t)

end = struct

  let ptest_vars ~env directory ~file config =
    let ptest_config = config_name ~env "" in
    let ptest_file = Filename.sanitize file in
    let ptest_name = Filename.remove_extension file in
    let ptest_vars =
        [ "PTEST_CONFIG", ptest_config;
          "PTEST_DIR", SubDir.get directory;
          "PTEST_RESULT", SubDir.get (SubDir.result_subdir ~env directory);
          "PTEST_FILE", ptest_file;
          "PTEST_NAME", ptest_name;
        ] in
    let subst = Macros.expand (Macros.add_list ptest_vars Macros.empty) in
    ptest_name,
    { config with
      dc_execnow = List.rev config.dc_execnow;
      dc_cmxs = List.map subst config.dc_cmxs;
      dc_deps = List.map subst config.dc_deps;
      dc_plugin = List.map subst config.dc_plugin;
      dc_plugin_all = StringSet.elements (StringSet.of_list  (List.map subst config.dc_plugin_all));
      dc_module = List.map subst config.dc_module;
      dc_libs = List.map subst config.dc_libs;
    },
    fun ~nth macros ->
      Macros.add_list (("PTEST_NUMBER", string_of_int nth)::ptest_vars) macros

  (** the name of the directory-wide configuration file*)
  let filename = "test_config"

  let default_commands config =
    [ { toplevel=config.dc_default_toplevel;
        opts="";
        exit_code=None;
        macros=config.dc_macros;
        logs=[];
        deps={ load_plugin=[];
               load_module=[];
               deps_cmd=[];
             };
        timeout=""
      } ]

  let default_config dir =
    { dc_subdir = dir;
      dc_test_regexp = test_file_regexp;
      dc_macros = Macros.default_macros;
      dc_execnow = [];
      dc_libs = [];
      dc_cmxs = [];
      dc_deps = [];
      dc_plugin = [];
      dc_plugin_all = [];
      dc_module = [];
      dc_filter = None ;
      dc_exit_code = None;
      dc_default_toplevel = !default_toplevel;
      dc_commands = [];
      dc_dont_run = false;
      dc_framac = true;
      dc_default_log = [];
      dc_timeout = "";
    }

  let scan_execnow ~file ~once dir ex_timeout ex_deps (s:string) =
    if once=false then
      Format.eprintf "%s: using EXEC directive (DEPRECATED): %s@."
        file s;
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
             (* It should be better to use a specific macro into the command (such as @MAKE@) for that. *)
             Format.eprintf "%s: EXEC%s directive with a make command (DEPRECATED): %s@."
               file (if once then "NOW" else "") cmd;
             let s = aux ({ s with ex_cmd = cmd; }) in
             { s with ex_cmd = "make "^cmd; } )
      with Scanf.Scan_failure _ ->
        s
    in
    let execnow = aux
        { ex_cmd = s;
          ex_log = [];
          ex_bin = [];
          ex_dir = dir;
          ex_deps;
          ex_timeout;
        }
    in
    if execnow.ex_log = [] && execnow.ex_bin = [] then
      Format.eprintf "%s: EXEC%s without LOG nor BIN target (DEPRECATED): %s@."
        file (if once then "NOW" else "") s;
    execnow

  let make_custom_opts =
    let space = Str.regexp " " in
    fun ~file ~dir stdopts s ->
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
            Format.eprintf "%a: unknown STDOPT configuration string: %s@."
              (SubDir.pp_file ~dir) file s;
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

  let deps_of_config ?(deps={load_module=[];load_plugin=[];deps_cmd=[]}) config =
    { load_module = deps.load_module @ config.dc_module;
      load_plugin = deps.load_plugin @ config.dc_plugin;
      deps_cmd = deps.deps_cmd @ config.dc_deps
    }

  let config_exec ~once ~drop:_ ~file ~dir s current =
    let s = Macros.expand current.dc_macros s in
    { current with
      dc_execnow =
        scan_execnow ~file ~once dir current.dc_timeout (deps_of_config current) s :: current.dc_execnow }

  let split_list =
    (* considers blanks (not preceded by '\'), tabs and commas as separators *)
    let nonsep_regexp = Str.regexp "[\\] " in (* removed for beeing reintroduced *)
    let sep_regexp = Str.regexp "[\t ,]+" in
    fun s -> (* splits on '\ ' first then on ' ' or ',' *)
      let r = List.fold_left (fun acc -> function
          | Str.Text s -> List.rev_append (Str.full_split sep_regexp s) acc
          | (Str.Delim _ as delim) -> delim::acc)
          []
          (Str.full_split nonsep_regexp s)
      in (* [r] is in the reverse order and the next [fold] restores the order *)
      let add s (glue,prev,curr) =
        if glue then false,(s^prev),curr
        else false,s,(if prev = "" then curr else prev::curr)
      in
      let acc = List.fold_left (fun ((_,prev,curr) as acc) -> function
          | Str.Delim ("\\ " as nonsep) -> true,(nonsep^prev),curr (* restore '\ ' *)
          | Str.Delim _ -> add "" acc (* separator *)
          | Str.Text s -> add s acc) (false,"",[]) r
      in
      let _,_,res = (add "" acc) in
      res

  let config_deps ~drop:_ ~file:_ ~dir:_ s current =
    let s = Macros.expand current.dc_macros s in
    { current with dc_deps = (split_list s) @ current.dc_deps }

  let config_cmxs ~drop:_ ~file:_ ~dir:_ s current =
    let s = Macros.expand current.dc_macros s in
    let l = List.map (fun s -> Filename.remove_extension s) (split_list s) in
    { current with dc_cmxs = l @ current.dc_cmxs }

  let config_libs ~drop:_ ~file:_ ~dir:_ s current =
    let s = Macros.expand current.dc_macros s in
    let l = List.map (fun s -> Filename.remove_extension s) (split_list s) in
    { current with dc_libs = l @ current.dc_libs }

  let config_plugin ~drop:_ ~file:_ ~dir:_ s current =
    let s = Macros.expand current.dc_macros s in
    let deps = split_list s in
    { current with dc_plugin = deps ;
                   dc_plugin_all = deps @ current.dc_plugin_all;
                   dc_macros = Macros.add_list ["PTEST_PLUGIN", s] current.dc_macros }

  let config_module ~drop:_ ~file:_ ~dir:_ s current =
    let s = Macros.expand current.dc_macros s in
    let l = List.map (fun s -> Filename.remove_extension s) (split_list s) in
    let deps = List.map (fun s -> s ^ ".cmxs") l in
    { current with
      dc_cmxs = l @ current.dc_cmxs;
      dc_module = deps;
      dc_macros = Macros.add_list ["PTEST_MODULE", s] current.dc_macros }

  let config_macro ~drop:_ ~file ~dir s current =
    (* note: the expansion is donly done into the definition *)
    let regex = Str.regexp "[ \t]*\\([^ \t@]+\\)\\([ \t]+\\(.*\\)\\|$\\)" in
    if Str.string_match regex s 0 then begin
      let name = Str.matched_group 1 s in
      let def =
        try Str.matched_group 3 s with Not_found -> (* empty text *) ""
      in
      if !verbosity >= 4 then
        Format.printf "%%   - New macro %s with definition %s@." name def;
      { current with dc_macros = Macros.add_expand name def current.dc_macros }
    end else begin
      Format.eprintf "%a: cannot understand MACRO definition: %s@." (SubDir.pp_file ~dir) file s;
      current
    end

  type parsing_env = {
    current_default_toplevel: string;
    current_default_log: string list;
    current_default_cmds: cmd list;
  }

  let default_parsing_env = ref {
      current_default_toplevel = "" ;
      current_default_log = [] ;
      current_default_cmds = []
    }

  let set_default_parsing_env config =
    default_parsing_env := {
      current_default_toplevel = config.dc_default_toplevel;
      current_default_log = config.dc_default_log;
      current_default_cmds = List.rev config.dc_commands;
    }

  let config_options =
    [ "CMD",
      (fun ~drop:_ ~file:_ ~dir:_ s current ->
         let s = Macros.expand current.dc_macros s in
         { current with dc_default_toplevel = s});

      "OPT",
      (fun ~drop ~file ~dir:_ s current ->
         if not (drop || current.dc_framac) then
           Format.eprintf "%s: a NOFRAMAC directive has been defined before a sub-test defined by an 'OPT' directive (That NOFRAMAC directive could be misleading.).@."
             file;
         let s = Macros.expand current.dc_macros s in
         let t =
           { toplevel = current.dc_default_toplevel;
             opts = s;
             macros = current.dc_macros ;
             exit_code = current.dc_exit_code ;
             logs = current.dc_default_log;
             timeout = current.dc_timeout;
             deps = deps_of_config current
           }
         in
         { current with
           dc_default_log = !default_parsing_env.current_default_log;
           dc_commands = t :: current.dc_commands });

      "STDOPT",
      (fun ~drop ~file ~dir s current ->
         if not (drop || current.dc_framac) then
           Format.eprintf "%s: a NOFRAMAC directive has been defined before a sub-test defined by a 'STDOPT' directive (That NOFRAMAC directive could be misleading.).@."
             file;
         let s = Macros.expand current.dc_macros s in
         let new_top =
           List.map
             (fun command ->
                { toplevel= current.dc_default_toplevel;
                  opts= make_custom_opts ~file ~dir command.opts s;
                  macros= current.dc_macros;
                  exit_code = current.dc_exit_code;
                  logs= command.logs @ current.dc_default_log;
                  timeout= current.dc_timeout;
                  deps = deps_of_config ~deps:command.deps current
                })
             (if !default_parsing_env.current_default_cmds = [] then
               default_commands current
             else !default_parsing_env.current_default_cmds)
         in
         { current with dc_commands = new_top @ current.dc_commands;
                        dc_default_log = !default_parsing_env.current_default_log @
                                         current.dc_default_log });
      "FILEREG",
      (fun ~drop:_ ~file:_ ~dir:_ s current ->
         let s = Macros.expand current.dc_macros s in
         { current with dc_test_regexp = s });

      "FILTER",
      (fun ~drop:_ ~file:_ ~dir:_ s current ->
         let s = Macros.expand current.dc_macros s in
         let s = trim_right s in
         match current.dc_filter with
         | None when s="" -> { current with dc_filter = None }
         | None           -> { current with dc_filter = Some s }
         | Some filter    -> { current with dc_filter = Some (s ^ " | " ^ filter) });

      "EXIT",
      (fun ~drop:_ ~file:_ ~dir:_ s current ->
         let s = Macros.expand current.dc_macros s in
         { current with dc_exit_code = Some s });

      "GCC",
      (fun ~drop:_ ~file ~dir:_ _ acc ->
         Format.eprintf "%s: GCC directive (DEPRECATED)@." file;
         acc);

      "COMMENT",
      (fun ~drop:_ ~file:_ ~dir:_ _ acc -> acc);

      "DONTRUN",
      (fun ~drop:_ ~file:_ ~dir:_ _ current ->
         { current with dc_dont_run = true });

      "EXECNOW", config_exec ~once:true;
      "EXEC", config_exec ~once:false;

      "MACRO", config_macro;
      "CMXS", config_cmxs;
      "LIBS", config_libs;
      "DEPS", config_deps;
      "MODULE", config_module;
      "PLUGIN", config_plugin;

      "LOG",
      (fun ~drop:_ ~file:_ ~dir:_ s current ->
         let s = Macros.expand current.dc_macros s in
         { current with dc_default_log = s :: current.dc_default_log });

      "TIMEOUT",
      (fun ~drop:_ ~file:_ ~dir:_ s current ->
         let s = Macros.expand current.dc_macros s in
         { current with dc_timeout = s });

      "NOFRAMAC",
      (fun ~drop ~file ~dir:_ _ current ->
         if not drop && current.dc_commands <> [] && current.dc_framac then
           Format.eprintf "%s: a NOFRAMAC directive has the effect of ignoring previous defined sub-tests (by some 'OPT' or 'STDOPT' directives that seems misleading). @."
             file;
         { current with dc_commands = []; dc_framac = false; });
    ]

  let scan_directives ~drop dir ~file scan_buffer default =
    set_default_parsing_env default;
    let r = ref { default with dc_commands = [] } in
    let treat_line s =
      try
        Scanf.sscanf s "%[ *]%[A-Za-z0-9]: %s@\n"
          (fun _ name opt ->
             try
               r := (List.assoc name config_options) ~drop ~file ~dir opt !r
             with Not_found ->
               Format.eprintf "@[%s: unknown configuration option: %s@.@]" file name)
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

  (* test for a possible toplevel configuration. *)
  let current_config ~env dir =
    let default_config = default_config dir in
    let general_config_file = SubDir.make_file dir (config_name ~env filename) in
    if Sys.file_exists general_config_file
    then begin
      if !verbosity >=2 then Format.printf "%% Parsing global config file=%s@." general_config_file;
      let scan_buffer = Scanf.Scanning.from_file general_config_file in
      scan_directives ~drop:false
        (SubDir.create ~env ~with_subdir:false Filename.current_dir_name)
        ~file:general_config_file
        scan_buffer
        default_config
    end
    else begin
      if !verbosity >=2 then Format.printf "%% There is no global config file=%s@." general_config_file;
      default_config
    end

  let split_config s = Str.split (Str.regexp ",[ ]*") s

  let is_config name =
    let prefix = "run.config" in
    let len = String.length prefix in
    String.length name >= len && String.sub name 0 len = prefix

  let scan_test_file ~env dir ~file default =
    let f = SubDir.make_file dir file in
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
               name = "run.config" && env.config = ""  ||
               name = "run.config_" ^ env.config
             in
             let configs = split_config (String.trim names) in
             if List.exists is_current_config configs then
               (* Found options for current config! *)
               scan_directives ~drop:false dir ~file:f scan_buffer default
             else (* config name does not match: eat config and continue.
                     But only if the comment is still opened by the end of
                     the line and we are indeed reading a config
                  *)
               (if List.exists is_config configs &&
                   not (Str.string_match end_comment names 0) then
                  ignore (scan_directives ~drop:true dir ~file:f scan_buffer default);
                scan_config ()))
      in
      let config =
        try
          let options =  scan_config () in
          Scanf.Scanning.close_in scan_buffer;
          options
        with End_of_file | Scanf.Scan_failure _ ->
          Scanf.Scanning.close_in scan_buffer;
          default
      in
      if config.dc_commands = [] && config.dc_framac
      then { config with dc_commands = default_commands config }
      else config
    end else
      (* if the file has disappeared, don't try to run it... *)
      { default with dc_dont_run = true }

end

type toplevel_command =
  { macros: Macros.t;
    log_files: string list;
    test_name : string ;
    file : string ;
    nb_files : int ;
    options : string ;
    toplevel: string ;
    filter : string option ;
    exit_code : int ;
    directory : SubDir.t ;
    nth : int;
    execnow:bool;
    timeout: string;
    deps: deps;
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

let make_result_file ~env:_ x = x
let make_oracle_file ~env x = Filename.concat (config_name ~env "oracle") x

let gen_prefix gen_file cmd =
  let prefix = gen_file (name_without_extension cmd) in
  catenate_number cmd.nb_files prefix cmd.nth
let oracle_prefix ~env = gen_prefix (make_oracle_file ~env)
let log_prefix ~env = gen_prefix (make_result_file ~env)


let basic_command_string command =
  let plugins_options =
    let opt_plugin = if command.deps.load_plugin = [] then ""
      else Printf.sprintf "-load-plugin=%s" (String.concat "," command.deps.load_plugin) in
    let opt_modules = if command.deps.load_module = [] then ""
      else Printf.sprintf "-load-module=%s" (String.concat "," command.deps.load_module) in
    String.concat " " [opt_plugin;opt_modules]
  in
  let macros = (* set expanded macros that can be used into CMD directives *)
    Macros.add_list [
      "PTEST_OPTIONS", Macros.expand command.macros command.options;
      "PLUGIN_OPTIONS", plugins_options;
    ] command.macros in
  let raw_command = Macros.expand macros command.toplevel in
  if command.timeout = "" then raw_command
  else "ulimit -t " ^ command.timeout ^ " && " ^ raw_command

let print_list fmt l = List.iter (Format.fprintf fmt " %S") l
module Fmt = struct
  let plugin_as_package fmt s = Format.fprintf fmt "frama-c-%s" s
  let quote pr fmt s = Format.fprintf fmt "%S" (Format.asprintf "%a" pr s)
  let list pr fmt l = List.iter (fun s -> Format.fprintf fmt " %a" pr s) l
  let var_libavailable pr fmt s = Format.fprintf fmt "%%{lib-available:%a}" pr s
  let package_as_deps pr fmt s = Format.fprintf fmt "(package %a)" pr s
end

let show_cmd =
  let regexp = Str.regexp "%{[a-z]+:\\([^}]+\\)}" in
  let subst = Str.global_replace regexp "\\1" in
  subst

let redirection ?reslog ?errlog cmd =
    match reslog, errlog with
    | None, None         -> cmd
    | None, Some err     -> Format.sprintf "%s 2> %s" cmd err
    | Some res, None     -> Format.sprintf "%s > %s" cmd res
    | Some res, Some err -> Format.sprintf "%s > %s 2> %s" cmd res err

let ptests_alias ~env = config_name ~env (env.dune_alias ^ "_config")

let mk_alias cmd suffix = Format.sprintf "%s.%d.%s" cmd.test_name cmd.nth suffix

type wtest = {
  dir: (string [@default ""]); (* information on the test directory *)
  info: (string [@default ""]); (* information *)
  cmd: (string [@default "echo unknown command"]);
  ret_code: (int [@default 0]);
  out: (string [@default "" (* bin target built by the command *) ]); (* sdtout target *)
  err: (string [@default "" (* bin target built by the command *) ]); (* stderr target *)
  tmpout: (string [@default ""]); (* temporary file to filter stdout result *)
  tmperr: (string [@default ""]); (* temporary file to filter stderr result *)
  sedout: (string [@default ""]); (* filter command for the stdout result *)
  sederr: (string [@default ""]); (* filter command for the stderr result *)
  bin: (string list [@default []]); (* binary targets (without oracles) *)
  log: (string list [@default []]); (* log targets (compared to log oracles *)
  oracle_dir: (string [@default "../oracle"]); (* directory containing the oracle of the log files *)
  oracle_out: (string [@default "" ]); (* oracle of the stdout target *)
  oracle_err: (string [@default "" ]); (* oracle of the stderr target *)
}
[@@deriving yojson]

let std = false
let pp_wtest ?(compacted=false) fmt wtest =
  let writer = (if compacted
        then (fun json -> Format.fprintf fmt "%s" (Yojson.Safe.to_string ~std json))
        else (fun json -> Format.fprintf fmt "%a" (Yojson.Safe.pretty_print ~std) json))
  in writer (wtest_to_yojson wtest)

let default_wtest = match wtest_of_yojson (Yojson.Safe.from_string "{}") with
  | Ok r -> r
  | _ -> assert false

let print_json_wrapper ~file wtest =
  (* Prints the JSON file for the wrapper *)
  if !verbosity >= 2 then Format.printf "%% Generates %S wrapper file...@." file;
  let wrapper_cout = open_out file in
  let wrapper_fmt = Format.formatter_of_out_channel wrapper_cout  in
  Format.fprintf wrapper_fmt "%a@" (pp_wtest ~compacted:false) wtest;
  close_out wrapper_cout

let oracle_target oracle_fmt dir fname =
  let oracle = SubDir.make_file dir fname in
  if not (Sys.file_exists oracle) then begin
    if !create_missing_oracles then begin
      let code = Sys.command ("touch " ^ oracle) in
      if code <> 0 then
        Format.printf "  - cannot create missing oracle: %s@." oracle
      else
        Format.printf "  - creates missing oracle: %s@." oracle;
    end
    else if !check_oracles then
      Format.printf "  - missing oracle: %s@." oracle;
  end
  else if is_file_empty_or_nonexisting oracle then begin
    if !remove_empty_oracles then begin
      Format.printf "  - removes empty oracle: %s@." oracle;
      unlink ~silent:false oracle
    end
    else if !check_oracles then
      Format.printf "  - empty oracle: %s@." oracle;
  end;
  Format.fprintf oracle_fmt
    "(rule (target %S) (mode fallback) (action (write-file %S \"\")))\n" fname fname

let command_string ~env ~result_fmt ~oracle_fmt command =
  let log_prefix = log_prefix ~env command in
  let reslog = log_prefix ^ ".res.log" in
  let errlog = log_prefix ^ ".err.log" in
  let cmdreslog,cmderrlog = match command.filter with
    | None -> reslog,errlog
    | Some _ -> (log_prefix ^ ".res.unfiltered-log"),(log_prefix ^ ".err.unfiltered-log")
  in
  let deps = command.deps in
  let accepted_exit_code = Format.sprintf "with-accepted-exit-codes %d" command.exit_code in
  let command_string = basic_command_string command in
  let filter_res,filter_err,wtest =
    match command.filter with
    | None -> "","",default_wtest
    | Some filter ->
      let regexp = Str.regexp "@PTEST_ORACLE@" in
      let filter_cmd funfiltred foracle =
        let filter = Str.global_replace regexp foracle filter in
        Format.sprintf "cat %s | %s" funfiltred filter
      in
      let filter_res = filter_cmd cmdreslog (log_prefix ^ ".res.oracle") in
      let filter_err = filter_cmd cmderrlog (log_prefix ^ ".err.oracle") in
      filter_res,filter_err, { default_wtest with
                               sedout = redirection ~reslog filter_res ;
                               sederr = redirection ~reslog:errlog filter_err ;
                               tmpout = cmdreslog ;
                               tmperr = cmderrlog ;
                             }
  in
  let oracle_prefix = oracle_prefix ~env command in
  let wtest =
    { wtest with
      dir = SubDir.get (SubDir.result_subdir ~env command.directory) ;
      info = Format.sprintf "TEST #%d OF TEST FILE %s/%s"
          command.nth (SubDir.get command.directory) command.file;
      cmd = redirection ~reslog:cmdreslog ~errlog:cmderrlog command_string ;
      out = reslog;
      err = errlog;
      ret_code = command.exit_code;
      log = command.log_files;
      oracle_out = Filename.concat ".." (oracle_prefix ^ ".res.oracle");
      oracle_err = Filename.concat ".." (oracle_prefix ^ ".err.oracle");
    }
  in
  let wtest = if wtest.log = [] then wtest else
    { wtest with
      oracle_dir = SubDir.get (SubDir.oracle_subdir ~env SubDir.upper_dir)
    }
  in
  let wrapper_basename =  mk_alias command "exec.wtests" in
  if !wrapper_cmd <> "" then begin
    Format.fprintf result_fmt
      "(rule ; %s\n  \
       (alias %S)\n  \
       (targets %S %S %a)\n  \
       (deps %S %S %a %a %S (package frama-c)%a)\n  \
       (action (run %s %%{dep:%s} %S %a))\n\
       )@."
      (* rules: *)
      wtest.info
      (* alias *)
      wrapper_basename
      (* targets: *)
      cmderrlog
      cmdreslog
      print_list command.log_files
      (* deps: *)
      wtest.oracle_out
      wtest.oracle_err
      print_list (List.map (Filename.concat wtest.oracle_dir) command.log_files)
      print_list deps.deps_cmd
      command.file
      Fmt.(list (package_as_deps (quote plugin_as_package))) command.deps.load_plugin
      (* action: *)
      !wrapper_cmd
      wrapper_basename
      wtest.cmd
      print_list (if command.filter = None then [] else [wtest.sedout ; wtest.sederr]);

    let wtest =
      { wtest with
        cmd = show_cmd wtest.cmd ;
        sedout = show_cmd wtest.sedout ;
        sederr = show_cmd wtest.sederr
      }
    in
    (* Prints the JSON file for the wrapper *)
    print_json_wrapper wtest
      ~file:(SubDir.make_file (SubDir.result_subdir ~env command.directory) wrapper_basename);
  end
  else begin
    Format.fprintf result_fmt
      "(rule ; %s\n  \
       (alias %S)\n  \
       (targets %S %S %a)\n  \
       (deps   %a %S (package frama-c)%a)\n  \
       (action (with-stderr-to %S (with-stdout-to %S (%s (system %S)))))\n\
       )@."
      (* rules: *)
      wtest.info
      (* alias *)
      wrapper_basename
      (* targets: *)
      cmderrlog
      cmdreslog
      print_list command.log_files
      (* deps: *)
      print_list deps.deps_cmd
      command.file
      Fmt.(list (package_as_deps (quote plugin_as_package))) command.deps.load_plugin
      (* action: *)
      cmderrlog
      cmdreslog
      accepted_exit_code
      command_string
  end;
  let filter_rule txt fin fout cmd =
    if cmd <> "" then
      Format.fprintf result_fmt
        "(rule ; FILTER %s #%d OF TEST FILE %S\n  \
         (deps %S)
         (action (with-stdout-to %S (with-accepted-exit-codes (or 0 1 2 125) (system %S))))\n\
         )@."
        txt
        command.nth
        command.file
        (* deps *)
        fin
        (*action *)
        fout cmd
  in
  filter_rule "RES" cmdreslog reslog filter_res ;
  filter_rule "ERR" cmderrlog errlog filter_err ;
  List.iteri (fun n log ->
      Format.fprintf result_fmt
        "(rule ; COMPARE TARGET #%d OF TEST #%d FOR TEST FILE %S\n  \
         (alias %s)\n  \
         (action (diff %S %S))\n\
         )@."
        n command.nth command.file
        (ptests_alias ~env)
        (SubDir.make_file (SubDir.oracle_subdir ~env SubDir.upper_dir) log)
        log
    ) command.log_files;
  Format.fprintf result_fmt
    "(rule ; REPRODUCE TEST #%d OF TEST FILE %S\n  \
     (alias %S)\n  \
     (deps  %a %S (package frama-c)%a (universe))\n  \
     (action (%s (system %S)))\n\
     )@."
    command.nth command.file
    (mk_alias command "exec")
    print_list deps.deps_cmd
    command.file
    Fmt.(list (package_as_deps (quote plugin_as_package))) command.deps.load_plugin
    accepted_exit_code
    command_string
  ;
  Format.fprintf result_fmt
    "(rule ; SHOW TEST COMMAND #%d OF TEST FILE %S\n  \
     (alias %S)\n  \
     (deps  %a %S (package frama-c)%a (universe))\n  \
     (action (system %S))\n\
     )@."
    command.nth command.file
    (mk_alias command "exec.show")
    print_list deps.deps_cmd
    command.file
    Fmt.(list (package_as_deps (quote plugin_as_package))) command.deps.load_plugin
    ("echo '" ^ show_cmd wtest.cmd ^"'");

  let diff_alias = log_prefix ^ ".diff" in
  (* diff with oracles *)
  Format.fprintf result_fmt
    "(rule\n  \
     (alias %S)\n  \
     (action (diff %S %S))\n\
     )@."
    diff_alias
    wtest.oracle_out
    reslog;
  Format.fprintf result_fmt
    "(rule\n  \
     (alias %S)\n  \
     (action (diff %S %S))\n\
     )@."
    diff_alias
    wtest.oracle_err
    errlog;
  Format.fprintf result_fmt
    "(alias (deps (alias %S)) (name %S); (enabled_if (and true %a))\n\
     )@."
    diff_alias
    (ptests_alias ~env)
    Fmt.(list (var_libavailable plugin_as_package )) command.deps.load_plugin
  ;
  let oracle_subdir = SubDir.oracle_subdir ~env command.directory in
  oracle_target oracle_fmt oracle_subdir (Filename.basename (oracle_prefix ^ ".err.oracle"));
  oracle_target oracle_fmt oracle_subdir (Filename.basename (oracle_prefix ^ ".res.oracle"));
  List.iter (oracle_target oracle_fmt oracle_subdir) command.log_files ;
  ()

(** process a test file *)
let dispatcher ~env ~result_fmt ~oracle_fmt file directory config =
  let config = Test_config.scan_test_file ~env directory ~file config in
  if not config.dc_dont_run then
    let test_name,config,ptest_vars = Test_config.ptest_vars ~env directory ~file config  in
    let dc_libs = List.map (fun s -> s^".cmxs") config.dc_libs in
    let deps_command macros deps =
      let subst = Macros.expand macros in
      { load_plugin = List.map subst deps.load_plugin;
        load_module = List.map subst (dc_libs @ deps.load_module);
        deps_cmd = List.map subst (dc_libs @ deps.load_module @ deps.deps_cmd);
      };
    in
    let nb_files = List.length config.dc_commands in
    let make_cmd =
      let i = ref 0 in
      fun { toplevel; opts=options; macros; exit_code; logs; timeout; deps } ->
        let nth = !i in
        incr i ;
        let macros = ptest_vars ~nth macros in
        let log_files = List.map (Macros.expand macros) logs in
        command_string ~env ~result_fmt ~oracle_fmt
          { test_name ; file; options; toplevel; nb_files; directory; nth; timeout;
            macros; log_files;
            filter = (* from a global directive applyed to all OPT tests  *)
              (match config.dc_filter with None -> None | Some s -> Some (Macros.expand macros s));
            exit_code = begin
              match exit_code with
              | None -> 0
              | Some exit_code ->
                try int_of_string exit_code with
                | _ -> Format.eprintf "@[%s: integer required for directive EXIT: %s (defaults to 0)@]@." file exit_code ; 0
            end;
            execnow=false;
            deps = deps_command macros deps;
          }
    in
    let nb_files_execnow = List.length config.dc_execnow in
    let make_execnow_cmd =
      let e = ref 0 in
      fun execnow->
       let nth = !e in
       incr e ;
       let macros = ptest_vars ~nth Macros.empty in
       let cmd =
         { test_name; file; nb_files = nb_files_execnow; directory; nth;
           log_files = [];
           options = "";
           toplevel = execnow.ex_cmd;
           exit_code = 0;
           timeout=execnow.ex_timeout;
           macros;
           filter = None; (* no FILTER applied to EXECNOW LOG *)
           execnow = true;
           deps = deps_command macros execnow.ex_deps;
         }
       in
       let wtest = {
         default_wtest with
         dir = SubDir.get (SubDir.result_subdir ~env cmd.directory) ;
         info = Format.sprintf "EXECNOW #%d OF TEST FILE %s/%s"
             nth (SubDir.get directory) file;
         cmd = basic_command_string cmd;
         log = List.map (Macros.expand cmd.macros) execnow.ex_log;
         bin = List.map (Macros.expand cmd.macros) execnow.ex_bin;
       }
       in
       let wrapper_basename =  mk_alias cmd "execnow.wtests" in
       if !wrapper_cmd <> "" then begin
         Format.fprintf result_fmt
           "(rule ; %s\n  \
            (alias %s)\n  \
            (deps %a %a %a (package frama-c)%a)\n  \
            (targets %a %a)\n  \
            (action (run %s %%{dep:%s} %S))\n\
            )@."
           (* rules: *)
           wtest.info
           (* alias *)
           wrapper_basename
           (* deps: *)
           print_list (List.map (Filename.concat wtest.oracle_dir) wtest.log)
           print_list (List.map (Filename.concat wtest.oracle_dir) wtest.bin)
           print_list cmd.deps.deps_cmd
           Fmt.(list (package_as_deps (quote plugin_as_package))) cmd.deps.load_plugin
           (* targets: *)
           print_list wtest.log
           print_list wtest.bin
           (* action: *)
           !wrapper_cmd
           wrapper_basename
           wtest.cmd;
         let wtest =
           { wtest with
             cmd = show_cmd wtest.cmd ;
           }
         in
         (* Prints the JSON file for the wrapper *)
         print_json_wrapper wtest
           ~file:(SubDir.make_file (SubDir.result_subdir ~env cmd.directory) wrapper_basename);
       end
       else begin
         Format.fprintf result_fmt
           "(rule ; %s\n  \
            (alias %s)\n  \
            (deps %a (package frama-c)%a)\n  \
            (targets %a %a)\n  \
            (action (system %S))\n\
            )@."
           (* rules: *)
           wtest.info
           (* alias *)
           wrapper_basename
           (* deps: *)
           print_list config.dc_deps
           Fmt.(list (package_as_deps (quote plugin_as_package))) cmd.deps.load_plugin
           (* targets: *)
           print_list wtest.log
           print_list wtest.bin
           (* action: *)
           wtest.cmd
       end;
       let oracle_subdir = SubDir.oracle_subdir ~env cmd.directory in
       List.iter (oracle_target oracle_fmt oracle_subdir) wtest.log ;
       List.iter (oracle_target oracle_fmt oracle_subdir) wtest.bin ;
       Format.fprintf result_fmt
         "(rule ; SHOW EXECNOW COMMAND #%d OF TEST FILE %S\n  \
          (alias %s)\n  \
          (deps %a (package frama-c)%a (universe))\n  \
          (action (system %S))\n\
          )@."
         (* rules: *)
         nth file
         (* alias *)
         (mk_alias cmd "execnow.show")
         (* deps: *)
         print_list config.dc_deps
         Fmt.(list (package_as_deps (quote plugin_as_package))) cmd.deps.load_plugin
         (* action: *)
         ("echo '" ^ show_cmd wtest.cmd ^"'");
       ;
       List.iteri (fun n log ->
           Format.fprintf result_fmt
             "(rule ; COMPARE TARGET #%d OF EXECNOW #%d FOR TEST FILE %S\n  \
              (alias %s)\n  \
              (action (diff %S %S))\n\
              )@."
             (* rules: *)
             n nth file
             (* alias *)
             (ptests_alias ~env)
             (* action: *)
             (SubDir.make_file (SubDir.oracle_subdir ~env SubDir.upper_dir) log)
             log
         ) wtest.log
    in
    let libs = String.concat " " (List.map Filename.basename config.dc_libs) in
    let plugin_all = List.map (Format.sprintf "frama-c-%s.core") config.dc_plugin_all in
    List.iteri (fun n cmxs ->
        Format.fprintf result_fmt
          "(executable ; MODULE #%d FOR TEST FILE %S\n  \
           (name %S)\n  \
           (modules %S)\n  \
           (modes plugin)\n  \
           (libraries frama-c.init.cmdline frama-c.boot frama-c.kernel %a %s)\n  \
           (flags -open Frama_c_kernel)\n\
           )@."
          (* executable: *)
          (n+1) file
          (* name: *)
          cmxs
          (* module: *)
          cmxs
          (* libraries: *)
          print_list plugin_all
          libs
      ) (StringSet.elements (StringSet.of_list config.dc_cmxs));
    if config.dc_commands <> [] || config.dc_execnow <> [] then begin
      let print_list_alias fmt l = List.iter (Format.fprintf fmt "(alias %S)") l in
      Format.fprintf result_fmt
          "; TEST FILE %S\n\
           (alias (deps %a%a) (name %S)) ; to performs all sub-tests related to a file\n\
           (alias (deps %a%a) (name %S)) ; to reproduce and visualize the all sub-test outputs related to a file@."
          file
          (* alias #1 *)
          print_list_alias (List.mapi (fun i _ -> Format.sprintf "%s.%d.exec.wtests" test_name i) config.dc_commands)
          print_list_alias (List.mapi (fun i _ -> Format.sprintf "%s.%d.execnow.wtests" test_name i) config.dc_execnow)
          (Format.sprintf "%s.wtests" test_name)
          (* alias #2 *)
          print_list_alias (List.mapi (fun i _ -> Format.sprintf "%s.%d.exec" test_name i) config.dc_commands)
          print_list_alias (List.mapi (fun i _ -> Format.sprintf "%s.%d.execnow.wtests" test_name i) config.dc_execnow)
          file;
    end ;
    List.iter make_cmd config.dc_commands;
    List.iter make_execnow_cmd config.dc_execnow;
    (config.dc_commands <> [] || config.dc_execnow <> [])
  else
    false

let test_pattern config =
  let regexp = Str.regexp config.dc_test_regexp in
  fun file -> Str.string_match regexp file 0

(* if we have some references to directories in the default config, they
   need to be adapted to the actual test directory. *)
let update_dir_ref dir config =
  let update_execnow e = { e with ex_dir = dir } in
  let dc_execnow = List.map update_execnow config.dc_execnow in
  { config with dc_execnow }

let process ~env default_config (suites:Ptests_config.alias StringMap.t) =
  StringMap.iter
    (fun suite alias ->
       let env = { env with dune_alias = alias.Ptests_config.alias } in
       let suite = Filename.concat env.dir suite in
       let directory = SubDir.create ~with_subdir:true ~env suite in
       let result_dune_file = SubDir.make_file (SubDir.result_subdir ~env directory) "dune" in
       if !verbosity >= 2 then Format.printf "%% Generates %S file for test suite %s%s and dune-alias=@@%s ...@."
           result_dune_file suite (if env.config = "" then "" else (", config=" ^ env.config)) env.dune_alias;
       let dir_config =
         let config = SubDir.make_file directory Test_config.filename in
         if Sys.file_exists config
         then begin
            let scan_buffer = Scanf.Scanning.from_file config in
            Test_config.scan_directives ~drop:false directory ~file:config
              scan_buffer default_config
         end
         else default_config
       in
       let result_cout = (open_out result_dune_file) in
       let result_fmt = Format.formatter_of_out_channel result_cout  in
       Format.fprintf result_fmt "(copy_files ../*.*)@.";
       Format.fprintf result_fmt "(alias (deps (alias %s)) (name %s))@." (ptests_alias ~env) env.dune_alias;
       let oracle_dune_file = SubDir.make_file (SubDir.oracle_subdir ~env directory) "dune" in
       let oracle_cout = (open_out oracle_dune_file) in
       let oracle_fmt = Format.formatter_of_out_channel oracle_cout in
       let dir_files = Sys.readdir (SubDir.get directory) in
       let has_test = ref false in
       if !verbosity >= 3 then Format.printf "%% - Look at %d entries of the directory...@." (Array.length dir_files);
       for i = 0 to pred (Array.length dir_files) do
         let file = dir_files.(i) in
         assert (Filename.is_relative file);
         if test_pattern dir_config file
         then begin
           if !verbosity >= 2 then Format.printf "%% - Process test file %s ...@." file;
           has_test := dispatcher ~env ~result_fmt ~oracle_fmt file directory dir_config || !has_test
         end;
       done;
       Format.fprintf result_fmt "@.";
       Format.fprintf oracle_fmt "@.";
       close_out result_cout;
       close_out oracle_cout;
       if not !has_test then begin (* there is no test_command *)
         unlink ~silent:false result_dune_file;
         unlink ~silent:false oracle_dune_file
       end
       else nb_dune_files := !nb_dune_files +2
    ) suites

let parse_args () =
  let suites = ref [] in
  let add_test_suite s = suites := s :: !suites in
  Arg.parse
    ((Arg.align
        (List.sort
           (fun (optname1, _, _) (optname2, _, _) ->
              compare optname1 optname2
           ) argspec)
     ) @ ["", Arg.Unit (fun () -> ()), example_msg;])
    add_test_suite
    umsg;
  !suites

let () =
  let suites = match parse_args () with
    | [] -> [ "tests" ]
    | l -> l
  in
  List.iter (fun dir ->
      Format.printf "Test directory: %s@." dir;
      let suites = Ptests_config.parse ~dir in
      if !verbosity >= 1 then Format.printf "%% Nb config= %d@." (StringMap.cardinal suites);
      let nb = !nb_dune_files in
      let nbi = !nb_ignores in
      StringMap.iter (fun config_mode suites ->
          if !verbosity >= 1 then Format.printf "%% - %s_SUITES -> nb suites= %d@."
              (match config_mode with "" -> "DEFAULT" | s -> s) (StringMap.cardinal suites);
          let env = { config = config_mode ; dir ; dune_alias = "" } in
          let directory = SubDir.create ~with_subdir:false ~env dir in
          let config = Test_config.current_config ~env directory in
          let config = update_dir_ref directory config in
          process ~env config suites) suites ;
      if !verbosity >= 1 then Format.printf "%% Nb dune files= %d@." (!nb_dune_files-nb);
      if (!nb_ignores-nbi) <> 0 then Format.printf "- %d ignored suite(s)@." (!nb_ignores-nbi);
    ) suites ;
  Format.printf "Total number of generated dune files: %d@." !nb_dune_files;
  if !nb_ignores <> 0 then begin
    Format.printf "- ignored suites= %d@." !nb_ignores;
    List.iter (Format.printf "  - %s@.") !ignored_suites
  end

(*
Local Variables:
compile-command: "LC_ALL=C make -C .. ptests"
End:
*)
