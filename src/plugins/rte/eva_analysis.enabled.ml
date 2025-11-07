let is_available = true

let is_computed kf =
  Eva.Analysis.is_computed () &&
  match Eva.Analysis.status kf with
  | Eva.Analysis.Analyzed _ -> true
  | _ -> false
