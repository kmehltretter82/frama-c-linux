(**************************************************************************)
(*                                                                        *)
(*  SPDX-License-Identifier LGPL-2.1                                      *)
(*  Copyright (C)                                                         *)
(*  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  *)
(*                                                                        *)
(**************************************************************************)

let no_status = `Share "theme/default/never_tried.png"
let ok_status = `Share "theme/default/surely_valid.png"
let ko_status = `Share "theme/default/unknown.png"
let wg_status = `Share "theme/default/surely_invalid.png"
let smoke_status = `Share "theme/default/valid_under_hyp.png"

let filter = function
  | VCS.Qed | VCS.Tactical -> false
  | VCS.Why3 _ -> true

(* -------------------------------------------------------------------------- *)
(* --- Palette Tool                                                       --- *)
(* -------------------------------------------------------------------------- *)

let timeout_for = function
  | VCS.Why3 _ ->
    let value = Wp_parameters.Timeout.get () in
    let spin = new Widget.spinner
      ~tooltip:"Prover Timeout (0 for none)"
      ~min:0 ~step:5 ~value () in
    Some spin
  | _ -> None

let stepout_for = function
  | VCS.Why3 _ ->
    let value = Wp_parameters.Steps.get () in
    let spin = new Widget.spinner
      ~tooltip:"Prover Step Limit (0 for none)"
      ~min:0 ~step:100 ~value () in
    Some spin
  | _ -> None

class prover ~(console:Wtext.text) ~prover =
  let tooltip = "Configure Prover" in
  let content = new Wpane.form () in
  let result = new Widget.label ~style:`Code ~align:`Center ~text:"No Result" () in
  let timeout = timeout_for prover in
  let stepout = stepout_for prover in
  object(self)
    inherit Wpalette.tool ~tooltip ~content:content#widget ()
    initializer
      begin
        assert (filter prover) ;
        content#add_row ~xpadding:6 ~ypadding:4 result#coerce ;
        Wutil.on timeout (fun spin -> content#add_field ~label:"Timeout" spin#coerce) ;
        Wutil.on stepout (fun spin -> content#add_field ~label:"Steps" spin#coerce) ;
      end

    method prover = prover

    method private log wpo res =
      begin
        let fout = Wpo.get_file_logout wpo prover in
        let ferr = Wpo.get_file_logerr wpo prover in
        let lout = Filesystem.exists fout in
        let lerr = Filesystem.exists ferr in
        if lout || lerr then console#hrule ;
        console#scroll () ;
        console#printf "[%a] %a@.%a" VCS.pp_prover prover
          VCS.pp_result res
          VCS.pp_model res.prover_model ;
        if lout then Command.pp_from_file console#fmt fout ;
        if lerr then Command.pp_from_file console#fmt ferr ;
        if lout || lerr then console#hrule ;
      end

    method private run wpo =
      begin
        let spinner = function None -> None | Some s -> Some s#get in
        let m = Wp_parameters.Memlimit.get () in
        let config = {
          VCS.valid = false ;
          VCS.timeout = Option.map float @@ spinner timeout ;
          VCS.stepout = spinner stepout ;
          VCS.memlimit = if m > 0 then Some m else None ;
        } in
        let result wpo _prv _res = self#update wpo in
        let task = Prover.prove ~config ~result wpo prover in
        let thread = Task.thread task in
        let kill () =
          Wpo.set_result wpo prover VCS.no_result ;
          Task.cancel thread in
        Wpo.set_result wpo prover (VCS.computing kill) ;
        let server = ProverTask.server () in
        Task.spawn server thread ;
        Task.launch server ;
        Wutil.later (fun () -> self#update wpo) ;
      end

    method clear =
      begin
        self#set_status no_status ;
        self#set_action ~icon:`MEDIA_PLAY ~tooltip:"Run Prover" ?callback:None () ;
        Pretty_utils.ksfprintf self#set_label "%a" VCS.pp_prover prover ;
        result#set_text "No Goal" ;
      end

    method update wpo =
      begin
        let res = Wpo.get_result wpo prover in
        result#set_text (Pretty_utils.to_string VCS.pp_result res) ;
        match res.VCS.verdict with
        | VCS.NoResult ->
          let callback () = self#run wpo in
          self#set_status no_status ;
          self#set_action ~icon:`MEDIA_PLAY ~tooltip:"Run Prover" ~callback () ;
        | VCS.Computing callback ->
          self#set_status `EXECUTE ;
          self#set_action ~tooltip:"Interrrupt Prover" ~icon:`STOP ~callback () ;
          Pretty_utils.ksfprintf self#set_label "%a (...)" VCS.pp_prover prover ;
        | VCS.Valid ->
          let callback () = self#run wpo in
          self#set_status ok_status ;
          self#set_action ~tooltip:"Run Prover" ~icon:`MEDIA_PLAY ~callback () ;
          Pretty_utils.ksfprintf self#set_label "%a (%a)" VCS.pp_prover prover
            Rformat.pp_time res.VCS.prover_time ;
        | VCS.Unknown | VCS.Timeout | VCS.Stepout | VCS.Invalid ->
          let callback () = self#run wpo in
          self#set_status ko_status ;
          self#set_action ~tooltip:"Run Prover" ~icon:`MEDIA_PLAY ~callback () ;
          Pretty_utils.ksfprintf self#set_label "%a (?)" VCS.pp_prover prover ;
        | VCS.Failed ->
          let callback () = self#log wpo res in
          self#set_status `DIALOG_WARNING ;
          self#set_action ~tooltip:"Dump Logs" ~icon:`FILE ~callback () ;
          Pretty_utils.ksfprintf self#set_label "%a (failed)" VCS.pp_prover prover ;
      end

  end
