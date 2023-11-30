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

(* -------------------------------------------------------------------------- *)
(* --- Server API for WP                                                  --- *)
(* -------------------------------------------------------------------------- *)

open WpApi
module P = Server.Package
module D = Server.Data
module R = Server.Request
module S = Server.States
module Md = Markdown
module AST = Server.Kernel_ast

let package = P.package ~plugin:"wp" ~name:"tip"
    ~title:"WP Interactive Prover" ()

(* -------------------------------------------------------------------------- *)
(* --- Proof Node                                                         --- *)
(* -------------------------------------------------------------------------- *)

let proofStatus = R.signal ~package ~name:"proofStatus"
    ~descr:(Md.plain "Proof Status has changed")

module Node = D.Index(Map.Make(ProofEngine.Node))(struct let name = "node" end)

let () =
  let inode = R.signature ~input:(module Node) () in
  let set_title = R.result inode ~name:"result"
      ~descr:(Md.plain "Proof node title") (module D.Jstring) in
  let set_proved = R.result inode ~name:"proved"
      ~descr:(Md.plain "Proof node complete") (module D.Jbool) in
  let set_pending = R.result inode ~name:"pending"
      ~descr:(Md.plain "Pending children") (module D.Jint) in
  let set_size = R.result inode ~name:"size"
      ~descr:(Md.plain "Proof size") (module D.Jint) in
  let set_stats = R.result inode ~name:"stats"
      ~descr:(Md.plain "Node statistics") (module D.Jstring) in
  let set_results = R.result inode ~name:"results"
      ~descr:(Md.plain "Prover results for current node")
      (module D.Jlist(D.Jpair(Prover)(Result))) in
  let set_tactic = R.result inode ~name:"tactic"
      ~descr:(Md.plain "Proof node tactic header (if any)")
      (module D.Jstring) in
  let set_children = R.result inode ~name:"children"
      ~descr:(Md.plain "Proof node tactic children (id any)")
      (module D.Jlist(D.Jpair(D.Jstring)(Node))) in
  R.register_sig ~package ~kind:`GET ~name:"getNodeInfos"
    ~descr:(Md.plain "Proof node information") inode
    ~signals:[proofStatus]
    begin fun rq node ->
      set_title rq (ProofEngine.title node) ;
      set_proved rq (ProofEngine.proved node) ;
      set_pending rq (ProofEngine.pending node) ;
      let s = ProofEngine.stats node in
      let tactic =
        match ProofEngine.tactical node with
        | None -> ""
        | Some { header } -> header in
      set_size rq (Stats.subgoals s) ;
      set_stats rq (Pretty_utils.to_string Stats.pretty s) ;
      set_results rq (Wpo.get_results (ProofEngine.goal node)) ;
      set_tactic rq tactic ;
      set_children rq (ProofEngine.children node) ;
    end

(* -------------------------------------------------------------------------- *)
(* --- Proof Tree                                                         --- *)
(* -------------------------------------------------------------------------- *)

let () =
  let state = R.signature ~input:(module Goal) () in
  let set_current = R.result state ~name:"current"
      ~descr:(Md.plain "Current proof node") (module Node) in
  let set_path = R.result state ~name:"path"
      ~descr:(Md.plain "Proof node parents") (module D.Jlist(Node)) in
  let set_index = R.result state ~name:"index"
      ~descr:(Md.plain "Current node index among pending nodes (else -1)")
      (module D.Jint) in
  let set_pending = R.result state ~name:"pending"
      ~descr:(Md.plain "Pending proof nodes") (module D.Jint) in
  R.register_sig ~package
    ~kind:`GET ~name:"getProofState"
    ~descr:(Md.plain "Current Proof Status of a Goal") state
    ~signals:[proofStatus]
    begin fun rq wpo ->
      let tree = ProofEngine.proof ~main:wpo in
      let current,index =
        match ProofEngine.current tree with
        | `Main -> ProofEngine.root tree,-1
        | `Internal node -> node,-1
        | `Leaf(idx,node) -> node,idx in
      let rec path node = match ProofEngine.parent node with
        | None -> []
        | Some p -> p::path p in
      set_current rq current ;
      set_path rq (path current) ;
      set_index rq index ;
      set_pending rq (ProofEngine.pending current) ;
    end

(* -------------------------------------------------------------------------- *)
(* --- Proof Tree Management                                              --- *)
(* -------------------------------------------------------------------------- *)

let () = R.register ~package ~kind:`SET ~name:"goForward"
    ~descr:(Md.plain "Go to to first pending node, or root if none")
    ~input:(module Goal) ~output:(module D.Junit)
    begin fun goal ->
      let tree = ProofEngine.proof ~main:goal in
      ProofEngine.forward tree ;
      R.emit proofStatus ;
    end

