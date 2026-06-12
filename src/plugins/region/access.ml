(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

open Cil_types
open Cil_datatype

type clause =
  | Body of Logic_info.t
  | Prop of Property.t
  | CallSite of Stmt.t * Kernel_function.t
  | CallProp of Stmt.t * Kernel_function.t * Property.t
[@@ deriving ord]

type acs =
  | Exp of Stmt.t * Exp.t
  | Ret of Stmt.t * Exp.t
  | Lval of Stmt.t * Lval.t
  | Init of Stmt.t * Lval.t * Exp.t
  | Term of clause * Term_lval.t
[@@ deriving ord]

module Set = Set.Make(struct type t = acs let compare = compare_acs end)

let pp_label fmt (s : stmt) =
  match s.labels with
  | Label(l,_,_)::_ -> Format.pp_print_string fmt l
  | _ ->
    let line = Stmt.loc s |> Fileloc.line in
    Format.fprintf fmt "L%d" line

let pp_clause fmt = function
  | Body l -> Format.pp_print_string fmt "logic:" ; Logic_info.pretty fmt l
  | Prop p -> Format.pp_print_string fmt @@ Property.Names.get_prop_name_id p
  | CallSite(st,kf) ->
    Format.fprintf fmt "%a@%a"
      Kernel_function.pretty kf pp_label st
  | CallProp(st,kf,prop) ->
    Format.fprintf fmt "%a@%a@%s"
      Kernel_function.pretty kf pp_label st
      (Property.Names.get_prop_name_id prop)

let pretty fmt = function
  | Init(s,l,v) ->
    Format.fprintf fmt "(%a=%a)@%a" Lval.pretty l Exp.pretty v pp_label s
  | Lval(s,l) ->
    Format.fprintf fmt "%a@%a" Lval.pretty l pp_label s
  | Exp(s,e) ->
    Format.fprintf fmt "(%a)@%a" Exp.pretty e pp_label s
  | Ret(s,e) ->
    Format.fprintf fmt "(return %a)@%a" Exp.pretty e pp_label s
  | Term(c,l) ->
    Format.fprintf fmt "(%a)@%a" Term_lval.pretty l pp_clause c

let pp_access fmt = function
  | Exp(_,e) -> Printer.pp_exp fmt e
  | Ret(_,e) -> Format.fprintf fmt "return %a" Printer.pp_exp e
  | Lval(_,l) -> Printer.pp_lval fmt l
  | Init(_,l,v) ->
    Format.fprintf fmt "init %a=%a" Printer.pp_lval l Printer.pp_exp v
  | Term(Prop _,t) -> Printer.pp_term_lval fmt t
  | Term(Body fn,t) ->
    Format.fprintf fmt "%a { %a }" Logic_info.pretty fn Printer.pp_term_lval t
  | Term((CallProp(_,kf,_) | CallSite(_,kf)),t) ->
    Format.fprintf fmt "%a { %a }" Kernel_function.pretty kf Printer.pp_term_lval t

let pp_line fmt stmt =
  let line = Stmt.loc stmt |> Fileloc.line in
  List.iter (Format.fprintf fmt "%a " Printer.pp_label) stmt.labels ;
  Format.fprintf fmt "s%d, line %d" stmt.sid line

let pp_source fmt = function
  | Init(stmt,_,_) | Ret(stmt,_) | Exp(stmt,_) | Lval(stmt,_) ->
    pp_line fmt stmt
  | Term(Prop ip,_) -> Description.pp_local fmt ip
  | Term(Body fn,_) ->
    if fn.l_type = None then
      Format.fprintf fmt "predicate %a" Logic_info.pretty fn
    else
      Format.fprintf fmt "logic %a" Logic_info.pretty fn
  | Term((CallProp(stmt,_,_)|CallSite(stmt,_)),_) ->
    Format.fprintf fmt "call at %a" pp_line stmt

let ctype_of = function
  | Ctype t -> t
  | _ -> Cil_const.voidType

let location = function
  | Body _ -> Options.gen_loc (* TODO *)
  | CallSite(s,_) -> Stmt.loc s
  | Prop ip | CallProp(_,_,ip) -> Property.location ip

let typeof = function
  | Init(_,lv,_) | Lval(_,lv) -> Cil.typeOfLval lv
  | Exp(_,e) | Ret(_,e) -> Cil.typeOf e
  | Term(_,lv) ->
    Ast_types.Acsl.plain_or_set ctype_of @@ Cil.typeOfTermLval lv

open Server.Printer_tag

let marker = function
  | Exp(stmt,e) | Ret(stmt,e) -> PExp(None,Kstmt stmt,e)
  | Init (stmt,(Var vi,_),_) -> PVDecl(None,Kstmt stmt,vi)
  | Init (stmt,(Mem e,_),_) -> PExp(None,Kstmt stmt,e)
  | Lval(stmt,_)
  | Term (CallSite (stmt, _), _)
  | Term (CallProp (stmt, _, _), _) ->
    PStmtStart(Kernel_function.find_englobing_kf stmt, stmt)
  | Term (Body fn, _) ->
    PGlobal(GAnnot(Dfun_or_pred(fn,Options.gen_loc),Options.gen_loc))
  | Term (Prop ip, _) -> PIP ip

let rank = function
  | Term (Body _, _) | Term(Prop _, _) -> 0
  | Exp(s,_) | Ret(s,_) | Init(s,_,_) | Lval(s,_)
  | Term(CallSite(s,_),_) | Term(CallProp(s,_,_),_) -> s.sid
