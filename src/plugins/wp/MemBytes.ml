(**************************************************************************)
(*                                                                        *)
(*  This file is part of WP plug-in of Frama-C.                           *)
(*                                                                        *)
(*  Copyright (C) 2007-2024                                               *)
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

open Lang.F
open Sigs
open Ctypes

module Logic = Qed.Logic

(* Why3 symbols *)

module Why3 = struct
  let library = "membytes"

  let t_vblock = Qed.Logic.Array (Qed.Logic.Int, Qed.Logic.Int)
  let t_memory = Qed.Logic.Array (Qed.Logic.Int,t_vblock)
  let t_iblock = Qed.Logic.Array (Qed.Logic.Int, Qed.Logic.Bool)
  let t_init = Qed.Logic.Array   (Qed.Logic.Int,t_iblock)

  let ty_fst_arg = function
    | Some l :: _ -> l
    | _ -> raise Not_found
  let l_havoc = Qed.Engine.F_call "havoc"
  let f_havoc = Lang.extern_f ~library ~typecheck:ty_fst_arg ~link:l_havoc "havoc"
  let havoc fresh current loc n =
    Lang.F.e_fun f_havoc [fresh;current;loc;n]

  let p_cinits = Lang.extern_fp ~coloring:true ~library "cinits"
  let cinits m = p_call p_cinits [m]
  let p_sconst = Lang.extern_fp ~coloring:true ~library "sconst"
  let sconst m = p_call p_sconst [m]
  let p_eqmem = Lang.extern_fp ~library "eqmem"
  let eqmem m1 m2 a size = p_call p_eqmem [ m1 ; m2 ; a ; size ]
  let p_is_init_range = Lang.extern_fp ~library "is_init_range"
  let is_init_range m a size = p_call p_is_init_range [ m ; a ; size ]
  let f_set_init_range = Lang.extern_fp ~library "set_init_range"
  let set_init_range m a size = e_fun f_set_init_range [ m ; a ; size ]

  let ty_fst_arg_val = function
    | Some (Qed.Logic.Array (_, Qed.Logic.Array (_, t))) :: _ -> t
    | _ -> raise Not_found

  let f_raw_get = Lang.extern_f ~typecheck:ty_fst_arg_val ~library "raw_get"
  let raw_get m a = e_fun f_raw_get [ m ; a ]
  let f_raw_set = Lang.extern_f ~typecheck:ty_fst_arg ~library "raw_set"
  let raw_set m a v = e_fun f_raw_set [ m ; a ; v]

  let p_bytes = Lang.extern_fp ~library "bytes"
  let bytes m = p_call p_bytes [ m ]

  (* read/write *)
  let f_read_uint8 = Lang.extern_f ~result:Qed.Logic.Int ~library "read_uint8"
  let read_uint8 m a = e_fun f_read_uint8 [ m ; a ]
  let f_read_uint16 = Lang.extern_f ~result:Qed.Logic.Int ~library "read_uint16"
  let read_uint16 m a = e_fun f_read_uint16 [ m ; a ]
  let f_read_uint32 = Lang.extern_f ~result:Qed.Logic.Int ~library "read_uint32"
  let read_uint32 m a = e_fun f_read_uint32 [ m ; a ]
  let f_read_uint64 = Lang.extern_f ~result:Qed.Logic.Int ~library "read_uint64"
  let read_uint64 m a = e_fun f_read_uint64 [ m ; a ]
  let f_read_sint8 = Lang.extern_f ~result:Qed.Logic.Int ~library "read_sint8"
  let read_sint8 m a = e_fun f_read_sint8 [ m ; a ]
  let f_read_sint16 = Lang.extern_f ~result:Qed.Logic.Int ~library "read_sint16"
  let read_sint16 m a = e_fun f_read_sint16 [ m ; a ]
  let f_read_sint32 = Lang.extern_f ~result:Qed.Logic.Int ~library "read_sint32"
  let read_sint32 m a = e_fun f_read_sint32 [ m ; a ]
  let f_read_sint64 = Lang.extern_f ~result:Qed.Logic.Int ~library "read_sint64"
  let read_sint64 m a = e_fun f_read_sint64 [ m ; a ]
  let f_write_uint8 = Lang.extern_f ~result:t_memory ~library "write_uint8"
  let write_uint8 m a v = e_fun f_write_uint8 [ m ; a ; v ]
  let f_write_uint16 = Lang.extern_f ~result:t_memory ~library "write_uint16"
  let write_uint16 m a v = e_fun f_write_uint16 [ m ; a ; v ]
  let f_write_uint32 = Lang.extern_f ~result:t_memory ~library "write_uint32"
  let write_uint32 m a v = e_fun f_write_uint32 [ m ; a ; v ]
  let f_write_uint64 = Lang.extern_f ~result:t_memory ~library "write_uint64"
  let write_uint64 m a v = e_fun f_write_uint64 [ m ; a ; v ]
  let f_write_sint8 = Lang.extern_f ~result:t_memory ~library "write_sint8"
  let write_sint8 m a v = e_fun f_write_sint8 [ m ; a ; v ]
  let f_write_sint16 = Lang.extern_f ~result:t_memory ~library "write_sint16"
  let write_sint16 m a v = e_fun f_write_sint16 [ m ; a ; v ]
  let f_write_sint32 = Lang.extern_f ~result:t_memory ~library "write_sint32"
  let write_sint32 m a v = e_fun f_write_sint32 [ m ; a ; v ]
  let f_write_sint64 = Lang.extern_f ~result:t_memory ~library "write_sint64"
  let write_sint64 m a v = e_fun f_write_sint64 [ m ; a ; v ]

  (* init *)
  let f_read_init8 = Lang.extern_f ~result:Qed.Logic.Bool ~library "read_init8"
  let read_init8 m a = e_fun f_read_init8 [ m ; a ]
  let f_read_init16 = Lang.extern_f ~result:Qed.Logic.Bool ~library "read_init16"
  let read_init16 m a = e_fun f_read_init16 [ m ; a ]
  let f_read_init32 = Lang.extern_f ~result:Qed.Logic.Bool ~library "read_init32"
  let read_init32 m a = e_fun f_read_init32 [ m ; a ]
  let f_read_init64 = Lang.extern_f ~result:Qed.Logic.Bool ~library "read_init64"
  let read_init64 m a = e_fun f_read_init64 [ m ; a ]
  let f_write_init8 = Lang.extern_f ~result:t_init ~library "write_init8"
  let write_init8 m a v = e_fun f_write_init8 [ m ; a ; v ]
  let f_write_init16 = Lang.extern_f ~result:t_init ~library "write_init16"
  let write_init16 m a v = e_fun f_write_init16 [ m ; a ; v ]
  let f_write_init32 = Lang.extern_f ~result:t_init ~library "write_init32"
  let write_init32 m a v = e_fun f_write_init32 [ m ; a ; v ]
  let f_write_init64 = Lang.extern_f ~result:t_init ~library "write_init64"
  let write_init64 m a v = e_fun f_write_init64 [ m ; a ; v ]
