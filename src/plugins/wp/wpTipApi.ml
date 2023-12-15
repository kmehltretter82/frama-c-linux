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
(* --- Signals                                                            --- *)
(* -------------------------------------------------------------------------- *)

let proofStatus = R.signal ~package ~name:"proofStatus"
    ~descr:(Md.plain "Proof Status has changed")

let printStatus = R.signal ~package ~name:"printStatus"
    ~descr:(Md.plain "Updated TIP printer")

(* -------------------------------------------------------------------------- *)
(* --- Proof Node                                                         --- *)
(* -------------------------------------------------------------------------- *)

module Node = D.Index
    (Map.Make(ProofEngine.Node))
    (struct
      let package = package
      let name = "node"
      let descr = Md.plain "Proof Node index"
    end)

module Tactic : D.S with type t = Tactical.t =
struct
  type t = Tactical.t
  let jtype = D.declare ~package ~name:"tactic"
      ~descr:(Md.plain "Tactic identifier") @@ P.Jkey "tactic"
  let to_json (t : Tactical.t) = `String t#id
  let of_json (js : Json.t) = Tactical.lookup ~id:(js |> Json.string)
end

module Path = D.Jlist(Node)

let () =
  let inode = R.signature ~input:(module Node) () in
  let set_title = R.result inode ~name:"title"
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
  let set_tactic = R.result_opt inode ~name:"tactic"
      ~descr:(Md.plain "Applied tactic (if any)")
      (module Tactic) in
  let set_header = R.result_opt inode ~name:"header"
      ~descr:(Md.plain "Proof node tactic label (if any)")
      (module D.Jstring) in
  let set_child = R.result_opt inode ~name:"child"
      ~descr:(Md.plain "Proof node child label (from parent, if any)")
      (module D.Jstring) in
  let set_path = R.result inode ~name:"path"
      ~descr:(Md.plain "Proof node path from goal")
      (module Path) in
  let set_children = R.result inode ~name:"children"
      ~descr:(Md.plain "Proof node tactic children (id any)")
      (module Path) in
  R.register_sig ~package ~kind:`GET ~name:"getNodeInfos"
    ~descr:(Md.plain "Proof node information") inode
    ~signals:[proofStatus]
    begin fun rq node ->
      set_title rq (ProofEngine.title node) ;
      set_proved rq (ProofEngine.proved node) ;
      set_pending rq (ProofEngine.pending node) ;
      let s = ProofEngine.stats node in
      let tactic = ProofEngine.tactic node in
      let header = ProofEngine.tactic_label node in
      let child = ProofEngine.child_label node in
      set_size rq (Stats.subgoals s) ;
      set_stats rq (Pretty_utils.to_string Stats.pretty s) ;
      set_results rq (Wpo.get_results (ProofEngine.goal node)) ;
      set_tactic rq tactic ;
      set_header rq header ;
      set_child rq child ;
      set_path rq (ProofEngine.path node) ;
      set_children rq (ProofEngine.subgoals node) ;
    end

(* -------------------------------------------------------------------------- *)
(* --- Proof Cursor                                                       --- *)
(* -------------------------------------------------------------------------- *)

