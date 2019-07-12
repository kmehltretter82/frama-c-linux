(**************************************************************************)
(*                                                                        *)
(*  This file is part of WP plug-in of Frama-C.                           *)
(*                                                                        *)
(*  Copyright (C) 2007-2019                                               *)
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

(* ------------------------------------------------------------------------ *)
(* ---  Prover List in Configuration                                    --- *)
(* ------------------------------------------------------------------------ *)

class enabled key =
  object(self)
    inherit [Why3.Whyconf.Sprover.t] Wutil.selector Why3.Whyconf.Sprover.empty

    method private load () =
      let open Gtk_helper.Configuration in
      let prover_of_conf acc = function
        | ConfList [ConfString prover_name;
                    ConfString prover_version;
                    ConfString prover_altern] ->
            Why3.Whyconf.Sprover.add
              Why3.Whyconf.{ prover_name; prover_version; prover_altern }
              acc
        | _ -> acc in
      try
        let data = Gtk_helper.Configuration.find key in
        match data with
        | ConfList data ->
            (List.fold_left prover_of_conf Why3.Whyconf.Sprover.empty data)
        | _ -> Why3.Whyconf.Sprover.empty
      with Not_found -> Why3.Whyconf.Sprover.empty

    method private save () =
      let open Gtk_helper.Configuration in
      let conf_of_prover dp = ConfList Why3.Whyconf.[ConfString dp.prover_name;
                                                     ConfString dp.prover_version;
                                                     ConfString dp.prover_altern] in
      Gtk_helper.Configuration.set key
        (ConfList (List.map conf_of_prover
                     (Why3.Whyconf.Sprover.elements self#get)))

    initializer
      begin
        let settings = self#load () in
        (** select automatically the provers set on the command line *)
        let cmdline = Wp_parameters.Provers.get () in
        let selection = List.fold_left
            (fun acc e ->
               match VCS.Why3_prover.find_opt e with
               | None-> acc
               | Some p -> Why3.Whyconf.Sprover.add p acc)
            settings cmdline
        in
        self#set selection ;
        self#on_event self#save ;
      end

  end

(* ------------------------------------------------------------------------ *)
(* ---  WP Provers Configuration Panel                                  --- *)
(* ------------------------------------------------------------------------ *)

class dp_chooser
    ~(main:Design.main_window_extension_points)
    ~(enabled:enabled)
  =
  let dialog = new Wpane.dialog
    ~title:"Why3 Provers"
    ~window:main#main_window
    ~resize:false () in
  let array = new Wpane.warray () in
  object(self)

    val mutable selected = Why3.Whyconf.Mprover.empty

    method private enable dp e =
      selected <- Why3.Whyconf.Mprover.add dp e selected

    method private lookup dp =
      Why3.Whyconf.Mprover.find dp selected

    method private entry dp =
      let text = VCS.Why3_prover.title dp in
      let sw = new Widget.switch () in
      let lb = new Widget.label ~align:`Left ~text () in
      sw#set (self#lookup dp) ;
      sw#connect (self#enable dp) ;
      let hbox = GPack.hbox ~spacing:10 ~homogeneous:false () in
      hbox#pack ~expand:false sw#coerce ;
      hbox#pack ~expand:true lb#coerce ;
      (object
        method widget = hbox#coerce
        method update () = sw#set (self#lookup dp)
        method delete () = ()
      end)

    method private configure dps =
      begin
        array#set (Why3.Whyconf.Sprover.elements dps) ;
        array#update () ;
      end

    method private detect () =
      begin
        self#configure (VCS.Why3_prover.provers_set ());
      end

    method private apply () =
      enabled#set
        (Why3.Whyconf.Mprover.map_filter
           (function
             | true -> Some ()
             | false -> None)
           selected)

    method run () =
      let dps = VCS.Why3_prover.provers_set () in
      let sel = enabled#get in
      selected <- Why3.Whyconf.Mprover.merge
          (fun _ avail enab ->
             match avail, enab with
             | None, _ -> None
             | Some (), Some () -> Some true
             | Some (), None -> Some false)
          dps sel;
      self#configure dps ;
      dialog#run ()

    initializer
      begin
        dialog#button ~action:(`ACTION self#detect) ~label:"Detect Provers" () ;
        dialog#button ~action:(`CANCEL) ~label:"Cancel" () ;
        dialog#button ~action:(`APPLY) ~label:"Apply" () ;
        array#set_entry self#entry ;
        dialog#add_block array#coerce ;
        dialog#on_value `APPLY self#apply ;
      end

  end

(* ------------------------------------------------------------------------ *)
(* ---  WP Prover Switch Panel                                          --- *)
(* ------------------------------------------------------------------------ *)

type mprover =
  | NONE
  | ERGO
  | COQ
  | WHY of VCS.Why3_prover.t

class dp_button =
  let render = function
    | NONE -> "(none)"
    | ERGO -> "Alt-Ergo (native)"
    | COQ -> "Coq (native)"
    | WHY p when VCS.Why3_prover.has_shortcut p "alt-ergo" ->
        "Alt-Ergo (why3)"
    | WHY dp -> VCS.Why3_prover.title dp in
  let select = function
    | ERGO -> VCS.NativeAltErgo
    | COQ -> VCS.NativeCoq
    | NONE -> VCS.Qed
    | WHY p -> VCS.Why3 p in
  let rec import = function
    | [] -> ERGO
    | spec::others ->
        match VCS.prover_of_name spec with
        | None | Some VCS.Qed -> NONE
        | Some (VCS.NativeAltErgo|VCS.Tactical) -> ERGO
        | Some VCS.NativeCoq -> COQ
        | Some (VCS.Why3 p) ->
            if Why3.Whyconf.Sprover.mem p (VCS.Why3_prover.provers_set ())
            then WHY p
            else import others
  in
  let items = [ NONE ; ERGO ; COQ ] in
  let button = new Widget.menu ~default:ERGO ~render ~items () in
  object(self)
    method coerce = button#coerce
    method widget = (self :> Widget.t)
    method set_enabled = button#set_enabled
    method set_visible = button#set_visible
    val mutable dps = Why3.Whyconf.Sprover.empty

    method update () =
      (* called in polling mode *)
      begin
        let avl = VCS.Why3_prover.provers_set () in
        if Why3.Whyconf.Sprover.equal avl dps then
          begin
            dps <- avl ;
            let dps = Why3.Whyconf.Sprover.elements dps in
            let items = [NONE;ERGO] @ List.map (fun p -> WHY p) dps @ [COQ] in
            button#set_items items
          end ;
        let cur = Wp_parameters.Provers.get () |> import in
        if cur <> button#get then button#set cur ;
      end

    initializer button#connect
        (fun s ->
           let p = select s in
           let p = VCS.name_of_prover p in
           Wp_parameters.Provers.set [p]
        )
  end

(* ------------------------------------------------------------------------ *)
