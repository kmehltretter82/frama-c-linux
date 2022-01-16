open MtUtils
open Cil_types



type name = Name.t
type value = Value.t
type args  = (varinfo * value) list

module Thread = struct
  type thread' =
    { name: name ; stmt: stmt ; func: kernel_function ; args: args }

  let dummy_unhashconsed =
    let name = Name.of_string "dummy" in
    let stmt = Cil.dummyStmt in
    let func = Kernel_function.dummy () in
    { name ; stmt ; func ; args = [] }

  module Thread' = Datatype.Make_with_collections (struct
    include Datatype.Serializable_undefined
    type t = thread'
    let name = "Mthread.thread"
    let reprs = [ dummy_unhashconsed ]
    let compare x y =
      let cmp_var = Cil_datatype.Varinfo.compare in
      let cmp_val = Value.compare in
      let cmp_arg (ix, vx) (iy, vy) = cmp_var ix iy <?> lazy (cmp_val vx vy) in
      Name.compare x.name y.name
      <?> lazy (Cil_datatype.Stmt.compare x.stmt y.stmt)
      <?> lazy (Kernel_function.compare x.func y.func)
      <?> lazy (List.compare cmp_arg x.args y.args)
    let equal x y = compare x y = 0
    let hash = Hashtbl.hash
    let pretty fmt { name ; stmt ; func ; args } =
      let pp_sep fmt () = Format.fprintf fmt ";@ " in
      let pp_var = Cil_datatype.Varinfo.pretty in
      let pp_val = Value.pretty in
      let pp fmt (var, v) = Format.fprintf fmt "%a <- %a" pp_var var pp_val v in
      Format.fprintf fmt
        "@[<v 2>Thread name :@ @[<hov>%a@]@]@\n\
         @[<v 2>At statement:@ @[<hov>%a@]@]@\n\
         @[<v 2>Executing   :@ @[<hov>%a@]@]@\n\
         @[<v 2>With args   :@ @[<hov>%a@]@]"
        Name.pretty name
        Cil_datatype.Stmt.pretty stmt
        Kernel_function.pretty func
        Format.(pp_print_list ~pp_sep pp) args
  end)

  module ThreadInfos = struct
    let name = "Mthread.thread.hashconsed"
    let dependencies = []
    let initial_values = Thread'.reprs
  end

  include State_builder.Hashcons (Thread') (ThreadInfos)
  let key_name = "thread"
  let key_id thread = id thread + 1 |> Z.of_int |> Value.inject_int
  let pretty_msg fmt t = get t |> fun { name } -> Name.pretty fmt name
end

type thread = Thread.t
include Thread

let id = key_id

let hashcons, of_cvalue =
  let module Cache = Datatype.Int.Hashtbl in
  let cache : t Cache.t = Cache.create 10 in
  let hashcons thread =
    let hashconsed = Thread.hashcons thread in
    let id = Thread.id hashconsed + 1 in
    Cache.add cache id hashconsed ;
    hashconsed
  and of_cvalue cvalue =
    match Value.extract_singleton cvalue with
    | None -> Result.error "Not a singleton value."
    | Some id ->
      match Cache.find_opt cache id with
      | None -> Result.error "Not a valid thread id."
      | Some thread -> Result.ok thread
  in
  hashcons, of_cvalue

let create name stmt func args = hashcons { name ; stmt ; func ; args }
let dummy = hashcons Thread.dummy_unhashconsed
let to_cvalue thread = Thread.id thread |> Z.of_int |> Value.inject_int
let main () =
  let name = Name.of_string "main" in
  let stmt = Cil.dummyStmt in
  let f () = Globals.entry_point () |> fst in
  try hashcons { name ; stmt ; func = f () ; args = [] }
  with Globals.No_such_entry_point m -> Self.fatal "%s Mthread cannot run" m

let return_lval thread =
  let { func } = get thread in
  Option.map Eva_ast.Build.var (Library_functions.get_retres_vi func)



type status = { running : Trilean.t ; canceled : Trilean.t }
module Status = struct
  include Datatype.Make (struct
    type t = status
    let name = "Mthread.thread.status"
    let reprs = [ { running = False ; canceled = False } ]
    let copy = Datatype.identity
    let rehash = Datatype.identity
    let mem_project = Datatype.never_any_project

    let structural_descr =
      let running = Datatype.Bool.packed_descr in
      let canceled = Trilean.packed_descr in
      Structural_descr.t_record [| running ; canceled |]

    let pretty fmt { running ; canceled } =
      Format.fprintf fmt "Running : %a@.Canceled : %a@."
        Trilean.pretty running Trilean.pretty canceled

    let compare l r =
      Trilean.compare l.running r.running
      <?> lazy (Trilean.compare l.canceled r.canceled)

    let equal l r = compare l r = 0
    let hash t = Trilean.hash t.running + 3 * Trilean.hash t.canceled
  end)

  (* let top = { running = Unknown ; canceled = Unknown } *)

  let is_included l r =
    Trilean.is_included l.running r.running
    && Trilean.is_included l.canceled r.canceled

  let join l r =
    let running = Trilean.join l.running r.running in
    let canceled = Trilean.join l.canceled r.canceled in
    { running ; canceled }

  let default = { running = False ; canceled = False }
end



module Register = struct
  include Register (Thread) (Status)

  let change_running ok msg =
    let after = Trilean.not ok in
    let new_status status = { status with running = after } in
    update new_status @@ fun { running } ->
    if Trilean.equal running ok then Ok
    else Invalid (msg, Trilean.equal running after)

  let start = change_running True "running"
  let suspend = change_running False "suspended"
  let cancel = update (fun s -> { s with canceled = True }) (fun _ -> Ok)
end
