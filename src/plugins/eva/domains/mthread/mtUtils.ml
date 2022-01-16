type pointer = Cil_types.varinfo * int

let (<?>) c other = if c = 0 then Lazy.force other else c



module Result = struct
  type log = string list
  type 'a t = Ok of 'a | Warning of 'a * log | Error of log

  let ok v = Ok v
  let warning v fmt = Format.kasprintf (fun msg -> Warning (v, [msg])) fmt
  let error fmt = Format.kasprintf (fun msg -> Error [msg]) fmt

  let map f = function
    | Ok v -> Ok (f v)
    | Warning (v, log) -> Warning (f v, log)
    | Error log -> Error log

  let bind result f =
    match result with
    | Ok v -> f v
    | Error log -> Error log
    | Warning (v, log) ->
      match f v with
      | Ok r -> Warning (r, log)
      | Warning (r, log') -> Warning (r, log @ log')
      | Error log' -> Error (log @ log')

  let join = function
    | Ok r -> r
    | Warning (Ok r, log) -> Warning (r, log)
    | Warning (Warning (r, log), log') -> Warning (r, log @ log')
    | Warning (Error log, log') -> Error (log @ log')
    | Error log -> Error log

  let compare f x y =
    let compare_log = Stdlib.List.compare String.compare in
    match x, y with
    | Ok x, Ok y -> f x y
    | Ok _, (Warning _ | Error _) -> -1
    | (Warning _ | Error _), Ok _ ->  1
    | Warning (x, lx), Warning (y, ly) -> f x y <?> lazy (compare_log lx ly)
    | Warning _, Error _ -> -1
    | Error _, Warning _ ->  1
    | Error lx, Error ly -> compare_log lx ly

  let equal f x y =
    let equal_log = Stdlib.List.equal String.equal in
    match x, y with
    | Ok x, Ok y -> f x y
    | Ok _, (Warning _ | Error _) | (Warning _ | Error _), Ok _ -> false
    | Warning (x, lx), Warning (y, ly) -> f x y && equal_log lx ly
    | Warning _, Error _ | Error _, Warning _ -> false
    | Error lx, Error ly -> equal_log lx ly

  let ( let* ) = bind
  let ( let+ ) v f = map f v

  let pp_log = Format.(pp_print_list ~pp_sep:pp_print_newline pp_print_string)
  let log ~error = function
    | Ok v -> v
    | Warning (v, log) -> Self.warning "%a" pp_log log ; v
    | Error log -> Self.error "%a" pp_log log ; error
end



type trilean = True | False | Unknown

module Trilean = struct
  include Datatype.Make_with_collections (struct
    type t = trilean
    let name = "Trilean"
    let structural_descr = Structural_descr.t_abstract
    let reprs = [ True ; False ; Unknown ]
    let rehash = Datatype.identity
    let copy = Datatype.identity
    let mem_project = Datatype.never_any_project
    let hash = function True -> 0 | False -> 1 | Unknown -> 2
    let compare x y = compare (hash x) (hash y)
    let equal x y = compare x y = 0
    let pretty fmt = function
      | True    -> Format.fprintf fmt "true"
      | False   -> Format.fprintf fmt "false"
      | Unknown -> Format.fprintf fmt "unknown"
  end)

  let top = Unknown
  let is_unknown = function Unknown -> true | _ -> false
  let is_included x y = is_unknown y || equal x y
  let join x y = if equal x y then x else Unknown
  let narrow = join

  let maybe_true  = function False -> false | _ -> true
  let maybe_false = function True  -> false | _ -> true

  let of_bool = function true -> True | false -> False

  let ( && ) l r =
    match l, r with
    | True, True -> True
    | True, False | False, True | False, False -> False
    | True, Unknown | Unknown, True-> Unknown
    | False, Unknown | Unknown, False -> False
    | Unknown, Unknown -> Unknown

  let ( || ) l r =
    match l, r with
    | False, False -> False
    | True, False | False, True | True, True -> True
    | True, Unknown | Unknown, True-> True
    | False, Unknown | Unknown, False -> Unknown
    | Unknown, Unknown -> Unknown

  let not = function
    | True -> False
    | False -> True
    | Unknown -> Unknown
