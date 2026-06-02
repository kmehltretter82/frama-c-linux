(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

(* -------------------------------------------------------------------------- *)
(* --- Logical Language                                                   --- *)
(* -------------------------------------------------------------------------- *)

open Cil_types
open Cil_datatype
open Ctypes
open Qed
open Qed.Logic

let dkey_pretty = Wp_parameters.register_category "pretty"

(* -------------------------------------------------------------------------- *)

let basename def name =
  let rec lookup def s k n =
    if k < n then
      let c = s.[k] in
      if ('a' <= c && c <= 'z') || ('A' <= c && c <= 'Z')
      then String.sub s k 1
      else lookup def s (succ k) n
    else def
  in lookup def name 0 (String.length name)

(* -------------------------------------------------------------------------- *)
(* Naming Prefixes
   Names starting with a lower-case character belong to logic language
   or external model(s).

   'pointer' Pointer type
   'Lit_<hex>' String Literal Values
   'Str_<eid>' String Literal Pointers
   'S_<s>' Structure <s>
   'U_<u>' Union <u>
   'F_<c>_<f>' Field <f> in compound <c>
   'A_<t>' ACSL Logic type <t>
   'C_<c>' ACSL Constructor <c>
   'P_<p>' ACSL Predicate <p> (see LogicUsage.get_name)
   'L_<f>' ACSL Logic function <f> (see LogicUsage.get_name)
   'FixP_<p>' ACSL Recursive Predicate <p> (see LogicUsage.get_name)
   'FixL_<f>' ACSL Recursive Logic function <f> (see LogicUsage.get_name)
   'Q_<l>' ACSL Lemma or Axiom
   'S_<n>' Set comprehension predicate
   'Is<phi>' Typing predicate for type <phi>
   'Null<phi>' Null value for type <phi>
*)
let avoid_leading_backlash s =
  if s.[0]='\\' then
    let s = Bytes.of_string s in
    Bytes.set s 0 '_'; Bytes.to_string s
  else s

let comp_id c =
  let prefix = if c.cstruct then 'S' else 'U' in
  if c.corig_name = "" then
    Printf.sprintf "%c%d" prefix c.ckey
  else
    Printf.sprintf "%c%d_%s" prefix c.ckey c.corig_name

let field_id f =
  let c = f.fcomp in
  if c.corig_name = "" then
    Printf.sprintf "F%d_%s" c.ckey f.fname
  else
    Printf.sprintf "F%d_%s_%s" c.ckey c.corig_name f.fname

let init_id (f: 'a -> string) (x: 'a) = "Init_" ^ (f x)
let comp_init_id = init_id comp_id
let field_init_id = init_id field_id

let type_id l =
  Printf.sprintf "A_%s" l.lt_name

let logic_id f =
  let name = avoid_leading_backlash (LogicUsage.get_name f) in
  if f.l_type = None
  then Printf.sprintf "P_%s" name
  else Printf.sprintf "L_%s" name

let ctor_id c = Printf.sprintf "C_%s" (avoid_leading_backlash c.ctor_name)
let lemma_id l = Printf.sprintf "Q_%s" (avoid_leading_backlash l)

(* -------------------------------------------------------------------------- *)

type datakind = KValue | KInit

type adt =
  | Qdata of Qed.Symbol.data (* Why3/Qed Type *)
  | Atype of logic_type_info (* ACSL Logic Type *)
  | Comp of compinfo * datakind (* C-code struct or union *)

(** name to print to the provers *)
and fields = { mutable fields : field list }
and field = Cfield of fieldinfo * datakind
and tau = (field,adt) Logic.datatype

let pointer = Context.create "Lang.pointer"
let floats = Context.create "Lang.floats"
let new_extern_id = ref (-1)

(* -------------------------------------------------------------------------- *)
(* --- Sorting & Typing                                                   --- *)
(* -------------------------------------------------------------------------- *)

let sort_of_object = function
  | C_int _ -> Logic.Sint
  | C_pointer _ | C_comp _ | C_array _ -> Logic.Sdata
  | C_float f -> Qed.Kind.of_tau (Context.get floats f)

let init_sort_of_object = function
  | C_int _ | C_float _ | C_pointer _ -> Logic.Sbool
  | C_comp _ | C_array _ -> Logic.Sdata

let sort_of_ctype t = sort_of_object (Ctypes.object_of t)

let sort_of_ltype t = match Ast_types.Acsl.unroll ~unroll_typedef:false t with
  | Ctype typ -> sort_of_ctype typ
  | Ltype _ | Lvar _ | Larrow _ -> Logic.Sdata
  | Lboolean -> Logic.Sbool
  | Linteger -> Logic.Sint
  | Lreal -> Logic.Sreal

let t_int = Logic.Int
let t_bool = Logic.Bool
let t_real = Logic.Real
let t_prop = Logic.Prop
let t_addr () = Context.get pointer
let t_float f = Context.get floats f
let t_comp c = Logic.Data(Comp (c, KValue),[])
let t_init c = Logic.Data(Comp (c, KInit), [])
let t_array a = Logic.Array(Logic.Int,a)
let t_farray a b = Logic.Array(a,b)
let t_data adt ts = Logic.Data(adt,ts)
let rec t_matrix a n = if n > 0 then t_matrix (t_array a) (pred n) else a

let rec tau_of_object = function
  | C_int _ -> Logic.Int
  | C_float f -> t_float f
  | C_pointer _ -> Context.get pointer
  | C_comp c -> t_comp c
  | C_array { arr_element = typ } -> t_array (tau_of_ctype typ)

and tau_of_ctype typ = tau_of_object (Ctypes.object_of typ)

let poly = Context.create "Wp.Lang.poly"

let rec init_of_object = function
  | C_int _ | C_float _ | C_pointer _ -> Logic.Bool
  | C_comp c -> t_init c
  | C_array { arr_element = typ } -> t_array (init_of_ctype typ)

and init_of_ctype typ = init_of_object (Ctypes.object_of typ)

let rec varpoly k x = function
  | [] -> Warning.error "Unbound type parameter <%s>" x
  | y::ys -> if x = y then k else varpoly (succ k) x ys

let hacked_types = Context.create "Wp.Lang.hacked_types"
let atype lt (ts : tau list) : tau =
  try Context.get hacked_types lt.lt_name ts
  with Not_found -> Qed.Logic.Data(Atype lt,ts)

let rec tau_of_ltype t =
  match Ast_types.Acsl.unroll ~unroll_typedef:false t with
  | Lboolean -> Logic.Bool
  | Linteger -> Logic.Int
  | Lreal -> Logic.Real
  | Ctype typ -> tau_of_ctype typ
  | Lvar x -> Logic.Tvar (varpoly 1 x (Context.get poly))
  | Ltype(lt,lts) -> atype lt (List.map tau_of_ltype lts)
  | Larrow(ts,tr) ->
    List.fold_left
      (fun r k -> Logic.Array(tau_of_ltype k,r))
      (tau_of_ltype tr) ts

let tau_of_return = function None -> Logic.Prop | Some t -> tau_of_ltype t

(* -------------------------------------------------------------------------- *)
(* --- Datatypes                                                          --- *)
(* -------------------------------------------------------------------------- *)

type 'a extern = {
  mutable value : 'a option ;
  mutable env : Why3.Env.env option ;
  compute : Why3.Env.env -> 'a ;
}

