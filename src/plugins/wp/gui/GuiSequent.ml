(**************************************************************************)
(*                                                                        *)
(*  This file is part of WP plug-in of Frama-C.                           *)
(*                                                                        *)
(*  Copyright (C) 2007-2023                                               *)
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

open Conditions
open Lang.F
open WpTip
module F = Lang.F
module Env = Plang.Env
module Imap = Qed.Intmap
type 'a printer = 'a Qed.Plib.printer

(* -------------------------------------------------------------------------- *)
(* --- Term Engine                                                        --- *)
(* -------------------------------------------------------------------------- *)

class type term_selection =
  object
    method is_focused : term -> bool
    method is_visible : term -> bool
    method is_targeted : term -> bool
  end

class plang
    ~(term : term Wtext.marker)
    ~(focus : term Wtext.marker)
    ~(target : term Wtext.marker)
    (autofocus : term_selection)
  =
  object(self)
    inherit Pcond.state as super

    method! shareable e = autofocus#is_targeted e || super#shareable e

    val mutable tgt = F.e_true
    method set_target t = tgt <- t
    method clear_target = tgt <- F.e_true

    method private wrap pp fmt e =
      if e != F.e_true && e == tgt then
        target#wrap pp fmt e
      else
      if autofocus#is_focused e then
        focus#wrap pp fmt e
      else
      if F.lc_closed e then
        term#wrap pp fmt e
      else
        pp fmt e

    method! pp_at fmt lbl = Format.fprintf fmt "@{<wp:label>@@%a@}" super#pp_label lbl
    method! pp_label fmt lbl = Format.fprintf fmt "@{<wp:label>%a@}" super#pp_label lbl
    method! pp_var fmt x = Format.fprintf fmt "@{<wp:var>%s@}" x
    method! pp_flow fmt e = self#wrap super#pp_flow fmt e
    method! pp_atom fmt e = self#wrap super#pp_atom fmt e
  end

(* -------------------------------------------------------------------------- *)
(* --- Sequent Engine                                                     --- *)
(* -------------------------------------------------------------------------- *)

class type step_selection =
  object
    method is_visible : term -> bool
    method is_visible_step : step -> bool
  end

class pcond
    ~(part : part Wtext.marker)
    ~(target : part Wtext.marker)
    (focus : step_selection)
    (plang : Pcond.state) =
  object(self)
    inherit Pcond.seqengine plang as super

    (* All displayed entries *)
    val mutable domain = Vars.empty
    val mutable ellipsed = false
    val mutable parts : part Wtext.entry list = []
    val mutable tgt : part = Term (* empty *)

    (* Register displayed entries *)
    initializer part#on_add (fun entry -> parts <- entry :: parts)

    method set_target p = tgt <- p

    method part p q =
      try
        let (_,_,part) =
          List.find
            (fun (a,b,_) -> a <= p && q <= b)
            (List.rev parts)
        in part (* find the tightest step, which was added first *)
      with Not_found -> Term

    (* Step Visibility Management *)

    method visible step =
      focus#is_visible_step step ||
      match tgt with
      | Term | Goal -> false
      | Step s -> s.id = step.id

    method private domain seq =
      Conditions.iter
        (fun step ->
           if self#visible step && not (Vars.subset step.vars domain)
           then
             begin
               match step.condition with
               | State _ -> ()
               | Have p | Init p | Core p | When p | Type p ->
                 domain <- Vars.union (F.varsp p) domain
               | Branch(p,a,b) ->
                 domain <- Vars.union (F.varsp p) domain ;
                 self#domain a ; self#domain b
               | Either cs -> List.iter self#domain cs
             end
        ) seq

    (* local-variable marking ; not hover/clickable marks *)
    method! mark (m : F.marks) s = if self#visible s then super#mark m s

    method! pp_step fmt step =
      if self#visible step then
        begin
          ellipsed <- false ;
          match tgt with
          | Step { condition = State _ } -> super#pp_step fmt step
          | Step s when s == step ->
            target#mark (Step step) super#pp_step fmt step
          | _ ->
            part#mark (Step step) super#pp_step fmt step
        end
      else
        ( if not ellipsed then Format.fprintf fmt "@ [...]" ; ellipsed <- true )

    method! pp_goal fmt goal =
      match tgt with
      | Goal ->
        target#mark Goal super#pp_goal fmt goal
      | _ ->
        part#mark Goal super#pp_goal fmt goal

    method! pp_block ~clause fmt seq =
      try
        Conditions.iter
          (fun step ->
             if self#visible step then
               raise Exit)
          seq ;
        Format.fprintf fmt "@ %a { ... }" self#pp_clause clause
      with Exit ->
        begin
          ellipsed <- false ;
          super#pp_block ~clause fmt seq ;
          ellipsed <- false ;
        end

    (* Global Call *)

    method! set_sequence hyps =
      parts <- [] ;
      domain <- Vars.empty ;
      super#set_sequence hyps ;
      if self#get_state then
        begin
          self#domain hyps ;
          plang#set_domain domain ;
        end

  end

