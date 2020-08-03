(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2020                                               *)
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

(*
- Permet l'utilisation des lval là où il faut des expression (sous typage)
- Construit de la même manière le C et la logique
- Pas nécessaire de renseigner la location partout
- Interface unifiée vers les smart constructors
*)

module Type :
sig
  type ('value,'shape) typ

  val typ : Cil_types.typ -> ('v,'v) typ
  val void : ('v,'v) typ
  val bool : ('v,'v) typ
  val char : ('v,'v) typ
  val schar : ('v,'v) typ
  val uchar : ('v,'v) typ
  val int : ('v,'v) typ
  val unit : ('v,'v) typ
  val short : ('v,'v) typ
  val ushort : ('v,'v) typ
  val long : ('v,'v) typ
  val ulong : ('v,'v) typ
  val longlong : ('v,'v) typ
  val ulonglong : ('v,'v) typ
  val float : ('v,'v) typ
  val double : ('v,'v) typ
  val longdouble : ('v,'v) typ

  val ptr : ('v,'s) typ -> ('v,'v) typ
  val array : ?size:int -> ('v,'s) typ -> ('v,'s list) typ

  val attribute : ('v,'s) typ -> string -> Cil_types.attrparam list
    -> ('v,'s) typ
  val const : ('v,'s) typ -> ('v,'s) typ
  val stdlib_generated : ('v,'s) typ -> ('v,'s) typ

  val cil_typ : ('v,'s) typ -> Cil_types.typ
end


(* --- C & Logic expressions builder --- *)

