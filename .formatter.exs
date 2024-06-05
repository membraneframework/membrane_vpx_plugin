[
  inputs: [
    "{lib,test,config,c_src}/**/*.{ex,exs}",
    ".formatter.exs",
    "*.exs"
  ],
  locals_without_parens: [
    module: 1,
    spec: 1,
    state_type: 1,
    dirty: 2
  ],
  import_deps: [:membrane_core]
]
