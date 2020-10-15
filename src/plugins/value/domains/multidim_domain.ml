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

[@@@warning "-60"] (* unused module *)
[@@@warning "-32"] (* unused value *)

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

  let zero = inject_int Integer.zero

  let misaligned _v = top

  let backward_is_finite positive fkind v =
    let prec = Fval.kind fkind in
    try
      let v = reinterpret_as_float fkind v in
      Fval.backward_is_finite ~positive prec (project_float v) >>-: inject_float
    with Not_based_on_null ->
      `Value v

  let top = top (* Locations.Location_Bytes.top_with_origin Origin.top *)
  let top_numerical = top_int
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


module MultidimOffset =
struct
  include Multidim

  let field fi x =
    let field_offset, field_size = Cil.fieldBitsOffset fi in
    add_int x field_offset, Integer.of_int field_size

  let index elem_typ index x =
    let elem_size = Integer.of_int (Cil.bitsSizeOf elem_typ) in
    add x (mul_integer index elem_size), elem_size

  let rec of_exp oracle = function
    | { Cil_types.enode=BinOp (PlusA,e1,e2,_typ) } ->
      add (of_exp oracle e1) (of_exp oracle e2)
    | { enode=BinOp (Mult,e1,e2,_typ) } ->
      mul (of_exp oracle e1) (of_exp oracle e2)
    | { enode=BinOp (Shiftlt,e1,e2,_typ) } as expr ->
      begin match oracle e2 with
        | (i,[]) -> mul_integer (of_exp oracle e1) (Integer.two_power i)
        | _ -> oracle expr (* default to oracle *)
      end
    | expr -> oracle expr (* default to oracle *)

  let assert_valid_size idx _array_size =
    idx

  let of_offset oracle base_typ offset =
    let rec aux base_typ base_size x = function
      | Cil_types.NoOffset -> x, base_size
      | Field (fi, sub) ->
        let x', size = field fi x in
        aux fi.ftype size x' sub
      | Index (exp, sub) ->
        match base_typ with
        | TArray (elem_typ, array_size, _, _) ->
          let idx = of_exp oracle exp in
          let idx = assert_valid_size idx array_size in
          let x', elem_size = index elem_typ idx x in
          aux elem_typ elem_size x' sub
        | _ -> assert false (* Index is only valid on arrays *)
    in
    let base_size = Integer.of_int (Cil.bitsSizeOf base_typ) in
    aux base_typ base_size zero offset
end

(* Multidim adresses building from valuation *)

module MultidimLocation =
struct
  module Map = Base.Base.Map

  type size = Integer.t
  type offset = MultidimOffset.t
  type t = offset Map.t * size

  let size ((_map,size) : t) : size =
    size

  let fold f ((map,size):t) x =
    Map.fold (fun base offset -> f base (offset,size)) map x

  (* Raises Abstract_domain.{Error_top,Error_bottom} *)
  let of_lval oracle ((host,offset) : Cil_types.lval) =
    let oracle' expr =
      try MultidimOffset.of_ival (Value.project_ival (oracle expr))
      with Value.Not_based_on_null -> raise Abstract_interp.Error_Top
    in
    let base_typ = Cil.typeOfLhost host in
    let offset, size = MultidimOffset.of_offset oracle' base_typ offset in
    let map = match host with
      | Var vi ->
        Map.singleton (Base.of_varinfo vi) offset
      | Mem exp ->
        let add b o map =
          Map.add b MultidimOffset.(add (of_ival o) offset) map
        in
        Locations.Location_Bytes.fold_topset_ok add (oracle exp) Map.empty
    in
    map, size

  let is_singleton (map,_) =
    match map_to_singleton map with
    | None -> false
    | Some (b,o) -> not (Base.is_weak b) && MultidimOffset.is_singleton o
end


module Offset =
struct
  open Memory_map
  type t = [ `Value of typed_offset | `Top ]

  let append o1 o2 =
    let rec aux o1 o2 =
      match o1 with
      | NoOffset _t -> o2
      | Field (fi, s) -> Field (fi, aux s o2)
      | Index (i, t, s) -> Index (i, t, aux s o2)
    in
    match o1, o2 with
    | `Top, _ | _, `Top -> `Top
    | `Value o1, `Value o2 -> `Value (aux o1 o2)

  let join o1 o2 =
    let rec aux o1 o2 =
      match o1, o2 with
      | NoOffset t, NoOffset t' when Cil_datatype.Typ.equal t t' ->
        NoOffset t
      | Field (fi, s1), Field (fi', s2) when Cil_datatype.Fieldinfo.equal fi fi' ->
        Field (fi, aux s1 s2)
      | Index (i1, t, s1), Index (i2, t', s2) when Cil_datatype.Typ.equal t t' ->
        Index (Ival.join i1 i2, t, aux s1 s2)
      | _ -> raise Abstract_interp.Error_Top
    in
    match o1, o2 with
    | `Top, _ | _, `Top -> `Top
    | `Value o1, `Value o2 ->
      try `Value (aux o1 o2) with Abstract_interp.Error_Top -> `Top

  let assert_valid_size idx _array_size =
    idx

  let of_offset oracle base_typ offset =
    (* Temorary debug *)
    let rec aux base_typ = function
      | Cil_types.NoOffset -> NoOffset base_typ
      | Field (fi, sub) -> Field (fi, aux fi.ftype sub)
      | Index (exp, sub) ->
        match Cil.unrollType base_typ with
        | TArray (elem_typ, array_size, _, _) ->
          let idx =
            try Value.project_ival (oracle exp)
            with Value.Not_based_on_null -> raise Abstract_interp.Error_Top
          in
          let idx = assert_valid_size idx array_size in
          Index (idx, elem_typ, aux elem_typ sub)
        | _ -> assert false
    in
    try `Value (aux base_typ offset) with Abstract_interp.Error_Top -> `Top

  let of_bits_offset base_typ typ i =
    try
      let offset, _t = Bit_utils.(find_offset base_typ i (MatchType typ)) in
      (* typ and _t may be different *)
      of_offset no_oracle base_typ offset
    with Bit_utils.NoMatchingOffset ->
      `Top

  let of_ival base_typ typ ival =
    match Ival.cardinal ival with
    | Some c when Integer.(lt c (of_int 100)) ->
      let f i acc =
        let offset = of_bits_offset base_typ typ i in
        match acc with
        | `Bottom -> offset
        | #t as prev -> join prev offset
      in
      begin match Ival.fold_int f ival `Bottom with
        | `Bottom -> assert false (* ival should not be bottom *)
        | #t as o -> o
      end

    | _ ->
      Value_parameters.feedback ~dkey ~current:true ~once:true
        "too many values to convert cvalues to multidim offset";
      `Top

  let index_of_term t =
    match t.term_node with
    | Tempty_set -> Ival.bottom
    | TConst (Integer (v, _)) -> Ival.inject_singleton v
    | Trange (l,u) ->
      let eval_bound = function
        | { term_node=TConst (Integer (v, _)) } -> v
        | _ -> raise Abstract_interp.Error_Top
      in
      let l' = Option.map eval_bound l
      and u' = Option.map eval_bound u in
      Ival.inject_range l' u'
    | _ -> raise Abstract_interp.Error_Top

  let of_term_offset base_typ offset =
    let rec aux base_typ = function
      | Cil_types.TNoOffset -> NoOffset base_typ
      | TField (fi, sub) ->
        Field (fi, aux fi.ftype sub)
      | TIndex (index, sub) ->
        begin match Cil.unrollType base_typ with
          | TArray (elem_typ, array_size, _, _) ->
            let idx = index_of_term index in
            let idx = assert_valid_size idx array_size in
            Index (idx, elem_typ, aux elem_typ sub)
          | _ -> assert false
        end
      | _ -> raise Abstract_interp.Error_Top
    in
    try `Value (aux base_typ offset) with Abstract_interp.Error_Top -> `Top

  let is_singleton =
    let rec aux = function
      | NoOffset _ -> true
      | Field (_fi, sub) -> aux sub
      | Index (ival, _elem_typ, sub) ->
        Ival.is_singleton_int ival && aux sub
    in function
      | `Top -> false
      | `Value o -> aux o
end

module Location =
struct
  module Map = Base.Base.Map

  type offset = Offset.t
  type t = offset Map.t

  let empty = Map.empty

  let fold = Map.fold

  let is_singleton map =
    match map_to_singleton map with
    | None -> false
    | Some (b,o) ->
      not (Base.is_weak b) && Offset.is_singleton o

  (* Raises Abstract_domain.{Error_top,Error_bottom} *)
  let of_lval oracle ((host,offset) as lval : Cil_types.lval) : t =
    let base_typ = Cil.typeOfLhost host in
    let offset : Offset.t = Offset.of_offset oracle base_typ offset in
    match host with
    | Var vi ->
      Map.singleton (Base.of_varinfo vi) offset
    | Mem exp ->
      let add base ival map =
        let offset' : Offset.t =
          match Base.typeof base with
          | None -> `Top
          | Some base_typ ->
            let typ = Cil.typeOfLval lval in
            Offset.(append (of_ival base_typ typ ival) offset)
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
      Map.add base (`Value Memory_map.(NoOffset typ)) map
    in
    Locations.Location_Bits.(fold_bases add_base loc'.loc empty)
end


(* The domain for *one* base *)

module Base_Domain =
struct
  module Config = struct let deps = [Ast.self] end
  module Memory = Memory_map.MakeTyped (Config) (Value)

  module Prototype =
  (* Datatype *)
  struct
    include Datatype.Undefined
    include Memory
    let name = "Multidim_domain.Base_Domain"
    let reprs = [ Memory.top ]
  end

  include Datatype.Make (Prototype)

  let pretty = Memory.pretty
  let pretty_debug = Memory.pretty
  let top = Memory.top
  let is_top = Memory.is_top
  let is_included = Memory.is_included
  let narrow = fun m1 _m2 -> m1
  let join = Memory.join (fun ~size:_ v1 v2 -> Value.join v1 v2)
  let widen h = Memory.widen (fun ~size v1 v2 -> Value.widen (size,h) v1 v2)

  let get m loc =
    match loc with
    | `Top -> Value.top
    | `Value loc -> Memory.reduce Value.join m loc

  let extract m loc =
    match loc with
    | `Top -> Memory.top
    | `Value loc -> Memory.extract Value.join m loc

  let initialize m loc init_value =
    match loc with
    | `Top -> Memory.top
    | `Value loc -> Memory.initialize m loc init_value

  let update ~weak new_v m loc =
    match loc with
    | `Top -> Memory.top
    | `Value loc ->
      let f ~weak old_v =
        if weak
        then Value.join old_v new_v
        else new_v
      in
      Memory.update ~weak f m loc

  let reduce f m loc =
    match loc with
    | `Top -> m
    | `Value loc ->
      let f' ~weak x =
        if weak
        then x
        else
          match f x with
          | `Value v -> v
          | `Bottom -> raise Abstract_interp.Error_Bottom
      in
      Memory.update ~weak:false f' m loc

  let erase m loc =
    match loc with
    | `Top -> m
    | `Value loc ->
      Memory.erase m loc

  let overwrite ~weak dst loc src =
    match loc with
    | `Top -> Memory.top
    | `Value loc ->
      let f ~weak old_v new_v =
        if weak
        then Value.join old_v new_v
        else new_v
      in
      Memory.overwrite ~weak f dst loc src
end


module Prototype =
struct
  (* The domain is essentially a map from bases to individual memory abstractions *)
  module Initial_Values = struct let v = [] end
  module Deps = struct let l = [Ast.self] end

  include Hptmap.Make
      (Base.Base) (Base_Domain)
      (Hptmap.Comp_unused) (Initial_Values) (Deps)

  type state = t
  type value = Value.t
  type base = Base.t
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
    let decide_both _ v1 v2 = Base_Domain.is_included v1 v2 in
    let decide_fast s t = if s == t then PTrue else PUnknown in
    binary_predicate cache UniversalPredicate
      ~decide_fast ~decide_fst ~decide_snd ~decide_both

  let narrow =
    let cache = cache_name "narrow" in
    let decide _ v1 v2 =
      Base_Domain.narrow v1 v2
    in
    fun a b ->
      `Value (join ~cache ~symmetric:true ~idempotent:true ~decide a b)

  let join =
    let cache = cache_name "join" in
    let decide _ v1 v2 =
      let r = Base_Domain.join v1 v2 in
      if Base_Domain.(is_top r) then None else Some r
    in
    inter ~cache ~symmetric:true ~idempotent:true ~decide

  let widen =
    let cache = cache_name "widen" in
    fun kf stmt ->
      let _,get_hints = Widen.getWidenHints kf stmt in
      let decide base b1 b2 =
        let r = Base_Domain.widen (get_hints base) b1 b2 in
        if Base_Domain.(is_top r) then None else Some r
      in
      inter ~cache ~symmetric:false ~idempotent:true ~decide


  (* Bases handling *)

  let covers_base (b : base) =
    match b with
    | Base.Var (vi, _) | Allocated (vi, _, _) ->
      not (Cil.typeHasQualifier "volatile" vi.vtype)
    | Null -> true
    | CLogic_Var _ | String _ -> false

  let find_or_top (state : state) (b : base) =
    try find b state with Not_found -> Base_Domain.top

  let remove_var (state : state) (v : Cil_types.varinfo) =
    remove (Base.of_varinfo v) state

  let remove_vars (state : state) (l : Cil_types.varinfo list) =
    List.fold_left remove_var state l

  let remove (state : state) (loc : location) =
    let loc = Precise_locs.imprecise_location loc in
    Locations.(Location_Bits.fold_bases remove loc.loc state)

  (* Accesses *)

  let load (state : state) (src : mdlocation) : value =
    let load_base base loc r =
      let v = Base_Domain.get (find_or_top state base) loc in
      Bottom.join Value.join r (`Value v)
    in
    match Location.fold load_base src `Bottom with
    | `Bottom -> Value.top (* does not happen if the location is not empty *)
    | `Value v -> v

  let extract (state : state) (src : mdlocation) : Base_Domain.t or_bottom =
    let extract_base base loc acc =
      let map = find_or_top state base in
      let value = Base_Domain.extract map loc in
      Bottom.join Base_Domain.join acc (`Value value)
    in
    Location.fold extract_base src `Bottom

  let store (state : state) (dst : mdlocation) (v : value) =
    let weak = not (Location.is_singleton dst) in
    let store_base base loc state =
      if covers_base base then
        add base (Base_Domain.update ~weak v (find_or_top state base) loc) state
      else
        state
    in
    Location.fold store_base dst state

  let overwrite (state : state) (dst : mdlocation) (src : mdlocation) =
    (* assert (Location.size dst = Location.size src); *)
    let weak = not (Location.is_singleton dst) in
    match  extract state src with
    | `Bottom -> state (* no source *)
    | `Value value ->
      let overwrite_base base loc state =
        if covers_base base then
          let map = find_or_top state base in
          add base (Base_Domain.overwrite ~weak map loc value) state
        else
          state (* destination base not covered : do nothing *)
      in
      Location.fold overwrite_base dst state

  let erase (state : state) (dst : mdlocation) =
    let erase_base base loc state =
      if mem base state
      then add base (Base_Domain.erase (find_or_top state base) loc) state
      else state
    in
    Location.fold erase_base dst state

  let update_loc (f : value -> value or_bottom) loc state =
    let update_base base loc state =
      if covers_base base then
        let map = find_or_top state base in
        add base (Base_Domain.reduce f map loc) state
      else
        state (* destination base not covered : do nothing *)
    in
    Location.fold update_base loc state

  let initialize dst init_value state =
    (* dst must be exact, otherwise, we may initialize things that shouldn't *)
    let initialize_base base loc state =
      if covers_base base then
        let map = find_or_top state base in
        add base (Base_Domain.initialize map loc init_value) state
      else
        state
    in
    Location.fold initialize_base dst state

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
        load state loc
      with Abstract_interp.Error_Top | Abstract_interp.Error_Bottom -> Value.top
    in
    `Value (v, None), Alarmset.all

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
        if Location.is_singleton loc
        then store state loc value
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
        `Value (store state dst value)
      | Copy (right, _value) ->
        try
          let src = Location.of_lval oracle right.lval in
          `Value (overwrite state dst src)
        with Abstract_interp.Error_Top | Abstract_interp.Error_Bottom ->
          `Value (erase state dst)
    with Abstract_interp.Error_Top | Abstract_interp.Error_Bottom ->
      (* Failed to evaluate the left location *)
      `Value top

  let assign _kinstr left _expr assigned_value valuation state =
    let state = assume_valuation valuation state in
    let oracle = make_oracle valuation in
    assign_lval left.lval assigned_value oracle state

  let assume _stmt _expr _pos valuation state =
    `Value (assume_valuation valuation state)

  let start_call _stmt call valuation state =
    let oracle = make_oracle valuation in
    let bind state arg =
      state >>- assign_lval (Cil.var arg.formal) arg.avalue oracle
    in
    List.fold_left bind (`Value state) call.arguments

  let finalize_call _stmt call ~pre:_ ~post =
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
          | `Value value -> Base_Domain.pretty fmt value
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
    | Some (Assigns (_it, from), pre_state) ->
      match from with
      | FromAny | From (_ :: _) -> remove state location
      | From [] ->
        let _env = {
          Abstract_domain.states = begin function
            | Cil_types.(BuiltinLabel (Pre | Here)) -> pre_state
            | _ -> assert false
          end;
          Abstract_domain.result = None
        } in
        (* let _dst,_typ = Location.of_term env it.it_content in *)
        let dst = Location.of_precise_loc location in
        initialize dst Memory_map.Numerical state

  let evaluate_predicate _ _ _ = Alarmset.Unknown

  let reduce_by_papp env li _labels args positive state =
    try
      match li.l_var_info.lv_name, args with
      | "\\are_finite", [arg] ->
        let loc,typ = Location.of_term env arg in
        begin match Cil.unrollType (Logic_utils.logicCType typ) with
          | TFloat (fkind,_) ->
            let update = Value.backward_is_finite positive fkind in
            `Value (update_loc update loc state)
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
      | Abstract_domain.Top  -> Memory_map.Numerical
      | Abstract_domain.Zero -> Memory_map.Zero
    in
    initialize dst d state

  let initialize_variable_using_type _kind vi state =
    let lval = Cil.var vi in
    let dst = Location.of_lval no_oracle lval in
    initialize dst Memory_map.Top state

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


include Domain_builder.Complete (Prototype)
