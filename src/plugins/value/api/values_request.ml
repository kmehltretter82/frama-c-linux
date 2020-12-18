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

module Kmap = Kernel_function.Hashtbl
module Smap = Cil_datatype.Stmt.Hashtbl
module CS = Value_types.Callstack
module CSmap = CS.Hashtbl

module Md = Markdown
module Jkf = Kernel_ast.Kf
module Jstmt = Kernel_ast.Stmt
module Jmarker = Kernel_ast.Marker

let package =
  Package.package
    ~plugin:"eva"
    ~name:"values"
    ~title:"Eva Values"
    ~readme:"eva.md"
    ()

type probe =
  | Pexpr of exp * stmt
  | Plval of lval * stmt
  | Pnone

type callstack = Value_types.callstack
type truth = Abstract_interp.truth
type step = [ `Here | `After | `Then of exp | `Else of exp ]

type domain = {
  values: ( step * string ) list ;
  alarms: ( truth * string ) list ;
}

let signal = Request.signal ~package ~name:"changed"
    ~descr:(Md.plain "Emitted when EVA results has changed")

let () = Analysis.register_computed_hook (fun () -> Request.emit signal)

(* -------------------------------------------------------------------------- *)
(* --- Marker Utilities                                                   --- *)
(* -------------------------------------------------------------------------- *)

let next_steps s : step list =
  match s.skind with
  | If(cond,_,_,_) -> [ `Then cond ; `Else cond ]
  | Instr (Set _ | Call _ | Local_init _ | Asm _ | Code_annot _)
  | Switch _ | Loop _ | Block _ | UnspecifiedSequence _
  | TryCatch _ | TryFinally _ | TryExcept _
    -> [ `After ]
  | Instr (Skip _) | Return _ | Break _ | Continue _ | Goto _ | Throw _ -> []

let probe_stmt s =
  match s.skind with
  | Instr (Set(lv,_,_)) -> Plval(lv,s)
  | Instr (Call(Some lr,_,_,_)) -> Plval(lr,s)
  | Instr (Local_init(v,_,_)) -> Plval((Var v,NoOffset),s)
  | Return (Some e,_) | If(e,_,_,_) | Switch(e,_,_,_) -> Pexpr(e,s)
  | _ -> Pnone

let probe marker =
  let open Printer_tag in
  match marker with
  | PLval(_,Kstmt s,l) -> Plval(l,s)
  | PExp(_,Kstmt s,e) -> Pexpr(e,s)
  | PStmt(_,s) | PStmtStart(_,s) -> probe_stmt s
  | PVDecl(_,Kstmt s,v) -> Plval((Var v,NoOffset),s)
  | _ -> Pnone

(* -------------------------------------------------------------------------- *)
(* --- Stmt Ranking                                                       --- *)
(* -------------------------------------------------------------------------- *)

module Ranking :
sig
  val stmt : stmt -> int
  val sort : callstack list -> callstack list
end =
struct

  class ranker =
    object(self)
      inherit Visitor.frama_c_inplace
      (* ranks really starts at 1 *)
      (* rank < 0 means not computed yet *)
      val mutable rank = (-1)
      val rmap = Smap.create 0
      val fmark = Kmap.create 0
      val fqueue = Queue.create ()

      method private call kf =
        if not (Kmap.mem fmark kf) then
          begin
            Kmap.add fmark kf () ;
            Queue.push kf fqueue ;
          end

      method private newrank s =
        let r = succ rank in
        Smap.add rmap s r ;
        rank <- r ; r

      method! vlval lv =
        begin
          try match fst lv with
            | Var vi -> self#call (Globals.Functions.get vi)
            | _ -> ()
          with Not_found -> ()
        end ; Cil.DoChildren

      method! vstmt_aux s =
        ignore (self#newrank s) ;
        Cil.DoChildren

      method flush =
        while not (Queue.is_empty fqueue) do
          let kf = Queue.pop fqueue in
          ignore (Visitor.(visitFramacKf (self :> frama_c_visitor) kf))
        done

      method compute =
        match Globals.entry_point () with
        | kf , _ -> self#call kf ; self#flush
        | exception Globals.No_such_entry_point _ -> ()

      method rank s =
        if rank < 0 then (rank <- 0 ; self#compute) ;
        try Smap.find rmap s
        with Not_found ->
          let kf = Kernel_function.find_englobing_kf s in
          self#call kf ;
          self#flush ;
          try Smap.find rmap s
          with Not_found -> self#newrank s

    end

  let stmt = let rk = new ranker in rk#rank

  let rec ranks (rks : int list) (cs : callstack) : int list =
    match cs with
    | [] -> rks
    | (_,Kglobal)::wcs -> ranks rks wcs
    | (_,Kstmt s)::wcs -> ranks (stmt s :: rks) wcs

  let order : int list -> int list -> int = Stdlib.compare

  let sort (wcs : callstack list) : callstack list =
    List.map fst @@
    List.sort (fun (_,rp) (_,rq) -> order rp rq) @@
    List.map (fun cs -> cs , ranks [] cs) wcs

end

(* -------------------------------------------------------------------------- *)
(* --- Domain Utilities                                                   --- *)
(* -------------------------------------------------------------------------- *)

module Jcallstack : S with type t = callstack =
struct
  module I = Data.Index
      (Value_types.Callstack.Map)
      (struct let name = "eva-callstack-id" end)
  let jtype = Data.declare ~package ~name:"callstack" I.jtype
  type t = I.t
  let to_json = I.to_json
  let of_json = I.of_json
end

module Jcalls : Request.Output with type t = callstack =
struct

  type t = callstack
  let jtype = Package.(Jlist (Jrecord [
      "callee" , Jkf.jtype ;
      "caller" , Joption Jkf.jtype ;
      "stmt" , Joption Jstmt.jtype ;
      "rank" , Joption Jnumber ;
    ]))

  let rec jcallstack jcallee ki cs : json list =
    match ki , cs with
    | Kglobal , _ | _ , [] -> [
        `Assoc [ "callee", jcallee ]
      ]
    | Kstmt stmt , (called,ki) :: cs ->
      let jcaller = Jkf.to_json called in
      let callsite = `Assoc [
          "callee", jcallee ;
          "caller", jcaller ;
          "stmt", Jstmt.to_json stmt ;
          "rank", Jint.to_json (Ranking.stmt stmt) ;
        ] in
      callsite :: jcallstack jcaller ki cs

  let to_json = function
    | [] -> `List []
    | (callee,ki)::cs -> `List (jcallstack (Jkf.to_json callee) ki cs)

end



module Jtruth : Data.S with type t = truth =
struct
  type t = truth
  let jtype =
    Package.(Junion [ Jtag "True" ; Jtag "False" ; Jtag "Unknown" ])
  let to_json = function
    | Abstract_interp.Unknown -> `String "Unknown"
    | True -> `String "True"
    | False -> `String "False"
  let of_json = function
    | `String "True" -> Abstract_interp.True
    | `String "False" -> Abstract_interp.False
    | _ -> Abstract_interp.Unknown
