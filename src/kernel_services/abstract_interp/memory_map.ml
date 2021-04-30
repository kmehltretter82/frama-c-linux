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

type default =
  | Top
  | Numerical
  | Zero

module Default =
struct
  let hash = function
    | Top -> 3
    | Numerical -> 7
    | Zero -> 13

  let equal d1 d2 =
    match d1,d2 with
    | Top, Top | Numerical, Numerical | Zero, Zero -> true
    | Top, (Numerical | Zero) | Numerical, (Top | Zero)
    | Zero, (Top | Numerical) -> false

  let compare d1 d2 =
    match d1,d2 with
    | Top, Top | Numerical, Numerical | Zero, Zero -> 0
    | Top, (Numerical | Zero) -> 1
    | (Numerical | Zero), Top -> -1
    | Numerical, Zero -> 1
    | Zero, Numerical -> -1

  let is_included d1 d2 =
    match d1, d2 with
    | (Top | Numerical | Zero), Top -> true
    | Top, (Numerical | Zero) -> false
    | (Numerical | Zero), Numerical -> true
    | Numerical, Zero -> false
    | Zero, Zero -> true

  let join d1 d2 =
    match d1, d2 with
    | Top, (Top | Numerical | Zero)
    | (Numerical | Zero), Top -> Top
    | Numerical, (Numerical | Zero)
    | Zero, Numerical -> Numerical
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
  val zero : t
  val misaligned : t -> t
  val top : t
  val top_numerical : t
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
  val initialize : t -> location -> default -> t
  val set : weak:bool -> t -> location -> value -> t
  val update : weak:bool -> (weak:bool -> value -> value) ->  t -> location -> t
  val erase : t -> location -> t
  val overwrite : weak:bool -> t -> location -> t -> t
  val is_included : t -> t -> bool
  val join : (size:size -> value -> value -> value) -> t -> t -> t
  val widen : (size:size -> value -> value -> value) -> t -> t -> t
  val pretty : Format.formatter -> t -> unit
end


