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

let typeof_array_elt ty =
  match Cil.unrollType ty with
  | TArray(te,_,_) -> te
  | _ -> Cil.voidType

(* -------------------------------------------------------------------------- *)
(* ---  L-Values & Expressions                                            --- *)
(* -------------------------------------------------------------------------- *)

let rec lval (m:map) (s:stmt) (lv:lval) : node =
  let h = fst lv in
  loffset m s (lhost m s h) (Cil.typeOfLhost h) (snd lv)

and lhost (m:map) (s:stmt) = function
  | Var x -> Memory.root m x
  | Mem e -> pointer m s e

and loffset (m:map) (s:stmt) (r:node) (ty:typ)= function
  | NoOffset -> r
  | Field(fd,ofs) ->
    let size = Cil.bitsSizeOf ty in
    let offset, length = Cil.fieldBitsOffset fd in
    let data = Memory.cell m () in
    let rc = Memory.range m ~size ~offset ~length ~data in
    ignore @@ Memory.merge m r rc ; loffset m s data fd.ftype ofs
  | Index(_,ofs) ->
    let size = Cil.bitsSizeOf ty in
    let te = typeof_array_elt ty in
    let data = Memory.cell m () in
    let rc = Memory.range m ~size ~offset:0 ~length:size ~data in
    ignore @@ Memory.merge m r rc ; loffset m s data te ofs

and pointer m s e = match exp m s e with None -> cell m () | Some r -> r

and value m s e = ignore (exp m s e)

and exp (m: map) (s:stmt) (e:exp) : node option =
  match e.enode with

  | AddrOf lv | StartOf lv ->
    let rv = lval m s lv in
    Some rv

  | Lval lv ->
    let rv = lval m s lv in
    Memory.read m rv (Lval(s,lv)) ;
    if Cil.isPointerType @@ Cil.typeOfLval lv then
      let rp = cell m () in
      Memory.points_to m rv rp ;
      Some rp
    else
      None

  | UnOp(_,e,_) ->
    value m s e ; None

  | BinOp((PlusPI|MinusPI),p,k,_) ->
    value m s k ;
    let r = pointer m s p in
    Memory.shift m r (Exp(s,e)) ;
    Some r

  | BinOp(_,a,b,_) ->
    value m s a ;
    value m s b ;
    None

  | CastE(ty,p) ->
    if Cil.isPointerType ty then
      Some (pointer m s p)
    else
      (value m s e ; None)

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
    Option.iter (Memory.points_to m r) (exp m s e)

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
    Option.iter (Memory.points_to m r) v

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
  rmap := Stmt.Map.add s (Memory.copy m) !rmap

let rec stmt (r:rmap) (m:map) (s:stmt) =

  let annots = Annotations.code_annot s in
  if annots <> [] then
    Options.warning ~source:(fst @@ Stmt.loc s)
      "Annotations not analyzed" ;
  match s.skind with
  | Instr ki -> instr m s ki ; store r m s
  | Return(Some e,_) -> value  m s e ; store r m s
  | Goto _ | Break _ | Continue _ | Return(None,_) -> store r m s
  | If(e,st,se,_) ->
    value  m s e ;
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
(* --- Function                                                           --- *)
(* -------------------------------------------------------------------------- *)

type domain = {
  map : map ;
  body : map Stmt.Map.t ;
  spec : map Property.Map.t ;
}

let domain kf =
  let m = Memory.create () in
  let r = ref Stmt.Map.empty in
  begin
    try
      let fundec = Kernel_function.get_definition kf in
      block r m fundec.sbody ;
    with Kernel_function.No_Definition -> ()
  end ; {
    map = m ;
    body = !r ;
    spec = Property.Map.empty ;
  }

(* -------------------------------------------------------------------------- *)
