include State_builder.Ref
    (Cil_datatype.Location)
    (struct
      let dependencies = []
      let name = "CurrentLoc"
      let default () = Cil_datatype.Location.unknown
    end)

let () = Log.set_current_source (fun () -> fst (get ()))

let with_loc loc f x =
  let oldLoc = get () in
  let finally () = set oldLoc in
  let work () = set loc; f x in
  Fun.protect ~finally work

let with_loc_opt loc_opt f x =
  match loc_opt with
  | None -> f x
  | Some loc -> with_loc loc f x

module Operators = struct
  type operation = UpdatedCurrentLoc

  let ( let<> ) loc f = with_loc loc f UpdatedCurrentLoc
  let ( let<?> ) loc_opt f = with_loc_opt loc_opt f UpdatedCurrentLoc
end