end

(* Model *)
let datatype = "MemBytes"
let lc_name = String.lowercase_ascii datatype
let dkey_state = Wp_parameters.register_category (lc_name ^ ":state")
let dkey_model = Wp_parameters.register_category (lc_name ^ ":model")

let configure () =
  begin
    let orig_pointer = Context.push Lang.pointer MemAddr.t_addr in
    let orig_null    = Context.push Cvalues.null (p_equal MemAddr.null) in
    let rollback () =
      Context.pop Lang.pointer orig_pointer ;
      Context.pop Cvalues.null orig_null ;
    in
    rollback
  end
let no_binder = { bind = fun _ f v -> f v }
let configure_ia _ = no_binder

let hypotheses p = p

module Chunk =
struct
  type t = Mem | Init | Alloc
  let self = "Chunk" ^ datatype
  let hash = Hashtbl.hash
  let equal = (=)
  let compare c1 c2 =
    match c1, c2 with
    | Mem, Mem | Init, Init | Alloc, Alloc -> 0
    | Mem, _ -> 1
    | _, Mem -> -1
    | Init, _ -> 1
    | _, Init -> -1

  let pretty fmt = function
    | Mem  -> Format.fprintf fmt "Mem"
    | Init -> Format.fprintf fmt "Init"
    | Alloc -> Format.fprintf fmt "Alloc"

  let tau_of_memory = Why3.t_memory
  let tau_of_init = Why3.t_init

  let tau_of_chunk = function
    | Mem -> tau_of_memory
    | Init -> tau_of_init
    | Alloc -> Logic.Array (Logic.Int, Logic.Int)

  let val_of_chunk = function
    | Mem -> Logic.Int
    | Init -> Logic.Bool
    | Alloc -> Logic.Int

  let basename_of_chunk = function
    | Mem -> "mem"
    | Init -> "init"
    | Alloc -> "alloc"

  let is_framed _ = false
end

module Heap = Qed.Collection.Make(Chunk)
module Sigma = Sigma.Make(Chunk)(Heap)

type loc = term

let pretty fmt =
  Format.fprintf fmt "l:(%a)" pp_term

let vars = vars
let occurs = occurs

type chunk = Chunk.t
type sigma = Sigma.t
type domain = Sigma.domain
type segment = loc rloc

let comp_cluster () =
  Definitions.cluster ~id:"Compound" ~title:"Memory Compound Loader" ()

let shift_cluster () =
  Definitions.cluster ~id:"Shifts" ~title:"Shifts Definitions" ()


(* ********************************************************************** *)
(* SIZE                                                                   *)
(* ********************************************************************** *)

module OPAQUE_COMP_LENGTH = WpContext.Generator(Cil_datatype.Compinfo)
    (struct
      let name = "MemBytes.EmptyCompLength"
      type key = Cil_types.compinfo
      type data = Lang.lfun
      let compile c =
        if c.Cil_types.cfields <> None then
          Wp_parameters.fatal
            "Asking for opaque struct length on non opaque struct" ;
        let result = Lang.t_int in
        let size =
          Lang.generated_f ~params:[] ~result "Length_of_%s" (Lang.comp_id c)
        in
        (* Registration *)
        Definitions.define_symbol {
          d_cluster = Definitions.compinfo c ;
          d_lfun = size ; d_types = 0 ; d_params = [] ;
          d_definition = Logic result ;
        } ;
        Definitions.define_lemma {
          l_kind = Admit ;
          l_name = "Positive_Length_of_" ^ Lang.comp_id c ;
          l_triggers = [] ; l_forall = [] ;
          l_cluster = Definitions.compinfo c ;
          l_lemma = Lang.F.(p_lt e_zero (e_fun size []))
        } ;
        size
    end)

let protected_sizeof_object = function
  | C_comp ({ cfields = None } as c) ->
    e_fun (OPAQUE_COMP_LENGTH.get c) []
  | obj -> e_int @@ Ctypes.sizeof_object obj

(* ********************************************************************** *)
(* SHIFT                                                                  *)
(* ********************************************************************** *)

type shift =
  | RS_Field of Cil_types.fieldinfo * term (* offset of the field *)
  | RS_Index of term  (* size of the shift *)

