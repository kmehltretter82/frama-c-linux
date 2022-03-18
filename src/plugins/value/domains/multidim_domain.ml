(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2022                                               *)
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
open Eval

let dkey = Self.register_category "d-multidim"

let map_to_singleton map =
  let aux base offset = function
    | None -> Some (base, offset)
    | Some _ -> raise Exit
  in
  try Base.Base.Map.fold aux map None with Exit -> None

module Value =
struct
  include Cvalue.V
  include Cvalue_forward (* for fallback oracles *)

  let backward_is_finite positive fkind v =
    let prec = Fval.kind fkind in
    try
      let v = reinterpret_as_float fkind v in
      Fval.backward_is_finite ~positive prec (project_float v) >>-: inject_float
    with Not_based_on_null ->
      `Value v
end

module Value_or_Uninitialized =
struct
  open Cvalue
  include V_Or_Uninitialized

  let to_integer cvalue =
    try  Some (Ival.project_int (V.project_ival (get_v cvalue)))
    with V.Not_based_on_null | Ival.Not_Singleton_Int -> None

  let make i v =
    let initialized = match i with
      | Abstract_memory.SurelyInitialized -> true
      | Abstract_memory.MaybeUninitialized -> false
    in
    V_Or_Uninitialized.make ~initialized ~escaping:false v

  let of_value v =
    V_Or_Uninitialized.make ~initialized:true ~escaping:false v

  let of_bit = function
    | Abstract_memory.Uninitialized -> uninitialized
    | Zero i -> make i (V.inject_int Integer.zero)
    | Any (Set s,i) -> make i (V.inject_top_origin Origin.top s)
    | Any (Top, i) -> make i (V.top_with_origin Origin.top)

  let to_bit v' =
    let v = get_v v'
    and initialization =
      if is_initialized v'
      then Abstract_memory.SurelyInitialized
      else Abstract_memory.MaybeUninitialized
    in
    if V.is_bottom v
    then Abstract_memory.Uninitialized
    else if V.is_zero v
    then Abstract_memory.Zero (initialization)
    else Abstract_memory.Any (V.get_bases v, initialization)

  let from_flagged fv =
    V_Or_Uninitialized.make
      ~initialized:fv.initialized
      ~escaping:false
      (Bottom.value ~bottom:V.bottom fv.v)

  let map' f v =
    f (get_v v) >>-: fun new_v -> map (fun _ -> new_v) v
end

let no_oracle exp =
  match Cil.isInteger exp with
  | None -> raise Abstract_interp.Error_Top
  | Some i -> Value.inject_int i

let convert_oracle oracle =
  fun exp ->
  match Ival.project_int_val (Value.project_ival (oracle exp)) with
  | Some int_val -> int_val
  | None | exception Value.Not_based_on_null -> Int_val.top

type assigned = (Precise_locs.precise_location,Value.t) Eval.assigned
type builtin = assigned list -> assigned or_bottom

let builtins : (string * builtin) list = []

let find_builtin =
  let module Table = Stdlib.Hashtbl in
  let table = Table.create 17 in
  List.iter (fun (name, f) -> Table.replace table name f) builtins;
  fun kf ->
    try Some (Table.find table (Kernel_function.get_name kf))
    with Not_found -> None


module Location =
struct
  open Abstract_offset

  module Offset = TypedOffsetOrTop
  module Map = Base.Base.Map

  type offset = Offset.t
  type base = Base.t
  type t = offset Map.t

  let _pretty =
    Pretty_utils.pp_iter2 ~sep:",@," ~between:":"
      Map.iter Base.pretty Offset.pretty

  let empty = Map.empty

  let fold : (base-> offset -> 'a -> 'a) -> t -> 'a -> 'a = Map.fold

  let bases map =
    Map.fold (fun b _ acc -> b :: acc) map []

  let is_singleton map =
    match map_to_singleton map with
    | None -> false
    | Some (b,o) ->
      not (Base.is_weak b) && Offset.is_singleton o

  let references map =
    let module Set = Cil_datatype.Varinfo.Set in
    let add_refs _b o =
      Set.union (Set.of_list (Offset.references o))
    in
    Map.fold add_refs map Set.empty |> Set.to_seq |> List.of_seq

  let of_var (vi : Cil_types.varinfo) : t =
    Map.singleton (Base.of_varinfo vi) (`Value (NoOffset vi.vtype))

  (* Raises Abstract_domain.{Error_top,Error_bottom} *)
  let of_lval oracle ((host,offset) as lval : Cil_types.lval) : t =
    let oracle' = convert_oracle oracle in
    let base_typ = Cil.typeOfLhost host in
    let offset =
      if Cil.typeHasQualifier "volatile" (Cil.typeOfLval lval) then
        `Top
      else
        Offset.of_cil_offset oracle' base_typ offset in
    match host with
    | Var vi ->
      Map.singleton (Base.of_varinfo vi) offset
    | Mem exp ->
      let exp, index = match exp.enode with
        | BinOp (PlusPI, e1, e2, _typ) ->
          e1, Some e2
        | _ -> exp, None
      in
      let add base ival map =
        let offset' : Offset.t =
          match Base.typeof base with
          | None -> `Top
          | Some base_typ ->
            let typ = Cil.typeOf_pointed (Cil.typeOf exp) in
            let base_offset = Offset.of_ival ~base_typ ~typ ival in
            let base_offset = match index with
              | None -> base_offset
              | Some exp -> Offset.add_index oracle' base_offset exp
            in
            Offset.append base_offset offset
        in
        Map.add base offset' map
      in
      let loc = Locations.loc_bytes_to_loc_bits (oracle exp) in
      Locations.Location_Bits.fold_i add loc Map.empty

  let of_term_lval env ((lhost, offset) as lval) =
    let vi = match lhost with
      | TVar ({lv_origin=Some vi}) -> vi
      | TResult _ -> Option.get env.Abstract_domain.result
      | _ -> raise Abstract_interp.Error_Top
    in
    let base' = Base.of_varinfo vi in
    let offset' = Offset.of_term_offset vi.vtype offset in
    Map.singleton base' offset', Cil.typeOfTermLval lval

  let of_term env t =
    match t.term_node with
    | TLval term_lval -> of_term_lval env term_lval
    | _ -> raise Abstract_interp.Error_Top

  let of_precise_loc loc =
    let loc' = Precise_locs.imprecise_location loc in
    let add_base base map =
      (* Null base doesn't have a type ; use void instead *)
      let typ = Option.value ~default:Cil.voidType (Base.typeof base) in
      Map.add base (`Value (NoOffset typ)) map
    in
    Locations.Location_Bits.(fold_bases add_base loc'.loc empty)
end


(* Redefines the memory domain so it can handle top locations *)

module Memory =
struct
  module Config = struct
    let deps = [Ast.self]
    let slice_limit = Parameters.MultidimSegmentLimit.get
    let disjunctive_invariants =
      Parameters.MultidimDisjunctiveInvariants.get
  end
  module Memory = Abstract_memory.TypedMemory (Config) (Value_or_Uninitialized)

  module Prototype =
  (* Datatype *)
  struct
    include Datatype.Undefined
    include Memory
    let name = "Multidim_domain.Memory"
    let reprs = [ Memory.top ]
  end

  include Datatype.Make (Prototype)

  let pretty = Memory.pretty
  let _pretty_debug = Memory.pretty
  let top = Memory.top
  let is_top = Memory.is_top
  let is_included = Memory.is_included
  let narrow = fun m1 _m2 -> m1
  let join = Memory.join
  let smash ~oracle = Memory.join ~oracle:(fun _ -> oracle)
  let widen h =
    Memory.widen
      (fun ~size v1 v2 -> Value_or_Uninitialized.widen (size,h) v1 v2)
  let incr_bound = Memory.incr_bound

  let get ~oracle m loc =
    match loc with
    | `Top -> Value_or_Uninitialized.top
    | `Value loc -> Memory.get ~oracle m loc

  let extract ~oracle m loc =
    match loc with
    | `Top -> Memory.top
    | `Value loc -> Memory.extract ~oracle m loc

  let erase ~oracle ~weak m loc bit_value =
    match loc with
    | `Top -> Memory.top
    | `Value loc -> Memory.erase ~oracle ~weak m loc bit_value

  let set ~oracle ~weak new_v m loc =
    match loc with
    | `Top -> Memory.top
    | `Value loc ->
      Memory.set ~oracle ~weak m loc new_v

  let reinforce ~oracle f m loc =
    match loc with
    | `Top -> `Value m
    | `Value loc ->
      Memory.reinforce ~oracle f m loc

  let overwrite ~oracle ~weak dst loc src =
    match loc with
    | `Top -> Memory.top
    | `Value loc ->
      Memory.overwrite ~oracle ~weak dst loc src

  let segmentation_hint ~oracle m loc bounds =
    match loc with
    | `Top -> Memory.top
    | `Value loc ->
      Memory.segmentation_hint ~oracle m loc bounds
end

(* References to variables inside array segmentation.
   For instance if an array A is described with the segmentation
     0..i-1 ; i ; i+1..10
   then, everytime i is changed, the segmentation must be updated. This requires
   referencing every base where at least one segmentation references i. *)
module References =
struct
  include Base.Hptset (* The set of bases referencing the variable *)
end

module TrackedBases =
struct
  include Base.Hptset
end

module DomainLattice =
struct
  (* The domain is essentially a map from bases to individual memory abstractions *)
  module Initial_Values = struct let v = [[]] end
  module Deps = struct let l = [Ast.self] end
  module V =
  struct
    include Datatype.Pair (Memory) (References)
    let pretty_debug = pretty
    let top = Memory.top, References.empty
  end

  module BaseMap =
  struct
    include
      Hptmap.Make
        (Base.Base) (V)
        (Hptmap.Comp_unused) (Initial_Values) (Deps)

    let find_or_top (state : t) (b : Base.t) =
      try find b state with Not_found -> V.top

    let remove_var (state : t) (v : Cil_types.varinfo) =
      remove (Base.of_varinfo v) state

    let remove_vars (state : t) (l : Cil_types.varinfo list) =
      List.fold_left remove_var state l

    let remove_loc (state : t) (loc : Precise_locs.precise_location) =
      let loc = Precise_locs.imprecise_location loc in
      Locations.(Location_Bits.fold_bases remove loc.loc state)
  end

  include Datatype.Pair_with_collections
      (BaseMap)
      (Datatype.Option (TrackedBases))
      (struct let module_name = "DomainLattice" end)

  type state = t
  type value = Value.t
  type value_or_uninitialized = Value_or_Uninitialized.t
  type base = Base.t
  type offset = Location.offset
  type memory = Memory.t
  type location = Precise_locs.precise_location
  type mdlocation = Location.t (* should be = to location *)
  type origin

  let log_category = dkey

  let cache_name s =
    Hptmap_sig.PersistentCache ("Multidim_domain." ^ s)

  (* Bases handling *)

  let covers_base (tracked : TrackedBases.t option) (b : base) : bool =
    match b with
    | Base.Var (vi, _) | Allocated (vi, _, _) ->
      not (Cil.typeHasQualifier "volatile" vi.vtype) &&
      Option.fold ~none:true ~some:(TrackedBases.mem b) tracked
    | Null -> true
    | CLogic_Var _ | String _ -> false

  let join_tracked tracked1 tracked2 =
    match tracked1, tracked2 with
    | None, tracked | tracked, None -> tracked
    | Some s1, Some s2 -> Some (TrackedBases.union s1 s2)


  (* Accesses *)

  let rec read :
    type a .
    (memory -> offset -> a) -> (a -> a -> a) ->
    state -> mdlocation -> a or_bottom =
    fun map reduce (state,_tracked) loc ->
    let f base off acc =
      let v = map (fst (BaseMap.find_or_top state base)) off in
      Bottom.join reduce (`Value v) acc
    in
    Location.fold f loc `Bottom

  and get (state : state) (src : mdlocation) : value_or_uninitialized or_bottom =
    let oracle = mk_oracle state in
    read (Memory.get ~oracle) Value_or_Uninitialized.join state src

  and mk_oracle' (state : state) : Cil_types.exp -> value =
    (* Until Eva gives access to good oracles, we use this poor stupid oracle
       instead *)
    let rec oracle exp =
      match exp.enode with
      | Lval lval ->
        let value = get state (Location.of_lval oracle lval) in
        Value_or_Uninitialized.get_v (Bottom.non_bottom value) (* TODO: handle exception *)
      | Const (CInt64 (i,_,_)) -> Value.inject_int i
      | Const (CReal (f,_,_)) -> Value.inject_float (Fval.singleton (Fval.F.of_float f))
      | UnOp (op, e, typ) -> Value.forward_unop typ op (oracle e)
      | BinOp (op, e1, e2, TFloat (fkind, _)) ->
        Value.forward_binop_float (Fval.kind fkind) (oracle e1) op (oracle e2)
      | BinOp (op, e1, e2, typ) ->
        Value.forward_binop_int ~typ (oracle e1) op (oracle e2)
      | CastE (typ, e) ->
        let scalar_type t = Option.get (Eval_typ.classify_as_scalar t) in
        let src_type =  scalar_type (Cil.typeOf e)
        and dst_type = scalar_type typ in
        Value.forward_cast ~src_type ~dst_type (oracle e)
      | _ ->
        Self.fatal
          "This type of array index expression is not supported: %a"
          Cil_printer.pp_exp exp
    in
    fun exp -> oracle (Cil.constFold true exp)

  and convert_oracle (oracle : Cil_types.exp -> value)
    : Abstract_memory.oracle =
    fun exp ->
    try
      Value.project_ival (oracle exp)
    with Value.Not_based_on_null ->
      Ival.top (* TODO: should it just not happen ? *)

  and convert_oracle_or_default state = function (* TODO: use everywhere *)
    | Some oracle -> convert_oracle oracle
    | None -> mk_oracle state

  and mk_oracle (state : state) : Abstract_memory.oracle =
    convert_oracle (mk_oracle' state)

  let extract (state : state) (src : mdlocation) : Memory.t or_bottom =
    let oracle = mk_oracle state in
    read (Memory.extract ~oracle) (Memory.smash ~oracle) state src

  let add_references (base_map,tracked) vi refs' =
    let base = Base.of_varinfo vi in
    let memory, refs = BaseMap.find_or_top base_map base in
    let refs'' = References.union refs (References.of_list refs') in
    BaseMap.add base (memory, refs'') base_map, tracked

  let add_references_l state l refs =
    List.fold_left (fun state vi -> add_references state vi refs) state l

  let write' (update : memory -> offset -> memory or_bottom)
      (state : state) (loc : mdlocation) : state or_bottom =
    let f base off state' =
      state' >>- fun (base_map,tracked) ->
      if covers_base tracked base then
        let memory, refs = BaseMap.find_or_top base_map base in
        update memory off >>-: fun memory' ->
        BaseMap.add base (memory', refs) base_map, tracked
      else
        state'
    in
    Location.fold f loc (`Value state) >>-: fun state ->
    add_references_l state (Location.references loc) (Location.bases loc)

  let write update state loc =
    (* Result can never be bottom if update never returns bottom *)
    Bottom.non_bottom (write' (fun m o -> `Value (update m o)) state loc)

  let set (state : state) (dst : mdlocation) (v : value_or_uninitialized) : state =
    let weak = not (Location.is_singleton dst)
    and oracle = mk_oracle state in
    write (Memory.set ~oracle ~weak v) state dst

  let overwrite (state : state) (dst : mdlocation) (src : mdlocation) : state =
    let weak = not (Location.is_singleton dst)
    and oracle = mk_oracle state in
    match extract state src with
    | `Bottom -> state (* no source *)
    | `Value value ->
      write (fun m off -> Memory.overwrite ~oracle ~weak m off value) state dst

  let erase (state : state) (dst : mdlocation) (b : Abstract_memory.bit): state =
    let weak = not (Location.is_singleton dst)
    and oracle = mk_oracle state in
    write (fun m off -> Memory.erase ~oracle ~weak m off b) state dst

  let reinforce
      ?oracle
      (f : value_or_uninitialized -> value_or_uninitialized or_bottom)
      (state : state) (dst : mdlocation) : state or_bottom =
    let oracle = convert_oracle_or_default state oracle in
    write' (fun m off -> Memory.reinforce ~oracle f m off) state dst

  (* Lattice *)

  let top = BaseMap.empty, None

  let is_included =
    let open BaseMap in
    let cache = cache_name "is_included" in
    let decide_fst _b _v1 = true (* v2 is top *) in
    let decide_snd _b _v2 = false (* v1 is top, v2 is not *) in
    let decide_both _ (m1,_r1) (m2,_r2) = Memory.is_included m1 m2 in
    let decide_fast s t = if s == t then PTrue else PUnknown in
    let is_included = binary_predicate cache UniversalPredicate
        ~decide_fast ~decide_fst ~decide_snd ~decide_both
    in
    fun (m1,_) (m2,_) -> is_included m1 m2

  let narrow =
    let open BaseMap in
    let cache = cache_name "narrow" in
    let decide _ v1 v2 = Memory.narrow v1 v2 in
    let narrow = join ~cache ~symmetric:false ~idempotent:true ~decide in
    fun (m1,t1) (m2,t2) -> `Value (narrow m1 m2, join_tracked t1 t2)

  let join (m1,t1 as s1) (m2,t2 as s2) =
    let open BaseMap in
    let oracle = function
      | Abstract_memory.Left -> mk_oracle s1
      | Right -> mk_oracle s2
    in
    let cache = Hptmap_sig.NoCache
    and decide _ (m1,r1) (m2,r2) =
      let m = Memory.join ~oracle m1 m2
      and r = References.union r1 r2 in
      if Memory.(is_top m) then None else Some (m,r)
    in
    inter ~cache ~symmetric:false ~idempotent:true ~decide m1 m2,
    join_tracked t1 t2


  let widen kf stmt (m1,t1 as s1) (m2,t2 as s2) =
    let open BaseMap in
    let oracle = function
      | Abstract_memory.Left -> mk_oracle s1
      | Right -> mk_oracle s2
    and _,get_hints = Widen.getWidenHints kf stmt in
    let cache = Hptmap_sig.NoCache
    and decide base (m1,r1) (m2,r2) =
      let m = Memory.widen ~oracle (get_hints base) m1 m2
      and r = References.union r1 r2 in
      if Memory.(is_top m) then None else Some (m,r)
    in
    inter ~cache ~symmetric:false ~idempotent:true ~decide m1 m2,
    join_tracked t1 t2
end

module Domain =
struct
  include DomainLattice
  include Domain_builder.Complete (DomainLattice)

  (* Eva Queries *)

  (* Nothing interesting to be done on expressions *)
  let extract_expr ~oracle:_ _context _state _expr =
    `Value (Value.top, None), Alarmset.all

  let extract_lval ~oracle _context state lv _typ _loc =
    let oracle = fun exp ->
      match oracle exp with
      | `Bottom, _ -> raise Abstract_interp.Error_Bottom
      | `Value v, _ -> v
    in
    try
      let loc = Location.of_lval oracle lv in
      let v = get state loc in
      (v >>-: fun v -> (Value_or_Uninitialized.get_v v, None)),
      match v with
      | `Bottom -> Alarmset.all
      | `Value v ->
        if Value_or_Uninitialized.is_initialized v
        then Alarmset.(set (Alarms.Uninitialized lv) True all)
        else Alarmset.all
    with
    | Abstract_interp.Error_Top -> `Value (Value.top, None), Alarmset.all
    | Abstract_interp.Error_Bottom -> `Bottom, Alarmset.all


  (* Eva Transfer *)

  let make_oracle valuation : Cil_types.exp -> value = fun exp ->
    match valuation.Abstract_domain.find exp with
    | `Top -> raise Abstract_interp.Error_Top
    | `Value {value={v=`Bottom}} -> raise Abstract_interp.Error_Bottom
    | `Value {value={v=`Value value}} -> value

  let assume_exp valuation expr record state' =
    state' >>- fun state ->
    let oracle = make_oracle valuation in
    try
      match expr.enode with
      | Lval lv ->
        let value = Value_or_Uninitialized.from_flagged record.value in
        if not (Value.is_topint (Value_or_Uninitialized.get_v value)) then
          let loc = Location.of_lval oracle lv in
          let update value' =
            let v = Value_or_Uninitialized.narrow value value' in
            if Value_or_Uninitialized.is_bottom v then `Bottom else `Value v
          in
          if Location.is_singleton loc
          then reinforce ~oracle update state loc
          else `Value state
        else `Value state
      | _ -> `Value state
    with
    (* Failed to evaluate the location *)
      Abstract_interp.Error_Top | Abstract_interp.Error_Bottom -> `Value state

  let assume_valuation valuation state =
    valuation.Abstract_domain.fold (assume_exp valuation) (`Value state)

  let update valuation state =
    assume_valuation valuation state

  let update_array_segmentation_bounds vi expr (base_map,tracked as state) =
    (* TODO: more general transfer function *)
    let incr = Option.bind expr (fun expr ->
        match expr.Cil_types.enode with
        | BinOp ((PlusA|PlusPI), { enode=Lval (Var vi', NoOffset) }, exp, _typ)
          when Cil_datatype.Varinfo.equal vi vi' ->
          Cil.constFoldToInt exp
        | BinOp ((PlusA|PlusPI), exp, { enode=Lval (Var vi', NoOffset)}, _typ)
          when Cil_datatype.Varinfo.equal vi vi' ->
          Cil.constFoldToInt exp
        | BinOp ((MinusA|MinusPI), { enode=Lval (Var vi', NoOffset) }, exp, _typ)
          when Cil_datatype.Varinfo.equal vi vi' ->
          Option.map Integer.neg (Cil.constFoldToInt exp)
        | _ -> None)
    in
    (* Very important : oracle must be the oracle before a non-invertible
       assignement of the bound to allow removing of eventual empty slice
       before the bound leaves the segmentation. *)
    let oracle = mk_oracle state in
    let references = snd (BaseMap.find_or_top base_map (Base.of_varinfo vi)) in
    let update_ref base base_map =
      let update (memory, refs) =
        Memory.incr_bound ~oracle vi incr memory, refs
      in
      BaseMap.replace (Option.map update) base base_map
    in
    let base_map = References.fold update_ref references base_map in
    (* If increment is None, every reference to vi should have been removed by
       Memory.incr_bound *)
    let base_map =
      if Option.is_none incr then
        BaseMap.replace
          (Option.map (fun (memory, _refs) -> memory, References.empty))
          (Base.of_varinfo vi)
          base_map
      else
        base_map
    in
    base_map, tracked

  let update_array_segmentation lval expr state =
    match lval with
    | Mem _, _ -> state (* Do nothing *)
    | Var vi, offset ->
      let expr = match offset with
        | NoOffset -> expr
        | _ -> None
      in
      update_array_segmentation_bounds vi expr state

  let assign_lval lval assigned_value oracle state =
    try
      let dst = Location.of_lval oracle lval in
      match assigned_value with
      | Assign value ->
        set state dst (Value_or_Uninitialized.of_value value)
      | Copy (right, _value) ->
        try
          let src = Location.of_lval oracle right.lval in
          overwrite state dst src
        with Abstract_interp.Error_Top | Abstract_interp.Error_Bottom ->
          erase state dst Abstract_memory.Bit.top
    with Abstract_interp.Error_Top | Abstract_interp.Error_Bottom ->
      (* Failed to evaluate the left location *)
      top

  let assign _kinstr left expr assigned_value valuation state =
    let state = update_array_segmentation left.lval (Some expr) state in
    assume_valuation valuation state >>-: fun state ->
    let oracle = make_oracle valuation in
    assign_lval left.lval assigned_value oracle state

  let assume _stmt _expr _pos valuation state =
    assume_valuation valuation state

  let start_call _stmt call recursion valuation state =
    if recursion <> None
    then
      Self.abort ~current:true
        "The multidim domain does not support recursive calls yet";
    let oracle = make_oracle valuation in
    let bind state arg =
      state >>-: assign_lval (Cil.var arg.formal) arg.avalue oracle
    in
    List.fold_left bind (`Value state) call.arguments

  let finalize_call _stmt call _recursion ~pre:_ ~post =
    match find_builtin call.kf, call.return with
    | None, _ | _, None   -> `Value post
    | Some f, Some return ->
      let args = List.map (fun arg -> arg.avalue) call.arguments in
      f args >>-: fun assigned_result ->
      assign_lval (Cil.var return) assigned_result no_oracle post

  let show_expr valuation state fmt expr =
    match expr.enode with
    | Lval lval | StartOf lval ->
      begin try
          let oracle = make_oracle valuation in
          let loc = Location.of_lval oracle lval in
          match extract state loc with
          | `Bottom -> Format.fprintf fmt "⊥"
          | `Value value -> Memory.pretty fmt value
        with Abstract_interp.Error_Top | Abstract_interp.Error_Bottom ->
          (* can't evaluate location : print nothing *)
          ()
      end
    | _ -> ()

  let enter_scope _kind vars state =
    let enter_one state v =
      let dst = Location.of_var v in
      erase state dst Abstract_memory.Bit.uninitialized
    in
    List.fold_left enter_one state vars

  let leave_scope _kf vars state =
    let state =
      List.fold_left
        (fun state vi -> update_array_segmentation_bounds vi None state)
        state vars
    in
    let (base_map,tracked) = state in
    BaseMap.remove_vars base_map vars, tracked

  let logic_assign assign location (base_map,tracked as state) =
    match assign with
    | None -> BaseMap.remove_loc base_map location, tracked
    | Some ((Frees _ | Allocates _), _) -> state
    | Some (Assigns (_dest, sources), _pre_state) ->
      match sources with
      | [] ->
        let dst = Location.of_precise_loc location in
        erase state dst Abstract_memory.Bit.numerical
      | _ ->
        BaseMap.remove_loc base_map location, tracked

  let reduce_by_papp env li _labels args positive state =
    try
      match li.l_var_info.lv_name, args with
      | "\\are_finite", [arg] ->
        let loc,typ = Location.of_term env arg in
        begin match Cil.unrollType (Logic_utils.logicCType typ) with
          | TFloat (fkind,_) ->
            let update = Value.backward_is_finite positive fkind in
            reinforce (Value_or_Uninitialized.map' update) state loc
          | _ | exception (Failure _) -> `Value state
        end
      | _ -> `Value state
    with
    | Abstract_interp.Error_Bottom -> `Bottom
    | Abstract_interp.Error_Top -> `Value state

  let reduce_by_predicate env state predicate truth =
    let rec reduce predicate truth state =
      match truth, predicate.pred_content with
      | true, Pand (p1,p2) | false, Por (p1,p2) ->
        state |> reduce p1 truth >>- reduce p2 truth
      | _,Papp (li, labels, args) ->
        reduce_by_papp env li labels args truth state
      | _ -> `Value state
    in
    reduce predicate truth state

  let interpret_acsl_extension extension _env state =
    match extension.ext_name with
    | "array_partition" ->
      let annotation = Eva_annotations.read_array_segmentation extension in
      let vi,offset,bounds = annotation in
      (* Update the segmentation *)
      let lval = Cil_types.Var vi, offset in
      let loc = Location.of_lval (mk_oracle' state) lval in
      let oracle = mk_oracle state in
      let update m offset =
        Memory.segmentation_hint ~oracle m offset bounds
      in
      let state = write update state loc in
      (* Update the references *)
      let add acc e =
        let r = Cil.extract_varinfos_from_exp e in
        (Cil_datatype.Varinfo.Set.to_seq r |> List.of_seq) @ acc
      in
      let references = List.fold_left add [] bounds in
      add_references_l state references (Location.bases loc)
    | "eva_domain_scope" ->
      let domain,vars = Eva_annotations.read_domain_scope extension in
      if domain = "multidim" then
        let (base_map,tracked) = state in
        let set = Option.value ~default:TrackedBases.empty tracked
        and bases = List.map Base.of_varinfo vars in
        base_map, Some (List.fold_right TrackedBases.add bases set)
      else
        state
    | _ ->
      state

  let empty () = top

  let initialize_variable lval _loc ~initialized:_ init_value state =
    let dst = Location.of_lval no_oracle lval in
    let d = match init_value with
      | Abstract_domain.Top  -> Abstract_memory.Bit.numerical
      | Abstract_domain.Zero -> Abstract_memory.Bit.zero
    in
    erase state dst d

  let initialize_variable_using_type _kind vi state =
    let lval = Cil.var vi in
    let dst = Location.of_lval no_oracle lval in
    erase state dst Abstract_memory.Bit.top

  let relate _kf _bases _state = Base.SetLattice.empty

  let filter _kf _kind bases (base_map,tracked) =
    BaseMap.filter (fun elt -> Base.Hptset.mem elt bases) base_map,
    tracked (* TODO: intersection with bases *)

  let reuse _kf bases =
    let open BaseMap in
    let cache = Hptmap_sig.NoCache in
    let decide_both _key _v1 v2 = Some v2 in
    let decide_left key v1 =
      if Base.Hptset.mem key bases then None else Some v1
    in
    let reuse = merge ~cache ~symmetric:false ~idempotent:true
        ~decide_both ~decide_left:(Traversing decide_left) ~decide_right:Neutral
    in
    fun ~current_input:(m1,t1)  ~previous_output:(m2,t2) ->
      reuse m1 m2, join_tracked t1 t2
end

include Domain

let multidim_top = top
let better_join _oracle_left _oracle_right a b = join a b

let multidim_hook (module Abstract: Abstractions.S) : (module Abstractions.S) =
  match Abstract.Dom.get key with
  | None -> (module Abstract)
  | Some get_multidim ->
    let module Eval =
      Evaluation.Make (Abstract.Val) (Abstract.Loc) (Abstract.Dom)
    in
    let module Dom = struct
      include Abstract.Dom

      let join a b =
        let r = join (set key multidim_top a) (set key multidim_top b) in
        let left_oracle = Eval.evaluate a in
        let right_oracle = Eval.evaluate b in
        let taint =
          better_join left_oracle right_oracle (get_multidim a) (get_multidim b)
        in
        set key taint r
    end
    in
    (module struct
      module Val = Abstract.Val
      module Loc = Abstract.Loc
      module Dom = Dom
    end)

(* Registers the domain. *)
let flag =
  let name = "multidim"
  and descr = "Improve the precision over arrays of structures \
               or multidimensional arrays."
  and experimental = true
  and abstraction =
    Abstractions.{ values = Single (module Main_values.CVal);
                   domain = Domain (module Domain); }
  in
  Abstractions.register ~name ~descr ~experimental abstraction

let () = Abstractions.register_hook multidim_hook
