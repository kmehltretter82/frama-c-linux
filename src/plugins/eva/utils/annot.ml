(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2023                                               *)
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

(* -------------------------------------------------------------------------- *)
(* --- Annotation Generator                                               --- *)
(* -------------------------------------------------------------------------- *)

module Ltype = Cil_datatype.Logic_type_ByName
module Exp = Cil_builder.Exp
type visitor = Visitor.frama_c_visitor

type pred =
  | True
  | False
  | Pand of pred * pred
  | Por of pred * pred
  | Eval of Exp.exp
  | Pcall of string * Exp.exp list

let pand (a : pred) (b : pred) : pred =
  match a,b with
  | False,_ | _,False -> False
  | True,c | c,True -> c
  | _ -> Pand(a,b)

let por (a : pred) (b : pred) : pred =
  match a,b with
  | True,_ | _,True -> True
  | False,c | c,False -> c
  | _ -> Por(a,b)

let rec has_profile (vs : logic_var list) (ts : term list) =
  match vs, ts with
  | [],[] -> true
  | [],_ | _,[] -> false
  | lv::vs, t::ts ->
    Ltype.equal lv.lv_type t.term_type && has_profile vs ts

let matches_params (ts : term list) (fn : logic_info) =
  fn.l_labels = [] && has_profile fn.l_profile ts

let predicate ~loc ?(name=[]) (p : pred) : predicate =
  let rec aux = function
    | True -> Logic_const.ptrue
    | False -> Logic_const.pfalse
    | Pand(a,b) -> Logic_const.pand ~loc (aux a, aux b)
    | Por(a,b) -> Logic_const.por ~loc (aux a, aux b)
    | Eval e -> Exp.cil_pred ~loc e
    | Pcall(f,es) ->
      let ts = List.map (Exp.cil_term ~loc) es in
      let ls = Logic_env.find_all_logic_functions f in
      match List.find_opt (matches_params ts) ls with
      | None -> raise (Invalid_argument ("Eva.Annot." ^ f))
      | Some li -> Logic_const.papp ~loc (li,[],ts)
  in { (aux p) with pred_name = name }

let error (err : Results.error) : pred =
  match err with
  | Top | DisabledDomain -> True
  | Bottom -> False

(* -------------------------------------------------------------------------- *)
(* --- Ivalues                                                            --- *)
(* -------------------------------------------------------------------------- *)

let iequal (exp : Exp.exp) (k : Z.t) : pred =
  Eval Exp.( exp == of_integer k )

let imin (exp : Exp.exp) (ival : Ival.t) : pred =
  match Ival.min_int ival with
  | None -> True
  | Some k -> Eval Exp.( of_integer k <= exp )

let imax (exp : Exp.exp) (ival : Ival.t) : pred =
  match Ival.max_int ival with
  | None -> True
  | Some k -> Eval Exp.( exp <= of_integer k )

let sparse = function
  | [] -> false
  | [_] -> true
  | x::xs ->
    let rec continuous x = function
      | [] -> true
      | y::ys -> Z.equal (Z.succ x) y && continuous y ys
    in not @@ continuous x xs

let ival (exp : Exp.exp) (ival : Ival.t) : pred =
  match Ival.project_small_set ival with
  | Some vs when sparse vs ->
    List.fold_left (fun w v -> por w (iequal exp v)) False vs
  | _ -> pand (imin exp ival) (imax exp ival)

(* -------------------------------------------------------------------------- *)
(* --- Fvalues                                                            --- *)
(* -------------------------------------------------------------------------- *)

let fNaN (exp : Exp.exp) (isNaN : bool) : pred =
  if isNaN then Pcall("\\is_NaN",[exp]) else False

let fmin ~kind (exp : Exp.exp) (a : Fval.F.t) : pred =
  if Fval.F.is_finite a then
    Eval Exp.( of_cfloat ~kind (Fval.F.to_float a) <= exp )
  else True

let fmax ~kind (exp : Exp.exp) (b : Fval.F.t) : pred =
  if Fval.F.is_finite b then
    Eval Exp.( exp <= of_cfloat ~kind (Fval.F.to_float b) )
  else True

let frange ~kind (exp : Exp.exp) = function
  | None -> True
  | Some(a,b) -> pand (fmin ~kind exp a) (fmax ~kind exp b)

let fval ~kind (exp : Exp.exp) (fval : Fval.t) : pred =
  let range,isNaN = Fval.min_and_max fval in
  por (fNaN exp isNaN) (frange ~kind exp range)

let fkind (typ : typ) =
  match typ with
  | TFloat(kind,_) -> kind
  | _ -> assert false

(* -------------------------------------------------------------------------- *)
(* --- Values                                                             --- *)
(* -------------------------------------------------------------------------- *)

type value = Results.value Results.evaluation

let value (exp : Exp.exp) typ (value : value) : pred =
  if Cil.isIntegralType typ then
    match Results.as_ival value with
    | Ok v -> ival exp v
    | Error err -> error err
  else
  if Cil.isFloatingType typ then
    match Results.as_fval value with
    | Ok v -> fval ~kind:(fkind typ) exp v
    | Error err -> error err
  else True

(* -------------------------------------------------------------------------- *)
(* --- Evalutation                                                        --- *)
(* -------------------------------------------------------------------------- *)

let eval_value ~loc ?name lv request =
  Results.eval_lval lv request
  |> value (Exp.of_lval lv) (Cil.typeOfLval lv)
  |> predicate ?name ~loc

