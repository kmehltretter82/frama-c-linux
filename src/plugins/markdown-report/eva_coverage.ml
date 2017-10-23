open Cil_types

type coverage_stats =
  { total_stmts: int;
    covered_stmts: int; }

let empty_stats =
  { total_stmts = 0;
    covered_stmts = 0 }

class eva_coverage_vis _syntactic_calls = object(self)
  inherit Visitor.frama_c_inplace
  val mutable stats = empty_stats
  val indirect_calls = Cil_datatype.Varinfo.Hashtbl.create 17

  method private incr_total_stmts =
    stats <- { stats with total_stmts = stats.total_stmts + 1 }
  method private incr_covered_stmts =
    stats <- { stats with covered_stmts = stats.covered_stmts + 1 }

  method! vstmt_aux s =
    (* We only consider real statements: Blocks do not count. *)
    match s.skind with
    | Block _ | UnspecifiedSequence _ -> Cil.DoChildren
    | _ ->
      self#incr_total_stmts;
      if Db.Value.is_reachable_stmt s then self#incr_covered_stmts;
      Cil.DoChildren

  method! vinst i =
    match i with
    | Call(_,{ enode = Lval (Mem _,NoOffset)},_,_) ->
      let s = Extlib.the self#current_stmt in
      let kfs = Db.Value.call_to_kernel_function s in
      let handle_one kf =
        let vi = Kernel_function.get_vi kf in
        if not (Cil_datatype.Varinfo.Hashtbl.mem indirect_calls vi) then begin
          Cil_datatype.Varinfo.Hashtbl.add indirect_calls vi false
        end
      in
      Kernel_function.Hptset.iter handle_one kfs;
      Cil.SkipChildren
    | _ -> Cil.SkipChildren (* No need to go further. *)

  method compute () =
    (* WRITEME: start from direct calls and iter
       if there are some indirect calls not visited yet. *)
    (Cil_datatype.Varinfo.Hashtbl.fold
       (fun k _ s -> Cil_datatype.Varinfo.Set.add k s)
       indirect_calls Cil_datatype.Varinfo.Set.empty,
     stats)

end

let md_gen () =
  let main = Kernel.MainFunction.get () in
  let syntactic_calls =
    Metrics.Metrics_coverage.compute_syntactic
      ~libc:false (Globals.Functions.find_by_name main)
  in
  !Db.Value.compute ();
  let vis = new eva_coverage_vis syntactic_calls in
  let only_indirect_calls, coverage_stats = vis#compute () in
  let summary =
    Markdown.plain_format
      "There were potentially %d functions syntactically reachable from %s."
      (Cil_datatype.Varinfo.Set.cardinal syntactic_calls) main
  in
  let summary =
    if Cil_datatype.Varinfo.Set.is_empty only_indirect_calls then summary
    else
      summary @
      Markdown.plain_format
        "In addition, %d were found potentially reachable through \
         indirect calls"
        (Cil_datatype.Varinfo.Set.cardinal only_indirect_calls)
  in
  let summary =
    summary @
    Markdown.plain_format
      "These functions contain %d statements, \
       of which %d are potentially reachable according to EVA, resulting in \
       a **statement coverage of %.1f%%**"
      coverage_stats.total_stmts coverage_stats.covered_stmts
      (float_of_int coverage_stats.covered_stmts *. 100. /.
       float_of_int coverage_stats.total_stmts)
  in
  Markdown.([ Block [ Text summary ]])
