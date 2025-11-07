let is_available = true

let is_computed kf =
  Eva.Analysis.is_computed () && Eva.Results.is_called kf
