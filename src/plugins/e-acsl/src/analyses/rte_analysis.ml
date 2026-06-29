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

  type kind =
    | Division_by_zero
    | Out_of_bounds
    | Memory_access
    | Initialized
    | Pointer_alignment

  type guard = { kind: kind; pred: predicate }

  module Terms = Terms.Id.Hashtbl

  let tbl = Terms.create 10

  let add t g =
    if not @@ Logic_utils.is_trivially_true g.pred then
      match Terms.find_opt tbl t with
      | Some guards -> Terms.replace tbl t (g :: guards)
      | None -> Terms.add tbl t [g]

  let add_list t guards =
    match Terms.find_opt tbl t with
    | Some guards' -> Terms.replace tbl t (guards @ guards')
    | None -> Terms.add tbl t guards

  let iter_on_guards t f =
    match Terms.find_opt tbl t with
    | Some guards -> List.iter (fun g -> f g.pred) guards
    | _ -> ()

  let fold_guards ~default t f =
    match Terms.find_opt tbl t with
    | Some guards -> List.fold_left (fun x g -> f g.pred x) default guards
    | _ -> default

  let copy t_src t_dst =
    match Terms.find_opt tbl t_src with
    | Some guards -> add_list t_dst guards
    | None -> ()

  let remove t = Terms.remove tbl t

  let mem_guard_kind t kind =
    match Terms.find_opt tbl t with
    | Some guards -> List.exists (fun g' -> g'.kind = kind) guards
    | None -> false

  let clear () = Terms.clear tbl

  let pretty fmt () =
    let pp_data fmt d =
      Pretty_utils.pp_list
        ~pre:"[" ~suf:"]" ~sep:";@ "
        Printer.pp_predicate fmt (List.map (fun g -> g.pred) d)
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

  (** [needs_pointer_alignment ()] @return
      - [true] if the option [-warn-unaligned-pointer] is used (default);
      - [false] if the option [-no-warn-unaligned-pointer] is used. *)
  let needs_pointer_alignment () =
    if Kernel.UnalignedPointer.is_set ()
    then not @@ Kernel.UnalignedPointer.get ()
    else true
end

(** The module [Undefined_behaviours] contains functions that makes a guard for
    each kind of undefined behavior listed below:
    - division by zero
    - memory access (read)
    - index out of bounds
    - initialization
    - pointer alignment *)
module Undefined_behaviours =
struct

  let mk_guard kind pred = Guards.{kind; pred}

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
    mk_guard Division_by_zero pred

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
    mk_guard Memory_access pred

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
    mk_guard Out_of_bounds pred

  (** [initialized ~loc ?label lv typ] creates the predicate that check if [lv]
      is initialized. *)
  let initialized ~loc ?(label = Logic_const.here_label) lv =
    let addr = Terms.mk_TAddrOrTStartOf ~loc lv in
    let pred =
      Logic_const.pinitialized ~loc ~names:["uninitialized"] (label, addr)
    in
    preprocess_guard pred;
    mk_guard Initialized pred

  (** [pointer_alignment ~loc t typ] creates the predicate that check if [t] is
      aligned regards of [typ]. *)
  let pointer_alignment ~loc t typ =
    let pred =
      Logic_const.paligned
        ~loc
        ~names:["pointer alignment"]
        (Smart_term.copy t, Smart_term.talignof ~loc typ)
    in
    preprocess_guard pred;
    mk_guard Pointer_alignment pred

end

