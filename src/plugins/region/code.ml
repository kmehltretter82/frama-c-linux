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

let rec lval (m:map) (s:stmt) (lv:lval) : node =
  let h = fst lv in
  loffset m s (lhost m s h) (Cil.typeOfLhost h) (snd lv)

and lhost (m:map) (s:stmt) = function
  | Var x -> Memory.add_root m x
  | Mem e -> pointer m s e

and loffset (m:map) (s:stmt) (r:node) (ty:typ)= function
  | NoOffset -> r
  | Field(fd,ofs) ->
    loffset m s (add_field m r fd) fd.ftype ofs
  | Index(_,ofs) ->
    loffset m s (add_index m r ty) (Cil.typeOf_array_elem ty) ofs

and pointer m s e = match exp m s e with None -> add_cell m () | Some r -> r

and value m s e = ignore (exp m s e)

and exp (m: map) (s:stmt) (e:exp) : node option =
  match e.enode with

  | AddrOf lv | StartOf lv ->
    let rv = lval m s lv in
    Some rv

  | Lval lv ->
    let rv = lval m s lv in
    Memory.read m rv (Lval(s,lv)) ;
    Memory.add_value m rv @@ Cil.typeOfLval lv

  | UnOp(_,e,_) ->
    value m s e ; None

  | BinOp((PlusPI|MinusPI),p,k,_) ->
    value m s k ;
    let r = pointer m s p in
    (*TODO: move the 'A' access on the source of the pointed region *)
    (*Memory.shift m r (Exp(s,p)) ;*)
    Some r

  | BinOp(_,a,b,_) ->
    value m s a ;
    value m s b ;
    None

  | CastE(ty,p) ->
    if Cil.isPointerType ty then
      Some (pointer m s p)
    else
      (value m s p ; None)

  | Const _
  | SizeOf _ | SizeOfE _ | SizeOfStr _
  | AlignOf _ | AlignOfE _
    -> None

(* -------------------------------------------------------------------------- *)
(* --- Initializers                                                       --- *)
(* -------------------------------------------------------------------------- *)

let rec init (m:map) (s:stmt) (acs:Access.acs) (lv:lval) (iv:init) =
  match iv with

  | SingleInit e ->
    let r = lval m s lv in
    Memory.write m r acs ;
    Option.iter (Memory.add_points_to m r) (exp m s e)

  | CompoundInit(_,fvs) ->
    List.iter
      (fun (ofs,iv) ->
         let lv = Cil.addOffsetLval ofs lv in
         init m s acs lv iv
      ) fvs

(* -------------------------------------------------------------------------- *)
(* --- Instructions                                                       --- *)
(* -------------------------------------------------------------------------- *)

let instr (m:map) (s:stmt) (instr:instr) =
  match instr with
  | Skip _ | Code_annot _ -> ()

  | Set(lv,e,_) ->
    let r = lval m s lv in
    let v = exp m s e in
    Memory.write m r (Lval(s,lv)) ;
    Option.iter (Memory.add_points_to m r) v

  | Local_init(x,AssignInit iv,_) ->
    let acs = Access.Init(s,x) in
    init m s acs (Var x,NoOffset) iv

  | Call(lr,e,es,_) ->
    value m s e ;
    List.iter (value m s) es ;
    Option.iter
      (fun lv ->
         let r = lval m s lv in
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

let rec stmt (r:rmap) (m:map) (s:stmt) =
  let annots = Annotations.code_annot s in
  if annots <> [] then
    Options.warning ~source:(fst @@ Stmt.loc s)
      "Annotations not analyzed" ;
  match s.skind with
  | Instr ki -> instr m s ki ; store r m s
  | Return(Some e,_) -> value m s e ; store r m s
  | Goto _ | Break _ | Continue _ | Return(None,_) -> store r m s
  | If(e,st,se,_) ->
    value m s e ;
    store r m s ;
    block r m st ;
    block r m se ;
  | Switch(e,b,_,_) ->
    value  m s e ;
    store r m s ;
    block r m b ;
  | Block b | Loop(_,b,_,_,_) -> block r m b
  | UnspecifiedSequence s -> block r m @@ Cil.block_from_unspecified_sequence s
  | Throw(exn,_) -> Option.iter (fun (e,_) -> value  m s e) exn
  | TryCatch(b,hs,_)  ->
    block r m b ;
    List.iter (fun (c,b) -> catch r m c ; block r m b) hs ;
  | TryExcept(a,(ks,e),b,_) ->
    block r m a ;
    List.iter (instr m s) ks ;
    value  m s e ;
    block r m b ;
  | TryFinally(a,b,_) ->
    block r m a ;
    block r m b ;

and catch (r:rmap) (m:map) (c:catch_binder) =
  match c with
  | Catch_all -> ()
  | Catch_exn(_,xbs) -> List.iter (fun (_,b) -> block r m b) xbs

and block (r:rmap) (m:map) (b:block) =
  List.iter (stmt r m) b.bstmts

(* -------------------------------------------------------------------------- *)
(* --- Behavior                                                           --- *)
(* -------------------------------------------------------------------------- *)

type imap = Memory.map Property.Map.t ref

let istore imap m ip =
  imap := Property.Map.add ip (Memory.copy ~locked:true m) !imap

let bhv ~kf (s:imap) (m:map) (bhv:behavior) =
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
      List.iter (bhv ~kf s m) funspec.spec_behavior ;
    with Annotations.No_funspec _ -> ()
  end ;
  begin
    try
      let fundec = Kernel_function.get_definition kf in
      block r m fundec.sbody ;
    with Kernel_function.No_Definition -> ()
  end ;
  {
    map = Memory.copy ~locked:true m ;
    body = !r ;
    spec = !s ;
  }

(* -------------------------------------------------------------------------- *)
