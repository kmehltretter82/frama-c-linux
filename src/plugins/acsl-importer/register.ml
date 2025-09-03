(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

(** {1 API [ACSL_importer.paste_global_annot].} *)

let paste_global_annot pfile pline cfile s ast =
  A2fcPaste.paste_global_annot ~pfile ~pline ~cfile s ast
let paste_global_annot =
  Dynamic.register
    ~plugin:"ACSL_importer"
    "paste_global_annot"
    (Datatype.func
       ~label:("pfile",None) Datatype.string
       (Datatype.func
          ~label:("pline",None) Datatype.int
          (Datatype.func
             ~label:("cfile",None) Filepath.ty
             (Datatype.func
                Datatype.string
                (Datatype.func
                   Cil_datatype.File.ty
                   Datatype.unit)))))
    paste_global_annot

let paste_global_annot
    ?(pfile="ACSL-importer-buffer") ?(pline=1) ?(cfile=Filepath.empty)
    s ast =
  paste_global_annot pfile pline cfile s ast

(** {1 API [ACSL_importer.paste_fun_spec].} *)

let paste_fun_spec kf pfile pline cfile s ast =
  A2fcPaste.paste_fun_spec kf ~pfile ~pline ~cfile s ast
let paste_fun_spec =
  Dynamic.register
    ~plugin:"ACSL_importer"
    "paste_fun_spec"
    (Datatype.func
       Kernel_function.ty
       (Datatype.func
          ~label:("pfile",None) Datatype.string
          (Datatype.func
             ~label:("pline",None) Datatype.int
             (Datatype.func
                ~label:("cfile",None) Filepath.ty
                (Datatype.func
                   Datatype.string
                   (Datatype.func
                      Cil_datatype.File.ty
                      Datatype.unit))))))
    paste_fun_spec

let get_cfile kf =
  let glob = Kernel_function.get_global kf in
  let file = (fst (Cil_datatype.Global.loc glob)).Filepath.pos_path in
  file

let paste_fun_spec
    kf ?(pfile="ACSL-importer-buffer") ?(pline=1) ?(cfile=(get_cfile kf))
    s ast =
  paste_fun_spec kf pfile pline cfile s ast

(** {1 API [ACSL_importer.paste_code_annot].} *)

let paste_code_annot kf stmt pfile pline cfile s ast =
  A2fcPaste.paste_code_annot kf stmt ~pfile ~pline ~cfile s ast

let paste_code_annot =
  Dynamic.register
    ~plugin:"ACSL_importer"
    "paste_code_annot"
    (Datatype.func
       Kernel_function.ty
       (Datatype.func
          Cil_datatype.Stmt.ty
          (Datatype.func
             ~label:("pfile",None) Datatype.string
             (Datatype.func
                ~label:("pline",None) Datatype.int
                (Datatype.func
                   ~label:("cfile",None) Filepath.ty
                   (Datatype.func
                      Datatype.string
                      (Datatype.func
                         Cil_datatype.File.ty
                         Datatype.unit)))))))
    paste_code_annot

let paste_code_annot
    kf stmt ?(pfile="ACSL-importer-buffer")
    ?(pline=1) ?(cfile=(get_cfile kf)) s ast =
  paste_code_annot kf stmt pfile pline cfile s ast

(** {1 API [ACSL_importer.import].} *)

(** Import process. *)
let import ~iDir ast nb pfile =
  A2fcImport.import ~iDir ~pfile ~init_typenames:(nb==0) ast ;
  nb+1

let import iDir files ast =
  if not (files = []) then
    begin
      let close_importation () =
        A2fcPaste.SymbolIndex.clear_temporary_table () ;
        Logic_env.reset_typenames ();
        (* importation may put additional dependencies between globals.
             Just ask for a reordering at the end of the process.
        *)
        File.reorder_custom_ast ast
        (* File.pretty_ast () *)
      in
      (*        try *)
      let nb = List.fold_left (import ~iDir ast) 0 files in
      close_importation () ;
      (*        with e ->
                  close_importation () ;
                  raise e *)
      A2fcParameter.feedback "Done: %d file%s.@."
        nb
        (if nb > 1 then "s" else "")
    end

let import files1 files2 ast =
  import
    (A2fcParameter.ACSLIdir.get ())
    (files1 @ (A2fcParameter.ACSLImport.get ()) @ files2)
    ast;
  A2fcParameter.set_importation_off ()

let import =
  Dynamic.register
    ~plugin:"ACSL_importer"
    "import"
    (Datatype.func (Datatype.list Datatype.string)
       (Datatype.func (Datatype.list Datatype.string)
          (Datatype.func Cil_datatype.File.ty Datatype.unit)))
    import

(** {1 API [ACSL_importer.import_from_cmdline].} *)

(** Import from the cmdline process. *)
let import_from_cmdline ast =
  A2fcParameter.feedback ~level:2 "Importing..." ;
  import [] [] ast;
  A2fcParameter.set_importation_off ()

let import_from_cmdline =
  Dynamic.register
    ~plugin:"ACSL_importer"
    "import_from_cmdline"
    (Datatype.func Cil_datatype.File.ty Datatype.unit)
    import_from_cmdline

(** {1 API [ACSL_importer.main].} *)

let dkey = A2fcParameter.register_category "trace-job"

(** The main entry point. *)
let main ast =
  A2fcParameter.debug ~level:2 ~dkey "Start ACSL_importer plugin...@." ;
  if A2fcParameter.is_importation_on () then import_from_cmdline ast ;
  A2fcParameter.debug ~level:2 ~dkey "Stop ACSL_importer plugin...@."

(** Register the function [main] as a main entry point. *)
let () =
  let main =
    Dynamic.register
      ~plugin:"ACSL_importer"
      "main"
      (Datatype.func Cil_datatype.File.ty Datatype.unit)
      main
  in
  File.add_code_transformation_after_cleanup
    ~deps:[(module A2fcParameter.ACSLImport:Parameter_sig.S);
           (module A2fcParameter.ACSLRun:Parameter_sig.S)]
    ~before:[Unfold_loops.transform] A2fcParameter.main_import main
