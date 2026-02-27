(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

include Eva__Results

let update request =
  match Update.CurrentCallstacks.get () with
  | [] -> request
  | [cs] -> in_callstack cs request
  | list -> in_callstacks list request

let at_start_of kf = at_start_of kf |> update
let at_end_of kf = at_end_of kf |> update
let before stmt = before stmt |> update
let after stmt = after stmt |> update
let before_kinstr kinstr = before_kinstr kinstr |> update
