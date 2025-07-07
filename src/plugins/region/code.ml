(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2025                                               *)
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
open Cil_datatype
open Memory

(* -------------------------------------------------------------------------- *)
(* ---  L-Values & Expressions                                            --- *)
(* -------------------------------------------------------------------------- *)

type value = node option

let pointer v =
  match v with
  | Some p -> p
  | None -> Options.abort "Not a pointer value"

let rec add_lval (m:map) (s:stmt) (lv:lval) : node =
  let h = fst lv in
  add_loffset m s (add_lhost m s h) (Cil.typeOfLhost h) (snd lv)

and add_lhost (m:map) (s:stmt) = function
  | Var x -> Memory.add_cvar m x
  | Mem e -> pointer @@ add_exp m s e

and add_loffset (m:map) (s:stmt) (r:node) (ty:typ)= function
  | NoOffset -> r
  | Field(fd,ofs) ->
    add_loffset m s (add_field m r fd) fd.ftype ofs
  | Index(e,ofs) ->
    let elt = Ast_types.direct_element_type ty in
    ignore @@ add_exp m s e ;
    add_loffset m s (add_index m r elt) elt ofs

and add_value m s e = ignore (add_exp m s e)

and add_exp (m: map) (s:stmt) (e:exp) : value =
  match e.enode with

  | AddrOf lv | StartOf lv -> Some (add_lval m s lv)

  | Lval lv ->
    let rv = add_lval m s lv in
    Memory.add_read m rv (Lval(s,lv)) ;
    Memory.add_value m rv @@ Cil.typeOfLval lv

  | BinOp((PlusPI|MinusPI),p,k,_) ->
    add_value m s k ;
    let vp = add_exp m s p in
    Memory.add_shift m (pointer vp) (Exp(s,e)) ; vp

  | UnOp(_,e,_) ->
    add_value m s e ; None

  | BinOp(_,a,b,_) ->
    add_value m s a ; add_value m s b ; None

  | CastE(_,p) ->
    add_exp m s p

  | Const _
  | SizeOf _ | SizeOfE _ | SizeOfStr _
  | AlignOf _ | AlignOfE _
    -> None

(* -------------------------------------------------------------------------- *)
(* --- Compound L-Values                                                  --- *)
(* -------------------------------------------------------------------------- *)

let is_comp lv =
  Ast_types.is_struct_or_union @@ Cil.typeOfLval lv

(* -------------------------------------------------------------------------- *)
(* --- Initializers                                                       --- *)
(* -------------------------------------------------------------------------- *)

let rec add_init (m:map) (s:stmt) (acs:Access.acs) (lv:lval) (iv:init) =
  match iv with

  | SingleInit { enode = Lval le } when is_comp le ->
    let r = add_lval m s lv in
    let v = add_lval m s le in
    Memory.merge m r v

  | SingleInit e ->
    let r = add_lval m s lv in
    Memory.add_write m r acs ;
    Option.iter (Memory.add_points_to m r) (add_exp m s e)

  | CompoundInit(_,fvs) ->
    List.iter
      (fun (ofs,iv) ->
         let lv = Cil.addOffsetLval ofs lv in
         add_init m s acs lv iv
      ) fvs


(* -------------------------------------------------------------------------- *)
(* --- Instructions                                                       --- *)
(* -------------------------------------------------------------------------- *)

let add_write ~map ~stmt ~acs (r:node) (e:exp) =
  Memory.add_write map r acs ;
  match e.enode with
  | Lval le when is_comp le ->
    let v = add_lval map stmt le in
    Memory.merge map r v
  | _ ->
    let v = add_exp map stmt e in
    Option.iter (Memory.add_points_to map r) v

let add_kf_call ~kf ~stmt map ?property ?result args kfct =
  let module Vmap = Cil_datatype.Varinfo.Map in
  let funspec = Annotations.funspec kfct in
  let fargs = Kernel_function.get_formals kfct in
  let ki = Kinstr.kinstr_of_opt_stmt (Some stmt) in
  let add_called_behavior bhv =
    let add_formal formal e arg =
      let property =
        match property with
        | Some p -> p
        | None -> Property.ip_of_behavior kf ki ~active:[] bhv in
      let env = Logic.{ map ; formal = Vmap.empty ; property ; result } in
      let d = Logic.add_term env @@ Logic_utils.expr_to_term e in
      Vmap.add arg d formal in
    let formal = List.fold_left2 add_formal Vmap.empty args fargs in
    Annot.add_behavior ~kf ~ki ~formal map bhv
  in List.iter (add_called_behavior ~iscalled:true) funspec.spec_behavior

let add_call ~kf ~stmt map ?result fct (args: exp list) =
  match Kernel_function.get_called fct with
  | Some kfct -> add_kf_call ~kf ~stmt map ?result args kfct
  | None ->
    begin match Dyncall.get stmt with
      | Some(property,kfcts) ->
        List.iter (add_kf_call ~kf ~stmt map ~property ?result args) kfcts
      | None ->
        Options.abort "Cannot resolve dynamic call for stmt:%a@."
          Printer.pp_stmt stmt
    end

