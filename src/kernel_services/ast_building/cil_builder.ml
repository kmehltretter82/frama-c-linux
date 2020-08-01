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


(* --- C & Logic expressions builder --- *)

module Exp =
struct
  (*
    This modules exportes polymorphic variant to simulate subtyping.
    It uses regular variant internally though, instead of using only the
    polymorphic variant, as
    1. it simplifies greatly the .mli since most of the types don't have
       to be exposed ; it also greatly simplifies mistyping errors for the user
    2. recursive polymorphic variant do not allow inclusion of one into another
    3. it is much easier to type the program with regular variants
  *)

  type const' =
    | Int of Integer.t
    | CilConstant of Cil_types.constant
  and var' =
    Cil_types.varinfo
  and lval' =
    | CilLval of Cil_types.lval
    | Var of var'
    | Result
    | Mem of exp'
    | Field of lval' * Cil_types.fieldinfo
    | FieldNamed of lval' * string
  and exp' =
    | CilExp of Cil_types.exp
    | CilExpCopy of Cil_types.exp
    | CilTerm of Cil_types.term
    | Lval of lval'
    | Const of const'
    | Range of exp' option * exp' option
    | Unop of Cil_types.unop * exp'
    | Binop of Cil_types.binop * exp' * exp'

  type const = [ `const of const' ]
  type var = [ `var of var' ]
  type lval = [  var | `lval of lval' ]
  type exp = [ const | lval | `exp of exp' ]

  (* Depolymorphize *)

  let harden_const c =
    match (c :> const) with
    | `const const -> const

  let harden_var v =
    match (v :> var) with
    | `var var -> var

  let harden_lval lv =
    match (lv :> lval) with
    | #var as var -> Var (harden_var var)
    | `lval lval -> lval

  let harden_lval_opt = function
    | `none -> None
    | #lval as lval -> Some (harden_lval lval)

  let harden_exp e =
    match (e :> exp) with
    | #const as const -> Const (harden_const const)
    | #lval as lval -> Lval (harden_lval lval)
    | `exp exp -> exp

  let harden_exp_opt = function
    | `none -> None
    | #exp as exp -> Some (harden_exp exp)

  let harden_exp_list l =
    List.map harden_exp l

  (* Build *)

  let constant c = `const (CilConstant c)
  let integer i = `const (Int i)
  let int i = `const (Int (Integer.of_int i))
  let zero = int 0
  let one = int 1
  let var v = `var v
  let lval lv = `lval (CilLval lv)
  let exp e = `exp (CilExp e)
  let exp_copy e = `exp (CilExpCopy e)
  let unop op e = `exp (Unop (op, harden_exp e))
  let neg e = unop Cil_types.Neg e
  let lognot e = unop Cil_types.LNot e
  let bwnot e = unop Cil_types.BNot e
  let binop op e1 e2 = `exp (Binop (op, harden_exp e1, harden_exp e2))
  let add e1 e2 = binop Cil_types.PlusA e1 e2
  let sub e1 e2 = binop Cil_types.MinusA e1 e2
  let mul e1 e2 = binop Cil_types.Mult e1 e2
  let div e1 e2 = binop Cil_types.Div e1 e2
  let modulo e1 e2 = binop Cil_types.Mod e1 e2
  let shiftl e1 e2 = binop Cil_types.Shiftlt e1 e2
  let shiftr e1 e2 = binop Cil_types.Shiftrt e1 e2
  let lt e1 e2 = binop Cil_types.Lt e1 e2
  let gt e1 e2 = binop Cil_types.Gt e1 e2
  let le e1 e2 = binop Cil_types.Le e1 e2
  let ge e1 e2 = binop Cil_types.Ge e1 e2
  let eq e1 e2 = binop Cil_types.Eq e1 e2
  let ne e1 e2 = binop Cil_types.Ne e1 e2
  let bwand e1 e2 = binop Cil_types.BAnd e1 e2
  let bwor e1 e2 = binop Cil_types.BOr e1 e2
  let bwxor e1 e2 = binop Cil_types.BXor e1 e2
  let logand e1 e2 = binop Cil_types.LAnd e1 e2
  let logor e1 e2 = binop Cil_types.LOr e1 e2
  let mem e = `lval (Mem (harden_exp e))
  let field lv fi = `lval (Field (harden_lval lv, fi))
  let fieldnamed lv s = `lval (FieldNamed (harden_lval lv, s))
  let result = `lval Result
  let term t = `exp (CilTerm t)
  let none = `none
  let range e1 e2 = `exp (Range (harden_exp_opt e1, harden_exp_opt e2))

  exception EmptyList

  let reduce f l =
    match (l :> exp list) with
    | [] -> raise EmptyList
    | h :: t -> List.fold_left f h t

  let logand_list l = reduce logand l
  let logor_list l = reduce logor l

  let (+), (-), ( * ), (/), (%) = add, sub, mul, div, modulo
  let (<<), (>>) = shiftl, shiftr
  let (<), (>), (<=), (>=), (==), (!=) = lt, gt, le, ge, eq, ne

  (* Convert *)

  exception LogicInC
  exception CInLogic
  exception Typing_error of string

  let get_fieldinfo typ fieldname =
    match Cil.unrollType typ with
    | Cil_types.TComp (compinfo,_,_) ->
      begin try
          Cil.getCompField compinfo fieldname
        with Not_found ->
          let cname = compinfo.Cil_types.cname in
          raise (Typing_error ("no field " ^ fieldname ^ " in " ^ cname))
      end
    | _ ->
      raise (Typing_error ("trying to get a field of a non-composite type"))

  let get_fieldinfo_from_ltype ltyp fieldname =
    match Logic_utils.unroll_type ltyp with
    | Cil_types.Ctype typ ->
      get_fieldinfo typ fieldname
    | _ ->
      raise (Typing_error ("trying to get a field of a logic type"))

  let rec build_constant = function
    | CilConstant const -> const
    | Int i -> Cil_types.(CInt64 (i, IInt, None))

  and build_lval ~loc = function
    | CilLval lval -> lval
    | Var v -> Cil_types.(Var v, NoOffset)
    | Result -> raise LogicInC
    | Mem e ->
      Cil.mkMem ~addr:(build_exp ~loc e) ~off:Cil_types.NoOffset
    | Field (lv,f) ->
      let host, offset = build_lval ~loc lv in
      let offset' = Cil.addOffset Cil_types.(Field (f, NoOffset)) in
      host, offset' offset
    | FieldNamed (lv,s) ->
      let (host, offset) as lval = build_lval ~loc lv in
      let ty = Cil.typeOfLval lval in
      let f = get_fieldinfo ty s in
      let offset' = Cil_types.(Field (f, NoOffset)) in
      host, Cil.addOffset offset' offset

  and build_exp ~loc = function
    | CilTerm _ | Range _ -> raise LogicInC
    | CilExp exp -> exp
    | CilExpCopy exp -> Cil.copy_exp exp
    | Const c->
      Cil.new_exp ~loc (Cil_types.Const (build_constant c))
    | Lval lval ->
      Cil.new_exp ~loc (Cil_types.Lval (build_lval ~loc lval))
    | Unop (op,e) ->
      let e' = build_exp ~loc e in
      let t = Cil.typeOf e' in
      let t' = Cil.integralPromotion t in
      Cil.(new_exp ~loc (Cil_types.UnOp (op, mkCastT e' t t', t')))
    | Binop (op,e1,e2) ->
      let e1' = build_exp ~loc e1
      and e2' = build_exp ~loc e2 in
      Cil.mkBinOp ~loc op e1' e2'

  let rec build_term_lval ~loc ~restyp = function
    | CilLval _ -> raise CInLogic
    | Var v -> Cil_types.(TVar (Cil.cvar_to_lvar v), TNoOffset)
    | Mem e -> Cil_types.(TMem (build_term ~loc ~restyp e), TNoOffset)
    | Result -> Cil_types.(TResult restyp, TNoOffset)
    | Field (lv,f) ->
      let host, offset = build_term_lval ~loc ~restyp lv in
      let offset' = Cil_types.(TField (f, TNoOffset)) in
      host, Logic_const.addTermOffset offset' offset
    | FieldNamed (lv,s) ->
      let (host, offset) as tlval = build_term_lval ~loc ~restyp lv in
      let ty = Cil.typeOfTermLval tlval in
      let f = get_fieldinfo_from_ltype ty s in
      let offset' = Cil_types.(TField (f, TNoOffset)) in
      host, Logic_const.addTermOffset offset' offset

  and build_term ~loc ~restyp = function
    | Const (CilConstant _) | CilExp _ | CilExpCopy _ -> raise CInLogic
    | CilTerm term -> term
    | Const (Int i) ->
      Logic_const.tint ~loc i
    | Lval lval ->
      let tlval = build_term_lval ~loc ~restyp lval in
      Logic_const.term ~loc Cil_types.(TLval tlval) (Cil.typeOfTermLval tlval)
    | Unop (op,e) ->
      let t = build_term e ~loc ~restyp in
      let ty = t.Cil_types.term_type in
      (* TODO: type conversion *)
      Logic_const.term ~loc Cil_types.(TUnOp (op,t)) ty
    | Binop (op,t1,t2) ->
      let t1 = build_term ~loc ~restyp t1
      and t2 = build_term ~loc ~restyp t2 in
      let ty = t1.Cil_types.term_type in
      (* TODO: type conversion *)
      Logic_const.term ~loc Cil_types.(TBinOp (op,t1,t2)) ty
    | Range (t1,t2) ->
      let t1' = Extlib.opt_map (build_term ~loc ~restyp) t1
      and t2' = Extlib.opt_map (build_term ~loc ~restyp) t2 in
      Logic_const.trange ~loc (t1',t2')

  (* Export *)

  let cil_varinfo v = harden_var v
  let cil_constant c = build_constant (harden_const c)
  let cil_lval ~loc lv = build_lval ~loc (harden_lval lv)
  let cil_lval_opt ~loc lv =
    Extlib.opt_map (build_lval ~loc) (harden_lval_opt lv)
  let cil_exp ~loc e = build_exp ~loc (harden_exp e)
  let cil_exp_opt ~loc e = Extlib.opt_map (build_exp ~loc) (harden_exp_opt e)
  let cil_exp_list ~loc l = List.map (cil_exp ~loc) l
  let cil_term_lval ~loc ~restyp lv =
    build_term_lval ~loc ~restyp (harden_lval lv)
  let cil_term ~loc ~restyp e = build_term ~loc ~restyp (harden_exp e)
end


(* --- Pure builder --- *)

module Pure =
struct
  include Exp

  type instr' =
    | CilInstr of Cil_types.instr
    | Skip
    | Assign of lval' * exp'
    | Call of lval' option * exp' * exp' list

  type stmt' =
    | CilStmt of Cil_types.stmt
    | CilStmtkind of Cil_types.stmtkind
    | Instr of instr'
    | Sequence of stmt' list
    | Ghost of stmt'

  type instr = [ `instr of instr' ]
  type stmt = [ instr | `stmt of stmt' ]

  (* Sequences *)

  let flatten_sequences l =
    let rec add_one acc = function
      | Sequence l -> add_list acc l
      | stmt -> stmt :: acc
    and add_list acc l =
      List.fold_left add_one acc l
    in
    List.rev (add_list [] l)

  (* Depolymorphize *)

  let harden_instr i =
    match (i :> instr) with
    | `instr instr -> instr

  let harden_stmt s =
    match (s :> stmt) with
    | #instr as instr -> Instr (harden_instr instr)
    | `stmt stmt -> stmt

  (* Build *)

  let instr i = `instr (CilInstr i)
  let skip = `instr Skip
  let assign dest src = `instr (Assign (harden_lval dest, harden_exp src))
  let incr dest = `instr (Assign (harden_lval dest, harden_exp (add dest one)))
  let call res callee args =
    `instr (Call (harden_lval_opt res, harden_exp callee, harden_exp_list args))
  let stmtkind sk = `stmt (CilStmtkind sk)
  let stmt s = `stmt (CilStmt s)
  let stmts l = `stmt (Sequence (List.map (fun s -> CilStmt s) l))
  let block l = `stmt (Sequence (List.map harden_stmt l))
  let ghost s = `stmt (Ghost (harden_stmt s))
  

  (* Convert *)

  let build_instr ~loc = function
    | CilInstr i -> i
    | Skip ->
      Cil_types.Skip (loc)
    | Assign (dest,src) ->
      Cil_types.Set (build_lval ~loc dest, build_exp ~loc src, loc)
    | Call (dest,callee,args) ->
      let dest' = Extlib.opt_map (build_lval ~loc) dest
      and callee' = build_exp ~loc callee
      and args' = List.map (build_exp ~loc) args in
      Cil_types.Call (dest', callee', args', loc)

  let rec build_stmtkind ~loc ~ghost = function
    | CilStmt s -> s.Cil_types.skind
    | CilStmtkind sk -> sk
    | Instr i -> Cil_types.Instr (build_instr ~loc i)
    | Sequence l -> Cil_types.Block (build_block ~loc ~ghost l)
    | Ghost s -> Cil_types.Block (build_block ~loc ~ghost:true [s])

  and build_stmt ~loc ~ghost = function
    | CilStmt s -> s
    | Ghost s -> build_stmt ~loc ~ghost:true s
    | stmt -> Cil.mkStmt ~ghost (build_stmtkind ~loc ~ghost stmt)

  and build_block ~loc ~ghost l =
    let bstmts = List.map (build_stmt ~ghost ~loc) (flatten_sequences l) in
    Cil.mkBlock bstmts

  (* Export *)

  let cil_instr ~loc i = build_instr ~loc (harden_instr i)
  let cil_stmtkind ~loc s = build_stmtkind ~loc ~ghost:false (harden_stmt s)
  let cil_stmt ~loc s = build_stmt ~loc ~ghost:false (harden_stmt s)
end


(* --- Stateful builder --- *)

let dkey = Kernel.register_category "cil-builder"

exception WrongContext of string

module type T =
sig
  val loc : Cil_types.location
end

module Stateful (Location : T) =
struct
  include Exp

  type stmt =
    | Label of Cil_types.label
    | CilStmt of Cil_types.stmt
    | CilStmtkind of Cil_types.stmtkind
    | CilInstr of Cil_types.instr

  type scope =
    {
      scope_type: scope_type;
      ghost: bool;
      mutable stmts: stmt list; (* In reverse order *)
      mutable vars: Cil_types.varinfo list; (* In reverse order *)
    }
  and scope_type =
    | Block
    | IfThen of {ifthen_exp: Cil_types.exp}
    | IfThenElse of {ifthenelse_exp: Cil_types.exp; then_block: Cil_types.block}
    | Switch of {switch_exp: Cil_types.exp}
    | Function of {fundec: Cil_types.fundec}


  let loc = Location.loc

  (* State management *)

  let stack : scope list ref = ref []
  let owner: Cil_types.fundec option ref = ref None

  let pretty_stack fmt =
    let pretty_stack_type fmt b =
      match b.scope_type with
      | Block -> Format.pp_print_string fmt "block"
      | IfThen _ -> Format.pp_print_string fmt "if-then"
      | IfThenElse _ -> Format.pp_print_string fmt "if-then-else"
      | Switch _ -> Format.pp_print_string fmt "switch"
      | Function _ -> Format.pp_print_string fmt "function"
    in
    Pretty_utils.pp_list ~pre:"[@[" ~sep:";@," ~last:"@]]"
      pretty_stack_type fmt !stack

  let check_empty () =
    if !stack <> [] then
      raise (WrongContext "some contextes have not been closed")

  let check_not_empty () =
    if !stack = [] then
      raise (WrongContext "only a finish_* function can close all contextes")

  let top () =
    match !stack with
    | [] -> raise (WrongContext "not in an opened context")
    | state :: _ -> state

  let push state =
    let parent_ghost = match !stack with
      | [] -> false
      | s :: _ -> s.ghost
    in
    stack := { state  with ghost = parent_ghost || state.ghost } :: !stack;
    Kernel.debug ~dkey "push onto %t" pretty_stack

  let pop () =
    Kernel.debug ~dkey "pop from %t" pretty_stack;
    match !stack with
    | [] -> raise (WrongContext "not in an opened context")
    | hd :: tail ->
      stack := tail;
      hd

  let finish () =
    match !stack with
    | [] -> raise (WrongContext "not in an opened context")
    | [b] -> b
    | _ :: _ :: _ -> raise (WrongContext "all contextes have not been closed")

  let reset_owner () =
    owner := None

  let set_owner o =
    owner := Some o

  let get_owner () =
    match !owner with
    | None -> raise (WrongContext "not in an opened function")
    | Some fundec -> fundec

  let append_stmt b s =
    b.stmts <- s :: b.stmts

  (* Conversion to Cil *)

  let build_stmt_list ~ghost l =
    let rev_build_one acc = function
      | Label l ->
        begin match acc with
          | [] -> (* No generated statement to attach the label to *)
            let stmt = Cil.mkEmptyStmt ~ghost ~loc () in
            stmt.Cil_types.labels <- [l];
            stmt :: acc
          | stmt :: _ -> (* There is a statement to attach the label to *)
            stmt.Cil_types.labels <- l :: stmt.Cil_types.labels;
            acc
        end
      | CilStmt stmt ->
        stmt :: acc
      | CilStmtkind sk ->
        Cil.mkStmt ~ghost sk :: acc
      | CilInstr instr ->
        Cil.mkStmt ~ghost (Cil_types.Instr instr) :: acc
    in
    List.fold_left rev_build_one [] l

  let build_block b =
    let block = Cil.mkBlock (build_stmt_list ~ghost:b.ghost b.stmts) in
    block.Cil_types.blocals <- List.rev b.vars;
    block

  let build_stmtkind b =
    let block = build_block b in
    match b.scope_type with
    | Block ->
      Cil_types.Block block
    | IfThen { ifthen_exp } ->
      Cil_types.If (ifthen_exp, block, Cil.mkBlock [], loc)
    | IfThenElse { ifthenelse_exp; then_block } ->
      Cil_types.If (ifthenelse_exp, then_block, block, loc)
    | Switch { switch_exp } ->
      let open Cil_types in
      (* Case are only allowed in the current block by the case function *)
      let contains_case stmt =
        List.exists (function Case _ -> true | _ -> false) stmt.labels
      in
      let case_stmts = List.filter contains_case block.bstmts in
      Cil_types.Switch (switch_exp, block, case_stmts , loc)
    | Function _ ->
      raise (WrongContext "not convertible to stmtkind")

  (* Statements *)

  let stmt s =
    let b = top () in
    append_stmt b (CilStmt s)

  let stmts l =
    List.iter stmt l

  let stmtkind sk =
    let b = top () in
    append_stmt b (CilStmtkind sk)

  let new_block ?(ghost=false) scope_type = {
    scope_type;
    ghost;
    stmts = [];
    vars = [];
  }

  let open_function ?ghost name =
    check_empty ();
    let fundec = Cil.emptyFunction name in
    set_owner fundec;
    push (new_block ?ghost (Function {fundec}));
    `var fundec.Cil_types.svar

  let open_block () =
    push (new_block Block)

  let open_ghost () =
    push (new_block ~ghost:true Block)

  let open_switch exp =
    let switch_exp = cil_exp ~loc exp in
    push (new_block (Switch {switch_exp}))

  let open_if exp =
    let ifthen_exp = cil_exp ~loc exp in
    push (new_block (IfThen {ifthen_exp}))

  let open_else () =
    let b = pop () in
    let ifthenelse_exp = match b.scope_type with
      | IfThen {ifthen_exp} -> ifthen_exp
      | _ -> raise (WrongContext "not in an opened if-then-else context")
    in
    let then_block = build_block b in
    push (new_block (IfThenElse {ifthenelse_exp; then_block}))

  let close () =
    let above = pop () in
    check_not_empty ();
    stmtkind (build_stmtkind above) (* add the block to the parent *)

  let finish_block () =
    let b = finish () in
    match build_stmtkind b with
    | Cil_types.Block b -> b
    | _ -> raise (WrongContext "not in an opened simple block context")

  let finish_stmt () =
    let b = finish () in
    Cil.mkStmt ~ghost:b.ghost (build_stmtkind b)

  let finish_function ?(register=true) () =
    let b = finish () in
    match b.scope_type with
    | Function {fundec} ->
      let open Cil_types in
      fundec.sbody <- build_block b;
      fundec.svar.vdefined <- true;
      fundec.svar.vghost <- b.ghost;
      if register then begin
        let funspec = Cil.empty_funspec () in
        Globals.Functions.replace_by_definition funspec fundec loc;
        let keepSwitch = Kernel.KeepSwitch.get () in
        Cfg.prepareCFG ~keepSwitch fundec;
        Cfg.cfgFun fundec;
      end;
      reset_owner ();
      GFun (fundec,loc)
    | _ -> raise (WrongContext "not in a opened function context")

  let case exp =
    let b = top () in
    match b.scope_type with
    | Switch _context ->
      let label = Cil_types.Case (cil_exp ~loc exp, loc) in
      append_stmt b (Label label)
    | _ -> raise (WrongContext "no in a opened switch context")

  let break () =
    stmtkind (Cil_types.Break loc)

  let return exp =
    stmtkind (Cil_types.Return (cil_exp_opt ~loc exp, loc))

  (* Instructions *)

  let instr i =
    let b = top () in
    append_stmt b (CilInstr i)

  let assign lval exp =
    let lval' = cil_lval ~loc lval
    and exp' = cil_exp ~loc exp in
    instr (Cil_types.Set (lval', exp', loc))

  let incr lval =
    assign lval (add lval (int 1))

  let call dest callee args =
    let dest' = cil_lval_opt ~loc dest
    and callee' = cil_exp ~loc callee
    and args' = cil_exp_list ~loc args in
    instr (Cil_types.Call (dest', callee', args', loc))

  (* Variables *)

  let return_type typ =
    let fundec = get_owner () in
    Cil.setReturnType fundec typ

  let local ?(ghost=false) typ name =
    let fundec = get_owner () and b = top () in
    let ghost = ghost || b.ghost in
    let v = Cil.makeLocalVar fundec ~insert:false ~ghost ~loc name typ in
    `var v

  let local_copy ?(ghost=false) ?(suffix="_tmp") (`var vi) =
    let fundec = get_owner () and b = top () in
    let ghost = ghost || b.ghost in
    let v = Cil.copyVarinfo vi (vi.Cil_types.vname ^ suffix) in
    v.vghost <- v.vghost || ghost;
    Cil.refresh_local_name fundec v;
    fundec.Cil_types.slocals <- fundec.Cil_types.slocals @ [v];
    b.vars <- v :: b.vars;
    `var v

  let parameter ?(ghost=false) ?(attributes=[]) typ name =
    let fundec = get_owner () and b = top () in
    let ghost = ghost || b.ghost in
    let v = Cil.makeFormalVar ~ghost ~loc fundec name typ in
    v.Cil_types.vattr <- attributes;
    `var v
end
