(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2023                                               *)
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



type ('a, 'b) dec_eq = ('a, 'b) Structure.eq option



(* --- Values abstraction --------------------------------------------------- *)

module Value = struct
  type 'v value = (module Abstract_value.S with type t = 'v)
  type 'v structure = 'v Abstract.Value.structure
  type 'v key = 'v Abstract.Value.key
  type 'v registered = 'v key * 'v value
  let register (type v) (k : v key) (v : v value) : v registered = (k, v)

  module type Structured = Abstract.Value.Internal
  module type Interactive = Abstract.Value.External
  type structured = (module Structured)
  type interactive = (module Interactive)

  let void_value () =
    Self.fatal "Cannot register a value module from a Void structure."

  let eq_type = Abstract.Value.eq_type
  let dec_eq : type a b. a registered -> b structure -> (a, b) dec_eq =
    fun (key, _) -> function Leaf (key', _) -> eq_type key key' | _ -> None

  let make_interactive (module Structured : Structured) =
    (module struct
      include Structured
      include Structure.Open (Abstract.Value) (Structured)
    end : Interactive)

  let leaf : type v. v registered -> v structure =
    fun (key, value) -> Abstract.Value.Leaf (key, value)

  let node : type a b. a structure -> b structure -> (a * b) structure =
    fun a b -> Abstract.Value.Node (a, b)

  let add : type v. v registered -> structured -> structured =
    fun (key, input) structured ->
      let open Abstract.Value in
      let module Interactive = (val make_interactive structured) in
      if not (Interactive.mem key) then
        (module struct
          include Value_product.Make (Interactive) (val input)
          let structure = node Interactive.structure (leaf (key, input))
        end)
      else structured

  module type From = sig type value val structure : value structure end
  module Converter (From : From) (To : Interactive) = struct
    type internal = From.value
    type extended = To.t
    let structure = From.structure

    let rec set : type v. v structure -> v -> extended -> extended = function
      | Leaf (key, _) -> To.set key
      | Node (s1, s2) -> fun (v1, v2) ext -> set s2 v2 ext |> set s1 v1
      | Option (s, default) -> fun v -> set s (Option.value ~default v)
      | Unit -> fun () value -> value
      | Void -> void_value ()

    let rec get : type v. v structure -> extended -> v = function
      | Leaf (key, _) -> Option.get (To.get key)
      | Node (s1, s2) -> fun v -> get s1 v, get s2 v
      | Option (s, _) -> fun v -> Some (get s v)
      | Unit -> fun _ -> ()
      | Void -> void_value ()

    let replace = set structure
    let extend v = replace v To.top
    let restrict = get structure
  end
end



(* --- Locations abstraction ------------------------------------------------ *)

module Location = struct
  type 'l structure = 'l Abstract.Location.structure
  type 'l key = 'l Abstract.Location.key

  type 'v dependencies =
    | Last : 'v Value.registered -> 'v dependencies
    | (::) : 'a Value.registered * 'b dependencies -> ('a * 'b) dependencies

  let rec outline : type v. v dependencies -> v Value.structure = function
    | Last value -> Value.leaf value
    | hd :: tl -> Value.node (Value.leaf hd) (outline tl)


  type ('v, 'l) location =
    (module Abstract_location.S with type value = 'v and type location = 'l)

  module type Registered = sig
    include Abstract_location.S
    val key : location key
    val dependencies : value dependencies
  end

  type ('v, 'l) registered =
    (module Registered with type location = 'l and type value = 'v)

  let register : type v l. l key -> (v, l) location -> v dependencies -> (v, l) registered =
    fun key (module Input) dependencies ->
      (module struct
        include Input
        let key = key
        let dependencies = dependencies
      end)

  module type Structured = Abstract.Location.Internal
  module type Interactive = Abstract.Location.External
  type 'v structured = (module Structured with type value = 'v)
  type interactive = (module Interactive)

  module type Abstraction = sig
    type value
    type location
    module Value : Value.Interactive with type t = value
    module Location : Structured
      with type value = value and type location = location
  end

  type ('v, 'l) abstraction =
    (module Abstraction with type value = 'v and type location = 'l)

  (* let test : type v l. (v, l) registered -> (v, l) abstraction = *)

  



  let leaf : type l. l registered -> l structure = fun (module Registered) ->
    Abstract.Location.Leaf (Registered.key, (module Registered))

  let node : type a b. a structure -> b structure -> (a * b) structure =
    fun a b -> Abstract.Location.Node (a, b)

  let void_location () =
    Self.fatal "Cannot register a location module from a Void structure."

  let eq_type = Abstract.Location.eq_type
  let dec_eq : type a b. a registered -> b structure -> (a, b) dec_eq =
    fun (module R) -> function Leaf (key', _) -> eq_type R.key key' | _ -> None

  let make_interactive (module Structured : Structured) =
    (module struct
      include Structured
      include Structure.Open (Abstract.Location) (struct
        include Structured
        type t = location
      end)
    end : Interactive)

  type 'v abstraction = (module Abstraction with type value = 'v)

  let add : type v l. l registered -> v abstraction -> v abstraction =
    fun (module Registered) (module Abstraction) ->
      let dependencies = outline Registered.dependencies in
      let dec_eq = Abstract.Value.eq_structure in
      let structured : v structured =
        match dec_eq dependencies Abstraction.Value.structure with
        | Some Eq ->
          (module struct
            include Registered
            let structure = leaf (module Registered)
          end : Structured with type value = v)
        | None ->
          let module From = struct
            type value = Registered.value
            let structure = dependencies
          end in
          let module Converter = Value.Converter (From) (Abstraction.Value) in
          (module Location_lift.Make (Registered) (Converter))
      in
      let location : v structured =
        let open Locations_product in
        let module Val = Abstraction.Value in
        let module Loc = Abstraction.Location in
        match Abstraction.Location.structure with
        | Unit -> structured
        | _ -> (module Same_value (Val) (val structured) (Loc))
      in
      (module struct
        type value = Abstraction.value
        module Value = Abstraction.Value
        module Location = (val location)
      end)


  module type From = sig type location val registered : location registered end
  module Converter (From : From) (To : Interactive) = struct
    type internal = From.location
    type extended = To.location

    let structure =
      let module Registered = (val From.registered) in
      let module Location = (val Registered.location) in
      Abstract.Location.Leaf (Registered.key, (module Location))

    let rec set : type l. l structure -> l -> extended -> extended = function
      | Leaf (key, _) -> To.set key
      | Node (s1, s2) -> fun (l1, l2) ext -> set s2 l2 ext |> set s1 l1
      | Option (s, default) -> fun l -> set s (Option.value ~default l)
      | Unit -> fun () loc -> loc
      | Void -> void_location ()

    let rec get : type l. l structure -> extended -> l = function
      | Leaf (key, _) -> Option.get (To.get key)
      | Node (s1, s2) -> fun l -> get s1 l, get s2 l
      | Option (s, _) -> fun l -> Some (get s l)
      | Unit -> fun _ -> ()
      | Void -> void_location ()

    let replace = set structure
    let extend l = replace l To.top
    let restrict = get structure
  end


  include Abstract.Location
  type internal = (module Internal)
  type ('v, 'l) input =
    (module Abstract_location.Leaf with type value = 'v and type location = 'l)

  module type Registered = sig
    type values
    type location
    val values: values Value.registered
    val location: (values, location) input
  end

  type 'l registered = (module Registered with type location = 'l)

  type ('v, 'l) abstraction =
    { dependencies: 'v Value.registered ; location: ('v, 'l) input }

  let register: type v l. (v, l) abstraction -> l registered =
    fun abstraction ->
      let module Location = struct
        type values = v
        type location = l
        let values = abstraction.dependencies
        let location = abstraction.location
      end in
      (module Location)

  let dec_eq : type a b. a structure -> b registered -> (a, b) dec_eq =
    fun structure (module R) ->
      let module L = (val R.location) in
      match structure with
      | Leaf (key, _) -> eq_type key L.key
      | _ -> None

  let void_loc () =
    Self.fatal "Cannot register a location module from a Void structure."

  let open_abstraction (module Loc : Internal) =
    (module struct
      include Loc
      include Structure.Open (Abstract.Location) (struct
        include Loc
        type t = location
      end)
    end : External)

  let add_leaf : type l. l key -> l data -> internal -> internal =
    fun key data locs ->
      let module Locs = (val open_abstraction locs) in
      if not (Locs.mem key) then
        (module struct
          include Locations_product.Make (Locs) (val data)
          let structure = Node (Locs.structure, Leaf (key, data))
        end)
      else locs

  let rec add_structure : type l. l structure -> internal -> internal =
    fun structure locs ->
      match structure with
      | Option (s, _) -> add_structure s locs
      | Leaf (key, v) -> add_leaf key v locs
      | Node (s1, s2) -> add_structure s1 locs |> add_structure s2
      | Unit -> locs
      | Void -> void_loc ()

  module type Struct = sig type l val s : l registered end

  module Convert (Loc: External) (Struct: Struct) = struct
    type extended = Loc.location

    let structure =
      let module Registered = (val Struct.s) in
      let module L = (val Registered.location) in
      Leaf (L.key, (module L))

    let replace =
      let rec set: type l. l structure -> l -> extended -> extended = function
        | Leaf (key, _) -> Loc.set key
        | Node (s1, s2) ->
          let set1 = set s1 and set2 = set s2 in
          fun (l1, l2) loc -> set1 l1 (set2 l2 loc)
        | Option (s, default) -> fun l -> set s (Option.value ~default l)
        | Unit -> fun () loc -> loc
        | Void -> void_loc ()
      in
      set structure

    let extend l = replace l Loc.top

    let restrict =
      let rec get: type l. l structure -> extended -> l = function
        | Leaf (key, _) -> Option.get (Loc.get key)
        | Node (s1, s2) ->
          let get1 = get s1 and get2 = get s2 in
          fun l -> get1 l, get2 l
        | Option (s, _) -> fun l -> Some (get s l)
        | Unit -> fun _ -> ()
        | Void -> void_loc ()
      in
      get structure
  end

  module type Acc = sig
    module Val : Abstract.Value.External
    module Loc : Abstract.Location.Internal with type value = Val.t
  end

  let add : type v l. (v, l) abstraction -> (module Acc) -> (module Acc) =
    fun abstraction (module Acc) ->
      let module Location = (val abstraction.location) in
      let location =
        match Value.dec_eq Acc.Val.structure abstraction.dependencies with
        | Some Eq ->
          (module struct
            include Location
            let structure = Leaf (Location.key, (module Location))
          end : Internal with type value = Acc.Val.t)
        | None ->
          let module Convert = Value.Convert (Acc.Val) (struct
            type v = Location.value
            let s = abstraction.dependencies
          end) in
          (module Location_lift.Make (Location) (Convert))
      in
      let location =
        let open Locations_product in
        match Acc.Loc.structure with
        | Unit -> location
        | _ -> (module Same_value (Acc.Val) (val location) (Acc.Loc))
      in
      (module struct
        module Val = Acc.Val
        module Loc = (val location)
      end)
end








module Domain = struct
  type ('v, 'l) leaf_domain =
    (module Abstract_domain.Leaf with type value = 'v and type location = 'l)
  
  module type Functor_value = sig
    type l
    module Make (V: Abstract.Value.External) :
      (Abstract_domain.Leaf with type value = V.t and type location = l)
  end

  type ('v, 'l) t =
    | Domain : ('v, 'l) leaf_domain -> ('v, 'l) t
    | FunctorValue : (module Functor_value with type l = 'l) -> (_, 'l) t

  module type Registered = sig
    type values
    type locations
    val values : values Value.structure
    val locations : locations Location.structure
    val domain : (values, locations) t
  end

  type ('v, 'l) registered =
    (module Registered with type values = 'v and type locations = 'l)

  type ('v, 'l) dependencies =
    { values: 'v Value.structure ; locations: 'l Location.structure }

  type ('v, 'l) abstraction =
    { dependencies: ('v, 'l) dependencies ; domain: ('v, 'l) t }

  let register : type v l. (v, l) abstraction -> (v, l) registered =
    fun abstraction ->
      (module struct
        type values = v
        type locations = l
        let values = abstraction.dependencies.values
        let locations = abstraction.dependencies.locations
        let domain = abstraction.domain
      end)
end



(* --- Registration types --------------------------------------------------- *)

type 'v value =
  | Single of (module Abstract_value.Leaf with type t = 'v)
  | Struct of 'v Abstract.Value.structure

type 'l location =
  | SingleLoc of (module Abstract_location.Leaf with type location = 'l)
  | StructLoc of 'l Abstract.Location.structure

type ('v, 'l) leaf_domain =
  (module Abstract_domain.Leaf with type location = 'l and type value = 'v)

module type Functor_value = sig
  type l
  module Make (V: Abstract.Value.External) :
    (Abstract_domain.Leaf with type value = V.t and type location = l)
end

type ('v, 'l) domain =
  | Domain : ('v, 'l) leaf_domain -> ('v, 'l) domain
  | FunctorValue : (module Functor_value with type l = 'l) -> (_, 'l) domain

type ('v, 'l) abstraction =
  { values: 'v value
  ; location: 'l location
  ; domain : ('v, 'l) domain
  }

type 't with_info =
  { name: string
  ; experimental: bool
  ; priority: int
  ; abstraction: 't
  }

type flag = Flag: ('v, 'l) abstraction with_info -> flag




(* --- Config and registration ---------------------------------------------- *)

module Config = struct
  module OptMode = Datatype.Option (Domain_mode)
  module Element = struct
    type t = flag * Domain_mode.t option

    (* Flags are sorted by increasing priority order, and then by name. *)
    let compare (Flag f1, mode1) (Flag f2, mode2) =
      let c = Datatype.Int.compare f1.priority f2.priority in
      if c <> 0 then c else
        let c = Datatype.String.compare f1.name f2.name in
        if c <> 0 then c else
          OptMode.compare mode1 mode2
  end

  include Set.Make (Element)

  let mem (Flag domain) =
    exists (fun (Flag flag, _mode) -> flag.name = domain.name)

  let abstractions = ref []
  let dynamic_abstractions = ref []

  let register_domain_option ~name ~experimental ~descr =
    let descr = if experimental then "Experimental. " ^ descr else descr in
    Parameters.register_domain ~name ~descr

  let register ~name ~descr ?(experimental=false) ?(priority=0) abstraction =
    register_domain_option ~name ~experimental ~descr;
    let flag = Flag { name; experimental; priority; abstraction } in
    abstractions := flag :: !abstractions;
    flag

  let dynamic_register ~name ~descr ?(experimental=false) ?(priority=0) make =
    register_domain_option ~name ~experimental ~descr;
    let make' () : flag =
      Flag { name; experimental; priority; abstraction = make () }
    in
    dynamic_abstractions := (name,make') :: !dynamic_abstractions

  let configure () =
    let add_main_mode mode =
      let main, _ = Globals.entry_point () in
      (main, Domain_mode.Mode.all) :: mode
    in
    let add config (name, make) =
      let enabled = Parameters.Domains.mem name in
      try
        let mode = Parameters.DomainsFunction.find name in
        let mode = if enabled then add_main_mode mode else mode in
        add (make (), Some mode) config
      with Not_found ->
        if enabled then add (make (), None) config else config
    in
    let aux config (Flag domain as flag) =
      add config (domain.name, (fun () -> flag))
    in
    let config = List.fold_left aux empty !abstractions in
    List.fold_left add config !dynamic_abstractions

  (* --- Register default abstractions -------------------------------------- *)

  let create_domain ?experimental priority name descr values location domain =
    let values = Single values in
    let location = SingleLoc location in
    let domain = Domain domain in
    let abstraction = { values ; location ; domain } in
    register ~name ~descr ~priority ?experimental abstraction

  (* Register standard domains over cvalues. *)
  let make ?experimental rank name descr =
    create_domain ?experimental rank name descr
      (module Main_values.CVal) (module Main_locations.PLoc)

  let cvalue =
    make 9 "cvalue"
      "Main analysis domain, enabled by default. Should not be disabled."
      (module Cvalue_domain.State)

  let symbolic_locations =
    make 7 "symbolic-locations"
      "Infers values of symbolic locations represented by imprecise lvalues, \
       such as t[i] or *p when the possible values of [i] or [p] are imprecise."
      (module Symbolic_locs.D)

  (* TODO: Location handling in equality functor *)
  let equality =
    let descr = "Infers equalities between syntactic C expressions. \
                 Makes the analysis less dependent on temporary variables and \
                 intermediate computations."
    and abstraction =
      { values = Struct Abstract.Value.Unit;
        location = SingleLoc (module Main_locations.PLoc);
        domain = FunctorValue (module struct
          type l = Main_locations.PLoc.location
          module Make = Equality_domain.Make
        end); }
    in
    register ~name:"equality" ~descr ~priority:8 abstraction

  let gauges =
    make 6 "gauges"
      "Infers linear inequalities between the variables modified within a loop \
       and a special loop counter."
      (module Gauges_domain.D)

  let octagon =
    make 6 "octagon"
      "Infers relations between scalar variables of the form b ≤ ±X ± Y ≤ e, \
       where X, Y are program variables and b, e are constants."
      (module Octagons)

  let bitwise =
    create_domain 3 "bitwise"
      "Infers bitwise information to interpret more precisely bitwise operators."
      (module Offsm_value.Offsm) (module Main_locations.PLoc) (module Offsm_domain.D)

  let sign =
    create_domain 4 "sign"
      "Infers the sign of program variables."
      (module Sign_value) (module Main_locations.PLoc) (module Sign_domain)

  let inout = make 5 "inout" ~experimental:true
      "Infers the inputs and outputs of each function."
      (module Inout_domain.D)

  let traces =
    make 2 "traces" ~experimental:true
      "Builds an over-approximation of all the traces that lead \
       to a statement."
      (module Traces_domain.D)

  let printer =
    make 2 "printer"
      "Debug domain, only useful for developers. Prints the transfer functions \
       used during the analysis."
      (module Printer_domain)

  (* --- Default and legacy configurations ---------------------------------- *)

  let default = configure ()
  let legacy = singleton (cvalue, None)
end

let register = Config.register
let dynamic_register = Config.dynamic_register



(* --- Building value abstractions ------------------------------------------ *)

module Leaf_Value (V: Abstract_value.Leaf) = struct
  include V
  let structure = Abstract.Value.Leaf (V.key, (module V))
end

module Internal_Value = struct
  open Abstract.Value

  let eq_value : type a b. a structure -> b value -> (a, b) dec_eq =
    fun structure -> function
      | Struct s -> eq_structure structure s
      | Single (module V) ->
        match structure with
        | Leaf (key, _) -> eq_type key V.key
        | _ -> None

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

  let void_value () =
    Self.fatal "Cannot register a value module from a Void structure."

  let add_value_structure value internal =
    let rec aux: type v. (module Internal) -> v structure -> (module Internal) =
      fun value -> function
        | Option (s, _) -> aux value s
        | Leaf (key, v) -> add_value_leaf value (V (key, v))
        | Node (s1, s2) -> aux (aux value s1) s2
        | Unit -> value
        | Void -> void_value ()
    in
    aux value internal

  let build_values config initial_value =
    let build (Flag flag, _) acc =
      match flag.abstraction.values with
      | Struct structure -> add_value_structure acc structure
      | Single (module V) -> add_value_leaf acc (V (V.key, (module V)))
    in
    let value = Config.fold build config initial_value in
    open_value_abstraction value

  module type Struct = sig type v val s : v value end

  module Convert (Value: Abstract.Value.External) (Struct: Struct) = struct
    type extended = Value.t

    let structure =
      match Struct.s with
      | Single (module V) -> Abstract.Value.Leaf (V.key, (module V))
      | Struct s -> s

    let replace =
      let rec set: type v. v structure -> v -> Value.t -> Value.t = function
        | Leaf (key, _) -> Value.set key
        | Node (s1, s2) ->
          let set1 = set s1 and set2 = set s2 in
          fun (v1, v2) value -> set1 v1 (set2 v2 value)
        | Option (s, default) -> fun v -> set s (Option.value ~default v)
        | Unit -> fun () value -> value
        | Void -> void_value ()
      in
      set structure

    let extend v = replace v Value.top

    let restrict =
      let rec get: type v. v structure -> Value.t -> v = function
        | Leaf (key, _) -> Option.get (Value.get key)
        | Node (s1, s2) ->
          let get1 = get s1 and get2 = get s2 in
          fun v -> get1 v, get2 v
        | Option (s, _) -> fun v -> Some (get s v)
        | Unit -> fun _ -> ()
        | Void -> void_value ()
      in
      get structure
  end
end



(* --- Building value abstractions ------------------------------------------ *)

module Leaf_Location (Loc: Abstract_location.Leaf) = struct
  include Loc
  let structure = Abstract.Location.Leaf (Loc.key, (module Loc))
end

module Internal_Loc = struct
  open Abstract.Location

  let eq_loc : type a b. a structure -> b location -> (a, b) dec_eq =
    fun structure -> function
      | StructLoc s -> eq_structure structure s
      | SingleLoc (module L) ->
        match structure with
        | Leaf (key, _) -> eq_type key L.key
        | _ -> None

  type loc_key_module = L : 'l key * 'l data -> loc_key_module

  let open_loc_abstraction (module Loc : Internal) =
    (module struct
      include Loc
      include Structure.Open (Abstract.Location) (struct
        include Loc
        type t = location
      end)
    end : Abstract.Location.External)

  (* TODO: Location product ? *)
  let add_loc_leaf loc (L (key, _l)) =
    let module Loc = (val open_loc_abstraction loc) in
    if Loc.mem key then loc else
      (* (module struct *)
      (*   include Location_product.Make (Loc) (val l) *)
      (*   let structure = Node (Loc.structure, Leaf (key, l)) *)
      (* end) *)
      assert false

  let void_loc () =
    Self.fatal "Cannot register a location module from a Void structure."

  let add_loc_structure loc internal =
    let rec aux: type l. (module Internal) -> l structure -> (module Internal) =
      fun loc -> function
        | Option (s, _) -> aux loc s
        | Leaf (key, v) -> add_loc_leaf loc (L (key, v))
        | Node (s1, s2) -> aux (aux loc s1) s2
        | Unit -> loc
        | Void -> void_loc ()
    in
    aux loc internal

  let build_locs config initial_loc =
    let build (Flag flag, _) acc =
      match flag.abstraction.location with
      | StructLoc structure -> add_loc_structure acc structure
      | SingleLoc (module L) -> add_loc_leaf acc (L (L.key, (module L)))
    in
    Config.fold build config initial_loc |> open_loc_abstraction

  module type Struct = sig type l val s : l location end

  module Convert (Loc: Abstract.Location.External) (Struct: Struct) = struct
    type extended = Loc.location

    let structure =
      match Struct.s with
      | SingleLoc (module L) -> Abstract.Location.Leaf (L.key, (module L))
      | StructLoc s -> s

    let replace =
      let rec set: type l. l structure -> l -> Loc.location -> Loc.location = function
        | Leaf (key, _) -> Loc.set key
        | Node (s1, s2) ->
          let set1 = set s1 and set2 = set s2 in
          fun (l1, l2) loc -> set1 l1 (set2 l2 loc)
        | Option (s, default) -> fun l -> set s (Option.value ~default l)
        | Unit -> fun () loc -> loc
        | Void -> void_loc ()
      in
      set structure

    let extend l = replace l Loc.top

    let restrict =
      let rec get: type l. l structure -> Loc.location -> l = function
        | Leaf (key, _) -> Option.get (Loc.get key)
        | Node (s1, s2) ->
          let get1 = get s1 and get2 = get s2 in
          fun l -> get1 l, get2 l
        | Option (s, _) -> fun l -> Some (get s l)
        | Unit -> fun _ -> ()
        | Void -> void_loc ()
      in
      get structure
  end
end



(* --- Building domain abstractions ----------------------------------------- *)

module type Acc = sig
  module Val : Abstract.Value.External
  module Loc : Abstract.Location.External
    with type value = Val.t
  module Dom : Abstract.Domain.Internal
    with type value = Val.t and type location = Loc.location
end

module Leaf_Domain (D: Abstract_domain.Leaf) = struct
  include D
  let structure = Abstract.Domain.Leaf (D.key, (module D))
end


module type Typ = sig type t end
let conversion_id (type t) (module T: Typ with type t = t) =
  (module struct
    type extended = T.t
    type internal = T.t
    let extend x = x
    let restrict x = x
  end: Domain_lift.Conversion with type extended = t and type internal = t)

type ('v, 'l) internal_domain =
  (module Abstract.Domain.Internal with type value = 'v and type location = 'l)

let add_domain (type v) (type l) dname mode (abstraction: (v, l) abstraction) (module Acc: Acc) =
  let domain : (Acc.Val.t, Acc.Loc.location) internal_domain =
    let eq_loc = Internal_Loc.eq_loc Acc.Loc.structure abstraction.location in
    match abstraction.domain with
    | FunctorValue (module Functor) ->
      let module Domain = Leaf_Domain (Functor.Make (Acc.Val)) in
      begin match eq_loc with
        | Some Structure.Eq -> (module Domain)
        | None ->
          let module ConvertVal = (val conversion_id (module Acc.Val)) in
          let module ConvertLoc = Internal_Loc.Convert (Acc.Loc) (struct
            type l = Domain.location
            let s = abstraction.location
          end) in
          (module Domain_lift.Make (Domain) (ConvertVal) (ConvertLoc))
      end
    | Domain (module Domain) ->
      let eq_value = Internal_Value.eq_value Acc.Val.structure abstraction.values in
      match eq_value, eq_loc with
      | Some Structure.Eq, Some Structure.Eq -> (module Leaf_Domain (Domain))
      | Some Structure.Eq, None ->
        let module ConvertVal = (val conversion_id (module Acc.Val)) in
        let module ConvertLoc = Internal_Loc.Convert (Acc.Loc) (struct
          type l = Domain.location
          let s = abstraction.location
        end) in
        (module Domain_lift.Make (Domain) (ConvertVal) (ConvertLoc))
      | None, Some Structure.Eq ->
        let module ConvertVal = Internal_Value.Convert (Acc.Val) (struct
          type v = Domain.value
          let s = abstraction.values
        end) in
        let module LocTyp = struct type t = Acc.Loc.location end in
        let module ConvertLoc = (val conversion_id (module LocTyp)) in
        (module Domain_lift.Make (Domain) (ConvertVal) (ConvertLoc))
      | None, None ->
        let module ConvertVal = Internal_Value.Convert (Acc.Val) (struct
          type v = Domain.value
          let s = abstraction.values
        end) in
        let module ConvertLoc = Internal_Loc.Convert (Acc.Loc) (struct
          type l = Domain.location
          let s = abstraction.location
        end) in
        (module Domain_lift.Make (Domain) (ConvertVal) (ConvertLoc))
  in
  (* Set the name of the domain. *)
  let module Domain = struct
    include (val domain)
    module Store = struct
      include Store
      let register_global_state storage state =
        let no_results = Parameters.NoResultsDomains.mem dname in
        register_global_state (storage && not no_results) state
    end
  end in
  (* Restricts the domain according to [mode]. *)
  let domain : (Acc.Val.t, Acc.Loc.location) internal_domain =
    match mode with
    | None -> (module Domain)
    | Some kf_modes ->
      let module Scope = struct let functions = kf_modes end in
      let module Domain =
        Domain_builder.Restrict
          (Acc.Val)
          (Domain)
          (Scope)
      in
      (module Domain)
  in
  let domain : (Acc.Val.t, Acc.Loc.location) internal_domain =
    match Abstract.Domain.(eq_structure Acc.Dom.structure Unit) with
    | Some _ -> domain
    | None ->
      (* The new [domain] becomes the left leaf of the domain product, and will
         be processed before the domains from [Acc.Dom] during the analysis. *)
      (module Domain_product.Make (Acc.Val) ((val domain)) (Acc.Dom))
  in
  (module struct
    module Val = Acc.Val
    module Loc = Acc.Loc
    module Dom = (val domain)
  end : Acc)

let warn_experimental flag =
  if flag.experimental then
    Self.(warning ~wkey:wkey_experimental
            "The %s domain is experimental." flag.name)

let build_domain config abstract =
  let build (Flag flag, mode) acc =
    warn_experimental flag;
    add_domain flag.name mode flag.abstraction acc
  in
  (* Domains in the [config] are sorted by increasing priority: domains with
     higher priority are added last: they will be at the top of the domains
     tree, and thus will be processed first during the analysis. *)
  Config.fold build config abstract



(* --- Value reduced product ----------------------------------------------- *)

module type Value = sig
  include Abstract.Value.External
  val reduce : t -> t
end

module type S = sig
  module Val : Value
  module Loc : Abstract.Location.External
    with type value = Val.t
  module Dom : Abstract.Domain.External
    with type value = Val.t and type location = Loc.location
end

module type Eva = sig
  include S
  module Eval: Evaluation.S
    with type state = Dom.t
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
      if Ival.is_int ival'
      then
        let reduced_ival = Ival.narrow ival ival' in
        let cvalue = Cvalue.V.inject_ival reduced_ival in
        cvalue, Some reduced_ival
      else cvalue, Some ival
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

module CVal = Leaf_Value (Main_values.CVal)

let unit_acc (type v)
  (module Value: Abstract.Value.External with type t = v)
  (module Loc: Abstract.Location.External with type value = v) =
    (module struct
      module Val = Value
      module Loc = Loc
      module Dom = Unit_domain.Make (Val) (Loc)
    end: Acc)

(* let unit_acc (module Value: Abstract.Value.External) = *)
(*   let loc : (module Abstract.Location.Internal with type value = Value.t) = *)
(*     match Abstract.Value.eq_structure Value.structure CVal.structure with *)
(*     | Some Structure.Eq -> (module Leaf_Location (Main_locations.PLoc)) *)
(*     | _ -> *)
(*       let module Struct = struct *)
(*         type v = Cvalue.V.t *)
(*         let s = Single (module Main_values.CVal) *)
(*       end in *)
(*       let module Conv = Internal_Value.Convert (Value) (Struct) in *)
(*       (module Location_lift.Make (Main_locations.PLoc) (Conv)) *)
(*   in *)
(*   (module struct *)
(*     module Val = Value *)
(*     module Loc = (val loc) *)
(*     module Dom = Unit_domain.Make (Val) (Loc) *)
(*   end : Acc) *)

let build_abstractions config =
  let initial_loc = (module Main_locations.PLoc: Abstract.Location.Internal) in
  let initial_value : (module Abstract.Value.Internal) =
    if Config.mem Config.bitwise config
    then (module Offsm_value.CvalueOffsm)
    else (module CVal)
  in
  let value = Internal_Value.build_values config initial_value in
  let loc = Internal_Loc.build_locs config initial_loc in
  let acc = unit_acc value loc in
  build_domain config acc

let configure = Config.configure

let make config =
  let abstractions = build_abstractions config in
  let abstractions = (module Open (val abstractions): S) in
  apply_final_hooks abstractions

module Default = (val make Config.default)
module Legacy = (val make Config.legacy)