(* -------------------------------------------------------------------------- *)
(* --- Printer                                                            --- *)
(* -------------------------------------------------------------------------- *)

type target = part * F.term option

class focused (wtext : Wtext.text) =
  let parts : part Wtext.marker = wtext#marker in
  let terms : term Wtext.marker = wtext#marker in
  let focus : term Wtext.marker = wtext#marker in
  let button : (unit -> unit) Wtext.marker = wtext#marker in
  let target_term : term Wtext.marker = wtext#marker in
  let target_part : part Wtext.marker = wtext#marker in
  let autofocus = new autofocus in
  let term_selection = (autofocus :> term_selection) in
  let step_selection = (autofocus :> step_selection) in
  let plang = new plang ~term:terms ~focus:focus ~target:target_term
    term_selection in
  let pcond = new pcond ~part:parts ~target:target_part
    step_selection (plang :> Pcond.state) in
  let popup = new Widget.popup () in
  object(self)
    val mutable demon = []
    val mutable items = []
    val mutable sequent = Conditions.empty , F.p_true
    val mutable selected_term = None
    val mutable selected_part = Term
    val mutable targeted = []

    initializer
      begin
        wtext#set_font "Monospace" ;
        wtext#set_css [
          "wp:clause" , [`WEIGHT `BOLD] ;
          "wp:comment" , [`FOREGROUND "darkgreen"] ;
          "wp:property" , [`FOREGROUND "blue"] ;
          "wp:label" , [`FOREGROUND "darkgreen"] ;
          "wp:stmt" , [`WEIGHT `BOLD;`FOREGROUND "darkgreen"] ;
          "wp:var" , [`STYLE `ITALIC] ;
        ] ;
        terms#set_hover [`BACKGROUND "lightblue"] ;
        parts#set_hover [`BACKGROUND "lightgreen"] ;
        focus#set_style [`BACKGROUND "wheat"] ;
        button#set_style [`BACKGROUND "lightblue" ];
        button#set_hover [`BACKGROUND "orange" ];
        button#on_click (fun (_,_,cb) -> cb ()) ;
        target_part#set_style [`BACKGROUND "orange"] ;
        target_term#set_style [`BACKGROUND "orange"] ;
        parts#on_click self#on_part ;
        parts#on_right_click self#on_popup_part ;
        terms#on_click (self#on_term ~extend:false) ;
        terms#on_shift_click (self#on_term ~extend:true) ;
        terms#on_right_click self#on_popup_term ;
        focus#on_click self#on_select ;
        focus#on_right_click self#on_popup_term ;
        target_part#on_right_click self#on_popup_part ;
        target_term#on_right_click self#on_popup_term ;
        target_part#on_add (fun (p,q,_) -> self#added_zone p q) ;
        target_term#on_add (fun (p,q,_) -> self#added_zone p q) ;
      end

    method reset =
      selected_term <- None ;
      selected_part <- Term ;
      targeted <- [] ;
      autofocus#reset

    method private added_zone p q = targeted <- (p,q) :: targeted
    method private target_zone =
      try
        List.find
          (fun (p,q) ->
             match selected_part , pcond#part p q with
             | Goal , Goal -> true
             | Step s , Step s' -> s.id = s'.id
             | _ -> false
          ) targeted
      with Not_found -> 0,0

    method get_focus_mode = autofocus#get_autofocus
    method set_focus_mode = autofocus#set_autofocus

    method get_state_mode = pcond#get_state
    method set_state_mode = pcond#set_state

    method set_iformat = plang#set_iformat
    method get_iformat = plang#get_iformat

    method set_rformat = plang#set_rformat
    method get_rformat = plang#get_rformat

    method selected =
      begin
        self#set_target self#selection ;
        List.iter (fun f -> f ()) demon ;
      end

    method on_selection f =
      demon <- demon @ [f]

    method on_popup (f : Widget.popup -> unit) =
      items <- items @ [f]

    method private item ~label ~callback =
      let callback () = let () = callback () in self#selected in
      popup#add_item ~label ~callback

    method private popup_term e =
      match autofocus#get_term e with
      | `Auto ->
        begin
          if autofocus#is_focused e then
            self#item ~label:"Un-focus Term"
              ~callback:(fun () -> autofocus#unfocus e) ;
          self#item ~label:"Hide Term"
            ~callback:(fun () -> autofocus#set_term e `Hidden) ;
          self#item ~label:"Don't Share"
            ~callback:(fun () -> autofocus#set_term e `Visible) ;
        end
      | `Hidden ->
        self#item ~label:"Show Term"
          ~callback:(fun () -> autofocus#set_term e `Auto)
      | `Visible | `Name _ | `Shared ->
        self#item ~label:"Autofocus"
          ~callback:(fun () -> autofocus#set_term e `Auto)

    method private popup_part = function
      | Goal | Term ->
        self#item
          ~label:"Reset Autofocus"
          ~callback:(fun () -> autofocus#reset)
      | Step step ->
        if autofocus#is_visible_step step then
          self#item ~label:"Hide Clause"
            ~callback:(fun () -> autofocus#set_step step `Hidden)
        else
          self#item ~label:"Show Clause"
            ~callback:(fun () -> autofocus#set_step step `Visible)

    method popup =
      begin
        popup#clear ;
        begin match selected_term with
          | Some e -> self#popup_term e
          | None -> self#popup_part selected_part
        end ;
        popup#add_separator ;
        List.iter (fun f -> f popup) items ;
        popup#run () ;
      end

    method selection =
      let inside clause t =
        if F.p_bool t == Tactical.head clause
        then Tactical.(Clause clause)
        else Tactical.(Inside(clause,t))
      in
      match selected_part , selected_term with
      | Term , None -> Tactical.Empty
      | Goal , None -> Tactical.(Clause(Goal(snd sequent)))
      | Step s , None -> Tactical.(Clause(Step s))
      | Term , Some t -> autofocus#locate t
      | Goal , Some t -> inside Tactical.(Goal (snd sequent)) t
      | Step s , Some t -> inside Tactical.(Step s) t

    method unselect =
      begin
        let p = selected_part in selected_part <- Term ;
        let t = selected_term in selected_term <- None ;
        autofocus#unfocus_last ;
        p,t
      end

    method restore (p,t) =
      begin
        selected_part <- p ;
        selected_term <- t ;
        self#set_target self#selection ;
      end

    method set_target tgt =
      match tgt with
      | Tactical.Empty | Tactical.Compose _ | Tactical.Multi _ ->
        begin
          pcond#set_target Term ;
          plang#clear_target ;
          autofocus#clear_target ;
        end
      | Tactical.Inside (_,t) ->
        begin
          pcond#set_target Term ;
          plang#set_target t ;
          autofocus#set_target t ;
        end
      | Tactical.Clause (Tactical.Goal _) ->
        begin
          pcond#set_target Goal ;
          plang#clear_target ;
          autofocus#clear_target ;
        end
      | Tactical.Clause (Tactical.Step s) ->
        begin
          pcond#set_target (Step s) ;
          plang#clear_target ;
          autofocus#clear_target ;
        end

    method private on_term ~extend (p,q,e) =
      if F.lc_closed e then (* defensive *)
        begin
          selected_term <- Some e ;
          selected_part <- pcond#part p q ;
          autofocus#focus ~extend e ;
          self#selected ;
        end

    method private on_select (p,q,e) =
      if F.lc_closed e then (* defensive *)
        begin
          selected_term <- Some e ;
          selected_part <- pcond#part p q ;
          self#selected ;
        end

    method private on_part (_,_,part) =
      begin
        selected_term <- None ;
        selected_part <- part ;
        autofocus#reset ;
        self#selected ;
      end

    method private on_popup_term (p,q,e) =
      if F.lc_closed e then (* defensive *)
        begin
          selected_term <- Some e;
          selected_part <- pcond#part p q ;
          self#popup ;
        end

    method private on_popup_part (_,_,part) =
      begin
        selected_term <- None ;
        selected_part <- part ;
        self#popup ;
      end

    method pp_term fmt e = plang#pp_sort fmt e
    method pp_pred fmt p = plang#pp_pred fmt p

    method pp_selection fmt = function
      | Tactical.Empty -> Format.fprintf fmt " - "
      | Tactical.Compose(Tactical.Range(a,b)) ->
        Format.fprintf fmt "%d..%d" a b
      | sel -> self#pp_term fmt (Tactical.selected sel)

    method sequent = sequent

    method pp_sequent s fmt =
      sequent <- s ;
      if autofocus#set_sequent s then
        begin
          selected_term <- None ;
          selected_part <- Term ;
        end ;
      targeted <- [] ;
      let env = autofocus#env in
      if pcond#get_state then Env.set_indexed_vars env ;
      pcond#pp_esequent env fmt s ;
      let p,q = self#target_zone in
      if p > 0 && q > p then
        (Wutil.later (fun () -> wtext#select ~scroll:true p q))

    method goal w fmt =
      let open Wpo in
      match w.po_formula with
      | GoalLemma _ ->
        Format.fprintf fmt "@\n@{<wp:clause>Lemma@} %a:@\n" Wpo.pp_title w ;
        let _,sequent = Wpo.compute w in
        self#pp_sequent sequent fmt
      | GoalAnnot _ ->
        Format.fprintf fmt "@\n@{<wp:clause>Goal@} %a:@\n" Wpo.pp_title w ;
        let _,sequent = Wpo.compute w in
        self#pp_sequent sequent fmt

    method button ~title ~callback fmt =
      let pp_title fmt title = Format.fprintf fmt " %s " title in
      Format.fprintf fmt "[%a]" (button#mark callback pp_title) title

  end
