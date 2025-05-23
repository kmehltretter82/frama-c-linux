(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

open Cil_types

module Typ = struct
  let params typ =
    match Ast_types.unroll_node typ with
    | TFun (_, args, _) -> Cil.argsToList args
    | _ -> invalid_arg "params"

  let ghost_partitioned_params typ =
    match Ast_types.unroll_node typ with
    | TFun (_, args, _) -> Cil.argsToPairOfLists args
    | _ -> invalid_arg "params"

  let params_types typ =
    List.map (fun (_,typ,_) -> typ) (params typ)

  let params_count typ =
    List.length (params typ)
end

module List = struct
  include List

  let rec make n a =
    if n <= 0 then []
    else a :: make (n - 1) a

  let rec take n l =
    if n <= 0 then []
    else match l with
      | [] -> []
      | a :: l -> a :: take (n - 1) l

  let rec drop n l =
    if n <= 0 then l
    else match l with
      | [] -> []
      | _ :: l -> drop (n - 1) l

  let rec break n l =
    if n <= 0 then ([], l)
    else match l with
      | [] -> ([], [])
      | a :: l ->
        let l1, l2 = break (n - 1) l in
        (a :: l1, l2)

  let mapi2 f l1 l2 =
    let i = ref 0 in
    let rec aux l1 l2 = match l1, l2 with
      | [], [] -> []
      | a1 :: l1, a2 :: l2 -> let r = f !i a1 a2 in incr i; r :: aux l1 l2
      | _, _ -> invalid_arg "List.mapi2"
    in
    aux l1 l2

  let ifind f l =
    let i = ref 0 in
    let rec aux = function
      | [] -> raise Not_found
      | a :: l -> if not (f a) then (incr i; aux l)
    in aux l; !i
end
