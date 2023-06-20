(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2025                                               *)
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

open Cil_types
open Cil
open Locations

(* Must be used inlined, as Machine.theMachine is mutable
   let pointer_size_bytes = Machine.sizeof_ptr ()
   let int_size_bytes = Machine.sizeof_int ()
*)
let size_char_in_bits = 8

module Types = struct

  type state = Cvalue.Model.t
  type value = Cvalue.V.t
  type zone = Zone.t
  type slice = Cvalue.V_Offsetmap.t

  type functions_states = state Cil_datatype.Stmt.Hashtbl.t
  type map_functions_states = state Cil_datatype.Stmt.Map.t

  type state_accesser =
    | Global
    | Local of functions_states

  let map_functions_states_to_get_state m =
    fun s ->
    try Cil_datatype.Stmt.Map.find s m
    with Not_found -> Cvalue.Model.bottom

  let functions_states_to_request h stmt =
    let state =
      try Cil_datatype.Stmt.Hashtbl.find h stmt
      with Not_found -> Cvalue.Model.bottom
    in
    Results.in_cvalue_state state

  let iter_requests = function
    | Global ->
      fun stmt f ->
        let requests = Results.(before stmt |> by_callstack |> List.map snd) in
        List.iter (fun request-> f request) requests
    | Local hs ->
      fun stmt f -> f (functions_states_to_request hs stmt)

  let merge_map_non_map_functions_states map h =
    Cil_datatype.Stmt.Hashtbl.fold
      (fun stmt state m ->
         let previous =
           try Cil_datatype.Stmt.Map.find stmt m
           with Not_found -> Cvalue.Model.bottom
         in
         let join = Cvalue.Model.join previous state in
         if join != previous then Cil_datatype.Stmt.Map.add stmt join m else m
      ) h map

  let merge_map_functions_states =
    Cil_datatype.Stmt.Map.merge (Extlib.merge_opt (fun _ -> Cvalue.Model.join))



  (* -------------------------------------------------------------------------- *)
  (* --- Ids                                                                --- *)
  (* -------------------------------------------------------------------------- *)

  type pointer = Cil_types.varinfo * int

  module Pointer = struct
    include Datatype.Pair_with_collections(Cil_datatype.Varinfo)(Datatype.Int)

    let pretty fmt ((v, o) : pointer) =
      if o = 0 then
        Format.fprintf fmt "&%a" Printer.pp_varinfo v
      else
        Format.fprintf fmt "&%a+%d" Printer.pp_varinfo v o

  end

end

let typ_array_char = Cil_const.(mk_tarray ucharType None)

let pretty_slice fmt s =
  Cvalue.V_Offsetmap.pretty_generic ~typ:typ_array_char () fmt s


let location_with_size_aux p sbytes =
  Locations.loc_bytes_to_loc_bits p,
  Abstract_interp.Int.of_int (size_char_in_bits * sbytes)

let location_with_size p sbytes =
  let locb, size = location_with_size_aux p sbytes in
  Locations.make_loc locb (Int_Base.inject size)

let location_of_pointer (p : Types.pointer) =
  Location_Bytes.inject
    (Base.of_varinfo (fst p) ) (Ival.of_int (snd p))


let lval_from_pointer (v, offs) : lval =
  let loc = v.vdecl in
  let exp_var = mkAddrOrStartOf ~loc (var v) in
  let exp_offs = Cil.new_exp ~loc
      (Const (CInt64 (Integer.of_int offs, IInt, None))) in
  let exp' = new_exp ~loc (BinOp (PlusPI, exp_var, exp_offs, Cil_const.intPtrType)) in
  let lval = mkMem ~addr:exp' ~off:NoOffset in
  lval


let read_int_pointer p state =
  let p = location_of_pointer p in
  let p = location_with_size p (Machine.sizeof_int ()) in
  Cvalue.Model.find state p

