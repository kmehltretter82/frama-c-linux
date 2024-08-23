(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2024                                               *)
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

type scalar = { from : node option ; ptr : node option }
let integral = { from = None ; ptr = None }
let pointer m v =
  match v.ptr with
  | Some p -> v, p
  | None ->
    let p = new_chunk m () in
    Option.iter (fun s -> Memory.add_points_to m s p) v.from ;
    { v with ptr = Some p }, p

let rec add_lval (m:map) (s:stmt) (lv:lval) : node =
  let h = fst lv in
  add_loffset m s (add_lhost m s h) (Cil.typeOfLhost h) (snd lv)

and add_lhost (m:map) (s:stmt) = function
  | Var x -> Memory.add_root m x
  | Mem e -> snd @@ pointer m @@ add_exp m s e

and add_loffset (m:map) (s:stmt) (r:node) (ty:typ)= function
  | NoOffset -> r
  | Field(fd,ofs) ->
    add_loffset m s (add_field m r fd) fd.ftype ofs
  | Index(_,ofs) ->
    let elt,size = Cil.typeOf_array_elem_size ty in
    let n = Z.to_int @@ Option.get size in
    add_loffset m s (add_index m r elt n) elt ofs

and add_value m s e = ignore (add_exp m s e)

and add_exp (m: map) (s:stmt) (e:exp) : scalar =
  match e.enode with

  | AddrOf lv | StartOf lv ->
    let rv = Some (add_lval m s lv) in
    { from = rv ; ptr = rv }

  | Lval lv ->
    let rv = add_lval m s lv in
    Memory.read m rv (Lval(s,lv)) ;
    let ptr = Memory.add_value m rv @@ Cil.typeOfLval lv in
    { from = Some rv ; ptr }

  | BinOp((PlusPI|MinusPI),p,k,_) ->
    add_value m s k ;
    let v = add_exp m s p in
    Option.iter (fun r -> Memory.shift m r (Exp(s,e))) v.from ; v

  | UnOp(_,e,_) ->
    add_value m s e ; integral

  | BinOp(_,a,b,_) ->
    add_value m s a ; add_value m s b ; integral

  | CastE(ty,p) ->
    let v = add_exp m s p in
    if Cil.isPointerType ty then
      fst @@ pointer m @@ v
    else
      integral

  | Const _
  | SizeOf _ | SizeOfE _ | SizeOfStr _
  | AlignOf _ | AlignOfE _
    -> integral

(* -------------------------------------------------------------------------- *)
(* --- Initializers                                                       --- *)
(* -------------------------------------------------------------------------- *)

let rec add_init (m:map) (s:stmt) (acs:Access.acs) (lv:lval) (iv:init) =
  match iv with

  | SingleInit e ->
    let r = add_lval m s lv in
    Memory.write m r acs ;
    Option.iter (Memory.add_points_to m r) (add_exp m s e).ptr

  | CompoundInit(_,fvs) ->
    List.iter
      (fun (ofs,iv) ->
         let lv = Cil.addOffsetLval ofs lv in
         add_init m s acs lv iv
      ) fvs

(* -------------------------------------------------------------------------- *)
(* --- Instructions                                                       --- *)
(* -------------------------------------------------------------------------- *)

let add_instr (m:map) (s:stmt) (instr:instr) =
  match instr with
  | Skip _ | Code_annot _ -> ()

  | Set(lv, { enode = Lval exp }, _) ->
    let l = add_lval m s lv in
    let r = add_lval m s exp in
    Memory.read m r (Lval(s,exp)) ;
    Memory.write m l (Lval(s,lv)) ;
    Memory.merge_copy m ~l ~r

  | Set(lv,e,_) ->
    let r = add_lval m s lv in
    let v = add_exp m s e in
    Memory.write m r (Lval(s,lv)) ;
    Option.iter (Memory.add_points_to m r) v.ptr

  | Local_init(x,AssignInit iv,_) ->
    let acs = Access.Init(s,x) in
    add_init m s acs (Var x,NoOffset) iv

  | Call(lr,e,es,_) ->
    add_value m s e ;
    List.iter (add_value m s) es ;
    Option.iter
      (fun lv ->
         let r = add_lval m s lv in
         Memory.write m r (Lval(s,lv))
      ) lr ;
    Options.warning ~source:(fst @@ Stmt.loc s) "Incomplete call analysis"

  | Local_init(_,ConsInit _,_) ->
    Options.warning ~source:(fst @@ Stmt.loc s)
      "Constructor init not yet implemented"
  | Asm _ ->
    Options.warning ~source:(fst @@ Stmt.loc s)
      "Inline assembly not supported (ignored)"

(* -------------------------------------------------------------------------- *)
(* --- Statements                                                         --- *)
(* -------------------------------------------------------------------------- *)

type rmap = Memory.map Stmt.Map.t ref

let store rmap m s =
  rmap := Stmt.Map.add s (Memory.copy ~locked:true m) !rmap

let rec add_stmt (r:rmap) (m:map) (s:stmt) =
  let annots = Annotations.code_annot s in
  if annots <> [] then
    Options.warning ~source:(fst @@ Stmt.loc s)
      "Annotations not analyzed" ;
  match s.skind with
  | Instr ki -> add_instr m s ki ; store r m s
  | Return(Some e,_) -> add_value m s e ; store r m s
  | Goto _ | Break _ | Continue _ | Return(None,_) -> store r m s
  | If(e,st,se,_) ->
    add_value m s e ;
    store r m s ;
    add_block r m st ;
    add_block r m se ;
  | Switch(e,b,_,_) ->
    add_value  m s e ;
    store r m s ;
    add_block r m b ;
  | Block b | Loop(_,b,_,_,_) -> add_block r m b
  | UnspecifiedSequence s -> add_block r m @@ Cil.block_from_unspecified_sequence s
  | Throw(exn,_) -> Option.iter (fun (e,_) -> add_value  m s e) exn
  | TryCatch(b,hs,_)  ->
    add_block r m b ;
    List.iter (fun (c,b) -> add_catch r m c ; add_block r m b) hs ;
  | TryExcept(a,(ks,e),b,_) ->
    add_block r m a ;
    List.iter (add_instr m s) ks ;
    add_value  m s e ;
    add_block r m b ;
  | TryFinally(a,b,_) ->
    add_block r m a ;
    add_block r m b ;

and add_catch (r:rmap) (m:map) (c:catch_binder) =
  match c with
  | Catch_all -> ()
  | Catch_exn(_,xbs) -> List.iter (fun (_,b) -> add_block r m b) xbs

and add_block (r:rmap) (m:map) (b:block) =
  List.iter (add_stmt r m) b.bstmts

(* -------------------------------------------------------------------------- *)
(* --- Behavior                                                           --- *)
(* -------------------------------------------------------------------------- *)

type imap = Memory.map Property.Map.t ref

let istore imap m ip =
  imap := Property.Map.add ip (Memory.copy ~locked:true m) !imap

let add_bhv ~kf (s:imap) (m:map) (bhv:behavior) =
  List.iter
    (fun e ->
       let rs = Annot.of_extension e in
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
      List.iter (add_bhv ~kf s m) funspec.spec_behavior ;
    with Annotations.No_funspec _ -> ()
  end ;
  begin
    try
      let fundec = Kernel_function.get_definition kf in
      add_block r m fundec.sbody ;
    with Kernel_function.No_Definition -> ()
  end ;
  {
    map = Memory.copy ~locked:true m ;
    body = !r ;
    spec = !s ;
  }

(* -------------------------------------------------------------------------- *)
