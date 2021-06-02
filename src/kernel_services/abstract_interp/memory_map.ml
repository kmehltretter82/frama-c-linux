(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2021                                               *)
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

(* Ocaml compiler incorrectly considers that module MemorySafe is unused and
   emits a warning *)
[@@@warning "-60"]

open Abstract_offset

type size = Integer.t

type bit =
  | Zero
  | Any of Base.SetLattice.t

module Bit =
struct
  module Bases = Base.SetLattice

  type t = bit

  let top = Any Bases.top

  let numerical = Any Bases.empty

  let zero = Zero

  let hash = function
    | Zero -> 3
    | Any set -> Bases.hash set

  let equal d1 d2 =
    match d1,d2 with
    | Zero, Zero -> true
    | Zero, Any _ | Any _, Zero -> false
    | Any set1, Any set2 -> Bases.equal set1 set2

  let compare d1 d2 =
    match d1,d2 with
    | Zero, Zero -> 0
    | Zero, Any _ -> 1
    | Any _, Zero -> -1
    | Any set1, Any set2 -> Bases.compare set1 set2

  let is_included d1 d2 =
    match d1, d2 with
    | Any set1, Any set2 -> Bases.is_included set1 set2
    | Any _, Zero -> false
    | Zero, (Zero | Any _) -> true

  let join d1 d2 =
    match d1, d2 with
    | Any set1, Any set2 -> Any (Bases.join set1 set2)
    | Any set, Zero | Zero, Any set -> Any set
    | Zero, Zero -> Zero
end

module type Value =
sig
  type t

  val name : string

  val hash : t -> int
  val equal : t -> t -> bool
  val compare : t -> t -> int

  val pretty : Format.formatter -> t -> unit
  val of_bit : bit -> t
  val to_bit : t -> bit
  val is_included : t -> t -> bool
  val join: t -> t -> t
end

module type Config =
sig
  val deps : State.t list
end

module type T =
sig
  type location
  type value
  type t

  val hash : t -> int
  val equal : t -> t -> bool
  val compare : t -> t -> int

  val top : t
  val zero : t
  val is_top : t -> bool
  val get : t -> location -> value
  val extract :t -> location -> t
  val erase : weak:bool -> t -> location -> bit -> t
  val set : weak:bool -> t -> location -> value -> t
  val overwrite : weak:bool -> t -> location -> t -> t
  val reinforce : (value -> value) ->  t -> location -> t
  val is_included : t -> t -> bool
  val join : (size:size -> value -> value -> value) -> t -> t -> t
  val widen : (size:size -> value -> value -> value) -> t -> t -> t
  val pretty : Format.formatter -> t -> unit
end