let extern = function
  | { value = Some v ; env = Some e } when e == Why3Provers.env () -> v
  | r ->
    let env = Why3Provers.env () in
    let value = r.compute env in
    r.env <- Some env ; r.value <- Some value ; value

module E =
struct
  let (!@) = extern
  let (@=) a b = !@a == b
end

let mk_extern compute = { value = None ; env = None ; compute }

let import_t ~context ts = Qdata (Qed.Symbol.of_ts context ts)
let extern_c name env = Qdata (Qed.Symbol.find_data env name)
let extern_t name = mk_extern (extern_c name)

module ADT =
struct

  type t = adt

  let basename = function
    | Qdata a -> basename "M" @@ Qed.Symbol.Data.name a
    | Comp (c,KValue) -> basename (if c.cstruct then "S" else "U") c.corig_name
    | Comp (c,KInit) -> basename (if c.cstruct then "IS" else "IU") c.corig_name
    | Atype lt -> basename "A" lt.lt_name

  let debug = function
    | Qdata a -> Qed.Symbol.Data.fullname a
    | Comp (c, KValue) -> comp_id c
    | Comp (c, KInit) -> comp_init_id c
    | Atype lt -> type_id lt

  let hash = function
    | Qdata a -> Qed.Symbol.Data.hash a
    | Comp (c, KValue) -> Compinfo.hash c
    | Comp (c, KInit) -> 13 * Compinfo.hash c
    | Atype lt -> Logic_type_info.hash lt

  let compare a b =
    if a==b then 0 else
      match a,b with
      | Qdata a , Qdata b -> Qed.Symbol.Data.compare a b
      | Qdata _ , _ -> (-1)
      | _ , Qdata _ -> (+1)
      | Comp (a, KValue) , Comp (b, KValue)
      | Comp (a, KInit)  , Comp (b, KInit) -> Compinfo.compare a b
      | Comp (_, KValue) , Comp (_, KInit) -> (-1)
      | Comp (_, KInit)  , Comp (_, KValue) -> (+1)
      | Comp _ , _ -> (-1)
      | _ , Comp _ -> (+1)
      | Atype a , Atype b -> Logic_type_info.compare a b

  let equal a b = (compare a b = 0)

  let pretty fmt a = Format.pp_print_string fmt (debug a)