let phi_base = function
  | p::_ -> MemAddr.base p
  | _ -> raise Not_found

let phi_field offset = function
  | [p] -> e_add (MemAddr.offset p) offset
  | _ -> raise Not_found

let phi_index size = function
  | [p;k] -> e_add (MemAddr.offset p) (e_mul size k)
  | _ -> raise Not_found

module RegisterShift = WpContext.Static
    (struct
      type key = Lang.lfun
      type data = shift
      let name = "MemBytes.RegisterShift"
      include Lang.Fun
    end)

let field_offset ci field =
  let comp = Cil_types.TComp(ci, []) in
  let field = Cil_types.Field(field, NoOffset) in
  let bits_offset, bits_size = Cil.bitsOffset comp field in
  if 0 <> bits_offset mod 8 || 0 <> bits_size mod 8 then
    Wp_parameters.error "Bitfields not allowed in Bytes model" ;
  bits_offset / 8


module ShiftFieldDef = WpContext.StaticGenerator(Cil_datatype.Fieldinfo)
    (struct
      let name = "MemBytes.ShiftFieldDef"
      type key = Cil_types.fieldinfo
      type data = Definitions.dfun

      let generate f =
        let result = MemAddr.t_addr in
        let lfun = Lang.generated_f ~result "shiftfield_%s" (Lang.field_id f) in
        (* Since its a generated it is the unique name given *)
        let p = Lang.freshvar ~basename:"p" MemAddr.t_addr in
        let tp = e_var p in
        let position = e_int @@ field_offset f.fcomp f in
        let def = MemAddr.shift tp position in
        let dfun = Definitions.Function( result , Def , def) in
        RegisterShift.define lfun (RS_Field(f,position)) ;
        MemAddr.register ~base:phi_base ~offset:(phi_field position) lfun ;
        Definitions.{
          d_lfun = lfun ; d_types = 0 ;
          d_params = [p] ;
          d_definition = dfun ;
          d_cluster = Definitions.dummy () ;
        }

      let compile = Lang.local generate
    end)

module ShiftField = WpContext.Generator(Cil_datatype.Fieldinfo)
    (struct
      let name = "MemBytes.ShiftField"
      type key = Cil_types.fieldinfo
      type data = Lang.lfun
      let compile fd =
        let dfun = ShiftFieldDef.get fd in
        let d_cluster = shift_cluster () in
        Definitions.define_symbol { dfun with d_cluster } ;
        dfun.d_lfun
    end)

module Cobj =
struct
  type t = c_object
  let pretty = C_object.pretty
  let compare = compare_ptr_conflated
end

(* This is a model-independent generator,
   which will be inherited from the model-dependent clusters *)
module ShiftGen = WpContext.StaticGenerator(Cobj)
    (struct
      let name = "MemBytes.ShiftDef"
      type key = Cobj.t
      type data = Definitions.dfun

      let rec c_object_id fmt = function
        | C_int i -> pp_int fmt i
        | C_float f -> pp_float fmt f
        | C_pointer _ -> Format.fprintf fmt "PTR"
        | C_comp c -> Format.pp_print_string fmt (Lang.comp_id c)
        | C_array a ->
          let te = object_of a.arr_element in
          match a.arr_flat with
          | None -> Format.fprintf fmt "A_%a" c_object_id te
          | Some f -> Format.fprintf fmt "A%d_%a" f.arr_size c_object_id te

      let c_object_id c = Format.asprintf "%a@?" c_object_id c

      let generate obj =
        let result = MemAddr.t_addr in
        let shift = Lang.generated_f ~result "shift_%s" (c_object_id obj) in
        let size = protected_sizeof_object obj in
        (* Since its a generated it is the unique name given *)
        let p = Lang.freshvar ~basename:"p" MemAddr.t_addr in
        let tp = e_var p in
        let k = Lang.freshvar ~basename:"k" Qed.Logic.Int in
        let tk = e_var k in
        let def = MemAddr.shift tp (e_mul size tk) in
        let dfun = Definitions.Function( result , Def , def) in
        RegisterShift.define shift (RS_Index size) ;
        MemAddr.register ~base:phi_base ~offset:(phi_index size)
          ~linear:true shift ;
        Definitions.{
          d_lfun = shift ; d_types = 0 ;
          d_params = [p;k] ;
          d_definition = dfun ;
          d_cluster = Definitions.dummy () ;
        }

      let compile = Lang.local generate
    end)

(* The model-dependent derivation of model-independent ShiftDef *)
module Shift = WpContext.Generator(Cobj)
    (struct
      let name = "MemBytes.Shift"
      type key = Cobj.t
      type data = Lang.lfun
      let compile obj =
        let dfun = ShiftGen.get obj in
        let d_cluster = shift_cluster () in
        Definitions.define_symbol { dfun with d_cluster } ;
        dfun.d_lfun
    end)

let field loc f =
  Wp_parameters.debug ~level:3 ~dkey:dkey_model
    "%s.field %a.%a" datatype pretty loc Cil_printer.pp_field f ;
  e_fun (ShiftField.get f) [loc]
let shift loc obj k =
  Wp_parameters.debug ~level:3 ~dkey:dkey_model
    "%s.shift %a + %a(%a)" datatype pretty loc pp_term k Ctypes.pp_object obj ;
  e_fun (Shift.get obj) [loc;k]

(* ********************************************************************** *)
(* VALIDITY and SEPARATION                                                *)
(* ********************************************************************** *)

let allocated sigma l = e_get (Sigma.value sigma Alloc) (MemAddr.base l)

