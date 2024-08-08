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

open Cil_types
open Machdep

(******************************************************************************)
(*** Machine parameters                                                       *)
(******************************************************************************)

type machine = {
  mutable useLogicalOperators: bool;
  (* Whether to use the logical operands LAnd and LOr. By default, do not
      use them because they are unlike other expressions and do not
      evaluate both of their operands. *)
  mutable machdep: mach;
  (* Machine.init will set this to the current machine description. *)
  mutable lowerConstants: bool;
  (* Do lower constants (default true) *)
  mutable insertImplicitCasts: bool;
  (* Do insert implicit casts (default true) *)
  mutable stringLiteralType: typ;
  mutable upointType: typ;
  (* An unsigned integer type that fits pointers. *)
  mutable upointKind: ikind;
  (* The integer kind of {!upointType}. *)
  mutable wcharType: typ;
  (* An integer type that fits wchar_t. *)
  mutable wcharKind: ikind;
  (* The integer kind of {!wcharType}. *)
  mutable ptrdiffType: typ;
  (* An integer type that fits ptrdiff_t. *)
  mutable ptrdiffKind: ikind;
  (* The integer kind of {!ptrdiffType}. *)
  mutable typeOfSizeOf: typ;
  (* An integer type that is the type of sizeof. *)
  mutable kindOfSizeOf: ikind;
  (* The integer kind of {!typeOfSizeOf}. *)
}

(* Contain dummy values *)
let create_machine () = {
  useLogicalOperators = false;
  machdep = List.hd Machdep.reprs;
  lowerConstants = false;
  insertImplicitCasts = true;
  stringLiteralType = Cil_const.charConstPtrType;
  upointType = Cil_const.voidType;
  upointKind = IChar;
  wcharType = Cil_const.voidType;
  wcharKind = IChar;
  ptrdiffType = Cil_const.voidType;
  ptrdiffKind = IChar;
  typeOfSizeOf = Cil_const.voidType;
  kindOfSizeOf = IUInt;
}

let copy_machine src dst =
  dst.useLogicalOperators <- src.useLogicalOperators;
  dst.machdep <- src.machdep;
  dst.lowerConstants <- src.lowerConstants;
  dst.insertImplicitCasts <- src.insertImplicitCasts;
  dst.stringLiteralType <- src.stringLiteralType;
  dst.upointType <- src.upointType;
  dst.upointKind <- src.upointKind;
  dst.wcharType <- src.wcharType;
  dst.wcharKind <- src.wcharKind;
  dst.ptrdiffType <- src.ptrdiffType;
  dst.ptrdiffKind <- src.ptrdiffKind;
  dst.typeOfSizeOf <- src.typeOfSizeOf;
  dst.kindOfSizeOf <- src.kindOfSizeOf

let the_machine = create_machine ()

let use_logical_operators () = the_machine.useLogicalOperators
let get_machdep () = the_machine.machdep
let lower_constants () = the_machine.lowerConstants
let insert_implicit_casts () = the_machine.insertImplicitCasts
let string_literal_type () = the_machine.stringLiteralType
let uintptr_type () = the_machine.upointType
let uintptr_kind () = the_machine.upointKind
let ptrdiff_type () = the_machine.ptrdiffType
let ptrdiff_kind () = the_machine.ptrdiffKind
let wchar_type () = the_machine.wcharType
let wchar_kind () = the_machine.wcharKind
let sizeof_type () = the_machine.typeOfSizeOf
let sizeof_kind () = the_machine.kindOfSizeOf

(******************************************************************************)
(*** Machdep   getters                                                        *)
(******************************************************************************)

