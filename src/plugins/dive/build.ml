(**************************************************************************)
(*                                                                        *)
(*  This file is part of the Frama-C plug-in `IIG'.                       *)
(*                                                                        *)
(*  Copyright (C) 2018                                                    *)
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

open Cil_types

module G = Imprecision_graph
open G

let location_to_lval location =
  let open Locations in
  match location.loc with
  | Location_Bits.Top _ -> None
  | Location_Bits.Map _m -> None  (* 
    let to_lval base ival acc =
      if Extlib.has_somme acc then raise Exit;

    in
    try
      Locations_Bits.fold to_lval m None
    with Exit -> None *)


let compute kinstr lval =
  let module Table = Cil_datatype.LvalStructEq.Hashtbl in
  !Db.Value.compute ();
  let graph = G.create () in
  let vertex_count = ref 0 in
  let edge_count = ref 0 in
  let table = Table.create 13 in

  let add_vertex vertex_lval =
    let v = {
      vertex_key = !vertex_count;
      vertex_lval;
    }
    in
    incr vertex_count;
    G.add_vertex graph v;
    v

  and add_edge v1 edge_kind v2 =
    let e = {
      edge_key = !edge_count;
      edge_kind;
    }
    in
    incr edge_count;
    G.add_edge_e graph (v1,e,v2)
  in

  let rec build_lval kinstr lval = (* TODO: derecursify if necessary *)
    let location = !Db.Value.lval_to_loc kinstr lval in
    let lval = Extlib.opt_conv lval (location_to_lval location) in
    try
      Table.find table lval
    with Not_found ->
      let v = add_vertex lval in
      Table.add table lval v;
      begin match lval with
        | Var vi, NoOffset when vi.vformal ->
          let kf = Extlib.the (Kernel_function.find_defining_kf vi) in
          let pos = Kernel_function.get_formal_position vi kf in
          let callsites = Kernel_function.find_syntactic_callsites kf
          and add_argument_dependencies (_caller_kf, stmt) =
            match stmt.skind with
            | Instr (Call (_,_,args,_))
            | Instr (Local_init (_, ConsInit (_, args, _), _)) ->
              let exp = List.nth args pos in
              build_exp_deps v (Kstmt stmt) Data exp
            | _ ->
              Self.abort "%a" Cil_printer.pp_stmt stmt;
              assert false (* TODO: comment *)
          in
          List.iter add_argument_dependencies callsites
        | _ -> ()
      end;

      if Locations.valid_cardinal_zero_or_one ~for_writing:false location then begin
        let zone = !Db.Value.lval_to_zone kinstr lval in
        let writes = Studia.Writes.compute zone
        and add_write_dependencies (stmt,effects) =
          match stmt.skind with
          | Instr instr when effects.Studia.Writes.direct ->
            build_instr_deps v (Kstmt stmt) instr
          | _ -> ()
        in
        List.iter add_write_dependencies writes;
      end;
      v

  and build_instr_deps src kinstr = function
    | Set (_, exp, _) | Local_init (_,AssignInit (SingleInit exp),_) ->
      build_exp_deps  src kinstr Data exp
    | Call (_, _callee, args, _) ->
      (* build_exp_deps src kinstr Callee callee; *)
      List.iter (build_exp_deps src kinstr Data) args
    | Local_init (_, ConsInit (_, args, _), _) ->
      List.iter (build_exp_deps src kinstr Data) args
    | Local_init _ -> () (* TODO *)
    | Asm _ -> () (* TODO : tell the user it's not supported *)
    | Skip _ | Code_annot _ -> ()

  and build_exp_deps src kinstr kind exp =
    match exp.enode with
    | Const _
    | SizeOf _ | SizeOfE _ | SizeOfStr _
    | AlignOf _ -> () | AlignOfE _
    | AddrOf _ | StartOf _     -> ()
    | Lval lval ->
      build_lval_deps src kinstr kind lval
    | UnOp (_,e,_) | CastE (_,e) | Info (e,_) ->
      build_exp_deps src kinstr kind e
    | BinOp (_,e1,e2,_) ->
      build_exp_deps src kinstr kind e1;
      build_exp_deps  src kinstr kind e2

  and build_lval_deps src kinstr kind lval =
    let dst = build_lval kinstr lval in
    add_edge src kind dst
  in
  ignore (build_lval kinstr lval);
  graph

  (* 
  Self.result "%a -> %t"
    Locations.Zone.pretty_debug zone
    (fun fmt -> List.iter (fun (s,_) -> Cil_printer.pp_stmt fmt s) l) *)