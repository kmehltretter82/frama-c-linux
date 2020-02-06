open Crowbar
open Cil_types

let file = ref None
let set_file f = file:= Some f
let get_file () =
  match !file with
  | None -> bad_test ()
  | Some file -> file

class random_ghost dec =
  let () = assert (dec <> []) in
  let _next = ref dec in
  let rec next i =
    match !_next with
    | [] -> _next := dec; next i
    | hd :: tl -> _next := tl; Some hd
  in
  let stream = Stream.from next in
  object
    inherit Visitor.frama_c_inplace
    val ghost_father = Stack.create ()
    method! vstmt_aux s =
      let ghost =
        if Stack.is_empty ghost_father ||
           not (Stack.top ghost_father)
        then begin
          let v = Stream.next stream in v = 0
        end else true
      in
      s.ghost <- ghost;
      Stack.push ghost ghost_father;
      Cil.DoChildrenPost (fun s -> ignore (Stack.pop ghost_father); s)
  end

let create_list length =
  let lmax = 20000 in
  let length = if length > lmax then lmax else length in
  let rec aux acc l =
    if l = 0 then acc
    else
      aux (map [range 10; acc] (fun v l -> v::l)) (l-1)
  in aux (const []) length

let gen_cat = File.register_code_transformation_category "ghostify"

let oracle_cat = File.register_code_transformation_category "oracle"

module Should_warn = State_builder.False_ref(
  struct
    let name = "Test_ghost_cfg.Should_warn"
    let dependencies = [Kernel.Files.self]
  end)

class should_warn =
  object
    inherit Visitor.frama_c_inplace
    method! vstmt_aux s =
      if s.ghost then begin
        match s.skind with
        | Break _ | Goto _ | Continue _ ->
          let s' = Extlib.as_singleton s.succs in
          if not (s'.ghost) then Should_warn.set true
        | Return _ -> Should_warn.set true
        | _ -> ()
      end;
      Cil.DoChildren
  end

let should_warn file = Visitor.visitFramacFileSameGlobals (new should_warn) file

let () =
  File.add_code_transformation_after_cleanup
    ~before:[Ghost_cfg.transform_category]
    oracle_cat
    should_warn

let input_file = "test.c"

let set_options () =
  Kernel.Files.set [Filepath.Normalized.of_string input_file];
  Kernel.CppExtraArgs.set ["-I/usr/include/csmith-2.3.0"];
  Kernel.set_warn_status Kernel.wkey_ghost_bad_use Log.Wabort

let ghostify file =
  let length =
    Cil.foldGlobals
      file
      (fun m g ->
         match g with
         | GFun (f,_) -> max m (Extlib.the f.smaxstmtid)
         | _ -> m)
      0
  in
  let make l =
    Project.set_current (Project.create "ghost");
    set_options ();
    let vis = new random_ghost l in
    let transform file =
      Visitor.visitFramacFileSameGlobals vis file;
      set_file file
    in
    let before = [oracle_cat] in
    File.add_code_transformation_after_cleanup ~before gen_cat transform
  in
  map [create_list length] make

let gen_file () = Sys.command ("csmith > " ^ input_file)

let () = Project.set_current (Project.create "simple project")

let () = set_options ()

let init = if Sys.file_exists input_file then bool else const true

let make gen =
  if gen then guard (gen_file () <> 0);
  ghostify (Ast.get ())

let create_ghost = dynamic_bind init make

let report s =
  let temp_dir = "." in
  let file_name = Filename.temp_file ~temp_dir "ghostified" ".c" in
  let summary =
    Printf.sprintf
      "%s. Saving ghostified file in %s"
      s file_name
  in
  let out = open_out file_name in
  let fmt = Format.formatter_of_out_channel out in
  Printer.pp_file fmt (get_file());
  fail summary

let check_file () =
  try
    Ast.compute ();
    if Should_warn.get () then
      report "Found ghost code that should not have been accepted"
  with
    | Log.AbortError s ->
      if not (Should_warn.get ()) then
        report
          ("Found ghost code that should have been accepted (msg: " ^ s ^ ")")
    | _ -> bad_test ()

let test = map [create_ghost] check_file

let () = add_test ~name:"ghost cfg" [create_ghost] check_file
