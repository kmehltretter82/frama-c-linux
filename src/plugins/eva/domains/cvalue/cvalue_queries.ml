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

module Queries = struct

  type state = Cvalue.Model.t
  type context = unit
  type value = Main_values.CVal.t
  type location = Main_locations.PLoc.location

  (* The origin is the value stored in the state for a lvalue, when this value
     has a type incompatible with the type of the lvalue. This may happen on
     union with fields of different types, or on code pattern such as
       int x = v; float f = *(float* )&x
     In this case, the value stored in the state and the value computed for the
     lvalue can be incomparable. The origin is then used to store the value from
     the state, to later choose which value to keep. This is done by the update
     function in cvalue_transfer. *)
  type origin = value

  let extract_expr ~oracle:_ _context _state _expr =
    `Value (Cvalue.V.top, None), Alarmset.all

  let indeterminate_alarms lval v =
    let open Cvalue.V_Or_Uninitialized in
    let status =
      if Cvalue.V.is_bottom (get_v v) then Alarmset.False else Alarmset.Unknown
    in
    match v with
    | C_uninit_noesc _ -> Alarmset.singleton ~status (Alarms.Uninitialized lval)
    | C_init_esc _     -> Alarmset.singleton ~status (Alarms.Dangling lval)
    | C_uninit_esc _   ->
      (* Unknown alarms: [v] can be either dangling or uninit *)
      Alarmset.(set (Alarms.Dangling lval) Unknown
                  (set (Alarms.Uninitialized lval) Unknown none))
    | C_init_noesc _   -> Alarmset.none


  let eval_one_loc state lval typ =
    let eval_one_loc single_loc =
      let v = Cvalue.Model.find_indeterminate state single_loc in
      Cvalue.V_Or_Uninitialized.get_v v, indeterminate_alarms lval v
    in
    (* We have no good neutral element for "no alarm emitted yet", so we use
       [None] instead. *)
    let join_alarms acc alarms =
      match acc with
      | None -> Some alarms
      | Some acc -> Some (Alarmset.union alarms acc)
    in
    fun loc (acc_result, acc_alarms) ->
      let result, alarms = eval_one_loc loc in
      let result = Cvalue_forward.make_volatile ~typ:typ result in
      Cvalue.V.join result acc_result, join_alarms acc_alarms alarms

  (* The zero singleton is shared between float and integer representations in
     ival, and is thus untyped. *)
  let is_float v =
    Cvalue.V.(is_included v top_float) && Cvalue.V.contains_non_zero v

  let read_garbled_mix = function
    | Cvalue.V.Top (bases, origin) -> Origin.register_read bases origin
    | _ -> ()

  let extract_scalar_lval state lval typ loc =
    let process_one_loc = eval_one_loc state lval typ in
    let acc = Cvalue.V.bottom, None in
    let value, alarms = Precise_locs.fold process_one_loc loc acc in
    let alarms = match alarms with None -> Alarmset.none | Some a -> a in
    (* The origin is set to false when the value stored in the memory has not
       the same type as the read lvalue. In this case, we don't update the state
       with the new value stemming from the evaluation, even if it has been
       reduced, in order to not propagate incompatible type. *)
    let incompatible_type = is_float value <> Cil.isFloatingType typ in
    let origin = if incompatible_type then Some value else None in
    let value = Cvalue_forward.reinterpret typ value in
    read_garbled_mix value;
    if Cvalue.V.is_bottom value
    then `Bottom, alarms
    else `Value (value, origin), alarms

  (* Imprecise version for aggregate types that cvalues are unable to precisely
     represent. The initialization alarms must remain sound, though. *)
  let extract_aggregate_lval state lval _typ ploc =
    let loc = Precise_locs.imprecise_location ploc in
    match loc.Locations.size with
    | Int_Base.Top -> `Value (Cvalue.V.top, None), Alarmset.all
    | Int_Base.Value size ->
      let offsm = Cvalue.Model.copy_offsetmap loc.Locations.loc size state in
      match offsm with
      | `Bottom -> `Bottom, Alarmset.none
      | `Value offsm ->
        let value = Cvalue.V_Offsetmap.find_imprecise_everywhere offsm in
        let alarms = indeterminate_alarms lval value in
        let v = Cvalue.V_Or_Uninitialized.get_v value in
        read_garbled_mix v;
        let v = if Cvalue.V.is_bottom v then `Bottom else `Value (v, None) in
        v, alarms

  let extract_lval ~oracle:_ _context state lval typ loc =
    if Cil.isArithmeticOrPointerType typ
    then extract_scalar_lval state lval typ loc
    else extract_aggregate_lval state lval typ loc

  let backward_location state _lval typ precise_loc value =
    let size = Precise_locs.loc_size precise_loc in
    let upto = succ (Int_set.get_small_cardinal()) in
    let loc = Precise_locs.imprecise_location precise_loc in
    let eval_one_loc single_loc =
      let v = Cvalue.Model.find state single_loc in
      let v = Cvalue_forward.make_volatile ~typ v in
      Cvalue_forward.reinterpret typ v
    in
    let process_ival base ival (acc_loc, acc_val as acc) =
      let loc_bits = Locations.Location_Bits.inject base ival in
      let single_loc = Locations.make_loc loc_bits size in
      let v = eval_one_loc single_loc in
      if Cvalue.V.intersects v value
      then Locations.Location_Bits.join loc_bits acc_loc, Cvalue.V.join v acc_val
      else acc
    in
    let fold_ival base ival acc =
      if Ival.cardinal_is_less_than ival upto
      then Ival.fold_enum (process_ival base) ival acc
      else process_ival base ival acc
    in
    let fold_location loc acc =
      try
        let loc = loc.Locations.loc in
        Locations.Location_Bits.fold_i fold_ival loc acc
      with
        Abstract_interp.Error_Top -> loc.Locations.loc, value
    in
    let acc = Locations.Location_Bits.bottom, Cvalue.V.bottom in
    let loc_bits, value = fold_location loc acc in
    if Locations.Location_Bits.is_bottom loc_bits
    then `Bottom
    else
      let loc = Precise_locs.inject_location_bits loc_bits in
      `Value (Precise_locs.make_precise_loc loc ~size, value)

  let reduce_further _state _expr _value = []
  let build_context _ = `Value ()
end

include Queries

(* -------------------------------------------------------------------------- *)
(*                Evaluation engine for the cvalue domain                     *)
(* -------------------------------------------------------------------------- *)

module Value = struct
  module Internal = struct
    include Main_values.CVal
    let structure = Abstract.Value.Leaf (key, (module Main_values.CVal))
  end
  include Internal
  include Structure.Open (Abstract.Value) (Internal)
  let reduce t = t
end

module Domain = struct
  include Cvalue.Model
  include Queries
end

include Evaluation.Make (Unit_context) (Value) (Main_locations.PLoc) (Domain)

let lval_to_loc state lval =
  let eval, _alarms = lvaluate ~for_writing:false state lval in
  match eval with
  | `Bottom -> Locations.loc_bottom
  | `Value (_valuation, ploc, _typ) -> Precise_locs.imprecise_location ploc
