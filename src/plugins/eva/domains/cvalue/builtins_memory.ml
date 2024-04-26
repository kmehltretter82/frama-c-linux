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

open Cil_types
open Cvalue
open Abstract_interp
open Locations

let register_builtin name ?replace builtin =
  Builtins.register_builtin name ?replace Cacheable builtin

let dkey = Self.register_category "imprecision"

let rec lval_of_address exp =
  match exp.enode with
  | AddrOf lval -> lval
  | CastE (_typ, exp) -> lval_of_address exp
  | _ -> Cil.mkMem ~addr:exp ~off:Cil_types.NoOffset

let plevel = Parameters.ArrayPrecisionLevel.get

(* Create a dependency [\from arg_n] where n is the nth argument of the
   currently called function. *)
let deps_nth_arg n =
  let kf = Callstack.top_kf (Eva_utils.current_call_stack ()) in
  try
    let vi = List.nth (Kernel_function.get_formals kf) n in
    Deps.add_data Deps.bottom (Locations.zone_of_varinfo vi)
  with Failure _ -> Kernel.fatal "%d arguments expected" n

(* Preconditions of memcpy, memmove and memset ensures that pointer arguments
   are valid. Reduce them accordingly. *)
let reduce_to_valid_loc dst size access =
  let min_size = Ival.min_int size in
  let size = Option.fold ~none:Int_Base.zero ~some:Int_Base.inject min_size in
  let dst_loc = Locations.make_loc dst size in
  let valid_dst_loc = Locations.valid_part ~bitfield:false access dst_loc in
  valid_dst_loc.Locations.loc

(* -------------------------------------------------------------------------- *)
(*                             Memcpy & Memmove                               *)
(* -------------------------------------------------------------------------- *)

(*  Warns when the value is indeterminate. *)
let warn_indeterminate_value ~name ?(precise = false) = function
  | V_Or_Uninitialized.C_init_noesc _ -> ()
  | _ ->
    Self.result ~dkey ~current:true ~once:true
      "@[In %s builtin:@ %sprecise copy@ of indeterminate values.@]%t"
      name (if precise then "" else "im") Eva_utils.pp_callstack

(*  Warns when the offsetmap contains an indeterminate value. *)
let check_indeterminate_offsetmap ~name offsm =
  if Self.is_debug_key_enabled dkey then
    let warn _ (v, _, _) = warn_indeterminate_value ~name ~precise:true v in
    V_Offsetmap.iter warn offsm

(* Adds \from dependency from [src_loc] to [dst_loc]. *)
let add_deps_loc ~exact ~src_loc ~dst_loc deps_table =
  let src_zone = Locations.(enumerate_valid_bits Read src_loc) in
  let dst_zone = Locations.(enumerate_valid_bits Write dst_loc) in
  let deps = Deps.(add_data bottom src_zone) in
  Assigns.Memory.add_binding ~exact deps_table dst_zone deps

(* Adds a sure \from dependency of size [size] from [src] to [dst].
   Also returns the written zone if it is a singleton. *)
let add_sure_deps ~size ~src ~dst (deps_table, sure_output) =
  let size = Int_Base.inject size in
  let src_loc = Locations.make_loc src size in
  let dst_loc = Locations.make_loc dst size in
  let exact = Location_Bits.cardinal_zero_or_one dst in
  let deps_table = add_deps_loc ~exact ~src_loc ~dst_loc deps_table in
  let dst_zone = Locations.(enumerate_valid_bits Write dst_loc) in
  let sure_zone = if exact then dst_zone else Zone.bottom in
  deps_table, Zone.join sure_zone sure_output

(* Copy the offsetmap of size [size] from [src] to [dst] in [state]. *)
let copy_offsetmap ~name ~exact ~size ~src ~dst ~dst_lval state =
  match Cvalue.Model.copy_offsetmap src size state with
  | `Bottom -> Cvalue.Model.bottom
  | `Value offsetmap ->
    check_indeterminate_offsetmap ~name offsetmap;
    let prefix = "Builtin " ^ name in
    Cvalue_transfer.warn_imprecise_offsm_write ~prefix dst_lval offsetmap;
    Cvalue.Model.paste_offsetmap ~from:offsetmap ~dst_loc:dst ~size ~exact state

