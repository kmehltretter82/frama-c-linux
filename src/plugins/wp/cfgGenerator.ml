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

module KFmap = Kernel_function.Map

type task = {
  mutable modes: CfgCalculus.mode list KFmap.t ;
  mutable props: CfgCalculus.props ;
  mutable lemmas: LogicUsage.logic_lemma list ;
}

let empty () = {
  lemmas = [];
  modes = KFmap.empty;
  props = `All;
}

(* -------------------------------------------------------------------------- *)
(* --- Property Guided Selection                                          --- *)
(* -------------------------------------------------------------------------- *)

let get_kf_infos model kf ?bhv ?prop () =
  if WpRTE.missing_guards model kf then
    Wp_parameters.warning ~current:false ~once:true "Missing RTE guards"
  else if Wp_parameters.RTE.get () then
    WpRTE.generate model kf ;
  CfgInfos.get kf ?bhv ?prop ()

let empty_default_behavior : funbehavior = {
  b_name = Cil.default_behavior_name ;
  b_requires = [] ;
  b_assumes = [] ;
  b_post_cond = [] ;
  b_assigns = WritesAny ;
  b_allocation = FreeAllocAny ;
  b_extended = [] ;
}

let default kf =
  match Annotations.behaviors kf with
  | [] -> [empty_default_behavior]
  | bhvs -> List.filter Cil.is_default_behavior bhvs

let select kf bnames =
  match Annotations.behaviors kf with
  | [] -> if bnames = [] then [empty_default_behavior] else []
  | bhvs -> if bnames = [] then bhvs else
        List.filter
          (fun b -> List.mem b.b_name bnames)
          bhvs

let lemma task ?(prop=[]) l =
  if l.LogicUsage.lem_kind <> `Axiom &&
     (prop=[] || WpPropId.select_by_name prop (WpPropId.mk_lemma_id l))
  then task.lemmas <- l :: task.lemmas

let apply model task ~kf ?infos ?bhvs ?target () =
  let infos = match infos with
    | Some infos -> infos
    | None -> get_kf_infos model kf () in
  let bhvs = match bhvs with
    | Some bhvs -> bhvs
    | None ->
        let bhvs = Annotations.behaviors kf in
        if List.exists (Cil.is_default_behavior) bhvs then bhvs
        else empty_default_behavior :: bhvs in
  let add_mode kf m =
    let ms = try KFmap.find kf task.modes with Not_found -> [] in
    task.modes <- KFmap.add kf (m :: ms) task.modes in
  begin
    List.iter (fun bhv -> add_mode kf CfgCalculus.{ infos ; kf ; bhv }) bhvs ;
    Option.iter (fun ip -> task.props <- `PropId ip) target ;
  end

let notyet prop =
  Wp_parameters.warning ~once:true
    "Not yet implemented wp for '%a'" Property.pretty prop

let rec strategy_ip model task target =
  let open Property in
  match target with
  | IPLemma { il_name } ->
      lemma task (LogicUsage.logic_lemma il_name)
  | IPAxiomatic { iax_props } ->
      List.iter (strategy_ip model task) iax_props
  | IPBehavior { ib_kf = kf ; ib_bhv = bhv } ->
      apply model task ~kf ~bhvs:[bhv] ()
  | IPPredicate { ip_kf = kf ; ip_kind ; ip_kinstr = ki } ->
      begin match ip_kind with
        | PKAssumes _ -> ()
        | PKRequires bhv ->
            begin
              match ki with
              | Kglobal -> (*TODO*) notyet target
              | Kstmt _ -> apply model task ~kf ~bhvs:[bhv] ~target ()
            end
        | PKEnsures(bhv,_) ->
            apply model task ~kf ~bhvs:[bhv] ~target ()
        | PKTerminates ->
            apply model task ~kf ~bhvs:(default kf) ~target ()
      end
  | IPDecrease { id_kf = kf } ->
      apply model task ~kf ~bhvs:(default kf) ~target ()
  | IPAssigns { ias_kf=kf ; ias_bhv=Id_loop ca }
  | IPAllocation { ial_kf=kf ; ial_bhv=Id_loop ca } ->
      let bhvs = match ca.annot_content with
        | AAssigns(bhvs,_) | AAllocation(bhvs,_) -> bhvs
        | _ -> [] in
      apply model task ~kf ~bhvs:(select kf bhvs) ~target ()
  | IPAssigns { ias_kf=kf ; ias_bhv=Id_contract(_,bhv) }
  | IPAllocation { ial_kf=kf ; ial_bhv=Id_contract(_,bhv) }
    -> apply model task ~kf ~bhvs:[bhv] ~target ()
  | IPCodeAnnot { ica_kf = kf ; ica_ca = ca } ->
      begin match ca.annot_content with
        | AExtended _ | APragma _ -> ()
        | AStmtSpec(fors,_) ->
            (*TODO*) notyet target ;
            apply model task ~kf ~bhvs:(select kf fors) ()
        | AVariant _ ->
            apply model task ~kf ~target ()
        | AAssert(fors, _)
        | AInvariant(fors, _, _)
        | AAssigns(fors, _)
        | AAllocation(fors, _) ->
            apply model task ~kf ~bhvs:(select kf fors) ~target ()
      end
  | IPComplete _ -> (*TODO*) notyet target
  | IPDisjoint _ -> (*TODO*) notyet target
  | IPFrom _ | IPReachable _ | IPTypeInvariant _ | IPGlobalInvariant _
  | IPPropertyInstance _ -> notyet target (* ? *)
  | IPExtended _ | IPAxiom _ | IPOther _ -> ()

let strategy_main model task ?(fct=Fct_all) ?(bhv=[]) ?(prop=[]) () =
  begin
    if fct = Fct_all && bhv = [] then
      LogicUsage.iter_lemmas (lemma task ~prop) ;
    Wp_parameters.iter_fct
      (fun kf ->
         let infos = get_kf_infos model kf ~bhv ~prop () in
         if CfgInfos.annots infos then
           if bhv=[]
           then apply model task ~infos ~kf ()
           else apply model task ~infos ~kf ~bhvs:(select kf bhv) ()
      ) fct ;
    task.props <- (if prop=[] then `All else `Names prop);
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
              ) task.lemmas ;
          end () ;
      KFmap.iter
        (fun _ modes ->
           List.iter
             begin fun (mode: CfgCalculus.mode) ->
               WpContext.on_context (model,WpContext.Kf mode.kf)
                 begin fun () ->
                   LogicUsage.iter_lemmas VCG.register_lemma ;
                   let bhv =
                     if Cil.is_default_behavior mode.bhv then None
                     else Some mode.bhv.b_name in
                   let index = Wpo.Function(mode.kf,bhv) in
                   let props = task.props in
                   let wp = WP.compute ~mode ~props in
                   let wcs = VCG.compile_wp index wp in
                   collection := Bag.concat !collection wcs
                 end ()
             end
             (List.rev modes)
        ) task.modes ;
      !collection
    end

  let compute_ip model ip =
    let task = empty () in
    strategy_ip model task ip ;
    compute model task

  let compute_call _model _stmt =
    Wp_parameters.warning
      ~once:true "Not yet implemented call preconds" ;
    Bag.empty

  let compute_main model ?fct ?bhv ?prop () =
    let task = empty () in
    strategy_main model task ?fct ?bhv ?prop () ;
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
  KFmap.iter
    (fun _ modes ->
       List.iter
         begin fun (mode : CfgCalculus.mode) ->
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
         end
         (List.rev modes)
    ) task.modes

let dumper setup driver =
  let model = Factory.instance setup driver in
  let generator : Wpo.generator =
    object
      method model = model
      method compute_ip ip =
        let task = empty () in
        strategy_ip model task ip ;
        dump task ; Bag.empty
      method compute_call _ = Bag.empty
      method compute_main ?fct ?bhv ?prop () =
        let task = empty () in
        strategy_main model task ?fct ?bhv ?prop () ;
        dump task ; Bag.empty
    end
  in generator

(* -------------------------------------------------------------------------- *)
