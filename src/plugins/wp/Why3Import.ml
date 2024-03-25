(**************************************************************************)
(*                                                                        *)
(*  This file is part of WP plug-in of Frama-C.                           *)
(*                                                                        *)
(*  Copyright (C) 2007-2023                                               *)
(*    CEA (Commissariat a l'energie atomique et aux energies              *)
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

module L = Wp_parameters
module T = Why3.Theory
module F = Filepath.Normalized
module W = Why3
module WConf = Why3.Whyconf

(* -------------------------------------------------------------------------- *)

let create_why3_env loadpath =
  let main = WConf.get_main @@ WConf.read_config None in
  W.Env.create_env @@ WConf.loadpath main @ F.to_string_list loadpath

let extract_path thname =
  let segments = String.split_on_char '.' thname in
  match List.rev segments with
  | hd :: tl -> hd, List.rev tl
  | [] -> "", []

(* For debug only*)
let pp_id fmt (id: W.Ident.ident) =
  Format.pp_print_string fmt id.id_string

(* logic_type =
  | Ctype of typ (** a C type *)
  | Ltype of logic_type_info * logic_type list
  (** an user-defined logic type with its parameters *)
  | Lvar of string (** a type variable. *)
  | Linteger (** mathematical integers, {i i.e.} Z *)
  | Lreal    (** mathematical reals, {i i.e.} R *)
  | Larrow of logic_type list * logic_type (** (n-ary) function type *)*)

(*logic_type_info = {
  mutable lt_name: string;
  lt_params : string list; (** type parameters*)
  mutable lt_def: logic_type_def option;
  (** definition of the type. None for abstract types. *)
  mutable lt_attr: attributes;
  (** attributes associated to the logic type.
      @since Phosphorus-20170501-beta1 *)
}*)

let rec lt_of_ts (_ty : W.Ty.ty) : Cil_types.logic_type  =
  raise Not_found
and lti_of_ls (tys : W.Ty.tysymbol) : Cil_types.logic_type_info  =
  {
    lt_name = tys.ts_name.id_string;
    lt_params = [""];
    lt_def = None;
    lt_attr = [];
  }

let import_theory env thname =
  let theory_name, theory_path = extract_path thname in
  try
    let theory = W.Env.read_theory env theory_path theory_name in
    List.iter (fun (tdecl : T.tdecl) ->
        match tdecl.td_node with
        | Decl decl ->
          begin
            match decl.d_node with
            | Dtype ts ->
              L.debug ~level:0 "Decl and type %a.@"  pp_id ts.ts_name
            | Ddata ddatas ->
              List.iter
                (fun ((ts, _) : W.Decl.data_decl) ->
                   L.debug ~level:0 "Decl and data %a.@" pp_id  ts.ts_name
                ) ddatas
            | Dparam ls ->
              L.debug ~level:0 "Decl and dparam %a.@" pp_id ls.ls_name
            | Dlogic dlogics ->
              List.iter
                (fun ((ls,_):W.Decl.logic_decl) ->
                   L.debug ~level:0 "Decl and dlogic %a.@" pp_id ls.ls_name
                ) dlogics
            | _ -> L.debug ~level:0 "Decl but whatever"
          end
        | Use _ -> L.debug ~level:0 "Use"
        | Clone _ -> L.debug ~level:0 "Clone"
        | Meta _ -> L.debug ~level:0 "Meta"
      ) theory.th_decls
  with W.Env.LibraryNotFound _ ->
    L.error "Library %s not found" thname

let () =
  Boot.Main.extend
    begin fun () ->
      let env = create_why3_env @@ L.Library.get () in
      List.iter (import_theory env) @@ L.Import.get ()
    end

(* -------------------------------------------------------------------------- *)
