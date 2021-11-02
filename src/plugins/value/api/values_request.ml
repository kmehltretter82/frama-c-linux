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

open Server
open Data
open Cil_types



module Kmap = Kernel_function.Hashtbl
module Smap = Cil_datatype.Stmt.Hashtbl
module CS = Value_types.Callstack
module CSet = CS.Set
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

let () = Analysis.register_computation_hook ~on:Computed
    (fun _ -> Request.emit signal)

let handle_top_or_bottom ~top ~bottom compute = function
  | `Bottom -> bottom
  | `Top -> top
  | `Value v -> compute v



(* -------------------------------------------------------------------------- *)
(* --- Marker Utilities                                                   --- *)
(* -------------------------------------------------------------------------- *)

let next_steps s : step list =
  match s.skind with
  | If (cond, _, _, _) -> [ `Then cond ; `Else cond ]
  | Instr (Set _ | Call _ | Local_init _ | Asm _ | Code_annot _) -> [ `After ]
  | Switch _ | Loop _ | Block _ | UnspecifiedSequence _ -> [ `After ]
  | TryCatch _ | TryFinally _ | TryExcept _ -> [ `After ]
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

module type Ranking_sig = sig
  val stmt : stmt -> int
  val sort : callstack list -> callstack list
end

module Ranking : Ranking_sig = struct

  class ranker = object(self)
    inherit Visitor.frama_c_inplace
    (* ranks really starts at 1 *)
    (* rank < 0 means not computed yet *)
    val mutable rank = (-1)
    val rmap = Smap.create 0
    val fmark = Kmap.create 0
    val fqueue = Queue.create ()

    method private call kf =
      if not (Kmap.mem fmark kf) then
        ( Kmap.add fmark kf () ; Queue.push kf fqueue )

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

module Jcallstack : S with type t = callstack = struct
  module I = Data.Index
      (Value_types.Callstack.Map)
      (struct let name = "eva-callstack-id" end)
  let jtype = Data.declare ~package ~name:"callstack" I.jtype
  type t = I.t
  let to_json = I.to_json
  let of_json = I.of_json
end

