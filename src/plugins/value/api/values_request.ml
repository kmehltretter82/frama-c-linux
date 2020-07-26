(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2020                                               *)
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

open Server
open Data
open Cil_types
module Md = Markdown

let package =
  Package.package
    ~plugin:"eva"
    ~name:"values"
    ~title:"Eva Values"
    ~readme:"eva.md"
    ()

type value =
  { value: string;
    alarm: bool; }

type evaluation =
  | Unreachable
  | Evaluation of value

type after =
  | Unchanged
  | Reduced of evaluation

type before_after =
  { before: evaluation;
    after_instr: after option;
    after_then: after option;
    after_else: after option; }

type values =
  { values: before_after;
    callstack: (Value_util.callstack * before_after) list option; }

let get_value = function
  | Unreachable -> "Unreachable"
  | Evaluation { value } -> value

let get_alarm = function
  | Unreachable -> false
  | Evaluation { alarm } -> alarm

let get_after_value =
  Extlib.opt_map
    (function Unchanged -> "unchanged" | Reduced eval -> get_value eval)

module CallStackId =
  Data.Index
    (Value_types.Callstack.Map)
    (struct
      let name = "eva-callstack-id"
    end)

(* This pretty-printer drops the toplevel kf, which is always the function
   in which we are pretty-printing the expression/term *)
