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

open Locations


module Tbl =
  Kernel_function.Make_Table
    (Eva.Assigns)
    (struct
      let name = "Functionwise dependencies"
      let size = 17
      let dependencies = [ Eva.Analysis.self ]
    end)
let () = From_parameters.ForceDeps.set_output_dependencies [Tbl.self]

(* Forward reference to a function computing the from for a given function *)
let force_compute = ref (fun _ -> assert false)

module To_Use = struct
  let stmt_request stmt = Eva.Results.before stmt

  let memo kf =
    Tbl.memo
      (fun kf ->
         !force_compute kf;
         try Tbl.find kf
         with Not_found -> invalid_arg "could not compute dependencies")
      kf

  let get_from_call kf _ = memo kf

  let keep_base kf = (* Eta-expansion required *)
    Eva.Logic_inout.accept_base ~formals:false ~locals:false kf

  let cleanup kf froms =
    if Eva.Assigns.Memory.is_bottom froms.Eva.Assigns.memory
    then froms
    else
      let accept_base =
        Eva.Logic_inout.accept_base ~formals:true ~locals:false kf
      in
      let f b intervs =
        if accept_base b
        then Zone.inject b intervs
        else Zone.bottom
      in
      let joiner = Zone.join in
      let projection _ = Int_Intervals.top in
      let zone_substitution =
        Zone.cached_fold ~cache_name:"from cleanup" ~temporary:true
          ~f ~joiner ~empty:Zone.bottom ~projection
      in
      let zone_substitution x =
        try
          zone_substitution x
        with Abstract_interp.Error_Top -> Zone.top
      in
      let map_zone = Eva.Deps.map zone_substitution in
      { memory = From_memory.map map_zone froms.memory;
        return = Eva.Deps.map zone_substitution froms.return;
      }

  let cleanup_and_save kf froms =
    let froms = cleanup kf froms in
    Tbl.add kf froms;
    froms
end

module From = From_compute.Make(To_Use)
let () = force_compute := From.compute


let self = Tbl.self

let compute kf = ignore (To_Use.memo kf)

let force_compute_all () =
  Eva.Analysis.compute () ;
  Callgraph.Uses.iter_in_rev_order @@ fun kf ->
  let is_definition = Kernel_function.is_definition kf in
  if is_definition && Eva.Results.is_called kf then compute kf

let compute_all =
  let name = "From.compute_all" in
  State_builder.apply_once name [Tbl.self] force_compute_all |> fst

let is_computed = Tbl.mem

let get = To_Use.memo

let pretty fmt v =
  From_memory.pretty_with_type (Kernel_function.get_type v) fmt (get v)

(*
Local Variables:
compile-command: "make -C ../../.."
End:
*)
