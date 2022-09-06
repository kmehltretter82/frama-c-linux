let run () =
  if Options.Gui.get() then
    Gui.show ()

let () = Db.Main.extend run
