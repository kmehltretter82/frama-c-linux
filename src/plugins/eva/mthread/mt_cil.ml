(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2025                                               *)
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


let mthread_global_var var_name () =
  try Globals.Vars.find_from_astinfo var_name Global
  with Not_found ->
    MtOptions.fatal
      "Variable@ %s@ not@ found.@ It@ should@ be@ in@ %a."
      var_name Filepath.Normalized.pretty (MtLib.mthread_h ())

let is_call_to_sync stmt =
  match stmt.skind with
  | Instr (Call (_, { enode = Lval (Var vi, _)}, _, _))
    when vi.vname = "Frama_C_mthread_sync" -> true
  (* No Local_init possible here, as Frama_C_mthread_sync returns void. *)
  | _ -> false

(* -------------------------------------------------------------------------- *)
(* --- Pretty-printing                                                    --- *)
(* -------------------------------------------------------------------------- *)

let pretty_stmt fmt stmt =
  Printer.pp_location fmt (Cil_datatype.Stmt.loc stmt);
  if MtOptions.ShowSid.get () then
    Format.fprintf fmt "@ (sid %d)" stmt.sid


let kinstr_to_source = function
  | Kglobal -> None
  | Kstmt stmt -> Some (fst (Cil_datatype.Stmt.loc stmt))


let pretty_succs fmt stmt =
  (Pretty_utils.pp_list ~sep:" "
     (fun fmt s -> Format.fprintf fmt "%d" s.sid)) fmt stmt.succs



(* -------------------------------------------------------------------------- *)
(* --- Stacks                                                             --- *)
(* -------------------------------------------------------------------------- *)

type stack_elt = kernel_function * kinstr

module StackElt = struct
  include Datatype.Pair(Kernel_function)(Cil_datatype.Kinstr)

  let pretty fmt (f, ki) =
    Format.fprintf fmt "@[<hov 2>%s%t@]"
      (Ast_info.Function.get_name f.fundec)
      (fun fmt -> match ki with
         | Kstmt stmt ->
           let loc = Cil_datatype.Stmt.loc stmt in
           Format.fprintf fmt " :: %a" Cil_datatype.Location.pretty loc
         | Kglobal -> ()
      )

end

type stack = stack_elt list

module Stack = struct

  include Datatype.List(StackElt)

  let pretty =
    Pretty_utils.pp_list ~pre:"@[<hv>" ~sep:" <-@ " ~suf:"@]" StackElt.pretty

  module FunAccessVars =
    State_builder.Option_ref(Cil_datatype.Kf)
      (struct let dependencies = [Ast.self]
        let name = "Stack.FunAccessVars"
      end)

  let fun_access_vars () =
    FunAccessVars.memo (fun () -> Kernel_function.dummy ())

  let access_to_var stmt : stack_elt = fun_access_vars (), Kstmt stmt
  let is_access_to_var (kf, _) =
    Kernel_function.equal kf (fun_access_vars ())

end