end

(* -------------------------------------------------------------------------- *)
(* --- Datatypes                                                          --- *)
(* -------------------------------------------------------------------------- *)

let field_observers = ref []
let field_observe fd = List.iter (fun k -> k fd) !field_observers ; fd
let on_field f = field_observers := f :: !field_observers

let cfield ?(kind=KValue) fd = field_observe @@ Cfield(fd,kind)
let comp c = Comp (c, KValue)
let comp_init c = Comp (c, KInit)

let fields_of_adt = function
  | Comp (c, k) ->
    List.map (fun f -> Cfield (f, k)) (Option.value ~default:[] c.cfields)
  | _ -> []

let fields_of_tau = function
  | Record fts -> List.map fst fts
  | Data(adt,_) -> fields_of_adt adt
  | _ -> []

let fields_of_field = function
  | Cfield(f, k) ->
    List.map (fun f -> Cfield (f, k)) (Option.value ~default:[] f.fcomp.cfields)

let tau_of_field = function
  | Cfield(f, KValue) -> tau_of_ctype f.ftype
  | Cfield(f, KInit) -> init_of_ctype f.ftype

let tau_of_record = function
  | Cfield(f, KValue) -> t_comp f.fcomp
  | Cfield(f, KInit) -> t_init f.fcomp

module Field =
struct

  type t = field

  let debug = function
    | Cfield(f, KValue) -> field_id f
    | Cfield(f, KInit) -> field_init_id f

  let hash = function
    | Cfield(f, KValue) -> Fieldinfo.hash f
    | Cfield(f, KInit) -> 13 * Fieldinfo.hash f

  let compare f g =
    if f==g then 0 else
      match f , g with
      | Cfield(f, KValue) , Cfield(g, KValue)
      | Cfield(f, KInit) , Cfield(g, KInit) ->
        Fieldinfo.compare f g
      | Cfield(_, KInit), Cfield(_, KValue) -> (-1)
      | Cfield(_, KValue), Cfield(_, KInit) -> (+1)

  let equal f g = (compare f g = 0)

  let pretty fmt f = Format.pp_print_string fmt (debug f)

  let sort = function
    | Cfield(f, KValue) -> sort_of_object (Ctypes.object_of f.ftype)
    | Cfield(f, KInit) -> init_sort_of_object (Ctypes.object_of f.ftype)

end

(* -------------------------------------------------------------------------- *)
(* --- Functions & Predicates                                             --- *)
(* -------------------------------------------------------------------------- *)

type lfun =
  | ACSL of Cil_types.logic_info
  (* Registered in Definition.t, only  *)
  | CTOR of Cil_types.logic_ctor_info
  (* Not registered in Definition.t, directly converted/printed *)
  | LFUN of lsymbol
  (* Generated function *)
  | QFUN of esymbol
  (* External function *)

and lsymbol = {
  m_id : int ;
  m_name : string ;
  m_context : WpContext.context option ;
  m_category : lfun category ;
  m_params : sort list ;
  m_result : sort ;
  m_typeof : tau option list -> tau ;
  m_coloring : bool ;
}

and esymbol = {
  e_category : lfun category ;
  e_coloring : bool ;
  e_symbol : Qed.Symbol.lfun ;
}

let lfun_observers = ref []
let lfun_observe lf = List.iter (fun k -> k lf) !lfun_observers ; lf
let on_lfun f = lfun_observers := f :: !lfun_observers

let acsl lf = lfun_observe (ACSL lf)
let ctor cf = lfun_observe (CTOR cf)
let lsymbol m = lfun_observe (LFUN m)

let of_qtau : Qed.Symbol.tau -> tau =
  Kind.map_tau (fun _ -> raise Not_found) (fun d -> Qdata d)

let compare_tau = Qed.Kind.compare_tau Field.compare ADT.compare

