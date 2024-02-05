let run () =
  if Options.Gui.get() then
    Gui.show ()

let () = Boot.Main.extend run
