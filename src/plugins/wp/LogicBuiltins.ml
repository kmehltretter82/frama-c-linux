(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

(* -------------------------------------------------------------------------- *)
(* Registry for ACSL Builtins                                             --- *)
(* -------------------------------------------------------------------------- *)

open Cil_types
open Ctypes
open Qed
open Lang

type category = Lang.lfun Qed.Logic.category

type builtin =
  | ACSLDEF
  | LFUN of lfun
  | HACK of (F.term list -> F.term)

type t_builtin =
  | ADT of adt
  | HACKT of (F.tau list -> F.tau)

type kind =
  | B (* boolean *)
  | Z (* integer *)
  | R (* real *)
  | I of Ctypes.c_int
  | F of Ctypes.c_float
  | A (* abstract data *)

(* [LC] kinds can be compared by Stdlib.compare *)

let okind = function
  | C_int i -> I i
  | C_float f -> F f
  | _ -> A

let ckind typ = okind (object_of typ)

let rec lkind t =
  match Ast_types.Acsl.unroll ~unroll_typedef:false t with
  | Ctype ty -> ckind ty
  | Ltype({lt_name="set"},[t]) -> lkind t
  | Lreal -> R
  | Linteger -> Z
  | Lboolean -> B
  | Ltype _ | Larrow _ | Lvar _ -> A

let kind_of_tau = function
  | Qed.Logic.Int -> Z
  | Qed.Logic.Real -> R
  | Qed.Logic.Bool -> B
  | _ -> A

let pp_kind fmt = function
  | I i -> Ctypes.pp_int fmt i
  | F f -> Ctypes.pp_float fmt f
  | B -> Format.pp_print_string fmt "bool"
  | Z -> Format.pp_print_string fmt "int"
  | R -> Format.pp_print_string fmt "real"
  | A -> Format.pp_print_string fmt "_"

let pp_kinds fmt = function
  | [] -> ()
  | t::ts ->
    Format.fprintf fmt "(%a" pp_kind t ;
    List.iter (fun t -> Format.fprintf fmt ",%a" pp_kind t) ts ;
    Format.fprintf fmt ")"

let pp_libs fmt = function
  | [] -> ()
  | t::ts ->
    Format.fprintf fmt ": %s" t ;
    List.iter (fun t -> Format.fprintf fmt ",%s" t) ts

let pp_link fmt = function
  | ACSLDEF -> Format.pp_print_string fmt "(ACSL)"
  | HACK _ -> Format.pp_print_string fmt "(HACK)"
  | LFUN f -> Fun.pretty fmt f

(* -------------------------------------------------------------------------- *)
(* --- Driver & Lookup & Registry                                         --- *)
(* -------------------------------------------------------------------------- *)

type sigfun = kind list * builtin

type driver = {
  driverid : string;
  description : string;
  hlogic : (string , sigfun list) Hashtbl.t;
  htypes : (string , t_builtin) Hashtbl.t;
  hdeps : (string, string list) Hashtbl.t;
  hoptions :
    (string (* library *) * string (* group *) * string (* name *), string list)
      Hashtbl.t;
  mutable locked: bool
}

let lock driver = driver.locked <- true

let id d = d.driverid
let descr d = d.description
let is_default d = (d.driverid = "")
let compare d d' = String.compare d.driverid d'.driverid

let driver = Context.create "driver"
let cdriver_ro () = Context.get driver
let cdriver_rw () =
  let driver = Context.get driver in
  if driver.locked then
    Wp_parameters.failure "Attempt to modify locked: %s" driver.driverid ;
  driver

let lookup_driver name kinds =
  try
    let sigs = Hashtbl.find (cdriver_ro ()).hlogic name in
    try List.assoc kinds sigs
    with Not_found ->
      Wp_parameters.feedback ~once:true
        "Use -wp-msg-key 'driver' for debugging drivers" ;
      if kinds=[]
      then Warning.error "Builtin %s undefined as a constant" name
      else Warning.error "Builtin %s undefined with signature %a" name
          pp_kinds kinds
  with Not_found ->
    if Logic_env.is_builtin_logic_function name
    || Logic_env.is_builtin_logic_ctor name
    then
      Warning.error "Builtin %s%a not defined" name pp_kinds kinds
    else
      ACSLDEF

let hacks = Hashtbl.create 8
let hack name phi = Hashtbl.replace hacks name phi

let lookup name kinds =
  try
    let hack = Hashtbl.find hacks name in
    let compute es =
      try hack es with Not_found ->
      match lookup_driver name kinds with
      | ACSLDEF | HACK _ -> Warning.error "No fallback for hacked '%s'" name
      | LFUN p -> F.e_fun p es
    in HACK compute
  with Not_found -> lookup_driver name kinds

let register ?source name kinds link =
  let driver = cdriver_rw () in
  let sigs = try Hashtbl.find driver.hlogic name with Not_found -> [] in
  if List.exists (fun (s,_) -> s = kinds) sigs then
    Wp_parameters.warning ?source "Redefinition of logic %s%a"
      name pp_kinds kinds ;
  let entry = (kinds,link) in
  Hashtbl.add driver.hlogic name (entry::sigs)

let register_type ?source name builtin =
  let driver = cdriver_rw () in
  if Hashtbl.mem driver.htypes name then
    Wp_parameters.warning ?source "Redefinition of type %s" name ;
  Hashtbl.add driver.htypes name builtin

let iter_table f =
  let items = ref [] in
  Hashtbl.iter
    (fun a sigs -> List.iter (fun (ks,lnk) -> items := (a,ks,lnk)::!items) sigs)
    (cdriver_ro ()).hlogic ;
  List.iter f (List.sort Stdlib.compare !items)

let iter_libs f =
  let items = ref [] in
  Hashtbl.iter
    (fun a libs -> items := (a,libs) :: !items)
    (cdriver_ro ()).hdeps ;
  List.iter f (List.sort Stdlib.compare !items)

let dump () =
  Log.print_on_output
    begin fun fmt ->
      Format.fprintf fmt "Builtins:@\n" ;
      iter_libs
        (fun (name,libs) -> Format.fprintf fmt " * Library %s%a@\n"
            name pp_libs libs) ;
      iter_table
        (fun (name,k,lnk) -> Format.fprintf fmt " * Logic %s%a = %a@\n"
            name pp_kinds k pp_link lnk) ;
    end

(* -------------------------------------------------------------------------- *)
(* --- Implemented Builtins                                               --- *)
(* -------------------------------------------------------------------------- *)

let logic phi =
  lookup phi.l_var_info.lv_name
    (List.map (fun v -> lkind v.lv_type) phi.l_profile)

let ctor phi =
  lookup phi.ctor_name (List.map lkind phi.ctor_params)

let constant name = lookup name []

(* -------------------------------------------------------------------------- *)
(* --- Declaration of Builtins                                            --- *)
(* -------------------------------------------------------------------------- *)

let dependencies lib =
  Hashtbl.find (cdriver_ro ()).hdeps lib

let add_library lib deps =
  let others = try dependencies lib with Not_found -> [] in
  Hashtbl.add (cdriver_rw ()).hdeps lib (others @ deps)

let add_alias ~source name kinds ~alias =
  register ~source name kinds (lookup alias kinds)

let check_param ~source name kind tau =
  match kind, tau with
  | (B, (Logic.Bool | Prop)) | (Z, Int) | (R, Real)
  | (I _, Int) | (F _, Real) | (A, _) -> ()
  | (F Float32, Data(qf,[])) when Qed.Symbol.Data.name qf = "f32" -> ()
  | (F Float64, Data(qf,[])) when Qed.Symbol.Data.name qf = "f64" -> ()
  | _ ->
    Wp_parameters.error ~source
      "Incorrect driver for %S (kind %a for type %a)"
      name pp_kind kind Qed.Symbol.Tau.pretty tau

let check_signature ~source ?(category=Logic.Function) result name kinds lf =
  begin
    match lf with
    | QFUN l ->
      let _,tr,ts = Qed.Symbol.signature l.e_symbol in
      begin
        match category with
        | Logic.Operator _ -> List.iter (check_param ~source name result) ts ;
        | _ -> List.iter2 (check_param ~source name) kinds ts ;
      end ;
      check_param ~source name result tr ;
    | _ -> ()
  end

let add_logic ~source ?category result name kinds ~link =
  let lfun = Lang.extern_f ?category "%s" link in
  check_signature ~source ?category result name kinds lfun ;
  register ~source name kinds (LFUN lfun)

let add_predicate ~source name kinds ~link =
  let lfun = Lang.extern_f "%s" link in
  check_signature ~source B name kinds lfun ;
  register ~source name kinds (LFUN lfun)

let add_ctor ~source name kinds ~link =
  let lfun = Lang.extern_f ~category:Constructor "%s" link in
  check_signature ~source A name kinds lfun ;
  register ~source name kinds (LFUN lfun)

let add_type ?source name ~link =
  register_type ?source name (ADT (Lang.extern_t link))

let hack_type name fn =
  register_type name (HACKT fn)

type sanitizer = driver_dir:string -> string -> string
let sanitizers : ( string * string , sanitizer ) Hashtbl.t = Hashtbl.create 10

exception Unknown_option of string * string

let sanitize ~driver_dir group name v =
  try
    (Hashtbl.find sanitizers (group,name)) ~driver_dir v
  with Not_found -> raise (Unknown_option(group,name))

type doption = string * string

let create_option ~sanitizer group name =
  let option = (group,name) in
  Hashtbl.replace sanitizers option sanitizer ;
  option

let get_option (group,name) ~library =
  try Hashtbl.find (cdriver_ro ()).hoptions (library,group,name)
  with Not_found -> []

let set_option ~driver_dir group name ~library value =
  let value = sanitize ~driver_dir group name value in
  Hashtbl.replace (cdriver_rw ()).hoptions (library,group,name) [value]

let add_option ~driver_dir group name ~library value =
  let value = sanitize ~driver_dir group name value in
  let l = get_option (group,name) ~library in
  Hashtbl.replace (cdriver_rw ()).hoptions (library,group,name) (l @ [value])

(* -------------------------------------------------------------------------- *)
(* --- Implemented Builtins                                               --- *)
(* -------------------------------------------------------------------------- *)

let builtin_driver = {
  driverid = "builtin driver";
  description = "builtin driver";
  hlogic = Hashtbl.create 131;
  htypes = Hashtbl.create 131;
  hdeps  = Hashtbl.create 31;
  hoptions = Hashtbl.create 131;
  locked = false
}

let add_builtin name kinds lfun =
  let phi = LFUN lfun in
  if Context.defined driver then
    register name kinds phi
  else
    Context.bind driver builtin_driver (register name kinds) phi

let add_builtin_type name adt =
  if Context.defined driver then
    register_type name (ADT adt)
  else
    Context.bind driver builtin_driver (register_type name) (ADT adt)

let hack_type name poly =
  if Context.defined driver then hack_type name poly
  else Context.bind driver builtin_driver hack_type name poly

let lookup_t =
  let lookup a = Hashtbl.find (cdriver_ro ()).htypes a in
  fun name ->
    if Context.defined driver then lookup name
    else Context.bind driver builtin_driver lookup name

let resolve_t name ts =
  match lookup_t name with
  | ADT adt -> Qed.Logic.Data(adt,ts)
  | HACKT fn -> fn ts

let is_builtin_type name =
  try let _ = lookup_t name in true with Not_found -> false

let () = Context.set Lang.hacked_types resolve_t

let new_driver ~id ?(base=builtin_driver)
    ?(descr=id) ?(configure=fun () -> ()) () =
  lock base ;
  let new_driver = {
    driverid = id ;
    description = descr ;
    hlogic = Hashtbl.copy base.hlogic ;
    htypes = Hashtbl.copy base.htypes ;
    hdeps  = Hashtbl.copy base.hdeps ;
    hoptions = Hashtbl.copy base.hoptions ;
    locked = false
  } in
  let old = Context.push driver new_driver in
  configure () ;
  Context.pop driver old ;
  new_driver

(* -------------------------------------------------------------------------- *)
