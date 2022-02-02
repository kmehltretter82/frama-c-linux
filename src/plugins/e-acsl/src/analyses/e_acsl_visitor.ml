(**************************************************************************)
(*                                                                        *)
(*  This file is part of the Frama-C's E-ACSL plug-in.                    *)
(*                                                                        *)
(*  Copyright (C) 2012-2021                                               *)
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

let case_globals
    ~default
    ?(builtin = fun _ -> default ())
    ?(fc_compiler_builtin = fun _ -> default ())
    ?(rtl_symbol = fun _ -> default ())
    ?(fc_stdlib_generated = fun _ -> default ())
    ?(var_fun_decl = fun _ -> default ())
    ?(var_init = fun _ -> default ())
    ?(var_def = fun _ _ -> default ())
    ~fun_def
  = function
    (* library functions and built-ins *)
    | GVarDecl(vi, _) | GVar(vi, _, _)
    | GFunDecl(_, vi, _) | GFun({ svar = vi }, _) when Builtins.mem vi.vname ->
      builtin vi

    (* Cil built-ins and other library globals*)
    | GVarDecl(vi, _) | GVar(vi, _, _) | GFun({ svar = vi }, _)
      when Misc.is_fc_or_compiler_builtin vi ->
      fc_compiler_builtin vi

    | g when Rtl.Symbols.mem_global g ->
      rtl_symbol g

    (* generated function declaration *)
    | GFunDecl(_, vi, _) when Misc.is_fc_stdlib_generated vi ->
      fc_stdlib_generated vi

    (* variable declarations *)
    | GVarDecl(vi, _) | GFunDecl(_, vi, _) ->
      var_fun_decl vi

    (* variable definition *)
    | GVar(vi, { init = None }, _) ->
      var_init vi

    | GVar(vi, { init = Some init }, _) ->
      var_def vi init

    (* function definition *)
    | GFun(fundec, _) ->
      fun_def fundec

    (* other globals: nothing to do *)
    | GType _
    | GCompTag _
    | GCompTagDecl _
    | GEnumTag _
    | GEnumTagDecl _
    | GAsm _
    | GPragma _
    | GText _
    | GAnnot _ (* do never read annotation from sources *)
      ->
      default ()

class visitor
  = object(self)
    inherit Visitor.frama_c_inplace

    method private default : unit -> global list Cil.visitAction =
      fun _ -> Cil.SkipChildren

    method builtin : varinfo -> global list Cil.visitAction =
      fun _ -> self#default ()

    method fc_compiler_builtin : varinfo -> global list Cil.visitAction =
      fun _ -> self#default ()

    method rtl_symbol : global -> global list Cil.visitAction =
      fun _ -> self#default ()

    method fc_stdlib_generated : varinfo -> global list Cil.visitAction =
      fun _ -> self#default ()

    method var_fun_decl : varinfo -> global list Cil.visitAction =
      fun _ -> self#default ()

    method var_init : varinfo -> global list Cil.visitAction =
      fun _ -> self#default ()

    method var_def : varinfo -> init -> global list Cil.visitAction =
      fun _ _ -> self#default ()

    method fun_def ({svar = vi}) =
      let kf = try Globals.Functions.get vi with Not_found -> assert false in
      if Functions.check kf then Cil.DoChildren else Cil.SkipChildren

    method !vglob_aux =
      case_globals
        ~default:self#default
        ~builtin:self#builtin
        ~fc_compiler_builtin:self#fc_compiler_builtin
        ~rtl_symbol:self#rtl_symbol
        ~fc_stdlib_generated:self#fc_stdlib_generated
        ~var_fun_decl:self#var_fun_decl
        ~var_init:self#var_init
        ~var_def:self#var_def
        ~fun_def:self#fun_def
  end
