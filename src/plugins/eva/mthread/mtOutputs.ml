(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2025                                               *)
(*    CEA (Commissariat à l'énergie atomique et aux énergies              *)
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
open MtTypes
open MtThread

module Utilities = struct

  let mk_translation_tbl l =
    List.fold_left
      (fun smap (s1,s2) ->
         Datatype.String.Map.add s1 s2 smap)
      Datatype.String.Map.empty l
  ;;

  (* Outputs are done in separate buffers then assembled together.
     The following allows to maintain some kind of consistency
     in buffer creations.
  *)
  let default_buffer_size = 2048;;


  let mk_buffer_formatter () =
    let b = Buffer.create default_buffer_size
    in
    b, Format.formatter_of_buffer b
  ;;

  let _escape_string special_chars =
    Str.global_replace special_chars "\\\\\\\\0"
  ;;

  let replace_chars ttable s =
    let buf = Buffer.create ((String.length s) * 2 ) in
    String.iter
      (fun c ->
         let s = Format.sprintf "%c" c in
         let ts =
           try
             Datatype.String.Map.find s ttable
           with Not_found -> s
         in Buffer.add_string buf ts
      ) s;
    buf
  ;;

  exception FramaCModelCheckingExec of string ;;

  let _run_cmd cmd =
    MtOptions.feedback "Running %s@."cmd;
    if Sys.command cmd <> 0 then
      let msg = Format.sprintf "Something happened when executing %s@." cmd in
      raise (FramaCModelCheckingExec(msg))
  ;;

  let rec _list_unique cmp l =
    match l with
    | [] -> []
    | x :: xs ->
      x :: _list_unique cmp (List.filter (fun e -> cmp x e <> 0) xs)
  ;;

  let _list_equal feq l1 l2 =
    try  List.for_all2 feq l1 l2
    with Invalid_argument _ -> false
  ;;
end


(** Module to produce HTML output *)
module Html = struct

  let escape = Extlib.html_escape

  let pretty_escaped pp fmt v =
    let s = Format.asprintf "%a" pp v in
    let s = escape s in
    Format.pp_print_string fmt s

  let dot_escape s =
    let translation_table =
      Utilities.mk_translation_tbl
        (List.map (fun s -> (s,"_"))
           ["&"; "+"; "["; "]"; "."]
        )
    in
    Utilities.replace_chars translation_table s
  ;;


  (* Formatting html with Format.formatters *)
  let html_stag_functions : Format.formatter_stag_functions =
    let mark_open_stag t = Format.sprintf "<%s>" (Extlib.format_string_of_stag t)
    and mark_close_stag t =
      let t = Extlib.format_string_of_stag t in
      try
        let index = String.index t ' ' in
        Format.sprintf "</%s>" (String.sub t 0 index)
      with
      | Not_found -> Format.sprintf "</%s>" t
    and print_open_stag _ = ()
    and print_close_stag _ = ()
    in
    { Format.mark_open_stag = mark_open_stag;
      Format.mark_close_stag = mark_close_stag;
      Format.print_open_stag = print_open_stag;
      Format.print_close_stag = print_close_stag;
    }
  ;;

  type html_page = {
    page_title: string;
    page_name: string;
    (* the buffer contains the html code of the page *)
    page_buffer: Buffer.t;
    (* formatter of the previous buffer to use with Format *)
    page_fmt: Format.formatter;
  }
  ;;

  let mk_html_page title name =
    let b, fmt = Utilities.mk_buffer_formatter () in
    { page_title = title;
      page_name = name;
      page_buffer = b;
      page_fmt = fmt;
    }
  ;;

  let html_fname html_page = escape html_page.page_name ^ ".html";;


  type html_div = {
    title : string;
    contents : Buffer.t;
    div_fmt : Format.formatter;
  }
  ;;

  let empty_string = "&nbsp;"

  let mk_div s =
    let b, fmt = Utilities.mk_buffer_formatter () in
    Format.pp_set_formatter_stag_functions fmt html_stag_functions;
    Format.pp_set_tags fmt true;
    { title = s; contents =  b; div_fmt = fmt; }
  ;;

  let pp_div fmt div =
    Format.pp_set_formatter_stag_functions fmt html_stag_functions;
    Format.pp_set_tags fmt true;
    Format.fprintf fmt
      "@[@{<div class=\"\"><h3>@ %s</h3>@ %s @}@]@?"
      div.title
      (Buffer.contents div.contents)
  ;;

  module Biassoc (K : Datatype.S_with_collections) =
  struct
    (* Bidirectional association tables *)
    type 'a t = {
      to_id : 'a K.Hashtbl.t;
      from_id : ('a,K.t) Hashtbl.t;
    }

    let mk n =
      { to_id = K.Hashtbl.create n;
        from_id = Hashtbl.create n;
      }
  end

  module Table (Row : Datatype.S_with_collections) (Col : Datatype.S_with_collections) =
  struct
    module Rows = Biassoc (Row)
    module Cols = Biassoc (Col)

    type 'a html_table = {
      rows : int Rows.t;
      columns : int Cols.t;
      tbl_contents : 'a array array;
      row_size : int;
      col_size : int;
    }

    let mk row_list col_list =
      let row_length = List.length row_list in
      let rows = Rows.mk row_length in
      let col_length = List.length col_list in
      let cols = Cols.mk col_length in

      List.iteri
        (fun i k ->
           Row.Hashtbl.add rows.to_id k i;
           Hashtbl.add rows.from_id i k;
        ) row_list;

      List.iteri
        (fun i k ->
           Col.Hashtbl.add cols.to_id k i;
           Hashtbl.add cols.from_id i k;
        ) col_list;

      { rows = rows;
        columns = cols;
        tbl_contents = Array.make_matrix row_length col_length empty_string ;
        row_size = row_length;
        col_size = col_length;
      }
    ;;

    (* Mark a set of actions according to a marking function
       in a HTML table
    *)
    let mark_action_set mark_fun table action_idtbl =
      Col.Hashtbl.iter_sorted
        (fun k aset ->
           try
             let col = Col.Hashtbl.find table.columns.to_id k in
             EventsSet.iter
               (fun a ->
                  let id, mark = mark_fun a in
                  let row = Row.Hashtbl.find table.rows.to_id id in
                  table.tbl_contents.(row).(col) <-
                    table.tbl_contents.(row).(col) ^ mark;
               ) aset
           with
           | Not_found -> assert false
        ) action_idtbl

    (* Pretty print a html table *)
    let pretty ~pp_row_head ~pp_col_head ~pp_cell ~caption ~legend fmt table =
      let pp_row fmt i =
        let row =
          try
            Hashtbl.find table.rows.from_id i
          with
          | Not_found ->
            MtOptions.fatal "@[Row %d not found@]@." i
        in

        let pp_cells fmt cell_array =
          Array.iter
            (Format.fprintf fmt "@ @[@{<td class=\"plop\">@ %a@ @}@]" pp_cell)
            cell_array

        in Format.fprintf fmt
          "@[<v 1>\
           @{<tr>@ \
           @{<th>%a@}\
           %a\
           @}\
           @]"
          pp_row_head row
          pp_cells table.tbl_contents.(i)
      in

      let rec pp_rows fmt i  =
        if i = table.row_size then Format.fprintf fmt ""
        else Format.fprintf fmt "@[<v 0>%a@ %a@]"
            pp_row i
            pp_rows (i+1)
      in

      let pp_headers fmt =
        let rec aux_pp_hdr fmt i =
          if i = table.col_size then Format.fprintf fmt ""
          else Format.fprintf fmt "@ @{<th>%a@}%a"
              pp_col_head (Hashtbl.find table.columns.from_id i)
              aux_pp_hdr (i+1)
        in Format.fprintf fmt
          "@[<v 1>@{<tr>@ \
           @{<td>%s@}%a\
           @}@]"
          legend
          aux_pp_hdr 0

      in
      Format.pp_set_tags fmt true;
      Format.pp_set_formatter_stag_functions fmt html_stag_functions;
      Format.fprintf fmt "@[<hov 1>@[@{<caption>%s@ @}@ @[%t@]@ %a@]@]@?"
        caption
        pp_headers
        pp_rows 0
  end

  module LockTable = Table (Mutex) (Thread)
  module MutexTable = Table (Mutex) (Thread)
  module QueueTable = Table (Mqueue) (Thread)

  (* Generate the set of lock taken in the program by all threads/processes
     And a hash table associating threads to locking procedures (take, release
     ...)
  *)
  let gen_locks_summary th_list =
    let lock_table = Thread.Hashtbl.create (List.length th_list) in
    let lockset =
      List.fold_left
        (fun lockset th ->
           let th_lockset = ref EventsSet.empty in
           let global_lockset =
             Trace.fold' th.th_amap
               (fun action lockset ->
                  match action with
                  | MutexRelease id
                  | MutexLock id ->
                    th_lockset := EventsSet.add action !th_lockset;
                    Mutex.Set.add id lockset
                  | _ -> lockset
               ) lockset
           in Thread.Hashtbl.add lock_table th.th_eva_thread !th_lockset;
           global_lockset
        )  Mutex.Set.empty th_list
    in
    if Mutex.Set.is_empty lockset then None
    else begin
      let lock_olist =
        Mutex.Set.elements lockset |>
        List.map (fun m -> Mutex.label m, m) |>
        List.fast_sort (fun (s1,_) (s2,_) -> String.compare s1 s2) |>
        List.map snd
      in
      Some (lock_table, LockTable.mk lock_olist (List.map (fun th -> th.th_eva_thread) th_list))
    end
  ;;

  (* Generate the set of fifos used in the program
     Mark the uses in a html table
     Also yields a hash table id -> fifo uses
  *)
  let gen_mqueues_summary th_list =
    let mq_table = Thread.Hashtbl.create (List.length th_list) in
    let queue_set =
      List.fold_left
        (fun queue_set th ->
           let th_queue_set = ref EventsSet.empty in
           let global_queue_set =
             Trace.fold' th.th_amap
               (fun action queue_set ->
                  match action with
                  | SendMsg (q, _)
                  | CreateQueue (q, _)
                  | ReceiveMsg (q, _, _) ->
                    th_queue_set := EventsSet.add action !th_queue_set;
                    Mqueue.Set.add q queue_set
                  | _ -> queue_set
               ) queue_set
           in Thread.Hashtbl.add mq_table th.th_eva_thread !th_queue_set;
           global_queue_set
        ) Mqueue.Set.empty th_list
    in
    (* Returns mothing when there is no queue in the program *)
    if Mqueue.Set.is_empty queue_set then None
    else begin
      let queue_olist =
        Mqueue.Set.elements queue_set |>
        List.map (fun m -> Mqueue.label m, m) |>
        List.fast_sort (fun (s1,_) (s2,_) -> String.compare s1 s2) |>
        List.map snd
      in
      assert ((Thread.Hashtbl.length mq_table) > 0);
      MtOptions.debug "%d queues found@." (Thread.Hashtbl.length mq_table);
      Some (mq_table, QueueTable.mk queue_olist (List.map (fun th -> th.th_eva_thread) th_list));
    end
  ;;


  (* Columns are thread name, rows are locks *)
  let mark_lock_actions =
    MutexTable.mark_action_set
      (fun action ->
         match action with
         | MutexRelease m -> m, "V"
         | MutexLock m -> m, "P"
         | _ -> assert false
         (* This action set is generated by gen_locks_summary
            and should only containt lock-related constructors
         *)
      )
  ;;

  let mark_mqueue_actions =
    QueueTable.mark_action_set
      (fun action ->
         match action with
         | SendMsg (id, _) -> id, "S"
         |  ReceiveMsg (id, _, _) -> id, "R"
         | CreateQueue (id, _) -> id, "C"
         | _ -> assert false
         (* This action set is generated by gen_mqueues_summary
            and should only containt queue-related constructors
         *)
      )
  ;;

  (* Generate the html table for lock take/release actions *)
  let mk_locks_summary div th_list =
    let b, fmt = div.contents, div.div_fmt in
    Format.pp_set_tags fmt true;
    match gen_locks_summary th_list with
    | None -> b
    | Some(lock_table, html_table) ->
      mark_lock_actions html_table lock_table;
      let pp_table =
        LockTable.pretty
          ~pp_row_head:Mutex.pretty
          ~pp_col_head:Thread.pretty
          ~pp_cell: Format.pp_print_string
          ~caption: "P = lock taken, V = lock released"
          ~legend: "uses lock &larr;<br/> &darr;"
      in
      Format.fprintf fmt
        "@[<v 1>\
         @{<h3>%s@}@ \
         @{<table>@ %a@ @}</table>\
         @]@?"
        div.title
        pp_table html_table;
      b
  ;;

  (* Generate the html table for write/receive fifo summaries *)
  let mk_mqueues_summary div th_list =
    match gen_mqueues_summary th_list with
    | None -> div.contents
    | Some (queue_idtbl, html_table) ->
      (* Only print when there is something to be said *)
      Format.pp_set_tags div.div_fmt true;
      mark_mqueue_actions html_table queue_idtbl;
      let pp_table =
        QueueTable.pretty
          ~pp_row_head:Mqueue.pretty
          ~pp_col_head:Thread.pretty
          ~pp_cell: Format.pp_print_string
          ~caption: "R = queue read, S = queue written, C = queue created"
          ~legend: "uses lock &larr;<br/> &darr;"
      in
      Format.fprintf div.div_fmt
        "@[<v 1>@ \
         @{<h3>%s@}@ \
         @{<table>@ %a@ @}</table>@]@?"
        div.title
        pp_table html_table;
      div.contents;
  ;;

  (* Output a small global summary :
     number of threads and their names
  *)
  let mk_global_summary th_list page_table =
    let b, fmt = Utilities.mk_buffer_formatter () in
    let th_buf, th_fmt = Utilities.mk_buffer_formatter () in
    Format.pp_set_tags fmt true;
    Format.pp_set_tags th_fmt true;
    Format.fprintf th_fmt "@[<v>";
    List.iter
      (fun th ->
         Format.fprintf th_fmt
           "@[ <li><a href=\"%s\">%a</a></li>@]@ "
           (html_fname (Thread.Hashtbl.find page_table th.th_eva_thread))
           (pretty_escaped ThreadState.pretty) th;
      ) th_list;
    Format.fprintf th_fmt "@]@.";
    Format.fprintf fmt "@[<v 1>@[\
                        @{<h1> Summary @}@ \
                        <br/>@ \
                        This program has %d thread(s)@ \
                        @ @{<ul>@ %s @}@]@]@?"
      (List.length th_list)
      (Buffer.contents th_buf);
    b
  ;;


  (* Some defaults *)

  let default_dir = "html_summary";;
  let main_page_name = "index";;
  let footer_links = mk_div "Go to thread";;
  let stmt_link s = Printf.sprintf "sid%d" s.sid

  (* Turns unicode mode off and returns original value *)
  let suspend_unicode () =
    let unicode = Kernel.Unicode.get () in
    Kernel.Unicode.off ();
    unicode
  ;;

  let mk_graph_img th =
    let unicode = suspend_unicode () in
    let f_stmt s = Format.sprintf "code.html#%s" (stmt_link s) in
    let thread_name = Thread.label th.th_eva_thread |> MtLib.sanitize_filename in
    let tmp_file, otmp =  Filename.open_temp_file (thread_name ^ "-") ".dot" in
    let fmt = Format.formatter_of_out_channel otmp in
    MtCfg.dot_fprint_graph fmt th.th_cfg f_stmt;
    close_out otmp;
    let dot_output_format = "svg" in
    let link_fname =
      (Format.asprintf "%s.%s" thread_name dot_output_format) in
    let output_file = Filename.concat default_dir link_fname in
    let args = [ "-Tsvg"; tmp_file; "-o"; output_file ] in
    let fail s =
      MtOptions.error "%s when generating graph for thread %a. \
                       Run 'dot %s' to restart generation"
        s ThreadState.pretty th (String.concat " " args)
    in
    begin
      try
        let ret = Command.command ~timeout:60 "dot" (Array.of_list args) in
        match ret with
        | Unix.WEXITED 0 ->
          MtOptions.debug "remove %s\n" tmp_file;
          Sys.remove tmp_file
        | Unix.WEXITED code ->
          fail (Printf.sprintf "Error (code %d)" code)
        | Unix.WSIGNALED id -> fail (Printf.sprintf "Signal %d" id)
        | Unix.WSTOPPED id ->
          fail (Printf.sprintf "Process stopped (signal %d)" id)
      with
      | Sys_error s -> fail (Printf.sprintf "Error (%s)" s)
      | Async.Cancel -> fail "Timeout or user interruption"
    end;
    Kernel.Unicode.set unicode;
    link_fname
  ;;

  let mk_thread_graph th_list =
    let module ThreadInheritanceGraph = struct
      include (Graph.Imperative.Digraph.Concrete(Thread))
      let graph_attributes _ = []
      let default_vertex_attributes _ = []
      let vertex_name v =
        let s = Format.asprintf "%a" Thread.pretty v in
        Buffer.contents (dot_escape s)
      let vertex_attributes v =
        let s = Format.asprintf "%a" Thread.pretty v in
        [ `Label (MtLib.escape_non_utf8 s)]
      let get_subgraph _ = None
      let default_edge_attributes _ = [`Style(`Solid);]
      let edge_attributes _ = []
    end
    in
    let graph = ThreadInheritanceGraph.create ~size:(List.length th_list) () in
    List.iter
      (fun th ->
         match th.th_parent with
         | None -> ThreadInheritanceGraph.add_vertex graph th.th_eva_thread;
         | Some parent -> ThreadInheritanceGraph.add_edge graph parent.th_eva_thread th.th_eva_thread
      ) th_list;
    let module TGDot = Graph.Graphviz.Dot(ThreadInheritanceGraph) in
    let unicode = suspend_unicode () in
    let name = "thread_inheritance_graph" in
    let tmp_file, otmp = Filename.open_temp_file name ".dot" in
    MtOptions.debug "Open %s for writing@." tmp_file;
    let fmt = Format.formatter_of_out_channel otmp in
    TGDot.fprint_graph fmt graph;
    close_out otmp;
    let dot_output_format = "svg" in
    let link_fname = Format.sprintf "%s.%s" name dot_output_format in
    let output_file = Filename.concat default_dir link_fname in
    let cmd = Format.sprintf "dot -T%s '%s' -o '%s'"
        dot_output_format tmp_file output_file in
    let ret = Sys.command cmd in
    if ret <> 0 then
      MtOptions.error "Something bad happened when running %s" cmd;
    MtOptions.debug "remove %s\n" tmp_file;
    Sys.remove tmp_file;
    Kernel.Unicode.set unicode;
    link_fname
  ;;

  let mk_thread_graph_div div th_list =
    let b, fmt = div.contents, div.div_fmt in
    let img = mk_thread_graph th_list in
    Format.fprintf fmt "@[<v 0>@{<div> \
                        @{<h3>%s@}\
                        @{<object data=\"%s\" width=\"700\" \
                        height=\"250\" type=\"image/svg+xml\"> @}\
                        @{<a href=\"%s\"> Direct link @}\
                        @}@]@?"
      div.title img img;
    b;
  ;;

  let pp_image_link fmt th =
    let img = mk_graph_img th in
    Format.fprintf fmt
      "@{<embed src=\"%s\" width=\"700\" \
       height=\"600\" type=\"image/svg+xml\" />\
       <br /> \
       <a href=\"%s\" >Direct link</a>"
      img img
  ;;

  let pp_thread_details html_page main_page th  =
    let fmt = html_page.page_fmt in
    Format.pp_set_tags fmt true;
    Format.fprintf fmt
      "@[<v 1>@ \
       @[<v 1>@{<div>@ \
       @{<h1><a name=\"%s\">%a</a>@}\
       @]@ \
       @[<hov 1>@{<div class=\"graph\">%a@}@]@ \
       @}\
       <br/>@ %a@ \
       <br/>@ @{<h3 class=\"back\">Back to @{<a href=\"%s\">index@}@}\
       @]@]@?"
      (escape html_page.page_name)
      ThreadState.pretty th
      pp_image_link th
      pp_div footer_links
      (html_fname main_page)
    ;
    Format.pp_print_flush fmt ();
  ;;


  (* Lazy to avoid messages when mthread is not launched, or the css
     not needed *)
  let css_content =
    lazy (
      let css_file =
        (MtOptions.MThread.Share.get_file "mthread.css" :> string)
      in
      try
        let ic = open_in css_file in
        let ic_length = in_channel_length ic in
        let b = Buffer.create ic_length in
        Buffer.add_channel b ic ic_length;
        close_in ic;
        Buffer.contents b
      with Sys_error _ ->
        MtOptions.warning "Cannot open mthread css '%s'" css_file;
        ""
    )
  ;;


  let pp_page page =
    let file = Filename.concat default_dir page.page_name ^ ".html" in
    MtOptions.debug "Open %s@." file;
    let ofile = open_out file in
    let fmt = Format.formatter_of_out_channel ofile in
    Format.pp_set_formatter_stag_functions fmt html_stag_functions;
    Format.pp_set_tags fmt true;

    Format.fprintf fmt "@[<v 1>\
                        <!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 4.01//EN\"\
                        \"http://www.w3.org/TR/html4/strict.dtd\">@ \
                        @{<html>@ \
                        @{<head>@ \
                        @{<title>%s@}@ \
                        <meta content=\"text/html; charset=iso-8859-1\" \
                        http-equiv=\"Content-Type\">@ \
                        @{<style type=\"text/css\">%s@}@}@ \
                        @{<body>@ %s@ \
                        @}@}@}@]@?"
      page.page_title
      (Lazy.force css_content)
      (Buffer.contents page.page_buffer);
    close_out ofile;
  ;;

  let mk_main_page page page_table th_list =
    (* Do the main page *)
    let buf_init, _fmt_init = page.page_buffer, page.page_fmt in
    let buf_append = Buffer.add_buffer buf_init in
    (* Generate the main page *)
    Buffer.add_string buf_init "<!--(* Generated my mthread *)-->";
    buf_append (mk_global_summary th_list page_table);
    (* Graph for thread creation *)
    buf_append (mk_thread_graph_div (mk_div "Thread creation graph") th_list);
    (* Table for lock uses *)
    buf_append (mk_locks_summary (mk_div "Lock operations") th_list);
    (* Table for queue uses *)
    buf_append (mk_mqueues_summary (mk_div "Queue operations") th_list);
  ;;

  class tagPrinterClass = object(self)
    inherit Printer.extensible_printer () as super

    method! next_stmt next fmt current =
      Format.fprintf fmt "@{<span id=\"sid%d\">%a@}"
        current.sid
        (super#next_stmt next) current

    method! stmtkind sattr s fmt skind =
      let print_as_is = Cil_printer.state.Printer_api.print_cil_as_is in
      (* Ugly hack to correctly print while(1) conditionals *)
      (match skind with
       | Loop _ -> Cil_printer.state.Printer_api.print_cil_as_is  <- true
       | _ -> ()
      );
      super#stmtkind sattr s fmt skind;
      Cil_printer.state.Printer_api.print_cil_as_is <- print_as_is

    method! varinfo fmt (v:varinfo) =
      let vclass =
        if Ast_types.is_fun v.vtype then "varinfo_fun" else "varinfo"
      in
      Format.fprintf fmt "@{<a class=\"%s\" href=\"#vid%d\">%a@}"
        vclass v.vid self#varname v.vname

    method! vdecl fmt (v:varinfo) =
      Format.fprintf fmt "@{<span class=\"vdecl\" id=\"vid%d\">%a@}"
        v.vid super#vdecl v

(*
    method! global fmt (g:global) =
      match g with
        | GVarDecl (v, _) when v.vstorage <> Extern -> ()
        | _ -> super#global fmt g
*)

  end


  let ast_to_html file =
    let page = mk_html_page "Source code" file in
    let fmt = page.page_fmt in
    Format.pp_set_formatter_stag_functions fmt html_stag_functions;
    Format.pp_set_tags fmt true;
    let pp = new tagPrinterClass in
    Format.fprintf fmt "@{<pre>@.%a@}@?" pp#file (Ast.get ());
    pp_page page
  ;;

  let output_threads analysis =
    let th_list = List.filter should_compute_thread (threads analysis) in
    let page_table, add_page, find_page =
      let module PageTable = Thread.Hashtbl in
      let page_table =
        PageTable.create (List.length th_list) in
      page_table, PageTable.add page_table, PageTable.find page_table
    in

    (try Unix.mkdir default_dir 0o777; with _ -> ());

    let main_page = mk_html_page "Summary" main_page_name in
    (* Initialize one page with a buffer, a link name, a formatter
       for every thread
    *)
    List.iter
      (fun th ->
         let thread_name =
           Format.asprintf "%a" ThreadState.pretty th in
         let html_page = mk_html_page
             (Format.asprintf "Summary for thread %s" thread_name)
             (Format.asprintf "%a" ThreadState.pretty th) in
         add_page th.th_eva_thread html_page;
         Format.pp_set_formatter_stag_functions
           html_page.page_fmt html_stag_functions;
         Format.pp_set_tags html_page.page_fmt true;
      ) th_list;

    (* Do back links *)
    let mk_footer_links () =
      Format.pp_set_formatter_stag_functions
        footer_links.div_fmt html_stag_functions;
      Format.pp_set_tags footer_links.div_fmt true;
      Format.fprintf footer_links.div_fmt
        "@[ <ul class=\"horizontal\">@]";
      List.iter
        (fun th ->
           let hpage = find_page th.th_eva_thread in
           Format.fprintf footer_links.div_fmt
             "@[@{<li class=\"horizontal\">@{<a href=\"%s\">@ %s@}@}@]"
             (html_fname hpage) (escape hpage.page_name)) th_list;
      Format.fprintf footer_links.div_fmt
        "@[ </ul>@]@.";
    in
    mk_footer_links ();

    (* Print pages *)
    List.iter
      (fun th ->
         let details = find_page th.th_eva_thread in
         pp_thread_details details main_page th
      ) th_list;

    mk_main_page main_page page_table th_list;

    (* Generate per thread files *)
    Thread.Hashtbl.iter_sorted (fun _th html_page -> pp_page html_page) page_table;
    pp_page main_page;
    ast_to_html "code";
  ;;

end

module Eva_results = struct
  (* Fuses the value analysis results for each thread, reprefix them by
     a fresh kernel function to have nice callstacks, fuse all the
     results, and set the result as Value's results. *)
  let display analysis =
    let ths = analysis.all_threads in
    let aux_th eva_th th acc =
      match th.th_value_results with
      | None -> acc (* Analysis skipped *)
      | Some results ->
        let change cs = Callstack.{ cs with thread = Thread.id eva_th } in
        let results' = Eva_results.change_callstacks change results in
        results' :: acc
    in
    let all_results = Thread.Hashtbl.fold aux_th ths [] in
    match all_results with
    | [] -> MtOptions.error "No results recorded. Nothing to display"
    | r :: qr ->
      let all = List.fold_left Eva_results.merge r qr in
      Eva_results.set_results all

end