end



module Name = struct
  type name = Pointer of pointer | String of string | Null

  include Datatype.Make_with_collections (struct
    include Datatype.Serializable_undefined
    type t = name
    let name = "Mthread_Name"
    let reprs = [ Null ]
    let compare x y =
      match x, y with
      | Null, Null -> 0
      | Null, _ -> 1
      | _, Null -> -1
      | String x, String y -> String.compare x y
      | String _, Pointer _ -> 1
      | Pointer _, String _ -> -1
      | Pointer (vx, ox), Pointer (vy, oy) ->
        let (<?>) c other = if c = 0 then Lazy.force other else c in
        Cil_datatype.Varinfo.compare vx vy <?> lazy (compare ox oy)
    let equal = Datatype.from_compare
    let pretty fmt = function
      | Null -> Format.fprintf fmt "NULL"
      | String s -> Format.pp_print_string fmt s
      | Pointer (v, o) ->
        Format.fprintf fmt "&%a + %i" Cil_datatype.Varinfo.pretty v o
    let hash = Hashtbl.hash
  end)

  let of_string s = String s

  let extract_bases_and_ival value =
    let fold = Locations.Location_Bytes.fold_i in
    try Result.ok (fold (fun b i l -> (b, i) :: l) value [])
    with exc ->
      Result.error "Not a correct id '%a'@.Conversion raised %s"
        Cvalue.V.pretty value (Printexc.to_string exc)

  let extract_int ival value =
    try Result.ok (Ival.project_int ival |> Abstract_interp.Int.to_int_exn)
    with Ival.Not_Singleton_Int | Z.Overflow ->
      Result.error "When@ decoding@ id,@ incorrect@ offset %a@ in '%a'."
        Ival.pretty ival Cvalue.V.pretty value

  (* Try to find a textual representation of the offset starting at [offset]
     bits in the type [typ]. The result is appended to [prefix] *)
  let rec nice_offset ~default typ offset prefix =
    match Ast_types.unroll_node typ with
    (* Array case; we continue in the relevant cell *)
    | TArray (typ, _) ->
      let size = Cil.bitsSizeOf typ in
      let new_prefix = Format.sprintf "%s[%d]" prefix (offset / size) in
      nice_offset ~default typ (offset mod size) new_prefix
    (* Struct (but not union); we search the relevant field *)
    | TComp ({cstruct = true} as ci) ->
      let rec find_field = function
        | [] -> default
        | fi :: q ->
          let off_fi, len_fi = Cil.bitsOffset typ (Field (fi, NoOffset)) in
          let new_prefix = Format.sprintf "%s.%s" prefix fi.fname in
          if offset >= off_fi + len_fi then find_field q
          else nice_offset ~default fi.ftype (offset - off_fi) new_prefix
      in find_field (Option.value ~default:[] ci.cfields)
    (* In any other case, either the offset is zero and we are done or we cannot
       produce a nice offset *)
    | _ -> if offset = 0 then String prefix else default

  let extract_of_cvalue cvalue =
    let open Result in
    let* bases = extract_bases_and_ival cvalue in
    match bases with
    | [ Base.Null, i ] when Ival.is_zero i -> ok Null
    | [ (Base.Var (v, _) | Base.Allocated (v, _, _)), i ] ->
      let* i = extract_int i cvalue in
      let default = Pointer (v, i) in
      ok (nice_offset ~default v.vtype (i * 8) ("&" ^ v.vname))
    | [ Base.String (_, Base.CSString s), i ] when Ival.is_zero i ->
      ok (String s)
    | [ Base.String (_, Base.CSWstring s), i ] when Ival.is_zero i ->
      ok (String (Escape.escape_wstring s))
    | _ ->
      error
        "When decoding id, incorrect value '%a'@ \
         (should be@ variable+offset@ or constant@ string)"
        Cvalue.V.pretty cvalue
end