let () = R.register ~package ~kind:`SET ~name:"goToRoot"
    ~descr:(Md.plain "Go to root of proof tree")
    ~input:(module Goal) ~output:(module D.Junit)
    begin fun goal ->
      let tree = ProofEngine.proof ~main:goal in
      ProofEngine.goto tree `Main ;
      R.emit proofStatus ;
    end

let () = R.register ~package ~kind:`SET ~name:"goToIndex"
    ~descr:(Md.plain "Go to k-th pending node of proof tree")
    ~input:(module D.Jpair(Goal)(D.Jint)) ~output:(module D.Junit)
    begin fun (goal,index) ->
      let tree = ProofEngine.proof ~main:goal in
      ProofEngine.goto tree (`Leaf index) ;
      R.emit proofStatus ;
    end

let () = R.register ~package ~kind:`SET ~name:"goToNode"
    ~descr:(Md.plain "Set current node of associated proof tree")
    ~input:(module Node) ~output:(module D.Junit)
    begin fun node ->
      let tree = ProofEngine.tree node in
      ProofEngine.goto tree (`Node node) ;
      R.emit proofStatus ;
    end

let () = R.register ~package ~kind:`SET ~name:"removeNode"
    ~descr:(Md.plain "Remove node from tree and go to parent")
    ~input:(module Node) ~output:(module D.Junit)
    begin fun node ->
      let tree = ProofEngine.tree node in
      ProofEngine.remove tree node ;
      R.emit proofStatus ;
    end

(* -------------------------------------------------------------------------- *)
(* --- Sequent Indexers                                                   --- *)
(* -------------------------------------------------------------------------- *)

module Term = D.Tagged
    (struct
      type t = Lang.F.term
      let id t = Printf.sprintf "#e%d" (Lang.F.QED.id t)
    end)
    (struct let name = "term" end)

module Part = D.Tagged
    (struct
      type t = [ `Term | `Goal | `Step of int ]
      let id = function
        | `Term -> "#term"
        | `Goal -> "#goal"
        | `Step k -> Printf.sprintf "#s%d" k
    end)
    (struct let name = "part" end)

let of_part = function
  | Ptip.Term -> "#term"
  | Ptip.Goal -> "#goal"
  | Ptip.Step s -> Printf.sprintf "#s%d" s.id

let to_part sequent = function
  | `Term -> Ptip.Term
  | `Goal -> Ptip.Goal
  | `Step k ->
    try Ptip.Step (Conditions.step_at sequent k) with Not_found -> Ptip.Term

(* -------------------------------------------------------------------------- *)
(* --- Sequent Printer                                                    --- *)
(* -------------------------------------------------------------------------- *)

let wrap tag pp fmt x =
  begin
    Format.pp_open_stag fmt (Format.String_tag tag) ;
    pp fmt x ;
    Format.pp_close_stag fmt () ;
  end

class printer () : Ptip.pseq =
  let terms : Ptip.term_wrapper =
    object
      method wrap pp fmt t = wrap (Term.get t) pp fmt t
    end in
  let focus : Ptip.term_wrapper =
    object
      method wrap pp fmt t = wrap "wp:focus" pp fmt t
    end in
  let target : Ptip.term_wrapper =
    object
      method wrap pp fmt t = wrap "wp:target" pp fmt t
    end in
  let parts : Ptip.part_marker =
    object
      method wrap pp fmt p = wrap (of_part p) pp fmt p
      method mark : 'a. Ptip.part -> 'a Ptip.printer -> 'a Ptip.printer
        = fun p pp fmt x -> wrap (of_part p) pp fmt x
    end in
  let autofocus = new Ptip.autofocus in
  let plang = new Ptip.plang ~terms ~focus ~target ~autofocus in
  let pcond = new Ptip.pcond ~parts ~target:parts ~autofocus ~plang in
  Ptip.pseq ~autofocus ~plang ~pcond

(* -------------------------------------------------------------------------- *)
(* --- Printer Registry                                                   --- *)
(* -------------------------------------------------------------------------- *)

let printStatus = R.signal ~package ~name:"printStatus"
    ~descr:(Md.plain "Updated TIP printer")

module PRINTER = State_builder.Ref
    (Datatype.Make
       (struct
         include Datatype.Undefined
         type t = (string,printer) Hashtbl.t
         let name = "WpTipApi.PRINTER.Datatype"
         let reprs = [ Hashtbl.create 0 ]
         let mem_project = Datatype.never_any_project
       end))
    (struct
      let name = "WpApi.PRINTER"
      let dependencies = [ Ast.self ]
      let default () = Hashtbl.create 0
    end)

let () = Wpo.add_removed_hook
    (fun wpo ->
       let registry = PRINTER.get () in
       Hashtbl.remove registry wpo.po_gid)

