(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

open Testlib

(** Command-line flags *)
let verbosity = ref 1

(* ------------------------------- *)

let pp_json fmt json =
  Format.fprintf fmt "%% dune build @@%S" json

let fail ~json s info =
  Format.printf "%a: Error - %s@.%% Aborting: %s@." pp_json json s info ;
  exit 2

let output_unix_error (exn : exn) =
  match exn with
  | Unix.Unix_error (error, _function, arg) ->
    let message = Unix.error_message error in
    if arg = "" then
      Format.eprintf "%s@." message
    else
      Format.eprintf "%s: %s@." arg message
  | _ -> assert false

let unlink ?(silent = true) file =
  let open Unix in
  try
    Unix.unlink file
  with
  | Unix_error _ when silent -> ()
  | Unix_error (ENOENT,_,_) -> () (* Ignore "No such file or directory" *)
  | Unix_error _ as e -> output_unix_error e

let system =
  if Sys.os_type = "Win32" then
    fun f ->
      Unix.system (Format.sprintf "bash -c %S" f)
  else
    fun f ->
      Unix.system f

let print_file dir_info file =
  Format.printf "%% Generated output file: %s/%s@." dir_info file;
  try
    let cin = open_in file in
    try
      while true do
        let line = input_line cin in
        Format.printf "%s\n" line
      done
    with _ ->
      close_in cin
  with _ ->
    Format.printf "%% Cannot open file: %s@." file

(* ------------------------------- *)

let example_msg =
  Format.sprintf
    "@.@[<v 0>\
     Wrapper to run test command.@."

let umsg = "Usage: frama-c-wtests [options] <json-config> <test-command>*"

let rec argspec =
  [
    ("-v", Arg.Unit (fun () -> incr verbosity),
     "Increase verbosity (up to twice)") ;
    ("-brief", Arg.Unit (fun () -> verbosity := 0),
     "Brief report only on test failure") ;
  ]
and help_msg () = Arg.usage (Arg.align argspec) umsg

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
  List.rev !suites

(* ------------------------------- *)

let launch command_string =
  let result = system command_string in
  match result with
  | Unix.WEXITED 127 ->
    Format.printf "%% Couldn't execute command.:@\n%s@\nStopping@."
      command_string ;
    exit 1
  | Unix.WEXITED r -> r
  | Unix.WSIGNALED s ->
    Format.printf
      "%% SIGNAL %d received while executing command:@\n%s@\nStopping@."
      s command_string ;
    exit 1
  | Unix.WSTOPPED s ->
    Format.printf
      "%% STOP %d received while executing command:@\n%s@\nStopping@."
      s command_string;
    exit 1

let remove file = if file <> "" then unlink file

let extract_logs test =
  let aux log tmp logs =
    (* If the log is filtered then the command saves to a temporary file and a
       later dune rule does the filtering. *)
    if tmp <> "" && tmp <> log then
      tmp :: logs
    else
      log :: logs
  in
  let logs = test.log in
  let logs = aux test.out test.tmpout logs in
  let logs = aux test.err test.tmperr logs in
  List.filter (fun f -> f <> "") logs

let parse ~json =
  if !verbosity > 0 then Format.printf "%% Parsing Jsonjson...@.";
  match wtest_of_yojson (Yojson.Safe.from_file json) with
  | Error txt ->  fail ~json txt "Json file cannot be parsed"
  | Ok r -> r

let wrapper ~json =
  let test, json =
    try
      let test = parse ~json in
      let json = test.dir ^ "/" ^ json in
      test, json
    with
    | Yojson.Json_error txt
    | Sys_error txt -> fail ~json txt "Json file cannot be parsed"
  in
  if !verbosity > 0 then begin
    Format.printf "%% Wrapping info: %s@." test.info ;
    Format.printf "%% Wrapped command: %s@." test.cmd ;
    List.iter (fun s -> Format.printf "%% Wrapped filter: %s@." s)
      [test.sedout; test.sederr];
  end;
  let logs = extract_logs test in
  if logs <> [] || test.bin <> [] then begin
    if !verbosity > 0 then Format.printf "%% Clean targets...@.";
    List.iter remove logs;
    List.iter remove test.bin
  end;
  if !verbosity > 0 then Format.printf "%% Run test command: %s@." test.cmd;
  let ret_code = launch test.cmd in
  let error = ret_code <> test.ret_code in
  if error || !verbosity > 0 then begin
    if test.out <> "" then print_file test.dir (if test.tmpout = "" then test.out else test.tmpout) ;
    if test.err <> "" then print_file test.dir (if test.tmperr = "" then test.err else test.tmperr) ;
    List.iter (print_file test.dir) test.log
  end;
  if error then begin
    Format.printf "%a: return code (%d) differs from the requested code (%d) for the command:%s@."
      pp_json json ret_code test.ret_code test.cmd;
    fail ~json "Test failed" test.info
  end

let () =
  let args = parse_args () in
  (* verbosity := 1; *)
  match args with
  | json :: _commands ->
    (* commands are passed to the script so that dune can extract the
       dependencies for its rule, but only the content of the json file is used
       by the wrapper to decide what to run *)
    if !verbosity > 0 then begin
      Format.printf "%% Wrapping from json file: %S@." json ;
    end;
    wrapper ~json
  | _ -> help_msg () ; exit 1
