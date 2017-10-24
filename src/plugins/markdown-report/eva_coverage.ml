open Cil_types

type coverage_stats =
  { syntactic_calls: int;
    indirect_calls: int;
    total_stmts: int;
    covered_stmts: int; }

let add_syntactic_call stats =
  { stats with syntactic_calls = stats.syntactic_calls + 1 }

let add_indirect_call stats =
  { stats with indirect_calls = stats.indirect_calls + 1 }

let empty_stats =
  { syntactic_calls = 0;
    indirect_calls = 0;
    total_stmts = 0;
    covered_stmts = 0 }

type callee_info = { has_direct_call: bool; is_analyzed: bool; visited: bool; }

let indirect_call =
  { has_direct_call = false; is_analyzed = false; visited = false; }

let direct_call = { indirect_call with has_direct_call = true }

let visit info = { info with visited = true; }

let is_analyzed_function vi =
  not (Cil.hasAttribute "fc_stdlib" vi.vattr) &&
  not (Cil.hasAttribute "fc_stdlib_generated" vi.vattr) &&
  not (List.mem vi.vname
         (String.split_on_char ','
            (Dynamic.Parameter.String.get "-val-use-spec" ()))) &&
  not (List.mem vi.vname
         (List.map
            (fun s -> List.hd (String.split_on_char ':' s))
            (String.split_on_char ','
               (Dynamic.Parameter.String.get "-val-builtin" ()))))

let is_analyzed_info vi info = {info with is_analyzed=is_analyzed_function vi; }


class eva_coverage_vis = object(self)
  inherit Visitor.frama_c_inplace
  val mutable stats = empty_stats
  val calls = Cil_datatype.Varinfo.Hashtbl.create 17

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
    | Call(_, { enode = Lval (Var vi, NoOffset)},_,_) ->
      if Cil_datatype.Varinfo.Hashtbl.mem calls vi then begin
        let info = Cil_datatype.Varinfo.Hashtbl.find calls vi in
        Cil_datatype.Varinfo.Hashtbl.replace
          calls vi { info with has_direct_call = true }
      end else begin
        Cil_datatype.Varinfo.Hashtbl.add
          calls vi (is_analyzed_info vi direct_call)
      end;
      Cil.SkipChildren
    | Call(_,{ enode = Lval (Mem _,NoOffset)},_,_) ->
      let s = Extlib.the self#current_stmt in
      let kfs = Db.Value.call_to_kernel_function s in
      let handle_one kf =
        let vi = Kernel_function.get_vi kf in
        if not (Cil_datatype.Varinfo.Hashtbl.mem calls vi)
        then begin
          Cil_datatype.Varinfo.Hashtbl.add
            calls vi (is_analyzed_info vi indirect_call)
        end
      in
      Kernel_function.Hptset.iter handle_one kfs;
      Cil.SkipChildren
    | _ -> Cil.SkipChildren (* No need to go further. *)

  method compute () =
    let treat_call vi info reached =
      let must_visit = not info.visited && info.is_analyzed in
      Cil_datatype.Varinfo.Hashtbl.replace calls vi (visit info);
      if must_visit then begin
        let kf = Globals.Functions.get vi in
        ignore (Visitor.visitFramacKf (self:>Visitor.frama_c_inplace) kf)
      end;
      reached && not must_visit
    in
    let check_fixpoint () =
      Cil_datatype.Varinfo.Hashtbl.fold treat_call calls true
    in
    let vi =
      Globals.Functions.get_vi
        (Globals.Functions.find_by_name (Kernel.MainFunction.get()))
    in
    Cil_datatype.Varinfo.Hashtbl.add calls vi (is_analyzed_info vi direct_call);
    while not (check_fixpoint ()) do () done;
    Cil_datatype.Varinfo.Hashtbl.fold
      (fun _ info stats ->
         if info.has_direct_call then add_syntactic_call stats
         else add_indirect_call stats)
      calls
      stats

end

let md_gen () =
  let main = Kernel.MainFunction.get () in
  !Db.Value.compute ();
  let vis = new eva_coverage_vis in
  let stats = vis#compute () in
  let summary =
    Markdown.plain_format
      "There were potentially %d functions syntactically reachable from %s."
      stats.syntactic_calls main
  in
  let summary =
    if stats.indirect_calls = 0 then summary
    else
      summary @
      Markdown.plain_format
        "In addition, %d were found potentially reachable through \
         indirect calls."
        stats.indirect_calls
  in
  let summary =
    summary @
    Markdown.plain_format
      "These functions contain %d statements, \
       of which %d are potentially reachable according to EVA, resulting in \
       a **statement coverage of %.1f%%** with respect to the perimeter set \
       by syntactic calls."
      stats.total_stmts stats.covered_stmts
      (float_of_int stats.covered_stmts *. 100. /.
       float_of_int stats.total_stmts)
  in
  Markdown.([ Block [ Text summary ]])