let () = Wpo.add_cleared_hook
    (fun () ->
       let registry = PRINTER.get () in
       Hashtbl.clear registry)

let lookup_printer (node : ProofEngine.node) : printer =
  let tree = ProofEngine.tree node in
  let wpo = ProofEngine.main tree in
  let registry = PRINTER.get () in
  try Hashtbl.find registry wpo.po_gid with Not_found ->
    let pp = new printer () in
    Hashtbl.add registry wpo.po_gid pp ; pp

let selection node =
  let pp = lookup_printer node in
  pp#selection

(* -------------------------------------------------------------------------- *)
(* --- PrintSequent Request                                               --- *)
(* -------------------------------------------------------------------------- *)

let flags (type a) ~name ~descr tags : a R.input =
  (module struct
    type t = a
    let jtype = D.declare ~package ~name ~descr
        (P.Junion (List.map (fun (tg,_) -> P.Jtag tg) tags))
    let of_json js = List.assoc (Json.string js) tags
  end)

let iformat : Plang.iformat R.input =
  flags ~name:"iformat" ~descr:(Md.plain "Integer constants format")
    [ "dec", `Dec ; "hex", `Hex ; "bin", `Bin ]

let rformat : Plang.rformat R.input =
  flags ~name:"rformat" ~descr:(Md.plain "Real constants format")
    [ "ratio", `Ratio ; "float", `Float ; "double", `Double ]

let () =
  let printSequent = R.signature ~output:(module D.Jtext) () in
  let get_node = R.param printSequent ~name:"node"
      ~descr:(Md.plain "Proof Node") (module Node) in
  let get_indent = R.param_opt printSequent ~name:"indent"
      ~descr:(Md.plain "Number of identation spaces") (module D.Jint) in
  let get_margin = R.param_opt printSequent ~name:"margin"
      ~descr:(Md.plain "Maximial text width") (module D.Jint) in
  let get_iformat = R.param_opt printSequent ~name:"iformat"
      ~descr:(Md.plain "Integer constants format") iformat in
  let get_rformat = R.param_opt printSequent ~name:"rformat"
      ~descr:(Md.plain "Real constants format") rformat in
  let get_autofocus = R.param_opt printSequent ~name:"autofocus"
      ~descr:(Md.plain "Auto-focus mode") (module D.Jbool) in
  let get_unmangled = R.param_opt printSequent ~name:"unmangled"
      ~descr:(Md.plain "Unmangled memory model") (module D.Jbool) in
  R.register_sig ~package
    ~kind:`EXEC
    ~name:"printSequent"
    ~descr:(Md.plain "Pretty-print the associated node")
    ~signals:[printStatus] printSequent
    begin fun rq () ->
      let node = get_node rq in
      let pp = lookup_printer node in
      let indent = get_indent rq in
      let margin = get_margin rq in
      Option.iter pp#set_iformat (get_iformat rq) ;
      Option.iter pp#set_rformat (get_rformat rq) ;
      Option.iter pp#set_focus_mode (get_autofocus rq) ;
      Option.iter pp#set_unmangled (get_unmangled rq) ;
      D.jpretty ?indent ?margin pp#pp_goal (ProofEngine.goal node)
    end

(* -------------------------------------------------------------------------- *)
(* --- Selection Requests                                                 --- *)
(* -------------------------------------------------------------------------- *)

let () =
  R.register ~package
    ~kind:`SET
    ~name:"clearSelection"
    ~descr:(Md.plain "Reset node selection")
    ~input:(module Node)
    ~output:(module D.Junit)
    begin fun node ->
      let pp = lookup_printer node in
      pp#reset ; R.emit printStatus
    end

let () =
  let setSelection = R.signature ~output:(module D.Junit) () in
  let get_node = R.param setSelection ~name:"node"
      ~descr:(Md.plain "Proof Node") (module Node) in
  let get_part = R.param setSelection ~name:"part" ~default:`Term
      ~descr:(Md.plain "Selected part") (module Part) in
  let get_term = R.param_opt setSelection ~name:"term"
      ~descr:(Md.plain "Selected term") (module Term) in
  let get_extend = R.param setSelection ~name:"extend"
      ~descr:(Md.plain "Extending selection mode")
      ~default:false (module D.Jbool) in
  R.register_sig ~package
    ~kind:`SET
    ~name:"setSelection"
    ~descr:(Md.plain "Set node selection")
    setSelection
    begin fun rq () ->
      let node = get_node rq in
      let part = get_part rq in
      let term = get_term rq in
      let extend = get_extend rq in
      let pp = lookup_printer node in
      let part = to_part (fst pp#sequent) part in
      pp#restore ~focus:(if extend then `Extend else `Focus) (part,term) ;
      R.emit printStatus
    end

(* -------------------------------------------------------------------------- *)
