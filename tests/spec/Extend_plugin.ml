open Logic_typing

include
  Plugin.Register
    (struct
      let name = "MyPlugin"
      let shortname = "myplugin"
      let help = ""
    end)

let type_foo typing_context _loc l =
  let preds =
    List.map
      (typing_context.type_predicate
         typing_context typing_context.pre_state)
      l
  in
  Cil_types.Ext_preds preds

let () =
  Acsl_extension.register_behavior ~plugin:"myplugin" "foo" type_foo false;
  Acsl_extension.register_behavior ~plugin:"myplugin" "foo" type_foo false