(* Returns the min and max size of a copy from an Ival.t. *)
let min_max_size size =
  let min, max = Ival.min_and_max size in
  let min = Option.fold min ~none:Int.zero ~some:Int.(max zero) in
  let max_max = Bit_utils.max_bit_size () in
  let max = Option.fold max ~none:max_max ~some:Int.(max zero) in
  min, max

(* Computes the remaining [src], [dst] and [size] to be copied after [factor]
   bits have already been copied. *)
let shift ~factor:i src dst size =
  let new_size = Int.sub size i in
  let ival = Ival.inject_singleton i in
  let new_src = Location_Bits.shift ival src in
  let new_dst = Location_Bits.shift ival dst in
  new_src, new_dst, new_size

(* Performs the remaining copy from [src] to [dst] for all other possible [size],
   after the copy for the minimum size has already been done.
   Iterates on all possible values of [size] (after the first), and does the
   copy for [previous_size..size]. *)
let copy_remaining_size_by_size ~name ~src ~dst ~dst_lval ~size state =
  let exception Result of Cvalue.Model.t in
  let do_size size (state, previous_size) =
    (* First iteration: this copy has already been performed, skip. *)
    if Int.(equal previous_size minus_one)
    then state, size
    else
      (* Copy data between [previous_size] and [size]. *)
      let src, dst, size = shift ~factor:previous_size src dst size in
      (* [exact] is false as all these copies may not happen according to the
          concrete value of [size]. *)
      let exact = false in
      let new_state = copy_offsetmap ~name ~exact ~size ~src ~dst ~dst_lval state in
      (* If this copy failed, the current size is completely invalid, and so
         will be the following ones. Stop now with the previous state. *)
      if not (Cvalue.Model.is_reachable new_state) then raise (Result state);
      new_state, size
  in
  try fst (Ival.fold_int do_size size (state, Int.minus_one))
  with Result state -> state

(* Copy the value at location [src_loc] to location [dst_loc] in [state]. *)
let imprecise_copy ~name ~src_loc ~dst_loc ~dst_lval state =
  Self.debug ~dkey ~once:true ~current:true
    "In %s builtin: too many sizes to enumerate, possible loss of precision"
    name;
  (* conflate_bottom:false as we want to copy padding bits *)
  let v = Model.find_indeterminate ~conflate_bottom:false state src_loc in
  warn_indeterminate_value ~name v;
  let value = Cvalue.V_Or_Uninitialized.get_v v in
  let prefix = "Builtin " ^ name in
  Cvalue_transfer.warn_imprecise_write ~prefix dst_lval dst_loc value;
  let new_state =
    Cvalue.Model.add_indeterminate_binding ~exact:false state dst_loc v
  in
  (* Beware that all sizes may be invalid, in which case [add_binding] will
     return [bottom]. In this case, return the previously computed state *)
  if Model.is_reachable new_state then new_state else state

(* Creates the location {loc + [0..max_size-1]} of size char. *)
let char_location loc max_size =
  let size_char = Bit_utils.sizeofchar () in
  let max = Int.sub max_size size_char in
  (* Use ranges modulo char_bits to read and write byte-by-byte, which can
     preserve some precision.*)
  let shift =
    Ival.inject_interval ~min:(Some Int.zero) ~max:(Some max)
      ~rem:Int.zero ~modu:size_char
  in
  let loc = Location_Bits.shift shift loc in
  make_loc loc (Int_Base.inject size_char)

