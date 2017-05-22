include Plugin.Register
    (struct
      let name = "Reduction"
      let shortname = "reduc"
      let help = "Generate ACSL annotations from Value Analysis informations"
    end)

module Reduc =
  Bool
    (struct
      let option_name = "-reduc"
      let help = "Use reduc"
      let default = false
    end)

module GenAnnot =
  String
    (struct
      let option_name = "-reduc-gen-annot"
      let arg_name = "gen-annot-heuristic"
      let help = "Heuristic to generate annotations from Value"
      let default = "inout"
    end)

module GenVars =
  String
    (struct
      let option_name = "-reduc-gen-vars"
      let arg_name = "gen-vars-heuristic"
      let help = "Heuristic to generate annotations for variables"
      let default = "all"
    end)
