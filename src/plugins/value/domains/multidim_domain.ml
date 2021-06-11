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

open Cil_types
open Eval

let dkey = Value_parameters.register_category "d-multidim"

let map_to_singleton map =
  let aux base offset = function
    | None -> Some (base, offset)
    | Some _ -> raise Exit
  in
  try Base.Base.Map.fold aux map None with Exit -> None

module Value =
struct
  include Cvalue.V

  let _to_integer cvalue =
    try  Some (Ival.project_int (project_ival cvalue))
    with Not_based_on_null | Ival.Not_Singleton_Int -> None

  let of_integer = inject_int

  let of_bit = function
    | Abstract_memory.Zero -> inject_int Integer.zero
    | Any (Set s) -> inject_top_origin Origin.top s
    | Any (Top) -> top_with_origin Origin.top

  let to_bit v =
    if is_zero v
    then Abstract_memory.Zero
    else Abstract_memory.Any (get_bases v)

  let backward_is_finite positive fkind v =
    let prec = Fval.kind fkind in
    try
      let v = reinterpret_as_float fkind v in
      Fval.backward_is_finite ~positive prec (project_float v) >>-: inject_float
    with Not_based_on_null ->
      `Value v
end

let no_oracle exp =
  match Cil.isInteger exp with
  | None -> raise Abstract_interp.Error_Top
  | Some i -> Value.of_integer i


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

  let is_singleton map =
    match map_to_singleton map with
    | None -> false
    | Some (b,o) ->
      not (Base.is_weak b) && Offset.is_singleton o

  (* Raises Abstract_domain.{Error_top,Error_bottom} *)
  let of_lval oracle ((host,offset) : Cil_types.lval) : t =
    let oracle' exp =
      match Ival.project_int_val (Value.project_ival (oracle exp)) with
      | Some int_val -> int_val
      | None | exception Value.Not_based_on_null -> Int_val.top
    in
    let base_typ = Cil.typeOfLhost host in
    let offset = Offset.of_cil_offset oracle' base_typ offset in
    match host with
    | Var vi ->
      Map.singleton (Base.of_varinfo vi) offset
    | Mem exp ->
      let add base ival map =
        let offset' : Offset.t =
          match Base.typeof base with
          | None -> `Top
          | Some base_typ ->
            let typ = Cil.typeOf_pointed (Cil.typeOf exp) in
            Offset.(append (of_ival ~base_typ ~typ ival) offset)
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
  module Config = struct let deps = [Ast.self] end
  module Memory = Abstract_memory.Make (Config) (Value)

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
  let pretty_debug = Memory.pretty
  let top = Memory.top
  let is_top = Memory.is_top
  let is_included = Memory.is_included
  let narrow = fun m1 _m2 -> m1
  let join = Memory.join
  let widen h = Memory.widen (fun ~size v1 v2 -> Value.widen (size,h) v1 v2)

  let get m loc =
    match loc with
    | `Top -> Value.top
    | `Value loc -> Memory.get m loc

  let extract m loc =
    match loc with
    | `Top -> Memory.top
    | `Value loc -> Memory.extract m loc

  let erase ~weak m loc bit_value =
    match loc with
    | `Top -> Memory.top
    | `Value loc -> Memory.erase ~weak m loc bit_value

  let set ~weak new_v m loc =
    match loc with
    | `Top -> Memory.top
    | `Value loc ->
      Memory.set ~weak m loc new_v

  let reinforce f m loc =
    match loc with
    | `Top -> m
    | `Value loc ->
      let f' x =
        match f x with
        | `Value v -> v
        | `Bottom -> raise Abstract_interp.Error_Bottom
      in
      Memory.reinforce f' m loc

  let overwrite ~weak dst loc src =
    match loc with
    | `Top -> Memory.top
    | `Value loc ->
      Memory.overwrite ~weak dst loc src
end


