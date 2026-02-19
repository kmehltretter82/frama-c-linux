(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

let dkey_shell = Wp_parameters.register_category "shell"

type t =
  | Why3 of Why3Provers.t
  | Qed
  | Tactical

let provers () =
  List.map (fun p -> Why3 p) @@
  List.filter Why3Provers.is_mainstream @@
  Why3Provers.provers ()

let iter_provers f =
  List.iter f @@ provers ()

let equal p q =
  match p,q with
  | Qed,Qed -> true
  | Tactical,Tactical -> true
  | Why3 p, Why3 q -> Why3Provers.equal p q
  | (Why3 _ | Qed | Tactical) , _ -> false

let compare p q =
  match p,q with
  | Qed , Qed -> 0
  | Qed , _ -> (-1)
  | _ , Qed -> (+1)
  | Why3 p , Why3 q -> Why3Provers.compare p q
  | Why3 _ , _ -> (-1)
  | _ , Why3 _ -> (+1)
  | Tactical , Tactical -> 0

let ident = function
  | Why3 s -> Why3Provers.ident_wp s
  | Qed -> "qed"
  | Tactical -> "script"

let name = function
  | Why3 s -> Why3Provers.name s
  | Qed -> "Qed"
  | Tactical -> "Script"

let shortcut = function
  | Why3 s -> String.lowercase_ascii @@ Why3Provers.name s
  | Qed -> "qed"
  | Tactical -> "script"

let version = function
  | Why3 p -> Why3Provers.version p
  | _ -> System_config.Version.id_and_codename

let parse = function
  | "" | "none" -> None
  | "qed" | "Qed" -> Some Qed
  | "script" -> Some Tactical
  | "tip" -> Some Tactical
  | "why3" -> Some (Why3 { Why3.Whyconf.prover_name = "why3";
                           Why3.Whyconf.prover_version = "";
                           Why3.Whyconf.prover_altern = "generate only" })
  | name ->
    match Why3Provers.lookup name with
    | Some p -> Some (Why3 p)
    | None -> None

let title ?version = function
  | Why3 s ->
    let version = match version with Some v -> v | None ->
      not (Wp_parameters.has_dkey dkey_shell)
    in Why3Provers.title ~version s
  | Qed -> "Qed"
  | Tactical -> "Script"

let pretty fmt p = Format.pp_print_string fmt (title p)

let is_auto = function
  | Qed -> true
  | Tactical -> false
  | Why3 p -> Why3Provers.is_auto p

let is_tactical = function
  | Qed | Why3 _ -> false
  | Tactical -> true

let is_extern = function
  | Qed | Tactical -> false
  | Why3 _ -> true

let has_counter_examples = function
  | Qed | Tactical -> false
  | Why3 p -> Why3Provers.with_counter_examples p <> None

let sanitize_why3 s =
  let buffer = Buffer.create 80 in
  assert (s <> "ide");
  Buffer.add_string buffer "Why3_" ;
  String.iter
    (fun c ->
       let c = if
         ('0' <= c && c <= '9') ||
         ('a' <= c && c <= 'z') ||
         ('A' <= c && c <= 'Z')
         then c else '_'
       in Buffer.add_char buffer c) s ;
  Buffer.contents buffer

let filename_for = function
  | Why3 s -> sanitize_why3 (Why3Provers.ident_wp s)
  | Qed -> "Qed"
  | Tactical -> "Tactical"


let of_name ?fallback = function
  | "qed" -> Some Qed
  | "script" -> Some Tactical
  | name ->
    match Why3Provers.lookup ?fallback name with
    | None -> None
    | Some prv -> Some (Why3 prv)

module P = struct type nonrec t = t let compare = compare end
module Pset = Set.Make(P)
module Pmap = Map.Make(P)

module InteractiveMode = struct
  type t =
    | Batch
    | Update
    | Edit
    | Fix
    | FixUpdate

  let title = function
    | Fix -> "Fix"
    | Edit -> "Edit"
    | Batch -> "Batch"
    | Update -> "Update"
    | FixUpdate -> "Fix Update"

  let parse m =
    match String.lowercase_ascii m with
    | "fix" -> Fix
    | "edit" -> Edit
    | "batch" -> Batch
    | "update" -> Update
    | "fixup" -> FixUpdate
    | _ ->
      Wp_parameters.error ~once:true
        "Unrecognized mode %S (use 'batch' instead)" m ; Batch

  let pretty fmt m = Format.pp_print_string fmt (title m)
end

module TipMode = struct
  type t =
    | Batch
    | Update
    | Dry
    | Init

  let parse ~origin ~fallback = function
    | "batch" -> Batch
    | "update" -> Update
    | "dry" -> Dry
    | "init" -> Init
    | "" -> raise Not_found
    | m ->
      Wp_parameters.warning ~current:false
        "Unknown %s mode %S (use %s instead)" origin m fallback ;
      raise Not_found

  module MODE = WpContext.StaticGenerator(Datatype.Unit)
      (struct
        type key = unit
        type data = t
        let name = "Wp.Script.mode"
        let compile () =
          try
            if not (Wp_parameters.CacheEnv.get()) then
              raise Not_found ;
            let origin = "FRAMAC_WP_SCRIPT" in
            parse ~origin ~fallback:"-wp-script" (Sys.getenv origin)
          with Not_found ->
          try
            let mode = Wp_parameters.ScriptMode.get() in
            parse ~origin:"-wp-script" ~fallback:"batch" mode
          with Not_found ->
            let provers = Wp_parameters.Provers.get () in
            if List.mem "tip" provers then Update else
            if List.mem "script" provers then Batch else
              Dry
      end)

  let get = MODE.get
  let set m = MODE.set () m

  let is_scratch () =
    match MODE.get () with
    | Batch | Update -> false
    | Dry | Init -> true

  let is_saving () =
    match MODE.get () with
    | Update | Init -> true
    | Batch | Dry -> false

end
