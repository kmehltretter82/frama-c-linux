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

  module Terms = Terms.Id.Hashtbl

  let tbl = Terms.create 10

  let add t pred =
    if not @@ Logic_utils.is_trivially_true pred then
      match Terms.find_opt tbl t with
      | Some preds -> Terms.replace tbl t (pred :: preds)
      | None -> Terms.add tbl t [pred]

  let add_list t preds =
    match Terms.find_opt tbl t with
    | Some preds' -> Terms.replace tbl t (preds @ preds')
    | None -> Terms.add tbl t preds

  let apply ~default t f =
    match Terms.find_opt tbl t with
    | Some preds -> f preds
    | _ -> default

  let copy t_src t_dst =
    match Terms.find_opt tbl t_src with
    | Some preds -> add_list t_dst preds
    | None -> ()

  let remove t = Terms.remove tbl t

  let mem t = Terms.mem tbl t

  let clear () = Terms.clear tbl

  let pretty fmt () =
    let pp_data fmt d =
      Pretty_utils.pp_list
        ~pre:"[" ~suf:"]" ~sep:";@ " Printer.pp_predicate fmt d
    in
    Terms.pretty
      ~item:(format_of_string "%a --> %a") Printer.pp_term pp_data fmt tbl
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

  (** [needs_mem_access ()] @return:
      - [true] if the option [-rte-mem] from the RTE plugin is used (default);
      - [false] if the option [-rte-no-mem] from the RTE plugin is used; *)
  let needs_mem_access () =
    if RteGen.Options.DoMemAccess.is_set ()
    then RteGen.Options.DoMemAccess.get ()
    else true

  (** [needs_initialized ()] @return
      - [true] if the option [-rte-initialized] from the RTE plugin has at least
        one element in its set;
      - [false] if the option [-rte-no-initialized] from the RTE plugin is used
        (default); *)
  let needs_initialized () =
    if RteGen.Options.DoInitialized.is_set ()
    then not @@ RteGen.Options.DoInitialized.is_empty ()
    else true
end

(** The module [Undefined_behaviours] contains functions that makes a guard for
    each kind of undefined behavior listed below:
    - division by zero
    - memory access (read)
    - index out of bounds
    - initialization *)
