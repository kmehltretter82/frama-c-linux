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



(* --- Values abstraction --------------------------------------------------- *)

module Value = struct
  type 'v structure = 'v Abstract.Value.structure
  type 'v key = 'v Abstract.Value.key
  let dec_eq = Abstract.Value.eq_structure

  type 'v value = (module Abstract_value.S with type t = 'v)


  (* Value registration *)
  type 'v register = { key : 'v key ; value : 'v value }
  type 'v registered = 'v key * 'v value
  let register : type v. v register -> v registered =
    fun { key ; value } -> (key, value)


  (* When registering a location or a domain, the user has to declare its
     values dependencies, i.e the values it uses during its computations. To
     simplify the abstraction build and the dependencies declaration, they
     are handled as a simple list. Arguably not so simple as it is
     heterogenous, but it is still a list. *)
  type 'v dependencies =
    | Last : 'v registered -> 'v dependencies
    | (::) : 'a registered * 'b dependencies -> ('a * 'b) dependencies

  (* When building the abstraction, we will need to compare the dependencies
     structure with the structured values. *)
  let rec outline : type v. v dependencies -> v structure = function
    | Last (key, value) -> Abstract.Value.Leaf (key, value)
    | (k, v) :: tl -> Abstract.Value.(Node (Leaf (k, v), outline tl))

  (* Folding over values dependencies *)
  type 'a folder = { folder : 'v. 'v registered -> 'a -> 'a }
  let rec fold : type v. 'a folder -> v dependencies -> 'a -> 'a =
    fun { folder } dependencies acc ->
    match dependencies with
    | Last registered -> folder registered acc
    | hd :: tl -> fold { folder } tl (folder hd acc)


  (* The value abstraction build consists of accumulating registered values
     into a structured value and then adding the needed operators, thus making
     it interactive. A [Unit] structured abstraction is used for the initial
     state and is discarded as soon as a real value abstraction is added. *)
  module type Structured = Abstract.Value.Internal
  module type Interactive = Abstract.Value.External
  type 'a or_unit = Unit | Value of 'a
  type structured = (module Structured) or_unit
  type interactive = (module Interactive) or_unit

  (* Making a structured value interactive simply consists of adding the
     needed operations using the Structure.Open functor.*)
  let make_interactive : structured -> interactive = function
    | Unit -> Unit
    | Value (module Structured) ->
      Value (module struct
        include Structured
        include Structure.Open (Abstract.Value) (Structured)
      end)

  (* Adding a registered value into a structured one consists of deciding if
     a product is needed (which comes down to checking if the registered
     value key we want to add is not in the structure), computing it, and
     updating the structure. *)
  let add : type v. v registered -> structured -> structured =
    fun (key, input) structured ->
    let open Abstract.Value in
    match make_interactive structured with
    | Unit ->
      Value (module struct
        include (val input)
        let structure = Leaf (key, input)
      end)
    | Value (module Interactive) when not (Interactive.mem key) ->
      Value (module struct
        include Value_product.Make (Interactive) (val input)
        let structure = Node (Interactive.structure, Leaf (key, input))
      end)
    | _ -> structured

  (* The minimal value abstraction to use. *)
  let init : structured = Unit

  (* During the complete abstraction build, we need to verify that there is at
     least one value in the computed abstraction.
     TODO: better error handling. *)
  let assert_not_unit = function
    | Unit -> Self.fatal "The built value cannot be unit."
    | Value interactive -> interactive


  (* When building the complete abstraction, we need to trick locations and
     domains into thinking that their value dependencies are there, even if
     the structured value type is not the good one. This is done through a
     lift that requires conversion operations to interact with the subpart
     of the structured value that matters for the location or the domain.
     This functor is responsible of building such conversion operations. *)
  module type From = sig type value val structure : value structure end
  module Converter (From : From) (To : Interactive) = struct
    type extended = To.t
    let structure = From.structure

    let void_value () =
      Self.fatal "Cannot register a value module from a Void structure."

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
  let dec_eq = Abstract.Location.eq_structure

  type ('v, 'l) location =
    (module Abstract_location.S with type value = 'v and type location = 'l)


  (* When registering a location, we also need its key and its values
     dependencies. *)
  type ('v, 'l) register =
    { key: 'l key
    ; location : ('v, 'l) location
    ; dependencies : 'v Value.dependencies
    }

  (* A registered location is simply a location with its key and its values
     dependencies. *)
  module type Registered = sig
    include Abstract_location.S
    val key : location key
    val structure : location structure
    val dependencies : value Value.dependencies
  end
  type 'l registered = (module Registered with type location = 'l)

  (* Location registration. *)
  let register : type v l. (v, l) register -> l registered =
    fun { key ; location ; dependencies } ->
    (module struct
      module Location = (val location)
      include Location
      let key = key
      let structure = Abstract.Location.Leaf (key, (module Location))
      let dependencies = dependencies
    end)


  (* When registering a domain, the user has to declare its locations
     dependencies, i.e the locations it uses during its computations. As
     for the values, they are handled as a simple heterogenous list. *)
  type 'l dependencies =
    | Last : 'l registered -> 'l dependencies
    | (::) : 'a registered * 'b dependencies -> ('a * 'b) dependencies

  (* When building the abstraction, we will need to compare dependencies
     with the structured locations. *)
  let rec outline : type l. l dependencies -> l structure = function
    | Last (module R) -> R.structure
    | (module R) :: tl -> Abstract.Location.Node (R.structure, outline tl)

  (* Folding over locations dependencies *)
  type 'a folder = { folder : 'v. 'v registered -> 'a -> 'a }
  let rec fold : type v. 'a folder -> v dependencies -> 'a -> 'a =
    fun { folder } dependencies acc ->
    match dependencies with
    | Last registered -> folder registered acc
    | hd :: tl -> fold { folder } tl (folder hd acc)

  (* Folding over the values dependencies of some locations dependencies. *)
  let rec fold_values : type v. 'a Value.folder -> v dependencies -> 'a -> 'a =
    fun folder dependencies acc ->
    match dependencies with
    | Last (module R) -> Value.fold folder R.dependencies acc
    | (module R) :: tl ->
      fold_values folder tl (Value.fold folder R.dependencies acc)


  (* As for the value abstraction, building the location abstraction consists
     of structuring the needed registered locations and then adding the needed
     operators to make it interactive. However, a structured location is not
     as simple as a structured value, as it needs to keep track of the value
     abstraction it is based on. This value is supposed to be the complete
     aggregation of all the values that are needed by the requested domains. *)
  module type Structured = sig
    type value
    module Value : Value.Interactive with type t = value
    module Location : Abstract.Location.Internal with type value = value
  end

  module type Interactive = Abstract.Location.External

  (* We expose the type of the structured value we are based on to statically
     ensure that we do not temper with it. As for the value abstractions, a
     [Unit] structured abstraction is used for the initial state and is
     discarded as soon as a location is added. *)
  type ('u, 'l) or_unit = Unit of 'u | Location of 'l
  type 'v value = (module Value.Interactive with type t = 'v)
  type 'v structured_module = (module Structured with type value = 'v)
  type 'v structured = ('v value, 'v structured_module) or_unit
  type 'v interactive_module = (module Interactive with type value = 'v)
  type 'v interactive = ('v value, 'v interactive_module) or_unit

  (* Initial location builder *)
  let init (value : 'v value) : 'v structured = Unit value

  (* During the complete abstraction build, we need to verify that there is at
     least one location in the computed abstraction.
     TODO: better error handling. *)
  let assert_not_unit = function
    | Unit _ -> Self.fatal "The built location cannot be unit."
    | Location interactive -> interactive


  (* Making a structured value interactive simply consists of adding the
     needed operations using the Structure.Open functor.*)
  let make_interactive : type v. v structured -> v interactive = function
    | Unit value -> Unit value
    | Location (module Structured) ->
      Location (module struct
        include Structured.Location
        include Structure.Open (Abstract.Location) (struct
            include Structured.Location
            type t = location
          end)
      end)

  (* Retrieves the value contained in a structured location. *)
  let get_value : type v. v structured -> v value = function
    | Unit value -> value
    | Location (module S) -> (module S.Value)


  (* Adding a registered location into a structured one is done in three steps:
     1. Lifting the location abstraction we want to add to match the value
        abstraction contained in the structured abstraction.
     2. Combine the given location abstraction with the one contained in the
        structured abstraction. It comes down to decide if a reduced product is
        needed.
     3. Rebuild a structured abstraction with the new location abstraction. *)
  let add : type v l. l registered -> v structured -> v structured =
    fun (module Registered) structured ->
    let deps = Value.outline Registered.dependencies in
    let module To = (val get_value structured) in
    let module From = struct include Registered let structure = deps end in
    let module Converter = Value.Converter (From) (To) in
    let lifted : (module Abstract.Location.Internal with type value = v) =
      match Value.dec_eq deps To.structure with
      | Some Eq -> (module Registered)
      | None -> (module Location_lift.Make (Registered) (Converter))
    in
    let combined : (module Abstract.Location.Internal with type value = v) =
      match make_interactive structured with
      | Unit _ -> lifted
      | Location (module Loc) when Loc.mem Registered.key -> (module Loc)
      | Location (module Loc) ->
        (module Locations_product.Make (To) (val lifted) (Loc))
    in
    Location (module struct
      type value = v
      module Value = To
      module Location = (val combined)
    end)


  (* When building the complete abstraction, we need to trick domains into
     thinking that their locations dependencies are there, even if the
     structured location type is not the good one. This is done through a
     lift that requires conversion operations to interact with the subpart
     of the structured location that matters for the domains. This functor is
     responsible of building such conversion operations. *)
  module type From = sig type location val structure : location structure end
  module Converter (From : From) (To : Interactive) = struct
    type extended = To.location
    let structure = From.structure

    let void_location () =
      Self.fatal "Cannot register a location module from a Void structure."

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
end



(* --- Domains abstraction -------------------------------------------------- *)

module Domain = struct
  type 's structure = 's Abstract.Domain.structure
  type 's key = 's Abstract.Domain.key
  module type S = Abstract_domain.S


  (* Registration of leaf domains, i.e simple domain with a fixed value. *)
  module Leaf = struct
    type ('v, 'l, 's) domain =
      (module S with type value = 'v and type location = 'l and type state = 's)

    (* We need the values and locations dependendies to register a domain. *)
    type ('v, 'l, 's) register =
      { key : 's key
      ; domain : ('v, 'l, 's) domain
      ; values : 'v Value.dependencies
      ; locations : 'l Location.dependencies
      }

    (* As for the locations, a registered domain is a simple module that
       contains all the information given during the register along with
       the domain structure (which is a leaf). *)
    module type Registered = sig
      include Abstract_domain.S
      val key : state key
      val structure : state structure
      val values : value Value.dependencies
      val locations : location Location.dependencies
    end

    (* Registration procedure. *)
    type 's registered = (module Registered with type state = 's)
    let register : type v l s. (v, l, s) register -> s registered =
      fun { key ; domain ; values ; locations } ->
      (module struct
        module Domain = (val domain)
        include Domain
        let key = key
        let structure = Abstract.Domain.Leaf (key, (module Domain))
        let values = values
        let locations = locations
      end)
  end


  (* Registration of a functor domain, i.e a domain that can be built on top of
     any value. *)
  module Functor = struct

    (* A functor domain is declared as an existantiel. This module type has to
       be read as: there exists a type <location> such as, given any Value, we
       can build a domain using this Value and relying on a Location of type
       <location>. *)
    module type Domain = sig
      type location
      module Make (V : Value.Interactive) : sig
        include Abstract_domain.S
          with type value = V.t
           and type location = location
        val key : state key
      end
    end
    type 'l domain = (module Domain with type location = 'l)

    (* As a functor domain can be instanciated for any value, we only need
       locations dependencies to register it. *)
    type 'l register =
      { domain : 'l domain
      ; locations : 'l Location.dependencies
      }

    (* Once registered, a functor domain builds a domain along with its
       structure and its key. *)
    module type RegisteredLeaf = sig
      include Abstract.Domain.Internal
      val key : state key
    end

    (* A registered functor domain contains its locations dependencies and a
       functor that builds a domain along its structure and its key. *)
    module type Registered = sig
      type location
      val locations : location Location.dependencies
      module Make (V : Value.Interactive) :
        RegisteredLeaf with type value = V.t and type location = location
    end

    (* Registration procedure. *)
    type registered = (module Registered)
    let register : type l. l register -> registered =
      fun { domain ; locations } ->
      let module Domain = (val domain) in
      (module struct
        type location = Domain.location
        let locations = locations
        module Make (V : Value.Interactive) = struct
          module Result = Domain.Make (V)
          include Result
          let structure = Abstract.Domain.Leaf (key, (module Result))
        end
      end)
  end


  (* To simplify the domain registration procedure, we provide common types.
     However, the code above is still useful to prove some properties, mainly
     that we do not temper with the dependencies. *)
  type register =
    | Domain : ('v, 'l, 's) Leaf.register -> register
    | Functor : 'l Functor.register -> register

  type registered =
    | RegisteredDomain  : 's Leaf.registered -> registered
    | RegisteredFunctor : Functor.registered -> registered

  (* Registered domain are saved in mutable lists along with there information,
     i.e. there name, there experimental and there priority flags. *)
  type 't with_info =
    { name : string
    ; experimental : bool
    ; priority : int
    ; abstraction : 't
    }

  (* The configuration of an analysis contains a set of domains along with their
     mode. *)
  type 't with_mode = 't * Domain_mode.t option


  (* Mutable lists containing statically and dynamically registered domains. *)
  let static_domains = ref []
  let dynamic_domains = ref []

  (* Helper function used to register the parameters of a domain. *)
  let register_domain_option ~name ~experimental ~descr =
    let descr = if experimental then "Experimental. " ^ descr else descr in
    Parameters.register_domain ~name ~descr

  (* Helper function used to dispatch the registration process to the good
     registration process depending of the domain kind. *)
  let register_abstraction = function
    | Domain register -> RegisteredDomain (Leaf.register register)
    | Functor register -> RegisteredFunctor (Functor.register register)

  (* Registration of a static domain. *)
  let register ~name ~descr ?(experimental=false) ?(priority=0) register =
    register_domain_option ~name ~descr ~experimental ;
    let abstraction = register_abstraction register in
    let registered = { name ; experimental ; priority ; abstraction } in
    static_domains := registered :: !static_domains ;
    abstraction

  (* Registration of a dynamic domain. *)
  let dynamic_register ~name ~descr ?(experimental=false) ?(priority=0) make =
    register_domain_option ~name ~descr ~experimental ;
    let make () = make () |> register_abstraction in
    let make () = { name ; experimental ; priority ; abstraction = make () } in
    dynamic_domains := (name, make) :: !dynamic_domains


  (* Building the domain abstraction consists of structuring the requested
     registered domains. To do so, we need to keep track of the values and
     locations abstraction on which the structured domain will rely. Those
     abstractions are supposed to be the complete aggregations of all the
     values (resp locations) that are needed by the requested domains. *)
  module type Structured = sig
    type value
    type location
    module Value : Value.Interactive with type t = value
    module Location : Location.Interactive
      with type value = value and type location = location
    module Domain : Abstract.Domain.Internal
      with type value = value and type location = location
  end

  (* As for the value and location abstractions, a [Unit] structured domain is
     used for the initial state. *)
  type ('v, 'l, 's) or_unit = Unit of 'v * 'l | State of 's
  type 'v value = (module Value.Interactive with type t = 'v)
  type ('v, 'l) location =
    (module Location.Interactive with type value = 'v and type location = 'l)
  type ('v, 'l) structured_module =
    (module Structured with type value = 'v and type location = 'l)
  type ('v, 'l) structured =
    ('v value, ('v, 'l) location, ('v, 'l) structured_module) or_unit

  (* Recovers the value and location abstractions of a structured domain. *)
  let get : type v l. (v, l) structured -> v value * (v, l) location = function
    | Unit (value, location) -> (value, location)
    | State (module S) -> ((module S.Value), (module S.Location))

  (* During the complete abstraction build, we need to verify that there is at
     least one domain in the computed abstraction.
     TODO: better error handling. *)
  let assert_not_unit = function
    | Unit _ -> Self.fatal "The built domain cannot be unit."
    | State structured -> structured


  (* Internal type used for intermediate results of the add procedure. *)
  type ('v, 'l) structured_domain =
    (module Abstract.Domain.Internal with type value = 'v and type location = 'l)

  (* Utility function used to create an identity converter. *)
  module type Typ = sig type t end
  let conversion_id (type t) (module T: Typ with type t = t) =
    (module struct
      type extended = T.t
      type internal = T.t
      let extend x = x
      let restrict x = x
    end: Domain_lift.Conversion with type extended = t and type internal = t)

  (* Adding a registered domain into a structured one consists of performing a
     lifting of the registered one if needed before performing the product,
     configuring the name and restricting the domain depending of the mode. *)
  type add_input = registered with_info with_mode
  let add : type v l. add_input -> (v, l) structured -> (v, l) structured =
    fun (registered, mode) structured ->
    let wkey = Self.wkey_experimental in
    let { experimental = exp ; name } = registered in
    if exp then Self.warning ~wkey "The %s domain is experimental." name ;
    let value, location = get structured in
    let module Val = (val value) in
    let module Loc = (val location) in
    let lifted : (v, l) structured_domain =
      match registered.abstraction with
      | RegisteredFunctor (module Functor) ->
        let locs = Location.outline Functor.locations in
        let eq_loc = Location.dec_eq locs Loc.structure in
        let module D = Functor.Make (Val) in
        begin match eq_loc with
          | Some Eq -> (module D)
          | None ->
            let module Val = (val conversion_id (module Val)) in
            let module From = struct include D let structure = locs end in
            let module Loc = Location.Converter (From) (Loc) in
            (module Domain_lift.Make (D) (Val) (Loc))
        end
      | RegisteredDomain (module D) ->
        let loc_deps = Location.outline D.locations in
        let val_deps = Value.outline D.values in
        let eq_loc = Location.dec_eq loc_deps Loc.structure in
        let eq_val = Value.dec_eq val_deps Val.structure in
        begin match eq_val, eq_loc with
          | Some Eq, Some Eq -> (module D)
          | Some Eq, None ->
            let module Val = (val conversion_id (module Val)) in
            let module From = struct include D let structure = loc_deps end in
            let module Loc = Location.Converter (From) (Loc) in
            (module Domain_lift.Make (D) (Val) (Loc))
          | None, Some Eq ->
            let module From = struct include D let structure = val_deps end in
            let module Val = Value.Converter (From) (Val) in
            let module LocTyp = struct type t = Loc.location end in
            let module Loc = (val conversion_id (module LocTyp)) in
            (module Domain_lift.Make (D) (Val) (Loc))
          | _, _ ->
            let module From = struct include D let structure = val_deps end in
            let module Val = Value.Converter (From) (Val) in
            let module From = struct include D let structure = loc_deps end in
            let module Loc = Location.Converter (From) (Loc) in
            (module Domain_lift.Make (D) (Val) (Loc))
        end
    in
    (* Set the name of the domain. *)
    let module Named = struct
      include (val lifted)
      module Store = struct
        include Store
        let register_global_state storage state =
          let no_results = Parameters.NoResultsDomains.mem registered.name in
          register_global_state (storage && not no_results) state
      end
    end in
    (* Restricts the domain according to [mode]. *)
    let restricted : (v, l) structured_domain =
      match mode with
      | None -> (module Named)
      | Some kf_modes ->
        let module Scope = struct let functions = kf_modes end in
        (module Domain_builder.Restrict (Val) (Named) (Scope))
    in
    let combined : (v, l) structured_domain =
      match structured with
      | Unit _ -> restricted
      | State (module Structured) ->
        (* The new [domain] becomes the left leaf of the domain product, and
           will be processed before the domains from [Acc.Dom] during the
           analysis. *)
        let module Dom = Structured.Domain in
        (module Domain_product.Make (Val) (val restricted) (Dom))
    in
    State (module struct
      type value = v
      type location = l
      module Value = Val
      module Location = Loc
      module Domain = (val combined)
    end)


  (* Build a complete abstraction based on a list of registered domains and a
     value initial configuration. *)
  let build domains : (module Structured) =
    let values =
      let add_value = Value.{ folder = add } in
      let add_values values (registered, _) =
        match registered.abstraction with
        | RegisteredDomain (module Domain) ->
          Value.fold add_value Domain.values values |>
          Location.fold_values add_value Domain.locations
        | RegisteredFunctor (module F) ->
          Location.fold_values add_value F.locations values
      in
      List.fold_left add_values Value.init domains |>
      Value.make_interactive
    in
    let module V = (val Value.assert_not_unit values) in
    let locations =
      let init : V.t Location.structured = Location.init (module V) in
      let add_loc = Location.{ folder = add } in
      let add_locations locs (registered, _) =
        match registered.abstraction with
        | RegisteredDomain  (module D) -> Location.fold add_loc D.locations locs
        | RegisteredFunctor (module D) -> Location.fold add_loc D.locations locs
      in
      List.fold_left add_locations init domains |>
      Location.make_interactive
    in
    let module L = (val Location.assert_not_unit locations) in
    let structured : (V.t, L.location) structured =
      Unit ((module V), (module L))
    in
    let structured = List.fold_left (fun s d -> add d s) structured domains in
    let module Structured : Structured = (val assert_not_unit structured) in
    (module Structured)
end



(* --- Configuration -------------------------------------------------------- *)

module Config = struct
  module Mode = Datatype.Option (Domain_mode)

  include Set.Make (struct
      open Domain
      type t = registered with_info with_mode
      let compare (d1, m1) (d2, m2) =
        let c = Datatype.Int.compare d1.priority d2.priority in
        if c = 0 then
          let c = Datatype.String.compare d1.name d2.name in
          if c = 0 then Mode.compare m1 m2 else c
        else c
    end)

  let singleton name abstraction =
    let experimental = false and priority = 9 in
    let abstraction = Domain.{ name ; priority ; experimental ; abstraction } in
    singleton (abstraction, None)

  let configure () =
    let find = Parameters.DomainsFunction.find in
    let find name = try Some (find name) with Not_found -> None in
    let main () = Globals.entry_point () |> fst in
    let add_main_mode modes = (main (), Domain_mode.Mode.all) :: modes in
    let dynamic (name, make) config =
      let enabled = Parameters.Domains.mem name in
      let enable modes = if enabled then add_main_mode modes else modes in
      match find name with
      | None -> if enabled then add (make (), None) config else config
      | Some modes -> add (make (), Some (enable modes)) config
    in
    let static d = dynamic (d.Domain.name, fun () -> d) in
    let fold f xs acc = List.fold_left (fun acc x -> f x acc) acc xs in
    fold static !Domain.static_domains empty |>
    fold dynamic !Domain.dynamic_domains
end



(* --- Value reduced product ----------------------------------------------- *)

module Reducer = struct
  type 'a key = 'a Value.key
  type ('a, 'b) reducer = 'a -> 'b -> 'a * 'b
  type action = Action : 'a key * 'b key * ('a, 'b) reducer -> action

  let actions = ref []

  let register left right reducer =
    actions := (Action (left, right, reducer)) :: !actions

  module type Value = sig
    include Abstract.Value.External
    val reduce : t -> t
  end

  module Make (Value : Abstract.Value.External) = struct
    include Value

    let make_reduction acc (Action (key1, key2, f)) =
      match Value.get key1, Value.get key2 with
      | Some get1, Some get2 ->
        let set1 = Value.set key1 and set2 = Value.set key2 in
        let reduce v = f (get1 v) (get2 v) in
        let reducer v = let v1, v2 = reduce v in set1 v1 (set2 v2 v) in
        reducer :: acc
      | _, _ -> acc

    let reduce =
      let list = List.fold_left make_reduction [] !actions in
      fun v -> List.fold_left (fun v reduce -> reduce v) v list
  end
end



(* --- Finalizing abstractions build ---------------------------------------- *)

module type S = sig
  module Val : Reducer.Value
  module Loc : Abstract.Location.External with type value = Val.t
  module Dom : Abstract.Domain.External
    with type value = Val.t and type location = Loc.location
end

module type S_with_evaluation = sig
  include S
  module Eval : Evaluation_sig.S
    with type state = Dom.t
     and type value = Val.t
     and type loc = Loc.location
     and type origin = Dom.origin
end

module Hooks = struct
  let hooks = ref []
  type hook = (module S) -> (module S)
  let register (f : hook) = hooks := f :: !hooks
  let apply abst = List.fold_left (fun acc f -> f acc) abst !hooks
end

module Open (Structured : Domain.Structured) : S = struct
  module Val = Reducer.Make (Structured.Value)
  module Loc = Structured.Location
  module Dom = struct
    include Structured.Domain
    include Structure.Open (Abstract.Domain) (Structured.Domain)
  end
end

let make config =
  let abstractions = Config.elements config |> Domain.build in
  let abstractions = (module Open (val abstractions) : S) in
  Hooks.apply abstractions
