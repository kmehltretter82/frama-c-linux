(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

open Printer_tag
open Gtk_helper
open Cil_types

module Make_HighlighterState(Info:sig val name: string end) =
  State_builder.List_ref
    (Cil_datatype.Stmt)
    (struct
      let name = Info.name
      let dependencies = [ Ast.self ]
    end)

module ForwardHighlighterState =
  Make_HighlighterState(struct let name = "Security_gui.Forward" end)

module IndirectBackwardHighlighterState =
  Make_HighlighterState(struct let name = "Security_gui.Indirectb" end)

module DirectHighlighterState =
  Make_HighlighterState(struct let name = "Security_gui.Direct" end)

let security_highlighter buffer loc ~start ~stop =
  let buffer = buffer#buffer in
  match loc with
  | PStmt (_,s) ->
    let f = ForwardHighlighterState.get () in
    if List.exists (fun k -> k.sid=s.sid) f then begin
      let tag = make_tag buffer ~name:"forward" [`BACKGROUND "orange" ] in
      apply_tag buffer tag start stop end;
    let i = IndirectBackwardHighlighterState.get () in
    if List.exists (fun k -> k.sid=s.sid) i then begin
      let tag = make_tag buffer ~name:"indirect_backward" [`BACKGROUND  "cyan" ] in
      apply_tag buffer tag start stop end;
    let d = DirectHighlighterState.get () in
    if List.exists (fun k -> k.sid=s.sid) d then begin
      let tag = make_tag buffer ~name:"direct" [`BACKGROUND  "green" ] in
      apply_tag buffer tag start stop end
  | PStmtStart _
  | PExp _ | PVDecl _ | PTermLval _ | PLval _ | PGlobal _ | PIP _
  | PType _ -> ()

let security_selector
    (popup_factory:GMenu.menu GMenu.factory) main_ui ~button localizable =
  if button = 3 && Security_slicing_parameters.Slicing.get () then
    match localizable with
    | PStmt (_kf, ki) ->
      ignore
        (popup_factory#add_item "_Security component"
           ~callback:
             (fun () ->
                ForwardHighlighterState.set
                  (Components.get_forward_component ki);
                IndirectBackwardHighlighterState.set
                  (Components.get_indirect_backward_component ki);
                DirectHighlighterState.set
                  (Components.get_direct_component ki);
                main_ui#rehighlight ()))
    | _ -> ()

let main main_ui =
  main_ui#register_source_selector security_selector;
  main_ui#register_source_highlighter security_highlighter

let () = Design.register_extension main
