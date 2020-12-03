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

open Bottom.Type

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

module Response =
struct
  type 'a t =
    [ `Consolidated of 'a
    | `ByCallstack of 'a by_callstack
    | `Top
    | `Bottom
    ]

  (* Constructors *)

  let consolidated =
    function
    | `Bottom -> `Bottom
    | `Value state -> `Consolidated state

  let singleton cs =
    function
    | `Bottom -> `Bottom
    | `Value state -> `ByCallstack [cs,state]

  let by_callstack req table =
    match table with
    | `Top -> `Top
    | `Bottom -> `Bottom
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
      `ByCallstack l

  (* Accessors *)

  let callstacks = function
    | `ByCallstack l -> List.map fst l
    | `Top | `Bottom -> [] (* What else to do when Top is given ? *) 

  (* Map *)

  let map f = function
    | `Consolidated v -> `Consolidated (f v)
    | `ByCallstack l -> `ByCallstack (List.map (fun (cs,x) -> cs,f x) l)
    | `Top -> `Top
    | `Bottom -> `Bottom

  (* Reduction *)

  let map_reduce
      (default : [`Top | `Bottom] -> 'b)
      (map : 'a -> 'b)
      (reduce : 'b -> 'b -> 'b) : 'a t -> 'b =
    function
    | `Consolidated v -> map v
    | `ByCallstack ((_,h) :: t) ->
      List.fold_left (fun acc (_,x) -> reduce acc (map x)) (map h) t    
    | `ByCallstack [] -> default `Bottom
    | (`Top | `Bottom) as v -> default v

  let map_join (map : 'a -> 'b) (join : 'b -> 'b -> 'b) =
    let default = function
      | `Bottom -> `Bottom
      | `Top -> `Top
    and map' x =
      `Value (map x)
    in
    map_reduce default map' (Bottom.Top.join join)

  let map_join' (map : 'a -> 'b or_top_bottom) (join : 'b -> 'b -> 'b) =
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
  type valuation = A.Eval.Valuation.t

  type evaluation =
  [ `LValue of Cil_types.lval *
      (valuation * value Eval.flagged_value) Eval.evaluated Response.t 
  | `Value of (valuation * value) Eval.evaluated Response.t
  ]

  let get_by_callstack req =
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

  let get req =
    if Option.is_some req.filter || Option.is_some req.selector then
      get_by_callstack req
    else
      let open Response in
      match req.control_point with
      | Before stmt ->
        A.get_stmt_state ~after:false stmt |> consolidated
      | After stmt ->
        A.get_stmt_state ~after:true stmt |> consolidated
      | _ ->
        get_by_callstack req

  let convert : 'a or_top_bottom -> 'a result = function
    | `Top -> Result.error Top
    | `Bottom -> Result.error Bottom
    | `Value v -> Result.ok v

  let callstacks req =
    Response.callstacks (get_by_callstack req)

  let equality_class _exp _req =
    raise Not_implemented (* Where is the key for Equality_domain ? *)

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

  let eval_lval lval req =
    let eval state =
      A.Eval.copy_lvalue state lval
    in
    `LValue (lval, Response.map eval (get req))

  let eval_exp exp req =
    let eval state =
      A.Eval.evaluate state exp
    in
    `Value (Response.map eval (get req))

  let eval_address lval req =
    let eval state =
      A.Eval.lvaluate state lval
    in
    Response.map eval (get req)

  (* Conversion *)

  open Bottom.Type

  let extract_value res =
    match res with
    | `LValue (_lval, r) ->
      let extract (x, _alarms) =
        x >>- (fun (_valuation,fv) -> fv.Eval.v)
      in
      Response.map extract r
    | `Value r ->
      let extract (x, _alarms) =
        x >>-: (fun (_valuation,v) -> v)
      in
      Response.map extract r

  let as_cvalue res =
    match A.Val.get Main_values.CVal.key with
    | None ->
      Result.error DisabledDomain
    | Some get ->
      let join = Main_values.CVal.join in
      let extract value =
        (value >>-: get :> 'a or_top_bottom)
      in
      extract_value res |> Response.map_join' extract join |> convert

  let as_functions res = 
      let join = (@)
      and extract value =
        value >>>- fun v -> (fst (A.Val.resolve_functions v) :> 'a or_top_bottom)
      in    
      extract_value res |> Response.map_join' extract join |> convert
end


(* State requests *)

let callstacks req =
  let module E = Make () in
  E.callstacks req

let equality_class exp req = 
  let module E = Make () in
  E.equality_class exp req

let as_cvalue_model req =
  let module E = Make () in
  E.as_cvalue_model req
  
(* Evaluation *)

module type Evaluation =
sig
  type evaluation
  val v : evaluation
  val as_cvalue : evaluation -> Main_values.CVal.t result
  val as_functions : evaluation -> Cil_types.kernel_function list result
end

type evaluation = (module Evaluation)
type lvaluation

let eval_lval lval req =
  (module struct
    include Make ()
    let v = (eval_lval lval req :> evaluation)
  end : Evaluation)

let eval_var vi req =
  eval_lval (Cil.var vi) req

let eval_exp exp req =
  (module struct
    include Make ()
    let v = (eval_exp exp req :> evaluation)
  end : Evaluation)

let eval_address _lval _req =
  raise Not_implemented

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

let as_kf _evaluation =
  raise Not_implemented

let as_location _lvaluation =
  raise Not_implemented
let as_zone _lvaluation =
  raise Not_implemented

(* Evaluation properties *)

let is_initialized _evaluation =
  raise Not_implemented
let deps _evaluation =
  raise Not_implemented
let alarms _evaluation =
  raise Not_implemented

(* Bottomness *)

let is_bottom _evaluation =
  raise Not_implemented
let is_called _kf =
  raise Not_implemented
let is_reachable _stmt =
  raise Not_implemented