module DomainPrototype =
struct
  (* The domain is essentially a map from bases to individual memory abstractions *)
  module Initial_Values = struct let v = [[]] end
  module Deps = struct let l = [Ast.self] end

  include Hptmap.Make
      (Base.Base) (Memory)
      (Hptmap.Comp_unused) (Initial_Values) (Deps)

  type state = t
  type value = Value.t
  type base = Base.t
  type offset = Location.offset
  type memory = Memory.t
  type location = Precise_locs.precise_location
  type mdlocation = Location.t (* should be = to location *)
  type origin


  let name = "Multidim domain"
  let log_category = dkey

  let cache_name s =
    Hptmap_sig.PersistentCache ("Multidim_domain." ^ s)


  (* Lattice *)

  let top = empty

  let is_included =
    let cache = cache_name "is_included" in
    let decide_fst _b _v1 = true (* v2 is top *) in
    let decide_snd _b _v2 = false (* v1 is top, v2 is not *) in
    let decide_both _ v1 v2 = Memory.is_included v1 v2 in
    let decide_fast s t = if s == t then PTrue else PUnknown in
    binary_predicate cache UniversalPredicate
      ~decide_fast ~decide_fst ~decide_snd ~decide_both

  let narrow =
    let cache = cache_name "narrow" in
    let decide _ v1 v2 =
      Memory.narrow v1 v2
    in
    let narrow = join ~cache ~symmetric:false ~idempotent:true ~decide in
    fun a b -> `Value (narrow a b)

  let join =
    let cache = cache_name "join" in
    let decide _ v1 v2 =
      let r = Memory.join v1 v2 in
      if Memory.(is_top r) then None else Some r
    in
    inter ~cache ~symmetric:true ~idempotent:true ~decide

  let widen kf stmt =
    let _,get_hints = Widen.getWidenHints kf stmt in
    let decide base b1 b2 =
      let r = Memory.widen (get_hints base) b1 b2 in
      if Memory.(is_top r) then None else Some r
    in
    inter ~cache:Hptmap_sig.NoCache ~symmetric:false ~idempotent:true ~decide


  (* Bases handling *)

  let covers_base (b : base) =
    match b with
    | Base.Var (vi, _) | Allocated (vi, _, _) ->
      not (Cil.typeHasQualifier "volatile" vi.vtype)
    | Null -> true
    | CLogic_Var _ | String _ -> false

  let find_or_top (state : state) (b : base) =
    try find b state with Not_found -> Memory.top

  let remove_var (state : state) (v : Cil_types.varinfo) =
    remove (Base.of_varinfo v) state

  let remove_vars (state : state) (l : Cil_types.varinfo list) =
    List.fold_left remove_var state l

  let remove (state : state) (loc : location) =
    let loc = Precise_locs.imprecise_location loc in
    Locations.(Location_Bits.fold_bases remove loc.loc state)

  (* Accesses *)

  let read (map : memory -> offset -> 'a) (reduce : 'a -> 'a -> 'a)
      (state : state) (loc : mdlocation) : 'a or_bottom =
    let f base off acc =
      let v = map (find_or_top state base) off in
      Bottom.join reduce (`Value v) acc
    in
    Location.fold f loc `Bottom

  let write (update : memory -> offset -> memory)
      (state : state) (loc : mdlocation) : state =
    let f base off state =
      if covers_base base then
        add base (update (find_or_top state base) off) state
      else
        state
    in
    Location.fold f loc state

  let get (state : state) (src : mdlocation) : value or_bottom =
    read Memory.get Value.join state src

  let extract (state : state) (src : mdlocation) : Memory.t or_bottom =
    read Memory.extract Memory.join state src

  let set (state : state) (dst : mdlocation) (v : value) : state =
    let weak = not (Location.is_singleton dst) in
    write (Memory.set ~weak v) state dst

  let overwrite (state : state) (dst : mdlocation) (src : mdlocation) : state =
    let weak = not (Location.is_singleton dst) in
    match extract state src with
    | `Bottom -> state (* no source *)
    | `Value value ->
      write (fun m off -> Memory.overwrite ~weak m off value) state dst

  let erase (state : state) (dst : mdlocation) (b : Abstract_memory.bit): state =
    let weak = not (Location.is_singleton dst) in
    write (fun m off -> Memory.erase ~weak m off b) state dst

  let reinforce (f : value -> value or_bottom)
      (state : state) (dst : mdlocation) : state =
    write (fun m off -> Memory.reinforce f m off) state dst

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
    let v =
      try
        let loc = Location.of_lval oracle lv in
        get state loc >>-: fun v -> v, None
      with
      | Abstract_interp.Error_Top -> `Value (Value.top, None)
      | Abstract_interp.Error_Bottom -> `Bottom
    in
    v, Alarmset.all

  (* do nothing for now *)
  let backward_location _state _lval _typ loc value =
    `Value (loc, value)

  (* do nothing for now *)
  let reduce_further _state _expr _value = []


  (* Eva Transfer *)

  let make_oracle valuation : Cil_types.exp -> value = fun exp ->
    match valuation.Abstract_domain.find exp with
    | `Top -> raise Abstract_interp.Error_Top
    | `Value {value={v=`Bottom}} -> raise Abstract_interp.Error_Bottom
    | `Value {value={v=`Value value}} -> value

  let assume_exp valuation expr record state =
    let oracle = make_oracle valuation in
    try
      match expr.enode, record.value.v with
      | Lval lv, `Value value ->
        let loc = Location.of_lval oracle lv in
        let update value' =
          `Value (Value.narrow value value')
        in
        if Location.is_singleton loc
        then reinforce update state loc
        else state
      | _, `Bottom -> state (* Indeterminate value, ignore *)
      | _ -> state
    with
    (* Failed to evaluate the location *)
      Abstract_interp.Error_Top | Abstract_interp.Error_Bottom -> state

  let assume_valuation valuation state =
    valuation.Abstract_domain.fold (assume_exp valuation) state

  let update valuation state =
    `Value (assume_valuation valuation state)

  let assign_lval lval assigned_value oracle state =
    try
      let dst = Location.of_lval oracle lval in
      match assigned_value with
      | Assign value ->
        `Value (set state dst value)
      | Copy (right, _value) ->
        try
          let src = Location.of_lval oracle right.lval in
          `Value (overwrite state dst src)
        with Abstract_interp.Error_Top | Abstract_interp.Error_Bottom ->
          `Value (erase state dst Abstract_memory.Bit.top)
    with Abstract_interp.Error_Top | Abstract_interp.Error_Bottom ->
      (* Failed to evaluate the left location *)
      `Value top

  let assign _kinstr left _expr assigned_value valuation state =
    let state = assume_valuation valuation state in
    let oracle = make_oracle valuation in
    assign_lval left.lval assigned_value oracle state

  let assume _stmt _expr _pos valuation state =
    `Value (assume_valuation valuation state)

  let start_call _stmt call recursion valuation state =
    if recursion <> None
    then
      Value_parameters.abort ~current:true
        "The multidim domain does not support recursive calls yet";
    let oracle = make_oracle valuation in
    let bind state arg =
      state >>- assign_lval (Cil.var arg.formal) arg.avalue oracle
    in
    List.fold_left bind (`Value state) call.arguments

  let finalize_call _stmt call _recursion ~pre:_ ~post =
    match find_builtin call.kf, call.return with
    | None, _ | _, None   -> `Value post
    | Some f, Some return ->
      let args = List.map (fun arg -> arg.avalue) call.arguments in
      f args >>- fun assigned_result ->
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

  let enter_scope _kind _vars state = state
  let leave_scope _kf vars state = remove_vars state vars

  let enter_loop _ state = state
  let incr_loop_counter _ state = state
  let leave_loop _ state = state

  let logic_assign assign location state =
    match assign with
    | None -> remove state location
    | Some ((Frees _ | Allocates _), _) -> state
    | Some (Assigns (_dest, sources), _pre_state) ->
      match sources with
      | [] ->
        let dst = Location.of_precise_loc location in
        erase state dst Abstract_memory.Bit.numerical
      | _ ->
        remove state location

  let evaluate_predicate _ _ _ = Alarmset.Unknown

  let reduce_by_papp env li _labels args positive state =
    try
      match li.l_var_info.lv_name, args with
      | "\\are_finite", [arg] ->
        let loc,typ = Location.of_term env arg in
        begin match Cil.unrollType (Logic_utils.logicCType typ) with
          | TFloat (fkind,_) ->
            let update = Value.backward_is_finite positive fkind in
            `Value (reinforce update state loc)
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

  let filter _kf _kind bases state =
    filter (fun elt -> Base.Hptset.mem elt bases) state

  let reuse _kf bases ~current_input ~previous_output =
    let cache = Hptmap_sig.NoCache in
    let decide_both _key _v1 v2 = Some v2 in
    let decide_left key v1 =
      if Base.Hptset.mem key bases then None else Some v1
    in
    merge ~cache ~symmetric:false ~idempotent:true
      ~decide_both ~decide_left:(Traversing decide_left) ~decide_right:Neutral
      current_input previous_output

  let storage () = true
end


include Domain_builder.Complete (DomainPrototype)
