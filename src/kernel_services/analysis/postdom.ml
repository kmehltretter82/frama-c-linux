(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2024                                               *)
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

(* This module performs dataflow analysis using [Interpreted_automata] to
   compute the domination/postdomination dependancies between statements of a
   given function. *)

open Cil_types
open Interpreted_automata

(* State type of our domain. *)
module StmtSet = struct
  include Cil_datatype.Stmt.Hptset
  let pretty fmt set =
    Pretty_utils.pp_iter ~pre:"@[{" ~sep:",@," ~suf:"}@]"
      iter (fun fmt stmt -> Format.pp_print_int fmt stmt.sid)
      fmt set
end

module StmtSetOpt = struct
  include Datatype.Option (StmtSet)

  let remove s setopt =
    Option.map (StmtSet.remove s) setopt

  let mem s setopt =
    Option.fold ~none:false ~some:(StmtSet.mem s) setopt

  let pretty fmt setopt =
    Pretty_utils.pp_opt ~none:"Top" StmtSet.pretty fmt setopt
end


(* Both analysis are using this domain. It simply propagate all encountered
   statements by adding them to the state. The [join] performs an intersection
   which is enough to compute domination/postdomination. *)
module Domain = struct
  type t = StmtSet.t

  let join = StmtSet.inter

  let widen a b =
    if StmtSet.subset a b then
      Fixpoint
    else
      Widening (join a b)

  (* Trivial transfert function : add all visited statements to the current
     state. *)
  let transfer v _ state =
    match v.vertex_start_of with
    | None -> Some state
    | Some stmt -> Some (StmtSet.add stmt state)
end

(* An analysis needs a name and a starting point. *)
module type Analysis = sig
  val name : string
  val get_starting_stmt : kernel_function -> stmt
  include DataflowAnalysis with type state = Domain.t
end

(* Main module, perform the analysis, store its results and provide ways to
   access them. *)
module Compute (Analysis : Analysis) = struct

  module Table =
    Cil_state_builder.Stmt_hashtbl
      (StmtSetOpt)
      (struct
        let name = Analysis.name ^ "_table"
        let dependencies = [Ast.self]
        let size = 503
      end)

  let compute kf =
    let init_stmt = Analysis.get_starting_stmt kf in
    match Table.find_opt init_stmt with
    | Some _ ->
      Kernel.feedback ~level:2 "%s analysis already computed for function %a"
        Analysis.name Kernel_function.pretty kf
    | None ->
      match kf.fundec with
      | Definition (f, _) ->
        Kernel.feedback ~level:2 "computing %s analysis for function %a"
          Analysis.name Kernel_function.pretty kf;
        (* Compute the analysis, initial state is empty. *)
        let result = Analysis.fixpoint kf StmtSet.empty in
        (* Fill table with all statements. *)
        List.iter (fun stmt -> Table.add stmt None) f.sallstmts;
        (* Update the table with analysis results. *)
        Analysis.Result.iter_stmt (fun s set ->
            (* A statement always (post)dominates itself, so we add it here. *)
            Table.replace s (Some (StmtSet.add s set))
          ) result;
        Kernel.feedback ~level:2 "done for function %a"
          Kernel_function.pretty kf
      (* [Analysis.get_starting_stmt] should fatal before this point. *)
      | Declaration _ -> assert false

  let find_kf stmt =
    try Kernel_function.find_englobing_kf stmt
    with Not_found ->
      Kernel.fatal "Statement %d is not part of a function" stmt.sid

  (* Generic function to get the set of (post)dominators of [stmt]. *)
  let get stmt =
    let kf = find_kf stmt in
    match Table.find_opt stmt with
    | None -> compute kf; Table.find stmt
    | Some v -> v

  (* Generic function to get the set of strict (post)dominators of [stmt]. *)
  let get_strict stmt = get stmt |> StmtSetOpt.remove stmt

  (* Generic function to test the (post)domination of 2 statements. *)
  let mem a b = get b |> StmtSetOpt.mem a

  (* Generic function to test the strict (post)domination of 2 statements. *)
  let mem_strict a b = get_strict b |> StmtSetOpt.mem a

  let pretty fmt () =
    let l = Table.to_seq () |> List.of_seq in
    Pretty_utils.pp_list ~pre:"@[<v>" ~sep:"@;" ~empty:"Empty"
      (fun fmt (k,v) ->
         Format.fprintf fmt "Stmt:%d -> @[%a@]" k.sid StmtSetOpt.pretty v
      ) fmt l

end

(* ---------------------------------------------------------------------- *)
(* --- Dominators                                                     --- *)
(* ---------------------------------------------------------------------- *)

module Dominators = struct
  module Analysis = struct
    include ForwardAnalysis (Domain)
    let name = "Dominators"
    let get_starting_stmt kf =
      try Kernel_function.find_first_stmt kf
      with Kernel_function.No_Statement ->
        Kernel.fatal "No first statement in function %a"
          Kernel_function.pretty kf
  end
  include Compute (Analysis)
end

let compute_dominators = Dominators.compute

let get_dominators = Dominators.get

let get_strict_dominators = Dominators.get_strict

let dominates = Dominators.mem

let strictly_dominates = Dominators.mem_strict

let pretty_dominators = Dominators.pretty

(* ---------------------------------------------------------------------- *)
(* --- Postdominators                                                 --- *)
(* ---------------------------------------------------------------------- *)

module PostDominators = struct
  module Analysis = struct
    include BackwardAnalysis (Domain)
    let name = "PostDominators"
    let get_starting_stmt kf =
      try Kernel_function.find_return kf
      with Kernel_function.No_Statement ->
        Kernel.fatal "No return statement in function %a"
          Kernel_function.pretty kf
  end
  include Compute (Analysis)
end

let compute_postdominators = PostDominators.compute

let get_postdominators = PostDominators.get

let get_strict_postdominators = PostDominators.get_strict

let postdominates = PostDominators.mem

let strictly_postdominates = PostDominators.mem_strict

let pretty_postdominators = PostDominators.pretty
