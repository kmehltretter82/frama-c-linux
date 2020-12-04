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
type probe = Pexpr of exp * stmt | Plval of lval

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

module CS = Value_types.Callstack
module CSmap = CS.Hashtbl
module CSlist =
struct
  type t = callstack list
  let rec hash = function [] -> 1 | a::q -> CS.hash a + 31 * hash q
  let rec equal ca cb = match ca , cb with
    | [] , [] -> true
    | a::p , b::q -> Callstack.equal a b && equal p q
    | _ -> false
end

(* -------------------------------------------------------------------------- *)
(* --- EVA Proxy                                                          --- *)
(* -------------------------------------------------------------------------- *)

module type EvaProxy =
sig
  val callstacks : stmt -> callstack list
  val domain : Printer_tag.localizable -> callstack list -> domain
end

module Proxy(A : Analysis.S) : EvaProxy =
struct

  open Eval
  type dstate = A.Dom.state or_top_or_bottom

  module CSSmap = Hashtbl.Make
      (struct
        type t = bool * stmt * callstack list
        let hash (after,stmt,cs) =
          Hashtbl.hash (after,Cil_datatype.Stmt.hash stmt,CSlist.hash cs)
        let equal (a1,s1,cs1) (a2,s2,cs2) =
          a1 = a2 && Cil_datatype.Stmt.equal s1 s2 && CSlist.equal cs1 cs2
      end)

  let stackcache = CSSmap.create 0

  let callstacks stmt =
    match A.get_stmt_state_by_callstack ~after:false stmt with
    | `Top | `Bottom -> []
    | `Value states ->
      CSmap.fold_sorted (fun cs _st css -> cs :: css) states []

  let dstate ~after stmt callstack =
    match callstack with
    | [] -> (A.get_stmt_state ~after stmt :> dstate)
    | css ->
      begin match A.get_stmt_state_by_callstack ~after stmt with
        | `Top -> `Top
        | `Bottom -> `Bottom
        | `Value cmap ->
          match css with
          | [cs] ->
            begin
              try `Value (CSmap.find cmap cs)
              with Not_found -> `Bottom
            end
          | css ->
            begin
              try CSSmap.find stackcache (after,stmt,css)
              with Not_found ->
                (List.fold_left
                   (fun d cs ->
                      try
                        let s = CSmap.find cmap cs in
                        match d with
                        | `Bottom -> d
                        | `Value s0 -> `Value (A.Dom.join s0 s)
                      with Not_found -> d
                   ) `Bottom css :> dstate)
            end
      end

  let dnone = {
    alarms = [] ;
    values = [] ;
  }

  let dtop = {
    alarms = [] ;
    values = [`Here , "Not available."] ;
  }

  let dbottom = {
    alarms = [] ;
    values = [`Here , "Unreachable."] ;
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

  let dexpr e s css = deval (e_expr e) s css
  let dlval l s css = deval (e_lval l) s css

  let domain marker _callstacks =
    let open Printer_tag in
    match marker with
    | _ -> dnone

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
