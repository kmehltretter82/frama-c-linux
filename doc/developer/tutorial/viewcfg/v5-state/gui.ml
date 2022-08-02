open Bogue
module W = Widget
module L = Layout

let show () =
  (* Create a few widgets for our GUI: a label, a text input with the function
     to be displayed, and a button to show it. *)
  let l = W.label "Show graph for function:" in
  let t = W.text_input ~text:"main" () in
  let b = W.button "Show CFG" in
  let status = W.label (String.make 50 '-') in (* used for error messages *)
  let layout = L.tower_of_w [l;t;b;status] in
  let show_graph _button =
    let name = W.get_text t in
    try
      (* Check the function name exists and is defined (not just declared). *)
      let kf = Globals.Functions.find_by_name name in
      let fd = Kernel_function.get_definition kf in
      W.set_text status "";

      (* Create a temporary file with the graph and pass it to 'dotty'. *)
      let (tmpname, oc) = Filename.open_temp_file "cfg_view" ".dot" in
      Dump.dump_function fd (Format.formatter_of_out_channel oc);
      close_out oc;
      let cmd = Format.asprintf "dotty %S" tmpname in
      ignore (Sys.command cmd);
      W.set_text status (String.make 50 '-');
      Unix.unlink tmpname
    with
    | Not_found ->
      W.set_text status ("Error: function " ^ name ^ " not found.")
    | Kernel_function.No_Definition ->
      W.set_text status ("Error: function " ^ name ^ " is not defined.")
  in
  W.on_release ~release:show_graph b;
  let board = Bogue.make [] [layout] in
  Bogue.run board
