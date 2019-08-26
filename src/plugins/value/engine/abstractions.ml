(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2019                                               *)
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

(* --- Registration types --------------------------------------------------- *)

type 'v value =
  | Single of (module Abstract_value.Leaf with type t = 'v)
  | Struct of 'v Abstract.Value.structure

type precise_loc = Precise_locs.precise_location

module type leaf_domain = Abstract_domain.Leaf with type location = precise_loc

module type domain_functor =
  functor (Value: Abstract.Value.External) ->
    (leaf_domain with type value = Value.t)

type 'v domain =
  | Domain: (module leaf_domain with type value = 'v) -> 'v domain
  | Functor: (module domain_functor) -> _ domain

type 'v abstraction =
  { name: string;
    values: 'v value;
    domain: 'v domain; }

(* --- Config and registration ---------------------------------------------- *)

module Config = struct
  type flag = Flag: 'v abstraction -> flag

  module Flag = struct
    type t = flag
    let compare (Flag f1) (Flag f2) = Datatype.String.compare f1.name f2.name
  end

  include Set.Make (Flag)

  type dynamic = Dynamic: (unit -> 'a option) * ('a -> 'v abstraction) -> dynamic

  let abstractions = ref []
  let dynamic_abstractions : dynamic list ref = ref []

  let register ~enable abstraction =
    abstractions := (enable, Flag abstraction) :: !abstractions

  let dynamic_register ~configure ~make =
    dynamic_abstractions := Dynamic (configure, make) :: !dynamic_abstractions

  let configure () =
    let aux config (enable, flag) =
      if enable () then add flag config else config
    in
    let config = List.fold_left aux empty !abstractions in
    let aux config (Dynamic (configure, make)) =
      match configure () with
      | None -> config
      | Some c -> add (Flag (make c)) config
    in
    List.fold_left aux config !dynamic_abstractions

  (* --- Register default abstractions -------------------------------------- *)

  let create ~enable abstract = register ~enable abstract; Flag abstract
  let create_domain name enable values domain =
    create ~enable { name; values = Single values; domain = Domain domain }

  open Value_parameters

  (* Register standard domains over cvalues. *)
  let make name enable = create_domain name enable (module Main_values.CVal)

  let cvalue = make "cvalue" CvalueDomain.get (module Cvalue_domain.State)
  let gauges = make "gauges" GaugesDomain.get (module Gauges_domain.D)
  let inout = make "inout" InoutDomain.get (module Inout_domain.D)
  let printer = make "printer" PrinterDomain.get (module Printer_domain)
  let symbolic_locations =
    make "symbolic_locations" SymbolicLocsDomain.get (module Symbolic_locs.D)

  let sign =
    create_domain "sign" SignDomain.get (module Sign_value) (module Sign_domain)

  let bitwise =
    create_domain "bitwise" BitwiseOffsmDomain.get
      (module Offsm_value.Offsm) (module Offsm_domain.D)

  let equality_domain =
    { name = "equality";
      values = Struct Abstract.Value.Unit;
      domain = Functor (module Equality_domain.Make); }
  let equality = create ~enable:EqualityDomain.get equality_domain

  (* --- Default and legacy configurations ---------------------------------- *)

  let default = configure ()
  let legacy = singleton cvalue
end

let register = Config.register
let dynamic_register = Config.dynamic_register

(* --- Building value abstractions ------------------------------------------ *)

module Leaf_Value (V: Abstract_value.Leaf) = struct
  include V
  let structure = Abstract.Value.Leaf (V.key, (module V))
end

module Leaf_Domain (D: Abstract_domain.Leaf) = struct
  include D
  let structure = Abstract.Domain.Leaf (D.key, (module D))
end

module type Acc = sig
  module Val : Abstract.Value.External
  module Loc : Abstract.Location.Internal with type value = Val.t
                                           and type location = precise_loc
  module Dom : Abstract.Domain.Internal with type value = Val.t
                                         and type location = Loc.location
end

module Internal_Value = struct
  open Abstract.Value

  type value_key_module =  V : 'v key * 'v data -> value_key_module

  let open_value_abstraction (module Value : Internal) =
    (module struct
      include Value
      include Structure.Open (Abstract.Value) (Value)
    end : Abstract.Value.External)

  let add_value_leaf value (V (key, v)) =
    let module Value = (val open_value_abstraction value) in
    if Value.mem key then value else
      (module struct
        include Value_product.Make (Value) (val v)
        let structure = Node (Value.structure, Leaf (key, v))
      end)

  let add_value_structure value internal =
    let rec aux: type v. (module Internal) -> v structure -> (module Internal) =
      fun value -> function
        | Leaf (key, v) -> add_value_leaf value (V (key, v))
        | Node (s1, s2) -> aux (aux value s1) s2
        | Unit -> value
    in
    aux value internal

  let build_values config initial_value =
    let build (Config.Flag abstraction) acc =
      match abstraction.values with
      | Struct structure -> add_value_structure acc structure
      | Single (module V) -> add_value_leaf acc (V (V.key, (module V)))
    in
    let value = Config.fold build config initial_value in
    open_value_abstraction value


  module Convert
      (Value: Abstract.Value.External)
      (Struct: sig type v val s : v value end)
  = struct

    let structure = match Struct.s with
      | Single (module V) -> Abstract.Value.Leaf (V.key, (module V))
      | Struct s -> s

    type extended_value = Value.t

    let replace_val =
      let rec set: type v. v structure -> v -> Value.t -> Value.t =
        function
        | Leaf (key, _) -> Value.set key
        | Node (s1, s2) ->
          let set1 = set s1 and set2 = set s2 in
          fun (v1, v2) value -> set1 v1 (set2 v2 value)
        | Unit -> fun () value -> value
      in
      set structure

    let extend_val v = replace_val v Value.top

    let restrict_val =
      let rec get: type v. v structure -> Value.t -> v = function
        | Leaf (key, _) -> Extlib.the (Value.get key)
        | Node (s1, s2) ->
          let get1 = get s1 and get2 = get s2 in
          fun v -> get1 v, get2 v
        | Unit -> fun _ -> ()
      in
      get structure

    type extended_location = Main_locations.PLoc.location

    let restrict_loc = fun x -> x
    let extend_loc = fun x -> x
  end
end

(* --- Building domain abstractions ----------------------------------------- *)

module type internal_domain =
  Abstract.Domain.Internal with type location = Precise_locs.precise_location

let eq_value:
  type a b. a Abstract.Value.structure -> b value -> (a,b) Structure.eq option
  = fun structure -> function
    | Struct s -> Abstract.Value.eq_structure structure s
    | Single (module V) ->
      match structure with
      | Abstract.Value.Leaf (key, _) -> Abstract.Value.eq_type key V.key
      | _ -> None

let add_domain (type v) (abstraction: v abstraction) (module Acc: Acc) =
  let domain : (module internal_domain with type value = Acc.Val.t) =
    match abstraction.domain with
    | Functor make ->
      let module Make = (val make: domain_functor) in
      (module Leaf_Domain (Make (Acc.Val)))
    | Domain domain ->
      match eq_value Acc.Val.structure abstraction.values with
      | Some Structure.Eq ->
        let module Domain = (val domain) in
        (module Leaf_Domain (Domain))
      | None ->
        let module Domain = (val domain : leaf_domain with type value = v) in
        let module Struct = struct
          type v = Domain.value
          let s = abstraction.values
        end in
        let module Convert = Internal_Value.Convert (Acc.Val) (Struct) in
        (module Domain_lift.Make (Domain) (Convert))
  in
  let domain : (module internal_domain with type value = Acc.Val.t) =
    match Abstract.Domain.(eq_structure Acc.Dom.structure Unit) with
    | Some _ -> domain
    | None -> (module Domain_product.Make (Acc.Val) (Acc.Dom) ((val domain)))
  in
  (module struct
    module Val = Acc.Val
    module Loc = Acc.Loc
    module Dom = (val domain)
  end : Acc)

let build_domain config abstract =
  let build (Config.Flag abstraction) acc = add_domain abstraction acc in
  Config.fold build config abstract


(* --- Value reduced product ----------------------------------------------- *)

module type Value = sig
  include Abstract.Value.External
  val reduce : t -> t
end

module type S = sig
  module Val : Value
  module Loc : Abstract.Location.External with type value = Val.t
  module Dom : Abstract.Domain.External with type value = Val.t
                                         and type location = Loc.location
end

module type Eva = sig
  include S
  module Eval: Evaluation.S with type state = Dom.t
                             and type value = Val.t
                             and type loc = Loc.location
                             and type origin = Dom.origin
end


type ('a, 'b) value_reduced_product =
  'a Abstract.Value.key * 'b Abstract.Value.key * ('a -> 'b -> 'a * 'b)

type v_reduced_product = R: ('a, 'b) value_reduced_product -> v_reduced_product

let value_reduced_product = ref []

let register_value_reduction reduced_product =
  value_reduced_product := (R reduced_product) :: !value_reduced_product

(* When the value abstraction contains both a cvalue and an interval
   component (coming currently from an Apron domain), reduce them from each
   other. If the Cvalue is not a scalar do nothing, because we do not
   currently use Apron for pointer offsets. *)
let reduce_apron_itv cvalue ival =
  match ival with
  | None -> begin
      try cvalue, Some (Cvalue.V.project_ival cvalue)
      with Cvalue.V.Not_based_on_null -> cvalue, ival
    end
  | Some ival ->
    try
      let ival' = Cvalue.V.project_ival cvalue in
      (match ival' with
       | Ival.Float _ -> raise Cvalue.V.Not_based_on_null
       | _ -> ());
      let reduced_ival = Ival.narrow ival ival' in
      let cvalue = Cvalue.V.inject_ival reduced_ival in
      cvalue, Some reduced_ival
    with Cvalue.V.Not_based_on_null -> cvalue, Some ival

let () =
  register_value_reduction
    (Main_values.CVal.key, Main_values.Interval.key, reduce_apron_itv)

module Reduce (Value : Abstract.Value.External) = struct
  include Value

  let make_reduction acc (R (key1, key2, f)) =
    match Value.get key1, Value.get key2 with
    | Some get1, Some get2 ->
      let set1 = Value.set key1
      and set2 = Value.set key2 in
      let reduce v = let v1, v2 = f (get1 v) (get2 v) in set1 v1 (set2 v2 v) in
      reduce :: acc
    | _, _ -> acc

  let reduce =
    let list = List.fold_left make_reduction [] !value_reduced_product in
    fun v -> List.fold_left (fun v reduce -> reduce v) v list
end

(* --- Final hook ----------------------------------------------------------- *)

let final_hooks = ref []

let register_hook f =
  final_hooks := f :: !final_hooks

let apply_final_hooks abstractions =
  List.fold_left (fun acc f -> f acc) abstractions !final_hooks

(* --- Building abstractions ------------------------------------------------ *)

module Open (Acc: Acc) : S = struct
  module Val = Reduce (Acc.Val)
  module Loc = struct
    include Acc.Loc
    include Structure.Open (Abstract.Location)
        (struct include Acc.Loc type t = location end)
  end
  module Dom = struct
    include Acc.Dom
    include Structure.Open (Abstract.Domain) (Acc.Dom)

    let get_cvalue = match get Cvalue_domain.State.key with
      | None -> None
      | Some get -> Some (fun s -> fst (get s))

    let get_cvalue_or_top = match get Cvalue_domain.State.key with
      | None -> fun _ -> Cvalue.Model.top
      | Some get -> fun s -> fst (get s)

    let get_cvalue_or_bottom = function
      | `Bottom -> Cvalue.Model.bottom
      | `Value state -> get_cvalue_or_top state
  end
end

module Unit_Acc (Value: Abstract.Value.External) : Acc = struct
  module Struct = struct
    type v = Cvalue.V.t
    let s = Single (module Main_values.CVal)
  end
  module Conv = Internal_Value.Convert (Value) (Struct)
  module Val = Value
  module Loc = Location_lift.Make (Main_locations.PLoc) (Conv)
  module Dom = Unit_domain.Make (Value) (Loc)
end

let build_abstractions config =
  let initial_value : (module Abstract.Value.Internal) =
    if Config.mem Config.bitwise config
    then (module Offsm_value.CvalueOffsm)
    else (module Leaf_Value (Main_values.CVal))
  in
  let value = Internal_Value.build_values config initial_value in
  let acc = (module Unit_Acc (val value): Acc) in
  build_domain config acc

let configure = Config.configure

let make config =
  let abstractions = build_abstractions config in
  let abstractions = (module Open (val abstractions): S) in
  apply_final_hooks abstractions

module Default = (val make Config.default)
module Legacy = (val make Config.legacy)
