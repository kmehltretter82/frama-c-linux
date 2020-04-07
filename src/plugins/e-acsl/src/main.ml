(**************************************************************************)
(*                                                                        *)
(*  This file is part of the Frama-C's E-ACSL plug-in.                    *)
(*                                                                        *)
(*  Copyright (C) 2012-2020                                               *)
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

let check () = assert false (* [TODO ARCHI] kill check *)

let check =
  Dynamic.register
    ~plugin:"e-acsl"
    ~journalize:true
    "check"
    (Datatype.func Datatype.unit Datatype.bool)
    check

module Resulting_projects =
  State_builder.Hashtbl
    (Datatype.String.Hashtbl)
    (Project.Datatype)
    (struct
      let name = "E-ACSL resulting projects"
      let size = 7
      let dependencies = Ast.self :: Options.parameter_states
    end)

let () =
  State_dependency_graph.add_dependencies
    ~from:Resulting_projects.self
    [ Label.self ]

let generate_code =
  Resulting_projects.memo
    (fun name ->
       Options.feedback "beginning translation.";
       Temporal.enable (Options.Temporal_validity.get ());
       let rtl_prj =
         Project.create_by_copy ~last:false "E_ACSL RTL"
       in
       if Plugin.is_present "variadic" then begin
         let opt_name = "-variadic-translation" in
         if Dynamic.Parameter.Bool.get opt_name () then begin
           if Ast.is_computed () then
             Options.abort
               "The variadic translation must be turned off for E-ACSL. \
                Please use option '-variadic-no-translation'";
           Options.warning "deactivating variadic translation";
           Dynamic.Parameter.Bool.off opt_name ();
         end
       end;
       Ast.compute ();
       let copied_prj = Project.create_by_copy ~last:true name in
       Project.on
         copied_prj
         (fun () ->
            (* preparation of the AST does not concern the E-ACSL RTL *)
            Prepare_ast.prepare ();
            Rtl.link rtl_prj;
            Injector.inject ();
            (* remove the RTE's results computed from E-ACSL: they are partial
               and associated with the wrong kernel function (the one of the old
               project). *)
            (* [TODO ARCHI] what if RTE was already computed? *)
            let selection =
              State_selection.union
                (State_selection.with_dependencies !Db.RteGen.self)
                (State_selection.with_dependencies Options.Run.self)
            in
            Project.clear ~selection ~project:copied_prj ();
            Resulting_projects.mark_as_computed ())
         ();
       Options.feedback "translation done in project \"%s\"."
         (Options.Project_name.get ());
       copied_prj)

let generate_code =
  Dynamic.register
    ~plugin:"E_ACSL"
    ~journalize:true
    "generate_code"
    (Datatype.func Datatype.string Project.ty)
    generate_code

let predicate_to_exp =
  Dynamic.register
    ~plugin:"E_ACSL"
    ~journalize:false
    "predicate_to_exp"
    (Datatype.func2
       Kernel_function.ty Cil_datatype.Predicate.ty Cil_datatype.Exp.ty)
    Translate.predicate_to_exp

(* The Frama-C standard library contains specific built-in variables prefixed by
   "__fc_" and declared as extern: they prevent the generated code to be
   linked. This modification of the default printer replaces them by their
   original version from the stdlib. For instance, [__fc_stdout] is replaced by
   [stdout]. That is very hackish since it modifies the default Frama-C
   printer.

   TODO: should be done by the Frama-C default printer at some points. *)
let change_printer =
  (* not projectified on purpose: this printer change is common to each
     project. *)
  let first = ref true in
  fun () ->
    if !first then begin
      first := false;
      let r = Str.regexp "^__fc_" in
      let module Printer_class(X: Printer.PrinterClass) = struct
        class printer = object
          inherit X.printer as super

          method !varinfo fmt vi =
            if Functions.Libc.is_vla_alloc_name vi.Cil_types.vname then
              (* Replace VLA allocation with calls to [__builtin_alloca] *)
              Format.fprintf fmt "%s" Functions.Libc.actual_alloca
            else if (not vi.vghost) && vi.vstorage == Cil_types.Extern then
              (* Replace calls to Frama-C builtins with calls to their original
                 version from the libc *)
              let s = Str.replace_first r "" vi.Cil_types.vname in
              Format.fprintf fmt "%s" s
            else
              (* Otherwise use the original printer *)
              super#varinfo fmt vi

          method !instr fmt i =
            match i with
            | Call(_, fct, _, _) when Functions.Libc.is_vla_free fct ->
              (* Nothing to print: VLA deallocation is done automatically when
                 leaving the scope *)
              Format.fprintf fmt "/* ";
              super#instr fmt i;
              Format.fprintf fmt " */"
            | _ ->
              super#instr fmt i

          method !global fmt g =
            let is_vla_builtin vi =
              Functions.Libc.is_vla_alloc_name vi.Cil_types.vname ||
              Functions.Libc.is_vla_free_name vi.Cil_types.vname
            in
            match g with
            | GFunDecl (_, vi, _) when is_vla_builtin vi ->
              (* Nothing to print: the VLA builtins don't have an original libc
                 version. *)
              ()
            | _ ->
              super#global fmt g
        end
      end in
      Printer.update_printer (module Printer_class: Printer.PrinterExtension)
    end

let main () =
  Keep_status.clear ();
  if Options.Run.get () then begin
    change_printer ();
    ignore (generate_code (Options.Project_name.get ()));
  end

let () = Db.Main.extend main

(*
Local Variables:
compile-command: "make -C ../../../.."
End:
*)
