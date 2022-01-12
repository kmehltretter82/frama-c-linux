(**************************************************************************)
(*                                                                        *)
(*  This file is part of the Frama-C's E-ACSL plug-in.                    *)
(*                                                                        *)
(*  Copyright (C) 2012-2021                                               *)
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

(** Labeled term and predicates pre-analysis *)

open Cil_types
open Cil_datatype
open Analyses_types
open Analyses_datatype
let dkey = Options.Dkey.labels
module Error = Error.Make(struct let phase = dkey end)

(**************************************************************************)
(********************** Forward references ********************************)
(**************************************************************************)

let must_translate_ppt_ref : (Property.t -> bool) ref =
  Extlib.mk_fun "must_translate_ppt_ref"

let must_translate_ppt_opt_ref : (Property.t option -> bool) ref =
  Extlib.mk_fun "must_translate_ppt_opt_ref"

let has_empty_quantif_ref: ((term * logic_var * term) list -> bool) ref =
  Extlib.mk_fun "has_empty_quantif_ref"

(**************************************************************************)
(************************** Labeled stmts *********************************)
(**************************************************************************)

let get_first_inner_stmt stmt =
  match stmt.labels, stmt.skind with
  | [], _ -> stmt
  | _ :: _, Block { bstmts = dest_stmt :: _ } ->
    dest_stmt
  | labels, _ ->
    Options.fatal "Unexpected stmt:\nlabels: [%a]\nstmt: %a"
      (Pretty_utils.pp_list ~sep:"; " Cil_types_debug.pp_label) labels
      Printer.pp_stmt stmt

(**************************************************************************)
(********************** Extended logic label ******************************)
(**************************************************************************)


(** Extended logic label module to associate a statement to a label where it is
    necessary. For instance the label `Old` is associated its contract statement
    to be able to differentiate between two `Old` annotations in the same
    function. On the contrary the `Pre` label does not have an associated
    statement because this label designate the same location for all contracts
    in the same function. *)
module ExtLogicLabel = struct
  (** @return an extended logic label from a [kinstr] and a [logic_label]. *)
  let from kinstr label =
    let from_stmt_opt =
      match kinstr, label with
      | Kglobal, _
      | Kstmt _, (BuiltinLabel (Pre | Here | Init) | FormalLabel _ | StmtLabel _) ->
        None
      | Kstmt _, BuiltinLabel (LoopCurrent | LoopEntry) ->
        (* [None] for now because these labels are unsupported, but the
           statement before the loop and the first statement of the loop should
           probably be used once they are supported. *)
        None
      | Kstmt s, BuiltinLabel (Old | Post) -> Some s
    in
    label, from_stmt_opt

  include Datatype.Make_with_collections
      (struct
        type t = logic_label * stmt option
        let name = "E_ACSL.Labels.ExtLogicLabel"
        let reprs =
          List.fold_left
            (fun acc label ->
               List.fold_left
                 (fun acc stmt ->
                    (label, Some stmt) :: (label, None) :: acc)
                 acc
                 Stmt.reprs)
            []
            Logic_label.reprs

        include Datatype.Undefined

        let compare (label1, from_stmt_opt1) (label2, from_stmt_opt2) =
          let cmp = Logic_label.compare label1 label2 in
          if cmp = 0 then
            Option.compare Stmt.compare from_stmt_opt1 from_stmt_opt2
          else cmp

        let equal = Datatype.from_compare

        let hash (label, from_stmt_opt)=
          match from_stmt_opt with
          | Some from_stmt ->
            Hashtbl.hash (Logic_label.hash label, Stmt.hash from_stmt)
          | None -> Logic_label.hash label

        let pretty fmt (label, from_stmt_opt) =
          match from_stmt_opt with
          | Some from_stmt ->
            Format.fprintf fmt "%a from stmt %d at %a"
              Logic_label.pretty label
              from_stmt.sid
              Printer.pp_location (Stmt.loc from_stmt)
          | None ->
            Format.fprintf fmt "%a"
              Logic_label.pretty label
      end)
end

(**************************************************************************)
(***************************** At data ************************************)
(**************************************************************************)

(** Basic printer for a [kinstr] *)
let basic_pp_kinstr fmt kinstr =
  Format.fprintf fmt "%s"
    (match kinstr with
     | Kglobal -> "Kglobal"
     | Kstmt _ -> "Kstmt")

(** Basic comparison for two [kinstr], i.e. two [Kstmt] are always equal
    regardless of the statement value. *)
let basic_kinstr_compare kinstr1 kinstr2 =
  match kinstr1, kinstr2 with
  | Kglobal, Kglobal | Kstmt _, Kstmt _ -> 0
  | Kglobal, _ -> 1
  | _, Kglobal -> -1

(** Basic hash function for a [kinstr], i.e. the statement of the [Kstmt] is
    not considered for the hash. *)
let basic_kinstr_hash kinstr =
  match kinstr with
  | Kglobal -> 1 lsl 29
  | Kstmt _ -> 1 lsl 31

(** Datatype for at_data *)
module AtData =
  Datatype.Make_with_collections
    (struct
      type t = at_data
      let name = "E_ACSL.Labels.AtData"

      let reprs =
        List.fold_left
          (fun acc kf ->
             List.fold_left
               (fun acc kinstr ->
                  List.fold_left
                    (fun acc pot ->
                       List.fold_left
                         (fun acc label ->
                            (kf, kinstr, Lscope.empty, pot, label) :: acc)
                         acc
                         Logic_label.reprs)
                    acc
                    PredOrTerm.reprs)
               acc
               Kinstr.reprs)
          []
          Kf.reprs

      include Datatype.Undefined

      let compare
          (kf1, kinstr1, lscope1, pot1, label1)
          (kf2, kinstr2, lscope2, pot2, label2)
        =
        let cmp = Kf.compare kf1 kf2 in
        let cmp =
          if cmp = 0 then
            basic_kinstr_compare kinstr1 kinstr2
          else cmp
        in
        let cmp =
          if cmp = 0 then Lscope.D.compare lscope1 lscope2
          else cmp
        in
        let cmp =
          if cmp = 0 then PredOrTerm.compare pot1 pot2
          else cmp
        in
        if cmp = 0 then
          let extlabel1 = ExtLogicLabel.from kinstr1 label1 in
          let extlabel2 = ExtLogicLabel.from kinstr2 label2 in
          ExtLogicLabel.compare extlabel1 extlabel2
        else cmp

      let equal = Datatype.from_compare

      let hash (kf, kinstr, lscope, pot, label) =
        let extlabel = ExtLogicLabel.from kinstr label in
        Hashtbl.hash
          (Kf.hash kf,
           basic_kinstr_hash kinstr,
           Lscope.D.hash lscope,
           PredOrTerm.hash pot,
           ExtLogicLabel.hash extlabel)

      let pretty fmt (kf, kinstr, lscope, pot, label) =
        let extlabel = ExtLogicLabel.from kinstr label in
        Format.fprintf fmt "@[(%a, %a, %a, %a, %a)@]"
          Kf.pretty kf
          basic_pp_kinstr kinstr
          Lscope.D.pretty lscope
          PredOrTerm.pretty pot
          ExtLogicLabel.pretty extlabel
    end)

(** Debug function to print the hash of an [at_data] value. *)
let _debug_hash (kf, kinstr, lscope, pot, label) =
  let extlabel = ExtLogicLabel.from kinstr label in
  Options.feedback ~level:4 "|    | debug hash key: %a"
    AtData.pretty (kf, kinstr, lscope, pot, label);
  Options.feedback ~level:4 "|    | -> hash kf: %d" (Kf.hash kf);
  Options.feedback ~level:4 "|    | -> hash kinstr: %d"
    (basic_kinstr_hash kinstr);
  Options.feedback ~level:4 "|    | -> hash pot: %d" (PredOrTerm.hash pot);
  Options.feedback ~level:4 "|    | -> hash label: %d"
    (ExtLogicLabel.hash extlabel);
  (match label with
   | StmtLabel { contents = stmt } ->
     Options.feedback ~level:4 "|    |  -> stmt of label: %a"
       Printer.pp_stmt stmt;
     Options.feedback ~level:4 "|    |  -> stmt id: %a" Stmt.pretty_sid stmt
   | _ -> ());
  (match extlabel with
   | _, Some from_stmt ->
     Options.feedback ~level:4 "|    |  -> from stmt of label: %a"
       Printer.pp_stmt from_stmt;
     Options.feedback ~level:4 "|    |  -> from stmt id: %a"
       Stmt.pretty_sid from_stmt
   | _ -> ());
  Options.feedback ~level:4 "|    | => hash key: %d"
    (AtData.hash (kf, kinstr, lscope, pot, label));
  ()

(**************************************************************************)
(*************************** Translation **********************************)
(**************************************************************************)

let preprocess_done = ref false

module Translation = struct
  (* see documentation in .mli *)
  type t =
    | Done of exp
    | Queued
    | Inplace

  (** Associate a statement with the [at_data] that need to be translated on
      this statement. *)
  let at_data_for_stmts: AtData.Set.t Stmt.Hashtbl.t = Stmt.Hashtbl.create 17
  (** Associate a [at_data] value with its translation. *)
  let at_data_translations: t Error.result AtData.Hashtbl.t =
    AtData.Hashtbl.create 17

  (** Formatter for a [at_data] translation. *)
  let pretty fmt t =
    Format.fprintf fmt "%s"
      (match t with
       | Done e -> Format.asprintf "%a" Printer.pp_exp e
       | Queued -> "Queued"
       | Inplace -> "In-place")

  (** Reset the translation information. *)
  let reset () =
    Stmt.Hashtbl.clear at_data_for_stmts;
    AtData.Hashtbl.clear at_data_translations

  (** Add [data] to the list of [at_data] that must be translated on the
      statement [stmt]. *)
  let add_at_for_stmt data stmt =
    let stmt = get_first_inner_stmt stmt in
    let ats = Stmt.Hashtbl.find_def at_data_for_stmts stmt AtData.Set.empty in
    let ats = AtData.Set.add data ats in
    Stmt.Hashtbl.replace
      at_data_for_stmts
      stmt
      ats

  (* see documentation in .mli *)
  let at_for_stmt stmt =
    if !preprocess_done then
      let ats = Stmt.Hashtbl.find_def at_data_for_stmts stmt AtData.Set.empty in
      Result.Ok (AtData.Set.elements ats)
    else Error.not_memoized ()

  (* see documentation in .mli *)
  let set ?(force=false) data tr =
    let tr =
      try
        let existing_tr = AtData.Hashtbl.find at_data_translations data in
        match existing_tr, tr with
        | _, Result.Error _ ->
          (* keep current result when trying to set an error on an existing
             translation, except if [force] is true *)
          if force then tr
          else existing_tr
        | Result.Error _, Result.Ok _ ->
          (* replace current error with result *)
          tr
        | Result.Ok Queued, Result.Ok (Done _ | Queued) ->
          (* either set done translation or continue to set queued
             translation *)
          tr
        | Result.Ok Inplace, Result.Ok Inplace ->
          (* continue to set inplace translation *)
          tr
        | Result.Ok Queued, Result.Ok Inplace
        | Result.Ok Inplace, Result.Ok Queued ->
          (* the term is used both in an annotation where the in-place
             translation would be appropriate, and in an annotation where it
             needs to be translated on a specific statement (queued). We keep
             the Queued translation so that both annotations can use the same
             expression. *)
          Result.Ok Queued
        | Result.Ok (Done e), Result.Ok _ ->
          Options.fatal
            "Trying to override existing translation '%a' for at data '%a' \
             with '%a'"
            Printer.pp_exp e
            AtData.pretty data
            (Error.pp_result pretty) tr
        | Result.Ok Inplace, Result.Ok _ ->
          Options.fatal
            "Trying to override in-place translation for at data '%a' with \
             '%a'"
            AtData.pretty data
            (Error.pp_result pretty) tr
      with Not_found ->
        (* No existing translation *)
        tr
    in
    AtData.Hashtbl.replace at_data_translations data tr

  (* see documentation in .mli *)
  let get data =
    if !preprocess_done then
      AtData.Hashtbl.find at_data_translations data
    else Error.not_memoized ()

  (** Print the content of the tables. *)
  let _debug () =
    Options.feedback ~level:2 "|Locations:";
    Stmt.Hashtbl.iter
      (fun stmt ats ->
         Options.feedback ~level:2 "| - stmt %d at %a"
           stmt.sid
           Printer.pp_location (Stmt.loc stmt);
         AtData.Set.iter
           (fun at ->
              let tr = try Some (get at) with Not_found -> None in
              Options.feedback ~level:2 "|    - at %a: %a"
                AtData.pretty at
                (Pretty_utils.pp_opt (Error.pp_result pretty)) tr)
           ats
      )
      at_data_for_stmts;
    Options.feedback ~level:2 "|Translations:";
    AtData.Hashtbl.iter
      (fun at tr ->
         Options.feedback ~level:2 "| - %a: %a"
           AtData.pretty at
           (Error.pp_result pretty) tr)
      at_data_translations
end

(**************************************************************************)
(************************** AST traversal *********************************)
(**************************************************************************)

module Process: sig
  val not_yet: ?error:exn -> string -> exn option
  (** Create and return a [Not_yet] exception with the given message. If [error]
      is provided, return this error instead. *)

  val term:
    ?error:exn ->
    stmt ->
    kernel_function ->
    kinstr ->
    stmt ->
    annotation_kind ->
    lscope ->
    term ->
    unit
  (** Traverse the given term to analyse labeled predicates and terms.

      See documentation of Process.t below for a description of the function
      parameters. *)

  val predicate:
    ?error:exn ->
    stmt ->
    kernel_function ->
    kinstr ->
    stmt ->
    annotation_kind ->
    lscope ->
    predicate ->
    unit
    (** Traverse the given predicate to analyse the labeled predicates and
        terms.

        See documentation of Process.t below for a description of the function
        parameters. *)

end = struct
  (** Environment to propagate during the traversal. *)
  type t = {
    (** Statement corresponding to the label [Pre] of the enclosing function. *)
    pre_func_stmt: stmt;
    (** Enclosing function of the predicate or term being analysed. *)
    kf: kernel_function;
    (** Kinstr of the predicate or term being analysed. *)
    kinstr: kinstr;
    (** Statement of the predicate or term being analysed. *)
    stmt: stmt;
    (** King of annotation for the predicate or term being analysed. *)
    akind: annotation_kind;
    (** Logic scope for the predicate or term being analysed. *)
    lscope: Lscope.t;
  }

  (** @return either the given error if it is provided, or [Some e] if not. *)
  let set_error ?error e =
    match error with
    | None -> Some e
    | Some _ -> error

  (** Create and return a [Not_yet] exception with the given message. If [error]
      is provided, return this error instead. *)
  let not_yet ?error s =
    set_error ?error (Error.make_not_yet (s ^ " (labels pre-analysis)"))

  (** Create and return a [Typing_error] exception with the given message. If
      [error] is provided, return this error instead. *)
  let untypable ?error s =
    set_error ?error (Error.make_untypable (s ^ " (labels pre-analysis)"))

  (** @return a textual representation of the given kind of annotation. *)
  let akind_to_string k =
    match k with
    | Assertion -> "Assertion"
    | Precondition -> "Precondition"
    | Postcondition -> "Postcondition"
    | Invariant -> "Invariant"
    | Variant -> "Variant"
    | RTE -> "RTE"

  (** Apply [fct ?error env] on every element of the list [args]. *)
  let do_list fct ?error env args =
    List.fold_left
      (fun error a -> fct ?error env a)
      error
      args

  (** Apply [fct ?error env] on [arg] if [arg_opt] is [Some arg], return
      directly [error] otherwise. *)
  let do_opt fct ?error env arg_opt =
    match arg_opt with
    | Some arg -> fct ?error env arg
    | None -> error

  (** Analyse the predicate or term [pot] and the label [label] to decide where
      the predicate or term must be translated. *)
  let process ?error env pot label =
    let error, dest_stmt_opt =
      match env.kinstr, env.akind, label with
      (* Arbitrary label, translate on the given statement *)
      | _, _, StmtLabel { contents = stmt } -> error, Some stmt

      (* Translate on the statement corresponding to the [Pre] label of the
         enclosing function. *)
      | Kglobal, Postcondition, BuiltinLabel(Pre | Old) ->
        error, Some env.pre_func_stmt
      | Kstmt _, (Precondition | Postcondition), BuiltinLabel(Pre) ->
        error, Some env.pre_func_stmt
      | _, Assertion, BuiltinLabel(Pre) ->
        error, Some env.pre_func_stmt

      (* Translate before the current statement. *)
      | Kstmt stmt, Postcondition, BuiltinLabel(Old) ->
        if not (Cil_datatype.Stmt.equal stmt env.stmt) then
          Options.fatal
            "The statement of the kinstr and the current statement should \
             always be equal";
        error, Some stmt

      (* In-place translations *)
      | _, _, BuiltinLabel(Here) ->
        error, None
      | Kglobal, Precondition, BuiltinLabel(Pre | Old) ->
        error, None
      | _, Postcondition, BuiltinLabel(Post) ->
        error, None
      | Kstmt _, Precondition, BuiltinLabel(Old) ->
        error, None

      (* Invalid position for the given label *)
      | _, Assertion, BuiltinLabel(Old | Post)
      | _, Precondition, BuiltinLabel(Post) ->
        let msg =
          Format.asprintf "label '%a' within annotation '%s' in '%a'"
            Printer.pp_logic_label label
            (akind_to_string env.akind)
            PredOrTerm.pretty pot
        in
        untypable msg, None

      (* Unexpected combination that should never happen *)
      | kinstr, akind, label ->
        let msg =
          Format.asprintf "label '%a' within %s annotation '%s' in '%a'"
            Printer.pp_logic_label label
            (match kinstr with Kglobal -> "function" | Kstmt _ -> "statement")
            (akind_to_string akind)
            PredOrTerm.pretty pot
        in
        untypable msg, None
    in
    let at = (env.kf, env.kinstr, env.lscope, pot, label) in
    begin match error, dest_stmt_opt with
      | Some e, _ ->
        (* Register the error instead of a translation expression for the
           current labeled pred_or_term *)
        Translation.set at (Result.Error e)
      | None, None ->
        (* The labeled pred_or_term will be translated in place *)
        Translation.set at (Result.Ok Translation.Inplace)
      | None, Some dest_stmt ->
        (* Register the current labeled pred_or_term to the destination
           statement for a later translation *)
        Translation.add_at_for_stmt at dest_stmt;
        (* Set the translation to [Queued] *)
        Translation.set at (Result.Ok Queued)
    end;
    error

  (** Term traversal *)
  let rec do_term ?error env t =
    match t.term_node with
    | Tat (t', l) ->
      let error = do_term ?error env t' in
      process ?error env (PoT_term t) l
    | Tbase_addr (l, t') | Tblock_length (l, t') | Toffset (l, t') ->
      let error = do_term ?error env t' in
      (* E-ACSL semantic: \base_addr{L](p) == \at(\base_addr(p), L) *)
      process ?error env (PoT_term t) l
    | Tlet (li, t) ->
      let lv_term = Misc.term_of_li li in
      let error = do_term ?error env lv_term in
      let lvs = Lvs_let (li.l_var_info, lv_term) in
      let env = { env with lscope = Lscope.add lvs env.lscope } in
      do_term ?error env t
    | TLval lv | TAddrOf lv | TStartOf lv ->
      do_lval ?error env lv
    | TSizeOfE t | TAlignOfE t | TUnOp (_, t) | TCastE (_, t) | Tlambda (_, t)
    | TLogic_coerce (_, t) ->
      do_term ?error env t
    | TBinOp (_, t1, t2) ->
      let error = do_term ?error env t1 in
      do_term ?error env t2
    | Tif (t1, t2, t3) ->
      let error = do_term ?error env t1 in
      let error = do_term ?error env t2 in
      do_term ?error env t3
    | Tapp (_, [], targs) ->
      do_list do_term ?error env targs
    | Tapp (li, labels, targs) ->
      let error = not_yet "logic functions with labels" in
      do_labeled_app ?error env li labels targs
    | Trange (t1_opt, t2_opt) ->
      let error = do_opt do_term ?error env t1_opt in
      do_opt do_term ?error env t2_opt
    | TDataCons (_, targs) ->
      (* Register a not_yet error for each labeled pred or term in the
         arguments *)
      let error = not_yet "constructor" in
      do_list do_term ?error env targs
    | TUpdate (t1, toff, t2) ->
      (* Register a not_yet error for each labeled pred or term used in the
         functional update *)
      let error = not_yet "functional update" in
      let error = do_term ?error env t1 in
      let error = do_toffset ?error env toff in
      do_term ?error env t2
    | Ttypeof t ->
      (* Register a not_yet error for each labeled pred or term used with the
         typeof operator *)
      let error = not_yet "typeof" in
      do_term ?error env t
    | Tunion ts | Tinter ts ->
      (* Register a not_yet error for each labeled pred or term used in the
         manipulation of tsets *)
      let error = not_yet "union or intersection of tsets" in
      do_list do_term ?error env ts
    | Tcomprehension (t, _, p_opt) ->
      (* Register a not_yet error for each labeled pred or term used in the
         comprehension *)
      let error = not_yet "tset comprehension" in
      let error = do_term ?error env t in
      do_opt do_predicate ?error env p_opt
    | TConst _ | TSizeOf _ | TAlignOf _ | TSizeOfStr _ | Tnull | Ttype _
    | Tempty_set -> error

  (** Lval traversal *)
  and do_lval ?error env (tlhost, toffset) =
    let error = do_tlhost ?error env tlhost in
    do_toffset ?error env toffset

  (** Lhost traversal *)
  and do_tlhost ?error env = function
    | TMem t -> do_term ?error env t
    | TVar _ | TResult _ -> error

  (** Offset traversal *)
  and do_toffset ?error env = function
    | TIndex (t, next) ->
      let error = do_term ?error env t in
      do_toffset ?error env next
    | TField (_, next) | TModel (_, next) ->
      do_toffset ?error env next
    | TNoOffset -> error

  (** Predicate traversal *)
  and do_predicate ?error env p =
    match p.pred_content with
    | Pat (p', l) ->
      let error = do_predicate ?error env p' in
      process ?error env (PoT_pred p) l
    | Pfreeable (l, t) | Pvalid (l, t) | Pvalid_read (l, t)
    | Pinitialized (l, t)  ->
      let error = do_term ?error env t in
      (* E-ACSL semantic: \freeable{L](p) == \at(\freeable(p), L) *)
      process ?error env (PoT_pred p) l
    | Pallocable (l, t) ->
      let error = not_yet "\\allocate" in
      let error = do_term ?error env t in
      process ?error env (PoT_pred p) l
    | Pdangling (l, t) ->
      let error = not_yet "\\dangling" in
      let error = do_term ?error env t in
      process ?error env (PoT_pred p) l
    | Pobject_pointer (l, t) ->
      let error = not_yet "\\object_pointer" in
      let error = do_term ?error env t in
      process ?error env (PoT_pred p) l
    | Plet (li, p) ->
      let lv_term = Misc.term_of_li li in
      let error = do_term ?error env lv_term in
      let lvs = Lvs_let (li.l_var_info, lv_term) in
      let env = { env with lscope = Lscope.add lvs env.lscope } in
      do_predicate ?error env p
    | Pforall _ | Pexists _ -> begin
        let preprocessed_quantifier_or_error =
          try
            Bound_variables.get_preprocessed_quantifier p
          with Error.Not_memoized _ ->
            Options.fatal "preprocessing of quantifier '%a' was not performed"
              Printer.pp_predicate p
        in
        match preprocessed_quantifier_or_error with
        | Result.Ok (bound_vars, goal) ->
          if not (!has_empty_quantif_ref bound_vars) then begin
            let env =
              List.fold_right
                (fun (t1, lv, t2) env ->
                   let lvs = Lvs_quantif (t1, Rle, lv, Rlt, t2) in
                   { env with lscope = Lscope.add lvs env.lscope })
                bound_vars
                env
            in
            let do_it ?error env (t1, _, t2) =
              let error = do_term ?error env t1 in
              do_term ?error env t2
            in
            let error = do_list do_it ?error env bound_vars in
            do_predicate ?error env goal
          end
          else error
        | Result.Error exn -> set_error ?error exn
      end
    | Pnot p ->
      do_predicate ?error env p
    | Pand (p1, p2) | Por (p1, p2) | Pxor (p1, p2) | Pimplies (p1, p2)
    | Piff (p1, p2) ->
      let error = do_predicate ?error env p1 in
      do_predicate ?error env p2
    | Pif (t, p1, p2) ->
      let error = do_term ?error env t in
      let error = do_predicate ?error env p1 in
      do_predicate ?error env p2
    | Prel (_, t1, t2) ->
      let error = do_term ?error env t1 in
      do_term ?error env t2
    | Papp (_, [], targs) | Pseparated (targs) ->
      do_list do_term ?error env targs
    | Papp (li, labels, targs) ->
      let error = not_yet "predicate with labels" in
      do_labeled_app ?error env li labels targs
    | Pvalid_function t ->
      let error = not_yet "\\valid_function" in
      do_term ?error env t
    | Pfresh (l1, l2, t, _) ->
      let error = not_yet "\\fresh" in
      let error = process ?error env (PoT_term t) l1 in
      process ?error env (PoT_term t) l2
    | Pfalse | Ptrue -> error

  (** Function application with labels traversal *)
  and do_labeled_app ?error env li labels targs =
    ignore li;
    let do_it ?error env t =
      (* Register a not_yet error for each labeled pred or term in the
         arguments *)
      let error = do_term ?error env t in
      (* Register a not_yet error for each use of an argument with a label
         of the function to avoid *)
      List.fold_left
        (fun error label -> process ?error env (PoT_term t) label)
        error
        labels
    in
    do_list do_it ?error env targs

  (* see documentation in module signature *)
  let term ?error pre_func_stmt kf kinstr stmt akind lscope t =
    let env =
      { pre_func_stmt;
        kf;
        kinstr;
        stmt;
        akind;
        lscope }
    in
    ignore @@ do_term ?error env t

  (* see documentation in module signature *)
  let predicate ?error pre_func_stmt kf kinstr stmt akind lscope p =
    let env =
      { pre_func_stmt;
        kf;
        kinstr;
        stmt;
        akind;
        lscope }
    in
    ignore @@ do_predicate ?error env p

end

class vis_at_labels () =
  object (self)
    inherit E_acsl_visitor.visitor dkey

    (** Statement corresponding to the [Pre] label of the enclosing function*)
    val mutable pre_func_stmt: stmt option = None

    (** @return the statement corresponding to the [Pre] label of the enclosing
        function. *)
    method pre_func_stmt () = Option.get pre_func_stmt

    (** Set the statement corresponding to the [Pre] label of the enclosing
        function. *)
    method set_pre_func_stmt s = pre_func_stmt <- Some s

    (** Reset the statement corresponding to the [Pre] label of the enclosing
        function. *)
    method reset_pre_func_stmt () = pre_func_stmt <- None

    (** Launch the analysis on the given predicate. *)
    method process_pred ?error kf kinstr stmt akind p =
      Process.predicate
        ?error
        (self#pre_func_stmt ())
        kf
        kinstr
        stmt
        akind
        Lscope.empty
        p

    (** Launch the analysis on the given term. *)
    method process_term ?error kf kinstr stmt akind t =
      Process.term
        ?error
        (self#pre_func_stmt ())
        kf
        kinstr
        stmt
        akind
        Lscope.empty
        t

    (** Launch the analysis on the given identified predicate. *)
    method process_id_pred ?error kf kinstr stmt akind ip =
      let p = ip.ip_content.tp_statement in
      self#process_pred ?error kf kinstr stmt akind p

    (** Launch the analysis on the given identified term. *)
    method process_id_term ?error kf kinstr stmt akind it =
      let t = it.it_content in
      self#process_term ?error kf kinstr stmt akind t

    (** Launch the analysis on the given assigns clause. *)
    method process_assigns ?error kf kinstr stmt akind assigns =
      match assigns with
      | Writes froms ->
        let error = Process.not_yet ?error "assigns clause in behavior" in
        List.iter
          (fun (it, deps) ->
             self#process_id_term ?error kf kinstr stmt akind it;
             match deps with
             | From its ->
               List.iter
                 (self#process_id_term ?error kf kinstr stmt akind)
                 its
             | FromAny -> ())
          froms;
      | WritesAny -> ()

    (** Launch the analysis on the given allocates clause. *)
    method process_allocates ?error kf kinstr stmt akind allocates =
      match allocates with
      | FreeAlloc (its1, its2) ->
        let error = Process.not_yet ?error "allocates clause in behavior" in
        List.iter
          (self#process_id_term ?error kf kinstr stmt akind)
          its1;
        List.iter
          (self#process_id_term ?error kf kinstr stmt akind)
          its2
      | FreeAllocAny -> ()

    (** Launch the analysis on the given function or statement contract. *)
    method process_spec ?error kf kinstr stmt spec =
      List.iter
        (fun bhv ->
           let akind = Precondition in
           List.iter
             (fun assumes -> self#process_id_pred kf kinstr stmt akind assumes)
             bhv.b_assumes;
           List.iter
             (fun requires ->
                if !must_translate_ppt_ref
                    (Property.ip_of_requires kf kinstr bhv requires) then
                  self#process_id_pred kf kinstr stmt akind requires)
             bhv.b_requires;
           let akind = Postcondition in
           (* The links between the [identified_property]s and the [assigns] or
              [allocates] clauses are not clear. For now store a [not_yet] error
              for every term of the clauses. Update the code to add the relevant
              [must_translate] calls once the [assigns] or [allocates] clauses
              translation are supported. *)
           self#process_assigns ?error kf kinstr stmt akind bhv.b_assigns;
           self#process_allocates ?error kf kinstr stmt akind bhv.b_allocation;
           List.iter
             (fun ((termination, post_cond) as tp) ->
                if !must_translate_ppt_ref
                    (Property.ip_of_ensures kf kinstr bhv tp) then
                  let error =
                    match termination with
                    | Normal ->
                      None
                    | Exits | Breaks | Continues | Returns ->
                      Process.not_yet
                        ?error "abnormal termination case in behavior"
                  in
                  self#process_id_pred ?error kf kinstr stmt akind post_cond)
             bhv.b_post_cond
        )
        spec.spec_behavior

    method! vstmt_aux stmt =
      let kf = Option.get self#current_kf in

      if Kernel_function.is_first_stmt kf stmt then begin
        (* If we are on the first statement of a function, then set the
           [pre_func_stmt] to it. *)
        self#set_pre_func_stmt stmt;

        (* Analyse the specification on the function on the first statement *)
        if Annotations.has_funspec kf then
          self#process_spec kf Kglobal stmt (Annotations.funspec kf)
      end;

      (* Analyse the specification on the current statement *)
      let kinstr = Kstmt stmt in
      Annotations.iter_code_annot
        (fun _ annot ->
           match annot.annot_content with
           | AAssert(l, p) ->
             if !must_translate_ppt_ref
                 (Property.ip_of_code_annot_single kf stmt annot) then
               let error =
                 match l with
                 | [] -> None
                 | _ :: _ ->
                   Process.not_yet "assertion applied only on some behaviors"
               in
               self#process_pred
                 ?error
                 kf
                 kinstr
                 stmt
                 Assertion
                 p.tp_statement
           | AStmtSpec(l, spec) ->
             let error =
               match l with
               | [] -> None
               | _ :: _ ->
                 Process.not_yet
                   "statement contract applied only on some behaviors"
             in
             self#process_spec ?error kf kinstr stmt spec
           | AInvariant(l, _, p) ->
             if !must_translate_ppt_ref
                 (Property.ip_of_code_annot_single kf stmt annot) then begin
               let error =
                 match l with
                 | [] -> None
                 | _ :: _ ->
                   Process.not_yet "invariant applied only on some behaviors"
               in
               self#process_pred
                 ?error
                 kf
                 kinstr
                 stmt
                 Invariant
                 p.tp_statement
             end
           | AVariant(t, _) ->
             if !must_translate_ppt_ref
                 (Property.ip_of_code_annot_single kf stmt annot) then
               self#process_term kf kinstr stmt Variant t
           | AAssigns (_, assigns) ->
             (* The link between the [identified_property] and the [assigns]
                clause is not clear. For now store a [not_yet] error for every
                term of the clause. Update the code to add the relevant
                [must_translate] calls once the [assigns] clause translation is
                supported. *)
             let error = Process.not_yet "assigns" in
             self#process_assigns
               ?error
               kf
               kinstr
               stmt
               Postcondition
               assigns
           | AAllocation (_, allocates) ->
             (* The link between the [identified_property] and the [allocates]
                clause is not clear. For now store a [not_yet] error for every
                term of the clause. Update the code to add the relevant
                [must_translate] calls once the [allocates] clause translation
                is supported. *)
             let error = Process.not_yet "allocates" in
             self#process_allocates
               ?error
               kf
               kinstr
               stmt
               Postcondition
               allocates
           | APragma _ -> ()
           | AExtended _ -> ()
        )
        stmt;

      let post stmt =
        (* If we are on the last statemement of a function, reset the
           [pre_func_stmt]. *)
        if Kernel_function.is_return_stmt kf stmt then
          self#reset_pre_func_stmt ();
        stmt
      in
      Cil.DoChildrenPost post

  end

let preprocess ast =
  let vis = new vis_at_labels () in
  Visitor.visitFramacFileSameGlobals (vis :> Visitor.frama_c_visitor) ast;
  preprocess_done := true

let reset () =
  preprocess_done := false;
  Translation.reset ()

let pp_at_data = AtData.pretty

let _debug () =
  Options.feedback ~level:2 "Labels preprocessing";
  Translation._debug ()

(*
Local Variables:
compile-command: "make -C ../../../../.."
End:
*)