module Exp :
sig
  include module type of Type

  type const'
  type var'
  type lval'
  type exp'
  type init'

  type const = [ `const of const' ]
  type var = [ `var of var' ]
  type lval = [  var | `lval of lval' ]
  type exp = [ const | lval | `exp of exp' ]
  type init = [ exp | `init of init']

  (* Build Constants *)

  val constant : Cil_types.constant -> [> const]
  val int : int -> [> const]
  val integer : Integer.t -> [> const]
  val zero : [> const]
  val one : [> const]

  (* Build LValues *)

  val var : Cil_types.varinfo -> [> var]
  val lval : Cil_types.lval -> [> lval]

  (* Build Expressions *)

  val exp : Cil_types.exp -> [> exp]
  val exp_copy : Cil_types.exp -> [> exp]
  val unop : Cil_types.unop -> [< exp] -> [> exp]
  val neg : [< exp] -> [> exp]
  val lognot : [< exp] -> [> exp]
  val bwnot : [< exp] -> [> exp]
  val succ : [< exp] -> [> exp] (* e + 1 *)
  val increment : [< exp] -> int -> [> exp] (* e + i *)
  val binop : Cil_types.binop -> [< exp] -> [< exp] -> [> exp]
  val add : [< exp] -> [< exp] -> [> exp]
  val sub : [< exp] -> [< exp] -> [> exp]
  val mul : [< exp] -> [< exp] -> [> exp]
  val div : [< exp] -> [< exp] -> [> exp]
  val modulo : [< exp] -> [< exp] -> [> exp]
  val shiftl : [< exp] -> [< exp] -> [> exp]
  val shiftr : [< exp] -> [< exp] -> [> exp]
  val lt : [< exp] -> [< exp] -> [> exp]
  val gt : [< exp] -> [< exp] -> [> exp]
  val le : [< exp] -> [< exp] -> [> exp]
  val ge : [< exp] -> [< exp] -> [> exp]
  val eq : [< exp] -> [< exp] -> [> exp]
  val ne : [< exp] -> [< exp] -> [> exp]
  val logor : [< exp] -> [< exp] -> [> exp]
  val logand : [< exp] -> [< exp] -> [> exp]
  val bwand : [< exp] -> [< exp] -> [> exp]
  val bwor : [< exp] -> [< exp] -> [> exp]
  val bwxor : [< exp] -> [< exp] -> [> exp]
  val cast : ('v,'s) typ -> [< exp] -> [> exp]
  val cast' : Cil_types.typ -> [< exp] -> [> exp]
  val addr : [< lval] -> [> exp]
  val mem : [< exp] -> [> lval]
  val field : [< lval] -> Cil_types.fieldinfo -> [> lval]
  val fieldnamed : [< lval] -> string -> [> lval]
  val result : [> lval]
  val term : Cil_types.term -> [> exp]
  val none : [> `none]
  val range :  [< exp | `none] -> [< exp | `none] -> [> exp]
  val whole : [> exp] (* Whole range, i.e. .. *)
  val whole_right : [> exp] (* Whole range right side, i.e. 0.. *)
  val init : Cil_types.init -> [> init]
  val compound : Cil_types.typ -> init list -> [> init]
  val values : (init,'values) typ -> 'values -> init

  exception EmptyList

  val logor_list : [< exp] list -> exp
  val logand_list : [< exp] list -> exp

  (* Redefined operators *)

  val (+) : [< exp] -> [< exp] -> [> exp]
  val (-) : [< exp] -> [< exp] -> [> exp]
  val ( * ) : [< exp] -> [< exp] -> [> exp]
  val (/) : [< exp] -> [< exp] -> [> exp]
  val (%) : [< exp] -> [< exp] -> [> exp]
  val (<<) : [< exp] -> [< exp] -> [> exp]
  val (>>) : [< exp] -> [< exp] -> [> exp]
  val (<) : [< exp] -> [< exp] -> [> exp]
  val (>) : [< exp] -> [< exp] -> [> exp]
  val (<=) : [< exp] -> [< exp] -> [> exp]
  val (>=) : [< exp] -> [< exp] -> [> exp]
  val (==) : [< exp] -> [< exp] -> [> exp]
  val (!=) : [< exp] -> [< exp] -> [> exp]

  (* Export CIL objects from built expressions *)

  exception LogicInC
  exception CInLogic
  exception Typing_error of string

  val cil_constant : [< const] -> Cil_types.constant
  val cil_varinfo : [< var] -> Cil_types.varinfo
  val cil_lval : loc:Cil_types.location -> [< lval] -> Cil_types.lval
  val cil_exp : loc:Cil_types.location -> [< exp] -> Cil_types.exp
  val cil_term_lval : loc:Cil_types.location -> restyp:Cil_types.typ ->
    [< lval] -> Cil_types.term_lval
  val cil_term : loc:Cil_types.location -> restyp:Cil_types.typ ->
    [< exp] -> Cil_types.term
  val cil_init : loc:Cil_types.location -> [< init] -> Cil_types.init
end


(* --- Pure builder --- *)

module Pure :
sig
  include module type of Exp

  type instr'
  type stmt'

  type instr = [ `instr of instr' ]
  type stmt = [ instr | `stmt of stmt' ]

  val instr : Cil_types.instr -> [> instr]
  val skip : [> instr]
  val assign : [< lval] -> [< exp] -> [> instr]
  val incr : [< lval] -> [> instr]
  val call : [< lval | `none] -> [< exp] -> [< exp] list -> [> instr]
  val stmtkind : Cil_types.stmtkind -> [> stmt]
  val stmt : Cil_types.stmt -> [> stmt]
  val stmts : Cil_types.stmt list -> [> stmt]
  val block : [< stmt] list -> [> stmt]
  val ghost : [< stmt] -> [> stmt]

  val cil_instr : loc:Cil_types.location -> instr -> Cil_types.instr
  val cil_stmtkind : loc:Cil_types.location -> stmt -> Cil_types.stmtkind
  val cil_stmt : loc:Cil_types.location -> stmt -> Cil_types.stmt
end


(* --- Stateful builder --- *)

exception WrongContext of string

module type T =
sig
  val loc : Cil_types.location
end

module Stateful (Location : T) :
sig
  include module type of Exp

  (* Statements *)
  val instr : Cil_types.instr -> unit
  val stmtkind : Cil_types.stmtkind -> unit
  val stmt : Cil_types.stmt -> unit
  val stmts : Cil_types.stmt list -> unit
  val open_function : ?ghost:bool -> string -> [> var]
  val open_block : unit -> unit
  val open_ghost : unit -> unit
  val open_switch : [< exp] -> unit
  val open_if : [< exp] -> unit
  val open_else : unit -> unit
  val close : unit -> unit
  val finish_block : unit -> Cil_types.block
  val finish_stmt : unit -> Cil_types.stmt
  val finish_function : ?register:bool -> unit -> Cil_types.global
  val case : [< exp] -> unit
  val break : unit -> unit
  val return : [< exp | `none] -> unit
  val assign : [< lval] -> [< exp] -> unit
  val incr : [< lval] -> unit
  val call : [< lval | `none] -> [< exp] -> [< exp] list -> unit

  (* Variables *)
  val return_type : Cil_types.typ -> unit
  val local : ?ghost:bool -> ?init:'v -> (init,'v) typ -> string -> [> var]
  val local' : ?ghost:bool -> ?init:init -> Cil_types.typ -> string -> [> var]
  val local_copy : ?ghost:bool -> ?suffix:string -> [< var] -> [> var]
  val parameter : ?ghost:bool -> ?attributes:Cil_types.attributes ->
    Cil_types.typ -> string -> [> var]
end
