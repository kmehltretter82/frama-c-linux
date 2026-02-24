(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

open Cil_types
open Cil_datatype

(* -------------------------------------------------------------------------- *)
(* ---  Side Conditions                                                   --- *)
(* -------------------------------------------------------------------------- *)

type value =
  | E of (exp [@ compare Exp.compare ])
  | T of (term [@ compare Term.compare ])
[@@ deriving ord]

type addr =
  | LV of (lval [@ compare Lval.compare ])
  | TLV of (term_lval [@ compare Term_lval.compare ])
[@@ deriving ord]

let pp_value fmt = function
  | E e -> Format.fprintf fmt "« %a »" Printer.pp_exp e
  | T t -> Printer.pp_term fmt t

let pp_addr fmt = function
  | LV lv -> Format.fprintf fmt "« %a »" Printer.pp_lval lv
  | TLV lv -> Printer.pp_term_lval fmt lv

type guard =
  | Bounds of value * Z.t
  | Non_null of addr
  | Valid of addr
  | Valid_read of addr
  | Valid_region of (Memory.node [@ compare fun _ _ -> 0]) * addr
  | Initialized of addr
  | Aligned of addr
[@@ deriving ord]

let pp_guard fmt = function
  | Bounds(k,n) -> Format.fprintf fmt "0<= %a < %a" pp_value k Z.pretty n
  | Non_null a -> Format.fprintf fmt "!(%a)" pp_addr a
  | Valid a -> Format.fprintf fmt "\\valid(%a)" pp_addr a
  | Valid_read a -> Format.fprintf fmt "\\valid_read(%a)" pp_addr a
  | Valid_region(_,a) -> Format.fprintf fmt "\\valid_region(%a)" pp_addr a
  | Initialized a -> Format.fprintf fmt "\\initialized(%a)" pp_addr a
  | Aligned a -> Format.fprintf fmt "\\aligned(%a)" pp_addr a

module S =
struct
  type t = guard
  let compare = compare_guard
end

module Guards = Map.Make(S)

let of_value = function
  | T t -> t
  | E e -> Logic_utils.expr_to_term ~coerce:true e

let of_addr ?loc = function
  | LV lval -> Condition.addrof ?loc lval
  | TLV lval -> Condition.taddrof ?loc lval

let of_guard ?loc ?names = function
  | Bounds(k,n) ->
    let z = Logic_const.tinteger ?loc 0 in
    let n = Logic_const.tint ?loc n in
    let k = of_value k in
    let inf = Logic_const.pred ?loc (Prel(Rle,z,k)) in
    let sup = Logic_const.pred ?loc (Prel(Rlt,k,n)) in
    Logic_const.pand ?loc ?names (inf,sup)
  | Non_null p ->
    let addr = of_addr ?loc p in
    let null = Logic_const.term ?loc Tnull addr.term_type in
    Logic_const.prel ?loc ?names (Rneq,addr,null)
  | Valid p -> Condition.pvalid ?loc ?names @@ of_addr ?loc p
  | Valid_read p -> Condition.pvalid_read ?loc ?names @@ of_addr ?loc p
  | Valid_region(_,p) -> Condition.pvalid_region ?loc ?names @@ of_addr ?loc p
  | Initialized p -> Condition.pinitialized ?loc ?names @@ of_addr ?loc p
  | Aligned p -> Condition.paligned ?loc ?names @@ of_addr ?loc p

(* -------------------------------------------------------------------------- *)
(* ---  Side Conditions Generator                                         --- *)
(* -------------------------------------------------------------------------- *)

type env = {
  map: Memory.map ;
  kinstr: kinstr ;
  mutable guards: bool Guards.t ;
}

let create ?stmt map =
  let kinstr = match stmt with None -> Kglobal | Some stmt -> Kstmt stmt in
  { map ; kinstr ; guards = Guards.empty }

let add env ?(valid=true) g = env.guards <- Guards.add g valid env.guards
let iter f env = Guards.iter (fun g valid -> f g ~valid) env.guards

let check env g n a = function
  | Condition.Default -> add env g
  | Residual { validregion ; condition } ->
    if validregion then add env (Valid_region(n,a)) ;
    match condition with
    | `True -> ()
    | `False -> add env ~valid:false g
    | `Non_null -> add env (Non_null a)

let kind = function
  | LV lv -> Condition.lkind lv
  | TLV lv -> Condition.term_lkind lv

let typeof = function
  | LV lv -> Cil.typeOfLval lv
  | TLV lv -> Logic_utils.logicCType @@ Cil.typeOfTermLval lv

(* -------------------------------------------------------------------------- *)
(* ---  Valid Conditions                                                  --- *)
(* -------------------------------------------------------------------------- *)

let valid env n a =
  check env (Valid a) n a @@
  Condition.rvalid ~readonly:false env.kinstr n (kind a)

let valid_read env n a =
  check env (Valid_read a) n a @@
  Condition.rvalid ~readonly:true env.kinstr n (kind a)

let valid_region env n a =
  if (kind a).unsafe then add env (Valid_region(n,a))

let initialized env n a =
  check env (Valid_read a) n a @@ Condition.rinitialized n (kind a)

let aligned env n a =
  let bits = Fields.bitsSizeOf @@ typeof a in
  check env (Valid_read a) n a @@ Condition.raligned n (kind a) ~bits

let readable env n a =
  begin
    valid_region env n a ;
    valid_read env n a ;
    aligned env n a ;
    if not (Ast_types.is_struct_or_union @@ typeof a) then
      initialized env n a ;
  end

let writable env n a =
  begin
    valid_region env n a ;
    valid env n a ;
    aligned env n a ;
  end

(* -------------------------------------------------------------------------- *)
(* ---  Lval/Exp Side Conditions                                          --- *)
(* -------------------------------------------------------------------------- *)

let rec glval env (h,o) =
  let t,r = ghost env h in
  goffset env t r o

and ghost env = function
  | Var v -> v.vtype, Memory.cvar env.map v
  | Mem e -> Cil.typeOf e, gaddr env e

and goffset env t r = function
  | NoOffset -> t,r
  | Field(fd,o) -> goffset env fd.ftype (Memory.field r fd) o
  | Index(k,o) ->
    gval env k ;
    let te = Ast_types.direct_element_type t in
    let r = Memory.index r te in
    begin
      if Kernel.SafeArrays.get () then
        let n = Ast_info.direct_array_size t in
        add env (Bounds(E k,n))
    end ;
    goffset env te r o

and gaddr env e = Option.get @@ gexp env e
and gval env e = ignore @@ gexp env e
and gexp env e =
  match e.enode with
  | AddrOf lv | StartOf lv ->
    let _,r = glval env lv in Some r
  | Lval lv ->
    let _,r = glval env lv in
    Memory.points_to r
  | CastE(_,e) -> gexp env e
  | BinOp((PlusPI|MinusPI),p,k,_) ->
    let r = gexp env p in
    gval env k ; r
  | BinOp(_,a,b,_) ->
    gval env a ;
    gval env b ;
    None
  | UnOp(_,e,_) -> gval env e ; None
  | Const _ | SizeOf _ | SizeOfE _ | AlignOf (_, _) | AlignOfE (_, _) -> None

(* -------------------------------------------------------------------------- *)
