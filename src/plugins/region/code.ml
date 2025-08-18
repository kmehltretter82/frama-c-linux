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

let add_kf_call ~kf ~stmt map ?property ~result args kfct =
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
    Annot.add_behavior ~iscalled:true ~kf ~ki ~formal ~result map bhv
  in List.iter add_called_behavior funspec.spec_behavior

let add_call ~kf ~stmt map ~result fct (args: exp list) =
  match Kernel_function.get_called fct with
  | Some kfct -> add_kf_call ~kf ~stmt map ~result args kfct
  | None ->
    begin match Dyncall.get stmt with
      | Some(property,kfcts) ->
        List.iter (add_kf_call ~kf ~stmt map ~property ~result args) kfcts
      | None ->
        Options.abort "Cannot resolve dynamic call for stmt:%a@."
          Printer.pp_stmt stmt
    end

let add_function (m:map) (s:stmt) (f:lhost) =
  match f with
  | Var _vf -> ()
  | Mem e -> add_value m s e

let add_instr ~kf (m:map) (s:stmt) (instr:instr) =
  match instr with
  | Skip _ -> ()
  | Code_annot (annot,_) ->
    Annot.add_code_annot ~iscalled:false ~kf ~stmt:s ~result:None m annot

  | Set(lv,e,_) ->
    let r = add_lval m s lv in
    add_write ~map:m ~stmt:s ~acs:(Lval(s,lv)) r e ;

  | Local_init(x,AssignInit iv,_) ->
    let acs = Access.Init(s,x) in
    add_init m s acs (Var x,NoOffset) iv

  | Local_init(x,ConsInit (vf,args,kind), loc) ->
    let r = add_cvar m x in
    Memory.add_write m r (Lval (s,Cil.var x)) ;
    Cil.treat_constructor_as_func
      begin fun _res fct args _loc ->
        add_function m s fct;
        List.iter (add_value m s) args ;
        add_call ~kf ~stmt:s m ~result:(Some r) fct args
      end x vf args kind loc

  | Call(lr,f,es,_) ->
    add_function m s f;
    List.iter (add_value m s) es ;
    let result = Option.map
        (fun lv ->
           let r = add_lval m s lv in
           Memory.add_write m r (Lval(s,lv)) ; r
        ) lr
    in add_call ~kf ~stmt:s m ~result f es

  | Asm _ ->
    Options.warning ~source:(fst @@ Stmt.loc s)
      "Inline assembly not supported (ignored)"

(* -------------------------------------------------------------------------- *)
(* --- Statements                                                         --- *)
(* -------------------------------------------------------------------------- *)

let rec add_stmt ~kf (m:map) (s:stmt) =
  let add_block = add_block ~kf in
  let add_annot =
    Annot.add_code_annot ~iscalled:false ~kf ~stmt:s ~result:None m in
  List.iter add_annot @@ Annotations.code_annot s ;
  match s.skind with
  | Instr ki -> add_instr ~kf m s ki ;
  | Return(Some e,_) ->
    add_write ~map:m ~stmt:s ~acs:(Exp(s,e)) (Memory.add_result m) e ;
  | Return(None,_) -> ignore @@ Memory.add_result m ;
  | Goto _ | Break _ | Continue _ -> ()
  | If(e,st,se,_) ->
    add_value m s e ;
    add_block m st ;
    add_block m se ;
  | Switch(e,b,_,_) ->
    add_value m s e ;
    add_block m b ;
  | Block b -> add_block m b
  | Loop(annots,b,_,_,_) -> List.iter add_annot annots ; add_block m b
  | UnspecifiedSequence s ->
    add_block m @@ Cil.block_from_unspecified_sequence s
  | Throw(exn,_) -> Option.iter (fun (e,_) -> add_value  m s e) exn
  | TryCatch(b,hs,_)  ->
    add_block m b ;
    List.iter (fun (c,b) -> add_catch ~kf m c ; add_block m b) hs ;
  | TryExcept(a,(ks,e),b,_) ->
    add_block m a ;
    List.iter (add_instr ~kf m s) ks ;
    add_value  m s e ;
    add_block m b ;
  | TryFinally(a,b,_) ->
    add_block m a ;
    add_block m b ;

and add_catch ~kf (m:map) (c:catch_binder) =
  match c with
  | Catch_all -> ()
  | Catch_exn(_,xbs) -> List.iter (fun (_,b) -> add_block ~kf m b) xbs

and add_block ~kf (m:map) (b:block) =
  List.iter (add_stmt ~kf m) b.bstmts

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
  spec : map Property.Map.t ;
}

let domain ?global kf =
  let m = match global with Some g -> g | None -> Memory.create () in
  let s = ref Property.Map.empty in
  begin
    try
      let funspec = Annotations.funspec kf in
      List.iter (add_bhv ~kf ~result s m) funspec.spec_behavior ;
      let ki = Kinstr.kinstr_of_opt_stmt None in
      List.iter (Annot.add_behavior ~iscalled:false ~kf ~ki ~result:None m)
        funspec.spec_behavior ;
    with Annotations.No_funspec _ -> ()
  end ;
  begin
    try
      let fundec = Kernel_function.get_definition kf in
      add_block ~kf m fundec.sbody ;
    with Kernel_function.No_Definition -> ()
  end ;
  {
    map = Memory.copy ~locked:true m ;
    spec = !s ;
  }

(* -------------------------------------------------------------------------- *)
