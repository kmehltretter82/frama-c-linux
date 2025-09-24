(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

open Cil_types

let add_menu
    (popup_factory:GMenu.menu GMenu.factory)
    (main_ui:Design.main_window_extension_points) localizable =
  begin
    match localizable with
    | Printer_tag.PVDecl (Some kf,_,{vglob=true}) ->
      ignore (popup_factory#add_item "Add function specification"
                ~callback:(fun () ->
                    let txt_opt =
                      GToolbox.input_string
                        ~title:"ACSL importer"
                        "  Enter an ACSL function specification to add  "
                    in
                    Option.iter
                      (fun txt ->
                         Register.paste_fun_spec
                           kf txt (Ast.get());
                         main_ui#redisplay ()) txt_opt));
      ignore
        (popup_factory#add_item "Add global annotation"
           ~callback:
             (fun () ->
                let txt_opt =
                  GToolbox.input_string
                    ~title:"ACSL importer"
                    "  Enter an ACSL annotation to add  "
                in
                Option.iter
                  (fun txt ->
                     let glob = Kernel_function.get_global kf in
                     let cfile =
                       (fst (Cil_datatype.Global.loc glob)).Filepath.pos_path
                     in
                     Register.paste_global_annot ~cfile txt (Ast.get());
                     main_ui#redisplay ()) txt_opt)) ;

    | Printer_tag.PStmt(kf,stmt) ->
      ignore
        (popup_factory#add_item "Add code annotation"
           ~callback:
             (fun () ->
                let txt_opt =
                  GToolbox.input_string
                    ~title:"ACSL importer"
                    "  Enter an ACSL annotation to add  "
                in
                Option.iter
                  (fun txt ->
                     Register.paste_code_annot kf stmt txt (Ast.get());
                     main_ui#redisplay ()) txt_opt)) ;

    | _ -> ()
  end

let select
    (popup_factory:GMenu.menu GMenu.factory)
    (main_ui:Design.main_window_extension_points)
    ~button localizable =
  match button with
  | 3 -> (* Popup Menu: *)
    add_menu  popup_factory main_ui localizable ;
  | _ -> (* Other buttons... *) ()

(* ------------------------------------------------------------------------ *)
let main main_ui =
  begin
    main_ui#register_source_selector select ;
  end

let () = Design.register_extension main

(* ------------------------------------------------------------------------ *)