let typecheck category (tr: tau) (ps : tau list) (ts : tau list) =
  let s = ref Qed.Intmap.empty in
  let rec unify_all ps ts =
    match ps,ts with
    | [],[] -> ()
    | p::ps,t::ts -> unify p t ; unify_all ps ts
    | _ -> raise Not_found
  and unify p t =
    match p , t with
    | _ , Tvar (-1) -> ()
    | Tvar k , _ -> merge k t
    | Int , Int -> ()
    | Real, Real -> ()
    | Bool, Bool -> ()
    | Prop, Prop -> ()
    | Array(a,b), Array(a',b') -> unify a a' ; unify b b'
    | Data(d,ps) , Data(d',ts) when ADT.equal d d' -> unify_all ps ts
    | _ -> raise Not_found
  and merge k t =
    match Qed.Intmap.find k !s with
    | exception Not_found -> s := Qed.Intmap.add k t !s
    | t0 -> if not (compare_tau t0 t = 0) then raise Not_found
  in
  begin
    match category with
    | Operator _ -> List.iter (unify tr) ts
    | _ -> unify_all ps ts
  end ;
  let rec resolve = function
    | Int -> Int
    | Real -> Real
    | Bool -> Bool
    | Prop -> Prop
    | Tvar x -> (try Qed.Intmap.find x !s with Not_found -> Tvar (-1))
    | Array(a,b) -> Array(resolve a, resolve b)
    | Record fts -> Record (List.map (fun (f,t) -> f,resolve t) fts)
    | Data(d,ts) -> Data(d,List.map resolve ts)
  in resolve tr

let tau_of_lfun phi ts =
  match phi with
  | ACSL f -> tau_of_return f.l_type
  | CTOR c ->
    if c.ctor_type.lt_params = []
    then Logic.Data(Atype c.ctor_type,[])
    else raise Not_found
  | LFUN m ->
    begin
      match m.m_result with
      | Sint -> Int
      | Sreal -> Real
      | Sbool -> Bool
      | _ -> m.m_typeof ts
    end
  | QFUN f ->
    try
      let _,r,ps = Qed.Symbol.signature f.e_symbol in
      typecheck f.e_category
        (of_qtau r)
        (List.map of_qtau ps)
        (List.map (Option.get ~exn:Not_found) ts)
    with _ -> raise Not_found

let is_coloring_lfun = function
  | ACSL _ | CTOR _ -> false
  | LFUN { m_coloring } -> m_coloring
  | QFUN { e_coloring } -> e_coloring

let generated_f
    ?(context=false)
    ?(category=Logic.Function)
    ?(params=[])
    ?(sort=Logic.Sdata)
    ?(result:tau option)
    ?(coloring=false)
    ?(typecheck:(tau option list -> tau) option)
    descr =
  Format.kasprintf
    begin fun name ->
      let id = incr new_extern_id ; !new_extern_id in
      let context = if context
        then Some (WpContext.get_context ())
        else None in
      let typeof =
        match typecheck with Some phi -> phi | None ->
        match result with Some t -> fun _ -> t | None -> raise Not_found in
      let result =
        match result with Some t -> Kind.of_tau t | None -> sort in
      lsymbol {
        m_id = id ;
        m_name = name ;
        m_category = category ;
        m_params = params ;
        m_result = result ;
        m_typeof = typeof ;
        m_context = context ;
        m_coloring = coloring ;
      }
    end descr

let generated_p = generated_f ~sort:Sprop ~result:Prop ~typecheck:(fun _ -> Prop)

let extern_l ?(category=Function) ?(coloring=false) name env =
  QFUN {
    e_symbol = Qed.Symbol.find_lfun env name ;
    e_coloring = coloring ;
    e_category = Qed.Kind.map_category extern category ;
  }

let extern_f ?category ?coloring name = mk_extern (extern_l ?category ?coloring name)

let import_f ~context ls = QFUN {
    e_symbol = Qed.Symbol.of_ls context ls ;
    e_category = Function ;
    e_coloring = false ;
  }

module Fun =
struct

  type t = lfun

  let debug = function
    | ACSL f -> logic_id f
    | CTOR c -> ctor_id c
    | LFUN l -> l.m_name
    | QFUN f -> Qed.Symbol.Fun.fullname f.e_symbol

  let hash = function
    | ACSL f -> Logic_info.hash f
    | CTOR c -> Logic_ctor_info.hash c
    | LFUN l -> 7 * l.m_id
    | QFUN f -> 13 * Qed.Symbol.Fun.hash f.e_symbol

  let compare f g =
    if f==g then 0 else
      match f , g with
      | LFUN f , LFUN g -> Int.compare f.m_id g.m_id
      | LFUN _ , _ -> (-1)
      | _ , LFUN _ -> (+1)
      | QFUN f , QFUN g -> Qed.Symbol.Fun.compare f.e_symbol g.e_symbol
      | QFUN _ , _ -> (-1)
      | _ , QFUN _ -> (+1)
      | ACSL f , ACSL g -> Logic_info.compare f g
      | ACSL _ , _ -> (-1)
      | _ , ACSL _ -> (+1)
      | CTOR c , CTOR d -> Logic_ctor_info.compare c d

  let equal f g = (compare f g = 0)

  let pretty fmt f = Format.pp_print_string fmt (debug f)

  let category = function
    | LFUN m -> m.m_category
    | QFUN _ -> Logic.Function
    | ACSL _ -> Logic.Function
    | CTOR _ -> Logic.Constructor

  let rec sort_of_qtau = function
    | Int -> Sint
    | Real -> Sreal
    | Bool -> Sbool
    | Prop -> Sprop
    | Array(_,s) -> Sarray (sort_of_qtau s)
    | _ -> Sdata

  let sort = function
    | LFUN m -> m.m_result
    | ACSL { l_type=None } -> Logic.Sprop
    | ACSL { l_type=Some t } -> sort_of_ltype t
    | CTOR _ -> Logic.Sdata
    | QFUN f ->
      let _, t, _ = Qed.Symbol.signature f.e_symbol in
      sort_of_qtau t

  let parameters = ref (fun _ -> [])

  let params = function
    | LFUN m -> m.m_params
    | QFUN f ->
      let _, _, ts = Qed.Symbol.signature f.e_symbol in
      List.map sort_of_qtau ts
    | CTOR ct -> List.map sort_of_ltype ct.ctor_params
    | (ACSL _) as f -> !parameters f

end

let parameters phi = Fun.parameters := phi
let associative = function
  | Operator op -> op.associative
  | _ -> false

class virtual idprinting =
  object(self)
    method virtual sanitize : string -> string

    method sanitize_type  = self#sanitize
    method sanitize_field = self#sanitize
    method sanitize_fun   = self#sanitize

    method datatype = function
      | Qdata a -> Qed.Symbol.Data.fullname a
      | Comp(c, KValue) -> self#sanitize_type (comp_id c)
      | Comp(c, KInit) -> self#sanitize_type (comp_init_id c)
      | Atype lt -> self#sanitize_type (type_id lt)

    method field = function
      | Cfield(f, KValue) -> self#sanitize_field (field_id f)
      | Cfield(f, KInit) -> self#sanitize_field (field_init_id f)

    method link = function
      | ACSL f -> Engine.F_call (self#sanitize_fun (logic_id f))
      | CTOR c -> Engine.F_call (self#sanitize_fun (ctor_id c))
      | LFUN l ->
        if associative l.m_category then
          Engine.F_assoc (self#sanitize_fun l.m_name)
        else
          Engine.F_call (self#sanitize_fun l.m_name)
      | QFUN l ->
        let ls = Qed.Symbol.Fun.symbol l.e_symbol in
        if ls.ls_proj then
          Engine.F_proj ls.ls_name.id_string
        else if associative l.e_category then
          Engine.F_assoc (Qed.Symbol.Fun.name l.e_symbol)
        else
          Engine.F_call (Qed.Symbol.Fun.name l.e_symbol)

  end

let name_of_lfun = function
  | ACSL f -> logic_id f
  | CTOR c -> ctor_id c
  | LFUN l -> l.m_name
  | QFUN l -> Qed.Symbol.Fun.fullname l.e_symbol

let context_of_lfun = function
  | ACSL _ | CTOR _ | QFUN _ -> None
  | LFUN l -> l.m_context

let name_of_field = function
  | Cfield(f, KValue) -> field_id f
  | Cfield(f, KInit) -> field_init_id f

(* -------------------------------------------------------------------------- *)
(* --- Terms                                                              --- *)
(* -------------------------------------------------------------------------- *)

module F =
struct

  module QZERO = Qed.Term.Make(ADT)(Field)(Fun)

  (* -------------------------------------------------------------------------- *)
  (* --- Qed Projectified State                                             --- *)
  (* -------------------------------------------------------------------------- *)

  module DATA =
    Datatype.Make
      (struct
        type t = QZERO.state
        let name = "Wp.Qed"
        let rehash = Datatype.identity
        let structural_descr = Structural_descr.t_unknown
        let reprs = [QZERO.get_state ()]
        let equal = Datatype.undefined
        let compare = Datatype.undefined
        let hash = Datatype.undefined
        let copy _old = QZERO.create ()
        let pretty = Datatype.undefined
        let mem_project _ _ = false
      end)

  module STATE = State_builder.Register(DATA)
      (struct
        type t = QZERO.state
        let create = QZERO.create
        let clear = QZERO.clr_state
        let get = QZERO.get_state
        let set = QZERO.set_state
        let clear_some_projects _ _ = false
      end)
      (struct
        let name = "Wp.Qed"
        let dependencies = [Ast.self]
        let unique_name = name
      end)
  include (STATE : sig end) (* For OCaml-4.0 *)

  (* -------------------------------------------------------------------------- *)
  (* --- Term API                                                           --- *)
  (* -------------------------------------------------------------------------- *)

  module Pretty = Qed.Pretty.Make(QZERO)
  module QED =
  struct
    include QZERO
    let typeof ?(field=tau_of_field) ?(record=tau_of_record) ?(call=tau_of_lfun) e =
      QZERO.typeof ~field ~record ~call e
  end
  include QED

  (* Hide force parameter. *)
  let set_builtin f = QZERO.set_builtin f
  let set_builtin' f = QZERO.set_builtin' f
  let set_builtin_eq f = QZERO.set_builtin_eq f
  let set_builtin_leq f = QZERO.set_builtin_leq f
  let set_builtin_get f = QZERO.set_builtin_get f
  let set_builtin_field f = QZERO.set_builtin_field f

  (* -------------------------------------------------------------------------- *)
  (* --- Term Extensions                                                    --- *)
  (* -------------------------------------------------------------------------- *)

  type unop = term -> term
  type binop = term -> term -> term

  let e_zero = QED.constant (e_zint Z.zero)
  let e_one  = QED.constant (e_zint Z.one)
  let e_minus_one = QED.constant (e_zint Z.minus_one)
  let e_minus_one_real  = QED.constant (e_real Q.minus_one)
  let e_one_real  = QED.constant (e_real Q.one)
  let e_zero_real = QED.constant (e_real Q.zero)

  let e_int64 z = e_zint (Z.of_string (Int64.to_string z))
  let e_fact k e = e_times (Z.of_int k) e
  let e_bigint z = e_zint (Z.of_string (Z.to_string z))
  let e_range a b = e_sum [b;e_one;e_opp a]

  let e_setfield r f v =
    (*TODO:NUPW: check for UNIONS *)
    let r = List.map
        (fun g -> g,if Field.equal f g then v else e_getfield r g)
        (fields_of_field f)
    in e_record r

  (* -------------------------------------------------------------------------- *)
  (* --- Predicates                                                         --- *)
  (* -------------------------------------------------------------------------- *)

  type pred = term
  type cmp = term -> term -> pred
  type operator = pred -> pred -> pred

  let p_bool t = t
  let e_prop t = t
  let p_bools xs = xs
  let e_props xs = xs
  let e_lift f = f
  let p_lift f = f

  let is_zero e = match QED.repr e with
    | Kint z -> Z.is_zero z
    | _ -> false

  let eqp = equal
  let comparep = compare

  let is_ptrue = is_true
  let is_pfalse = is_false
  let is_equal a b = is_true (e_eq a b)

  let is_int e =
    try typeof e = Qed.Logic.Int with Not_found -> false

  let is_real e =
    try typeof e = Qed.Logic.Real with Not_found -> false

  let is_prop e =
    try match typeof e with Qed.Logic.Prop | Qed.Logic.Bool -> true | _ -> false
    with Not_found -> false

  let is_arith e =
    try match typeof e with Qed.Logic.Int | Qed.Logic.Real -> true | _ -> false
    with Not_found -> false

  let p_equal = e_eq
  let p_equals = List.map (fun (x,y) -> p_equal x y)
  let p_neq = e_neq
  let p_leq = e_leq
  let p_lt = e_lt

  let p_positive e = e_leq e_zero e

  let p_true = e_true
  let p_false = e_false

  let p_not = e_not
  let p_bind = e_bind
  let p_forall = e_forall
  let p_exists = e_exists
  let p_subst = e_subst
  let p_subst_var = e_subst_var

  let p_and p q = e_and [p;q]
  let p_or p q = e_or [p;q]
  let p_imply h p = e_imply [h] p
  let p_hyps hs p = e_imply hs p
  let p_equiv = e_equiv
  let p_if = e_if

  let p_conj = e_and
  let p_disj = e_or

  let p_all f xs = e_and (List.map f xs)
  let p_any f xs = e_or (List.map f xs)

  let e_vars e = List.sort Var.compare (Vars.elements (vars e))
  let p_vars = e_vars
  let p_call = e_fun ~result:Prop
  let p_close = e_close_forall

  let occurs x t = Vars.mem x (vars t)
  let intersect a b = Vars.intersect (vars a) (vars b)
  let occursp = occurs
  let intersectp = intersect
  let varsp = vars
  let p_expr = repr
  let e_expr = repr

  let pp_tau = Pretty.pp_tau
  let context_pp = Context.create "Lang.F.pp"
  let pp_term fmt e =
    if Wp_parameters.has_dkey dkey_pretty
    then QED.debug fmt e
    else
      match Context.get_opt context_pp with
      | Some env -> Pretty.pp_term_env env  fmt e
      | None ->
        let env = Pretty.known Pretty.empty (QED.vars e) in
        Pretty.pp_term env fmt e
  let pp_pred = pp_term
  let pp_var fmt x = pp_term fmt (e_var x)
  let pp_vars fmt xs =
    begin
      Format.fprintf fmt "@[<hov 2>{" ;
      Vars.iter (fun x -> Format.fprintf fmt "@ %a" pp_var x) xs ;
      Format.fprintf fmt " }@]" ;
    end

  let debugp = QED.debug

  type env = Pretty.env
  let env xs = Pretty.known Pretty.empty xs
  let marker = Pretty.marks
  let mark_e = QED.mark
  let mark_p = QED.mark
  let define f env m =
    List.fold_left
      (fun env t ->
         let x,env_x = Pretty.fresh env t in
         f env x t ; env_x)
      env (QED.defs m)

  let pp_eterm = Pretty.pp_term
  let pp_epred = Pretty.pp_term

  module Pmap = Tmap
  module Pset = Tset

  let set_builtin_1 f r =
    set_builtin f (function [e] -> r e | _ -> raise Not_found)

  let set_builtin_2 f r =
    set_builtin f (function [a;b] -> r a b | _ -> raise Not_found)

  let set_builtin_2' f r =
    set_builtin' f (function [a;b] -> r a b | _ -> raise Not_found)

  let set_builtin_eqp = set_builtin_eq

end

open F

let extern_data et ts = E.(t_data !@et ts)
let extern_tau name = mk_extern (fun env -> t_data (extern_c name env) [])
let extern_val name = mk_extern (fun env -> e_fun (extern_l name env) [])
let extern_map f e = mk_extern (fun env -> f @@ e.compute env)
let extern_const c = mk_extern (fun _env -> c)
let extern_lfun ef es = E.(e_fun !@ef es)
let extern_pred ef es = E.(p_call !@ef es)

module N = struct

  let ( + ) = e_add
  let ( ~-: ) x = e_sub e_zero x
  let ( - ) = e_sub
  let ( * ) = e_mul
  let ( / ) = e_div
  let ( mod ) = e_mod

  let ( = ) = p_equal
  let ( < ) = p_lt
  let ( > ) x y = p_lt y x
  let ( <= ) = p_leq
  let ( >= ) x y = p_leq y x
  let ( <> ) = p_neq

  let ( ==> ) = p_imply
  let ( &&: ) = p_and
  let ( ||: ) = p_or
  let not = p_not

  let ( $ ) = e_fun
  let ( $$ ) = p_call

end


(* -------------------------------------------------------------------------- *)
(* --- Local Assumptions                                --- *)
(* -------------------------------------------------------------------------- *)

type gamma = {
  mutable hyps : pred list ;
}

let cpool = Context.create "Lang.pool"
let cgamma = Context.create "Lang.gamma"
let add_vars pool = function
  | None -> ()
  | Some xs -> F.add_vars pool xs

let new_pool ?copy ?(vars = Vars.empty) () =
  let pool = F.pool ?copy () in
  F.add_vars pool vars ; pool
let new_gamma ?copy () =
  match copy with
  | None -> { hyps=[] }
  | Some g -> { hyps = g.hyps }

let get_pool () = Context.get cpool
let get_gamma () = Context.get cgamma
let has_gamma () = Context.defined cgamma

let freshvar ?basename tau = F.fresh (Context.get cpool) ?basename tau
let freshen x = F.alpha (Context.get cpool) x

let local ?pool ?vars ?gamma f =
  let pool = match pool with None -> F.pool () | Some p -> p in
  add_vars pool vars ;
  let gamma = match gamma with None -> { hyps=[] } | Some g -> g in
  Context.bind cpool pool (Context.bind cgamma gamma f)

let sigma () = F.sigma ~pool:(Context.get cpool) ()

let alpha () =
  let sigma = sigma () in
  let alpha = ref Tmap.empty in
  let lookup e x =
    try Tmap.find e !alpha with Not_found ->
      let y = F.Subst.fresh sigma (F.tau_of_var x) in
      let ey = e_var y in alpha := Tmap.add e ey !alpha; ey in
  let compute e =
    match F.repr e with
    | Fvar x -> lookup e x
    | _ -> raise Not_found in
  F.Subst.add_fun sigma compute ; sigma

let subst xs vs =
  let sigma = sigma () in
  begin
    try List.iter2 (fun x v -> F.Subst.add sigma (e_var x) v) xs vs
    with Invalid_argument _ -> raise (Invalid_argument "Wp.Lang.Subst.sigma")
  end ; sigma

let e_subst f =
  let sigma = sigma () in
  F.Subst.add_fun sigma f ; F.e_subst sigma

let p_subst f =
  let sigma = sigma () in
  F.Subst.add_fun sigma f ; F.p_subst sigma

(* -------------------------------------------------------------------------- *)
(* --- Hypotheses                                                         --- *)
(* -------------------------------------------------------------------------- *)

let masked = ref false

let without_assume job x =
  if !masked
  then job x
  else
    try masked := true ; let y = job x in masked := false ; y
    with err -> masked := false ; raise err

let assume p =
  if p != p_true && not !masked then
    let d = Context.get cgamma in
    d.hyps <- p :: d.hyps

let hypotheses g = g.hyps

let get_hypotheses () = (Context.get cgamma).hyps

let filter_hypotheses xs =
  let d = Context.get cgamma in
  let vars = List.fold_right Vars.add xs Vars.empty in
  let matches p = Vars.intersect vars (varsp p) in
  let hs_with_vars , hs_without_vars = List.partition matches d.hyps in
  d.hyps <- hs_without_vars ; hs_with_vars

(** For why3_api but circular dependency *)

module For_export = struct

  type specific_equality = {
    for_tau:(tau -> bool);
    mk_new_eq:F.binop;
  }

  (** delay the create at most as possible (due to constants handling in qed) *)
  let state = ref None

  let init = ref (fun () -> ())

  let add_init f =
    let old = !init in
    init := (fun () -> old (); f ())

  let get_state () =
    match !state with
    | None ->
      let st = QZERO.create () in
      QZERO.in_state st !init ();
      state := Some st;
      st
    | Some st -> st

  let rebuild ?cache t = QZERO.rebuild_in_state (get_state ()) ?cache t

  let set_builtin f c =
    add_init (fun () -> QZERO.set_builtin ~force:true f c)

  let set_builtin' f c =
    add_init (fun () -> QZERO.set_builtin' ~force:true f c)
  let set_builtin_eq f c =
    add_init (fun () -> QZERO.set_builtin_eq ~force:true f c)
  let set_builtin_leq f c =
    add_init (fun () -> QZERO.set_builtin_leq ~force:true f c)

  let in_state f v = QZERO.in_state (get_state ()) f v

end

(* -------------------------------------------------------------------------- *)
(* --- Simplifier                                                         --- *)
(* -------------------------------------------------------------------------- *)

exception Contradiction

class type simplifier =
  object
    method name : string
    method copy : simplifier
    method assume : F.pred -> unit
    method target : F.pred -> unit
    method fixpoint : unit
    method infer : F.pred list

    method equivalent_exp : F.term -> F.term
    method weaker_hyp : F.pred -> F.pred
    method equivalent_branch : F.pred -> F.pred
    method stronger_goal : F.pred -> F.pred
  end

let is_atomic_pred = function
  | Neq _ | Eq _ | Leq _ | Lt _ | Fun _ -> true
  | _ -> false
let is_literal p = match repr p with
  | Not p -> is_atomic_pred (repr p)
  | _ ->  is_atomic_pred (repr p)

let iter_consequence_literals f_literal p =
  let f_literal = (fun p -> if QED.lc_closed p then f_literal p else ()) in
  let rec aux_pos p = match repr p with
    | And ps -> List.iter aux_pos ps
    | Not p ->  aux_neg p
    | Bind((Forall|Exists),_,a) -> aux_pos (QED.lc_repr a)
    | rep when is_atomic_pred rep -> f_literal p
    | _ -> ()
  and aux_neg p = match repr p with
    | Imply (hs,p) -> List.iter aux_pos hs ; aux_neg p
    | Or ps -> List.iter aux_neg ps
    | Not p -> aux_pos p
    | Bind((Forall|Exists),_,a) -> aux_neg (QED.lc_repr a)
    | rep when is_atomic_pred rep -> f_literal (e_not p)
    | _ -> ()
  in aux_pos p

(* -------------------------------------------------------------------------- *)
