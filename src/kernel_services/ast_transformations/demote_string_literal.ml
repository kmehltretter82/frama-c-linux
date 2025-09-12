(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

open Cil_types

let to_seq_string loc s =
  let len = String.length s in
  let gen i =
    if i >= len then
      Some (Cil.new_exp ~loc (Const (CChr '\000')),i)
    else
      Some (Cil.new_exp ~loc (Const (CChr s.[i])),i+1)
  in
  Seq.unfold gen 0

let to_seq_wstring loc s =
  let kind = Machine.wchar_kind () in
  let gen = function
    | [] -> Some (Cil.kinteger ~loc kind 0, [])
    | wchar :: tl ->
      let transf =
        if Machine.char_is_unsigned() then Z.of_int64_unsigned else Z.of_int64
      in
      Some (Cil.kinteger64 ~loc ~kind (transf wchar),tl)
  in
  Seq.unfold gen s

let to_seq_idx up =
  let gen i =
    if Z.lt i up then
      Some (i, Z.succ i)
    else None
  in
  Seq.unfold gen Z.zero

let init_idx loc idx elt =
  let kind = Machine.sizeof_kind () in
  Index (Cil.kinteger64 ~loc ~kind idx, NoOffset), SingleInit elt

let mk_array_init loc dest src =
  let s = Globals.Vars.get_string_literal src in
  let len, elts =
    match s with
    | Str s -> String.length s, to_seq_string loc s
    | Wstr s -> List.length s, to_seq_wstring loc s
  in
  let _,alen = Ast_types.array_elem_type_and_size dest.vtype in
  let alen = Option.bind Cil.constFoldToInt alen in
  let alen = Option.value ~default:(Z.of_int (len + 1)) alen in
  let idx = to_seq_idx alen in
  let l = Seq.map2 (init_idx loc) idx elts in
  CompoundInit (dest.vtype,List.of_seq l)

class demote vi =
  object
    inherit Visitor.frama_c_inplace

    method! vinst i =
      match i with
      | Local_init(
          dest,AssignInit(SingleInit { enode = Lval(Var src,NoOffset) }),loc)
        when Cil_datatype.Varinfo.equal vi src ->
        let new_init = mk_array_init loc dest src in
        Ast.mark_as_changed();
        ChangeTo [Local_init(dest,AssignInit new_init,loc)]
      | _ -> Cil.SkipChildren
  end

let demote vi =
  if Ast_info.is_string_literal vi then begin
    let vis = new demote vi in
    Visitor.visitFramacFileSameGlobals vis (Ast.get());
    vi.vattr <- Ast_attributes.(drop fc_literal vi.vattr)
  end