end

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
      CSmap.fold_sorted (fun cs _st wcs -> cs :: wcs) states []

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
        | `Value state ->
          let values =
            try fst @@ eval state
            with exn -> Printf.sprintf "Error (%S)" (Printexc.to_string exn)
          in (step , values) :: vs in
      let others = List.fold_right
          begin fun st vs ->
            match st with
            | `Here -> vs (* absurd *)
            | `After -> dnext st vs @@ dstate ~after:true stmt callstack
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

  let domain p wcs = match p with
    | Plval(l,s) -> deval (e_lval l) s wcs
    | Pexpr(e,s) -> deval (e_expr e) s wcs
    | Pnone -> dnone

end

let proxy =
  let make (a : (module Analysis.S)) = (module Proxy(val a) : EvaProxy) in
  let current = ref (make @@ Analysis.current_analyzer ()) in
  let () = Analysis.register_hook
      begin fun a ->
        current := make a ;
        Request.emit signal ;
      end
  in current

(* -------------------------------------------------------------------------- *)
(* --- Request getCallstacks                                              --- *)
(* -------------------------------------------------------------------------- *)

let () = Request.register ~package
    ~kind:`GET ~name:"getCallstacks"
    ~descr:(Md.plain "Callstacks for markers")
    ~input:(module Jstmt)
    ~output:(module Jlist(Jcallstack))
    begin fun stmt ->
      let module A = (val !proxy) in
      Ranking.sort (A.callstacks stmt)
    end

(* -------------------------------------------------------------------------- *)
(* --- Request getCallstackInfo                                           --- *)
(* -------------------------------------------------------------------------- *)

