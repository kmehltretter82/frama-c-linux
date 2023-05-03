(**************************************************************************)
(*                                                                        *)
(*  This file is part of WP plug-in of Frama-C.                           *)
(*                                                                        *)
(*  Copyright (C) 2007-2023                                               *)
(*    CEA (Commissariat a l'energie atomique et aux energies              *)
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

(* -------------------------------------------------------------------------- *)
(* --- Why3 Config & Provers                                              --- *)
(* -------------------------------------------------------------------------- *)

let cfg = lazy
  begin
    let extra_config = Wp_parameters.Why3ExtraConfig.get () in
    try Why3.Whyconf.init_config ~extra_config None
    with exn ->
      Wp_parameters.abort "%a" Why3.Exn_printer.exn_printer exn
  end

let version = Why3.Config.version
let config () = Lazy.force cfg

let set_procs = Why3.Controller_itp.set_session_max_tasks

let configure =
  let todo = ref true in
  begin fun () ->
    if !todo then
      begin
        let commands = "why3"::Wp_parameters.Why3Flags.get () in
        let args = Array.of_list commands in
        begin try
            (* Ensure that an error message generating directly by why3 is
               reported as coming from Why3, not from Frama-C. *)
            Why3.Getopt.commands := commands;
            Why3.Getopt.parse_all
              (Why3.Debug.Args.[desc_debug;desc_debug_all;desc_debug_list])
              (fun opt -> raise (Arg.Bad ("unknown option: " ^ opt)))
              args
          with Arg.Bad s | Arg.Help s -> Wp_parameters.abort "%s" s
        end;
        ignore (Why3.Debug.Args.option_list ());
        Why3.Debug.Args.set_flags_selected ();
        todo := false
      end
  end

type t = Why3.Whyconf.prover

let find_opt s =
  try
    let config = Lazy.force cfg in
    let filter = Why3.Whyconf.parse_filter_prover s in
    Some ((Why3.Whyconf.filter_one_prover config filter).Why3.Whyconf.prover)
  with
  | Why3.Whyconf.ProverNotFound _
  | Why3.Whyconf.ParseFilterProver _
  | Why3.Whyconf.ProverAmbiguity _  ->
    None

type fallback = Exact of t | Fallback of t | NotFound

let find_fallback name =
  match find_opt name with
  | Some prv -> Exact prv
  | None ->
    (* Why3 should deal with this intermediate case *)
    match find_opt (String.lowercase_ascii name) with
    | Some prv -> Exact prv
    | None ->
      match String.split_on_char ',' name with
      | shortname :: _ :: _ ->
        begin
          match find_opt (String.lowercase_ascii shortname) with
          | Some prv -> Fallback prv
          | None -> NotFound
        end
      | _ -> NotFound

let ident_why3 = Why3.Whyconf.prover_parseable_format
let ident_wp s =
  let name = Why3.Whyconf.prover_parseable_format s in
  let prv = String.split_on_char ',' name in
  String.concat ":" prv

let title ?(version=true) p =
  if version then Pretty_utils.to_string Why3.Whyconf.print_prover p
  else p.Why3.Whyconf.prover_name
let compare = Why3.Whyconf.Prover.compare
let is_mainstream p = p.Why3.Whyconf.prover_altern = ""

let provers () =
  Why3.Whyconf.Mprover.keys (Why3.Whyconf.get_provers (config ()))

let provers_set () : Why3.Whyconf.Sprover.t =
  Why3.Whyconf.Mprover.domain (Why3.Whyconf.get_provers (config ()))

let is_available p =
  Why3.Whyconf.Mprover.mem p (Why3.Whyconf.get_provers (config ()))

let has_shortcut p s =
  match Why3.Wstdlib.Mstr.find_opt s
          (Why3.Whyconf.get_prover_shortcuts (config ())) with
  | None -> false
  | Some p' -> Why3.Whyconf.Prover.equal p p'

(** model *)
type model = Why3.Model_parser.concrete_syntax_term Probe.Map.t
let empty_model = Probe.Map.empty
let print_model fmt m =
  Pretty_utils.pp_iter2 Probe.Map.iter
    Probe.pretty Why3.Model_parser.print_concrete_term
    fmt m

(* -------------------------------------------------------------------------- *)
