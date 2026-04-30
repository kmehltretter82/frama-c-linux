(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

(* -------------------------------------------------------------------------- *)
(* --- Side Condition Helpers                                             --- *)
(* -------------------------------------------------------------------------- *)

open Cil_types
open Cil_datatype

(* -------------------------------------------------------------------------- *)
(* --- Valid Region Built-in                                              --- *)
(* -------------------------------------------------------------------------- *)

let lvalid_region = "\\valid_region"
let is_valid_region lf = lf.l_var_info.lv_name = lvalid_region

let () = Logic_builtin.register {
    bl_name = lvalid_region;
    bl_labels = [FormalLabel "A"] ;
    bl_params = [] ;
    bl_type = None ;
    bl_profile = [
      "ptr", Ctype Cil_const.voidConstPtrType ;
      "size", Linteger ;
    ];
  }

let pvalid_region ?loc ?names ?(label=Logic_const.here_label) addr =
  let f = List.hd @@ Logic_env.find_all_logic_functions lvalid_region in
  let te = Logic_typing.ctype_of_pointed addr.term_type in
  let size = Logic_const.term ?loc (TSizeOf te) Linteger in
  Logic_const.papp ?loc ?names (f,[label],[addr;size])

(* -------------------------------------------------------------------------- *)
(* ---  Side Conditions                                                   --- *)
(* -------------------------------------------------------------------------- *)

type addr =
  | L of Lval.t
  | E of Exp.t
  | T of Term.t * Typ.t
  | R of Term.t * Typ.t * Term.t * Term.t
[@@ deriving eq]

let pp_addr fmt = function
  | L lv -> Format.fprintf fmt "&(%a)" Printer.pp_lval lv
  | E p -> Printer.pp_exp fmt p
  | T(p,_) -> Printer.pp_term fmt p
  | R(a,_,p,q) ->
    Format.fprintf fmt "&(%a[%a..%a])"
      Printer.pp_term a Printer.pp_term p Printer.pp_term q

type access = Read | Write | Region | Initialized [@@ deriving eq]

type guard =
  | True | Invalid of guard
  | Named of string * guard
  | Or of guard * guard
  | And of guard * guard
  | Imply of guard * guard
  | Bounds of Exp.t * Z.t
  | Null of bool * addr
  | Valid of access * addr
  | Separated of addr * addr
[@@ deriving eq]

let rec pp_guard fmt = function
  | True -> Format.pp_print_string fmt "\\true"
  | Invalid p -> Format.fprintf fmt "\\false/* %a */" pp_guard p
  | Named(a,p) -> Format.fprintf fmt "%s: %a" a pp_guard p
  | Or(p,q) -> Format.fprintf fmt "(@[<hov 2>%a@ || %a)@]" pp_guard p pp_guard q
  | And(p,q) -> Format.fprintf fmt "(@[<hov 2>%a@ && %a)@]" pp_guard p pp_guard q
  | Imply(p,q) -> Format.fprintf fmt "(@[<hov 2>%a@ ==> %a)@]" pp_guard p pp_guard q
  | Bounds(k,n) -> Format.fprintf fmt "0<= %a < %a" Printer.pp_exp k Z.pretty n
  | Null(eq,a) -> Format.fprintf fmt "(%a %c= \\null)" pp_addr a (if eq then '=' else '!')
  | Valid(Write,a) -> Format.fprintf fmt "\\valid(%a)" pp_addr a
  | Valid(Read,a) -> Format.fprintf fmt "\\valid_read(%a)" pp_addr a
  | Valid(Region,a) -> Format.fprintf fmt "\\valid_region(%a)" pp_addr a
  | Valid(Initialized,a) -> Format.fprintf fmt "\\initialized(%a)" pp_addr a
  | Separated(a,b) -> Format.fprintf fmt "\\separated(%a,%a)" pp_addr a pp_addr b

let rec trivial = function True -> true | Named(_,g) -> trivial g | _ -> false
let rec invalid = function Invalid _ -> true | Named(_,g) -> invalid g | _ -> false
let rec falsy = function Invalid p -> p | Named(_,g) -> falsy g | g -> g

let pointed = function
  | L lv -> Cil.typeOfLval lv
  | E p -> Ast_types.pointed_type @@ Cil.typeOf p
  | T(_,te) | R(_,te,_,_) -> te

let is_zero t =
  match t.term_node with
  | TConst(Integer(z,_)) -> Z.is_zero z
  | _ -> false

(* -------------------------------------------------------------------------- *)
(* ---  Smart Constructors                                                --- *)
(* -------------------------------------------------------------------------- *)

let g_true = True
let g_invalid p = Invalid p
let g_name a g = if a <> "" then Named(a,g) else g

let g_null ?(eq=true) = function
  | R(p,t,_,_) -> Null(eq,T(p,t))
  | L(Var _,_) as addr -> if eq then Invalid (Null(eq,addr)) else True
  | addr -> Null(eq,addr)

let g_and p q =
  match p,q with
  | True,w | w,True -> w
  | Invalid _,_ -> p
  | _,Invalid _ -> q
  | _ -> And(p,q)

let g_or p q =
  match p,q with
  | True,_ | _,True -> True
  | Invalid _,w | w,Invalid _ -> w
  | _ -> Or(p,q)

let rec filter hyp = function
  | Or(p,q) -> g_or (filter hyp p) (filter hyp q)
  | And(p,q) -> g_and (filter hyp p) (filter hyp q)
  | Imply(p,q) ->
    if equal_guard hyp p
    then filter hyp q
    else Imply(filter hyp p, filter hyp q)
  | p ->
    if equal_guard hyp p then True else p

let g_imply p q =
  match p,q with
  | True,_ -> q
  | Invalid _,_ | _,True -> True
  | Null(eq,a) , Invalid _ -> Null(not eq,a)
  | _ -> if equal_guard p q then True else Imply(p,filter p q)

let g_bounds e n = Bounds(e,n)
let g_valid acs p = Valid(acs,p)
let g_separated p q = Separated(p,q)

(* -------------------------------------------------------------------------- *)
(* ---  Extraction                                                        --- *)
(* -------------------------------------------------------------------------- *)

let of_addr ?loc = function
  | L lv ->
    let lv = Logic_utils.lval_to_term_lval lv in
    Logic_utils.mk_logic_AddrOf ?loc lv @@ Cil.typeOfTermLval lv
  | E ptr ->
    Logic_utils.expr_to_term ~coerce:true ptr
  | T(ptr,_) -> ptr
  | R(a,t,p,q) ->
    if is_zero p && is_zero q then a else
      let index =
        if Term.equal p q then p
        else Logic_const.trange ?loc (Some p,Some q)
      in Logic_const.term ?loc
        (TBinOp(PlusPI,a,index))
        (Ctype (Cil_const.mk_tptr t))

(* Names are only set at top-level predicate *)
let rec of_guard ?loc ?(names=[]) = function
  | True -> Logic_const.prepend_names ~names @@ Logic_const.ptrue
  | Invalid p -> of_guard ?loc ~names p
  | Named(a,p) -> of_guard ?loc ~names:(names @ [a]) p
  | Or(p,q) -> Logic_const.por ?loc ~names (of_guard ?loc p , of_guard ?loc q)
  | And(p,q) -> Logic_const.pand ?loc ~names (of_guard ?loc p , of_guard ?loc q)
  | Imply(p,q) -> Logic_const.pimplies ?loc ~names (of_guard ?loc p , of_guard ?loc q)
  | Bounds(k,n) ->
    let z = Logic_const.tinteger ?loc 0 in
    let n = Logic_const.tint ?loc n in
    let k = Logic_utils.expr_to_term ~coerce:true k in
    let inf = Logic_const.pred ?loc (Prel(Rle,z,k)) in
    let sup = Logic_const.pred ?loc (Prel(Rlt,k,n)) in
    Logic_const.pand ?loc ~names (inf,sup)
  | Null(eq,a) ->
    let addr = of_addr ?loc a in
    let null = Logic_const.term ?loc Tnull addr.term_type in
    let rel = if eq then Req else Rneq in
    Logic_const.prel ?loc ~names (rel,addr,null)
  | Valid(Write,p) ->
    Logic_const.(pvalid ?loc ~names (here_label, of_addr ?loc p))
  | Valid(Read,p) ->
    Logic_const.(pvalid_read ?loc ~names (here_label, of_addr ?loc p))
  | Valid(Initialized,p) ->
    Logic_const.(pinitialized ?loc ~names (here_label, of_addr ?loc p))
  | Valid(Region,p) -> pvalid_region ?loc ~names @@ of_addr ?loc p
  | Separated(a,b) ->
    Logic_const.pseparated ?loc ~names [ of_addr ?loc a ; of_addr ?loc b ]

(* -------------------------------------------------------------------------- *)
