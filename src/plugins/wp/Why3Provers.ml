(**************************************************************************)
(*                                                                        *)
(*  This file is part of WP plug-in of Frama-C.                           *)
(*                                                                        *)
(*  Copyright (C) 2007-2024                                               *)
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

let why3_version = Why3.Config.version
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

let ident_why3 = Why3.Whyconf.prover_parseable_format
let ident_wp s =
  let name = Why3.Whyconf.prover_parseable_format s in
  let prv = String.split_on_char ',' name in
  String.concat ":" prv

let title ?(version=true) p =
  if version then Pretty_utils.to_string Why3.Whyconf.print_prover p
  else p.Why3.Whyconf.prover_name
let compare = Why3.Whyconf.Prover.compare
let name p = p.Why3.Whyconf.prover_name
let version p = p.Why3.Whyconf.prover_version
let altern p = p.Why3.Whyconf.prover_altern
let is_mainstream p = p.Why3.Whyconf.prover_altern = ""
let is_auto (p : t) =
  match p.prover_name with
  | "Coq" | "Isabelle" -> false
  | "Alt-Ergo" | "Z3" | "CVC4" | "CVC5" | "Colibri2" -> true
  | _ ->
    let config = config () in
    try
      let prover_config = Why3.Whyconf.get_prover_config config p in
      not prover_config.interactive
    with Not_found -> true
let has_counter_examples p =
  List.mem "counterexamples" @@
  String.split_on_char '+' p.Why3.Whyconf.prover_altern

let provers () =
  Why3.Whyconf.Mprover.keys (Why3.Whyconf.get_provers (config ()))

let provers_set () : Why3.Whyconf.Sprover.t =
  Why3.Whyconf.Mprover.domain (Why3.Whyconf.get_provers (config ()))

let is_available p =
  Why3.Whyconf.Mprover.mem p (Why3.Whyconf.get_provers (config ()))

let with_counter_examples p =
  if has_counter_examples p then Some p else
    let name = p.prover_name in
    let version = p.prover_version in
    List.find_opt
      (fun (q : t) ->
         q.prover_name = name &&
         q.prover_version = version &&
         has_counter_examples q)
    @@ provers ()

(* -------------------------------------------------------------------------- *)
(* ---  Prover Lookup                                                     --- *)
(* -------------------------------------------------------------------------- *)

(* semantical version comparison *)

type sem = V of int | S of string
let sem s = try V (int_of_string s) with Failure _ -> S s
let cmp x y =
  match x,y with
  | V a,V b -> b - a
  | V _,S _ -> (-1)
  | S _,V _ -> (+1)
  | S a,S b -> String.compare a b
let scmp u v = cmp (sem u) (sem v)
let vcmp u v =
  List.compare scmp (String.split_on_char '.' u) (String.split_on_char '.' v)
let by_version (p:t) (q:t) = vcmp p.prover_version q.prover_version

let filter ~name ?version (p:t) =
  p.prover_altern = "" &&
  String.lowercase_ascii p.prover_name = name &&
  match version with None -> true | Some v -> p.prover_version = v

let select ~name ?version () =
  match
    List.sort by_version @@ List.filter (filter ~name ?version) @@ provers ()
  with p::_ -> Some p | [] -> None

let lookup ?(fallback=false) prover_name =
  match String.split_on_char ':' @@ String.lowercase_ascii prover_name with
  | [name] -> select ~name ()
  | [name;version] ->
    begin
      match select ~name ~version () with
      | Some _ as res -> res
      | None ->
        if fallback then
          match select ~name () with
          | None -> None
          | Some p as res ->
            Wp_parameters.warning ~once:true ~current:false
              "Prover %s not found, fallback to %s" prover_name (ident_wp p) ;
            res
        else None
    end
  | _ -> None

(* -------------------------------------------------------------------------- *)
(* --- Models                                                             --- *)
(* -------------------------------------------------------------------------- *)

type model = Why3.Model_parser.concrete_syntax_term
let pp_model = Why3.Model_parser.print_concrete_term

(* -------------------------------------------------------------------------- *)
