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

(* ************************************************************************** *)
(* Topological iterators *)
(* ************************************************************************** *)

module Make
    (G:Graph.Sig.G with type V.t = Kernel_function.t)
    (N:sig val name: string end) =
struct

  (* Topological iterations are memoized in order to improve efficiency when
     calling them several times. This has been proved to have a significant
     impact in practice. *)

  module S =
    State_builder.Queue
      (Kernel_function)
      (struct
        let name = "Callgraph.Uses" ^ N.name
        let dependencies = [ Cg.self ]
      end)

  module T = Graph.Topological.Make_stable(G)

  let iter g f =
    (* Warns if [-cg-no-function-pointers] is in effect, which may lead
       to unsound analyses for the users of the callgraph. *)
    if not (Options.Function_pointers.get ()) then
      Options.warning ~once:true "using callgraph while option %s is unset, \
                                  result may be unsound"
        Options.Function_pointers.name;
    if S.is_empty () then T.iter S.add g;
    S.iter f

end

let iter_in_order =
  let module I = Make(Cg.G)(struct let name = "iter_in_order" end) in
  fun f -> I.iter (Cg.get ()) f

let iter_in_rev_order =
  let module I =
    Make
      (struct
        include Cg.G
        (* inverse operations over successors required by
           [Graph.Topological.G] *)
        let iter_succ = iter_pred
        let in_degree = out_degree
      end)
      (struct let name = "iter_in_rev_order" end)
  in
  fun f -> I.iter (Cg.get ()) f

let _iter_in_rev_order =
  Dynamic.register
    ~comment:"Iterate over all the functions in the callgraph in reverse order"
    ~plugin:Options.name
    "iter_in_rev_order"
    Datatype.(func (func Kernel_function.ty unit) unit)
    iter_in_rev_order

let iter_on_aux iter_dir f kf =
  let cg = Cg.get () in
  if Cg.G.mem_vertex cg kf then
    let visited = Kernel_function.Hashtbl.create 17 in
    let rec aux kf =
      iter_dir
        (fun kf' ->
           if not (Kernel_function.Hashtbl.mem visited kf') then begin
             f kf';
             Kernel_function.Hashtbl.add visited kf' ();
             aux kf'
           end)
        cg
        kf
    in
    aux kf

let iter_on_callers = iter_on_aux Cg.G.iter_pred
let iter_on_callees = iter_on_aux Cg.G.iter_succ

let nb_calls () =
  let g = Cg.get () in
  (* [g] contains bidirectional edges (from caller to callee and
     conversely). Conseqently each function call is counted twice. *)
  Cg.G.nb_edges g / 2

(*
Local Variables:
compile-command: "make -C ../../.."
End:
*)
