(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2025                                               *)
(*    CEA (Commissariat à l'énergie atomique et aux énergies              *)
(*         alternatives)                                                  *)
(*                                                                        *)
(*  All rights reserved.                                                  *)
(*  Contact CEA LIST for licensing.                                       *)
(*                                                                        *)
(**************************************************************************)

open Cil_types
open MtLib
open MtMemory.Types


type id_type = IdThread | IdMutex | IdQueue

module IdType = struct
  include Datatype.Make(
    struct
      type t = id_type
      let name = "MtMemory.id_type"
      let equal : t -> t -> bool = (==)
      let compare: t -> t -> int = Stdlib.compare
      let hash: t -> int = Hashtbl.hash
      let pretty fmt = function
        | IdThread -> Format.fprintf fmt "Thread"
        | IdMutex -> Format.fprintf fmt "Mutex"
        | IdQueue -> Format.fprintf fmt "Queue"
      let reprs = [IdThread;IdMutex;IdQueue]

      let rehash = Datatype.identity
      let copy = Datatype.identity
      let structural_descr = Structural_descr.t_abstract
      let mem_project = Datatype.never_any_project
    end)
  let format_lc : t -> (_, _, _, _, _, _) format6 = function
    | IdThread -> "thread"
    | IdMutex -> "mutex"
    | IdQueue -> "queue"

  let pretty_lc fmt lc = Format.fprintf fmt (format_lc lc)


  let pretty_lc_plural fmt = function
    | IdThread -> Format.fprintf fmt "threads"
    | IdMutex -> Format.fprintf fmt "mutexes"
    | IdQueue -> Format.fprintf fmt "queues"

end

type raw_id = id_type * int

module RawId = struct
  include Datatype.Pair_with_collections(IdType)(Datatype.Int)

  let pretty fmt (idt, offset) =
    Format.fprintf fmt "%a_%d" IdType.pretty_lc idt offset
end

module MapCreation = Map.Make(Datatype.Pair(RawId)(Eva.Callstack))

type id_name_hint =
  | Hint_pointer of pointer
  | Hint_string of string
  | NoHint

module IdNameHint =
  Datatype.Make_with_collections(
  struct
    type t = id_name_hint
    let name = "MtMemory.id_name_hint"

    let equal h1 h2 = match h1, h2 with
      | Hint_pointer p1, Hint_pointer p2 -> Pointer.equal p1 p2
      | Hint_string s1, Hint_string s2 -> s1 = s2
      | NoHint, NoHint -> true
      | _ -> false

    let compare h1 h2 = match h1, h2 with
      | Hint_pointer p1, Hint_pointer p2 -> Pointer.compare p1 p2
      | Hint_string s1, Hint_string s2 -> String.compare s1 s2
      | NoHint, NoHint -> 0
      | (Hint_pointer _ | Hint_string _ | NoHint), _ ->
        MtLib.compare_tag h1 h2

    let hash = function
      | Hint_pointer p -> 3 + Pointer.hash p
      | Hint_string s -> Hashtbl.hash s
      | NoHint -> 7

    let pretty fmt = function
      | Hint_pointer p -> Pointer.pretty fmt p
      | Hint_string s -> Format.pp_print_string fmt s
      | NoHint -> Format.pp_print_string fmt "_"

    let rehash = Datatype.identity
    let copy = Datatype.identity
    let structural_descr = Structural_descr.t_abstract
    let mem_project = Datatype.never_any_project

    let reprs = [NoHint; Hint_string ""]
  end)


type id = {
  id_raw: raw_id;
  id_creator: id;
  mutable id_updated: int;
  mutable id_name: string;
  mutable id_name_hint: id_name_hint;
}

let raw_id_main_thread = IdThread, 1

let rec id_main_thread = {
  id_raw = raw_id_main_thread;
  id_name = "_main_";
  id_name_hint = Hint_string "_main_";
  id_creator = id_main_thread;
  id_updated = 0;
}

module Id = struct
  include Datatype.Make_with_collections(
    struct
      type t = id
      let name = "MtIds.id"
      let reprs = [id_main_thread]

      let compare id1 id2 = RawId.compare id1.id_raw id2.id_raw
      let hash id = RawId.hash id.id_raw
      let equal id1 id2 = RawId.equal id1.id_raw id2.id_raw

      let pretty fmt id = Format.pp_print_string fmt id.id_name

      let rehash = Datatype.identity
      let copy = Datatype.identity
      let structural_descr = Structural_descr.t_abstract
      let mem_project = Datatype.never_any_project

    end)

  type set = Set.t
  type 'a map = 'a Map.t

  let compare_by_name id1 id2 =
    if equal id1 id_main_thread then -1 else
    if equal id2 id_main_thread then 1 else
      MtLib.comp IdNameHint.compare id1.id_name_hint id2.id_name_hint
        String.compare id1.id_name id2.id_name

  let id_type id = fst id.id_raw

  let sanitize_name ?(char='_') id =
    let s = Format.asprintf "%a" pretty id in
    let is_invalid c =
      match c with
      | '&' | '+' | '[' | ']' | '.' -> true
      | _ -> false
    in
    String.map (fun c -> if is_invalid c then char else c) s

end


type known_ids = {
  ids_infos: id RawId.Map.t;
  ids_by_names: raw_id IdNameHint.Map.t;
  ids_by_stacks: raw_id MapCreation.t;
  next_thread_id: int;
  next_mutex_id: int;
  next_queue_id: int;
}


(* Initial state. The main thread is pre-registered, all the offsets
   start at 1 because some programs use the convention (offset == 0)
   to mean not-initialized *)
let no_known_ids = {
  next_thread_id = 2;
  next_mutex_id = 1;
  next_queue_id = 1;
  ids_by_stacks = MapCreation.empty;
  ids_by_names = IdNameHint.Map.empty;
  ids_infos = RawId.Map.add raw_id_main_thread id_main_thread RawId.Map.empty;
}

let find_id known ((idt, offset): raw_id) =
  try `Success (RawId.Map.find (idt, offset) known.ids_infos)
  with Not_found ->
    `Failure (fun fmt ->
        Format.fprintf fmt "Id %d for %a does not exists@ (incrementation@ \
                            inside@ program?)."
          offset IdType.pretty_lc_plural idt)

let all_ids_by_idtype idt known =
  RawId.Map.fold
    (fun (idt', _) id s ->
       if IdType.equal idt idt' then Id.Set.add id s else s)
    known.ids_infos Id.Set.empty

let all_threads = all_ids_by_idtype IdThread
let all_mutexes = all_ids_by_idtype IdMutex
let all_queues = all_ids_by_idtype IdQueue

(* YYY cache this per project *)
let array_threads = MtCil.mthread_global_var "__FRAMAC_MTHREAD_THREADS"
let array_mutexes = MtCil.mthread_global_var "__FRAMAC_MTHREAD_MUTEXES"
let array_queues = MtCil.mthread_global_var "__FRAMAC_MTHREAD_QUEUES"

let array_of_idt = function
  | IdThread -> array_threads ()
  | IdMutex -> array_mutexes ()
  | IdQueue -> array_queues ()

let array_size v =
  let fail fmt =
    Format.fprintf fmt
      "Incorrect@ declaration@ for %s,@ unrecognized@ array.@ Is %a@ standard?"
      v.vname Filepath.Normalized.pretty (MtLib.mthread_h ())
  in
  match Ast_types.unroll_node v.vtype with
  | TArray (_, size) ->
    (try Cil.lenOfArray size
     with Cil.LenOfArray _ -> raise (FailMsg fail))
  | _ -> raise (FailMsg fail)


let next_id_ok idt next =
  let array = array_of_idt idt in
  let len = array_size array in
  if next > len then
    raise (FailMsg (fun fmt ->
        Format.fprintf fmt
          "Too many@ %a ids, unable@ to@ register@ another one.@ Try to@ \
           increase@ MTHREAD_NUMBER_IDS@ above %d in@ the@ preprocessing@ \
           directive." IdType.pretty_lc idt len
      ))


let register_new_id_aux known idt name stack thread iteration =
  let ki = Eva.Callstack.top_callsite stack in
  (* Auxiliary function that allocate a new id *)
  let fresh fname =
    let next, known = match idt with
      | IdThread ->
        let n = known.next_thread_id in
        next_id_ok idt n;
        n, { known with next_thread_id = n + 1 }
      | IdMutex ->
        let n = known.next_mutex_id in
        next_id_ok idt n;
        n, { known with next_mutex_id = n + 1 }
      | IdQueue ->
        let n = known.next_queue_id in
        next_id_ok idt n;
        n, { known with next_queue_id = n + 1 }
    in
    let id = (idt, next) in
    let infos = {
      id_raw = id;
      id_name = fname next;
      id_name_hint = name;
      id_creator = thread;
      id_updated = iteration;
    } in
    let infos_map = RawId.Map.add id infos known.ids_infos in
    let known = { known with ids_infos = infos_map } in
    MtOptions.debug ~level:3 ?source:(MtCil.kinstr_to_source ki)
      "ID New %a, name %s, offset %d" IdType.pretty_lc idt infos.id_name next;
    infos, known
  and existing infos =
    MtOptions.debug ~level:3 ?source:(MtCil.kinstr_to_source ki)
      "ID Known id %s" infos.id_name;
    (infos, known)
  in
  (* We check that the id does not already exists *)
  match name with
  | NoHint ->
    (try
       (* No name, only one id per stack can be registered *)
       let id_p = MapCreation.find (thread.id_raw, stack)
           known.ids_by_stacks in
       let infos = RawId.Map.find id_p known.ids_infos in
       if not (Id.equal thread infos.id_creator) then
         `Failure (fun fmt -> Format.fprintf fmt
                      "%a %s@ created@ by@ both@ threads@ %s and %s."
                      IdType.pretty idt infos.id_name
                      infos.id_creator.id_name thread.id_name)
       else if infos.id_updated = iteration then
         `Failure (fun fmt -> Format.fprintf fmt
                      "%a %s@ initialized@ more@ than@ once@ by@ \
                       thread %s@ at@ same@ statement."
                      IdType.pretty idt infos.id_name thread.id_name)
       else
         `Success (existing infos)
     with Not_found ->
       let id, known =
         fresh (fun offset ->
             Format.asprintf "%a" RawId.pretty (idt, offset)) in
       let stacks_map =
         MapCreation.add (thread.id_raw, stack) id.id_raw
           known.ids_by_stacks in
       let known = { known with ids_by_stacks = stacks_map } in
       `Success (id, known)
    )
  | Hint_pointer _ | Hint_string _ ->
    (try
       let id_p = IdNameHint.Map.find name known.ids_by_names in
       let infos = RawId.Map.find id_p known.ids_infos in
       if not (Id.equal thread infos.id_creator) then
         `WithWarning (
           (fun fmt -> Format.fprintf fmt
               "%a %s@ created@ by@ both@ threads@ %s and %s."
               IdType.pretty idt infos.id_name
               infos.id_creator.id_name thread.id_name
           ),
           existing infos)
       else (* No check by stack, we suppose the code knows what it does.
               In erroneous cases, there will be a warning printed
               by the hooks anyway *)
         `Success (existing infos)
     with Not_found ->
       let id, known =
         fresh (fun _ -> Pretty_utils.to_string IdNameHint.pretty name) in
       let name_map = IdNameHint.Map.add name id.id_raw
           known.ids_by_names in
       let known = { known with ids_by_names = name_map } in
       `Success (id, known)
    )

let register_new_id known idt name stack thread iteration =
  try register_new_id_aux known idt name stack thread iteration
  with FailMsg msg -> `Failure msg

let give_name_to_id known id name =
  if name = NoHint then
    `Failure (fun fmt -> Format.fprintf fmt "Empty name hint")
  else
    let idt = Id.id_type id in
    try
      let id' = IdNameHint.Map.find name known.ids_by_names in
      if RawId.equal id.id_raw id' then
        `Success (None, known)
      else
        `Failure (fun fmt -> Format.fprintf fmt
                     "%a name %a@ already@ registered@ for@ other@ object %a."
                     IdType.pretty idt IdNameHint.pretty name RawId.pretty id')
    with Not_found ->
      id.id_name_hint <- name;
      let sname = Pretty_utils.to_string IdNameHint.pretty name in
      id.id_name <- sname;
      let name_map = IdNameHint.Map.add name id.id_raw known.ids_by_names in
      let known = { known with ids_by_names = name_map } in
      `Success (Some sname, known)


let pointer_of_id ((idt, offset): raw_id) : pointer =
  assert (offset > 0);
  let array = array_of_idt idt
  and offset = (offset - 1) * (Machine.sizeof_int ())
  (* Let us not lose the first cell of the array *)
  in
  array, offset

exception NoNiceName

(* Try to find a textual representation of the offset starting at [offset] bits
   in the type [typ]. The result is appended to [prefix] *)
let rec nice_offset typ offset prefix =
  match Ast_types.unroll_node typ with
  | TArray (typ, _) ->
    (* Array case; we continue in the relevant cell *)
    let size = Cil.bitsSizeOf typ in
    let new_prefix = Format.sprintf "%s[%d]" prefix (offset / size) in
    nice_offset typ (offset mod size) new_prefix

  | TComp ({cstruct = true} as ci) ->
    (* Struct (but not union); we search the relevant field *)
    let rec find_field = function
      | [] -> raise NoNiceName
      | fi :: q ->
        let off_fi, len_fi = Cil.bitsOffset typ (Field (fi, NoOffset)) in
        if offset >= off_fi + len_fi then
          find_field q
        else
          let new_prefix = Format.sprintf "%s.%s" prefix fi.fname in
          nice_offset fi.ftype (offset - off_fi) new_prefix
    in
    find_field (Option.value ~default:[] ci.cfields)

  | _ ->
    if offset = 0 then prefix
    else raise NoNiceName

let extract_name_hint value =
  try
    match Locations.Location_Bytes.fold_i (fun b i l -> (b,i) :: l) value [] with
    | [(Base.Var (v, _) | Base.Allocated (v, _, _)), i] ->
      (try
         let i = Abstract_interp.Int.to_int_exn (Ival.project_int i) in
         if not (MtOptions.NiceOffsets.get ())
         then `Success (Hint_pointer (v, i))
         else
           try
             let prefix = "&" ^ v.vname in
             `Success (Hint_string (nice_offset v.vtype (i*8) prefix))
           with _ ->
             MtOptions.warning "Unable to@ give@ a good name@ to@ \
                                object %a.@ You@ should@ deactivate@ option %s"
               Pointer.pretty (v, i) MtOptions.NiceOffsets.option_name;
             MtOptions.NiceOffsets.set false;
             `Success (Hint_pointer (v, i))
       with Ival.Not_Singleton_Int ->
         `Failure (fun fmt -> Format.fprintf fmt
                      "When@ decoding@ id,@ incorrect@ offset %a@ in '%a'.@ \
                       Try to@ increase@ slevel."
                      Ival.pretty i Cvalue.V.pretty value)
      )

    | [Base.String (_, e), i] when Ival.is_zero i ->
      conv_map (fun s -> Hint_string s) (MtMemory.extract_non_wide_string e)

    | [Base.Null, i] when Ival.is_zero i -> `Success NoHint

    | _ ->
      `Failure (fun fmt -> Format.fprintf fmt
                   "When decoding id, incorrect value '%a'@ \
                    (should be@ variable+offset@ or constant@ string)"
                   Cvalue.V.pretty value)
  with e ->
    `Failure (fun fmt -> Format.fprintf fmt "Not a correct id '%a'@. \
                                             Conversion raised %s"
                 Cvalue.V.pretty value (Printexc.to_string e))



let read_id_state state id =
  let p = pointer_of_id id.id_raw in
  MtMemory.read_int_pointer p state

let read_id_state_enumerate card state id : _ MtLib.conversion =
  let value = read_id_state state id in
  let failure fmt = Format.fprintf fmt "Id %a contains garbled state %a"
      Id.pretty id Cvalue.V.pretty value
  in
  try
    match Locations.Location_Bytes.fold_i (fun b i l -> (b,i) :: l) value []
    with
    | [Base.Null,i]  -> begin
        try
          ignore (Ival.cardinal_less_than i card);
          `Success (Ival.fold_int (fun i l -> Abstract_interp.Int.to_int_exn i :: l) i [])
        with Abstract_interp.Not_less_than -> `Failure failure
      end

    | _ -> `Failure failure
  with Not_found -> `Failure failure


let write_id_state state id v =
  let p = pointer_of_id id.id_raw in
  MtMemory.write_int_pointer p v state

let replace_id_value state id ~before ~after =
  let p = pointer_of_id id.id_raw in
  MtMemory.replace_value_at_int_pointer p ~before ~after state

let id_offset id = snd id.id_raw