let add_instr ~kf (m:map) (s:stmt) (instr:instr) =
  match instr with
  | Skip _ -> ()
  | Code_annot (annot,_) ->
    Annot.add_code_annot ~iscalled:true ~kf ~stmt:s m annot

  | Set(lv,e,_) ->
    let r = add_lval m s lv in
    add_write ~map:m ~stmt:s ~acs:(Lval(s,lv)) r e ;

  | Local_init(x,AssignInit iv,_) ->
    let acs = Access.Init(s,x) in
    add_init m s acs (Var x,NoOffset) iv

  | Local_init(_,ConsInit _,_) ->
    Options.warning ~source:(fst @@ Stmt.loc s)
      "Constructor init not yet implemented"

  | Call(lr,e,es,_) ->
    add_value m s e ;
    List.iter (add_value m s) es ;
    let result = Option.map
        (fun lv ->
           let r = add_lval m s lv in
           Memory.add_write m r (Lval(s,lv)) ; r
        ) lr
    in add_call ~kf ~stmt:s m ?result e es
      (*
      use some of the code in : cfgCalculus.ml:~335 & LogicSemantics:~909
    let result = Option.fold ~none:pure ~some:(Ldomain.of_lval) lv in
    let ofun = Kernel_function.(Option.map get_vi @@ get_called e) in
    add_call ~kf m result e es ; *)

  | Asm _ ->
    Options.warning ~source:(fst @@ Stmt.loc s)
      "Inline assembly not supported (ignored)"

(* -------------------------------------------------------------------------- *)
(* --- Statements                                                         --- *)
(* -------------------------------------------------------------------------- *)

type rmap = Memory.map Stmt.Map.t ref

let store rmap m s =
  rmap := Stmt.Map.add s (Memory.copy ~locked:true m) !rmap

let rec add_stmt ~kf (r:rmap) (m:map) (s:stmt) =
  let add_block = add_block ~kf in
  let add_annot = Annot.add_code_annot ~iscalled:true ~kf ~stmt:s m in
  List.iter add_annot @@ Annotations.code_annot s ;
  match s.skind with
  | Instr ki -> add_instr ~kf m s ki ; store r m s
  | Return(Some e,_) ->
    add_write ~map:m ~stmt:s ~acs:(Exp(s,e)) (Memory.add_result m) e ;
    store r m s ;
  | Return(None,_) -> ignore @@ Memory.add_result m ; store r m s
  | Goto _ | Break _ | Continue _ -> store r m s
  | If(e,st,se,_) ->
    add_value m s e ;
    store r m s ;
    add_block r m st ;
    add_block r m se ;
  | Switch(e,b,_,_) ->
    add_value  m s e ;
    store r m s ;
    add_block r m b ;
  | Block b -> add_block r m b
  | Loop(annots,b,_,_,_) -> List.iter add_annot annots ; add_block r m b
  | UnspecifiedSequence s ->
    add_block r m @@ Cil.block_from_unspecified_sequence s
  | Throw(exn,_) -> Option.iter (fun (e,_) -> add_value  m s e) exn
  | TryCatch(b,hs,_)  ->
    add_block r m b ;
    List.iter (fun (c,b) -> add_catch ~kf r m c ; add_block r m b) hs ;
  | TryExcept(a,(ks,e),b,_) ->
    add_block r m a ;
    List.iter (add_instr ~kf m s) ks ;
    add_value  m s e ;
    add_block r m b ;
  | TryFinally(a,b,_) ->
    add_block r m a ;
    add_block r m b ;

and add_catch ~kf (r:rmap) (m:map) (c:catch_binder) =
  match c with
  | Catch_all -> ()
  | Catch_exn(_,xbs) -> List.iter (fun (_,b) -> add_block ~kf r m b) xbs

and add_block ~kf (r:rmap) (m:map) (b:block) =
  List.iter (add_stmt ~kf r m) b.bstmts

(* -------------------------------------------------------------------------- *)
(* --- Behavior                                                           --- *)
(* -------------------------------------------------------------------------- *)

type imap = Memory.map Property.Map.t ref

let istore imap m ip =
  imap := Property.Map.add ip (Memory.copy ~locked:true m) !imap

let add_bhv ~kf ~result:_ (s:imap) (m:map) (bhv:behavior) =
  List.iter
    (fun e ->
       let rs = Spec.of_extension e in
       if rs <> [] then
         begin
           List.iter (Logic.add_region m) rs ;
           let ip = Property.ip_of_extended (ELContract kf) e in
           istore s m ip ;
         end
    ) bhv.b_extended

(* -------------------------------------------------------------------------- *)
(* --- Function                                                           --- *)
(* -------------------------------------------------------------------------- *)

type domain = {
  map : map ;
  body : map Stmt.Map.t ;
  spec : map Property.Map.t ;
}

let domain ?global kf =
  let m = match global with Some g -> g | None -> Memory.create () in
  let r = ref Stmt.Map.empty in
  let s = ref Property.Map.empty in
  begin
    try
      let funspec = Annotations.funspec kf in
      List.iter (add_bhv ~kf ~result s m) funspec.spec_behavior ;
      let ki = Kinstr.kinstr_of_opt_stmt None in
      List.iter (Annot.add_behavior ~iscalled:false ~kf ~ki m) funspec.spec_behavior ;
    with Annotations.No_funspec _ -> ()
  end ;
  begin
    try
      let fundec = Kernel_function.get_definition kf in
      add_block ~kf r m fundec.sbody ;
    with Kernel_function.No_Definition -> ()
  end ;
  {
    map = Memory.copy ~locked:true m ;
    body = !r ;
    spec = !s ;
  }

(* -------------------------------------------------------------------------- *)