let compute_memcpy ~name ~dst_lval ~dst ~src ~size state =
  let size_min, size_max = min_max_size size in
  (* Empty \from dependencies and sure output *)
  let empty_deps = Assigns.Memory.empty, Zone.bottom in
  (* First step: copy the bits we are sure to copy, i.e. for the minimum size
     [size_min] if it is not zero. *)
  let state, (deps_table, written_zone) =
    if Int.gt size_min Int.zero
    then
      let state =
        copy_offsetmap ~name ~exact:true ~size:size_min ~src ~dst ~dst_lval state
      in
      (* If the copy succeeded, update \from dependencies and sure output. *)
      if Cvalue.Model.is_reachable state
      then state, add_sure_deps ~size:size_min ~src ~dst empty_deps
      else state, empty_deps
    else state, empty_deps
  in
  (* Stop here if the first copy failed or if there is nothing more to copy. *)
  if not (Cvalue.Model.is_reachable state) || Int.equal size_min size_max
  then state, deps_table, written_zone
  else
    (* Second step: size is imprecise, we will now copy some bits that we are
       not sure to copy, for all possible sizes greater than [size_min]. *)
    (* [size_min] bits have already been copied. *)
    let src_shift, dst_shift, size_diff = shift ~factor:size_min src dst size_max in
    (* Remaining locations to be read/written, as locations of char size. *)
    let src_loc = char_location src_shift size_diff
    and dst_loc = char_location dst_shift size_diff in
    let deps_table = add_deps_loc ~exact:false ~src_loc ~dst_loc deps_table in
    (* If there is sufficiently few possible sizes, iter on each possible size
       via [copy_remaining_size_by_size]. Otherwise, use [imprecise_copy] in one
       step to read the entire range src+(size_min..size_max-1) as one byte, and
       write the result as one byte in dst+(size_min..size_max-1). *)
    let state =
      if Ival.cardinal_is_less_than size (plevel () / 10)
      then copy_remaining_size_by_size ~name ~src ~dst ~dst_lval ~size state
      else imprecise_copy ~name ~src_loc ~dst_loc ~dst_lval state
    in
    state, deps_table, written_zone

let frama_c_memcpy name state actuals =
  match actuals with
  | [(dst_exp, dst_cvalue); (_src_exp, src_cvalue); (_size_exp, size_cvalue)] ->
    let dst_lval = lval_of_address dst_exp in
    let size =
      try Cvalue.V.project_ival size_cvalue
      with Cvalue.V.Not_based_on_null -> Ival.top (* TODO: use size_t *)
    in
    (* Convert locations and size into bits. *)
    let size = Ival.scale (Bit_utils.sizeofchar ()) size in
    let src = loc_bytes_to_loc_bits src_cvalue in
    let dst = loc_bytes_to_loc_bits dst_cvalue in
    (* Remove invalid locations. *)
    let src = reduce_to_valid_loc src size Locations.Read in
    let dst = reduce_to_valid_loc dst size Locations.Write in
    (* Do the copy. *)
    let state, memory, sure_output =
      compute_memcpy ~name ~dst_lval ~dst ~src ~size state
    in
    (* Build the builtin results. *)
    let return = deps_nth_arg 0 in
    let froms = Assigns.{ memory; return } in
    let c_assigns = Some (froms, sure_output) in
    let return, c_clobbered =
      if Model.is_reachable state then
        (* Copy at least partially succeeded *)
        Some dst_cvalue, Builtins.clobbered_set_from_ret state dst_cvalue
      else
        None, Base.SetLattice.bottom
    in
    Builtins.Full { c_values = [ return, state ]; c_clobbered; c_assigns }
  | _ -> raise (Builtins.Invalid_nb_of_args 3)

let () =
  register_builtin ~replace:"memcpy" "Frama_C_memcpy" (frama_c_memcpy "memcpy");
  register_builtin ~replace:"memmove" "Frama_C_memmove" (frama_c_memcpy "memmove")

(* -------------------------------------------------------------------------- *)
(*                                  Memset                                    *)
(* -------------------------------------------------------------------------- *)

