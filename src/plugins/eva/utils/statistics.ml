(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2024                                               *)
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

(* Statistics are stored in a dictionary, implemented as an hashtable from
   keys to integers.

   [Key] is the representation of the dictionary keys: a couple of a registered
   statistic (type ['a t]) accompanied by the function or the statement the stat
   is about (type ['a]).

   Statistics must be registered before usage. The registry keeps track of the
   registered statistics and allow the reloading of projects by matching the
   previous stats to the current ones.
*)

(* --- Type --- *)

type _ kind =
  | Global : unit kind
  | Function : Cil_types.kernel_function kind
  | Statement : Cil_types.stmt kind

type 'a t = {
  id: int;
  name: string;
  kind: 'a kind;
}


(* --- Registry --- *)

type registered_stat = Registered : 'a t -> registered_stat [@@unboxed]

let kind_to_string : type a. a kind -> string = function
  | Global -> "global"
  | Function  -> "function"
  | Statement -> "statement"

let registry = Hashtbl.create 13
let last_id = ref 0

let register (type a) (name : string) (kind : a kind) : a t =
  try
    (* If the stat is already registered, return the previous one *)
    let Registered stat = Hashtbl.find registry name in
    match stat.kind, kind with (* equality must be ensured to return the right type of stat *)
    | Global, Global -> stat
    | Function, Function -> stat
    | Statement, Statement -> stat
    | _ ->
      Self.fatal
        "%s statistic \"%s\" was already registered with as a %s statistic"
        name (kind_to_string kind) (kind_to_string stat.kind)
  with Not_found ->
    (* Otherwise, create a new record for the stat *)
    incr last_id;
    let stat = { id = !last_id; name; kind } in
    Hashtbl.add registry name (Registered stat);
    stat

let register_global_stat name =
  register name Global

let register_function_stat name =
  register name Function

let register_statement_stat name =
  register name Statement


(* --- Keys --- *)

type key = Key : 'a t * 'a -> key

module Key_Datatype = struct
  include Datatype.Serializable_undefined

  type t = key
  let name = "Statistics.Key"
  let rehash (Key (s, x)) =
    (Key (register s.name s.kind, x))
  let reprs = [Key ({ id = 0; name="dummy"; kind=Global }, ())]
  let equal = Datatype.from_compare
  let compare (Key (s1,x1)) (Key (s2,x2)) =
    let c = s1.id - s2.id in
    if c <> 0 then c else
      match s1.kind, s2.kind with
      | Global, Global -> 0
      | Function, Function -> Kernel_function.compare x1 x2
      | Statement, Statement -> Cil_datatype.Stmt.compare x1 x2
      | Global, (Function | Statement) -> -1
      | (Function | Statement), Global -> 1
      | Function, Statement -> -1
      | Statement, Function -> 1
  let hash (Key (s,x)) =
    let h = match s.kind with
      | Global -> 0
      | Function -> Kernel_function.hash x
      | Statement -> Cil_datatype.Stmt.hash x
    in
    Hashtbl.hash (s.id, h)
  let copy k = k
  let pretty fmt (Key (s,x)) =
    match s.kind with
    | Global ->
      Format.fprintf fmt "%s" s.name
    | Function ->
      Format.fprintf fmt "%s:%a" s.name Kernel_function.pretty x
    | Statement ->
      let loc = Cil_datatype.Stmt.loc x in
      Format.fprintf fmt "%s:%a" s.name Cil_datatype.Location.pretty loc
end

module Key = struct
  include Datatype.Make_with_collections (Key_Datatype)

  let name (Key (s, _x)) = s.name

  let pretty_kf fmt (Key (s, x)) =
    match s.kind with
    | Global -> ()
    | Function -> Kernel_function.pretty fmt x
    | Statement -> Kernel_function.(pretty fmt (find_englobing_kf x))

  let pretty_stmt fmt (Key (s, x)) =
    match s.kind with
    | Global | Function -> ()
    | Statement -> Cil_datatype.Location.pretty fmt (Cil_datatype.Stmt.loc x)
end

(* --- Projectified state --- *)

module State =
  State_builder.Hashtbl
    (Key.Hashtbl)
    (Datatype.Int)
    (struct
      let name = "Eva.Statistics.State"
      let dependencies = [ Self.state ]
      let size = 17
    end)


(* --- Statistics update --- *)

let set (type a) (stat : a t) (x : a) value =
  let k = Key (stat,x) in
  State.replace k value

let update (type a) (stat : a t) (x : a) (f : int -> int) =
  let k = Key (stat,x) in
  State.replace k (f (State.find_opt k |> Option.value ~default:0))

let incr (type a) (stat : a t) (x : a) =
  update stat x (fun v -> v + 1)

let grow (type a) (stat : a t) (x : a) value =
  update stat x (fun v -> max v value)

let reset_all () =
  State.clear ()


(* -- Export --- *)

let export_as_list () =
  State.to_seq () |> List.of_seq |>
  List.sort (fun (k1,_v1) (k2,_v2) -> Key.compare k1 k2)

let export_as_csv_to_channel out_channel =
  let fmt = Format.formatter_of_out_channel out_channel in
  let l = export_as_list () in
  let pp_stat fmt (key, value) =
    Format.fprintf fmt "%s\t%a\t%a\t%d\n"
      (Key.name key)
      Key.pretty_kf key
      Key.pretty_stmt key
      value
  in
  List.iter (pp_stat fmt) l

let export_as_csv_to_file filename =
  let out_channel = open_out (filename : Filepath.Normalized.t :> string) in
  export_as_csv_to_channel out_channel

let export_as_csv ?filename () =
  match filename with
  | None ->
    if not (Parameters.StatisticsFile.is_empty ()) then
      let filename = Parameters.StatisticsFile.get () in
      export_as_csv_to_file filename
  | Some filename ->
    export_as_csv_to_file filename
