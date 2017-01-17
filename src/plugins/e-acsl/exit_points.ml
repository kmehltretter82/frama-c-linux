(**************************************************************************)
(*                                                                        *)
(*  This file is part of the Frama-C's E-ACSL plug-in.                    *)
(*                                                                        *)
(*  Copyright (C) 2012-2016                                               *)
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
(*  for more details (enclosed in the file license/LGPLv2.1).             *)
(*                                                                        *)
(**************************************************************************)

open Cil_types
open Cil_datatype

let statement_locals:
  Cil_types.varinfo list Stmt.Hashtbl.t = Stmt.Hashtbl.create 17
(* Mapping of statements to local variables available within that statement's
   scope. The mappings of this structure are used to determine variables which
   need to be removed before goto jumps. Generally, if some goto (with
   scope variables are given by set G') jumps to a labeled statement with
   scope variables given by set L', then the goto exists the scopes of
   variables given via set G' \ L'. Consequently, if those variables are
   tracked, they need to be removed from tracking. *)

let exit_context:
  Cil_types.stmt Stmt.Hashtbl.t = Stmt.Hashtbl.create 17
(* Statement to statement mapping indicating source/destination of a jump.
   For instance, break statements are mapped to switches or loops they jump
   out from and goto statements are mapped to their labeled statements. Notably,
   such information does not really be computed for gotos (since they already
   capture references to labelled statements they jumps to). Nevertheless it is
   done for consistency, so all required information is stored uniformly. *)

let labelled_jumps:
  Cil_types.stmt Stmt.Hashtbl.t = Stmt.Hashtbl.create 17
(* Map labelled statements back to gotos which lead to them *)

let bypassed_variables:
  Cil_types.stmt Varinfo.Hashtbl.t = Varinfo.Hashtbl.create 5
(* Map variables that are bypasssed by goto jumps to the goto statements
   which bypass them *)

let clear () =
  Stmt.Hashtbl.clear statement_locals;
  Stmt.Hashtbl.clear exit_context;
  Stmt.Hashtbl.clear labelled_jumps;
  Varinfo.Hashtbl.clear bypassed_variables

let filter_vars varlst1 varlst2 =
  let s1 = Varinfo.Set.of_list varlst1 in
  let s2 = Varinfo.Set.of_list varlst2 in
  Varinfo.Set.elements (Varinfo.Set.diff s1 s2)

let find_locals stmt =
  Stmt.Hashtbl.find statement_locals stmt

let find_exit stmt =
  Stmt.Hashtbl.find exit_context stmt

let delete_vars stmt =
  match stmt.skind with
  | Goto(_) | Break(_) | Continue(_) ->
    filter_vars (find_locals stmt) (find_locals (find_exit stmt))
  | _ -> []

let bypass_warning goto var =
  let loc = match goto.skind with
    | Goto(_, l) -> l
    | _ -> assert false
  in
  Options.warning "Declaration of local variable %s at %a is bypassed by a\
goto statement at %a"
  var.vname
  Printer.pp_location var.vdecl
  Printer.pp_location loc

let store_vars stmt =
  if Stmt.Hashtbl.mem labelled_jumps stmt then
    let gotos = Stmt.Hashtbl.find_all labelled_jumps stmt in
    let acc = List.fold_left
      (fun acc goto ->
        acc @ filter_vars (find_locals stmt) (find_locals goto))
      []
      gotos
    in
    Varinfo.Set.elements (Varinfo.Set.of_list acc)
  else
    []

let is_bypassed_by vi =
  if Varinfo.Hashtbl.mem bypassed_variables vi then
    Some (Varinfo.Hashtbl.find bypassed_variables vi)
  else
    None

let bypassed_by_stmt stmt =
  let gotos = Stmt.Hashtbl.find_all labelled_jumps stmt in
  List.iter (fun goto ->
    List.iter
      (fun v -> Varinfo.Hashtbl.replace bypassed_variables v goto)
      (filter_vars (find_locals stmt) (find_locals goto))
  ) gotos

class jump_context = object (self)
  inherit Visitor.frama_c_inplace

  val mutable locals = [[]]
  (* Maintained list of local variables within a scope of a visitor,
     variables within a single scope are given by a single list *)

  val mutable jumps = []
  (* Stack of entered switches and loops  *)

  method private add_locals stmt =
    Stmt.Hashtbl.replace statement_locals stmt (List.flatten locals)

  method private add_exit stmt from =
    Stmt.Hashtbl.replace exit_context stmt from

  method private add_labelled label goto =
    Stmt.Hashtbl.add labelled_jumps label goto

  method !vfunc _ =
    Cil.DoChildrenPost
    (fun fn ->
      Stmt.Hashtbl.iter (fun vi _ -> bypassed_by_stmt vi) labelled_jumps;
      fn)

  method !vblock blk =
    locals <- [blk.blocals] @ locals;
    Cil.DoChildrenPost
    (fun blk -> locals <- List.tl locals; blk)

  method !vstmt stmt =
    match stmt.skind with
    | Loop(_) | Switch(_) ->
      self#add_locals stmt;
      jumps <- stmt :: jumps;
      Cil.DoChildrenPost (fun st -> jumps <- List.tl jumps; st)
    | Break(_) | Continue(_) ->
      self#add_exit stmt (List.hd jumps);
      self#add_locals stmt;
      Cil.DoChildren
    | Goto(sref, _)  ->
      self#add_locals stmt;
      self#add_exit stmt !sref;
      self#add_labelled !sref stmt;
      Cil.DoChildren
    | _ when (List.length stmt.labels) > 0 ->
      self#add_locals stmt;
      Cil.DoChildren
    | _ -> Cil.DoChildren
end

let generate fct =
  clear ();
  let _ = Cil.visitCilFunction (new jump_context :> Cil.cilVisitor) fct in ()
