(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

open Cil_types

let tsizeof ?(loc = Options.gen_loc) typ =
  if Options.Optimisations.Smart_cil.get () then
    try Logic_const.tint ~loc @@ Z.of_int @@ Cil.bytesSizeOf typ
    with Cil.SizeOfError _ -> Logic_const.term ~loc (TSizeOf typ) Linteger
  else Logic_const.term ~loc (TSizeOf typ) Linteger

let talignof ?(loc = Options.gen_loc) typ =
  if Options.Optimisations.Smart_cil.get () then
    try Logic_const.tint ~loc @@ Z.of_int @@ Cil.bytesAlignOf typ
    with Cil.SizeOfError _ -> Logic_const.term ~loc (TAlignOf typ) Linteger
  else Logic_const.term ~loc (TAlignOf typ) Linteger

let tblock_length ?(label = Logic_const.here_label) ?(loc = Options.gen_loc) t =
  Logic_const.term ~loc (Tblock_length (label,t)) Linteger

let toffset ?(label = Logic_const.here_label) ?(loc = Options.gen_loc) t =
  Logic_const.term ~loc (Toffset (label,t)) Linteger

let tbinop ?(loc = Options.gen_loc) binop t1 t2 =
  let tb = Logic_const.term ~loc (TBinOp (binop,t1,t2)) Linteger in
  if Options.Optimisations.Smart_cil.get () then try
      let z1 = Option.get @@ Terms.extract_integer t1 in
      let z2 = Option.get @@ Terms.extract_integer t2 in
      match binop with
      | PlusA -> Logic_const.tint ~loc @@ Z.add z1 z2
      | MinusA -> Logic_const.tint ~loc @@ Z.sub z1 z2
      | Mult -> Logic_const.tint ~loc @@ Z.mul z1 z2
      | _ -> tb
    with _ -> tb
  else tb

let copy t =
  if Options.Optimisations.Smart_cil.get () then
    match t.term_node with
    | TSizeOf typ -> tsizeof ~loc:t.term_loc typ
    | TAlignOf typ -> talignof ~loc:t.term_loc typ
    | _ -> Terms.Id.deep_copy t
  else Terms.Id.deep_copy t

let trange_array ?(loc = Options.gen_loc) t  =
  (* size(t) = (\block_length(array) - \offset(array)) / sizeof(typ) *)
  let approx typ =
    copy @@
    tbinop ~loc Div
      (tbinop MinusA (tblock_length t) (toffset t))
      (tsizeof typ)
  in
  let rec sizes typ =
    match Ast_types.C.unroll_deep_node typ with
    | TArray (elem_typ, Some size) ->
      Logic_utils.expr_to_term size :: sizes elem_typ
    | TArray (elem_typ, None) -> approx elem_typ :: sizes elem_typ
    | _ -> []
  in
  match t.term_node with
  | TLval lval ->
    begin match t.term_type with
      | Ctype typ ->
        let sizes = sizes typ in
        let range size =
          Logic_const.trange ~loc
            (Option.some @@ Logic_const.tint ~loc Z.zero,
             Option.some @@
             tbinop ~loc MinusA size (Logic_const.tint ~loc Z.one))
        in
        List.fold_left
          (fun lval size ->
             Logic_const.addTermOffsetLval (TIndex (range size, TNoOffset)) lval)
          lval
          sizes
      | _ ->  Options.fatal
                "Trying to retrieve an array length from logic type: %a"
                Printer.pp_logic_type t.term_type
    end
  | _ -> Options.fatal "not a left-value %a" Printer.pp_term t
