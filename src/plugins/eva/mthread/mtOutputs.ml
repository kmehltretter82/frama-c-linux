(**************************************************************************)
(*                                                                        *)
(*  This file is part of Frama-C.                                         *)
(*                                                                        *)
(*  Copyright (C) 2007-2025                                               *)
(*    CEA (Commissariat à l'énergie atomique et aux énergies              *)
(*         alternatives)                                                  *)
(*                                                                        *)
(*  All rights reserved.                                                  *)
(*  Contact CEA LIST for licensing.                                       *)
(*                                                                        *)
(**************************************************************************)

open Cil_types
open MtTypes
open MtIds
open MtThread
;;

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

  let translate_string s =
    let translation_table =
      Utilities.mk_translation_tbl
        [ (">", "&gt;")  ;
          ("<", "&lt;") ;
          ("&", "&amp;") ;
        ]
    in
    Buffer.contents (Utilities.replace_chars translation_table s)
  ;;

  let pretty_escaped pp fmt v =
    let s = Format.asprintf "%a" pp v in
    let s = translate_string s in
    Format.pp_print_string fmt s

  let pretty_id = pretty_escaped Id.pretty

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

  let html_fname html_page = translate_string html_page.page_name ^ ".html";;

  (* Bidirectional association tables *)
  type 'a id_biassoc = {
    to_id : 'a Id.Hashtbl.t;
    from_id : ('a, Id.t) Hashtbl.t;
  }
  ;;

  let mk_id_biassoc n =
    { to_id = Id.Hashtbl.create n;
      from_id = Hashtbl.create n;
    }
  ;;


  type 'a html_table = {
    rows : int id_biassoc;
    columns : int id_biassoc;
    tbl_contents : 'a array array;
    row_size : int;
    col_size : int;
  }
  ;;


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

  let mk_html_table row_list col_list =
    let row_length = List.length row_list in
    let rows = mk_id_biassoc row_length in
    let col_length = List.length col_list in
    let cols = mk_id_biassoc col_length in

    List.iteri
      (fun i id ->
         Id.Hashtbl.add rows.to_id id i;
         Hashtbl.add rows.from_id i id;
      ) row_list;

    List.iteri
      (fun i id ->
         Id.Hashtbl.add cols.to_id id i;
         Hashtbl.add cols.from_id i id;
      ) col_list;

    { rows = rows;
      columns = cols;
      tbl_contents = Array.make_matrix row_length col_length empty_string ;
      row_size = row_length;
      col_size = col_length;
    }
  ;;


  (* Generate the set of lock taken in the program by all threads/processes
     And a hash table associating threads to locking procedures (take, release
     ...)
  *)
  let gen_locks_summary th_list =
    let idlock_tbl = Id.Hashtbl.create (List.length th_list) in
    let lockset =
      List.fold_left
        (fun lockset (id, th)  ->
           let th_lockset = ref EventsSet.empty in
           let global_lockset =
             Trace.fold' th.th_amap
               (fun action lockset ->
                  match action with
                  | MutexRelease id
                  | MutexLock id ->
                    th_lockset := EventsSet.add action !th_lockset;
                    Id.Set.add id lockset
                  | _ -> lockset
               ) lockset
           in Id.Hashtbl.add idlock_tbl id !th_lockset;
           global_lockset
        )  Id.Set.empty th_list
    in
    if Id.Set.is_empty lockset then None
    else begin
      let lock_olist =
        List.sort Id.compare_by_name
          (Id.Set.fold (fun x l -> x :: l) lockset []) in
      let th_idlist =  List.map fst th_list in
      Some (idlock_tbl, mk_html_table lock_olist th_idlist)
    end
  ;;

  (* Generate the set of fifos used in the program
     Mark the uses in a html table
     Also yields a hash table id -> fifo uses
  *)
  let gen_mqueues_summary th_list =
    let mq_idtbl = Id.Hashtbl.create (List.length th_list) in
    let queueset =
      List.fold_left
        (fun queueset (id, th)  ->
           let th_queueset = ref EventsSet.empty in
           let global_queueset =
             Trace.fold' th.th_amap
               (fun action queueset ->
                  match action with
                  | SendMsg (id, _)
                  | CreateQueue (id, _)
                  | ReceiveMsg (id, _, _) ->
                    th_queueset := EventsSet.add action !th_queueset;
                    MtIds.Id.Set.add id queueset
                  | _ -> queueset
               ) queueset
           in Id.Hashtbl.add mq_idtbl id !th_queueset;
           global_queueset
        ) MtIds.Id.Set.empty th_list
    in
    (* Returns mothing when there is no queue in the program *)
    if Id.Set.is_empty queueset then None
    else begin
      let queue_olist =
        List.sort MtIds.Id.compare_by_name
          (MtIds.Id.Set.fold (fun x l -> x :: l) queueset []) in
      let th_list =  List.map fst th_list in
      assert ((MtIds.Id.Hashtbl.length mq_idtbl) > 0);
      MtOptions.debug "%d queues found@." (MtIds.Id.Hashtbl.length mq_idtbl);
      Some (mq_idtbl, mk_html_table queue_olist th_list);
    end
  ;;

  (* Mark a set of actions according to a marking function
     in a HTML table
  *)
  let mark_action_set mark_fun html_tbl action_idtbl =
    Id.Hashtbl.iter_sorted
      (fun id aset ->
         try
           let col = Id.Hashtbl.find html_tbl.columns.to_id id in
           EventsSet.iter
             (fun a ->
                let id, mark = mark_fun a in
                let row = Id.Hashtbl.find html_tbl.rows.to_id id in
                html_tbl.tbl_contents.(row).(col) <-
                  html_tbl.tbl_contents.(row).(col) ^ mark;
             ) aset
         with
         | Not_found -> assert false
      ) action_idtbl;
  ;;

  (* Columns are thread name, rows are locks *)
  let mark_lock_actions =
    mark_action_set
      (fun action ->
         match action with
         | MutexRelease id -> id, "V"
         | MutexLock id -> id, "P"
         | _ -> assert false
         (* This action set is generated by gen_locks_summary
            and should only containt lock-related constructors
         *)
      )
  ;;

  let mark_mqueue_actions =
    mark_action_set
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


  (* Pretty print a html table *)
  let pp_html_tbl pretty_row caption legend  fmt html_tbl  =
    let pp_row fmt i =
      let row_thread =
        try
          Hashtbl.find html_tbl.rows.from_id i
        with
        | Not_found ->
          MtOptions.fatal "@[Row %d not found@]@." i
      in

      let pp_cells fmt () =
        Array.iter
          (fun s ->
             Format.fprintf fmt "@ @[@{<td class=\"plop\">@ %s@ @}@]" s
          ) html_tbl.tbl_contents.(i)

      in Format.fprintf fmt
        "@[<v 1>\
         @{<tr>@ \
         @{<th>%a@}\
         %a\
         @}\
         @]"
        pretty_row row_thread
        pp_cells ()
    in

    let rec pp_rows fmt i  =
      if i = html_tbl.row_size then Format.fprintf fmt ""
      else Format.fprintf fmt "@[<v 0>%a@ %a@]"
          pp_row i
          pp_rows (i+1)
    in

    let pp_headers fmt () =
      let rec aux_pp_hdr fmt i =
        if i = html_tbl.col_size then Format.fprintf fmt ""
        else Format.fprintf fmt "@ @{<th>%a@}%a"
            pretty_row (Hashtbl.find html_tbl.columns.from_id i)
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
    Format.fprintf fmt "@[<hov 1>@[@{<caption>%s@ @}@ @[%a@]@ %a@]@]@?"
      caption
      pp_headers ()
      pp_rows 0
  ;;

  let pp_id_html_tbl = pp_html_tbl pretty_id;;

  (* Generate the html table for lock take/release actions *)
  let mk_locks_summary div th_idlist =
    let b, fmt = div.contents, div.div_fmt in
    Format.pp_set_tags fmt true;
    match gen_locks_summary th_idlist with
    | None -> b
    | Some(idlock_tbl, html_table) ->
      let html_legend = "uses lock &larr;<br/> &darr;" in
      mark_lock_actions html_table idlock_tbl;
      Format.fprintf fmt
        "@[<v 1>\
         @{<h3>%s@}@ \
         @{<table>@ %a@ @}</table>\
         @]@?"
        div.title
        (pp_id_html_tbl "P = lock taken, V = lock released" html_legend) html_table;
      b
  ;;

  (* Generate the html table for write/receive fifo summaries *)
  let mk_mqueues_summary div th_idlist =
    let html_legend = "uses lock &larr;<br/> &darr;" in
    match gen_mqueues_summary th_idlist with
    | None -> div.contents
    | Some (queue_idtbl, html_table) ->
      (* Only print when there is something to be said *)
      Format.pp_set_tags div.div_fmt true;
      mark_mqueue_actions html_table queue_idtbl;
      Format.fprintf div.div_fmt
        "@[<v 1>@ \
         @{<h3>%s@}@ \
         @{<table>@ %a@ @}</table>@]@?"
        div.title
        (pp_id_html_tbl "R = queue read, S = queue written, C = queue created"
           html_legend) html_table;
      div.contents;
  ;;

  (* Output a small global summary :
     number of threads and their names
  *)
  let mk_global_summary th_idlist html_idtbl =
    let b, fmt = Utilities.mk_buffer_formatter () in
    let th_buf, th_fmt = Utilities.mk_buffer_formatter () in
    Format.pp_set_tags fmt true;
    Format.pp_set_tags th_fmt true;
    Format.fprintf th_fmt "@[<v>";
    List.iter
      (fun (th_id, _) ->
         Format.fprintf th_fmt
           "@[ <li><a href=\"%s\">%a</a></li>@]@ "
           (html_fname (Id.Hashtbl.find html_idtbl th_id))
           pretty_id th_id;
      ) th_idlist;
    Format.fprintf th_fmt "@]@.";
    Format.fprintf fmt "@[<v 1>@[\
                        @{<h1> Summary @}@ \
                        <br/>@ \
                        This program has %d thread(s)@ \
                        @ @{<ul>@ %s @}@]@]@?"
      (List.length th_idlist)
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
    let thread_name = Id.sanitize_name th.th_id in
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
        s Id.pretty th.th_id (String.concat " " args)
    in
    begin
      try
        let ret = Command.command ~timeout:60 "dot" (Array.of_list args) in
        match ret with
        | Unix.WEXITED 0 ->
          if not (MtOptions.KeepDotFiles.get ()) then begin
            MtOptions.debug "remove %s\n" tmp_file;
            Sys.remove tmp_file
          end
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

  let mk_thread_graph th_idlist =
    let module ThreadInheritanceGraph = struct
      include (Graph.Imperative.Digraph.Concrete(MtIds.Id))
      let graph_attributes _ = []
      let default_vertex_attributes _ = []
      let vertex_name v =
        let s = Format.asprintf "%a" Id.pretty v in
        Buffer.contents (dot_escape s)
      let vertex_attributes v =
        let s = Format.asprintf "%a" Id.pretty v in
        [ `Label (MtLib.escape_non_utf8 s)]
      let get_subgraph _ = None
      let default_edge_attributes _ = [`Style(`Solid);]
      let edge_attributes _ = []
    end
    in
    let graph = ThreadInheritanceGraph.create ~size:(List.length th_idlist) () in
    List.iter
      (fun (id, th) ->
         match th.th_parent with
         | None -> ThreadInheritanceGraph.add_vertex graph id;
         | Some p_id -> ThreadInheritanceGraph.add_edge graph p_id.th_id id
      ) th_idlist;
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

  let mk_thread_graph_div div th_idlist =
    let b, fmt = div.contents, div.div_fmt in
    let img = mk_thread_graph th_idlist in
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
      (translate_string html_page.page_name)
      pretty_id th.th_id
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

  let mk_main_page page html_idtbl th_idlist =
    (* Do the main page *)
    let buf_init, _fmt_init = page.page_buffer, page.page_fmt in
    let buf_append = Buffer.add_buffer buf_init in
    (* Generate the main page *)
    Buffer.add_string buf_init "<!--(* Generated my mthread *)-->";
    buf_append (mk_global_summary th_idlist html_idtbl);
    (* Graph for thread creation *)
    buf_append (mk_thread_graph_div (mk_div "Thread creation graph") th_idlist);
    (* Table for lock uses *)
    buf_append (mk_locks_summary (mk_div "Lock operations") th_idlist);
    (* Table for queue uses *)
    buf_append (mk_mqueues_summary (mk_div "Queue operations") th_idlist);
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
    let ths = List.filter should_compute_thread (threads analysis) in
    let ths = List.map (fun th -> th.th_id, th) ths in
    let html_idtbl =
      Id.Hashtbl.create (List.length ths) in

    (try Unix.mkdir default_dir 0o777; with _ -> ());

    let main_page = mk_html_page "Summary" main_page_name in
    (* Initialize one page with a buffer, a link name, a formatter
       for every thread
    *)
    let th_ord_list =
      (* We keep the first separately, as it is the main one *)
      (List.hd ths) ::
      List.sort
        (fun (id1, _) (id2, _) -> Id.compare_by_name id1 id2)
        (List.tl ths)
    in
    List.iter
      (fun (id, _) ->
         let thread_name =
           Format.asprintf "%a" pretty_id id in
         let html_page = mk_html_page
             (Format.asprintf "Summary for thread %s" thread_name)
             (Format.asprintf "%a" Id.pretty id) in
         Id.Hashtbl.add html_idtbl id html_page;
         Format.pp_set_formatter_stag_functions
           html_page.page_fmt html_stag_functions;
         Format.pp_set_tags html_page.page_fmt true;
      ) th_ord_list;

    (* Do back links *)
    let mk_footer_links () =
      Format.pp_set_formatter_stag_functions
        footer_links.div_fmt html_stag_functions;
      Format.pp_set_tags footer_links.div_fmt true;
      Format.fprintf footer_links.div_fmt
        "@[ <ul class=\"horizontal\">@]";
      List.iter
        (fun (id, _) ->
           let hpage = Id.Hashtbl.find html_idtbl id in
           Format.fprintf footer_links.div_fmt
             "@[@{<li class=\"horizontal\">@{<a href=\"%s\">@ %s@}@}@]"
             (html_fname hpage) (translate_string hpage.page_name)) th_ord_list;
      Format.fprintf footer_links.div_fmt
        "@[ </ul>@]@.";
    in
    mk_footer_links ();

    (* Print pages *)
    List.iter
      (fun (id, th) ->
         let details = Id.Hashtbl.find html_idtbl id in
         pp_thread_details details main_page th
      ) th_ord_list;

    mk_main_page main_page html_idtbl th_ord_list;

    (* Generate per thread files *)
    Id.Hashtbl.iter_sorted (fun _id html_page -> pp_page html_page) html_idtbl;
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
    let aux_th _ th acc =
      match th.th_value_results with
      | None -> acc (* Analysis skipped *)
      | Some results ->
        let thread = snd th.th_id.id_raw in
        let change cs = Eva.Callstack.{ cs with thread } in
        let results' = Eva.Eva_results.change_callstacks change results in
        results' :: acc
    in
    let all_results = MtIds.Id.Hashtbl.fold aux_th ths [] in
    match all_results with
    | [] -> MtOptions.error "No results recorded. Nothing to display"
    | r :: qr ->
      let all = List.fold_left Eva.Eva_results.merge r qr in
      Eva.Eva_results.set_results all

end
