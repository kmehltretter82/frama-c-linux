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

type 'a or_top_bottom = 'a Bottom.Top.or_top_bottom

let (>>>-) t f = match t with
  | `Top -> `Top
  | `Bottom  -> `Bottom
  | `Value t -> f t

exception Not_implemented

module Callstack = Value_types.Callstack

type callstack = Callstack.t
type 'a by_callstack = (callstack * 'a) list

type control_point =
  | Initial
  | Final
  | Start of Cil_types.kernel_function
  | End of Cil_types.kernel_function
  | Before of Cil_types.stmt
  | After of Cil_types.stmt

type request = {
  control_point : control_point;
  selector : Callstack.Set.t option;
  filter: (callstack -> bool) option;
}

type error = Bottom | Top | DisabledDomain
type 'a result = ('a,error) Result.t

(* Building requests *)

let make control_point = {
  control_point;
  selector = None;
  filter = None;
}

let before stmt = make (Before stmt)
let after stmt = make (After stmt)
let at_start_of kf = make (Start kf)
let at_end_of kf = make (End kf)
let at_start = make Initial
let at_end = make Final

let before_kinstr = function
  | Cil_types.Kglobal -> at_start
  | Kstmt stmt -> before stmt

let after_kinstr = function
  | Cil_types.Kglobal -> at_end
  | Kstmt stmt -> after stmt

let in_callstacks l req =
  let set = Callstack.Set.of_list l in
  {
    req with
    selector = Some (Option.fold
                       ~none:set
                       ~some:(Callstack.Set.inter set)
                       req.selector)
  }

let in_callstack cs req =
  in_callstacks [cs] req

let filter_callstack f req = {
  req with
  filter = Some (Option.fold ~none:f ~some:(fun g x -> g x && f x) req.filter)
}


(* Manipulating request results *)

type restricted_to_callstack
type unrestricted_response

module Response =
struct

  type ('a, 'callstack) t =
    | Consolidated : 'a -> ('a, unrestricted_response) t
    | ByCallstack  : 'a by_callstack -> ('a, 'callstack) t
    | Top : ('a, 'callstack) t
    | Bottom : ('a, 'callstack) t

  let coercion : ('a, restricted_to_callstack) t -> ('a, 'c) t = function
    | ByCallstack c -> ByCallstack c
    | Top -> Top
    | Bottom -> Bottom

  (* Constructors *)

  let consolidated =
    function
    | `Bottom -> Bottom
    | `Value state -> Consolidated state

  let singleton cs =
    function
    | `Bottom -> Bottom
    | `Value state -> ByCallstack [cs,state]

  let by_callstack : request ->
    [< `Bottom | `Top | `Value of 'a Value_types.Callstack.Hashtbl.t ] ->
    ('a, restricted_to_callstack) t =
    fun req table ->
    match table with
    | `Top -> Top
    | `Bottom -> Bottom
    | `Value table ->
      (* Selection *)
      let l =
        match req.selector with
        | None ->
          let add cs state acc =
            (cs,state) :: acc
          in
          Callstack.Hashtbl.fold add table []
        | Some selector ->
          let add cs acc =
            match Callstack.Hashtbl.find_opt table cs with
            | Some state -> (cs,state) :: acc
            | None -> acc
          in
          Callstack.Set.fold add selector []
      in
      (* Filter *)
      let l =
        match req.filter with
        | None -> l
        | Some filter -> List.filter (fun (cs,_) -> filter cs) l
      in
      ByCallstack l

  (* Accessors *)

  let callstacks : ('a, restricted_to_callstack) t -> callstack list = function
    | Top | Bottom -> [] (* What else to do when Top is given ? *)
    | ByCallstack l -> List.map fst l

  (* Fold *)

  let fold (f  : callstack -> 'a -> 'b -> 'b) (acc : 'b) :
    ('a, restricted_to_callstack) t -> 'b =
    function
    | Top | Bottom -> acc (* What else to do when Top is given ? *)
    | ByCallstack l -> List.fold_left (fun acc (cs,x) -> f cs x acc) acc l

  (* Map *)

  let map : type c. ('a -> 'b) -> ('a, c) t -> ('b, c) t = fun f -> function
    | Consolidated v -> Consolidated (f v)
    | ByCallstack l -> ByCallstack (List.map (fun (cs,x) -> cs,f x) l)
    | Top -> Top
    | Bottom -> Bottom

  (* Reduction *)

  let map_reduce : type c. ([`Top | `Bottom] -> 'b) -> ('a -> 'b) ->
    ('b -> 'b -> 'b) -> ('a, c) t -> 'b =
    fun default map reduce -> function
      | Consolidated v -> map v
      | ByCallstack ((_,h) :: t) ->
        List.fold_left (fun acc (_,x) -> reduce acc (map x)) (map h) t
      | ByCallstack [] | Bottom -> default `Bottom
      | Top -> default `Top

  let map_join : type c.
    ('a -> 'b) -> ('b -> 'b -> 'b) -> ('a, c) t -> 'b or_top_bottom =
    fun map join ->
    let default = function
      | `Bottom -> `Bottom
      | `Top -> `Top
    and map' x =
      `Value (map x)
    in
    map_reduce default map' (Bottom.Top.join join)

  let map_join' : type c. ('a -> 'b or_top_bottom) -> ('b -> 'b -> 'b) ->
    ('a, c) t -> 'b or_top_bottom =
    fun map join ->
    let default = function
      | `Bottom -> `Bottom
      | `Top -> `Top
    and map' = (map :> 'a -> 'b or_top_bottom) in
    map_reduce default map' (Bottom.Top.join join)
end


(* Extracting states and values *)

module Make () =
struct
  module A = (val Analysis.current_analyzer ())

  type value = A.Val.t
  type location = A.Loc.location
  type valuation = A.Eval.Valuation.t

  type 'callstack lvaluation =
    ((valuation * location * Cil_types.typ) Eval.evaluated, 'callstack) Response.t

  type 'callstack evaluation =
    [ `LValue of ((valuation * value Eval.flagged_value) Eval.evaluated, 'callstack) Response.t
    | `Value of ((valuation * value) Eval.evaluated, 'callstack) Response.t
    ]

  let get_by_callstack : request -> (_, restricted_to_callstack) Response.t =
    fun req ->
    let open Response in
    match req.control_point with
    | Before stmt ->
      A.get_stmt_state_by_callstack ~after:false stmt |> by_callstack req
    | After stmt ->
      A.get_stmt_state_by_callstack ~after:true stmt |> by_callstack req
    | Initial ->
      A.get_kinstr_state ~after:false Kglobal |> singleton []
    | Start kf ->
      A.get_initial_state_by_callstack kf |> by_callstack req
    | Final | End _ ->
      raise Not_implemented

  let get : request -> (_, unrestricted_response) Response.t = fun req ->
    if Option.is_some req.filter || Option.is_some req.selector then
      Response.coercion @@ get_by_callstack req
    else
      let open Response in
      match req.control_point with
      | Before stmt ->
        A.get_stmt_state ~after:false stmt |> consolidated
      | After stmt ->
        A.get_stmt_state ~after:true stmt |> consolidated
      | _ ->
        Response.coercion @@ get_by_callstack req

  let convert : 'a or_top_bottom -> 'a result = function
    | `Top -> Result.error Top
    | `Bottom -> Result.error Bottom
    | `Value v -> Result.ok v

  let callstacks req =
    get_by_callstack req |> Response.callstacks

  let fold_callstacks f acc req =
    let f' cs _res acc =
      f cs (in_callstack cs req) acc
    in
    get_by_callstack req |> Response.fold f' acc

  let by_callstack req =
    let f cs _res acc =
      (cs, in_callstack cs req) :: acc
    in
    get_by_callstack req |> Response.fold f []

  let is_reachable req =
    match get req with
    | Bottom -> false
    | _ -> true

  let equality_class exp req =
    let open Equality in
    match A.Dom.get Equality_domain.key with
    | None ->
      Result.error DisabledDomain
    | Some extract ->
      let hce = Hcexprs.HCE.of_exp exp in
      let extract' state =
        let equalities = Equality_domain.project (extract state) in
        NonTrivial (Set.find hce equalities)
      and reduce e1 e2 =
        match e1, e2 with
        | Trivial, _ | _, Trivial -> Trivial
        | NonTrivial e1, NonTrivial e2 -> Equality.inter e1 e2
      in
      let r = match Response.map_join extract' reduce (get req) with
        | (`Top | `Bottom) as r -> r
        | `Value Trivial -> `Top
        | `Value (NonTrivial e) ->
          let l = Equality.elements e in
          `Value (List.map Hcexprs.HCE.to_exp l)
      in
      convert r

  let as_cvalue_model req =
    match A.Dom.get Cvalue_domain.State.key with
    | None ->
      Result.error DisabledDomain
    | Some extract ->
      let extract' state =
        fst (extract state)
      in
      convert (Response.map_join extract' Cvalue.Model.join (get req))

  (* Evaluation *)

  let eval_lval lval req=
    let eval state = A.Eval.copy_lvalue state lval in
    `LValue (Response.map eval (get req))

  let eval_exp exp req =
    let eval state = A.Eval.evaluate state exp in
    `Value (Response.map eval (get req))

  let eval_address lval req =
    let eval state = A.Eval.lvaluate ~for_writing:false state lval in
    Response.map eval (get req)

  (* Conversion *)

  open Bottom.Type

  let extract_value : type c. c evaluation -> (value or_bottom, c) Response.t =
    function
    | `LValue r ->
      let extract (x, _alarms) = x >>- (fun (_valuation,fv) -> fv.Eval.v) in
      Response.map extract r
    | `Value r ->
      let extract (x, _alarms) = x >>-: (fun (_valuation,v) -> v) in
      Response.map extract r

  let as_cvalue : type c. c evaluation -> Locations.Location_Bytes.t result =
    fun res ->
    match A.Val.get Main_values.CVal.key with
    | None ->
      Result.error DisabledDomain
    | Some get ->
      let join = Main_values.CVal.join in
      let extract value =
        (value >>-: get :> 'a or_top_bottom)
      in
      extract_value res |> Response.map_join' extract join |> convert

  let as_functions : type c. c evaluation ->
    Cil_types.kernel_function list result =
    fun res ->
    let join = (@)
    and extract value =
      value >>>- fun v -> (fst (A.Val.resolve_functions v) :> 'a or_top_bottom)
    in
    extract_value res |> Response.map_join' extract join |> convert

  let extract_loc : type c. c lvaluation -> (location or_bottom, c) Response.t =
    fun r ->
    let extract (x, _alarms) = x >>-: (fun (_valuation,loc,_typ) -> loc) in
    Response.map extract r

  let as_location : type c. c lvaluation -> Locations.location result =
    fun res ->
    match A.Loc.get Main_locations.PLoc.key with
    | None ->
      Result.error DisabledDomain
    | Some get ->
      let join loc1 loc2 =
        let open Locations in
        let size = loc1.size
        and loc = Location_Bits.join loc1.loc loc2.loc in
        assert (Int_Base.equal loc2.size size);
        make_loc loc size
      and extract loc =
        (loc  >>-: get >>-: Precise_locs.imprecise_location :> 'a or_top_bottom)
      in
      extract_loc res |> Response.map_join' extract join |> convert

  let as_zone : type c. c lvaluation -> Locations.Zone.t result =
    fun res ->
    match A.Loc.get Main_locations.PLoc.key with
    | None ->
      Result.error DisabledDomain
    | Some get ->
      let join = Locations.Zone.join
      and extract loc =
        (loc  >>-: get >>-: Precise_locs.enumerate_valid_bits Read :> 'a or_top_bottom)
      in
      extract_loc res |> Response.map_join' extract join |> convert

  let is_initialized : type c. c evaluation -> bool =
    function
    | `LValue r ->
      let join = (&&)
      and extract (x, _alarms) =
        (x >>-: (fun (_valuation,fv) -> fv.Eval.initialized) :> 'a or_top_bottom)
      in
      begin match Response.map_join' extract join r with
        | `Bottom | `Top -> false
        | `Value v -> v
      end
    | `Value _ -> true (* computed values are always initialized *)

  let alarms : type c. c evaluation -> Alarms.t list =
    fun res ->
    let extract (_,v) = `Value v in
    let r = match res with
      | `LValue r ->
        Response.map_join' extract Alarmset.union r
      | `Value r ->
        Response.map_join' extract Alarmset.union r
    in
    match r with
    | `Bottom | `Top -> []
    | `Value alarmset ->
      let open Alarmset in
      let l = ref [] in
      let add alarm = function
        | True -> ()
        | False | Unknown -> l := alarm :: !l
      in
      Alarmset.iter add alarmset;
      !l

  let is_bottom : type c. c evaluation -> bool =
    fun res ->
    let extract (x,_) = (x >>-: fun _ -> () :> unit or_top_bottom) in
    let join () () = () in
    let r = match res with
      | `LValue r ->
        Response.map_join' extract join r
      | `Value r ->
        Response.map_join' extract join r
    in
    match r with
    | `Bottom -> true
    | `Top | `Value () -> false
end


(* Working with callstacks *)

let callstacks req =
  let module E = Make () in
  E.callstacks req

let fold_callstacks f acc req =
  let module E = Make () in
  E.fold_callstacks f acc req

let by_callstack req =
  let module E = Make () in
  E.by_callstack req


(* State requests *)

let equality_class exp req =
  let module E = Make () in
  E.equality_class exp req

let as_cvalue_model req =
  let module E = Make () in
  E.as_cvalue_model req


(* Evaluation *)

module type Evaluator =
sig
  type 'a lvaluation
  type 'a evaluation
  type restriction
  val as_cvalue : 'callstack evaluation -> Main_values.CVal.t result
  val as_functions : 'callstack evaluation ->
    Cil_types.kernel_function list result
  val as_location : 'callstack lvaluation -> Locations.location result
  val as_zone : 'callstack lvaluation -> Locations.Zone.t result
  val is_initialized : 'callstack evaluation -> bool
  val alarms : 'callstack evaluation -> Alarms.t list
  val is_bottom : 'callstack evaluation -> bool
end

module type Lvaluation =
sig
  include Evaluator
  val v : restriction lvaluation
end

module type Evaluation =
sig
  include Evaluator
  val v : restriction evaluation
end

type lvaluation = (module Lvaluation)
type evaluation = (module Evaluation)

let build_eval_lval_and_exp () =
  let module M = Make () in
  let open Response in
  let build = function
    | `LValue (Consolidated _)
    | `Value (Consolidated _) as eval ->
      (module struct
        include M
        type restriction = unrestricted_response
        let v = eval
      end : Evaluation)
    | `LValue (ByCallstack _ | Top | Bottom)
    | `Value (ByCallstack _ | Top | Bottom) as eval ->
      (module struct
        include M
        type restriction = restricted_to_callstack
        let v = eval
      end : Evaluation)
  in
  let eval_lval lval req = build @@ M.eval_lval lval req in
  let eval_exp exp req = build @@ M.eval_exp exp req in
  eval_lval, eval_exp

let eval_lval lval req = (fst @@ build_eval_lval_and_exp ()) lval req

let eval_var vi req =
  eval_lval (Cil.var vi) req

let eval_exp exp req = (snd @@ build_eval_lval_and_exp ()) exp req

let eval_address lval req =
  let module M = Make () in
  let open Response in
  match M.eval_address lval req with
  | Consolidated _ as lval ->
    (module struct
      include M
      type restriction = unrestricted_response
      let v = lval
    end : Lvaluation)
  | (ByCallstack _ | Top | Bottom) as lval ->
    (module struct
      include M
      type restriction = restricted_to_callstack
      let v = lval
    end : Lvaluation)

(* Value conversion *)

let as_cvalue evaluation =
  let module E = (val evaluation : Evaluation) in
  E.as_cvalue E.v

let as_ival evaluation =
  try
    Result.map Cvalue.V.project_ival (as_cvalue evaluation)
  with Cvalue.V.Not_based_on_null ->
    Result.error Top

let as_fval evaluation =
  let f ival =
    if Ival.is_float ival
    then Result.ok (Ival.project_float ival)
    else Result.error Top
  in
  Result.bind (as_ival evaluation) f

let as_float evaluation =
  try
    as_fval evaluation |>
    Result.map Fval.project_float |>
    Result.map Fval.F.to_float
  with Fval.Not_Singleton_Float ->
    Result.error Top

let as_functions evaluation =
  let module E = (val evaluation : Evaluation) in
  E.as_functions E.v

let as_integer evaluation =
  try
    Result.map Ival.project_int (as_ival evaluation)
  with Ival.Not_Singleton_Int ->
    Result.error Top

let as_int evaluation =
  try
    Result.map Integer.to_int (as_integer evaluation)
  with Z.Overflow ->
    Result.error Top

let as_location lvaluation =
  let module E = (val lvaluation : Lvaluation) in
  E.as_location E.v

let as_zone lvaluation =
  let module E = (val lvaluation : Lvaluation) in
  E.as_zone E.v

(* Evaluation properties *)

let is_initialized evaluation =
  let module E = (val evaluation : Evaluation) in
  E.is_initialized E.v

let alarms evaluation =
  let module E = (val evaluation : Evaluation) in
  E.alarms E.v

(* Bottomness *)

let is_bottom evaluation =
  let module E = (val evaluation : Evaluation) in
  E.is_bottom E.v

let is_called kf =
  let module M = Make () in
  M.is_reachable (at_start_of kf)

let is_reachable stmt =
  let module M = Make () in
  M.is_reachable (before stmt)
