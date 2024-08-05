open Cil_types

module StmtSet = Cil_datatype.Stmt.Hptset

let get = function
  | None -> "none"
  | Some stmt -> string_of_int stmt.sid

let pp_res =
  Pretty_utils.pp_list ~pre:"(" ~sep:", " ~suf:")" Format.pp_print_string

let first_stmt_f = ref None
let first_stmt_g = ref None

(** For each statement of [f], find its immediate dominator and postdominator
    and print the triplets. *)
let print_immediate f =
  let res =
    List.map (fun s ->
        let dom = Dominators.get_idom s in
        let postdom = Dominators.get_ipostdom s in
        [string_of_int s.sid; get dom; get postdom]
      ) f.sallstmts
  in
  Format.printf "@[<v2>Immediate dominators of %s (sid, idom, ipostdom):@;%a@]@;"
    f.svar.vname
    (Pretty_utils.pp_list ~pre:"@[" ~sep:",@ " ~suf:"@]" pp_res) res

(** For each couple of statement of [f], find their common ancestor and children
    and print the quadruplets. *)
let print_nearest f =
  assert (Dominators.nearest_common_ancestor [] = None);
  let res =
    List.map (fun s ->
        List.map (fun s' ->
            let dom = Dominators.nearest_common_ancestor [s; s'] in
            let postdom = Dominators.nearest_common_children [s; s'] in
            [string_of_int s.sid; string_of_int s'.sid; get dom; get postdom]
          ) f.sallstmts
      ) f.sallstmts
    |> List.flatten
  in
  Format.printf "@[<v2>Nearest common ancestors/children of %s (sid, sid, ancestor, children):@;%a@]@;"
    f.svar.vname
    (Pretty_utils.pp_list ~pre:"@[" ~sep:",@ " ~suf:"@]" pp_res) res

(* Make sure that the difference between (post)dominators and strict
   (post)dominators of a statement [s] is equal to the singleton [s]. *)
let test_strict f =
  let test s dom strict_dom =
    if StmtSet.is_empty dom
    then assert (StmtSet.is_empty strict_dom)
    else assert (StmtSet.diff dom strict_dom == StmtSet.singleton s)
  in
  List.iter (fun s ->
      let dom = Dominators.get_dominators s in
      let sdom = Dominators.get_strict_dominators s in
      let postdom = Dominators.get_postdominators s in
      let spostdom = Dominators.get_strict_postdominators s in
      test s dom sdom;
      test s postdom spostdom;
      assert (Dominators.strictly_dominates s s = false);
      assert (Dominators.strictly_postdominates s s = false)
    ) f.sallstmts

class visitPostDom = object(self)
  inherit Visitor.frama_c_inplace

  method! vfunc f =
    let kf = Option.get (self#current_kf) in
    Format.printf "@[<v>Computing for function %s:@;%a@?@;@?"
      f.svar.vname Cil_printer.pp_block f.sbody;

    Dominators.compute_dominators kf;
    Dominators.print_dot_dominators "dom_graph" kf;

    Dominators.compute_postdominators kf;
    Dominators.print_dot_postdominators "postdom_graph" kf;

    print_immediate f;
    print_nearest f;
    test_strict f;

    Format.printf "@]@.";
    SkipChildren
end

let catch f x =
  try ignore (f x)
  with Log.AbortFatal _ -> ()

let cover_errors () =
  let loc = Cil_datatype.Location.unknown in
  (* Test statement not in a function. *)
  let skip = Cil_builder.Pure.(cil_stmt ~loc skip) in
  catch Dominators.get_postdominators skip;
  let trigger kf =
    match kf.fundec with
    | Definition _ -> ()
    | Declaration _ ->
      (* Test Kernel_function.find_first_stmt on decl. *)
      catch Dominators.compute_dominators kf;
      (* Test Kernel_function.find_return on decl. *)
      catch Dominators.compute_postdominators kf;
      (* Test print_dot on decl. *)
      catch (Dominators.print_dot_dominators "tmp") kf
  in
  Globals.Functions.iter trigger

let pretty () =
  Format.printf "@[<v2>Dominators analysis:@;%a@]\n@."
    Dominators.pretty_dominators ();
  Format.printf "@[<v2>Postominators analysis:@;%a@]\n@."
    Dominators.pretty_postdominators ()

let startup () =
  ignore (Cil.visitCilFileSameGlobals (new visitPostDom:>Cil.cilVisitor) (Ast.get ()));
  pretty ();
  Ast.mark_as_changed ();
  Format.printf "Invalidate tables, which should now be empty\n@.";
  pretty ();
  cover_errors ()

let () = Boot.Main.extend startup
