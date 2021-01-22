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


let json_of_parameters parms =
  let pair param =
    let name = param.Typed_parameter.name in
    let value = Typed_parameter.get_value param in
    (name, `String value)
  in
  let parms_json = List.map pair parms in
  `Assoc [("correctness-parameters", `Assoc parms_json)]

let parameters_of_json parms_json =
  try
    let open Yojson.Basic.Util in
    let parms = parms_json |> member "correctness-parameters" |> to_assoc in
    List.map (fun (key, value) -> (key, value |> to_string)) parms
  with
  | Yojson.Json_error msg ->
    Kernel.abort "error reading JSON file: %s" msg
  | Yojson.Basic.Util.Type_error (msg, v) ->
    Kernel.abort "error reading JSON file: %s - %s" msg
      (Yojson.Basic.pretty_to_string v)

let print_correctness_parameters path =
  let parameters_correctness = Value_parameters.parameters_correctness in
  if Filepath.Normalized.is_special_stdout path then begin
    Value_parameters.feedback "Correctness parameters of the analysis:";
    let print param =
      let name = param.Typed_parameter.name in
      let value = Typed_parameter.get_value param in
      Value_parameters.printf "  %s: %s" name value
    in
    List.iter print parameters_correctness
  end else begin
    let json = `Assoc [("eva", json_of_parameters parameters_correctness)] in
    Json.merge_object path json
  end

let check_correctness_parameters json =
  let get param =
    let name = param.Typed_parameter.name in
    let value = Typed_parameter.get_value param in
    (name, value)
  in
  let parameters_correctness = Value_parameters.parameters_correctness in
  let parameters = List.map get parameters_correctness in
  let expected_parameters =
    parameters_of_json (json |> Yojson.Basic.Util.member "eva")
  in
  let sort = List.sort (fun (p1, _) (p2, _) -> Stdlib.String.compare p1 p2) in
  let expected_parameters = sort expected_parameters in
  let parameters = sort parameters in
  (* Note: we could simply compare lengths and use a two-list iterator,
     but in case of divergence, the error messages would be less clear. *)
  List.iter (fun (exp_p, exp_v) ->
      try
        let v = List.assoc exp_p parameters in
        if exp_v <> v then
          Kernel.warning ~wkey:Kernel.wkey_audit
            "correctness parameter %s: expected value %s, but got %s" exp_p
            exp_v v
      with Not_found ->
        Kernel.warning ~wkey:Kernel.wkey_audit
          "expected correctness parameter %s, but not found" exp_p
    ) expected_parameters

let compute_warning_status (module Plugin: Log.Messages) =
  let warning_categories = Plugin.get_all_warn_categories_status () in
  let is_active = function
    | Log.Winactive | Wfeedback_once | Wfeedback -> false
    | Wonce | Wactive | Werror_once | Werror | Wabort -> true
  in
  let is_enabled (_key, status) = is_active status in
  let enabled, disabled = List.partition is_enabled warning_categories in
  let pp_fst = List.map (fun (c, s) -> Plugin.wkey_name c, s) in
  (pp_fst enabled, pp_fst disabled)

let json_of_warning_statuses wkeys key_name =
  let json_of_wkey = List.map (fun (c, _) -> `String c) in
  (key_name, `List (json_of_wkey wkeys))

let warning_statuses_of_json json =
  try
    let open Yojson.Basic.Util in
    json |> to_list |> filter_string
  with
  | Yojson.Json_error msg ->
    Kernel.abort "error reading JSON file: %s" msg
  | Yojson.Basic.Util.Type_error (msg, v) ->
    Kernel.abort "error reading JSON file: %s - %s" msg
      (Yojson.Basic.pretty_to_string v)

let print_warning_status path name (module Plugin: Log.Messages) =
  let enabled, disabled = compute_warning_status (module Plugin) in
  if Filepath.Normalized.is_special_stdout path then
    begin
      let pp_categories =
        Pretty_utils.pp_list ~sep:",@ " Format.pp_print_string
      in
      Value_parameters.feedback "Audit: %s warning categories:" name;
      Value_parameters.printf "  Enabled: @[%a@]"
        pp_categories (List.map fst enabled);
      Value_parameters.printf "  Disabled: @[%a@]"
        pp_categories (List.map fst disabled)
    end
  else begin
    let enabled_json =
      json_of_warning_statuses enabled "enabled"
    in
    let disabled_json =
      json_of_warning_statuses disabled "disabled"
    in
    let json = `Assoc [(Stdlib.String.lowercase_ascii name,
                        `Assoc [("warning-categories",
                                 `Assoc [enabled_json; disabled_json])])]
    in
    Json.merge_object path json
  end

let check_warning_status json name (module Plugin: Log.Messages) =
  let lower_name = Stdlib.String.lowercase_ascii name in
  let enabled, _disabled = compute_warning_status (module Plugin) in
  let enabled = List.map fst enabled in
  let (expected_enabled : string list) =
    try
      let open Yojson.Basic.Util in
      json |> member lower_name |> member "warning-categories" |>
      member "enabled" |> to_list |> filter_string
    with
    | Yojson.Json_error msg ->
      Kernel.abort "error reading JSON file: %s" msg
    | Yojson.Basic.Util.Type_error (msg, v) ->
      Kernel.abort "error reading JSON file: %s - %s" msg
        (Yojson.Basic.pretty_to_string v)
  in
  let diff l1 l2 = List.filter (fun k -> not (List.mem k l2)) l1 in
  let should_be_enabled = diff expected_enabled enabled in
  if should_be_enabled <> [] then
    Kernel.warning ~wkey:Kernel.wkey_audit
      "the following warning categories were expected to be enabled,@ \
       but were disabled: %a"
      (Pretty_utils.pp_list ~sep:", " Format.pp_print_string) should_be_enabled

let check_configuration path =
  let json = Json.from_file path in
  check_correctness_parameters json;
  check_warning_status json "Kernel" (module Kernel);
  check_warning_status json "Eva" (module Value_parameters)

let print_configuration path =
  print_correctness_parameters path;
  print_warning_status path "Kernel" (module Kernel);
  print_warning_status path "Eva" (module Value_parameters)