let rte_visitor =
  object(self)

    inherit E_acsl_visitor.visitor dkey

    method private trivially_aligned t typ ptyp: bool =
      if Ast_types.C.is_void ptyp || Ast_types.C.is_fun ptyp
      then
        (* - From an alignment point of view, casting to void* is always OK
            (except for function pointers, but anyway, the problem is not
            alignment)
           - Alignment does not make sense for functions *)
        true
      else
        let typ_align = Cil.bytesAlignOf ptyp in
        if Ast_types.C.is_void_ptr typ || Ast_types.C.is_fun_ptr typ
        then false
        else
        if Ast_types.C.is_integral typ
        then match Logic_utils.constFoldTermToInt t with
          | Some value when Z.(zero = (value mod of_int typ_align)) -> true
          | _ -> false
        else
          match t.term_node with
          | TAddrOf (TVar vi, TNoOffset) | TStartOf (TVar vi, TNoOffset) ->
            Option.fold ~none:false
              ~some:(fun v ->
                  0 = Cil.bytesAlignOfVarinfo v mod typ_align)
              (vi.lv_origin)
          | _ -> false

    (** [skip_pointer_alignment t] @return [true] if [t] already has a
        [Pointer_alignment] kind guard in the table. *)
    method private skip_pointer_alignment t =
      Guards.mem_guard_kind t Pointer_alignment

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

    method private add_array_comparison tl tr =
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
    method private add_initialized ~orig ~loc lv typ =
      let needs_guard lv =
        match lv with
        | TVar { lv_origin = Some vi }, _ ->
          not (vi.vglob || vi.vformal || vi.vtemp) &&
          not (Ast_types.C.is_struct_or_union typ)
        | _ -> false
      in
      if Flags.needs_initialized () && needs_guard lv then
        Guards.add orig (Undefined_behaviours.initialized ~loc lv)

    (** [add_aligned ~orig t typ] adds an entry for [orig] if [t] has a pointer
        type. *)
    method private add_aligned ~orig t typ =
      if Flags.needs_pointer_alignment () &&
         not (self#skip_pointer_alignment orig) then begin
        (* The type has to be a pointer type, otherwise the function
           [Ast_types.direct_pointed_type] can fail. *)
        assert (Ast_types.C.is_ptr typ);
        let pointed_typ = Ast_types.C.direct_pointed typ in
        let t = Cil.stripTermCasts t in
        if not (Options.Optimisations.Omit_trivial_rte.get ()) ||
           not (self#trivially_aligned t typ pointed_typ)
        then
          Guards.add orig
            (Undefined_behaviours.pointer_alignment
               ~loc:orig.term_loc t pointed_typ)
      end

    method private add_aligned_cast ~orig t dst =
      let aux src =
        match Ast_types.C.unroll_node src,  Ast_types.C.unroll_node dst with
        (* From int, To pointer *)
        | TInt _, TPtr _ -> self#add_aligned ~orig orig dst
        (* From pointer, To pointer *)
        | TPtr _, TPtr _ -> self#add_aligned ~orig t dst
        | _ -> ()
      in
      match Ast_types.Acsl.unroll t.term_type with
      | Ctype src -> aux src
      | _ -> ()

    method private add_aligned_access lv =
      match lv with
      | TMem ({term_type = Ctype typ} as t), _ -> self#add_aligned ~orig:t t typ
      | _ -> ()

    method !vterm t =
      begin match t.term_node with
        | TBinOp ((Div | Mod),_,divider) -> self#add_div_mod ~orig:t divider
        | TLval lv ->
          begin match Ast_types.Acsl.unroll t.term_type with
            | Ctype typ ->
              self#add_mem_access ~orig:t lv;
              self#add_initialized ~orig:t ~loc:t.term_loc lv typ;
              self#add_aligned_access lv;
              if Ast_types.C.is_ptr typ then self#add_aligned ~orig:t t typ
            | _ -> ()
          end
        (* [false] means an explicit cast into a C type *)
        | TCast (false,ty,t') ->
          begin match Ast_types.Acsl.unroll ~unroll_typedef:false ty with
            | Ctype dst -> self#add_aligned_cast ~orig:t t' dst
            | _ ->
              Options.fatal
                "Explicit conversion to a C type, but %a is not a C type"
                Printer.pp_logic_type ty
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
  if not @@ Options.Optimisations.Omit_rte.get ()
  then begin
    ignore @@ rte_visitor#visit_file ast;
    Options.feedback ~dkey:dkey "Result of the RTE analysis.%!";
    Options.feedback ~dkey:dkey "%a%!" Guards.pretty ()
  end else
    Options.feedback ~dkey:dkey "Skip the RTE analysis.%!"

let preprocess_predicate p =
  if not @@ Options.Optimisations.Omit_rte.get ()
  then begin
    ignore @@ rte_visitor#visit_predicate p;
    Options.feedback ~dkey "Result of the RTE analysis on %a.%!"
      Printer.pp_predicate p;
    Options.feedback ~dkey:dkey "%a%!" Guards.pretty ()
  end else
    Options.feedback ~dkey:dkey "Skip the RTE analysis on %a.%!"
      Printer.pp_predicate p

let iter_on_guards = Guards.iter_on_guards

let fold_guards ~default = Guards.fold_guards ~default

let remove t = Guards.remove t

let clear () = Guards.clear ()
