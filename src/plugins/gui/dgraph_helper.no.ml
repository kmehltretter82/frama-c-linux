let window_msg_unavailable () =
  let buttons = GWindow.Buttons.ok in
  let message_type = `WARNING in
  let message =
    "Frama-C has not been compiled against a library with \
     working graph visualization. Property dependencies graph can't be shown."
  in
  ignore (GWindow.message_dialog ~buttons ~message_type ~message ())

let graph_window ~parent:_ ~title:_ _ =
  window_msg_unavailable ()

let graph_window_through_dot ~parent:_ ~title:_ _ =
  window_msg_unavailable ()