let () =
  let state = R.signature ~input:(module Goal) () in
  let set_index = R.result state ~name:"index"
      ~descr:(Md.plain "Current node index among pending nodes (else -1)")
      (module D.Jint) in
  let set_pending = R.result state ~name:"pending"
      ~descr:(Md.plain "Pending proof nodes") (module D.Jint) in
  let set_current = R.result state ~name:"current"
      ~descr:(Md.plain "Current proof node") (module Node) in
  let set_above = R.result state ~name:"above"
      ~descr:(Md.plain "Above nodes (up to current when internal)")
      (module Path) in
  let set_below = R.result state ~name:"below"
      ~descr:(Md.plain "Below nodes (including current when pending)")
      (module Path) in
  let set_tactic = R.result_opt state ~name:"tactic"
      ~descr:(Md.plain "Applied tactic (if any)")
      (module Tactic) in
  R.register_sig ~package
    ~kind:`GET ~name:"getProofStatus"
    ~descr:(Md.plain "Current Proof Status of a Goal") state
    ~signals:[proofStatus]
    begin fun rq wpo ->
      let tree = ProofEngine.proof  ~main:wpo in
      let root = ProofEngine.root tree in
      set_pending rq (ProofEngine.pending root) ;
      let current, index =
        match ProofEngine.current tree with
        | `Main -> root, -1
        | `Internal node -> node, -1
        | `Leaf(idx,node) -> node, idx
      in
      set_index rq index ;
      set_current rq current ;
      set_tactic rq @@ ProofEngine.tactic current ;
      let above = ProofEngine.path current in
      let below = ProofEngine.subgoals current in
      if below = [] then
        match above with
        | [] ->
          set_above rq [] ;
          set_below rq [] ;
        | p::_ ->
          set_above rq above ;
          set_below rq (ProofEngine.subgoals p) ;
      else
        begin
          set_above rq (current::above) ;
          set_below rq below ;
        end
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
      ProofEngine.goto tree (`Node node) ;
      ProofEngine.validate tree ;
      S.update WpApi.goals @@ ProofEngine.main tree ;
      R.emit proofStatus ;
    end

(* -------------------------------------------------------------------------- *)
(* --- Sequent Indexers                                                   --- *)
(* -------------------------------------------------------------------------- *)

module Part = D.Tagged
    (struct
      type t = [ `Term | `Goal | `Step of int ]
      let id = function
        | `Term -> "#term"
        | `Goal -> "#goal"
        | `Step k -> Printf.sprintf "#s%d" k
    end)
    (struct
      let package = package
      let name = "part"
      let descr = Md.plain "Proof part marker"
    end)

module Term = D.Tagged
    (struct
      type t = Lang.F.term
      let id t = Printf.sprintf "#e%d" (Lang.F.QED.id t)
    end)
    (struct
      let package = package
      let name = "term"
      let descr = Md.plain "Term marker"
    end)

let of_part = function
  | Ptip.Term -> `Term
  | Ptip.Goal -> `Goal
  | Ptip.Step s -> `Step s.id

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
      method wrap pp fmt t = wrap "wp:focus" (terms#wrap pp) fmt t
    end in
  let target : Ptip.term_wrapper =
    object
      method wrap pp fmt t = wrap "wp:target" (terms#wrap pp) fmt t
    end in
  let parts : Ptip.part_marker =
    object
      method wrap pp fmt p = wrap (Part.get @@ of_part p) pp fmt p
      method mark : 'a. Ptip.part -> 'a Ptip.printer -> 'a Ptip.printer
        = fun p pp fmt x -> wrap (Part.get @@ of_part p) pp fmt x
    end in
  let target_part : Ptip.part_marker =
    object
      method wrap pp fmt p = wrap "wp:target" (parts#wrap pp) fmt p
      method mark : 'a. Ptip.part -> 'a Ptip.printer -> 'a Ptip.printer
        = fun p pp fmt x -> wrap "wp:target" (parts#mark p pp) fmt x
    end in
  let autofocus = new Ptip.autofocus in
  let plang = new Ptip.plang ~terms ~focus ~target ~autofocus in
  let pcond = new Ptip.pcond ~parts ~target:target_part ~autofocus ~plang in
  Ptip.pseq ~autofocus ~plang ~pcond

(* -------------------------------------------------------------------------- *)
(* --- Printer Registry                                                   --- *)
(* -------------------------------------------------------------------------- *)

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

let selection node = (lookup_printer node)#selection

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
  let get_node = R.param_opt printSequent ~name:"node"
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
    ~kind:`GET
    ~name:"printSequent"
    ~descr:(Md.plain "Pretty-print the associated node")
    ~signals:[printStatus] printSequent
    begin fun rq () ->
      match get_node rq with
      | None -> D.jtext ""
      | Some node ->
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
      pp#reset ;
      pp#selected ;
      R.emit printStatus
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

let () =
  let getSelection = R.signature ~input:(module Node) () in
  let set_part = R.result_opt getSelection ~name:"part"
      ~descr:(Md.plain "Selected part") (module Part) in
  let set_term = R.result_opt getSelection ~name:"term"
      ~descr:(Md.plain "Selected term") (module Term) in
  R.register_sig ~package
    ~kind:`GET
    ~name:"getSelection"
    ~descr:(Md.plain "Get current selection in proof node")
    ~signals:[printStatus;proofStatus]
    getSelection
    begin fun rq node ->
      let (part,term) = (lookup_printer node)#target in
      set_part rq (if part <> Term then Some (of_part part) else None);
      set_term rq term;
    end

(* -------------------------------------------------------------------------- *)
