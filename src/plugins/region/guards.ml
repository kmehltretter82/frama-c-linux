(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

open Cil_types

(* -------------------------------------------------------------------------- *)
(* ---  Side Conditions Generator                                         --- *)
(* -------------------------------------------------------------------------- *)

type env = {
  map: Memory.map ;
  mutable guards : Condition.guard list ;
}

let create map = { map ; guards = [] }
let add env guard = env.guards <- guard :: env.guards
let iter f env = List.iter f @@ List.rev env.guards

(* -------------------------------------------------------------------------- *)
(* ---  Valid Conditions                                                  --- *)
(* -------------------------------------------------------------------------- *)

let valid env acs n a = add env (Valid(acs,n,a))

(* -------------------------------------------------------------------------- *)
(* ---  Lval/Exp Side Conditions                                          --- *)
(* -------------------------------------------------------------------------- *)

let rec lval env (h,o) =
  let t,r = lhost env h in
  offset env true t r o

and lhost env = function
  | Var v -> v.vtype, Memory.cvar env.map v
  | Mem e ->
    let s,r = addr env e in
    if not s then valid env Region r (ADDR e) ;
    Ast_types.direct_pointed_type @@ Cil.typeOf e, r

and offset env s t r = function
  | NoOffset -> s,t,r
  | Field(fd,o) -> offset env s fd.ftype (Memory.field r fd) o
  | Index(k,o) ->
    eval env k ;
    let te = Ast_types.direct_element_type t in
    let r = Memory.index r te in
    let s =
      if Kernel.SafeArrays.get () then
        let n = Ast_info.direct_array_size t in
        add env (Bounds(k,n)) ; s
      else false
    in offset env s te r o

and addr env e = Option.get @@ exp env e
and eval env e = ignore @@ exp env e

and exp env e =
  match e.enode with
  | AddrOf lv | StartOf lv ->
    let s,_,r = lval env lv in
    Some (s,r)
  | Lval lv ->
    let s,_,r = lval env lv in
    if not s then valid env Region r (LV lv) ;
    Option.map (fun r -> false,r) @@ Memory.points_to r
  | CastE(t,e) when
      Ast_types.is_fun_or_ptr t &&
      not (Ast_types.is_fun_or_ptr @@ Cil.typeOf e) ->
    Options.not_yet_implemented ~source:(fst e.eloc) "Integral to pointer casts"
  | CastE(_,e) ->
    Option.map (fun (_,r) -> false,r) @@ exp env e
  | BinOp((PlusPI|MinusPI),p,k,_) ->
    eval env k ;
    Option.map (fun (_,r) -> false,r) @@ exp env p
  | BinOp(_,a,b,_) ->
    eval env a ; eval env b ; None
  | UnOp((Neg|BNot|LNot),e, _) -> eval env e ; None
  | Const _ | SizeOf _ | SizeOfE _ | AlignOf (_, _) | AlignOfE (_, _) -> None

let write env lv =
  let s,_,r = lval env lv in
  if not s then valid env Region r (LV lv)

(* -------------------------------------------------------------------------- *)
(* --- Root Side Conditions                                               --- *)
(* -------------------------------------------------------------------------- *)

let nullable ~from addr =
  if Attr.mem `Nullable from then Condition.Null(false,addr)
  else True

let readable ~node ~from addr =
  if Attr.mem `Allocated from then Condition.Valid(Read,node,addr)
  else nullable ~from addr

let writable ~node ~from addr =
  if Attr.mem `Readonly from then Condition.False else
  if Attr.mem `Allocated from then Condition.Valid(Write,node,addr)
  else nullable ~from addr

let requires ~readonly ~node ~from ~target addr =
  let valid =
    if readonly || Attr.mem `Readonly target then
      readable ~node ~from addr
    else
      writable ~node ~from addr in
  let initialized =
    if Attr.mem `Garbage target || not @@ Attr.mem `Garbage from then
      Condition.True
    else
      Condition.Valid(Initialized,node,addr) in
  let allocated =
    if Attr.mem `Allocated target then
      Condition.g_imply valid initialized
    else
      Condition.g_and valid initialized in
  let nullable =
    if Attr.mem `Nullable target then
      Condition.Null(false,addr)
    else False in
  Condition.g_or nullable allocated
[@@ warning "-32"]

(* -------------------------------------------------------------------------- *)
(* --- Code Side Conditions                                               --- *)
(* -------------------------------------------------------------------------- *)

let rec init env = function
  | SingleInit e -> eval env e
  | CompoundInit(_,ofs) -> List.iter (fun (_,i) -> init env i) ofs

let called env = function
  | Var _vf -> ()
  | Mem e -> eval env e

let instr env = function
  | Set(lv,e,_) ->
    eval env e ;
    write env lv ;
  | Call(r,f,es,_) ->
    called env f ;
    List.iter (eval env) es ;
    Option.iter (write env) r
  | Local_init(_,AssignInit i,_) -> init env i
  | Local_init(_,ConsInit(_,es,_),_) -> List.iter (eval env) es
  | Asm _ | Skip _ | Code_annot _ -> ()

let rec stmtkind env = function
  | Instr i -> instr env i
  | Return(r,_) -> Option.iter (eval env) r
  | If(e,_,_,_) | Switch(e,_,_,_)| Throw (Some(e,_),_) -> eval env e
  | Goto _ | Break _ | Continue _ | Loop _ | Block _
  | Throw(None,_) | TryCatch _ | TryFinally _ -> ()
  | TryExcept(_,(ks,e),_,_) -> List.iter (instr env) ks ; eval env e
  | UnspecifiedSequence us ->
    let b = Cil.block_from_unspecified_sequence us in
    List.iter (fun s -> stmtkind env s.skind) b.bstmts

let guards map f stmt =
  let env = create map in
  stmtkind env stmt.skind ;
  iter f env

(* -------------------------------------------------------------------------- *)
(* --- Generate Annotations                                               --- *)
(* -------------------------------------------------------------------------- *)

let self =
  let em = ref None in
  fun () ->
    match !em with
    | Some e -> e
    | None ->
      let e = Emitter.create "Region Side-Conditions"
          Emitter.[ Code_annot ; Property_status ]
          ~correctness:[]
          ~tuning:[] in
      em := Some e ; e

let add_annotation ?kf ?emitter ?(names=[]) ?(invalid=false) ?(hyps=[]) stmt guard =
  let loc = Cil_datatype.Stmt.loc stmt in
  let kind = if Options.Assert.get () then Cil_types.Assert else Check in
  let enames = if invalid then "invalid"::names else names in
  let enames = if emitter = None then "region"::enames else enames in
  let e = match emitter with Some e -> e | None -> self () in
  let a = Condition.of_guard ~loc ~names:enames guard in
  let a = Logic_const.toplevel_predicate ~kind a in
  let ca = Logic_const.new_code_annotation (AAssert ([],a)) in
  Annotations.add_code_annot e ?kf stmt ca ;
  if invalid then
    let kf = Kernel_function.find_englobing_kf stmt in
    let ips = Property.ip_of_code_annot kf stmt ca in
    let status = Property_status.False_if_reachable in
    List.iter (fun ip -> Property_status.emit e ~hyps ip status) ips ;
    match names with
    | [] ->
      Options.warning ~source:(fst loc) "Invalid side-condition"
    | [e] ->
      Options.warning ~source:(fst loc) "Invalid side-condition (%s)" e
    | es ->
      Options.warning ~source:(fst loc) "Invalid side-conditions (%s)"
        (String.concat ", " es)

(* -------------------------------------------------------------------------- *)
(* ---  Function Annotation                                               --- *)
(* -------------------------------------------------------------------------- *)

module Computed =
  State_builder.Hashtbl(Kernel_function.Hashtbl)(Datatype.Unit)
    (struct
      let name = "Region.Guards.Computed"
      let dependencies = [Ast.self]
      let size = 0
    end)

let is_annotated kf = Computed.mem kf
let set_annotated kf = Computed.add kf ()

let annotate =
  Computed.memo
    begin fun kf ->
      if Kernel_function.has_definition kf then
        begin
          let map = Analysis.get kf in
          Options.feedback "annotating function %a" Kernel_function.pretty kf ;
          let fd = Kernel_function.get_definition kf in
          List.iter
            (fun stmt -> guards map (add_annotation ~kf stmt) stmt)
            fd.sallstmts ;
          set_annotated kf ;
        end
    end

(* -------------------------------------------------------------------------- *)
