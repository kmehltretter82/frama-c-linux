(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2021                                               *)
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

module Orig_project =
  State_builder.Option_ref(Project.Datatype)(
  struct
    let name = "Ast_diff.OrigProject"
    let dependencies = []
  end)

type 'a correspondance =
  [ `Same of 'a (** symbol with identical definition has been found. *)
  | `Not_present (** no correspondance *)
  ]

module Correspondance =
  Datatype.Polymorphic(
  struct
    type 'a t = 'a correspondance
    let name a = Type.name a ^ " correspondance"
    let module_name = "Correspondance"
    let structural_descr _ = Structural_descr.t_abstract
    let reprs x = [ `Not_present; `Same x]
    let mk_equal eq x y =
      match x,y with
      | `Same x, `Same y -> eq x y
      | `Not_present, `Not_present -> true
      | `Same _, `Not_present
      | `Not_present, `Same _ -> false
    let mk_compare cmp x y =
      match x,y with
      | `Not_present, `Not_present -> 0
      | `Not_present, `Same _ -> -1
      | `Same x, `Same y -> cmp x y
      | `Same _, `Not_present -> 1
    let mk_hash h = function
      | `Same x -> 117 * h x
      | `Not_present -> 43
    let map f = function
      | `Same x -> `Same (f x)
      | `Not_present -> `Not_present
    let mk_internal_pretty_code pp prec fmt = function
      | `Not_present -> Format.pp_print_string fmt "`Not_present"
      | `Same x ->
        let pp fmt = Format.fprintf fmt "`Same %a" (pp Type.Call) x in
        Type.par prec Call fmt pp
    let mk_pretty pp fmt = function
      | `Not_present -> Format.pp_print_string fmt "N/A"
      | `Same x -> Format.fprintf fmt " => %a" pp x
    let mk_varname v = function
      | `Not_present -> "x"
      | `Same x -> v x ^ "_c"
    let mk_mem_project mem query = function
      | `Not_present -> false
      | `Same x -> mem query x
  end
  )

type kf_correspondance =
  [ kernel_function correspondance
  | `Same_spec of kernel_function (** body has changed, but spec is identical *)
  ]

module Kf_correspondance =
  Datatype.Make(
  struct
    let name = "Kf_correspondance"
    module C = Correspondance.Make(Kernel_function)
    include Datatype.Serializable_undefined
    type t = kf_correspondance
    let reprs =
      let kf = List.hd Kernel_function.reprs in
      `Same_spec kf :: (C.reprs :> t list)
    let compare x y =
      match x,y with
      | `Same_spec f1, `Same_spec f2 -> Kernel_function.compare f1 f2
      | `Same_spec _, _ -> 1
      | _, `Same_spec _ -> -1
      | (#correspondance as x), (#correspondance as y) -> C.compare x y
    let equal = Datatype.from_compare
    let hash = function
      | `Same_spec f -> 57 * (Kernel_function.hash f)
      | #correspondance as x -> C.hash x
    let internal_pretty_code p fmt = function
      | `Same_spec f ->
        let pp fmt =
          Format.fprintf fmt "`Same %a"
            (Kernel_function.internal_pretty_code Type.Call) f
        in
        Type.par p Call fmt pp
      | #correspondance as x -> C.internal_pretty_code p fmt x
    let pretty fmt = function
      | `Same_spec f ->
        Format.fprintf fmt "-> (contract) %a" Kernel_function.pretty f
      | #correspondance as x -> C.pretty fmt x
  end)

module Info(I: sig val name: string end) =
  (struct
    let name = "Ast_diff." ^ I.name
    let dependencies = [Ast.self; Orig_project.self ]
    let size = 43
  end)

module Build(D:Datatype.S_with_collections) =
  State_builder.Hashtbl(D.Hashtbl)(Correspondance.Make(D))
    (Info(struct let name = "Ast_diff." ^ D.name end))

module Varinfo = Build(Cil_datatype.Varinfo)

module Compinfo = Build(Cil_datatype.Compinfo)

module Enuminfo = Build(Cil_datatype.Enuminfo)

module Enumitem = Build(Cil_datatype.Enumitem)

module Typeinfo = Build(Cil_datatype.Typeinfo)

module Stmt = Build(Cil_datatype.Stmt)

module Logic_info = Build(Cil_datatype.Logic_info)

module Logic_type_info = Build(Cil_datatype.Logic_type_info)

module Fieldinfo = Build(Cil_datatype.Fieldinfo)

module Model_info = Build(Cil_datatype.Model_info)

module Logic_var = Build(Cil_datatype.Logic_var)

module Kernel_function =
  State_builder.Hashtbl(Kernel_function.Hashtbl)(Kf_correspondance)
    (Info(struct let name = "Ast_diff.Kernel_function" end))

module Fundec = Build(Cil_datatype.Fundec)