(*  Implementation of [memset] that accepts imprecise arguments. *)
let frama_c_memset_imprecise state dst_lval dst v size =
  let prefix = "Builtin memset" in
  let size_min, size_max = min_max_size size in
  (* Write [v] everywhere that might be written, ie between
     [dst] and [dst+size-1]. *)
  let state, over_zone =
    if Int.gt size_max Int.zero then
      let loc = char_location dst size_max in
      Cvalue_transfer.warn_imprecise_write ~prefix dst_lval loc v;
      let state = Cvalue.Model.add_binding ~exact:false state loc v in
      let written_zone = enumerate_valid_bits Locations.Write loc in
      state, written_zone
    else state, Zone.bottom
  in
  (* Write "sure" bytes in an exact way: they exist only if there is only
     one base, and within it, size_min+leftmost_loc > rightmost_loc *)
  let state, sure_zone =
    try
      let base, offset = Location_Bits.find_lonely_key dst in
      let minb, maxb = match Ival.min_and_max offset with
        | Some minb, Some maxb -> minb, maxb
        | _ -> raise Not_found
      in
      let sure = Int.sub (Int.add minb size_min) maxb in
      if Int.gt sure Int.zero then
        let dst_loc = Location_Bits.inject base (Ival.inject_singleton maxb) in
        let vuninit = V_Or_Uninitialized.initialized v in
        let size_v = Bit_utils.sizeofchar () in
        let from = V_Offsetmap.create ~size:sure vuninit ~size_v in
        Cvalue_transfer.warn_imprecise_offsm_write ~prefix dst_lval from;
        let state =
          Cvalue.Model.paste_offsetmap
            ~from ~dst_loc ~size:sure ~exact:true state
        in
        let sure_loc = make_loc dst_loc (Int_Base.inject sure) in
        let sure_zone = enumerate_valid_bits Locations.Write sure_loc in
        state, sure_zone
      else
        state, Zone.bottom
    with Not_found -> state, Zone.bottom (* from find_lonely_key + explicit raise *)
  in
  state, sure_zone, over_zone

