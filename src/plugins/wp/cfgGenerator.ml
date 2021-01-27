(**************************************************************************)
(*                                                                        *)
(*  This file is part of WP plug-in of Frama-C.                           *)
(*                                                                        *)
(*  Copyright (C) 2007-2020                                               *)
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

open Cil_types
open Wp_parameters

(* -------------------------------------------------------------------------- *)
(* --- Task Manager                                                       --- *)
(* -------------------------------------------------------------------------- *)

type task = {
  mutable lemmas: LogicUsage.logic_lemma list ;
  mutable modes: CfgCalculus.mode list ;
  mutable props: CfgCalculus.props ;
}

let empty () = {
  lemmas = [];
  modes = [];
  props = `All ;
}

(* -------------------------------------------------------------------------- *)
(* --- Property Guided Selection                                          --- *)
(* -------------------------------------------------------------------------- *)

let default kf =
  List.filter
    Cil.is_default_behavior
    (Annotations.behaviors kf)

let select kf bnames =
  let bhvs = Annotations.behaviors kf in
  if bnames = [] then bhvs else
    List.filter
      (fun b -> List.mem b.b_name bnames)
      bhvs

let lemma task l = task.lemmas <- l :: task.lemmas

let apply task ~kf ?bhvs ?prop () =
  begin
    let bhvs = match bhvs with
      | None -> Annotations.behaviors kf
      | Some bhvs -> bhvs in
    List.iter (fun bhv ->
        task.modes <- { kf ; bhv } :: task.modes
      ) bhvs ;
    Extlib.may (fun ip -> task.props <- `PropId ip) prop ;
  end

let notyet prop =
  Wp_parameters.warning ~once:true
    "Not yet implemented wp for '%a'" Property.pretty prop

let rec strategy_ip task prop =
  let open Property in
  match prop with
  | IPLemma { il_name } ->
      lemma task (LogicUsage.logic_lemma il_name)
  | IPAxiomatic { iax_props } ->
      List.iter (strategy_ip task) iax_props
  | IPBehavior { ib_kf = kf ; ib_bhv = bhv } ->
      apply task ~kf ~bhvs:[bhv] ()
  | IPPredicate { ip_kf = kf ; ip_kind ; ip_kinstr = ki } ->
      begin match ip_kind with
        | PKAssumes _ -> ()
        | PKRequires bhv ->
            begin
              match ki with
              | Kglobal -> (*TODO*) notyet prop
              | Kstmt _ -> apply task ~kf ~bhvs:[bhv] ~prop ()
            end
        | PKEnsures(bhv,_) ->
            apply task ~kf ~bhvs:[bhv] ~prop ()
        | PKTerminates ->
            apply task ~kf ~bhvs:(default kf) ~prop ()
      end
  | IPDecrease { id_kf = kf } ->
      apply task ~kf ~bhvs:(default kf) ~prop ()
  | IPAssigns { ias_kf=kf ; ias_bhv=Id_loop ca }
  | IPAllocation { ial_kf=kf ; ial_bhv=Id_loop ca } ->
      let bhvs = match ca.annot_content with
        | AAssigns(bhvs,_) | AAllocation(bhvs,_) -> bhvs
        | _ -> [] in
      apply task ~kf ~bhvs:(select kf bhvs) ~prop ()
  | IPAssigns { ias_kf=kf ; ias_bhv=Id_contract(_,bhv) }
  | IPAllocation { ial_kf=kf ; ial_bhv=Id_contract(_,bhv) }
    -> apply task ~kf ~bhvs:[bhv] ~prop ()
  | IPCodeAnnot { ica_kf = kf ; ica_ca = ca } ->
      begin match ca.annot_content with
        | AExtended _ | APragma _ -> ()
        | AStmtSpec(fors,_) ->
            (*TODO*) notyet prop ;
            apply task ~kf ~bhvs:(select kf fors) ()
        | AVariant _ ->
            apply task ~kf ~prop ()
        | AAssert(fors, _)
        | AInvariant(fors, _, _)
        | AAssigns(fors, _)
        | AAllocation(fors, _) ->
            apply task ~kf ~bhvs:(select kf fors) ~prop ()
      end
  | IPComplete _ -> (*TODO*) notyet prop
  | IPDisjoint _ -> (*TODO*) notyet prop
  | IPFrom _ | IPReachable _ | IPTypeInvariant _ | IPGlobalInvariant _
  | IPPropertyInstance _ -> notyet prop (* ? *)
  | IPExtended _ | IPAxiom _ | IPOther _ -> ()

