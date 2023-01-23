(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2023                                               *)
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

module Thread = Int (* Threads are identified by integers *)
module Kf = Kernel_function
module Stmt = Cil_datatype.Stmt

type call = Cil_types.kernel_function * Cil_types.stmt

module Call = Datatype.Pair_with_collections(Kf)(Stmt)
    (struct let module_name = "Eva.Callstack.Call" end)


module Calls = Datatype.List (Call)

type callstack = {
  thread: int;
  entry_point: Cil_types.kernel_function;
  stack: call list;
}


(* Datatype *)

module Prototype =
struct
  include Datatype.Serializable_undefined

  type t = callstack

  let name = "Eva.Callstack"

  let reprs =
    List.concat_map (fun stack ->
        List.map (fun entry_point -> { thread = 0; entry_point; stack })
          Kernel_function.reprs)
      Calls.reprs

  let pretty fmt cs =
    let pp_call fmt (kf,stmt) =
      Format.fprintf fmt "%a :: %a <-@ "
        Kf.pretty kf
        Cil_datatype.Location.pretty (Stmt.loc stmt)
    in
    Format.fprintf fmt "@[<hv>";
    List.iter (pp_call fmt) cs.stack;
    Format.fprintf fmt "%a@]" Kf.pretty cs.entry_point

  let equal cs1 cs2 =
    Thread.equal cs1.thread cs2.thread &&
    Calls.equal cs1.stack cs2.stack &&
    Kf.equal cs1.entry_point cs2.entry_point

  let compare cs1 cs2 =
    let r = Thread.compare cs1.thread cs2.thread in
    if r <> 0 then r else
      let r = Kf.compare cs1.entry_point cs2.entry_point in
      if r <> 0 then r else
        Calls.compare cs1.stack cs2.stack

  let hash cs =
    Hashtbl.hash (cs.thread, Kf.hash cs.entry_point, Calls.hash cs.stack)
end

include Datatype.Make_with_collections (Prototype)


(* Constructors *)

let init ?(thread=0) entry_point = { thread ; entry_point ; stack = [] }

let of_legacy (cs : Value_types.callstack) =
  let rec aux acc = function
    | (kf, Cil_types.Kstmt stmt) :: tail -> aux ((kf, stmt) :: acc) tail
    | [(kf, Kglobal)] ->
      { thread = 0 ; entry_point = kf ; stack = List.rev acc }
    | _ -> assert false
  in
  aux [] cs


(* Stack manipulation *)

let push kf stmt cs =
  { cs with stack = (kf, stmt) :: cs.stack }

let pop cs =
  match cs.stack with
  | [] -> None
  | (kf,stmt) :: tail -> Some (kf, stmt, { cs with stack = tail })

let top cs =
  match cs.stack with
  | [] -> None
  | (kf, stmt) :: _ -> Some (kf, stmt)

let top_kf cs =
  match cs.stack with
  | [] -> cs.entry_point
  | (kf, _stmt) :: _ -> kf

let top_callsite cs =
  match cs.stack with
  | [] -> None
  | (_kf, stmt) :: _ -> Some (stmt)

(* Conversion *)

let to_legacy cs =
  let l = List.rev_map (fun (kf, stmt) -> (kf, Cil_types.Kstmt stmt)) cs.stack in
  List.rev ((cs.entry_point, Cil_types.Kglobal) :: l)

let to_kf_list cs =
  cs.entry_point :: List.rev_map fst cs.stack

let to_stmt_list cs =
  List.rev_map snd cs.stack