(* TODO: restore warnings *)
let read_slice ~p ~sbytes state =
  let loc_bits, size = location_with_size_aux p sbytes in
  match Cvalue.Model.copy_offsetmap loc_bits size state with
  | `Bottom ->
    assert (Cvalue.Model.equal state Cvalue.Model.bottom);
    MtOptions.fatal "Reading inside bottom state"
  | `Value offs -> offs

let write_int_pointer p i state =
  let sbytes = Machine.sizeof_int ()
  and value = Location_Bytes.inject Base.null (Ival.of_int i) in
  let pointer = location_of_pointer p in
  let p = location_with_size pointer sbytes in
  MtOptions.debug ~level:3 "# Write %a at %a, size %d bytes"
    Cvalue.V.pretty value Locations.pretty p sbytes;
  Cvalue.Model.add_binding ~exact:true state p value

let replace_value_at_int_pointer p ~before ~after state =
  let sbytes = Machine.sizeof_int () in
  let value_after = Location_Bytes.inject Base.null (Ival.of_int after) in
  let value_before = Location_Bytes.inject Base.null (Ival.of_int before) in
  let pointer = location_of_pointer p in
  let p = location_with_size pointer sbytes in
  let cur = Cvalue.Model.find ~conflate_bottom:true state p in
  if Location_Bytes.equal cur value_before then
    Cvalue.Model.add_binding ~exact:true state p value_after
  else
  if Location_Bytes.is_included value_before cur then
    let v = Cvalue.V.(join (diff_if_one cur value_before) value_after) in
    Cvalue.Model.add_binding ~exact:true state p v
  else
    state

let write_slice ~p ~sbytes ~slice ~exact state =
  let pointer = Locations.loc_bytes_to_loc_bits (location_of_pointer p) in
  Cvalue.Model.paste_offsetmap
    ~from:slice ~dst_loc:pointer
    ~size:(Abstract_interp.Int.of_int (sbytes * size_char_in_bits))
    ~exact
    state