(* Sizeof *)
let sizeof_short () = the_machine.machdep.sizeof_short
let sizeof_int () = the_machine.machdep.sizeof_int
let sizeof_long () = the_machine.machdep.sizeof_long
let sizeof_longlong () = the_machine.machdep.sizeof_longlong
let sizeof_ptr () = the_machine.machdep.sizeof_ptr
let sizeof_float () = the_machine.machdep.sizeof_float
let sizeof_double () = the_machine.machdep.sizeof_double
let sizeof_longdouble () = the_machine.machdep.sizeof_longdouble
let sizeof_void () = the_machine.machdep.sizeof_void
let sizeof_fun () = the_machine.machdep.sizeof_fun

(* Names *)
let size_t () = the_machine.machdep.size_t
let ssize_t () = the_machine.machdep.ssize_t
let wchar_t () = the_machine.machdep.wchar_t
let ptrdiff_t () = the_machine.machdep.ptrdiff_t
let intptr_t () = the_machine.machdep.intptr_t
let uintptr_t () = the_machine.machdep.uintptr_t
let int_fast8_t () = the_machine.machdep.int_fast8_t
let int_fast16_t () = the_machine.machdep. int_fast16_t
let int_fast32_t () = the_machine.machdep. int_fast32_t
let int_fast64_t () = the_machine.machdep. int_fast64_t
let uint_fast8_t () = the_machine.machdep.uint_fast8_t
let uint_fast16_t () = the_machine.machdep.uint_fast16_t
let uint_fast32_t () = the_machine.machdep.uint_fast32_t
let uint_fast64_t () = the_machine.machdep.uint_fast64_t
let wint_t () = the_machine.machdep.wint_t
let sig_atomic_t () = the_machine.machdep.sig_atomic_t
let time_t () = the_machine.machdep.time_t

(* Alignof *)
let alignof_short () = the_machine.machdep.alignof_short
let alignof_int () = the_machine.machdep.alignof_int
let alignof_long () = the_machine.machdep.alignof_long
let alignof_longlong () = the_machine.machdep.alignof_longlong
let alignof_ptr () = the_machine.machdep.alignof_ptr
let alignof_float () = the_machine.machdep.alignof_float
let alignof_double () = the_machine.machdep.alignof_double
let alignof_longdouble () = the_machine.machdep.alignof_longdouble
let alignof_str () = the_machine.machdep.alignof_str
let alignof_aligned () = the_machine.machdep.alignof_aligned
let alignof_fun () = the_machine.machdep.alignof_fun

(* Misc *)
let char_is_unsigned () = the_machine.machdep.char_is_unsigned
let little_endian () = the_machine.machdep.little_endian
let has_builtin_va_list () = the_machine.machdep.has__builtin_va_list
let compiler () = the_machine.machdep.compiler
let cpp_arch_flags () = the_machine.machdep.cpp_arch_flags
let version () = the_machine.machdep.version
let machdep_name () = the_machine.machdep.machdep_name
let errno () = the_machine.machdep.errno
let custom_defs () = the_machine.machdep.custom_defs

(* Macro expansion *)
let weof () = the_machine.machdep.weof
let wordsize () = the_machine.machdep.wordsize
let posix_version () = the_machine.machdep.posix_version
let bufsiz () = the_machine.machdep.bufsiz
let eof () = the_machine.machdep.eof
let fopen_max () = the_machine.machdep.fopen_max
let filename_max () = the_machine.machdep.filename_max
let host_name_max () = the_machine.machdep.host_name_max
let tty_name_max () = the_machine.machdep.tty_name_max
let l_tmpnam () = the_machine.machdep.l_tmpnam
let path_max () = the_machine.machdep.path_max
let tmp_max () = the_machine.machdep.tmp_max
let rand_max () = the_machine.machdep.rand_max
let mb_cur_max () = the_machine.machdep.mb_cur_max
let nsig () = the_machine.machdep.nsig

let msvcMode () = msvcMode (get_machdep ())
let gccMode () = gccMode (get_machdep ())

let acceptEmptyCompinfo = ref false
let set_acceptEmptyCompinfo () = acceptEmptyCompinfo := true

