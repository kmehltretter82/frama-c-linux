(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

open Cil_types

let dkey = Options.Dkey.rte

(** [Guards] stores the pairs ([term],[predicate list]) created during the
    analysis. *)
module Guards =
struct

  module Terms = Misc.Id_term.Hashtbl

  let tbl = Terms.create 10

  let add t pred =
    if not @@ Logic_utils.is_trivially_true pred then
      match Terms.find_opt tbl t with
      | Some preds -> Terms.replace tbl t (pred :: preds)
      | None -> Terms.add tbl t [pred]

  let clear () = Terms.clear tbl

  let pretty fmt () =
    let pp_data fmt d =
      Pretty_utils.pp_list
        ~pre:"[" ~suf:"]" ~sep:";@ " Printer.pp_predicate fmt d
    in
    Terms.pretty
      ~item:(format_of_string "%a --> %a") Printer.pp_term pp_data fmt tbl
end

(** The module [Undefined_behaviours] contains functions that makes a guard for
    each kind of undefined behavior listed below:
    - division by zero *)
module Undefined_behaviours =
struct

  (** [div_by_zero ~loc divider] creates the predicate that checks if [divider]
      is not equal to [Z.zero]. The guard does not contain directly [divider]
      but a copy of it. *)
  let div_by_zero ~loc divider =
    let divider_cpy = Smart_term.copy divider in
    let pred =
      Smart_predicate.prel
        ~loc
        ~names:["division by zero"]
        Rneq
        divider_cpy
        (Logic_const.tint Z.zero)
    in
    pred

end

module Flags =
struct

  (** [needs_div_mod ()] @return:
      - [true] if the option [-rte-div] from the RTE plugin is used (default);
      - [false] if the option [-rte-no-div] from the RTE plugin is used. *)
  let needs_div_mod () =
    if RteGen.Options.DoDivMod.is_set ()
    then RteGen.Options.DoDivMod.get ()
    else true

end

let rte_visitor =
  object(self)

    inherit E_acsl_visitor.visitor dkey

    (** [add_div_mod orig divider] adds an entry for [orig] if [divider] can
        be equal to zero. *)
    method private add_div_mod ~orig divider =
      if Flags.needs_div_mod () then
        Guards.add orig
          (Undefined_behaviours.div_by_zero ~loc:orig.term_loc divider)

    method !vterm t =
      begin match t.term_node with
        | TBinOp ((Div | Mod),_,divider) -> self#add_div_mod ~orig:t divider
        | _ -> ()
      end;
      Cil.DoChildren

    method !vpredicate p =
      begin match p.pred_content with
        | Paligned (_,v) -> self#add_div_mod ~orig:v v
        | _ -> ()
      end;
      Cil.DoChildren
  end

let preprocess ast =
  ignore @@ rte_visitor#visit_file ast;
  Options.feedback ~dkey:dkey "Result of the RTE analysis.%!";
  Options.feedback ~dkey:dkey "%a%!" Guards.pretty ()

let clear () = Guards.clear ()
