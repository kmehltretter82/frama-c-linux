(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2019                                               *)
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

open Cil
open Cil_types
open Visitor_behavior

module Stmt = Cil_datatype.Stmt
module StmtSet = Stmt.Hptset
module Location = Cil_datatype.Location

let error = Kernel.warning ~wkey:Kernel.wkey_ghost_bad_use

let noGhostBlock b =
  let noGhostVisitor = object (self)
    inherit genericCilVisitor (refresh (Project.current()))

    method private original = Get_orig.stmt self#behavior

    method! vstmt s =
      if s.ghost then begin
        s.skind <- Instr(Skip (Stmt.loc s)) ;
        s.labels <- [] ;
        s.ghost <- false ;
        SkipChildren
      end else
        begin match s.skind with
          | Switch(e, block, cases, loc) ->
            let cases = List.filter (fun s -> not (self#original s).ghost) cases in
            s.skind <- Switch(e, block, cases, loc) ;
            DoChildren
          | _ -> DoChildren
        end

    method getBehavior () = self#behavior
  end in
  (visitCilBlock (noGhostVisitor :> cilVisitor) b), (noGhostVisitor#getBehavior ())

let the l = match l with [ stmt ] -> stmt | _ -> assert false

let isSkip stmt =
  match stmt.skind with
  | Instr(Skip(_)) | Block(_) | Continue(_) | Break(_) -> true
  | _ -> false

type follower =
  | Infinite | Exit | Stmt of stmt

let rec skipSkip ?(visited=StmtSet.empty) s =
  if StmtSet.mem s visited then Infinite
  else match isSkip s with
    | false -> Stmt s
    | true when s.succs = [] -> Exit
    | _ -> skipSkip ~visited:(StmtSet.add s visited) (the s.succs)

let firstNonSkipNonGhosts stmt =
  let rec do_find ~visited stmt =
    if List.mem stmt !visited then []
    else begin
      visited := stmt :: !visited ;
      if isSkip stmt then do_find ~visited (the stmt.succs)
      else if not (stmt.ghost) then [ stmt ]
      else List.flatten (List.map (do_find ~visited) stmt.succs)
    end
  in
  do_find ~visited:(ref []) stmt

let alteredCFG stmt =
  error "Ghost code breaks CFG starting at: %a@.%a"
    Location.pretty (Stmt.loc stmt)
    Cil_printer.pp_stmt stmt

let rec checkGhostCFG bhv ?(visited=ref StmtSet.empty) withGhostStart noGhost =
  match (skipSkip withGhostStart), (skipSkip noGhost) with
  | Stmt withGhost, Stmt noGhost -> begin
      if StmtSet.mem withGhost !visited then ()
      else begin
        visited := StmtSet.add withGhost !visited ;
        let withGhost = List.sort_uniq Stmt.compare (firstNonSkipNonGhosts withGhost) in
        match withGhost, noGhost with
        | [ s1 ], s2 when s1.sid <> (Get_orig.stmt bhv s2).sid ->
          alteredCFG withGhostStart
        | [ { skind = If(_) } as s1 ], s2 ->
          checkIf bhv ~visited s1 s2
        | [ { skind = Switch(_) } as s1 ], s2 ->
          checkSwitch bhv ~visited s1 s2
        | [ { skind = Loop(_) } as s1 ], s2 ->
          checkLoop bhv ~visited s1 s2
        | [ { succs = [next_s1] } ], { succs = [next_s2] } ->
          checkGhostCFG bhv ~visited next_s1 next_s2
        | [ { succs = [] } ], { succs = [] } -> ()
        | _, _  ->
          alteredCFG withGhostStart
      end
    end ;
  | Exit, Exit | Infinite, Infinite -> ()
  | _ , _ -> alteredCFG withGhostStart
and checkIf bhv ~visited withGhost noGhost =
  let withGhostThen, withGhostElse = Cil.separate_if_succs withGhost in
  let noGhostThen  , noGhostElse   = Cil.separate_if_succs noGhost in
  checkGhostCFG bhv ~visited withGhostThen noGhostThen ;
  checkGhostCFG bhv ~visited withGhostElse noGhostElse
and checkLoop bhv ~visited withGhost noGhost =
  let withGhostBlock, noGhostBlock = match withGhost.skind, noGhost.skind with
    | Loop(_, b1, _, _, _), Loop(_, b2, _, _, _) -> b1, b2
    | _ -> assert false
  in
  match withGhostBlock.bstmts, noGhostBlock.bstmts with
  | s1 :: _ , s2 :: _ -> checkGhostCFG bhv ~visited s1 s2
  | _, _ -> ()
and checkSwitch bhv ~visited withGhost noGhost =
  let noGhostSuccs, noGhostDef = Cil.separate_switch_succs noGhost in
  let withGhostAllSuccs, withGhostDef = Cil.separate_switch_succs withGhost in
  let withGhostSuccsGhost, withGhostSuccsNonGhost =
    List.partition (fun s -> s.ghost) withGhostAllSuccs
  in
  let mustDefault = withGhostDef :: withGhostSuccsGhost in
  assert(List.length noGhostSuccs = List.length withGhostSuccsNonGhost) ;
  List.iter2 (checkGhostCFG bhv ~visited) withGhostSuccsNonGhost noGhostSuccs ;
  List.iter (fun s -> checkGhostCFG bhv ~visited s noGhostDef) mustDefault

let checkGhostCFGInFun (fd : fundec) =
  if fd.svar.vghost then ()
  else begin
    let noGhost, bhv = noGhostBlock fd.sbody in
    let vname = "__ghost_cfg_handler_" ^ fd.svar.vname in
    let vi = { fd.svar with vid = -1 ; vname ; vsource = false } in
    let noGhostFD = {
      svar = vi ; smaxid = 0; slocals = []; sformals = [];
      smaxstmtid = None; sallstmts = []; sspec = empty_funspec();
      sbody = noGhost;
    } in
    Cfg.clearCFGinfo ~clear_id:false noGhostFD ;
    Cfg.cfgFun noGhostFD ;
    checkGhostCFG bhv (List.hd fd.sbody.bstmts) (List.hd noGhostFD.sbody.bstmts)
  end

let checkGhostCFGInFile (f : file) =
  let visitor = object
    inherit Visitor.frama_c_inplace
    method! vfunc f = checkGhostCFGInFun f ; SkipChildren
  end in
  Visitor.visitFramacFileSameGlobals visitor f

let transform_category =
  File.register_code_transformation_category "Ghost CFG checking"

let () =
  File.add_code_transformation_after_cleanup
    transform_category checkGhostCFGInFile
