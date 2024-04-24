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

open Conditions
open Lang.F
open Ptip
module F = Lang.F
module Env = Plang.Env
module Imap = Qed.Intmap

(* -------------------------------------------------------------------------- *)
(* --- Printer                                                            --- *)
(* -------------------------------------------------------------------------- *)

class focused (wtext : Wtext.text) =
  let parts : part Wtext.marker = wtext#marker in
  let terms : term Wtext.marker = wtext#marker in
  let focus : term Wtext.marker = wtext#marker in
  let button : (unit -> unit) Wtext.marker = wtext#marker in
  let target : term Wtext.marker = wtext#marker in
  let target_part : part Wtext.marker = wtext#marker in
  let autofocus = new autofocus in
  let plang = new plang ~terms ~focus ~target ~autofocus in
  let pcond = new pcond ~parts ~target:target_part ~autofocus ~plang in
  let popup = new Widget.popup () in
  object(self)
    inherit pseq ~autofocus ~plang ~pcond as super
    val mutable items = []
    val mutable targeted = []
    val mutable allparts : part Wtext.entry list = []

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
        target#set_style [`BACKGROUND "orange"] ;
        parts#on_click self#on_part ;
        parts#on_right_click self#on_popup_part ;
        terms#on_click (self#on_term ~extend:false) ;
        terms#on_shift_click (self#on_term ~extend:true) ;
        terms#on_right_click self#on_popup_term ;
        focus#on_click self#on_select ;
        focus#on_right_click self#on_popup_term ;
        target_part#on_right_click self#on_popup_part ;
        target#on_right_click self#on_popup_term ;
        target_part#on_add (fun (p,q,_) -> self#added_zone p q) ;
        target#on_add (fun (p,q,_) -> self#added_zone p q) ;
        parts#on_add (fun entry -> allparts <- entry :: allparts)

      end

    method! reset = super#reset ; targeted <- []

    method private part p q =
      try
        let (_,_,part) =
          List.find
            (fun (a,b,_) -> a <= p && q <= b)
            (List.rev allparts)
        in part (* find the tightest step, which was added first *)
      with Not_found -> Term

    method private added_zone p q = targeted <- (p,q) :: targeted
    method private target_zone =
      try
        let selected_part, _ = self#target in
        List.find
          (fun (p,q) ->
             match selected_part , self#part p q with
             | Goal , Goal -> true
             | Step s , Step s' -> s.id = s'.id
             | _ -> false
          ) targeted
      with Not_found -> 0,0

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
        let part , term = self#target in
        begin match term with
          | Some e -> self#popup_term e
          | None -> self#popup_part part
        end ;
        popup#add_separator ;
        List.iter (fun f -> f popup) items ;
        popup#run () ;
      end

    method private on_term ~extend (p,q,e) =
      if F.lc_closed e then (* defensive *)
        begin
          let part = self#part p q in
          let focus = if extend then `Extend else `Focus in
          self#restore ~focus (part,Some e)
        end

    method private on_select (p,q,e) =
      if F.lc_closed e then (* defensive *)
        begin
          let part = self#part p q in
          self#restore ~focus:`Select (part,Some e) ;
        end

    method private on_part (_,_,part) =
      begin
        self#restore ~focus:`Reset (part,None)
      end

    method private on_popup_term (p,q,e) =
      if F.lc_closed e then (* defensive *)
        begin
          let part = self#part p q in
          self#restore ~focus:`Transient (part,Some e) ;
          self#popup ;
        end

    method private on_popup_part (_,_,part) =
      begin
        self#restore ~focus:`Transient (part,None) ;
        self#popup ;
      end

    method! pp_sequent fmt s =
      allparts <- [] ;
      targeted <- [] ;
      super#pp_sequent fmt s ;
      let p,q = self#target_zone in
      if p > 0 && q > p then
        (Wutil.later (fun () -> wtext#select ~scroll:true p q))

    method button ~title ~callback fmt =
      let pp_title fmt title = Format.fprintf fmt " %s " title in
      Format.fprintf fmt "[%a]" (button#mark callback pp_title) title

  end