let s_valid sigma acs p n =
  let valid = match acs with
    | RW -> MemAddr.valid_rw
    | RD -> MemAddr.valid_rd
    | OBJ -> (fun m p _ -> MemAddr.valid_obj m p)
  in
  valid (Sigma.value sigma Alloc) p n

let s_invalid sigma p n =
  MemAddr.invalid (Sigma.value sigma Alloc) p n

let segment phi = function
  | Rloc(obj,l) ->
    phi l @@ protected_sizeof_object obj
  | Rrange(l,obj,Some a,Some b) ->
    let l = shift l obj a in
    let n = e_mul (protected_sizeof_object obj) (e_range a b) in
    phi l n
  | Rrange(l,_,a,b) ->
    Wp_parameters.abort ~current:true
      "Invalid infinite range @[<hov 2>%a+@,(%a@,..%a)@]"
      Lang.F.pp_term l Vset.pp_bound a Vset.pp_bound b

let valid sigma acs =
  Wp_parameters.debug ~level:2 ~dkey:dkey_model "%s.valid _ _" datatype ;
  segment (s_valid sigma acs)
let invalid sigma =
  Wp_parameters.debug ~level:2 ~dkey:dkey_model "%s.invalid _ _" datatype ;
  segment (s_invalid sigma)

let included =
  Wp_parameters.debug ~level:2 ~dkey:dkey_model "%s.included _ _" datatype ;
  let addrof l = l in
  let sizeof obj = protected_sizeof_object obj in
  MemAddr.included ~shift ~addrof ~sizeof

let separated =
  Wp_parameters.debug ~level:2 ~dkey:dkey_model "%s.separated _ _" datatype ;
  let addrof l = l in
  let sizeof obj = protected_sizeof_object obj in
  MemAddr.separated ~shift ~addrof ~sizeof

(* Prepare loader *)

let float_cluster () =
  Definitions.cluster ~id:"MemBytes.Float" ~title:"MemBytes definitions" ()

module Float = struct
  type t = Ctypes.c_float
  let pretty = Ctypes.pp_float
  let compare = Ctypes.compare_c_float
  let ikind = function
    | Float32 -> UInt32
    | Float64 -> UInt64
end

module CODEC_FLOAT = WpContext.Generator(Float)
    (struct
      let name = "MemBytes.LOAD_FLOAT"
      type key = Float.t
      type data = Lang.lfun * Lang.lfun

      let decode ft =
        let result = Cfloat.tau_of_float ft in
        let f = Lang.freshvar ~basename:"f" Lang.t_int in
        let decode =
          Lang.generated_f ~result "int_to_%a" Float.pretty ft in
        Definitions.define_symbol {
          d_lfun = decode ;
          d_cluster = float_cluster () ; d_types = 0 ;
          d_params = [ f ] ;
          d_definition = Logic result ;
        } ;
        decode

      let encode ft =
        let result = Lang.t_int in
        let f = Lang.freshvar ~basename:"f" @@ Cfloat.tau_of_float ft in
        let encode =
          Lang.generated_f ~result "%a_to_int" Float.pretty ft in
        Definitions.define_symbol {
          d_lfun = encode ;
          d_cluster = float_cluster () ; d_types = 0 ;
          d_params = [ f ] ;
          d_definition = Logic result ;
        } ;
        encode

      let add_decode_encode ft encode decode =
        let f = Lang.freshvar ~basename:"f" @@ Cfloat.tau_of_float ft in
        let tf = e_var f in
        let name = Format.asprintf "decode_encode_%a" Float.pretty ft in
        let lemma =
          p_equal tf (e_fun decode [e_fun encode [tf]]) in
        Definitions.define_lemma {
          l_kind = Admit ;
          l_name = name ;
          l_triggers = [] ;
          l_forall = [f] ;
          l_cluster = float_cluster () ;
          l_lemma = lemma
        }

      let add_encode_decode ft encode decode =
        let i = Lang.freshvar ~basename:"i" Lang.t_int in
        let ti = e_var i in
        let name = Format.asprintf "encode_decode_%a" Float.pretty ft in
        let lemma =
          p_equal ti (e_fun encode [e_fun decode [ti]]) in
        Definitions.define_lemma {
          l_kind = Admit ;
          l_name = name ;
          l_triggers = [] ;
          l_forall = [i] ;
          l_cluster = float_cluster () ;
          l_lemma = lemma
        }

      let add_encode_bounds ft encode =
        let f = Lang.freshvar ~basename:"f" @@ Cfloat.tau_of_float ft in
        let tf = e_var f in
        let name = Format.asprintf "encode_bounds_%a" Float.pretty ft in
        let lemma = Cint.range (Float.ikind ft) @@ e_fun encode [ tf ] in
        Definitions.define_lemma {
          l_kind = Admit ;
          l_name = name ;
          l_triggers = [] ;
          l_forall = [f] ;
          l_cluster = float_cluster () ;
          l_lemma = lemma
        }

      let compile ft =
        let encode = encode ft in
        let decode = decode ft in
        add_encode_decode ft encode decode ;
        add_decode_encode ft encode decode ;
        add_encode_bounds ft encode ;
        encode, decode
    end)

let float_to_int fkind f =
  e_fun (fst @@ CODEC_FLOAT.get fkind) [ f ]

let int_to_float fkind f =
  e_fun (snd @@ CODEC_FLOAT.get fkind) [ f ]