module Make (Config : Config) (Value : Value) =
struct
  type location = Abstract_offset.typed_offset
  type value = Value.t

  type 'fieldmap memory =
    | Raw of bit
    | Scalar of memory_scalar
    | Struct of 'fieldmap memory_struct
    | Union of 'fieldmap memory_union
    | Array of 'fieldmap memory_array
  and memory_scalar = {
    scalar_value: Value.t;
    scalar_type: Cil_types.typ;
  }
  and 'fieldmap memory_struct = {
    struct_value: 'fieldmap;
    struct_info: Cil_types.compinfo;
    struct_padding: bit; (* for missing fields and padding *)
  }
  (* unions are handled separately from struct to avoid confusion and error *)
  and 'fieldmap memory_union = {
    union_value: 'fieldmap memory;
    union_field: Cil_types.fieldinfo;
    union_padding: bit;
  }
  and 'fieldmap memory_array = {
    array_value: 'fieldmap memory;
    array_cell_type: Cil_types.typ;
  }

  (* Datatype prototype *)

  module Prototype (
      FieldMap :
      sig
        type t
        include Hptmap_sig.S
          with type t := t
           and type key = Cil_types.fieldinfo
           and type v = t memory
      end) =
  struct
    type t = FieldMap.t memory

    let rec pretty fmt =
      let rec leading_indexes acc = function
        | Array a -> leading_indexes (() :: acc) a.array_value
        | (Raw _ | Scalar _ | Struct _ | Union _) as m -> List.rev acc, m
      in
      let pretty_index fmt () =
        Format.fprintf fmt "[..]"
      in
      let pretty_indexes fmt l =
        Pretty_utils.pp_list pretty_index fmt l
      in
      let pretty_field fmt =
        let first = ref true in
        fun fi m ->
          if not !first then Format.fprintf fmt ",@;<1 2>";
          first := false;
          let indexes, sub = leading_indexes [] m in
          Format.fprintf fmt "@[<hv>.%s%a = %a@]"
            fi.Cil_types.fname
            pretty_indexes indexes
            pretty sub
      in
      function
      | Raw b ->
        begin match b with
          | Zero -> Format.fprintf fmt "0"
          | Any (Set set) when Base.SetLattice.O.is_empty set ->
            Format.fprintf fmt "[--..--]"
          | Any _ -> Format.fprintf fmt "T"
        end
      | Scalar {scalar_value} -> Value.pretty fmt scalar_value
      | Struct s ->
        Format.fprintf fmt "{@;<1 2>";
        FieldMap.iter (pretty_field fmt) s.struct_value;
        Format.fprintf fmt "@ }";
      | Union u ->
        Format.fprintf fmt "{@;<1 2>%t@ }"
          (fun fmt -> pretty_field fmt u.union_field u.union_value)
      | Array a ->
        let indexes, sub = leading_indexes [()] a.array_value in
        Format.fprintf fmt "%a = %a"
          pretty_indexes indexes
          pretty sub

    let rec hash = function
      | Raw b -> Bit.hash b
      | Scalar s -> Hashtbl.hash (
          Value.hash s.scalar_value,
          Cil_datatype.Typ.hash s.scalar_type)
      | Struct s -> Hashtbl.hash (
          FieldMap.hash s.struct_value,
          Cil_datatype.Compinfo.hash s.struct_info,
          Bit.hash s.struct_padding)
      | Union u -> Hashtbl.hash (
          hash u.union_value,
          Cil_datatype.Fieldinfo.hash u.union_field,
          Bit.hash u.union_padding)
      | Array a -> Hashtbl.hash (
          hash a.array_value,
          Cil_datatype.Typ.hash a.array_cell_type)

    let rec equal m1 m2 =
      match m1, m2 with
      | Raw b1, Raw b2 -> Bit.equal b1 b2
      | Scalar s1, Scalar s2 ->
        Value.equal s1.scalar_value s2.scalar_value &&
        Cil_datatype.Typ.equal s1.scalar_type s2.scalar_type
      | Struct s1, Struct s2 ->
        FieldMap.equal s1.struct_value s2.struct_value &&
        Bit.equal s1.struct_padding s2.struct_padding &&
        Cil_datatype.Compinfo.equal s1.struct_info s2.struct_info
      | Union u1, Union u2 ->
        equal u1.union_value u2.union_value &&
        Bit.equal u1.union_padding u2.union_padding &&
        Cil_datatype.Fieldinfo.equal u1.union_field u2.union_field
      | Array a1, Array a2 ->
        equal a1.array_value a2.array_value &&
        Cil_datatype.Typ.equal a1.array_cell_type a2.array_cell_type
      | (Raw _ | Scalar _ | Struct _ | Union _ | Array _), _ -> false

    let rec compare m1 m2 =
      let (<?>) c (cmp,x,y) =
        if c = 0 then cmp x y else c
      in
      match m1, m2 with
      | Raw b1, Raw b2 -> Bit.compare b1 b2
      | Scalar s1, Scalar s2 ->
        Value.compare s1.scalar_value s2.scalar_value <?>
        (Cil_datatype.Typ.compare, s1.scalar_type, s2.scalar_type)
      | Struct s1, Struct s2 ->
        FieldMap.compare s1.struct_value s2.struct_value <?>
        (Bit.compare, s1.struct_padding, s2.struct_padding) <?>
        (Cil_datatype.Compinfo.compare, s1.struct_info, s2.struct_info)
      | Union u1, Union u2 ->
        compare u1.union_value u2.union_value <?>
        (Bit.compare, u1.union_padding, u2.union_padding) <?>
        (Cil_datatype.Fieldinfo.compare, u1.union_field, u2.union_field)
      | Array a1, Array a2 ->
        compare a1.array_value a2.array_value <?>
        (Cil_datatype.Typ.compare, a1.array_cell_type, a2.array_cell_type)
      | Raw _, _ -> 1
      | _, Raw _ -> -1
      | Scalar _, _ -> 1
      | _, Scalar _ -> -1
      | Struct _, _ -> 1
      | _, Struct _ -> -1
      | Union _, _ -> 1
      | _, Union _ -> -1
  end


  (* Instanciation of Hptmaps for the tree structure of the memory *)

  module Initial_Values = struct let v = [[]] end

  module Deps = struct let l = Config.deps end

  module Keys =
  struct
    include Cil_datatype.Fieldinfo
    let id f = f.Cil_types.forder (* At each node, all fields come from the same comp *)
  end

  module rec Memory :
    Hptmap.V with type t = FieldMap.t memory =
  struct
    include Datatype.Make (
      struct
        include Datatype.Undefined
        include MemorySafe
        let name = "Memory_map.Typed"
        let reprs = [ Raw Bit.top ]
      end)
    let pretty_debug = pretty
  end

  (* To allow recursive modules to be instanciated, there must be one safe
     module in the cycle. This is it. It should contain all references
     to FieldMap and no constants, only functions *)
  and MemorySafe :
  sig
    type t = FieldMap.t memory
    val pretty : Format.formatter -> t -> unit
    val hash : t -> int
    val equal : t -> t -> bool
    val compare : t -> t -> int
  end =
  struct
    include Prototype (FieldMap)
  end

  (* Maps for structures : field -> node *)
  and FieldMap :
    Hptmap_sig.S
    with type key = Cil_types.fieldinfo
     and type v = Memory.t =
    Hptmap.Make (Keys) (Memory) (Hptmap.Comp_unused) (Initial_Values) (Deps)

  (* Caches *)

  let _cache_name s =
    Hptmap_sig.PersistentCache ("Multidim_domain.(" ^ Value.name ^ ")." ^ s)

  (* Datatype *)

  include Memory

  (* Constuctors *)

  let top = Raw Bit.top

  let zero = Raw Bit.zero

  let is_top m =
    m = top

  (* Types compatibility *)

  let typ_size t =
    Integer.of_int (Cil.bitsSizeOf t)

  let are_typ_compatible t1 t2 =
    Integer.equal (typ_size t1) (typ_size t2)

  let are_scalar_compatible s1 s2 =
    are_typ_compatible s1.scalar_type s2.scalar_type

  let are_aray_compatible a1 a2 =
    are_typ_compatible a1.array_cell_type a2.array_cell_type

  let are_structs_compatible s1 s2 =
    s1.struct_info.ckey = s2.struct_info.ckey

  let are_union_compatible u1 u2 =
    Cil_datatype.Fieldinfo.equal u1.union_field u2.union_field

  (* Conversion *)

  let raw m =
    let rec aux acc = function
      | Raw b -> Bit.join acc b
      | Scalar s -> Bit.join acc (Value.to_bit s.scalar_value)
      | Array a -> aux acc a.array_value
      | Struct s ->
        let acc = Bit.join acc s.struct_padding in
        FieldMap.fold (fun _ x acc -> aux acc x) s.struct_value acc
      | Union u ->
        let acc = Bit.join acc u.union_padding in
        aux acc u.union_value
    in
    aux Zero m

  (* Lattice operations *)

  let is_included =
    let rec is_included m1 m2 = match m1, m2 with
      | Raw _, _ | _, Raw _ -> Bit.is_included (raw m1) (raw m2)
      | Scalar s1, Scalar s2 ->
        are_scalar_compatible s1 s2 &&
        Value.(is_included s1.scalar_value s2.scalar_value)
      | Array a1, Array a2 ->
        are_aray_compatible a1 a2 &&
        is_included a1.array_value a2.array_value
      | Struct s1, Struct s2 ->
        are_structs_compatible s1 s2 &&
        Bit.is_included s1.struct_padding s2.struct_padding &&
        let decide_fast s t = if s == t then FieldMap.PTrue else PUnknown in
        let decide_fst _fi m1 = is_included m1 (Raw s2.struct_padding) in
        let decide_snd _fi m2 = is_included (Raw s1.struct_padding) m2 in
        let decide_both _fi m1 m2 = is_included m1 m2 in
        FieldMap.binary_predicate Hptmap_sig.NoCache UniversalPredicate
          ~decide_fast ~decide_fst ~decide_snd ~decide_both
          s1.struct_value s2.struct_value
      | Union u1, Union u2 ->
        are_union_compatible u1 u2 &&
        Bit.is_included u1.union_padding u2.union_padding &&
        is_included u1.union_value u2.union_value
      | Scalar _, (Array _ | Struct _ | Union _)
      | Array _, (Scalar _ | Struct _ | Union _)
      | Struct _, (Scalar _ | Array _ | Union _)
      | Union _, (Scalar _ | Array _ | Struct _) -> false
    in
    is_included

  let join f =
    let rec join m1 m2 =
      match m1, m2 with
      | Raw b1, Raw b2 -> Raw (Bit.join b1 b2)
      | Scalar s1, Scalar s2 when are_scalar_compatible s1 s2 ->
        let size = typ_size s1.scalar_type in
        Scalar {
          scalar_type = s1.scalar_type;
          scalar_value = f ~size s1.scalar_value s2.scalar_value;
        }
      | Scalar s, Raw b | Raw b, Scalar s ->
        let size = typ_size s.scalar_type in
        Scalar {
          s with
          scalar_value = f ~size (Value.of_bit b) s.scalar_value;
        }
      | Array a1, Array a2 when are_aray_compatible a1 a2 ->
        Array { a1 with array_value = join a1.array_value a2.array_value }
      | Array a, (Raw b) | (Raw b), Array a ->
        Array { a with array_value = join (Raw b) a.array_value }
      | Struct s1, Struct s2 when are_structs_compatible s1 s2 ->
        let decide b =
          FieldMap.Traversing (fun _fi m -> Some (join (Raw b) m))
        in
        let decide_both _fi = fun m1 m2 -> Some (join m1 m2)
        and decide_left = decide s2.struct_padding
        and decide_right = decide s1.struct_padding
        in
        let struct_value = FieldMap.merge
            ~cache:Hptmap_sig.NoCache
            ~symmetric:false ~idempotent:true
            ~decide_both ~decide_left ~decide_right
            s1.struct_value s2.struct_value
        in
        Struct {
          s1 with
          struct_value;
          struct_padding = Bit.join s1.struct_padding s2.struct_padding;
        }
      | Struct s, Raw b | Raw b, Struct s ->
        Struct {
          s with
          struct_value = FieldMap.map (join (Raw b)) s.struct_value;
          struct_padding = Bit.join b s.struct_padding ;
        }
      | Union u1, Union u2 when are_union_compatible u1 u2 ->
        Union {
          u1 with
          union_value = join u1.union_value u2.union_value;
          union_padding = Bit.join u1.union_padding u2.union_padding;
        }
      | Union u, Raw b | Raw b, Union u ->
        Union {
          u with
          union_value = join (Raw b) u.union_value;
          union_padding = Bit.join b u.union_padding;
        }
      | _,_ ->
        Raw (Bit.join (raw m1) (raw m2))
    in
    join

  let widen = join

  (* Read/Write accesses *)

  let rec read m offset =
    match offset, m with
    | NoOffset t, Scalar s when are_typ_compatible s.scalar_type t -> m
    | NoOffset _, m -> m (* TODO check type compatibility *)
    | Field (fi, offset'), Struct s when s.struct_info.ckey = fi.fcomp.ckey ->
      begin try
          let m' = FieldMap.find fi s.struct_value in
          read m' offset'
        with Not_found ->
          Raw s.struct_padding (* field undefined *)
      end
    | Field (fi, offset'), Union u when u.union_field.forder = fi.forder ->
      read u.union_value offset'
    | Index (_index, elem_type, offset'), Array a
      when are_typ_compatible a.array_cell_type elem_type ->
      read a.array_value offset'
    | _, _ -> Raw (raw m) (* structure mismatch *)

  let get m offset =
    match read m offset with
    | Scalar s -> s.scalar_value
    | m -> Value.of_bit (raw m)

  let extract = read

  let rec write ~weak (f : weak:bool -> t -> Cil_types.typ -> t) m = function
    | NoOffset t ->
      f ~weak m t
    | Field (fi, offset') ->
      if fi.fcomp.cstruct then (* Structures *)
        let old = match m with
          | Struct s when s.struct_info.ckey = fi.fcomp.ckey -> s
          | _ -> {
              struct_value = FieldMap.empty;
              struct_info = fi.fcomp;
              struct_padding = raw m
            }
        in
        let write' opt =
          let old = Option.value ~default:(Raw old.struct_padding) opt in
          Some (write f ~weak old offset')
        in
        Struct {
          old with struct_value = FieldMap.replace write' fi old.struct_value
        }
      else (* Unions *)
        let old = match m with
          | Union u when u.union_field.forder = fi.forder -> u
          | _ ->
            let b = raw m in {
              union_value = Raw b;
              union_field = fi;
              union_padding = b;
            }
        in
        Union {
          old with union_value = write f ~weak old.union_value offset'
        }
    | Index (index, elem_type, offset') ->
      let old = match m with
        | Array a when are_typ_compatible a.array_cell_type elem_type ->
          a.array_value
        | _ -> Raw (raw m)
      in
      let weak = weak || not (Ival.(is_included top index)) in
      Array {
        array_value = write f ~weak old offset';
        array_cell_type = elem_type
      }

  let set ~weak m offset new_v =
    let f ~weak m t =
      let scalar_value =
        if weak then
          let old_v = get m (NoOffset t) in
          Value.join old_v new_v
        else
          new_v
      in
      Scalar { scalar_value ; scalar_type=t }
    in
    write ~weak f m offset

  let reinforce f' m offset =
    let f ~weak m scalar_type =
      match m with
      | m when weak -> m
      | Scalar s when are_typ_compatible s.scalar_type scalar_type ->
        Scalar { s with scalar_value = f' s.scalar_value }
      | Raw b ->
        Scalar { scalar_type; scalar_value = f' (Value.of_bit b) }
      | m -> m
    in
    write ~weak:false f m offset

  let rec weak_erase b = function
    | Raw b' -> Raw (Bit.join b' b)
    | Scalar s -> Raw (Bit.join (Value.to_bit s.scalar_value) b)
    | Array a -> Array { a with array_value = weak_erase b a.array_value }
    | Struct s -> Struct {
        s with
        struct_padding = Bit.join s.struct_padding b;
        struct_value = FieldMap.map (weak_erase b) s.struct_value;
      }
    | Union u -> Union {
        u with
        union_padding = Bit.join u.union_padding b;
        union_value = weak_erase b u.union_value;
      }

  let erase ~weak m offset b =
    let f ~weak m _t =
      if weak then
        weak_erase b m
      else
        Raw b
    in
    write ~weak f m offset

  let overwrite ~weak dst offset src =
    let f' ~weak m _t =
      if weak then
        join (fun ~size:_ -> Value.join) m src
      else
        src
    in
    write ~weak f' dst offset
end
