(**************************************************************************)
(*                                                                        *)
(*  This file is part of the Frama-C's E-ACSL plug-in.                    *)
(*                                                                        *)
(*  Copyright (C) 2012-2018                                               *)
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

(* Implements Figure 3 of J. Signoles' JFLA'15 paper "Rester statique pour
   devenir plus rapide, plus précis et plus mince".
   Also implements a partial support for real numbers. *)

(* ********************************************************************* *)
(* Basic datatypes and operations *)
(* ********************************************************************* *)

exception Is_a_real
exception Not_a_number
(* Not_a_number has priority over Is_a_real *)

exception Not_an_integer

(* constructors *)

let singleton_of_int n = Ival.inject_singleton (Integer.of_int n)

let interv_of_unknown_block =
  (* since we have no idea of the size of this block, we take the largest
     possible one which is unfortunately quite large *)
  lazy
    (Ival.inject_range
       (Some Integer.zero)
       (Some (Bit_utils.max_byte_address ())))

(* The boolean indicates whether we have real numbers *)
let rec interv_of_typ_with_real ty is_real = match Cil.unrollType ty with
  | TInt (k,_) as ty ->
    let n = Cil.bitsSizeOf ty in
    let l, u =
      if Cil.isSigned k then Cil.min_signed_number n, Cil.max_signed_number n
      else Integer.zero, Cil.max_unsigned_number n
    in
    Ival.inject_range (Some l) (Some u), is_real
  | TEnum(enuminfo, _) ->
    interv_of_typ_with_real (TInt (enuminfo.ekind, [])) is_real
  | TFloat _ ->
    (* TODO: Do not systematically consider floats as reals for efficiency *)
    Ival.bottom, true
  | _ when Real.is_t ty ->
    Ival.bottom, true
  | _ ->
    raise Not_a_number

let interv_of_logic_typ = function
  | Ctype ty -> interv_of_typ_with_real ty false
  | Linteger -> Ival.inject_range None None, false
  | Lreal -> Ival.bottom, true
  | Ltype _ -> Error.not_yet "user-defined logic type"
  | Lvar _ -> Error.not_yet "type variable"
  | Larrow _ -> Error.not_yet "functional type"

let ikind_of_interv i =
  if Ival.is_bottom i then IInt
  else match Ival.min_and_max i with
    | Some l, Some u ->
      let is_pos = Integer.ge l Integer.zero in
      let lkind = Cil.intKindForValue l is_pos in
      let ukind = Cil.intKindForValue u is_pos in
      (* kind corresponding to the interval *)
      let kind = if Cil.intTypeIncluded lkind ukind then ukind else lkind in
      (* convert the kind to [IInt] whenever smaller. *)
      if Cil.intTypeIncluded kind IInt then IInt else kind
    | None, None -> raise Cil.Not_representable (* GMP *)
    | None, Some _ | Some _, None ->
      Kernel.fatal ~current:true "ival: %a" Ival.pretty i

(* Imperative environments *)
module rec Env: sig
  val clear: unit -> unit
  val add: Cil_types.logic_var -> Ival.t -> unit
  val find: Cil_types.logic_var -> Ival.t
  val remove: Cil_types.logic_var -> unit
  val replace: Cil_types.logic_var -> Ival.t -> unit
end = struct
  open Cil_datatype
  let tbl: Ival.t Logic_var.Hashtbl.t = Logic_var.Hashtbl.create 7

  let add = Logic_var.Hashtbl.add tbl
  let remove = Logic_var.Hashtbl.remove tbl
  let replace = Logic_var.Hashtbl.replace tbl
  let find = Logic_var.Hashtbl.find tbl

  let clear () =
    Logic_var.Hashtbl.clear tbl;
    Logic_function_env.clear ()

end

(* Environment for handling recursive logic functions *)
and Logic_function_env: sig
  val widen:
    infer_with_real:(term -> bool -> Ival.t * bool) -> term -> Ival.t
    -> bool * Ival.t
  val clear: unit -> unit
end = struct

  module Profile =
    Datatype.List_with_collections
      (Ival)
      (struct
        let module_name = "E_ACSL.Interval.Logic_function_env.Profile"
      end)

  module LF =
    Datatype.Pair_with_collections
      (Datatype.String)
      (Profile)
      (struct
        let module_name = "E_ACSL.Interval.Logic_function_env.LF"
      end)

  let tbl = LF.Hashtbl.create 7

  let clear () = LF.Hashtbl.clear tbl

  let interv_of_typ_containing_interv i =
    try
      let kind = ikind_of_interv i in
      interv_of_typ_with_real (TInt(kind, [])) false
    with Cil.Not_representable ->
      (* infinity *)
      Ival.inject_range None None, false

  let extract_profile ~infer_with_real t = match t.term_node with
    | Tapp(li, _, args) ->
      li.l_var_info.lv_name,
      List.map2
        (fun param arg ->
           try
             (* TODO RATIONAL: what if a rational is used as argument or
                returned? *)
             let i, _is_real = infer_with_real arg false in
             (* over-approximation of the interval to reach the fixpoint
                faster, and to generate fewer specialized functions *)
             let larger_i, _is_real = interv_of_typ_containing_interv i in
             (* TODO RATIONAL: what to do with is_real? *)
             Env.add param larger_i;
             larger_i
           with Not_an_integer ->
             (* no need to add [param] to the environment *)
             Ival.bottom)
        li.l_profile
        args
    | _ ->
      assert false

  let widen ~infer_with_real t i =
    let p = extract_profile ~infer_with_real t in
    try
      let old_i = LF.Hashtbl.find tbl p in
      if Ival.is_included i old_i then true, old_i
      else begin
        let j = Ival.join i old_i in
        LF.Hashtbl.replace tbl p j;
        false, j
      end
    with Not_found ->
      LF.Hashtbl.add tbl p i;
      false, i

end

(* ********************************************************************* *)
(* Main algorithm *)
(* ********************************************************************* *)

let infer_sizeof ty is_real =
  try singleton_of_int (Cil.bytesSizeOf ty), is_real
  with Cil.SizeOfError _ ->
    interv_of_typ_with_real Cil.theMachine.Cil.typeOfSizeOf is_real

let infer_alignof ty = singleton_of_int (Cil.bytesAlignOf ty)

let rec infer_with_real t is_real =
  let get_cty t = match t.term_type with Ctype ty -> ty | _ -> assert false in
  match t.term_node with
  | TConst (Integer (n,_)) -> Ival.inject_singleton n, is_real
  | TConst (LChr c) ->
    let n = Cil.charConstToInt c in
    Ival.inject_singleton n, is_real
  | TConst (LEnum enumitem) ->
    let rec find_idx n = function
      | [] -> assert false
      | ei :: l -> if ei == enumitem then n else find_idx (n + 1) l
    in
    let n = Integer.of_int (find_idx 0 enumitem.eihost.eitems) in
    Ival.inject_singleton n, is_real
  | TLval lv -> infer_term_lval lv is_real
  | TSizeOf ty -> infer_sizeof ty is_real
  | TSizeOfE t -> infer_sizeof (get_cty t) is_real
  | TSizeOfStr str ->
    singleton_of_int (String.length str + 1 (* '\0' *)), is_real
  | TAlignOf ty -> infer_alignof ty, is_real
  | TAlignOfE t -> infer_alignof (get_cty t), is_real

  | TUnOp (Neg, t) ->
    let i, is_real = infer_with_real t is_real in
    Ival.neg_int i, is_real
  | TUnOp (BNot, t) ->
    let i, is_real = infer_with_real t is_real in
    Ival.bitwise_signed_not i, is_real
  | TUnOp (LNot, _)

  | TBinOp ((Lt | Gt | Le | Ge | Eq | Ne | LAnd | LOr), _, _) ->
    Ival.zero_or_one, is_real
  | TBinOp (PlusA, t1, t2) ->
    let i1, is_real1 = infer_with_real t1 is_real in
    let i2, is_real2 = infer_with_real t2 is_real in
    Ival.add_int i1 i2, is_real1 || is_real2
  | TBinOp (MinusA, t1, t2) ->
    let i1, is_real1 = infer_with_real t1 is_real in
    let i2, is_real2 = infer_with_real t2 is_real in
    Ival.sub_int i1 i2, is_real1 || is_real2
  | TBinOp (Mult, t1, t2) ->
    let i1, is_real1 = infer_with_real t1 is_real in
    let i2, is_real2 = infer_with_real t2 is_real in
    Ival.mul i1 i2, is_real1 || is_real2
  | TBinOp (Div, t1, t2) ->
    let i1, is_real1 = infer_with_real t1 is_real in
    let i2, is_real2 = infer_with_real t2 is_real in
    Ival.div i1 i2, is_real1 || is_real2
  | TBinOp (Mod, t1, t2) ->
    let i1, is_real1 = infer_with_real t1 is_real in
    let i2, is_real2 = infer_with_real t2 is_real in
    Ival.c_rem i1 i2, is_real1 || is_real2
  | TBinOp (Shiftlt , _, _) -> Error.not_yet "right shift"
  | TBinOp (Shiftrt , _, _) -> Error.not_yet "left shift"
  | TBinOp (BAnd, _, _) -> Error.not_yet "bitwise and"
  | TBinOp (BXor, t1, t2) ->
    let i1, is_real1 = infer_with_real t1 is_real in
    let i2, is_real2 = infer_with_real t2 is_real in
    Ival.bitwise_xor i1 i2, is_real1 || is_real2
  | TBinOp (BOr, t1, t2) ->
    let i1, is_real1 = infer_with_real t1 is_real in
    let i2, is_real2 = infer_with_real t2 is_real in
    Ival.bitwise_or i1 i2, is_real1 || is_real2
  | TCastE (ty, t) ->
    (try
       let it, is_real1 = infer_with_real t is_real in
       let ity, is_real2 = interv_of_typ_with_real ty is_real in
       Ival.meet it ity, is_real1 || is_real2
     with Not_a_number ->
       if Cil.isIntegralType ty then begin
         (* heterogeneous cast from a non-integral term to an integral type:
            consider that one eventually gets an integral type even if it is
            not sure. *)
         Options.warning
           ~once:true "possibly unsafe cast from term '%a' to type '%a'."
           Printer.pp_term t
           Printer.pp_typ ty;
         interv_of_typ_with_real ty is_real
       end else
         raise Not_a_number)
  | Tif (_, t2, t3) ->
    let i2, is_real2 = infer_with_real t2 is_real in
    let i3, is_real3 = infer_with_real t3 is_real in
    Ival.join i2 i3, is_real2 || is_real3
  | Tat (t, _) ->
    infer_with_real t is_real
  | TBinOp (MinusPP, t, _) ->
    (match Cil.unrollType (get_cty t) with
     | TArray(_, _, { scache = Computed n (* size in bits *) }, _) ->
       (* the second argument must be in the same block than [t]. Consequently
          the result of the difference belongs to [0; \block_length(t)] *)
       let nb_bytes = if n mod 8 = 0 then n / 8 else n / 8 + 1 in
       let i =
         Ival.inject_range (Some Integer.zero) (Some (Integer.of_int nb_bytes))
       in
       i, is_real
     | TArray _ | TPtr _ -> Lazy.force interv_of_unknown_block, is_real
     | _ -> assert false)
  | Tblock_length (_, t)
  | Toffset(_, t) ->
    (match Cil.unrollType (get_cty t) with
     | TArray(_, _, { scache = Computed n (* size in bits *) }, _) ->
       let nb_bytes = if n mod 8 = 0 then n / 8 else n / 8 + 1 in
       singleton_of_int nb_bytes, is_real
     | TArray _ | TPtr _ -> Lazy.force interv_of_unknown_block, is_real
     | _ -> assert false)
  | Tnull  -> singleton_of_int 0, is_real
  | TLogic_coerce (_, t) -> infer_with_real t is_real

  | Tapp (li, _, _args) ->
    (match li.l_body with
     | LBpred _ ->
       Ival.zero_or_one, false
     | LBterm t' ->
       let rec fixpoint i =
         let is_included, new_i =
           Logic_function_env.widen ~infer_with_real t' i
         in
         if is_included then begin
           List.iter (fun lv -> Env.remove lv) li.l_profile;
           (* TODO RATIONAL: check if returning [false] is correct *)
           new_i, false
         end else
           (* TODO RATIONAL: check if [false] is the correct value *)
           (* TODO RATIONAL: what if a real is returned? *)
           let i, _ = infer_with_real t' false in
           List.iter (fun lv -> Env.remove lv) li.l_profile;
           fixpoint i
       in
       fixpoint Ival.bottom
     | LBnone
     | LBreads _ ->
       (match li.l_type with
       | None -> assert false
       | Some ret_type -> interv_of_logic_typ ret_type)
     | LBinductive _ ->
       Error.not_yet "logic functions inductively defined")

  | Tunion _ -> Error.not_yet "tset union"
  | Tinter _ -> Error.not_yet "tset intersection"
  | Tcomprehension (_,_,_) -> Error.not_yet "tset comprehension"
  | Trange(Some n1, Some n2) ->
    let i1, is_real1 = infer_with_real n1 is_real in
    let i2, is_real2 = infer_with_real n2 is_real in
    Ival.join i1 i2, is_real1 || is_real2
  | Trange(None, _) | Trange(_, None) ->
    Options.abort "unbounded ranges are not part of E-ACSl"

  | Tlet (li,t) ->
    let li_t = Misc.term_of_li li in
    let li_v = li.l_var_info in
    let i, is_real = infer_with_real li_t is_real in
    Env.add li_v i;
    let i, is_real = infer_with_real t is_real in
    Env.remove li_v;
    i, is_real
  | TConst (LReal _) ->
    Ival.bottom, true
  | TConst (LStr _ | LWStr _)
  | TBinOp (PlusPI,_,_)
  | TBinOp (IndexPI,_,_)
  | TBinOp (MinusPI,_,_)
  | TAddrOf _
  | TStartOf _
  | Tlambda (_,_)
  | TDataCons (_,_)
  | Tbase_addr (_,_)
  | TUpdate (_,_,_)
  | Ttypeof _
  | Ttype _
  | Tempty_set ->
    raise Not_a_number

and infer_term_lval (host, offset as tlv) is_real =
  match offset with
  | TNoOffset -> infer_term_host host is_real
  | _ ->
    let ty = Logic_utils.logicCType (Cil.typeOfTermLval tlv) in
    interv_of_typ_with_real ty is_real

and infer_term_host thost is_real =
  match thost with
  | TVar v ->
    (try Env.find v, is_real
     with Not_found ->
     match v.lv_type with
     | Linteger ->
       Ival.inject_range None None, false
     | Ctype (TFloat _) -> (* TODO: handle in MR !226 *)
       raise Not_an_integer
     | Lreal ->
       Ival.bottom, true
     | Ctype _ ->
       (* TODO RATIONAL: check if [false] is the correct value *)
       interv_of_typ_with_real (Logic_utils.logicCType v.lv_type) false
     | Ltype _ | Lvar _ | Larrow _ ->
       Options.fatal "unexpected logic type")
  | TResult ty ->
    interv_of_typ_with_real ty is_real
  | TMem t ->
    let ty = Logic_utils.logicCType t.term_type in
    match Cil.unrollType ty with
    | TPtr(ty, _) | TArray(ty, _, _, _) ->
      interv_of_typ_with_real ty is_real
    | _ ->
      Options.fatal "unexpected type %a for term %a"
        Printer.pp_typ ty
        Printer.pp_term t

let infer t =
  let i, is_real = infer_with_real t false in
  if is_real then raise Is_a_real else i

let interv_of_typ ty =
  let i, is_real = interv_of_typ_with_real ty false in
  if is_real then raise Is_a_real else i

(*
Local Variables:
compile-command: "make"
End:
 *)
