(**************************************************************************)
(*                                                                        *)
(*  This file is part of the Frama-C's E-ACSL plug-in.                    *)
(*                                                                        *)
(*  Copyright (C) 2012-2025                                               *)
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
open Interlang
module Term = Cil_datatype.Term

module Conf = struct
  type env =
    {kf : kernel_function;
     loc : location;
     vars : exp Term.Map.t;
     env : Env.t;
     rte : bool}

  type state = exp Term.Map.t (* local variables *)

  type out = unit
  let merge_out () () = ()
  let empty_out () = ()
end


exception Not_covered

include Conf

module M = struct
  include Monad_rws.Make (Conf)
  open Operators

  let not_covered ?pre pp x =
    let* {loc} = read in
    Options.debug
      ~dkey:Options.Dkey.interlang_not_covered "@[<2>@[%a: %a@]@;@[<2>%a@]@]"
      Printer.pp_location loc
      (Pretty_utils.pp_opt ~suf:": " Format.pp_print_string) pre
      pp x;
    raise Not_covered

  let read_logic_env = let* {env} = read in return @@ Env.Logic_env.get env
end

type 'a m = 'a M.t

let binop : Cil_types.binop -> Interlang.binop = function
  | Cil_types.PlusA -> Interlang.Plus
  | MinusA -> Minus
  | Mult -> Mult
  | Lt -> Lt
  | Gt -> Gt
  | Le -> Le
  | Ge -> Ge
  | Eq -> Eq
  | Ne -> Ne
  | Div -> Div
  | Mod -> Mod
  | _ -> raise Not_covered