module Jcalls : Request.Output with type t = callstack = struct

  type t = callstack

  let jtype = Package.(Jlist (Jrecord [
      "callee" , Jkf.jtype ;
      "caller" , Joption Jkf.jtype ;
      "stmt" , Joption Jstmt.jtype ;
      "rank" , Joption Jnumber ;
    ]))

  let rec jcallstack jcallee ki cs : json list =
    match ki , cs with
    | Kglobal , _ | _ , [] -> [ `Assoc [ "callee", jcallee ] ]
    | Kstmt stmt , (called,ki) :: cs ->
      let jcaller = Jkf.to_json called in
      let callsite = `Assoc [
          "callee", jcallee ;
          "caller", jcaller ;
          "stmt", Jstmt.to_json stmt ;
          "rank", Jint.to_json (Ranking.stmt stmt) ;
        ]
      in callsite :: jcallstack jcaller ki cs

  let to_json = function
    | [] -> `List []
    | (callee,ki)::cs -> `List (jcallstack (Jkf.to_json callee) ki cs)

end

module Jtruth : Data.S with type t = truth = struct
  type t = truth
  let jtype = Package.(Junion [ Jtag "True" ; Jtag "False" ; Jtag "Unknown" ])
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

module type EvaProxy = sig
  val callstacks : stmt -> callstack list
  val domain : probe -> callstack option -> domain
  val pointed_lvalues : probe -> callstack option -> lval list option
end

module Proxy(A : Analysis.S) : EvaProxy = struct

  open Eval
  type dstate = A.Dom.state or_top_or_bottom

  let dnone = { alarms = [] ; values = [] }
  let dtop = { alarms = [] ; values = [`Here , "Not available."] }
  let dbottom = { alarms = [] ; values = [`Here , "Unreachable."] }

  let callstacks stmt =
    match A.get_stmt_state_by_callstack ~after:false stmt with
    | `Top | `Bottom -> []
    | `Value states -> CSmap.fold_sorted (fun cs _ wcs -> cs :: wcs) states []

  let dstate ~after stmt = function
    | None -> (A.get_stmt_state ~after stmt :> dstate)
    | Some cs ->
      match A.get_stmt_state_by_callstack ~after stmt with
      | (`Top | `Bottom) as res -> res
      | `Value cmap -> try `Value (CSmap.find cmap cs) with Not_found -> `Bottom

  let eval_lval lval state =
    let value, alarms = A.copy_lvalue state lval in
    let default = Eval.Flagged_Value.bottom in
    (Bottom.default ~default value).v, alarms

  let eval_expr expr state = A.eval_expr state expr

  let dalarms alarms =
    let descr = Format.asprintf "@[<hov 2>%a@]" Alarms.pretty in
    let f alarm status pool = (status, descr alarm) :: pool in
    Alarmset.fold f [] alarms |> List.rev

  let fold_steps f stmt callstack state acc =
    let steps = `Here :: next_steps stmt in
    let add_state = function
      | `Here -> `Value state
      | `After -> dstate ~after:true stmt callstack
      | `Then cond -> (A.assume_cond stmt state cond true :> dstate)
      | `Else cond -> (A.assume_cond stmt state cond false :> dstate)
    in List.fold_left (fun acc step -> f acc step @@ add_state step) acc steps

  let domain_step eval ((values, alarms) as acc) step =
    let to_string = Pretty_utils.to_string (Bottom.pretty A.Val.pretty) in
    handle_top_or_bottom ~top:acc ~bottom:acc @@ fun state ->
      let step_value, step_alarms = eval state in
      let alarms = match step with `Here -> step_alarms | _ -> alarms in
      (step, to_string step_value) :: values, alarms

  let domain_eval eval stmt callstack =
    let fold = fold_steps (domain_step eval) stmt callstack in
    let build (vs, als) = { values = List.rev vs ; alarms = dalarms als } in
    let compute_domain state = fold state ([], Alarmset.none) |> build in
    handle_top_or_bottom ~top:dtop ~bottom:dbottom compute_domain @@
    dstate ~after:false stmt callstack

  let domain p callstack =
    match p with
    | Plval (lval, stmt) -> domain_eval (eval_lval lval) stmt callstack
    | Pexpr (expr, stmt) -> domain_eval (eval_expr expr) stmt callstack
    | Pnone -> dnone

  let var_of_base base acc =
    let add vi acc = if Cil.isFunctionType vi.vtype then acc else vi :: acc in
    try add (Base.to_varinfo base) acc with Base.Not_a_C_variable -> acc

  let compute_pointed_lvalues eval_lval stmt callstack =
    Option.(bind (A.Val.get Main_values.CVal.key)) @@ fun get ->
      let loc state = eval_lval state |> fst >>-: get in
      let bases value = Cvalue.V.fold_bases var_of_base value [] in
      let lvalues state = loc state >>-: bases >>-: List.map Cil.var in
      let compute state = lvalues state |> Bottom.to_option in
      handle_top_or_bottom ~top:None ~bottom:None compute @@
      dstate ~after:true stmt callstack

  let pointed_lvalues p callstack =
    match p with
    | Plval (l, stmt) -> compute_pointed_lvalues (eval_lval l) stmt callstack
    | Pexpr (e, stmt) -> compute_pointed_lvalues (eval_expr e) stmt callstack
    | Pnone -> None

end

let proxy =
  let make (a : (module Analysis.S)) = (module Proxy(val a) : EvaProxy) in
  let current = ref (make @@ Analysis.current_analyzer ()) in
  let hook a = current := make a ; Request.emit signal in
  Analysis.register_hook hook ; current



(* -------------------------------------------------------------------------- *)
(* --- Request getCallstacks                                              --- *)
(* -------------------------------------------------------------------------- *)

let () = Request.register ~package
    ~kind:`GET ~name:"getCallstacks"
    ~descr:(Md.plain "Callstacks for markers")
    ~input:(module Jlist(Jmarker))
    ~output:(module Jlist(Jcallstack))
    begin fun markers ->
      let module A = (val !proxy) in
      let cset = List.fold_left
          (fun cset marker ->
             match probe marker with
             | Pexpr(_,stmt) | Plval(_,stmt) ->
               List.fold_right CSet.add (A.callstacks stmt) cset
             | Pnone -> cset
          ) CSet.empty markers in
      Ranking.sort (CSet.elements cset)
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
        (fun (step, values) ->
           let domain = Some values in
           match step with
           | `Here -> set_domain rq domain
           | `After -> set_after rq domain
           | `Then _ -> set_then rq domain
           | `Else _ -> set_else rq domain
        ) domain.values ;
    end



(* -------------------------------------------------------------------------- *)
(* --- Request getPointedLvalues                                          --- *)
(* -------------------------------------------------------------------------- *)

let () =
  let getPointedLvalues = Request.signature () in
  (* Inputs of the request *)
  let get_tgt = Request.param getPointedLvalues ~name:"pointer"
    ~descr:(Md.plain "")
    (module Jmarker)
  and get_cs = Request.param_opt getPointedLvalues ~name:"callstack"
    ~descr:(Md.plain "Callstack to collect (defaults to none)")
    (module Jcallstack)
  in
  (* Outputs of the request *)
  let set_lvalues = Request.result_opt getPointedLvalues ~name:"lvalues"
    ~descr:(Md.plain "")
    (module Jlist(Jpair(Jstring)(Jmarker)))
  in
  (* Register and request computation *)
  Request.register_sig ~package getPointedLvalues
    ~kind:`GET ~name:"getPointedLvalues"
    ~descr:(Md.plain "")
    begin fun rq () ->
      let module A : EvaProxy = (val !proxy) in
      let marker = get_tgt rq and callstack = get_cs rq in
      let kf = Printer_tag.kf_of_localizable marker in
      let ki = Printer_tag.ki_of_localizable marker in
      let pp = Pretty_utils.to_string Printer.pp_lval in
      let to_marker lval = pp lval, Printer_tag.PLval (kf, ki, lval) in
      let lvalues = A.pointed_lvalues (probe marker) callstack in
      Option.map (List.map to_marker) lvalues |> set_lvalues rq
    end

(* -------------------------------------------------------------------------- *)

