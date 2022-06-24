(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2022                                               *)
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

let () =
  Cmdline.run_after_extended_stage
    (fun () ->
       State_dependency_graph.add_codependencies
         ~onto:Pdg_tbl.self
         [ !Db.From.self ])

(* This module contains polymorphic functions : cannot be registered in Db.
   Can be used through Pdg.Register instead (see Pdg.mli) *)
include Marks


let deps =
  [Pdg_tbl.self; Pdg_parameters.BuildAll.self; Pdg_parameters.BuildFct.self]

let () = Pdg_parameters.BuildAll.set_output_dependencies deps

let compute_for_kf kf =
  let all = Pdg_parameters.BuildAll.get () in
  (all && Eva.Results.is_called kf) ||
  Kernel_function.Set.mem kf (Pdg_parameters.BuildFct.get ())

let compute () =
  Eva.Analysis.compute ();
  let do_kf_pdg kf =
    if compute_for_kf kf then
      let pdg = Pdg_tbl.get kf in
      let dot_basename = Pdg_parameters.DotBasename.get () in
      if dot_basename <> "" then
        let fname = Kernel_function.get_name kf in
        Pdg_tbl.print_dot pdg (dot_basename ^ "." ^ fname ^ ".dot")
  in
  Callgraph.Uses.iter_in_rev_order do_kf_pdg;
  let pp_sep fmt () = Format.pp_print_string fmt "," in
  Pdg_parameters.(
    debug "Logging keys : %a"
      (Format.pp_print_list ~pp_sep pp_category) (get_debug_keys ()));
  if Pdg_parameters.BuildAll.get () then
    Pdg_parameters.feedback "====== PDG GRAPH COMPUTED ======"

let compute_once, _ =
  State_builder.apply_once "Pdg.Register.compute_once" deps compute

let output () =
  let bw  = Pdg_parameters.PrintBw.get () in
  let do_kf_pdg kf =
    if compute_for_kf kf then
      let pdg = Pdg_tbl.get kf in
      let header fmt =
        Format.fprintf fmt "PDG for %a" Kernel_function.pretty kf
      in
      Pdg_parameters.printf ~header "@[ @[%a@]@]"
        (PdgTypes.Pdg.pretty_bw ~bw) pdg
  in
  Callgraph.Uses.iter_in_rev_order do_kf_pdg

let something_to_do () =
  Pdg_parameters.BuildAll.get ()
  || not (Kernel_function.Set.is_empty (Pdg_parameters.BuildFct.get ()))

let main () =
  if something_to_do () then
    (compute_once ();
     Pdg_parameters.BuildAll.output output)

let () = Db.Main.extend main


(*
  Local Variables:
  compile-command: "make -C ../../.."
  End:
*)