module Undefined_behaviours =
struct

  let preprocess_guard guard =
    Logic_normalizer.preprocess_predicate guard;
    Bound_variables.preprocess_predicate guard

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
    preprocess_guard pred;
    pred

  (** [mem_access ~loc lv] creates the predicate that checks if [lv] is a
       valid read. *)
  let mem_access ~loc lv =
    let addr = Terms.mk_TAddrOrTStartOf ~loc lv in
    let pred =
      Logic_const.pvalid_read
        ~loc
        ~names:["memory access"]
        (Logic_const.here_label, addr)
    in
    preprocess_guard pred;
    pred

  (** [index_bound ~loc t size] creates the predicate that check if [t] is
      between [Z.zero] and the array's upper bound regards of its [size]. *)
  let index_bound ~loc t size =
    let t_cpy_1 = Smart_term.copy t in
    let t_cpy_2 = Smart_term.copy t in
    let pred =
      Smart_predicate.pand
        ~loc
        ~names:["index out of bounds"]
        (Smart_predicate.prel Rle (Logic_const.tint Z.zero) t_cpy_1)
        (Smart_predicate.prel Rlt t_cpy_2 (Logic_utils.expr_to_term size))
    in
    preprocess_guard pred;
    pred

  (** [initialized ~loc ?label lv typ] creates the predicate that check if [lv]
      is initialized. *)
  let initialized ~loc ?(label = Logic_const.here_label) lv =
    let addr = Terms.mk_TAddrOrTStartOf ~loc lv in
    let pred =
      Logic_const.pinitialized ~loc ~names:["uninitialized"] (label, addr)
    in
    preprocess_guard pred;
    pred
end

let rte_visitor =
  object(self)

    inherit E_acsl_visitor.visitor dkey

    (** [add_div_mod ~orig divider] adds an entry for [orig] if [divider] can
        be equal to zero. *)
    method private add_div_mod ~orig divider =
      if Flags.needs_div_mod () then
        Guards.add orig
          (Undefined_behaviours.div_by_zero ~loc:orig.term_loc divider)

    (** [add_index ~index size] adds [index] as key in [table] with a
            guard that checks if [index] is between [0] (included) and [size]
            (excluded). *)
    method private add_index ~index size =
      Guards.add index
        (Undefined_behaviours.index_bound ~loc:index.term_loc index size)

    (**
       [add_mem_access ~orig lv] checks if the lvalue [lv] is a
       variable or a dereference (other cases are not checked). In both, it
       calls the function [unroll_offset] with the information of being a
       dereference or not through the [~is_deref] argument.
    *)
    method private add_mem_access ~orig lv =
      let rec unroll_offset ~is_deref off typ =
        match off with
        | TNoOffset when is_deref ->
          Guards.add orig
            (Undefined_behaviours.mem_access ~loc:orig.term_loc lv)
        | TIndex (index, off) ->
          begin match Ast_types.C.unroll_node typ with
            | TArray (typ, Some size) ->
              self#add_index ~index size;
              unroll_offset ~is_deref off typ
            (* if no size provided, then we act as it is a dereferencement. *)
            | TArray (typ, None) -> unroll_offset ~is_deref:true off typ
            | _ ->
              Options.abort "%a is type %a but should be type array"
                Printer.pp_term_lval lv
                Printer.pp_typ typ
          end
        | TField (fi, off) -> unroll_offset ~is_deref off fi.ftype
        | _ -> ()
      in
      if Flags.needs_mem_access () then
        match lv with
        | TVar v, off ->
          begin match v.lv_type with
            | Ctype typ -> unroll_offset ~is_deref:false off typ
            | _ -> ()
          end
        | TMem lh, off ->
          if not @@ Ast_types.Acsl.is_plain_fun @@ Cil.typeOfTermLval lv
          then begin
            try
              unroll_offset ~is_deref:true off @@
              Ast_types.C.direct_pointed @@
              Ast_types.Acsl.get_ctype lh.term_type
            with  | _ ->
              Options.abort "%a is dereferenced but it is a not pointer type %a"
                Printer.pp_term_lval lv
                Printer.pp_logic_type lh.term_type
          end
        | _ -> ()

    method add_array_comparison tl tr =
      let both x y f = f x; f y in
      both tl tr @@ fun t ->
      let rt =
        Logic_const.term
          ~loc:t.term_loc
          (TLval (Smart_term.trange_array ~loc:t.term_loc t))
          (Ast_types.Acsl.direct_array_element t.term_type)
      in
      ignore @@ self#vterm rt;
      Guards.copy rt t

    (** [add_initialized ~orig ~loc divider] adds an entry for [orig] if [lv]
        is a variable. *)
    method add_initialized ~orig ~loc lv typ =
      let needs_guard lv =
        match lv with
        | TVar { lv_origin = Some vi }, _ ->
          not (vi.vglob || vi.vformal || vi.vtemp) &&
          not (Ast_types.C.is_struct_or_union typ)
        | _ -> false
      in
      if Flags.needs_initialized () && needs_guard lv then
        Guards.add orig (Undefined_behaviours.initialized ~loc lv)

    method !vterm t =
      begin match t.term_node with
        | TBinOp ((Div | Mod),_,divider) -> self#add_div_mod ~orig:t divider
        | TLval lv ->
          begin match Ast_types.Acsl.unroll t.term_type with
            | Ctype typ ->
              self#add_mem_access ~orig:t lv;
              self#add_initialized ~orig:t ~loc:t.term_loc lv typ
            | _ -> ()
          end
        | _ -> ()
      end;
      Cil.DoChildren

    method !vpredicate p =
      match p.pred_content with
      | Paligned (_,v) ->
        self#add_div_mod ~orig:v v;
        Cil.DoChildren
      | Prel((Req | Rneq),t1,t2) when Logic_utils.is_C_array t1 &&
                                      Logic_utils.is_C_array t2 ->
        self#add_array_comparison t1 t2;
        Cil.SkipChildren
      | _ -> (); Cil.DoChildren
  end

let preprocess ast =
  if Options.O.get () < 3
  then begin
    ignore @@ rte_visitor#visit_file ast;
    Options.feedback ~dkey:dkey "Result of the RTE analysis.%!";
    Options.feedback ~dkey:dkey "%a%!" Guards.pretty ()
  end else
    Options.feedback ~dkey:dkey "Skip the RTE analysis.%!"

let preprocess_predicate p =
  if Options.O.get () < 3
  then begin
    ignore @@ rte_visitor#visit_predicate p;
    Options.feedback ~dkey "Result of the RTE analysis on %a.%!"
      Printer.pp_predicate p;
    Options.feedback ~dkey:dkey "%a%!" Guards.pretty ()
  end else
    Options.feedback ~dkey:dkey "Skip the RTE analysis on %a.%!"
      Printer.pp_predicate p

let iter_on_guards t f = Guards.apply ~default:() t (List.iter f)

let fold_guards_il ~default t f =
  Guards.apply ~default t @@ List.fold_left (fun x y -> f y x) default

let fold_guards_old ~default t f =
  (* [collect t] returns the RTE guards associated to [t] and its sub-terms. *)
  let collect t =
    let preds = ref [] in
    let collector =
      object
        inherit Visitor.frama_c_inplace
        method! vterm t =
          Guards.apply ~default:() t (fun p -> preds := p @ !preds; Guards.remove t);
          match t.term_node with
          (* warning: we do not retrieve RTE guards from [Tif] sub-terms *)
          | Tif _ -> Cil.SkipChildren
          | _ -> Cil.DoChildren
      end in
    if Guards.mem t then ignore @@ Visitor.visitFramacTerm collector t;
    !preds
  in
  List.fold_left (fun x y -> f y x) default (collect t)

let remove t = Guards.remove t

let clear () = Guards.clear ()