let select_lemma_prop l = function
  | None -> true
  | Some ns -> WpPropId.select_by_name ns (WpPropId.mk_lemma_id l)

let strategy_main task ?(fct=Fct_all) ?bhv ?prop () =
  begin
    if fct = Fct_all && bhv = None then
      LogicUsage.iter_lemmas (fun l ->
          if l.lem_kind <> `Axiom && select_lemma_prop l prop
          then lemma task l
        ) ;
    Wp_parameters.iter_fct
      (fun kf ->
         match bhv with
         | None | Some [] -> apply task ~kf ()
         | Some bs -> apply task ~kf ~bhvs:(select kf bs) ()
      ) fct ;
    task.props <- (match prop with None -> `All | Some ps -> `Names ps) ;
  end

(* -------------------------------------------------------------------------- *)
(* --- Compute All Tasks                                                  --- *)
(* -------------------------------------------------------------------------- *)

module Make(VCG : CfgWP.VCgen) =
struct

  module WP = CfgCalculus.Make(VCG)

  let compute model task =
    begin
      let collection = ref Bag.empty in
      Lang.F.release () ;
      if task.lemmas <> [] then
        WpContext.on_context (model,WpContext.Global)
          begin fun () ->
            LogicUsage.iter_lemmas VCG.register_lemma ;
            List.iter (fun l ->
                if l.LogicUsage.lem_kind <> `Axiom then
                  let wpo = VCG.compile_lemma l in
                  collection := Bag.add wpo !collection
              ) (List.rev task.lemmas) ;
          end () ;
      List.iter
        (fun (mode : CfgCalculus.mode) ->
           WpContext.on_context (model,WpContext.Kf mode.kf)
             begin fun () ->
               LogicUsage.iter_lemmas VCG.register_lemma ;
               let bhv =
                 if Cil.is_default_behavior mode.bhv then None
                 else Some mode.bhv.b_name in
               let index = Wpo.Function(mode.kf,bhv) in
               let wp = snd @@ WP.compute ~mode ~props:task.props in
               let wcs = VCG.compile_wp index wp in
               collection := Bag.concat !collection wcs
             end ()
        ) task.modes ;
      !collection
    end

  let compute_ip model ip =
    let task = empty () in
    strategy_ip task ip ;
    compute model task

  let compute_call _model _stmt =
    Wp_parameters.warning
      ~once:true "Not yet implemented call preconds" ;
    Bag.empty

  let compute_main model ?fct ?bhv ?prop () =
    let task = empty () in
    strategy_main task ?fct ?bhv ?prop () ;
    compute model task

end

(* -------------------------------------------------------------------------- *)
(* --- New WP Computer (main entry points)                                --- *)
(* -------------------------------------------------------------------------- *)

let generators = WpContext.MINDEX.create 1

let generator setup driver =
  let model = Factory.instance setup driver in
  try WpContext.MINDEX.find generators model
  with Not_found ->
    let module VCG = (val CfgWP.vcgen setup driver) in
    let module CC = Make(VCG) in
    let generator : Wpo.generator =
      object
        method model = model
        method compute_ip = CC.compute_ip model
        method compute_call = CC.compute_call model
        method compute_main = CC.compute_main model
      end in
    WpContext.MINDEX.add generators model generator ;
    generator

(* -------------------------------------------------------------------------- *)
(* --- Dumper                                                             --- *)
(* -------------------------------------------------------------------------- *)

let dump task =
  let module WP = CfgCalculus.Make(CfgDump) in
  let props = task.props in
  List.iter
    (fun (mode : CfgCalculus.mode) ->
       let bhv =
         if Cil.is_default_behavior mode.bhv
         then None else Some mode.bhv.b_name in
       try
         CfgDump.fopen mode.kf bhv ;
         ignore (WP.compute ~mode ~props) ;
         CfgDump.flush () ;
       with err ->
         CfgDump.flush () ;
         raise err
    ) task.modes

let dumper setup driver =
  let model = Factory.instance setup driver in
  let generator : Wpo.generator =
    object
      method model = model
      method compute_ip ip =
        let task = empty () in
        strategy_ip task ip ;
        dump task ; Bag.empty
      method compute_call _ = Bag.empty
      method compute_main ?fct ?bhv ?prop () =
        let task = empty () in
        strategy_main task ?fct ?bhv ?prop () ;
        dump task ; Bag.empty
    end
  in generator

(* -------------------------------------------------------------------------- *)