let acceptEmptyCompinfo () =
  msvcMode () || gccMode () || !acceptEmptyCompinfo

let theMachineProject = ref (create_machine ())

module Machine_datatype =
  Datatype.Make
    (struct
      include Datatype.Serializable_undefined
      type t = machine
      let name = "theMachine"
      let reprs = [ the_machine ]
      let copy x =
        let m = create_machine () in
        copy_machine x m;
        m
      let mem_project = Datatype.never_any_project
    end)

module TheMachine =
  State_builder.Register
    (Machine_datatype)
    (struct
      type t = machine
      let create = create_machine
      let get () = !theMachineProject
      let set m =
        theMachineProject := m;
        copy_machine !theMachineProject the_machine
      let clear m = copy_machine (create_machine ()) m
      let clear_some_projects _ _ = false
    end)
    (struct
      let name = "theMachine"
      let unique_name = name
      let dependencies = [ Kernel.Machdep.self; Kernel.LogicalOperators.self ]
    end)

let self = TheMachine.self

let () =
  State_dependency_graph.add_dependencies
    ~from:self
    Logic_env.builtin_states

let is_computed = TheMachine.is_computed

let init_builtins_ref : (unit -> unit) ref = Extlib.mk_fun "init_builtins_ref"

let init ~initLogicBuiltins machdep =
  if not (TheMachine.is_computed ()) then begin
    (* Set the machine *)
    the_machine.machdep <- machdep;
    (* Pick type for string literals *)
    the_machine.stringLiteralType <- Cil_const.charConstPtrType;
    (* Find the right ikind given the size *)
    let findIkindSz (unsigned: bool) (sz: int) : ikind =
      (* Test the most common sizes first *)
      if sz = sizeof_int () then
        if unsigned then IUInt else IInt
      else if sz = sizeof_long () then
        if unsigned then IULong else ILong
      else if sz = 1 then
        if unsigned then IUChar else IChar
      else if sz = sizeof_short () then
        if unsigned then IUShort else IShort
      else if sz = sizeof_longlong () then
        if unsigned then IULongLong else ILongLong
      else
        Kernel.fatal ~current:true
          "Machine.init: cannot find the right ikind for size %d\n" sz
    in
    (* Find the right ikind given the name *)
    let findIkindName (name: string) : ikind =
      (* Test the most common sizes first *)
      if name = "int" then IInt
      else if name = "unsigned int" then IUInt
      else if name = "long" then ILong
      else if name = "unsigned long" then IULong
      else if name = "short" then IShort
      else if name = "unsigned short" then IUShort
      else if name = "char" then IChar
      else if name = "unsigned char" then IUChar
      else if name = "long long" then ILongLong
      else if name = "unsigned long long" then IULongLong
      else
        Kernel.fatal ~current:true
          "Machine.init: cannot find the right ikind for type %s" name
    in
    the_machine.upointKind <- findIkindSz true (sizeof_ptr ());
    the_machine.upointType <- TInt(the_machine.upointKind, []);
    the_machine.kindOfSizeOf <- findIkindName (size_t ());
    the_machine.typeOfSizeOf <- TInt(the_machine.kindOfSizeOf, []);
    the_machine.wcharKind <- findIkindName (wchar_t ());
    the_machine.wcharType <- TInt(the_machine.wcharKind, []);
    the_machine.ptrdiffKind <- findIkindName (ptrdiff_t ());
    the_machine.ptrdiffType <- TInt(the_machine.ptrdiffKind, []);
    the_machine.useLogicalOperators <- Kernel.LogicalOperators.get ();
    (* Have to be marked before calling [init*Builtins] below. *)
    TheMachine.mark_as_computed ();
    (* projectify theMachine *)
    copy_machine the_machine !theMachineProject;

    !init_builtins_ref ();

    Logic_env.Builtins.extend initLogicBuiltins;

  end

(* To be removed ideally *)
let theMachine = the_machine
