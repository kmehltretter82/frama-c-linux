include Plugin.Register(
  struct
    let name = "Markdown report"
    let shortname = "mdr"
    let help = "generates a report in markdown format"
  end)

module Output = String(
struct
  let option_name = "-mdr-out"
  let arg_name = "f"
  let default = "report.md"
  let help = "sets the name of the output file to <f>"
end)

module Generate = False(
struct
  let option_name = "-mdr-gen"
  let help = "generates an analysis report on the current project"
end)

module Gen_draft = False(
  struct
    let option_name = "-mdr-gen-draft"
    let help =
      "instead of a full report, generates an empty draft \
       in a format suitable for -mdr-remarks"
  end)

module Remarks = Empty_string(
struct
  let option_name = "-mdr-remarks"
  let arg_name = "f"
  let help =
    "reads file <f> to add additional remarks to various sections of the report. \
     Must be in a format compatible with the file produced by -mdr-gen-draft. \
     Remarks themselves must be written in pandoc's markdown, although this is \
     not enforced by the plug-in"
end
)

module Authors = String_list(
struct
  let option_name = "-mdr-authors"
  let arg_name = "l"
  let help = "list of authors of the report"
end)

module Stubs = String_list(
  struct
    let option_name = "-mdr-stubs"
    let arg_name = "f1,...,fn"
    let help = "list of C files containing stub functions"
  end)