let load_int_raw memory kind addr =
  let read = match kind with
    | CBool -> Why3.read_uint8
    | UInt8 -> Why3.read_uint8
    | SInt8 -> Why3.read_sint8
    | UInt16 -> Why3.read_uint16
    | SInt16 -> Why3.read_sint16
    | UInt32 -> Why3.read_uint32
    | SInt32 -> Why3.read_sint32
    | UInt64 -> Why3.read_uint64
    | SInt64 -> Why3.read_sint64
  in
  read memory addr

let load_int sigma kind addr =
  load_int_raw (Sigma.value sigma Chunk.Mem) kind addr

let load_float sigma kind addr =
  int_to_float kind @@ load_int sigma (Float.ikind kind) addr

let load_pointer_raw memory _ty loc =
  MemAddr.addr_of_int @@ load_int_raw memory (Ctypes.c_ptr ()) loc

let load_pointer sigma _ty loc =
  MemAddr.addr_of_int @@ load_int sigma (Ctypes.c_ptr ()) loc

let load_init memory size loc =
  match size with
  | 1 -> Why3.read_init8  memory loc
  | 2 -> Why3.read_init16 memory loc
  | 4 -> Why3.read_init32 memory loc
  | 8 -> Why3.read_init64 memory loc
  | _ -> assert false

let is_init_atom sigma obj loc =
  let init_memory = Sigma.value sigma Init in
  let size = sizeof_object obj in
  load_init init_memory size loc

let store_int sigma kind addr v =
  let write = match kind with
    | CBool -> Why3.write_uint8
    | UInt8 -> Why3.write_uint8
    | SInt8 -> Why3.write_sint8
    | UInt16 -> Why3.write_uint16
    | SInt16 -> Why3.write_sint16
    | UInt32 -> Why3.write_uint32
    | SInt32 -> Why3.write_sint32
    | UInt64 -> Why3.write_uint64
    | SInt64 -> Why3.write_sint64
  in
  Chunk.Mem, write (Sigma.value sigma Mem) addr v

let store_float sigma kind addr v =
  store_int sigma (Float.ikind kind) addr @@ float_to_int kind v

let store_pointer sigma _kind addr v =
  store_int sigma (Ctypes.c_ptr ()) addr @@ MemAddr.int_of_addr v

let store_init_raw m size loc v =
  let write = match size with
    | 1 -> Why3.write_init8
    | 2 -> Why3.write_init16
    | 4 -> Why3.write_init32
    | 8 -> Why3.write_init64
    | _ -> assert false
  in
  write m loc v

let set_init_atom sigma obj loc v =
  let init_memory = Sigma.value sigma Init in
  let size = sizeof_object obj in
  Chunk.Init, store_init_raw init_memory size loc v

