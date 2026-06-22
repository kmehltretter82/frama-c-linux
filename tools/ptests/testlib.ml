(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

type wtest = {
  info: (string [@default ""]); (* info *)
  dir: (string [@default ""]); (* test directory *)
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
  oracle_dir: (string [@default ""]); (* directory containing the oracle of the log files *)
  oracle_out: (string [@default "" ]); (* oracle of the stdout target *)
  oracle_err: (string [@default "" ]); (* oracle of the stderr target *)
}
[@@deriving yojson]

module Filename = struct
  include Filename

  let concat =
    if Sys.os_type = "Win32" then
      fun a b -> a ^ "/" ^ b
    else
      concat

  let sanitize f = String.escaped f

  let sanitize_with_space =
    let regexp = Str.regexp "[\\] " in
    let subst = Str.global_replace regexp " " in
    subst

  let remove_extension_opt suffixes name =
    let ext = extension name in
    if (String.equal "" ext) || not (List.mem ext suffixes) then name
    else remove_extension name
end

