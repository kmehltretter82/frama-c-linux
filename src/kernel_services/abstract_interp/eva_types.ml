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

module Callstack =
struct
  module Thread = Int (* Threads are identified by integers *)
  module Kf = Kernel_function
  module Stmt = Cil_datatype.Stmt
  module Var = Cil_datatype.Varinfo

  module Call = Datatype.Pair_with_collections(Kf)(Stmt)
      (struct let module_name = "Eva.Callstack.Call" end)

  module Calls = Datatype.List (Call)

  type callstack = {
    thread: int;
    entry_point: Kernel_function.t;
    stack: Call.t list;
  }

  module Prototype =
  struct
    include Datatype.Serializable_undefined

    type t = callstack = {
      thread: int;
      entry_point: Kernel_function.t;
      stack: Call.t list;
    }
    [@@deriving eq, ord]

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
      Format.fprintf fmt "%a@]" Kernel_function.pretty cs.entry_point

    let hash cs =
      Hashtbl.hash
        (cs.thread, Kernel_function.hash cs.entry_point, Calls.hash cs.stack)
  end

  type call = Call.t

  include Datatype.Make_with_collections (Prototype)

  let pretty_debug = pretty

  let compare_lex cs1 cs2 =
    if cs1 == cs2 then 0 else
      let c = Thread.compare cs1.thread cs2.thread in
      if c <> 0 then c else
        let c = Kernel_function.compare cs1.entry_point cs2.entry_point in
        if c <> 0 then c else
          Calls.compare (List.rev cs1.stack) (List.rev cs2.stack)

  (* Stack manipulation *)

  let init ?(thread=0) kf = { thread; entry_point=kf; stack = [] }

  let push kf stmt cs =
    { cs with stack = (kf, stmt) :: cs.stack }

  let pop cs =
    match cs.stack with
    | [] -> None
    | _ :: tail -> Some { cs with stack = tail }

  let top cs =
    match cs.stack with
    | [] -> None
    | (kf, stmt) :: _ -> Some (kf, stmt)

  let top_kf cs =
    match cs.stack with
    | (kf, _stmt) :: _ -> kf
    | [] -> cs.entry_point

  let top_callsite cs =
    match cs.stack with
    | [] -> None
    | (_kf, stmt) :: _ -> Some (stmt)

  let top_call cs =
    match cs.stack with
    | (kf, stmt) :: _ -> kf, Cil_types.Kstmt stmt
    | [] -> cs.entry_point, Cil_types.Kglobal

  let last_caller cs =
    match cs.stack with
    | _ :: (kf, _) :: _ -> Some kf
    | [_] -> Some cs.entry_point
    | [] -> None

  (* Conversion *)

  let to_kf_list cs = cs.entry_point :: List.rev_map fst cs.stack
  let to_stmt_list cs = List.rev_map snd cs.stack

  let to_call_list cs =
    let l =
      List.rev_map (fun (kf, stmt) -> (kf, Cil_types.Kstmt stmt)) cs.stack
    in
    (cs.entry_point, Cil_types.Kglobal) :: l

  let to_legacy cs = List.rev (to_call_list cs)
end
