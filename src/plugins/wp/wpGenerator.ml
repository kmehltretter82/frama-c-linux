(**************************************************************************)
(*                                                                        *)
(*  This file is part of WP plug-in of Frama-C.                           *)
(*                                                                        *)
(*  Copyright (C) 2007-2021                                               *)
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

(* -------------------------------------------------------------------------- *)
(* --- WP Computer (main entry points)                                    --- *)
(* -------------------------------------------------------------------------- *)

class type computer =
  object
    method model : WpContext.model
    method add_strategy : WpStrategy.strategy -> unit
    method add_lemma : LogicUsage.logic_lemma -> unit
    method compute : Wpo.t Bag.t
  end

(* -------------------------------------------------------------------------- *)
(* --- Property Entry Point                                               --- *)
(* -------------------------------------------------------------------------- *)

let compute_ip cc ip =
  let open Property in match ip with
  | IPLemma _
  | IPAxiomatic _
    ->
      let rec iter cc = function
        | IPLemma {il_name} -> cc#add_lemma (LogicUsage.logic_lemma il_name)
        | IPAxiomatic {iax_props} -> List.iter (iter cc) iax_props
        | _ -> ()
      in iter cc ip ;
      cc#compute
  | _ ->
      List.iter cc#add_strategy
        (WpAnnot.get_property_strategies ~model:cc#model ip) ;
      cc#compute

(* -------------------------------------------------------------------------- *)
(* --- Annotations Entry Point                                            --- *)
(* -------------------------------------------------------------------------- *)

let add_kf cc ?bhv ?prop kf =
  let model = cc#model in
  let assigns = WpAnnot.WithAssigns in
  List.iter cc#add_strategy
    (WpAnnot.get_function_strategies ~model ~assigns ?bhv ?prop kf)

let add_lemmas cc = function
  | None | Some[] ->
      LogicUsage.iter_lemmas
        (fun lem ->
           let idp = WpPropId.mk_lemma_id lem in
           if WpPropId.filter_status idp then cc#add_lemma lem)
  | Some ps ->
      if List.mem "-@lemmas" ps then ()
      else LogicUsage.iter_lemmas
          (fun lem ->
             let idp = WpPropId.mk_lemma_id lem in
             if WpPropId.filter_status idp && WpPropId.select_by_name ps idp
             then cc#add_lemma lem)

let compute_kf cc ?kf ?bhv ?prop () =
  begin
    Option.iter (add_kf cc ?bhv ?prop) kf ;
    cc#compute
  end

let compute_selection cc ?(fct=Wp_parameters.Fct_all) ?bhv ?prop () =
  begin
    add_lemmas cc prop ;
    Wp_parameters.iter_fct (add_kf cc ?bhv ?prop) fct ;
    cc#compute
  end

let compute_call cc stmt =
  let model = cc#model in
  List.iter cc#add_strategy (WpAnnot.get_call_pre_strategies ~model stmt) ;
  cc#compute

(* -------------------------------------------------------------------------- *)
(* --- WPO Computer                                                       --- *)
(* -------------------------------------------------------------------------- *)

module KFmap = Kernel_function.Map

module Computer(VCG : CfgWP.VCgen) =
struct

  open LogicUsage
  module WP = Calculus.Cfg(VCG)

  let prove_strategy collection model kf strategy =
    let cfg = WpStrategy.cfg_of_strategy strategy in
    let bhv = WpStrategy.get_bhv strategy in
    let index = Wpo.Function( kf , bhv ) in
    if WpRTE.missing_guards model kf then
      Wp_parameters.warning ~current:false ~once:true
        "Missing RTE guards" ;
    try
      let (results,_) = WP.compute cfg strategy in
      List.iter
        (fun wp ->
           let wcs = VCG.compile_wp index wp in
           collection := Bag.concat !collection wcs
        ) results
    with Warning.Error(source,reason) ->
      Wp_parameters.failure
        ~current:false "From %s: %s" source reason

  class wp (model:WpContext.model) =
    object
      val mutable lemmas : LogicUsage.logic_lemma Bag.t = Bag.empty
      val mutable annots : WpStrategy.strategy Bag.t KFmap.t = KFmap.empty

      method model = model

      method add_lemma lemma =
        if Logic_utils.verify_predicate lemma.lem_predicate.tp_kind then
          lemmas <- Bag.append lemmas lemma

      method add_strategy strategy =
        let kf = WpStrategy.get_kf strategy in
        let sf = try KFmap.find kf annots with Not_found -> Bag.empty in
        annots <- KFmap.add kf (Bag.append sf strategy) annots

      method compute : Wpo.t Bag.t =
        begin
          let collection = ref Bag.empty in
          Lang.F.release () ;
          WpContext.on_context (model,WpContext.Global)
            begin fun () ->
              Bag.iter
                (fun (l : LogicUsage.logic_lemma) ->
                   if Logic_utils.verify_predicate l.lem_predicate.tp_kind then
                     let vc = VCG.compile_lemma l in
                     collection := Bag.append !collection vc
                ) lemmas ;
            end () ;
          KFmap.iter
            (fun kf strategies ->
               WpContext.on_context (model,WpContext.Kf kf)
                 begin fun () ->
                   LogicUsage.iter_lemmas
                     (fun (l : LogicUsage.logic_lemma) ->
                        if Logic_utils.use_predicate l.lem_predicate.tp_kind
                        then VCG.register_lemma l) ;
                   LogicUsage.iter_lemmas VCG.register_lemma ;
                   Bag.iter (prove_strategy collection model kf) strategies ;
                 end ()
            ) annots ;
          lemmas <- Bag.empty ;
          annots <- KFmap.empty ;
          Lang.F.release () ;
          !collection
        end
    end

end

(* -------------------------------------------------------------------------- *)
(* --- Dump Computer                                                      --- *)
(* -------------------------------------------------------------------------- *)

module DUMPER = Calculus.Cfg(CfgDump)

let dumper () =
  let driver = Driver.load_driver () in
  let model = Factory.(instance default driver) in
  object
    val mutable wptasks = []

    method model = model

    method add_lemma (_ : LogicUsage.logic_lemma) = ()

    method add_strategy strategy =
      wptasks <- strategy :: wptasks

    method compute : Wpo.t Bag.t =
      begin
        (* Generates Wpos and accumulate exported goals *)
        List.iter
          (fun strategy ->
             let cfg = WpStrategy.cfg_of_strategy strategy in
             let kf = Cil2cfg.cfg_kf cfg in
             let bhv = WpStrategy.behavior_name_of_strategy strategy in
             CfgDump.fopen kf bhv ;
             try
               ignore (DUMPER.compute cfg strategy) ;
               CfgDump.flush ()
             with err ->
               CfgDump.flush () ;
               raise err
          ) wptasks ;
        wptasks <- [] ;
        Bag.empty
      end

  end

(* -------------------------------------------------------------------------- *)
(* --- Generators                                                         --- *)
(* -------------------------------------------------------------------------- *)

let generators = WpContext.MINDEX.create 1

let computer setup driver =
  let model = Factory.instance setup driver in
  try WpContext.MINDEX.find generators model
  with Not_found ->
    let module VCG = (val CfgWP.vcgen setup driver) in
    let module CC = Computer(VCG) in
    let computer = (new CC.wp model :> computer) in
    WpContext.MINDEX.add generators model computer ; computer

(* -------------------------------------------------------------------------- *)
