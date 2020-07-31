(**************************************************************************)
(*                                                                        *)
(*  This file is part of Aorai plug-in of Frama-C.                        *)
(*                                                                        *)
(*  Copyright (C) 2007-2020                                               *)
(*    CEA (Commissariat à l'énergie atomique et aux énergies              *)
(*         alternatives)                                                  *)
(*    INRIA (Institut National de Recherche en Informatique et en         *)
(*           Automatique)                                                 *)
(*    INSA  (Institut National des Sciences Appliquees)                   *)
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

open Cil_types
open Promelaast


let dkey_metavar_init = Aorai_option.register_category "metavar-init"

module type InitAnalysisParam =
sig
  val is_metavariable : varinfo -> bool
end

module InitAnalysis (Env : InitAnalysisParam) =
struct
  type vertex = Aorai_graph.E.vertex
  type edge = Aorai_graph.E.t
  type g = Aorai_graph.t

  module Set = Cil_datatype.Varinfo.Set
  type data = Bottom | InitializedSet of Set.t

  let dkey = dkey_metavar_init

  let top = InitializedSet Set.empty

  let init v =
    if v.Promelaast.init = Bool3.True then top else Bottom

  let direction = Graph.Fixpoint.Forward

  let equal d1 d2 =
    match d1, d2 with
    | Bottom, d | d, Bottom -> d = Bottom
    | InitializedSet s1, InitializedSet s2 -> Set.equal s1 s2

  let join d1 d2 =
    match d1, d2 with
    | Bottom, d | d, Bottom -> d
    | InitializedSet s1, InitializedSet s2 ->
      InitializedSet (Set.inter s1 s2)

  let used_metavariables cond =
    let result = ref Set.empty in
    let visit_term =
      let v = object
        inherit Visitor.frama_c_inplace
        method!vlogic_var_use lv =
          match lv.lv_origin with
          | Some vi when Env.is_metavariable vi ->
            result := Set.add vi !result;
            Cil.SkipChildren
          | _ -> Cil.SkipChildren
      end in
      fun t -> ignore (Visitor.visitFramacTerm v t)
    in
    let rec visit_cond = function
      | TAnd (c1,c2) | TOr (c1,c2) -> visit_cond c1; visit_cond c2
      | TNot (c) -> visit_cond c
      | TRel (_,t1,t2) -> visit_term t1; visit_term t2
      | TCall _ | TReturn _ | TTrue | TFalse -> ()
    in
    visit_cond cond;
    !result

  let pretty_state fmt st =
    Format.pp_print_string fmt st.Promelaast.name

  let pretty_trans fmt tr =
    Promelaoutput.Typed.print_condition fmt tr.cross;
    if tr.actions <> [] then
      Format.fprintf fmt "{@[%a@]}" Promelaoutput.Typed.print_actionl tr.actions

  let pretty_set fmt set =
    let l = Set.elements set in
    Pretty_utils.pp_list ~sep:", " Cil_printer.pp_varinfo fmt l

  let _pretty_data fmt = function
    | Bottom -> Format.printf "Bottom"
    | InitializedSet set -> pretty_set fmt set

  let alarm (src,tr,dst) vars =
    Aorai_option.abort
      "The metavariables %a may not be initialized before the transition \
       from %a to %a:@\n%a"
      pretty_set vars
      pretty_state src
      pretty_state dst
      pretty_trans tr

  let analyze ((src,tr,dst) as edge) = function
    | Bottom -> Bottom
    | InitializedSet initialized ->
      (* Check that the condition uses only initialized variables *)
      let used = used_metavariables tr.cross in
      let diff = Set.diff used initialized in
      if not (Set.is_empty diff) then
        alarm edge diff;
      (* Add variables initialized by the condition *)
      let add set = function
        | Copy_value ((TVar({lv_origin = Some vi}),_),_) -> Set.add vi set
        | _ -> set
      in
      let initialized' = List.fold_left add initialized tr.actions in
      Aorai_option.debug ~dkey "%a {%a} -> %a {%a}"
        pretty_state src pretty_set initialized
        pretty_state dst pretty_set initialized';
      InitializedSet initialized'
end


let checkInitialization auto =
  let module P =
  struct
    let is_metavariable vi =
      let module Map = Datatype.String.Map in
      Map.exists (fun _ -> Cil_datatype.Varinfo.equal vi) auto.metavariables
  end
  in
  let module A = InitAnalysis (P) in
  let module Fixpoint = Graph.Fixpoint.Make (Aorai_graph) (A) in
  let g = Aorai_graph.of_automaton auto in
  let _result = Fixpoint.analyze A.init g in
  ()
