  $ frama-c -no-autoload-plugins -load-plugin server ast_services.i -server-batch ast_services.json -server-msg-key use-relative-filepath
  [kernel] Parsing ast_services.i (no preprocessing)
  [server] Script "ast_services.json"
  [server] [GET] kernel.ast.fetchFunctions
  [server] [GET] kernel.ast.fetchFunctions
  [server] Output "ast_services.out.json"
  $ cat ast_services.out.json
  [
    {
      "id": "GET-1",
      "data": {
        "updated": [
          {
            "key": "kf#24",
            "decl": "#F24",
            "name": "g",
            "signature": "int g(int y);",
            "defined": true,
            "sloc": {
              "dir": ".",
              "base": "ast_services.i",
              "file": "ast_services.i",
              "line": 2
            }
          },
          {
            "key": "kf#20",
            "decl": "#F20",
            "name": "f",
            "signature": "int f(int x);",
            "defined": true,
            "sloc": {
              "dir": ".",
              "base": "ast_services.i",
              "file": "ast_services.i",
              "line": 1
            }
          }
        ],
        "removed": [],
        "reload": true,
        "pending": 0
      }
    },
    {
      "id": "GET-2",
      "data": { "updated": [], "removed": [], "reload": false, "pending": 0 }
    }
  ]