let pretty_callstack fmt cs =
  match cs with
  | [_, Kglobal] -> ()
  | (_kf_cur, Kstmt callsite) :: q -> begin
      let rec aux callsite = function
        | (kf, callsite') :: q -> begin
            Format.fprintf fmt "%a (%a)"
              Kernel_function.pretty kf
              Cil_datatype.Location.pretty (Cil_datatype.Stmt.loc callsite);
            match callsite' with
            | Kglobal -> ()
            | Kstmt callsite' ->
              Format.fprintf fmt " ←@ ";
              aux callsite' q
          end
        | _ -> assert false
      in
      Format.fprintf fmt "@[<hv>%a" Value_types.Callstack.pretty_hash cs;
      aux callsite q;
      Format.fprintf fmt "@]"
    end
  | _ -> assert false

(* This pretty-printer prints only the lists of the functions, not
   the locations. *)
let pretty_callstack_short fmt cs =
  match cs with
  | [_, Kglobal] -> ()
  | (_kf_cur, Kstmt _callsite) :: q ->
    Format.fprintf fmt "%a" Value_types.Callstack.pretty_hash cs;
    Pretty_utils.pp_flowlist ~left:"@[" ~sep:" ←@ " ~right:"@]"
      (fun fmt (kf, _) -> Kernel_function.pretty fmt kf) fmt q
  | _ -> assert false

module CallStack = struct
  type record

  let record: record Record.signature = Record.signature ()

  let id = Record.field record ~name:"id"
      ~descr:(Md.plain "Callstack id") (module Jint)
  let short = Record.field record ~name:"short"
      ~descr:(Md.plain "Short name for the callstack") (module Jstring)
  let full = Record.field record ~name:"full"
      ~descr:(Md.plain "Full name for the callstack") (module Jstring)

  module R =
    (val
      (Record.publish
         ~package
         ~name:"callstack"
         ~descr:(Md.plain "CallStack")
         record) : Record.S with type r = record)

  type t = Value_types.callstack option

  let jtype = R.jtype

  let pp_callstack ~short = function
    | None -> if short then "all" else ""
    | Some callstack ->
      let pp_text =
        if short
        then Pretty_utils.to_string ~margin:50 pretty_callstack_short
        else Pretty_utils.to_string pretty_callstack
      in
      (pp_text callstack)

  let id_callstack = function
    | None -> -1
    | Some callstack -> CallStackId.get callstack

  let to_json callstack =
    R.default |>
    R.set id (id_callstack callstack) |>
    R.set short (pp_callstack ~short:true callstack) |>
    R.set full (pp_callstack ~short:false callstack) |>
    R.to_json

  let key = function
    | None -> "all"
    | Some callstack -> string_of_int (CallStackId.get callstack)
end


let consolidated = ref None
let table = Hashtbl.create 100

let iter f =
  if Hashtbl.length table > 1
  then Extlib.may (fun values -> f (None, values)) !consolidated;
  Hashtbl.iter (fun key data -> f (Some key, data)) table

let array =
  let model = States.model () in
  let () =
    States.column
      ~name:"callstack"
      ~descr:(Md.plain "CallStack")
      ~data:(module CallStack)
      ~get:fst
      model
  in
  let () =
    States.column
      ~name:"value_before"
      ~descr:(Md.plain "Value inferred just before the selected point")
      ~data:(module Jstring)
      ~get:(fun (_, e) -> get_value e.before)
      model
  in
  let () =
    States.column
      ~name:"alarm"
      ~descr:(Md.plain "Did the evaluation led to an alarm?")
      ~data:(module Jbool)
      ~get:(fun (_, e) -> get_alarm e.before)
      model
  in
  let () =
    States.column
      ~name:"value_after"
      ~descr:(Md.plain "Value inferred just after the selected point")
      ~data:(module Joption(Jstring))
      ~get:(fun (_, e) -> get_after_value e.after_instr)
      model
  in
  States.register_array
    ~package
    ~name:"values"
    ~descr:(Md.plain "Abstract values inferred by the Eva analysis")
    ~key:(fun (cs, _) -> CallStack.key cs)
    ~iter
    model

let update_values values =
  Hashtbl.clear table;
  consolidated := Some values.values;
  let () =
    match values.callstack with
    | None -> ()
    | Some by_callstack ->
      List.iter
        (fun (callstack, before_after) ->
           Hashtbl.add table callstack before_after)
        by_callstack
  in
  States.reload array

module type S = sig
  val evaluate: kinstr -> exp -> values
  val lvaluate: kinstr -> lval -> values
end

module Make (Eva: Analysis.S) : S = struct

  let make_before eval before =
    let before =
      match before with
      | `Bottom -> Unreachable
      | `Value state -> Evaluation (eval state)
    in
    { before; after_instr = None; after_then = None; after_else = None; }

  let make_callstack stmt eval =
    let before = Eva.get_stmt_state_by_callstack ~after:false stmt in
    match before with
    | (`Bottom | `Top) -> []
    | `Value before ->
      let aux callstack before acc =
        let before_after = make_before eval (`Value before) in
        (callstack, before_after) :: acc
      in
      Value_types.Callstack.Hashtbl.fold aux before []

  let make_before_after eval ~before ~after =
    match before with
    | `Bottom ->
      { before = Unreachable;
        after_instr = None;
        after_then = None;
        after_else = None; }
    | `Value before ->
      let before = eval before in
      let after_instr =
        match after with
        | `Bottom -> Some (Reduced Unreachable)
        | `Value after ->
          let after = eval after in
          if String.equal before.value after.value
          then Some Unchanged
          else Some (Reduced (Evaluation after))
      in
      { before = Evaluation before;
        after_instr; after_then = None; after_else = None; }

  let make_instr_callstack stmt eval =
    let before = Eva.get_stmt_state_by_callstack ~after:false stmt in
    let after = Eva.get_stmt_state_by_callstack ~after:true stmt in
    match before, after with
    | (`Bottom | `Top), _
    | _, (`Bottom | `Top) -> []
    | `Value before, `Value after ->
      let aux callstack before acc =
        let before = `Value before in
        let after =
          try `Value (Value_types.Callstack.Hashtbl.find after callstack)
          with Not_found -> `Bottom
        in
        let before_after = make_before_after eval ~before ~after in
        (callstack, before_after) :: acc
      in
      Value_types.Callstack.Hashtbl.fold aux before []

  let make eval kinstr =
    let before = Eva.get_kinstr_state ~after:false kinstr in
    let values, callstack =
      match kinstr with
      | Cil_types.Kglobal ->
        make_before eval before, None
      | Cil_types.Kstmt stmt ->
        match stmt.skind with
        | Instr _ ->
          let after = Eva.get_kinstr_state ~after:true kinstr in
          let values = make_before_after eval ~before ~after in
          let callstack = make_instr_callstack stmt eval in
          values, Some callstack
        | _ ->
          make_before eval before, Some (make_callstack stmt eval)
    in
    { values; callstack; }


  let evaluate kinstr expr =
    let eval state =
      let value, alarms = Eva.eval_expr state expr in
      let alarm = not (Alarmset.is_empty alarms) in
      let str = Format.asprintf "%a" (Bottom.pretty Eva.Val.pretty) value in
      { value = str; alarm }
    in
    make eval kinstr

  let lvaluate kinstr lval =
    let eval state =
      let value, alarms = Eva.copy_lvalue state lval in
      let alarm = not (Alarmset.is_empty alarms) in
      let flagged_value = match value with
        | `Bottom -> Eval.Flagged_Value.bottom
        | `Value v -> v
      in
      let pretty = Eval.Flagged_Value.pretty Eva.Val.pretty in
      let str = Format.asprintf "%a" pretty flagged_value in
      { value = str; alarm }
    in
    make eval kinstr
end


let ref_request =
  let module Analyzer = (val Analysis.current_analyzer ()) in
  ref (module Make (Analyzer) : S)

let hook (module Analyzer: Analysis.S) =
  ref_request := (module Make (Analyzer) : S)

let () = Analysis.register_hook hook


let update tag =
  let module Request = (val !ref_request) in
  match tag with
  | Printer_tag.PExp (_kf, kinstr, expr) ->
    update_values (Request.evaluate kinstr expr)
  | Printer_tag.PLval (_kf, kinstr, lval) ->
    update_values (Request.lvaluate kinstr lval)
  | PVDecl (_kf, kinstr, varinfo) ->
    update_values (Request.lvaluate kinstr (Var varinfo, NoOffset))
  | _ -> ()

let () =
  Server.Request.register
    ~package
    ~kind:`GET
    ~name:"getValues"
    ~descr:(Md.plain "Get the abstract values computed for an expression or lvalue")
    ~input:(module Kernel_ast.Marker)
    ~output:(module Junit)
    update