let extract_fun value =
  try
    let b, _ = Location_Bytes.find_lonely_key value in
    (match b with
     | Base.Var (v, _)  ->
       (try
          let f = Globals.Functions.get v in
          (match f.fundec with
           | Definition (_, _) -> `Success f
           | Declaration (_, f, _, _) ->
             `Failure (fun fmt -> Format.fprintf fmt
                          "Missing@ definition@ for function@ '%s'." f.vname))
        with Not_found ->
          `Failure (fun fmt -> Format.fprintf fmt
                       "Expected@ pointer to@ function,@ received@ \
                        non-function@ value %a." Base.pretty b))
     | _ -> raise Not_found)
  with Not_found -> (* find_loneley_key + above *)
    `Failure (fun fmt -> Format.fprintf fmt
                 "Expected@ pointer@ to function,@ received %a."
                 Cvalue.V.pretty value)

let extract_pointer value =
  try
    let b, i = Location_Bytes.find_lonely_key value in
    (match b with
     | Base.Var (v, _) | Base.Allocated (v, _, _) ->
       (try
          `Success (v, Abstract_interp.Int.to_int_exn (Ival.project_int i))
        with Ival.Not_Singleton_Int ->
          `Failure (fun fmt -> Format.fprintf fmt "Not@ a@ correct@ \
                                                   pointer@, incorrect@ offset: %a" Ival.pretty i)
       )

     | _ -> raise Not_found)
  with Not_found -> (* find_loneley_key + above *)
    `Failure (fun fmt -> Format.fprintf fmt "Not@ a@ correct@ \
                                             pointer '%a'@ (should be@ variable+offset)"
                 Cvalue.V.pretty value)

let extract_int value =
  try
    let b, i = Location_Bytes.find_lonely_key value in
    (match b with
     | Base.Null ->
       (try
          `Success (Abstract_interp.Int.to_int_exn (Ival.project_int i))
        with Ival.Not_Singleton_Int ->
          `Failure (fun fmt -> Format.fprintf fmt "Non-integer value: %a"
                       Ival.pretty i)
       )

     | _ -> raise Not_found)
  with Not_found -> (* find_loneley_key + above *)
    `Failure (fun fmt -> Format.fprintf fmt "Non-integer value: %a"
                 Cvalue.V.pretty value)

let extract_int_possibly_zero value =
  try
    let b, i = Location_Bytes.find_lonely_key value in
    (match b with
     | Base.Null ->
       let fail =
         `Failure (fun fmt -> Format.fprintf fmt "Non-integer value: %a"
                      Ival.pretty i)
       in
       (try
          ignore (Ival.cardinal_less_than i 3);
          (match Ival.fold_int (fun i l -> i :: l) i [] with
           | [v] -> `Success (Abstract_interp.Int.to_int_exn v, `Exact)
           | [v1; v2] -> (* Sorted in reverse direction *)
             let v1 = Abstract_interp.Int.to_int_exn v1 in
             let v2 = Abstract_interp.Int.to_int_exn v2 in
             if v2 = 0 then `Success (v1, `WithZero)
             else fail
           | [] | _ :: _ :: _ :: _ -> fail
          )
        with Abstract_interp.Error_Top | Abstract_interp.Not_less_than -> fail)
     | _ -> raise Not_found)
  with Not_found -> (* find_loneley_key + above *)
    `Failure (fun fmt -> Format.fprintf fmt "Non-integer value: %a"
                 Cvalue.V.pretty value)


let extract_non_wide_string cstr =
  match cstr with
  | Base.CSString s -> `Success s
  | Base.CSWstring s ->
    `Failure (fun fmt -> Format.fprintf fmt
                 "Wide string not supported (string@ '%s')"
                 (Escape.escape_wstring s))


let extract_constant_string value =
  try
    match Location_Bytes.fold_i (fun b i l -> (b,i) :: l) value [] with
    | [Base.String (_, e), i] when Ival.is_zero i ->
      extract_non_wide_string e

    | _ ->
      `Failure (fun fmt -> Format.fprintf fmt
                   "When decoding string, incorrect value@ '%a'"
                   Cvalue.V.pretty value)
  with e ->
    `Failure (fun fmt -> Format.fprintf fmt "Not a correct string '%a'@. \
                                             Conversion raised %s"
                 Cvalue.V.pretty value (Printexc.to_string e))



(* *)

let clear_non_globals =
  Cvalue.Model.filter_base (fun v -> not (Base.is_any_formal_or_local v))


(* *)

let join_state s1 s2 =
  let r = Cvalue.Model.join s2 s1 in
  r, Cvalue.Model.equal r s1 = false

let join_value v1 v2 =
  let r = Cvalue.V.join v1 v2 in
  r, Cvalue.V.equal r v1 = false

let rec join_params l1 l2 = match l1, l2 with
  | [], [] -> ([], false)
  | [], l | l, [] ->
    MtOptions.warning "Joining parameters lists of different lengths";
    (l, true)
  | x::xs , y::ys ->
    let v, recv = join_value x y and lv, recl = join_params xs ys in
    v :: lv, recv || recl

let join_zone z1 z2 =
  let r = Zone.join z1 z2 in
  r, Zone.equal r z1 = false


(* *)

let is_frama_c_var v =
  String.starts_with ~prefix:"__FRAMAC_MTHREAD" v.vname

let is_frama_c_base = function
  | Base.Var (v, _) | Base.Allocated (v, _, _) -> is_frama_c_var v
  | _ -> false

let remove_frama_c_var_from_zone =
  Zone.filter_base (fun b -> not (is_frama_c_base b))

let remove_frama_c_var_from_mem  =
  Cvalue.Model.filter_base (fun b -> not (is_frama_c_base b))


let int_to_value i = Cvalue.V.inject_ival (Ival.of_int i)
