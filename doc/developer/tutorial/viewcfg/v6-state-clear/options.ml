module Self = Plugin.Register(struct
    let name = "control flow graph"
    let shortname = "viewcfg"
    let help = "control flow graph computation and display"
  end)

module Gui = Self.False(struct
    let option_name = "-cfg-gui"
    let help =
      "when on (off by default), displays a mini-GUI for showing graphs."
  end)