module Make (Config : Config) (Value : Value) =
struct
  type location = Abstract_offset.typed_offset
  type value = Value.t

  type 'fieldmap memory' =
    | Default of default
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
    struct_default: default; (* for missing fields *)
  }
  (* unions are handled separately from struct to avoid confusion and error *)
  and 'fieldmap memory_union = {
    union_value: 'fieldmap memory';
    union_field: Cil_types.fieldinfo;
  }
  and 'fieldmap memory_array = {
    array_value: 'fieldmap memory';
    array_cell_type: Cil_types.typ;
  }

  (* Instanciation of Hptmaps for the tree structure of the memory *)

  module Initial_Values = struct let v = [[]] end

  module Deps = struct let l = Config.deps end

  module Keys =
  struct
    include Cil_datatype.Fieldinfo
    let id f = f.Cil_types.forder (* At each node, all fields come from the same comp *)
  end

  module rec Memory :
    Hptmap.V with type t = FieldMap.t memory' =
  struct
    include Datatype.Make (
      struct
        include Datatype.Undefined
        include MemorySafe
        let name = "Memory_map.Typed"
        let reprs = [ Default Top ]
      end)
    let pretty_debug = pretty
  end

  (* To allow recursive modules to be instanciated, there must be one safe
     module in the cycle. This is it. It should contain all references
     to FieldMap and no constants, only functions *)
  and MemorySafe :
  sig
    type t = FieldMap.t memory'
    val pretty : Format.formatter -> t -> unit
    val hash : t -> int
    val equal : t -> t -> bool
    val compare : t -> t -> int
  end =
  struct
    type t = FieldMap.t memory'

    let rec pretty fmt =
      let rec leading_indexes acc = function
        | Array a -> leading_indexes (() :: acc) a.array_value
        | (Default _ | Scalar _ | Struct _ | Union _) as m -> List.rev acc, m
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
      | Default Top -> Format.fprintf fmt "T"
      | Default Numerical -> Format.fprintf fmt "[--..--]"
      | Default Zero -> Format.fprintf fmt "0"
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
      | Default d -> Default.hash d
      | Scalar s -> Hashtbl.hash (
          Value.hash s.scalar_value,
          Cil_datatype.Typ.hash s.scalar_type)
      | Struct s -> Hashtbl.hash (
          FieldMap.hash s.struct_value,
          Cil_datatype.Compinfo.hash s.struct_info,
          Default.hash s.struct_default)
      | Union u -> Hashtbl.hash (
          hash u.union_value,
          Cil_datatype.Fieldinfo.hash u.union_field
        )
      | Array a -> Hashtbl.hash (
          hash a.array_value,
          Cil_datatype.Typ.hash a.array_cell_type)

    let rec equal m1 m2 =
      match m1, m2 with
      | Default d1, Default d2 -> Default.equal d1 d2
      | Scalar s1, Scalar s2 ->
        Value.equal s1.scalar_value s2.scalar_value &&
        Cil_datatype.Typ.equal s1.scalar_type s2.scalar_type
      | Struct s1, Struct s2 ->
        FieldMap.equal s1.struct_value s2.struct_value &&
        Cil_datatype.Compinfo.equal s1.struct_info s2.struct_info
      | Union u1, Union u2 ->
        equal u1.union_value u2.union_value &&
        Cil_datatype.Fieldinfo.equal u1.union_field u2.union_field
      | Array a1, Array a2 ->
        equal a1.array_value a2.array_value &&
        Cil_datatype.Typ.equal a1.array_cell_type a2.array_cell_type
      | (Default _ | Scalar _ | Struct _ | Union _ | Array _), _ -> false

    let compare m1 m2 =
      let (<?>) c (cmp,x,y) =
        if c = 0 then cmp x y else c
      in
      match m1, m2 with
      | Default d1, Default d2 -> Default.compare d1 d2
      | Scalar s1, Scalar s2 ->
        Value.compare s1.scalar_value s2.scalar_value <?>
        (Cil_datatype.Typ.compare, s1.scalar_type, s2.scalar_type)
      | Struct s1, Struct s2 ->
        FieldMap.compare s1.struct_value s2.struct_value <?>
        (Cil_datatype.Compinfo.compare, s1.struct_info, s2.struct_info)
      | Union u1, Union u2 ->
        compare u1.union_value u2.union_value <?>
        (Cil_datatype.Fieldinfo.compare, u1.union_field, u2.union_field)
      | Array a1, Array a2 ->
        compare a1.array_value a2.array_value <?>
        (Cil_datatype.Typ.compare, a1.array_cell_type, a2.array_cell_type)
      | Default _, _ -> 1
      | _, Default _ -> -1
      | Scalar _, _ -> 1
      | _, Scalar _ -> -1
      | Struct _, _ -> 1
      | _, Struct _ -> -1
      | Union _, _ -> 1
      | _, Union _ -> -1
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

  (* Default values *)

  let top = Default Top

  let zero = Default Zero

  let default_to_value = function
    | Top -> Value.top
    | Zero -> Value.zero
    | Numerical -> Value.top_numerical

  let is_top m =
    m = top

  let typ_size t =
    Integer.of_int (Cil.bitsSizeOf t)

  let are_typ_compatible t1 t2 =
    Integer.equal (typ_size t1) (typ_size t2)

  let are_scalar_compatible s1 s2 =
    are_typ_compatible s1.scalar_type s2.scalar_type

  let scalar_compatibility s1 s2 =
    if are_scalar_compatible s1 s2
    then Some (typ_size s1.scalar_type)
    else None

  let are_aray_compatible a1 a2 =
    are_typ_compatible a1.array_cell_type a2.array_cell_type

  let are_structs_compatible s1 s2 =
    s1.struct_info.ckey = s2.struct_info.ckey

  let are_union_compatible u1 u2 =
    Cil_datatype.Fieldinfo.equal u1.union_field u2.union_field

  let typ_size t =
    Integer.of_int (Cil.bitsSizeOf t)

  let is_included =
    let rec is_included m1 m2 = match m1, m2 with
      | Default d1, Default d2 -> Default.is_included d1 d2
      | _, Default Top -> true
      | _, Default (Numerical | Zero) -> false
      | Default Top, _ -> false
      | Scalar s1, Scalar s2 ->
        are_scalar_compatible s1 s2 &&
        Value.(is_included s1.scalar_value s2.scalar_value)
      | Default d, Scalar s ->
        Value.(is_included (default_to_value d) s.scalar_value)
      | Array a1, Array a2 ->
        are_aray_compatible a1 a2 &&
        is_included a1.array_value a2.array_value
      | Default _, Array a2 ->
        is_included m1 a2.array_value
      | Struct s1, Struct s2 ->
        are_structs_compatible s1 s2 &&
        let decide_fast s t = if s == t then FieldMap.PTrue else PUnknown in
        let decide_fst _fi m1 = is_included m1 (Default s2.struct_default) in
        let decide_snd _fi m2 = is_included (Default s1.struct_default) m2 in
        let decide_both _fi m1 m2 = is_included m1 m2 in
        FieldMap.binary_predicate Hptmap_sig.NoCache UniversalPredicate
          ~decide_fast ~decide_fst ~decide_snd ~decide_both
          s1.struct_value s2.struct_value
      | Union u1, Union u2 ->
        are_union_compatible u1 u2 &&
        is_included u1.union_value u2.union_value
      | Default _, Union u2 ->
        is_included m1 u2.union_value
      | Default _, Struct s2 ->
        FieldMap.for_all (fun _key m2' -> is_included m1 m2') s2.struct_value
      | Scalar _, (Array _ | Struct _ | Union _)
      | Array _, (Scalar _ | Struct _ | Union _)
      | Struct _, (Scalar _ | Array _ | Union _)
      | Union _, (Scalar _ | Array _ | Struct _) -> false
    in
    is_included

  let join f =
    let rec join m1 m2 =
      match m1, m2 with
      | _, Default Top | Default Top, _ -> Default Top
      | Default d1, Default d2 -> Default (Default.join d1 d2)
      | Scalar s1, Scalar s2 ->
        begin match scalar_compatibility s1 s2 with
          | Some size -> Scalar {
              scalar_type = s1.scalar_type;
              scalar_value = f ~size s1.scalar_value s2.scalar_value;
            }
          | None -> Default Top
        end
      | Scalar s, Default d | Default d, Scalar s ->
        let size = typ_size s.scalar_type in
        Scalar { s with
                 scalar_value = f ~size (default_to_value d) s.scalar_value;
               }
      | Array a1, Array a2 ->
        if are_aray_compatible a1 a2
        then Array { a1 with
                     array_value = join a1.array_value a2.array_value
                   }
        else Default Top
      | Array a, (Default d) | (Default d), Array a ->
        Array { a with
                array_value = join (Default d) a.array_value
              }
      | Struct s1, Struct s2 ->
        if are_structs_compatible s1 s2 then
          let empty_action = function
            | Top -> FieldMap.Absorbing
            | d ->
              FieldMap.Traversing (fun _fi m -> Some (join (Default d) m))
          in
          let decide_both _fi = fun m1 m2 -> Some (join m1 m2)
          and decide_left = empty_action s2.struct_default
          and decide_right = empty_action s1.struct_default
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
            struct_default = Default.join s1.struct_default s2.struct_default;
          }
        else Default Top
      | Struct s, (Default d) | (Default d), Struct s ->
        Struct { s with
                 struct_value = FieldMap.map (join (Default d)) s.struct_value;
                 struct_default = Default.join d s.struct_default ;
               }
      | Union u1, Union u2 ->
        if are_union_compatible u1 u2
        then Union { u1 with
                     union_value = join u1.union_value u2.union_value
                   }
        else Default Top
      | Union u, (Default d) | (Default d), Union u ->
        Union { u with
                union_value = join (Default d) u.union_value
              }
      | Scalar _, (Array _ | Struct _ | Union _)
      | Array _, (Scalar _ | Struct _ | Union _)
      | Struct _, (Scalar _ | Array _ | Union _)
      | Union _, (Scalar _ | Array _ | Struct _) -> Default Top
    in
    join

  let widen f =
    let rec widen m1 m2 = match m1, m2 with
      | _, Default _ | Default _, _ -> join f m1 m2
      | Scalar s1, Scalar s2 ->
        begin match scalar_compatibility s1 s2 with
          | Some size -> Scalar {
              scalar_type = s1.scalar_type;
              scalar_value = f ~size s1.scalar_value s2.scalar_value;
            }
          | None -> Default Top
        end
      | Array a1, Array a2 ->
        if are_aray_compatible a1 a2
        then Array { a1 with
                     array_value = widen a1.array_value a2.array_value
                   }
        else Default Top
      | Struct s1, Struct s2 ->
        if are_structs_compatible s1 s2 then
          let empty_action = function
            | Top -> FieldMap.Absorbing
            | d ->
              FieldMap.Traversing (fun _fi m -> Some (widen (Default d) m))
          in
          let decide_both _fi = fun m1 m2 -> Some (widen m1 m2)
          and decide_left = empty_action s2.struct_default
          and decide_right = empty_action s1.struct_default
          in
          let struct_value = FieldMap.merge
              ~cache:Hptmap_sig.NoCache
              ~symmetric:false ~idempotent:true
              ~decide_both ~decide_left ~decide_right
              s1.struct_value s2.struct_value
          in
          Struct { s1 with
                   struct_value;
                   struct_default = Default.join s1.struct_default s2.struct_default;
                 }
        else Default Top
      | Union u1, Union u2 ->
        if are_union_compatible u1 u2
        then Union { u1 with
                     union_value = widen u1.union_value u2.union_value
                   }
        else Default Top
      | Scalar _, (Array _ | Struct _ | Union _)
      | Array _, (Scalar _ | Struct _ | Union _)
      | Struct _, (Scalar _ | Array _ | Union _)
      | Union _, (Scalar _ | Array _ | Struct _) -> Default Top
    in
    widen

  exception IncompatibleOffset of default

  let rec read m = function
    | NoOffset t -> m, t
    | Field (fi, offset') ->
      begin match m with
        | Struct s when s.struct_info.ckey = fi.fcomp.ckey ->
          begin try
              let m' = FieldMap.find fi s.struct_value in
              read m' offset'
            with Not_found ->
              raise (IncompatibleOffset s.struct_default) (* field undefined *)
          end
        | Union u when u.union_field.forder = fi.forder ->
          read u.union_value offset'
        | _ -> raise (IncompatibleOffset Top) (* structure mismatch *)
      end
    | Index (_index, elem_type, offset') ->
      begin match m with
        | Array a ->
          if not (are_typ_compatible a.array_cell_type elem_type)
          then raise (IncompatibleOffset Top) (* cell size not compatible *)
          else read a.array_value offset'
        | _ -> raise (IncompatibleOffset Top) (* structure mismatch *)
      end

  let get m offset =
    match read m offset with
    | Scalar s, typ when are_typ_compatible s.scalar_type typ -> s.scalar_value
    | _ -> default_to_value Top
    | exception (IncompatibleOffset d) -> default_to_value d

  let extract m offset =
    try
      fst (read m offset)
    with IncompatibleOffset d -> Default d

  let rec write ~weak f m = function
    | NoOffset t ->
      f ~weak (m,t)
    | Field (fi, offset') ->
      if fi.fcomp.cstruct then (* Structures *)
        let old = match m with
          | Struct s when s.struct_info.ckey = fi.fcomp.ckey -> s
          | _ -> {
              struct_value = FieldMap.empty;
              struct_info = fi.fcomp;
              struct_default = match m with
                | Default d -> d
                | _ -> Top
            }
        in
        let write' opt =
          let old = Option.value ~default:(Default old.struct_default) opt in
          Some (write f ~weak old offset')
        in
        Struct {
          old with struct_value = FieldMap.replace write' fi old.struct_value
        }
      else (* Unions *)
        let old = match m with
          | Union u when u.union_field.forder = fi.forder -> u.union_value
          | _ -> Default Top
        in
        Union {
          union_value = write f ~weak old offset';
          union_field = fi;
        }
    | Index (index, elem_type, offset') ->
      let old = match m with
        | Array a when are_typ_compatible a.array_cell_type elem_type ->
          a.array_value
        | Default _ -> m
        | _ -> top
      in
      let weak = weak || not (Ival.(is_included top index)) in
      Array {
        array_value = write f ~weak old offset';
        array_cell_type = elem_type
      }

  let initialize m offset d =
    let f ~weak:_ (_m,_t) =
      Default d
    in
    write ~weak:false f m offset

  let set ~weak m offset new_v =
    let f ~weak (m,t) =
      let scalar_value =
        if weak then 
          let old_v = match m with
            | Scalar s when are_typ_compatible s.scalar_type t -> s.scalar_value
            | Default d -> default_to_value d
            | _ -> Value.top
          in
          Value.join old_v new_v
        else
          new_v
      in
      Scalar { scalar_value ; scalar_type=t }
    in
    write ~weak f m offset
    
  let update ~weak f' m offset =
    let f ~weak (m,t) =
      let old = match m with
        | Scalar s when are_typ_compatible s.scalar_type t -> s.scalar_value
        | Default d -> default_to_value d
        | _ -> Value.top
      in
      Scalar {
        scalar_value = f' ~weak old;
        scalar_type = t;
      }
    in
    write ~weak f m offset

  let erase m offset =
    let f ~weak:_ (_m,_t) =
      top
    in
    write ~weak:false f m offset

  let overwrite ~weak dst offset src =
    let f' ~weak (m,_t) =
      if weak then
        join (fun ~size:_ -> Value.join) m src
      else
        src
    in
    write ~weak f' dst offset
end
