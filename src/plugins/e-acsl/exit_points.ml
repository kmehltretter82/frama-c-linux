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

(* Mapping of statements to local variables available within that statement's
   scope. The mappings of this structure are used to determine variables which
   need to be removed before goto jumps. Generally, if some goto (with
   scope variables are given by set G') jumps to a labeled statement with
   scope variables given by set L', then the goto exists the scopes of
   variables given via set G' \ L'. Consequently, if those variables are
   tracked, they need to be removed from tracking. *)
module SLocals: sig
  val add: stmt -> varinfo list -> unit
  val find: stmt -> Varinfo.Set.t
  val is_empty: unit -> bool
  val reset: unit -> unit
end = struct
  let statement_locals = Stmt.Hashtbl.create 17
  let add stmt locals =
    Stmt.Hashtbl.replace statement_locals stmt (Varinfo.Set.of_list locals)
  let find stmt =
    Stmt.Hashtbl.find statement_locals stmt
  let is_empty () =
    Stmt.Hashtbl.length statement_locals = 0
  let reset () = Stmt.Hashtbl.reset statement_locals
end

(* Statement to statement mapping indicating source/destination of a jump.
   For instance, break statements are mapped to switches or loops they jump
   out from and goto statements are mapped to their labeled statements. Notably,
   such information does not really be computed for gotos (since they already
   capture references to labelled statements they jumps to). Nevertheless it is
   done for consistency, so all required information is stored uniformly. *)
module Exits: sig
  val add: stmt -> stmt -> unit
  val find: stmt -> stmt
  val is_empty: unit -> bool
  val reset: unit -> unit
end = struct
  let exit_context = Stmt.Hashtbl.create 17
  let add stmt from =
    Stmt.Hashtbl.replace exit_context stmt from
  let find stmt =
    Stmt.Hashtbl.find exit_context stmt
  let is_empty () =
    Stmt.Hashtbl.length exit_context = 0
  let reset () = Stmt.Hashtbl.reset exit_context
end

(* Map labelled statements back to gotos which lead to them *)
module LJumps: sig
  val add: stmt -> stmt -> unit
  val find_all: stmt -> stmt list
  val is_empty: unit -> bool
  val reset: unit -> unit
end = struct
  let labelled_jumps = Stmt.Hashtbl.create 17
  let find_all stmt =
    Stmt.Hashtbl.find_all labelled_jumps stmt
  let add label goto =
    Stmt.Hashtbl.add labelled_jumps label goto
  let is_empty () =
    Stmt.Hashtbl.length labelled_jumps = 0
  let reset () = Stmt.Hashtbl.reset labelled_jumps
end

let reset () =
  SLocals.reset ();
  Exits.reset ();
  LJumps.reset ()

let is_empty () =
  SLocals.is_empty () && Exits.is_empty () && LJumps.is_empty ()

let filter_vars s1 s2 =
  Varinfo.Set.elements (Varinfo.Set.diff s1 s2)

let delete_vars stmt =
  match stmt.skind with
  | Goto(_) | Break(_) | Continue(_) ->
    filter_vars (SLocals.find stmt) (SLocals.find (Exits.find stmt))
  | _ -> []

let store_vars stmt =
  let gotos = LJumps.find_all stmt in
  let acc = List.fold_left
    (fun acc goto ->
      acc @ filter_vars (SLocals.find stmt) (SLocals.find goto))
    []
    gotos
  in
  Varinfo.Set.elements (Varinfo.Set.of_list acc)

class jump_context = object (_)
  inherit Visitor.frama_c_inplace

  val mutable locals = [[]]
  (* Maintained list of local variables within the scope of a currently
     visited statement. Variables within a single scope are given by a
     single list *)

  val jumps = Stack.create ()
  (* Stack of entered switches and loops *)

  method !vblock blk =
    locals <- [blk.blocals] @ locals;
    Cil.DoChildrenPost
    (fun blk -> locals <- List.tl locals; blk)

  method !vstmt stmt =
    match stmt.skind with
    | Loop(_) | Switch(_) ->
      SLocals.add stmt (List.flatten locals);
      Stack.push stmt jumps;
      Cil.DoChildrenPost (fun st -> ignore(Stack.pop jumps); st)
    | Break(_) | Continue(_) ->
      Exits.add stmt (Stack.top jumps);
      SLocals.add stmt (List.flatten locals);
      Cil.DoChildren
    | Goto(sref, _)  ->
      SLocals.add stmt (List.flatten locals);
      Exits.add stmt !sref;
      LJumps.add !sref stmt;
      Cil.DoChildren
    | Instr(_) | Return(_) | If(_) | Block(_) | UnspecifiedSequence(_)
    | Throw(_) | TryCatch(_) | TryFinally(_) | TryExcept(_) ->
      (match stmt.labels with
      | [] -> ()
      | _ :: _ -> SLocals.add stmt (List.flatten locals));
      Cil.DoChildren
end

let generate fct =
  assert (is_empty ());
  ignore (Cil.visitCilFunction (new jump_context :> Cil.cilVisitor) fct)