let () =
  Request.register ~package
    ~kind:`GET ~name:"getCallstackInfo"
    ~descr:(Md.plain "Callstack Description")
    ~input:(module Jcallstack)
    ~output:(module Jcalls)
    begin fun cs -> cs end

(* -------------------------------------------------------------------------- *)
(* --- Request getStmtInfo                                                --- *)
(* -------------------------------------------------------------------------- *)

let () =
  let getStmtInfo = Request.signature ~input:(module Jstmt) () in
  let set_fct = Request.result getStmtInfo ~name:"fct"
      ~descr:(Md.plain "Englobing function")
      (module Jkf) in
  let set_rank = Request.result getStmtInfo ~name:"rank"
      ~descr:(Md.plain "Global stmt order")
      (module Jint) in
  Request.register_sig ~package getStmtInfo
    ~kind:`GET ~name:"getStmtInfo"
    ~descr:(Md.plain "Stmt Information")
    begin fun rq s ->
      set_fct rq (Kernel_function.find_englobing_kf s) ;
      set_rank rq (Ranking.stmt s) ;
    end

(* -------------------------------------------------------------------------- *)
(* --- Request getProbeInfo                                               --- *)
(* -------------------------------------------------------------------------- *)

let () =
  let getProbeInfo = Request.signature ~input:(module Jmarker) () in
  let set_code = Request.result_opt getProbeInfo
      ~name:"code" ~descr:(Md.plain "Probe source code")
      (module Jstring) in
  let set_stmt = Request.result_opt getProbeInfo
      ~name:"stmt" ~descr:(Md.plain "Probe statement")
      (module Jstmt) in
  let set_rank = Request.result getProbeInfo
      ~name:"rank" ~descr:(Md.plain "Probe statement rank")
      ~default:0 (module Jint) in
  let set_effects = Request.result getProbeInfo
      ~name:"effects" ~descr:(Md.plain "Effectfull statement")
      ~default:false (module Jbool) in
  let set_condition = Request.result getProbeInfo
      ~name:"condition" ~descr:(Md.plain "Conditional statement")
      ~default:false (module Jbool) in
  let set_probe rq pp p s =
    begin
      set_code rq (Some (Pretty_utils.to_string pp p)) ;
      set_stmt rq (Some s) ;
      set_rank rq (Ranking.stmt s) ;
      List.iter
        (function
          | `Here -> ()
          | `Then _ | `Else _ -> set_condition rq true
          | `After -> set_effects rq true
        )
        (next_steps s)
    end
  in Request.register_sig ~package ~kind:`GET getProbeInfo
    ~name:"getProbeInfo" ~descr:(Md.plain "Probe informations")
    begin fun rq marker ->
      match probe marker with
      | Plval(l,s) ->
        set_probe rq Printer.pp_lval l s ;
      | Pexpr(e,s) ->
        set_probe rq Printer.pp_exp e s ;
      | Pnone -> ()
    end

(* -------------------------------------------------------------------------- *)
(* --- Request getValues                                                  --- *)
(* -------------------------------------------------------------------------- *)

let () =
  let getValues = Request.signature () in
  let get_tgt = Request.param getValues ~name:"target"
      ~descr:(Md.plain "Works with all markers containing an expression")
      (module Jmarker) in
  let get_cs = Request.param_opt getValues ~name:"callstack"
      ~descr:(Md.plain "Callstack to collect (defaults to none)")
      (module Jcallstack) in
  let set_alarms = Request.result getValues ~name:"alarms"
      ~descr:(Md.plain "Alarms raised during evaluation")
      (module Jlist(Jpair(Jtruth)(Jstring))) in
  let set_domain = Request.result_opt getValues ~name:"values"
      ~descr:(Md.plain "Domain values")
      (module Jstring) in
  let set_after = Request.result_opt getValues ~name:"v_after"
      ~descr:(Md.plain "Domain values after execution")
      (module Jstring) in
  let set_then = Request.result_opt getValues ~name:"v_then"
      ~descr:(Md.plain "Domain values for true condition")
      (module Jstring) in
  let set_else = Request.result_opt getValues ~name:"v_else"
      ~descr:(Md.plain "Domain values for false condition")
      (module Jstring) in
  Request.register_sig ~package getValues
    ~kind:`GET ~name:"getValues"
    ~descr:(Md.plain "Abstract values for the given marker")
    begin fun rq () ->
      let marker = get_tgt rq in
      let callstack = get_cs rq in
      let domain =
        let module A : EvaProxy = (val !proxy) in
        A.domain (probe marker) callstack in
      set_alarms rq domain.alarms ;
      List.iter
        (fun (step,values) ->
           let domain = Some values in
           match step with
           | `Here -> set_domain rq domain
           | `After -> set_after rq domain
           | `Then _ -> set_then rq domain
           | `Else _ -> set_else rq domain
        ) domain.values ;
    end


(* -------------------------------------------------------------------------- *)
