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

  type local_stack = {
    thread: int;
    entry_point: Kernel_function.t;
    stack: Call.t list;
  }

  module LocalStack =
  struct
    type t = local_stack = {
      thread: int;
      entry_point: Kernel_function.t;
      stack: Call.t list;
    }
    [@@deriving eq, ord]

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

    let compare_lex ls1 ls2 =
      if ls1 == ls2 then 0 else
        let c = Thread.compare ls1.thread ls2.thread in
        if c <> 0 then c else
          let c = Kernel_function.compare ls1.entry_point ls2.entry_point in
          if c <> 0 then c else
            Calls.compare (List.rev ls1.stack) (List.rev ls2.stack)

    let hash cs =
      Hashtbl.hash
        (cs.thread, Kernel_function.hash cs.entry_point, Calls.hash cs.stack)
  end

  type call = Call.t

  type callstack =
    | Global of Cil_datatype.Varinfo.t
    | Local of LocalStack.t

  (* Datatype *)

  module Prototype =
  struct
    open Cil_datatype
    include Datatype.Serializable_undefined

    type t = callstack =
      | Global of Varinfo.t
      | Local of LocalStack.t
    [@@deriving eq, ord]

    let name = "Eva.Callstack"

    let reprs =
      List.map (fun vi -> Global vi) Varinfo.reprs @
      List.map (fun ls -> Local ls) LocalStack.reprs

    let pretty fmt cs =
      match cs with
      | Global vi -> Format.fprintf fmt "init %a" Varinfo.pretty vi
      | Local ls -> LocalStack.pretty fmt ls

    let hash cs =
      match cs with
      | Global vi -> Hashtbl.hash (1, Varinfo.hash vi)
      | Local ls -> Hashtbl.hash (2, LocalStack.hash ls)
  end

  include Datatype.Make_with_collections (Prototype)

  let compare_lex cs1 cs2 =
    match cs1, cs2 with
    | Local ls1, Local ls2 -> LocalStack.compare_lex ls1 ls2
    | cs1, cs2 -> compare cs1 cs2

  (* Constructor *)

  let init_global vi =
    Global vi

  let init_local ?(thread=0) kf =
    Local { thread; entry_point=kf; stack = [] }

  (* Query *)

  let is_local = function
    | Global _ -> false
    | Local _ -> true

  (* Stack manipulation *)

  let local = function
    | Global _vi ->
      invalid_arg "invalid stack manipulation on a global callstack"
    | Local ls -> ls

  let push kf stmt cs =
    let ls = local cs in
    Local { ls with stack = (kf, stmt) :: ls.stack }

  let pop cs =
    match cs with
    | Global _vi -> None
    | Local ls ->
      match ls.stack with
      | [] -> None
      | (kf,stmt) :: tail -> Some (kf, stmt, Local { ls with stack = tail })

  let top cs =
    match cs with
    | Global _vi -> None
    | Local ls ->
      match ls.stack with
      | [] -> None
      | (kf, stmt) :: _ -> Some (kf, stmt)

  let top_kf cs =
    let ls = local cs in
    match ls.stack with
    | (kf, _stmt) :: _ -> kf
    | [] -> ls.entry_point

  let top_callsite cs =
    match cs with
    | Global _vi -> None
    | Local ls ->
      match ls.stack with
      | [] -> None
      | (_kf, stmt) :: _ -> Some (stmt)

  let top_call cs =
    let ls = local cs in
    match ls.stack with
    | (kf, stmt) :: _ -> kf, Cil_types.Kstmt stmt
    | [] -> ls.entry_point, Cil_types.Kglobal


  (* Conversion *)

  let to_legacy cs =
    match cs with
    | Global _vi -> []
    | Local ls ->
      let l =
        List.rev_map (fun (kf, stmt) -> (kf, Cil_types.Kstmt stmt)) ls.stack
      in
      List.rev ((ls.entry_point, Cil_types.Kglobal) :: l)

  let to_kf_list cs =
    match cs with
    | Global _vi -> []
    | Local ls ->
      ls.entry_point :: List.rev_map fst ls.stack

  let to_stmt_list cs =
    match cs with
    | Global _vi -> []
    | Local ls ->
      List.rev_map snd ls.stack
end