(* -------------------------------------------------------------------------- *)
(* --- Instructions                                                       --- *)
(* -------------------------------------------------------------------------- *)

module Slv = Cil_datatype.LvalStructEq.Set

class evaluator request =
  object(self)
    inherit Visitor.frama_c_inplace

    val mutable locked = Slv.empty
    val mutable domain : pred list = []

    method add p = if p <> True then domain <- p::domain
    method flush = List.rev domain

    method !vlval lv =
      if not @@ Slv.mem lv locked then
        begin
          locked <- Slv.add lv locked ;
          self#add @@ value (Exp.of_lval lv) (Cil.typeOfLval lv) @@
          Results.eval_lval lv request ;
          Cil.DoChildren
        end
      else Cil.SkipChildren

    method !vterm_lval lv =
      try
        let _ = self#vlval @@ Logic_to_c.term_lval_to_lval lv in
        DoChildren
      with Logic_to_c.No_conversion ->
        DoChildren

    method private visit_expr e =
      ignore @@ Visitor.visitFramacExpr (self :> visitor) e

    method private visit_offset ofs =
      ignore @@ Visitor.visitFramacOffset (self :> visitor) ofs

    method private visit_host = function
      | Var _ -> ()
      | Mem e -> self#visit_expr e

    method private visit_lset lv =
      begin
        self#visit_host (fst lv) ;
        self#visit_offset (snd lv) ;
      end

    method !vinst = function
      | Set(lv,exp,_) ->
        self#visit_lset lv ;
        self#visit_expr exp ;
        SkipChildren
      | Call(lr,_,es,_) ->
        Option.iter self#visit_lset lr ;
        List.iter self#visit_expr es ;
        SkipChildren
      | Local_init _ | Asm _ | Skip _ | Code_annot _ ->
        DoChildren

    method !vstmt_aux stmt =
      match stmt.skind with
      (* Instructions *)
      | Instr _ | Return _ -> DoChildren
      (* Branching expressions *)
      | If(e,_,_,_) | Switch(e,_,_,_) -> self#visit_expr e ; SkipChildren
      (* Blocks & Jumps *)
      | Goto _ | Break _ | Continue _
      | Loop _ | Block _ | UnspecifiedSequence _
      | Throw _ | TryCatch _ | TryFinally _ | TryExcept _
        -> SkipChildren

  end

let eval_instr ?callstack ?name stmt =
  let request =
    let r = Results.before stmt in
    match callstack with
    | None -> r
    | Some c -> Results.in_callstack c r in
  let engine = new evaluator request in
  let _ = Visitor.visitFramacStmt (engine :> visitor) stmt in
  List.map (predicate ?name ~loc:(Cil_datatype.Stmt.loc stmt)) engine#flush

(* -------------------------------------------------------------------------- *)
(* --- Annotation Generator                                               --- *)
(* -------------------------------------------------------------------------- *)

let generated = Emitter.create "Eva_domain"
    [ Emitter.Code_annot ]
    ~correctness:[]
    ~tuning:[]

class generator =
  object(self)
    inherit Visitor.frama_c_inplace

    method! vlval _ = SkipChildren
    method! vexpr _ = SkipChildren

    method !vstmt_aux stmt =
      match self#current_kf with
      | None -> Cil.SkipChildren
      | Some kf ->
        List.iter
          (Annotations.add_assert generated ~kf stmt)
          (eval_instr stmt) ;
        Annotations.iter_code_annot
          (fun e ca ->
             if Emitter.equal e generated then
               List.iter
                 (fun ip ->
                    Property_status.emit Analysis.emitter ~hyps:[] ip True
                 ) (Property.ip_of_code_annot kf stmt ca)
          ) stmt ;
        DoChildren

  end

let generator () = (new generator :> visitor)

(* -------------------------------------------------------------------------- *)
(* --- Annotation Removal                                                 --- *)
(* -------------------------------------------------------------------------- *)

class cleaner =
  object(self)
    inherit Visitor.frama_c_inplace

    method! vlval _ = SkipChildren
    method! vexpr _ = SkipChildren

    method !vstmt_aux stmt =
      match self#current_kf with
      | None -> Cil.SkipChildren
      | Some kf ->
        Annotations.iter_code_annot
          (fun e ca ->
             if Emitter.equal e generated then
               Annotations.remove_code_annot e ~kf stmt ca
          ) stmt ;
        DoChildren

  end

let cleaner () = (new cleaner :> visitor)

(* -------------------------------------------------------------------------- *)
(* --- Command Line Option                                                --- *)
(* -------------------------------------------------------------------------- *)

let main () =
  if Analysis.is_computed () then
    let ast = Ast.get () in
    let cleaner = cleaner () in
    Self.feedback ~ontty:`Transient "Cleaning annotations..." ;
    Visitor.visitFramacFile cleaner ast ;
    let generator = new generator in
    Parameters.Annot.iter
      begin fun kf ->
        if Kernel_function.has_definition kf then
          if Results.are_available kf then
            let fundec = Kernel_function.get_definition kf in
            Self.feedback "Annotate %a" Kernel_function.pretty kf ;
            ignore @@ Visitor.visitFramacFunction generator fundec
          else
            Self.warning "Can not annotate %a (no available results)"
              Kernel_function.pretty kf
        else
          Self.warning "Can not annotate %a (no definition)"
            Kernel_function.pretty kf
      end

let () = Boot.Main.extend main

(* -------------------------------------------------------------------------- *)