(* Type that describes why the 'precise memset' builtin may fail. *)
type imprecise_memset_reason =
  | UnsupportedType
  | ImpreciseTypeSize
  | NoTypeForDest
  | NotSingletonLoc
  | SizeMismatch
  | ImpreciseValue
  | ImpreciseSize
  | NegativeOrNullSize (* The zero case is licit, but it is simpler to handle
                          through the imprecise builtin. See bts #1799 *)

exception ImpreciseMemset of imprecise_memset_reason

let imprecision_descr = function
  | UnsupportedType -> "destination has an unknown type"
  | ImpreciseTypeSize -> "destination has a type with unknown size"
  | NoTypeForDest -> "destination has an unknown form"
  | NotSingletonLoc -> "destination is not exact"
  | SizeMismatch -> "destination type and size differ"
  | ImpreciseValue -> "value to write is imprecise"
  | ImpreciseSize -> "size is imprecise"
  | NegativeOrNullSize -> "size is negative or null"


(*  [memset_typ_offsm typ i] returns an offsetmap of size [sizeof(typ)]
    that maps each byte to the integer [i]. The shape of the type is
    respected: the fields in [typ] are bound to values of the good type,
    not just to 'i%repeated modulo 8'. May raise ImpreciseMemset. *)
let memset_typ_offsm_int full_typ i =
  try
    let size = Int.of_int (Cil.bitsSizeOf full_typ) in
    let vi = V_Or_Uninitialized.initialized (Cvalue.V.inject_int i) in
    let size_char = Bit_utils.sizeofchar () in
    let full_offsm = V_Offsetmap.create ~size vi ~size_v:size_char in
    if Int.is_zero i then
      full_offsm (* Shortcut: no need to follow the type, this offsetmap is
                    optimally precise *)
    else
      let validity = Base.validity_from_size size in
      let rec aux styp offset offsm =
        (* Read [full_offsm] between [offset] and [offset+size-1], and return
           the value stored there. *)
        let find size =
          V_Offsetmap.find ~validity
            ~offsets:(Ival.inject_singleton offset) ~size full_offsm
        in
        (* Update [full_offsm] between [offset] and [offset+size-1], and store
           exactly [v] there *)
        let update size v =
          let bounds = (offset, Int.(pred (add offset size))) in
          let vinit = V_Or_Uninitialized.initialized v in
          V_Offsetmap.add bounds (vinit, size, Rel.zero) offsm
        in
        match Cil.unrollType styp with
        | TInt _ | TEnum _ | TPtr _ ->
          let size = Eval_typ.sizeof_lval_typ styp (* handles bitfields *) in
          let size = Int_Base.project size in
          let v = V_Or_Uninitialized.get_v (find size) in
          let signed = Bit_utils.is_signed_int_enum_pointer styp in
          let v = Cvalue.V.cast_int_to_int ~size ~signed v in
          update size v
        | TFloat _ ->
          let size = Int.of_int (Cil.bitsSizeOf styp) in
          let v = V_Or_Uninitialized.get_v (find size) in
          let v' = Cvalue_forward.reinterpret styp v in
          let f = Ival.project_float (Cvalue.V.project_ival v') in
          (* Do not produce NaN or infinites here (unless they are accepted
             by the engine). *)
          if Fval.is_finite f = True then update size v' else update size v
        | TComp ({ cstruct = true ; cfields = l}, _) -> (* struct *)
          let aux_field offsm fi =
            let offset_fi = Int.of_int (fst (Cil.fieldBitsOffset fi)) in
            aux fi.ftype (Int.add offset offset_fi) offsm
          in
          List.fold_left aux_field offsm (Option.value ~default:[] l)
        | TComp ({ cstruct = false ; cfields = l}, _) -> (* union *)
          (* Use only the first field. This is somewhat arbitrary *)
          aux (List.hd (Option.get l)).ftype offset offsm
        | TArray (typelt, nb, _) -> begin
            let nb = Cil.lenOfArray64 nb in (* always succeeds, we computed the
                                               size of the entire type earlier *)
            if Integer.(gt nb zero) then begin
              let sizeelt = Int.of_int (Cil.bitsSizeOf typelt) in
              (* Do the first cell *)
              let offsm' = aux typelt offset offsm in
              if Integer.(gt nb one) then begin
                (* Copy the result *)
                let src = Ival.inject_singleton offset in
                let copy =
                  V_Offsetmap.copy_slice
                    ~validity ~offsets:src ~size:sizeelt offsm'
                in
                (* Paste on all offsets > 1 *)
                let dst =
                  let idx =
                    Ival.inject_range (Some Int.one) (Some (Int.pred nb))
                  in
                  let idx_size = Ival.scale sizeelt idx in
                  Ival.add_singleton_int offset idx_size
                in
                match copy with
                | `Bottom -> assert false (* the copy is within bounds *)
                | `Value copy ->
                  let r =
                    V_Offsetmap.paste_slice ~validity
                      ~exact:true ~from:copy ~size:sizeelt ~offsets:dst offsm'
                  in
                  match r with
                  | `Bottom -> assert false (* so is the write *)
                  | `Value r -> r
              end
              else offsm' (* size = 1 *)
            end
            else offsm (* size = 0. Do nothing, this is supposed to be invalid
                          anyway *)
          end
        | TVoid _ | TFun _ | TBuiltin_va_list _ ->
          raise (ImpreciseMemset UnsupportedType)
        | TNamed _ -> assert false (* unrolled *)
      in
      aux full_typ Int.zero full_offsm
  with Cil.SizeOfError _ | Abstract_interp.Error_Top ->
    raise (ImpreciseMemset ImpreciseTypeSize)

(*  Type-aware memset on an entire type. Same as [memset_typ_offsm_int], but
    with a [Cvalue.V] instead of an integer. We accept [-ilevel] different
    possible values in [v] before falling back to the imprecise memset.
    May raise {!ImpreciseMemset}.  *)
let memset_typ_offsm typ v =
  try
    let i = V.project_ival v in
    ignore (Ival.cardinal_less_than i (Int_set.get_small_cardinal ()));
    let aux_i i offsm =
      let offsm_i = memset_typ_offsm_int typ i in
      match offsm with
      | None -> Some offsm_i
      | Some o -> Some (Cvalue.V_Offsetmap.join o offsm_i)
    in begin
      match Ival.fold_int aux_i i None with
      | None -> (* v == Ival.bottom *)
        raise (ImpreciseMemset ImpreciseValue)
      | Some o -> o
    end
  with V.Not_based_on_null | Not_less_than ->
    raise (ImpreciseMemset ImpreciseValue)

(*  Precise memset builtin, that requires its arguments to be sufficiently
    precise abstract values. *)
let frama_c_memset_precise state dst_lval dst v (exp_size, size) =
  try
    (* We want an exact size, Otherwise, we can use the imprecise memset as a
       fallback *)
    let size = Ival.project_int size in
    (* Extract the location, check that it is precise. *)
    if Location_Bits.(is_bottom dst || not (cardinal_zero_or_one dst)) then
      raise (ImpreciseMemset NotSingletonLoc);
    if not (Int.gt size Int.zero) then
      raise (ImpreciseMemset NegativeOrNullSize);
    (* Now, try to find a type that matches [size]. *)
    let typ =
      (* If [exp_size] is a sizeof, use this type. *)
      let rec find_sizeof e = match e.enode with
        | SizeOf typ -> Some typ
        | SizeOfE e -> Some (Cil.typeOf e)
        | CastE (_, e) -> find_sizeof e
        | _ -> None
      in
      match find_sizeof exp_size with
      | Some typ -> typ
      | None ->
        (* No such luck. Use the base and the offset of [dst] to resynthesize
           a type *)
        let base_dst, offset_dst = Location_Bits.find_lonely_binding dst in
        let offset = Ival.project_int offset_dst in
        let vi_dst = Base.to_varinfo base_dst in
        let mo = Bit_utils.MatchSize size in
        snd (Bit_utils.(find_offset vi_dst.vtype ~offset mo))
    in
    let offsm = memset_typ_offsm typ v in
    let prefix = "Builtin memset" in
    Cvalue_transfer.warn_imprecise_offsm_write ~prefix dst_lval offsm;
    let state =
      Cvalue.Model.paste_offsetmap
        ~from:offsm ~dst_loc:dst ~size ~exact:true state
    in
    let dst_location = Locations.make_loc dst (Int_Base.Value size) in
    let dst_zone = Locations.(enumerate_valid_bits Write dst_location) in
    state, dst_zone, dst_zone
  with
  | Bit_utils.NoMatchingOffset -> raise (ImpreciseMemset SizeMismatch)
  | Base.Not_a_C_variable -> raise (ImpreciseMemset NoTypeForDest)
  | Cil.SizeOfError _ -> raise (ImpreciseMemset ImpreciseTypeSize)
  | Ival.Not_Singleton_Int | V.Not_based_on_null ->
    raise (ImpreciseMemset ImpreciseSize)

(* let () = register_builtin "Frama_C_memset_precise" frama_c_memset_precise *)

let frama_c_memset state actuals =
  match actuals with
  | [(dst_exp, dst_cvalue); (_, v); (exp_size, size_cvalue)] ->
    begin
      let dst_lval = lval_of_address dst_exp in
      let size =
        try Cvalue.V.project_ival size_cvalue
        with Cvalue.V.Not_based_on_null -> Ival.top (* TODO: use size_t *)
      in
      (* Convert locations and size into bits. *)
      let size = Ival.scale (Bit_utils.sizeofchar ()) size in
      let dst = Locations.loc_bytes_to_loc_bits dst_cvalue in
      (* Remove read-only destinations *)
      let dst = reduce_to_valid_loc dst size Locations.Write in
      (* Keep only the first byte of the value argument *)
      let _, v = Cvalue.V.extract_bits
          ~topify:Origin.Misalign_read
          ~start:Int.zero ~stop:(Int.pred (Bit_utils.sizeofchar ()))
          ~size:(Int.of_int (Cil.bitsSizeOfInt IInt))
          v
      in
      let state, sure_output, over_output =
        try frama_c_memset_precise state dst_lval dst v (exp_size, size)
        with ImpreciseMemset reason ->
          Self.debug ~dkey ~current:true
            "Call to builtin precise_memset(%a) failed; %s%t"
            Eva_utils.pretty_actuals actuals (imprecision_descr reason)
            Eva_utils.pp_callstack;
          frama_c_memset_imprecise state dst_lval dst v size
      in
      let assigns =
        let value_dep = deps_nth_arg 1 in
        let memory = Assigns.Memory.empty in
        let memory =
          Assigns.Memory.add_binding ~exact:false memory over_output value_dep
        in
        let memory =
          Assigns.Memory.add_binding ~exact:true memory sure_output value_dep
        in
        let return = deps_nth_arg 0 in
        Assigns.{ memory; return }
      in
      Builtins.Full
        { Builtins.c_values = [ Some dst_cvalue, state ];
          c_clobbered = Base.SetLattice.bottom;
          c_assigns = Some (assigns, sure_output); }
    end
  | _ -> raise (Builtins.Invalid_nb_of_args 3)

let () = register_builtin ~replace:"memset" "Frama_C_memset" frama_c_memset

(* -------------------------------------------------------------------------- *)
(*                  is_base_aligned, offset, split, ungarbled                 *)
(* -------------------------------------------------------------------------- *)

let frama_C_is_base_aligned _state = function
  | [_, x; _, y] ->
    let result =
      match Ival.project_small_set (Cvalue.V.project_ival y) with
      | Some si ->
        let aligned =
          Location_Bytes.for_all
            (fun b _o -> List.for_all (Base.is_aligned_by b) si)
            x
        in
        if aligned then Cvalue.V.singleton_one else Cvalue.V.zero_or_one
      | None
      | exception Cvalue.V.Not_based_on_null -> Cvalue.V.zero_or_one
    in
    Builtins.Result [result]
  | _ -> raise (Builtins.Invalid_nb_of_args 2)

let () = register_builtin "Frama_C_is_base_aligned" frama_C_is_base_aligned


let frama_c_offset _state = function
  | [_, x] ->
    let result =
      try
        let acc = Ival.bottom in
        let offsets = Location_Bytes.fold_i (fun _b -> Ival.join) x acc in
        Cvalue.V.inject_ival offsets
      with Abstract_interp.Error_Top ->
        Self.error ~current:true
          "Builtin Frama_C_offset is applied to a value not \
           guaranteed to be an address";
        Cvalue.V.top_int
    in
    Builtins.Result [result]
  | _ -> raise (Builtins.Invalid_nb_of_args 1)

let () = register_builtin "Frama_C_offset" frama_c_offset

let frama_c_interval_split _state actuals =
  match actuals with
  | [_,lower; _,upper] ->
    begin
      try
        let upper = Ival.project_int (Cvalue.V.project_ival upper) in
        let lower = Ival.project_int (Cvalue.V.project_ival lower) in
        let i = ref lower in
        let r = ref [] in
        while (Int.le !i upper) do
          r := Cvalue.V.inject_int !i :: !r;
          i := Int.succ !i;
        done;
        Builtins.Result !r
      with
      | Cvalue.V.Not_based_on_null
      | Ival.Not_Singleton_Int ->
        Self.abort
          "Invalid call to Frama_C_interval_split%a"
          Eva_utils.pretty_actuals actuals
    end
  | _ -> raise (Builtins.Invalid_nb_of_args 2)

let () = register_builtin "Frama_C_interval_split" frama_c_interval_split

(* Transforms a garbled mix into Top_int. Let other values unchanged.
   Remark: this currently returns an int. Maybe we need multiple versions? *)
let frama_c_ungarble _state = function
  | [_, i] ->
    if Cvalue.V.is_imprecise i
    then Builtins.Result [Cvalue.V.top_int]
    else Builtins.Result [i]
  | _ -> raise (Builtins.Invalid_nb_of_args 1)

let () = register_builtin "Frama_C_ungarble" frama_c_ungarble


(*
Local Variables:
compile-command: "make -C ../../../../.."
End:
*)
