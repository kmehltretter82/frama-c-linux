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

let clear () =
  Stmt.Hashtbl.clear statement_locals;
  Stmt.Hashtbl.clear exit_context

let filter_vars varlst1 varlst2 =
  List.filter
    (fun var1 -> not
      (List.exists (fun var2 -> var1.vname = var2.vname) varlst2))
    varlst1
    (* Given that lists [varlist1] and [varlist2] represent two sets of
       variables, substract [varlist2] from [varlist2]. *)

let delete_vars stmt =
  let find_locals stmt = Stmt.Hashtbl.find statement_locals stmt in
  let find_exit stmt = Stmt.Hashtbl.find exit_context stmt in
  match stmt.skind with
  | Goto(_) | Break(_) | Continue(_) ->
    filter_vars (find_locals stmt) (find_locals (find_exit stmt))
  | _ -> []

class jump_context = object (self)
  inherit Visitor.frama_c_inplace

  val mutable locals = [[]]
  (* Maintained list of local variables within a scope of a visitor,
   * variables within a single scope are given by a single list *)

  val mutable jumps = []
  (* Stack of entered switches and loops  *)

  method private add_locals stmt =
    Stmt.Hashtbl.replace statement_locals stmt (List.flatten locals)

  method private add_exit stmt from =
    Stmt.Hashtbl.replace exit_context stmt from

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
      Cil.DoChildren
    | _ when (List.length stmt.labels) > 0 ->
      self#add_locals stmt;
      Cil.DoChildren
    | _ -> Cil.DoChildren
end

let generate fct =
  clear ();
  let _ = Cil.visitCilFunction (new jump_context :> Cil.cilVisitor) fct in ()