module Model = struct
  module Chunk = Chunk
  module Sigma = Sigma

  let name = "MemBytes.Loader"

  type nonrec loc = loc

  let sizeof = protected_sizeof_object
  let field = field
  let shift = shift

  let to_addr l = l
  let to_region_pointer l = 0,l
  let of_region_pointer _r _obj l = l

  let value_footprint _ _ = Sigma.Chunk.Set.singleton Chunk.Mem
  let init_footprint _ _ = Sigma.Chunk.Set.singleton Chunk.Init

  let frames  ~addr:p ~offset:n ?(basename="mem") tau =
    let t_block = Qed.Logic.Array (Qed.Logic.Int, tau) in
    let t_mem = Qed.Logic.Array(Qed.Logic.Int, t_block) in
    let m  = e_var (Lang.freshvar ~basename t_mem) in
    let m' = e_var (Lang.freshvar ~basename t_mem) in
    let p' = e_var (Lang.freshvar ~basename:"q" MemAddr.t_addr) in
    let n' = e_var (Lang.freshvar ~basename:"n" Qed.Logic.Int) in
    let mh = Why3.havoc m' m p' n' in
    let v' = e_var (Lang.freshvar ~basename:"v" tau) in
    let meq = Why3.eqmem m m' p' n' in
    let diff = p_call MemAddr.p_separated [p;n;p';e_one] in
    let sep = p_call MemAddr.p_separated [p;n;p';n'] in
    let inc = p_call MemAddr.p_included [p;n;p';n'] in
    let teq = Definitions.Trigger.of_pred meq in
    [
      "update" , []    , [diff]    , m , Why3.raw_set m p' v' ;
      "eqmem"  , [teq] , [inc;meq] , m , m' ;
      "havoc"  , []    , [sep]     , m , mh ;
    ]

  let frames obj addr = function
    | Chunk.Alloc -> []
    | m ->
      let offset = sizeof obj in
      let tau = Chunk.val_of_chunk m in
      let basename = Chunk.basename_of_chunk m in
      frames ~addr ~offset ~basename tau

  let last sigma obj l =
    let n = protected_sizeof_object obj in
    e_sub (e_div (allocated sigma l) n) e_one

  let havoc obj loc ~length chunk ~fresh ~current =
    if chunk <> Chunk.Alloc then
      let n = e_mul (e_int @@ sizeof_object obj) length in
      Why3.havoc fresh current loc n
    else fresh

  let eqmem obj loc _chunk m1 m2 =
    Why3.eqmem m1 m2 loc @@ sizeof obj

  let eqmem_forall obj loc _chunk m1 m2 =
    let xp = Lang.freshvar ~basename:"p" MemAddr.t_addr in
    let p = e_var xp in
    let addrof l = l in
    let separated =
      MemAddr.separated
        ~shift ~addrof ~sizeof (Rloc (C_int UInt8, p)) (Rloc (obj, loc))
    in
    let equal = p_equal (Why3.raw_get m1 p) (Why3.raw_get m2 p) in
    [xp],separated,equal

  let load_int = load_int
  let load_float = load_float
  let load_pointer = load_pointer

  let store_int = store_int
  let store_float = store_float
  let store_pointer = store_pointer

  let is_init_atom = is_init_atom
  let is_init_range sigma obj loc length =
    let n = e_mul (sizeof obj) length in
    Why3.is_init_range (Sigma.value sigma Init) loc n

  let set_init_atom = set_init_atom
  let set_init obj loc ~length _chunk ~current =
    let n = e_mul (sizeof obj) length in
    Why3.set_init_range current loc n

end

include MemLoader.Make(Model)

(* ********************************************************************** *)
(* BASES                                                                  *)
(* ********************************************************************** *)

let cluster_globals () =
  Definitions.cluster ~id:"Globals" ~title:"Global Variables" ()
let globals = 0
let locals = 1
let formals = 2

module RegisterBASE = WpContext.Index
    (struct
      type key = Lang.lfun
      type data = Cil_types.varinfo
      let name = "MemBytes.RegisterBASE"
      include Lang.Fun
    end)

module BASE = WpContext.Generator(Cil_datatype.Varinfo)
    (struct
      let name = datatype ^ ".BASE"
      type key = Cil_types.varinfo
      type data = Lang.F.term

      open Cil_types

      let static_alloc prefix base =
        let name = prefix ^ "_static_alloc" in
        Definitions.define_lemma {
          l_kind = Admit ;
          l_name = name ; l_triggers = [] ; l_forall = [] ;
          l_lemma = MemAddr.static_alloc base ;
          l_cluster = cluster_globals () ;
        }

      let region prefix x base =
        let name = prefix ^ "_region" in
        let region =
          if x.vglob then globals
          else if x.vformal then formals
          else locals
        in
        Definitions.define_lemma {
          l_kind = Admit ;
          l_name = name ; l_triggers = [] ; l_forall = [] ;
          l_lemma = p_equal (MemAddr.region base) (e_int region) ;
          l_cluster = cluster_globals () ;
        }

      let sizeof x =
        Warning.handle
          ~handler:(fun _ -> None)
          ~fallback:(Printf.sprintf "No allocation size for variable '%s'" x.vname)
          (fun obj -> Some (protected_sizeof_object obj))
          (Ctypes.object_of x.vtype)

      let alloc prefix x base =
        let name = prefix ^ "_linked" in
        let size =
          if x.vglob then sizeof x else Some e_zero
        in
        match size with
        | None -> ()
        | Some size ->
          let a = Lang.freshvar ~basename:"alloc" MemAddr.t_malloc in
          let m = e_var a in
          let base_size = p_equal (Lang.F.e_get m base) size in
          Definitions.define_lemma {
            l_kind = Admit ;
            l_name = name ;
            l_triggers = [] ; l_forall = [] ;
            l_lemma = p_forall [a] (p_imply (MemAddr.linked m) base_size) ;
            l_cluster = cluster_globals () ;
          }

      (* Specializes the lemma in Pointers below for globals *)
      let pointer_type prefix base =
        let name = prefix ^ "_is_pointer" in
        let typed =
          MemAddr.in_uintptr_range (MemAddr.global base)
        in
        Definitions.define_lemma {
          l_kind = Admit ;
          l_name = name ;
          l_triggers = [] ; l_forall = [] ;
          l_lemma = typed ;
          l_cluster = cluster_globals () ;
        }

      let compile vi =
        let result = Logic.Int in
        let acs_rd = Cil.typeHasQualifier "const" vi.vtype in
        let prefix =
          if vi.vglob
          then if acs_rd then "K" else "G"
          else if vi.vformal then "P" else "L" in
        let lfun = Lang.generated_f
            ~category:Logic.Constructor ~result:Logic.Int "%s_%s_%d"
            prefix vi.vorig_name vi.vid in
        Definitions.define_symbol {
          d_lfun = lfun ; d_types = 0 ; d_params = [ ] ;
          d_definition = Definitions.Function (result, Def, e_int vi.vid) ;
          d_cluster = cluster_globals () ;
        } ;
        let prefix = Lang.Fun.debug lfun in
        let base = e_fun lfun [] in
        RegisterBASE.define lfun vi ;
        static_alloc prefix base ;
        region prefix vi base ;
        alloc prefix vi base ;
        pointer_type prefix base ;
        base
    end)

module LITERAL =
struct
  type t = int * Cstring.cst
  let compare (a:t) (b:t) = Stdlib.compare (fst a) (fst b)
  let pretty fmt (eid,cst) = Format.fprintf fmt "%a@%d" Cstring.pretty cst eid
end

module EID = State_builder.Ref(Datatype.Int)
    (struct
      let name = datatype ^ ".EID"
      let dependencies = [Ast.self]
      let default () = 0
    end)

module STRING = WpContext.Generator(LITERAL)
    (struct
      let name = datatype ^ ".STRING"
      type key = LITERAL.t
      type data = term

      let linked prefix base cst =
        let name = prefix ^ "_linked" in
        let a = Lang.freshvar ~basename:"alloc" (Chunk.tau_of_chunk Alloc) in
        let m = e_var a in
        let alloc = Lang.F.e_get m base in (* The size is alloc-1 *)
        let sized = Cstring.str_len cst (Lang.F.(e_add alloc e_minus_one)) in
        Definitions.define_lemma {
          l_kind = Admit ;
          l_name = name ;
          l_triggers = [] ; l_forall = [] ;
          l_lemma = p_forall [a] (p_imply (MemAddr.linked m) sized) ;
          l_cluster = Cstring.cluster () ;
        }

      let region prefix base cst =
        let name = prefix ^ "_region" in
        let re = - Cstring.str_id cst in
        Definitions.define_lemma {
          l_kind = Admit ;
          l_name = name ; l_triggers = [] ; l_forall = [] ;
          l_lemma = p_equal (MemAddr.region base) (e_int re) ;
          l_cluster = Cstring.cluster () ;
        }

      let sconst prefix base cst =
        (* describe the content of literal strings *)
        let name = prefix ^ "_literal" in
        let i = Lang.freshvar ~basename:"i" Lang.t_int in
        let c = Cstring.char_at cst (e_var i) in
        let ikind = Ctypes.c_char () in
        let m = Lang.freshvar ~basename:"mchar" (Chunk.tau_of_chunk Mem) in
        let addr = shift (MemAddr.global base) (C_int ikind) (e_var i) in
        let v = load_int_raw (e_var m) ikind addr in
        let read = Lang.F.(p_equal c v) in
        Definitions.define_lemma {
          l_kind = Admit ;
          l_name = name ; l_triggers = [] ;
          l_forall = [m;i] ;
          l_cluster = Cstring.cluster () ;
          l_lemma = Lang.F.p_imply (Why3.sconst @@ e_var m) read ;
        }

      let fresh () =
        let eid = succ (EID.get ()) in
        EID.set eid ; eid

      let compile (_,cst) =
        let eid = fresh () in
        let lfun = Lang.generated_f ~result:Lang.t_int "Str_%d" eid in
        (* Since its a generated it is the unique name given *)
        let prefix = Lang.Fun.debug lfun in
        let base = Lang.F.e_fun lfun [] in
        Definitions.define_symbol {
          d_lfun = lfun ; d_types = 0 ; d_params = [] ;
          d_definition = Logic Lang.t_int ;
          d_cluster = Cstring.cluster () ;
        } ;
        Definitions.define_lemma {
          l_name = prefix ^ "_base" ;
          l_kind = Admit ;
          l_triggers = [] ; l_forall = [] ;
          l_lemma = Lang.F.(p_lt base e_zero) ;
          l_cluster = Cstring.cluster () ;
        } ;
        region prefix base cst ;
        linked prefix base cst ;
        sconst prefix base cst ;
        base

    end)

let pretty fmt loc =
  Format.fprintf fmt "l:(%a)" Lang.F.pp_term loc

let null = MemAddr.null

let literal ~eid cst =
  Wp_parameters.debug ~level:3 ~dkey:dkey_model
    "%s.literal %d _" datatype eid ;
  shift (MemAddr.global (STRING.get (eid,cst))) (C_int (Ctypes.c_char ())) e_zero

let cvar vi =
  Wp_parameters.debug ~level:3 ~dkey:dkey_model
    "%s.cvar %a" datatype Cil_printer.pp_varinfo vi ;
  MemAddr.global (BASE.get vi)

let global _sigma p =
  Wp_parameters.debug ~level:2 ~dkey:dkey_model "%s.global _ _" datatype ;
  p_leq (MemAddr.region @@ MemAddr.base p) e_zero

(* ********************************************************************** *)
(* STATE                                                                  *)
(* ********************************************************************** *)

type state = chunk Tmap.t

let rec lookup_a e =
  match repr e with
  | Fun( f , [e] ) when MemAddr.is_f_global f -> lookup_a e
  | Fun( f , es ) -> lookup_f f es
  | _ -> raise Not_found

and lookup_f f es =
  try match RegisterShift.find f , es with
    | RS_Field(fd,_) , [e] -> Mstate.field (lookup_lv e) fd
    | RS_Index _ , [e;k] -> Mstate.index (lookup_lv e) k
    | _ -> raise Not_found
  with Not_found when es = [] ->
    Sigs.(Mvar (RegisterBASE.find f),[])

and lookup_lv e = try lookup_a e with Not_found -> Sigs.(Mmem e,[])

let mchunk c =
  match c with
  | Chunk.Init -> Sigs.Mchunk (Pretty_utils.to_string Chunk.pretty c, KInit)
  | _ -> Sigs.Mchunk (Pretty_utils.to_string Chunk.pretty c, KValue)

let lookup s e =
  Wp_parameters.debug ~level:2 ~dkey:dkey_state "%s.lookup _ %a"
    datatype pp_term e ;
  try mchunk (Tmap.find e s)
  with Not_found ->
  try match repr e with
    | Fun( f , es ) -> Sigs.Maddr (lookup_f f es)
    | Aget( m , k ) when Tmap.find m s = Init ->
      Sigs.Mlval (lookup_lv k, KInit)
    | Aget( m , k ) when Tmap.find m s <> Alloc ->
      Sigs.Mlval (lookup_lv k, KValue)
    | _ -> Sigs.Mterm
  with Not_found -> Sigs.Mterm

let state sigma =
  Wp_parameters.debug ~level:2 ~dkey:dkey_state "%s.state _" datatype ;
  let s = ref Tmap.empty in
  Sigma.iter (fun c x -> s := Tmap.add (e_var x) c !s) sigma ; !s

let iter f s =
  Wp_parameters.debug ~level:2 ~dkey:dkey_state "%s.iter _ _" datatype ;
  Tmap.iter (fun m c -> f (mchunk c) m) s

let updates _ _ =
  Wp_parameters.debug ~level:2 ~dkey:dkey_state "%s.updates _ _" datatype ;
  Bag.empty

let apply f s =
  Wp_parameters.debug ~level:2 ~dkey:dkey_state "%s.apply _ _" datatype ;
  Tmap.fold (fun m c w -> Tmap.add (f m) c w) s Tmap.empty

(* ********************************************************************** *)
(* POINTERS OPS                                                           *)
(* ********************************************************************** *)

let pointer_loc t = t
let pointer_val t = t

let base_addr loc =
  Wp_parameters.debug ~level:3 ~dkey:dkey_model
    "%s.base_addr %a" datatype pretty loc ;
  MemAddr.mk_addr (MemAddr.base loc) e_zero
let base_offset loc =
  Wp_parameters.debug ~level:3 ~dkey:dkey_model
    "%s.base_offset %a" datatype pretty loc ;
  MemAddr.base_offset (MemAddr.base loc) (MemAddr.offset loc)
let block_length sigma _obj loc =
  Wp_parameters.debug ~level:3 ~dkey:dkey_model
    "%s.block_length _ _ _ " datatype ;
  e_get (Sigma.value sigma Chunk.Alloc) (MemAddr.base loc)

let cast _ loc =
  Wp_parameters.debug ~level:3 ~dkey:dkey_model
    "%s.cast _ %a" datatype pretty loc ;
  loc

let loc_of_int _ loc =
  Wp_parameters.debug ~level:3 ~dkey:dkey_model
    "%s.loc_of_int _ %a" datatype pretty loc ;
  MemAddr.addr_of_int loc

let int_of_loc _ loc =
  Wp_parameters.debug ~level:3 ~dkey:dkey_model
    "%s.int_of_loc _ %a" datatype pretty loc ;
  MemAddr.int_of_addr loc


(* -------------------------------------------------------------------------- *)

let domain _ _ = Sigma.Chunk.Set.of_list [ Init ; Mem ]

let is_null = p_equal null
let loc_eq = p_equal
let loc_lt = MemAddr.addr_lt
let loc_leq = MemAddr.addr_le
let loc_neq l1 l2 = p_not @@ loc_eq l1 l2

let loc_diff _ l1 l2 =
  let byte_size = Ctypes.sizeof_object (C_int (Ctypes.c_char ())) in
  e_div (e_sub (MemAddr.offset l1) (MemAddr.offset l2)) (e_int byte_size)

let pointer_cluster () =
  Definitions.cluster
    ~id:"MemBytes.PointersProperties" ~title:"MemBytes definitions" ()

module PointersProperties = WpContext.Generator(Datatype.Unit)
    (struct
      let name = datatype ^ ".POINTERS"
      type key = unit
      type data = Lang.lfun

      let ranges () =
        let a = Lang.freshvar ~basename:"a" MemAddr.t_addr in
        let prop = MemAddr.in_uintptr_range (e_var a) in
        Definitions.define_lemma {
          l_kind = Admit ; l_name = "pointers_int_range" ;
          l_triggers = [] ; l_forall = [a] ;
          l_cluster = pointer_cluster () ;
          l_lemma = prop ;
        }

      let compile () =
        let lfun = Lang.generated_p "framed" in
        let m = Lang.freshvar ~basename:"m" Why3.t_memory in
        let a = Lang.freshvar ~basename:"a" MemAddr.t_addr in
        let p = load_pointer_raw (e_var m) (Cil_const.voidPtrType) (e_var a) in
        let ba = MemAddr.base (e_var a) and bp = MemAddr.base p in
        let body =
          p_forall [a] @@ p_imply
            (p_leq (MemAddr.region ba) e_zero)
            (p_leq (MemAddr.region bp) e_zero)
        in
        Definitions.define_symbol {
          d_lfun = lfun ;
          d_cluster = pointer_cluster () ; d_types = 0 ;
          d_params = [ m ] ; d_definition = Predicate (Def, body)
        };
        ranges () ;
        lfun
    end)

let framed m =
  p_call (PointersProperties.get ()) [ m ]

let frame sigma =
  Wp_parameters.debug ~level:2 ~dkey:dkey_model "%s.frame _" datatype ;
  let wellformed_frame phi chunk =
    if Sigma.mem sigma chunk
    then [ phi (Sigma.value sigma chunk) ]
    else []
  in
  wellformed_frame MemAddr.linked Alloc @
  wellformed_frame Why3.cinits Init @
  wellformed_frame Why3.sconst Mem @
  [ framed (Sigma.value sigma Mem) ]

let is_well_formed s =
  Wp_parameters.debug ~level:2 ~dkey:dkey_model "%s.is_well_formed _" datatype ;
  Why3.bytes (Sigma.value s Mem)

(* ********************************************************************** *)
(* ALLOCATION                                                             *)
(* ********************************************************************** *)

let alloc sigma xs =
  Wp_parameters.debug ~level:2 ~dkey:dkey_model
    "%s.alloc %a %a"
    datatype Sigma.pretty sigma (Pretty_utils.pp_list Cil_printer.pp_varinfo) xs ;
  if xs = [] then sigma else Sigma.havoc_chunk sigma Alloc

let scope seq scope xs =
  Wp_parameters.debug ~level:2 ~dkey:dkey_model
    "%s.scope { %a ; %a } %s %a"
    datatype Sigma.pretty seq.pre Sigma.pretty seq.post
    (if scope = Sigs.Enter then "Enter" else "Leave")
    (Pretty_utils.pp_list Cil_printer.pp_varinfo) xs ;
  if xs = [] then [] else
    let alloc =
      List.fold_left
        (fun m x ->
           let size = match scope with
             | Sigs.Leave -> e_zero
             | Sigs.Enter ->
               protected_sizeof_object @@ Ctypes.object_of x.Cil_types.vtype
           in e_set m (BASE.get x) size)
        (Sigma.value seq.pre Alloc) xs in
    [ p_equal (Sigma.value seq.post Alloc) alloc ]