module Value = struct
  include Cvalue.V

  let zero = inject_int Z.zero

  let of_int n = Z.of_int n |> inject_int

  let extract_singleton cvalue =
    try Some (Cvalue.V.project_ival cvalue |> Ival.project_int |> Z.to_int)
    with Cvalue.V.Not_based_on_null | Ival.Not_Singleton_Int | Z.Overflow ->
      None

  let error_not_a_pointer_to_function value =
    Result.error "Expected@ pointer@ to function,@ received %a."
      Cvalue.V.pretty value

  let find_lonely_key_result value =
    try Result.ok (Locations.Location_Bytes.find_lonely_key value |> fst)
    with Not_found -> error_not_a_pointer_to_function value

  let get_function value var =
    try Result.ok (Globals.Functions.get var)
    with Not_found -> error_not_a_pointer_to_function value

  let extract_fun cvalue =
    let open Result in
    let* b = find_lonely_key_result cvalue in
    match b with
    | Base.Var (v, _) ->
      let* f = get_function cvalue v in
      begin match f.fundec with
        | Definition (_, _) -> ok f
        | Declaration (_, f, _, _) ->
          error "Missing@ definition@ for function@ '%s'." f.vname
      end
    | _ -> error_not_a_pointer_to_function cvalue
end



type errors =
  | AlreadyRegistered
  | NotRegistered
  | MayBeInState of (string * bool)

type update_check = Ok | Invalid of (string * bool)

module type Key_sig = sig
  include Hptmap.Id_Datatype
  val key_name : string
  val key_id : t -> Value.t
  val pretty_msg : Format.formatter -> t -> unit
end

module type Status_sig = sig
  include Lattice_type.Join_Semi_Lattice
  val default : t
end

module Register (Key : Key_sig) (Status : Status_sig) = struct
  module Info = struct
    let initial_values = [ ]
    let dependencies = [ Ast.self ]
  end
  include Hptmap.Make (Key) (Status) (Info)
  let cache_name s = Hptmap_sig.PersistentCache (name ^ "." ^ s)
  let find key map = try Some (find key map) with Not_found -> None

  type status = Status.t
  type key = Key.t

  let warning key register = function
    | AlreadyRegistered ->
      Result.warning (register, Key.key_id key)
        "The %s %a is already registered."
        Key.key_name Key.pretty_msg key
    | NotRegistered ->
      Result.warning (register, Value.of_int 1)
        "The %s %a is not registered."
        Key.key_name Key.pretty_msg key
    | MayBeInState (state, sure) ->
      Result.warning (register, Value.of_int 2)
        "The %s %a %s already %s."
        Key.key_name Key.pretty_msg key
        (if sure then "is" else "may be") state

  let register key register =
    if not (mem key register)
    then Result.ok (add key Status.default register, Key.key_id key)
    else warning key register AlreadyRegistered

  let update new_status check key register =
    match find key register with
    | None -> warning key register NotRegistered
    | Some status ->
      let register = add key (new_status status) register in
      match check status with
      | Ok -> Result.ok (register, Value.zero)
      | Invalid reason -> warning key register (MayBeInState reason)

  (* If a key is not in the register, we consider that is may be unregistered
     from the point of view of the partial order. It means that the empty map is
     the top element. *)
  let top = empty

  let is_included =
    let cache = cache_name "is_included" in
    let decide_fst _b _l = true  (* r is top *) in
    let decide_snd _b _r = false (* l is top *) in
    let decide_both _ l r = Status.is_included l r in
    let decide_fast s t = if s == t then PTrue else PUnknown in
    binary_predicate cache UniversalPredicate
      ~decide_fast ~decide_fst ~decide_snd ~decide_both

  (* Over-approximation of the narrow of two registers. Keys registered on
     each sides are all kept. However, we are conservative on their status. *)
  let narrow =
    let cache = cache_name "narrow" in
    let decide _ x y = Status.join x y in
    fun x y -> join ~cache ~symmetric:true ~idempotent:true ~decide x y

  (* Join of two registers. It only keeps keys registered on both sides and
     their statuses are joined. *)
  let join =
    let cache = cache_name "join" in
    let decide _ x y = Some (Status.join x y) in
    fun x y -> inter ~cache ~symmetric:true ~idempotent:true ~decide x y
end
