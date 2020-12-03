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
module Jkf = Kernel_ast.Kf
module Jki = Kernel_ast.Ki
module Jstmt = Kernel_ast.Stmt
module CS = Value_types.Callstack
module CSmap = CS.Hashtbl

let package =
  Package.package
    ~plugin:"eva"
    ~name:"values"
    ~title:"Eva Values"
    ~readme:"eva.md"
    ()

type callstack = Value_types.callstack

type truth = Abstract_interp.truth
type step = [ `Here | `After | `Then of exp | `Else of exp ]

type probe =
  | Expr of exp * stmt
  | Lval of lval * stmt

type domain = {
  values: ( step * string ) list ;
  alarms: ( truth * string ) list ;
}

(* -------------------------------------------------------------------------- *)
(* --- Domain Utilities                                                   --- *)
(* -------------------------------------------------------------------------- *)

let next_steps s : step list =
  match s.skind with
  | If(cond,_,_,_) -> [ `Then cond ; `Else cond ]
  | Instr (Set _ | Call _ | Local_init _ | Asm _ | Code_annot _)
  | Switch _ | Loop _ | Block _ | UnspecifiedSequence _
  | TryCatch _ | TryFinally _ | TryExcept _
    -> [ `After ]
  | Instr (Skip _) | Return _ | Break _ | Continue _ | Goto _ | Throw _ -> []

(* -------------------------------------------------------------------------- *)
(* --- EVA Proxy                                                          --- *)
(* -------------------------------------------------------------------------- *)

module type EvaProxy =
sig
  val callstacks : stmt -> callstack list
  val domain : probe -> callstack option -> domain
end

module Proxy(A : Analysis.S) : EvaProxy =
struct

  open Eval
  type dstate = A.Dom.state or_top_or_bottom

  let callstacks stmt =
    match A.get_stmt_state_by_callstack ~after:false stmt with
    | `Top | `Bottom -> []
    | `Value states ->
      CSmap.fold_sorted (fun cs _st css -> cs :: css) states []

  let dstate ~after stmt callstack =
    match callstack with
    | None -> (A.get_stmt_state ~after stmt :> dstate)
    | Some cs ->
      begin match A.get_stmt_state_by_callstack ~after stmt with
        | `Top -> `Top
          | `Bottom -> `Bottom
          | `Value cmap ->
            try `Value (CSmap.find cmap cs)
            with Not_found -> `Bottom
      end

  let dbottom = {
    alarms = [] ;
    values = [`Here , "Unreachable (bottom)"] ;
  }

  let dtop = {
    alarms = [] ;
    values = [`Here , "Not available (top)"] ;
  }

  let dalarms alarms =
    let pool = ref [] in
    Alarmset.iter
      (fun alarm status ->
         let descr = Format.asprintf "@[<hov 2>%a@]" Alarms.pretty alarm
         in pool := (status , descr) :: !pool
      ) alarms ;
    List.rev !pool

  let deval (eval : A.Dom.state -> string * Alarmset.t) stmt callstack =
    match dstate ~after:false stmt callstack with
    | `Bottom -> dbottom
    | `Top -> dtop
    | `Value state ->
      let value, alarms = eval state in
      let dnext (step : step) vs = function
        | `Top | `Bottom -> vs
        | `Value state -> (step , fst @@ eval state) :: vs in
      let others = List.fold_right
          begin fun st vs ->
            match st with
            | `Here -> vs (* absurd *)
            | `After -> dnext st vs @@ dstate ~after:false stmt callstack
            | `Then cond -> dnext st vs @@ A.assume_cond stmt state cond true
            | `Else cond -> dnext st vs @@ A.assume_cond stmt state cond false
          end (next_steps stmt) []
      in {
        values = (`Here,value) :: others ;
        alarms = dalarms alarms ;
      }

  let e_expr expr state =
    let value, alarms = A.eval_expr state expr in
    begin
      Pretty_utils.to_string (Bottom.pretty A.Val.pretty) value,
      alarms
    end

  let e_lval lval state =
    let value, alarms = A.copy_lvalue state lval in
    let flagged = match value with
      | `Bottom -> Eval.Flagged_Value.bottom
      | `Value v -> v in
    begin
      Pretty_utils.to_string (Eval.Flagged_Value.pretty A.Val.pretty) flagged,
      alarms
    end

  let domain probe callstack =
    match probe with
    | Expr(expr,stmt) -> deval (e_expr expr) stmt callstack
    | Lval(lval,stmt) -> deval (e_lval lval) stmt callstack

end

let proxy =
  let make (a : (module Analysis.S)) = (module Proxy(val a) : EvaProxy) in
  let current = ref (make @@ Analysis.current_analyzer ()) in
  let () = Analysis.register_hook (fun a -> current := make a) in
  current

(* -------------------------------------------------------------------------- *)
(* --- Request getCallstackInfos                                          --- *)
(* -------------------------------------------------------------------------- *)

module Jcallstack = Data.Index(Value_types.Callstack.Map)
    (struct let name = "eva-callstack-id" end)

let pretty fmt cs =
  match cs with
    | (_, Kstmt _) :: callers ->
      Value_types.Callstack.pretty_hash fmt cs;
      Pretty_utils.pp_flowlist ~left:"@[" ~sep:" ←@ " ~right:"@]"
        (fun fmt (kf, _) -> Kernel_function.pretty fmt kf) fmt callers
    | _ -> ()

let () =
  let getCallstackInfos = Request.signature
      ~input:(module Jcallstack) () in
  let set_descr = Request.result getCallstackInfos ~name:"descr"
      ~descr:(Md.plain "Description")
      (module Jstring) in
  let set_calls = Request.result getCallstackInfos ~name:"calls"
      ~descr:(Md.plain "Callers site, from last to first")
      (module Jlist(Jpair(Jkf)(Jki))) in
  Request.register_sig ~package getCallstackInfos
      ~kind:`GET ~name:"getCallstackInfos"
      ~descr:(Md.plain "Callstack Description")
      begin fun rq cs ->
        set_calls rq cs ;
        set_descr rq (Pretty_utils.to_string pretty cs) ;
      end

(* -------------------------------------------------------------------------- *)
(* --- Request getCallstacks                                              --- *)
(* -------------------------------------------------------------------------- *)

let () = Request.register ~package
    ~kind:`GET ~name:"getCallstacks"
    ~descr:(Md.plain "Callstacks to a statement")
    ~input:(module Jstmt)
    ~output:(module Jlist(Jcallstack))
    (fun stmt -> let module A = (val !proxy) in A.callstacks stmt)

(* -------------------------------------------------------------------------- *)
