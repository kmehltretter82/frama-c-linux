(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

open Cil_types
open Cil_datatype
open Memory

module Vmap = Varinfo.Map

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
    add_loffset m s (add_field r fd) fd.ftype ofs
  | Index(e,ofs) ->
    let elt = Ast_types.direct_element_type ty in
    ignore @@ add_exp m s e ;
    add_loffset m s (add_index r elt) elt ofs

and add_value m s e = ignore (add_exp m s e)

and add_exp (m: map) (s:stmt) (e:exp) : value =
  match e.enode with

  | AddrOf lv | StartOf lv -> Some (add_lval m s lv)
  | Lval lv ->
    let rv = add_lval m s lv in
    Memory.add_read rv (Lval(s,lv)) ;
    Memory.add_value rv @@ Cil.typeOfLval lv

  | BinOp((PlusPI|MinusPI),p,k,_) ->
    add_value m s k ;
    let vp = add_exp m s p in
    Memory.add_shift (pointer vp) (Exp(s,e)) ; vp

  | UnOp(_,e,_) ->
    add_value m s e ; None

  | BinOp(_,a,b,_) ->
    add_value m s a ; add_value m s b ; None

  | CastE(_,p) ->
    add_exp m s p

  | Const _
  | SizeOf _ | SizeOfE _
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
    Memory.merge r v

  | SingleInit e ->
    let r = add_lval m s lv in
    Memory.add_init r acs ;
    Option.iter (Memory.add_points_to r) (add_exp m s e)

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
  Memory.add_write r acs ;
  match e.enode with
  | Lval le when is_comp le ->
    let v = add_lval map stmt le in
    Memory.merge r v
  | _ ->
    let v = add_exp map stmt e in
    Option.iter (Memory.add_points_to r) v

let add_function (m:map) (s:stmt) (f:lhost) =
  match f with
  | Var _vf -> ()
  | Mem e -> add_value m s e

let add_result (m:map) (s:stmt) lv =
  let r = add_lval m s lv in
  Memory.add_write r (Lval(s,lv)) ; r

let add_formal m s formals x e =
  Vmap.add x (Ldomain.scalar @@ add_exp m s e) formals

let add_kf_call m s r kf es =
  Populate_spec.populate_funspec kf [`Assigns] ;
  let funspec = Annotations.funspec kf in
  let args = Kernel_function.get_formals kf in
  let formals = List.fold_left2 (add_formal m s) Vmap.empty args es in
  let add_called_behavior bhv =
    Annot.add_behavior ~iscalled:true ~kf ~ki:Kglobal ~formals ~result:r m bhv
  in List.iter add_called_behavior funspec.spec_behavior

let add_call m s r fct es =
  match Kernel_function.get_called fct with
  | Some kf -> add_kf_call m s r kf es
  | None ->
    begin
      match Dyncall.get s with
      | Some(_,kfs) ->
        List.iter (fun kf -> add_kf_call m s r kf es) kfs
      | None ->
        Options.abort ~source:(fst @@ Stmt.loc s) "Cannot resolve dynamic call"
    end

let add_instr ~kf ~stmt (m:map) (instr:instr) =
  match instr with
  | Skip _ -> ()
  | Code_annot (annot,_) ->
    Annot.add_code_annot ~kf ~stmt ~formals:Vmap.empty ~result:None m annot

  | Set(lv,e,_) ->
    let r = add_lval m stmt lv in
    add_write ~map:m ~stmt:stmt ~acs:(Lval(stmt,lv)) r e ;

  | Local_init(x,AssignInit iv,_) ->
    let acs = Access.Init(stmt,x) in
    add_init m stmt acs (Var x,NoOffset) iv

  | Local_init(x,ConsInit (vf,args,kind), loc) ->
    let r = add_cvar m x in
    Memory.add_init r (Lval (stmt,Cil.var x)) ;
    Cil.treat_constructor_as_func
      begin fun _res fct args _loc ->
        add_function m stmt fct;
        List.iter (add_value m stmt) args ;
        add_call m stmt (Some r) fct args
      end x vf args kind loc

  | Call(lr,f,es,_) ->
    add_function m stmt f;
    let r = Option.map (add_result m stmt) lr in
    add_call m stmt r f es

  | Asm _ ->
    Options.warning ~source:(fst @@ Stmt.loc stmt)
      "Inline assembly not supported (ignored)"

(* -------------------------------------------------------------------------- *)
(* --- Statements                                                         --- *)
(* -------------------------------------------------------------------------- *)

let add_code_annot ~kf ~stmt map =
  Annot.add_code_annot ~kf ~stmt
    ~formals:Vmap.empty
    ~result:None map

let rec add_stmt ~kf map stmt =
  List.iter (add_code_annot ~kf ~stmt map) @@ Annotations.code_annot stmt ;
  match stmt.skind with
  | Instr instr -> add_instr ~kf ~stmt map instr ;
  | Return(None,_) -> ()
  | Return(Some e,_) ->
    add_write ~map ~stmt ~acs:(Exp(stmt,e)) (Memory.add_result map) e
  | Goto _ | Break _ | Continue _ -> ()
  | If(e,sthen,selse,_) ->
    add_value map stmt e ;
    add_block ~kf map sthen ;
    add_block ~kf map selse ;
  | Switch(e,b,_,_) ->
    add_value map stmt e ;
    add_block ~kf map b ;
  | Block b -> add_block ~kf map b
  | Loop(annots,b,_,_,_) ->
    List.iter (add_code_annot ~kf ~stmt map) annots ;
    add_block ~kf map b
  | UnspecifiedSequence s ->
    add_block ~kf map @@ Cil.block_from_unspecified_sequence s
  | Throw(exn,_) -> Option.iter (fun (e,_) -> add_value map stmt e) exn
  | TryCatch(b,hs,_)  ->
    add_block ~kf map b ;
    List.iter (fun (c,b) -> add_catch ~kf map c ; add_block ~kf map b) hs
  | TryExcept(a,(ks,e),b,_) ->
    add_block ~kf map a ;
    List.iter (add_instr ~kf ~stmt map) ks ;
    add_value map stmt e ;
    add_block ~kf map b ;
  | TryFinally(a,b,_) ->
    add_block ~kf map a ;
    add_block ~kf map b ;

and add_catch ~kf (m:map) (c:catch_binder) =
  match c with
  | Catch_all -> ()
  | Catch_exn(_,xbs) -> List.iter (fun (_,b) -> add_block ~kf m b) xbs

and add_block ~kf (m:map) (b:block) =
  List.iter (add_stmt ~kf m) b.bstmts

(* -------------------------------------------------------------------------- *)
(* --- Function                                                           --- *)
(* -------------------------------------------------------------------------- *)

type domain = map

let domain kf =
  let m = Memory.create () in
  begin
    try
      let funspec = Annotations.funspec kf in
      let ki = Kglobal in
      let iscalled = false in
      let formals = Vmap.empty in
      let result =
        if Kernel_function.returns_void kf then None else
          Some (Memory.add_result m) in
      List.iter
        (Annot.add_behavior ~kf ~ki ~iscalled ~formals ~result m)
        funspec.spec_behavior ;
    with Annotations.No_funspec _ -> ()
  end ;
  begin
    try
      let fundec = Kernel_function.get_definition kf in
      add_block ~kf m fundec.sbody ;
    with Kernel_function.No_Definition -> ()
  end ;
  Memory.lock m ; m

(* -------------------------------------------------------------------------- *)
