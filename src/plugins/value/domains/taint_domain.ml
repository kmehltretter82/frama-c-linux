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

open Locations

type taint = Zone.t


module LatticeTaint = struct

  (* Frama-C "datatype" for type [taint]. *)
  include Datatype.Make_with_collections(struct
      include Datatype.Serializable_undefined

      type t = taint

      let name = "Value.Taint.t"

      let reprs = [ List.hd Zone.reprs; ]

      let structural_descr = Structural_descr.t_record [| Zone.packed_descr; |]

      let compare = Zone.compare

      let equal = Datatype.from_compare

      let pretty fmt c = Format.fprintf fmt "@[<hov>%a@]" Zone.pretty c

      let hash = Zone.hash

      let copy c = c

    end)

  (* Initial state at the start of the computation: nothing is tainted yet. *)
  let empty = Zone.bottom

  (* Top state: everything is tainted. *)
  let top = Zone.top

  (* Join: keep to over-approximate. *)
  let join = Zone.join

  (* The memory locations are finite, so the ascending chain property is
     already verified. We simply use a join. *)
  let widen _ _ c1 c2 = join c1 c2

  let narrow c1 c2 = `Value (Zone.narrow c1 c2)

  (* Inclusion testing: pointwise. *)
  let is_included = Zone.is_included

end


module TransferTaint = struct

  (* No update about taint wrt information provided by the other domains. *)
  let update _valuation state = `Value state

  let assign _ki _lv _exp _v _valuation state = `Value state

  let assume _stmt _exp _b _valuation state = `Value state

  let start_call _stmt _call _valutaion state = `Value state

  let finalize_call _stmt _call ~pre:_ ~post = `Value post

  let show_expr _valuation _state _fmt _exp = ()

end


module QueriesTaint = struct

  let top_query = `Value (Cvalue.V.top, None), Alarmset.all

  let extract_expr _oracle _state _expr = top_query

  let extract_lval _oracle _state _lv _typ _locs = top_query

  let backward_location _state _lval _typ loc value = `Value (loc, value)

  let reduce_further _state _expr _value =
    [] (* Nothing intelligent to suggest *)

end


module ReuseTaint = struct

  let relate _kf _bases _state = Base.SetLattice.empty
  let filter _kf _kind _bases state = state
  let reuse _kf _bases ~current_input:_ ~previous_output = previous_output

end


module InternalTaint = struct
  type state = taint
  type value = Cvalue.V.t
  type location = Precise_locs.precise_location
  type origin

  include (LatticeTaint: sig
             include Datatype.S_with_collections with type t = state
             include Abstract_domain.Lattice with type state := state
           end)

  include (QueriesTaint: Abstract_domain.Queries
           with type state := state
            and type value := value
            and type location := location
            and type origin := origin)

  include (TransferTaint: Abstract_domain.Transfer
           with type state := state
            and type value := value
            and type location := location
            and type origin := origin)

  include (ReuseTaint: Abstract_domain.Reuse with type t := state)

  let name = "taint"
  let log_category = Value_parameters.register_category "d-taint"


  (* Logic. *)

  let logic_assign _assign _location _state = top
  let evaluate_predicate _ _ _ = Alarmset.Unknown
  let reduce_by_predicate _ state _ _ = `Value state


  (* Scoping and Initialization. *)

  let enter_scope _kind _vars state = state
  let leave_scope _kf _vars state = state

  (* Initial state: initializers are singletons, so we store nothing. *)
  let empty () = LatticeTaint.empty
  let initialize_variable _ _ ~initialized:_ _ state = state
  let initialize_variable_using_type _ _ state  = state


  (* Misc. *)

  let enter_loop _ state = state
  let incr_loop_counter _ state = state
  let leave_loop _ state = state

  let storage () = true

end


include Domain_builder.Complete (InternalTaint)
