  $ frama-c -no-autoload-plugins -load-plugin server ast_services.i -server-batch ast_services.json -server-msg-key use-relative-filepath
  [kernel] Parsing ast_services.i (no preprocessing)
  [server] Script "ast_services.json"
  [server] [GET] kernel.ast.fetchFunctions
  [server] [GET] kernel.ast.fetchFunctions
  [server] [GET] kernel.ast.printFunction
  [server] [GET] kernel.ast.printFunction
  [server] [GET] kernel.ast.printFunction
  [server] User Error: [kernel.ast.printFunction] Undefined function 'h'
  [server] Output "ast_services.out.json"
  [server] User Error: Deferred error message was emitted during execution. See above messages for more information.
  [kernel] Plug-in server aborted: invalid user input.
  [1]
  $ cat ast_services.out.json
  [
    {
      "id": "GET-1",
      "data": {
        "updated": [
          {
            "key": "kf#24",
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
    },
    {
      "id": "PRINT-F",
      "data": [
        "",
        [
          "#v20",
          [ "#y1", "int" ],
          " f(",
          [ "#v22", [ "#y1", "int" ], " x" ],
          ")"
        ],
        "\n{\n  ",
        [ "#v23", [ "#y1", "int" ], " tmp" ],
        ";\n  ",
        [
          "#s1",
          [
            "#k1",
            "{ /* sequence */\n    ",
            [ "#s2", [ "#k2", [ "#l2", "tmp" ], " = ", [ "#l3", "x" ], ";" ] ],
            "\n    ",
            [ "#s3", [ "#k3", [ "#l4", "x" ], " ++;" ] ],
            "\n    ",
            [ "#s4", [ "#k4", ";" ] ],
            "\n  }"
          ]
        ],
        "\n  ",
        [ "#s5", [ "#k5", "return ", [ "#l5", "tmp" ], ";" ] ],
        "\n}\n",
        "\n"
      ]
    },
    {
      "id": "PRINT-G",
      "data": [
        "",
        [
          "#v24",
          [ "#y1", "int" ],
          " g(",
          [ "#v26", [ "#y1", "int" ], " y" ],
          ")"
        ],
        "\n{\n  ",
        [ "#v27", [ "#y1", "int" ], " tmp" ],
        ";\n  ",
        [
          "#s7",
          [
            "#k7",
            "{ /* sequence */\n    ",
            [ "#s8", [ "#k8", [ "#l6", "tmp" ], " = ", [ "#l7", "y" ], ";" ] ],
            "\n    ",
            [ "#s9", [ "#k9", [ "#l8", "y" ], " ++;" ] ],
            "\n    ",
            [ "#s10", [ "#k10", ";" ] ],
            "\n  }"
          ]
        ],
        "\n  ",
        [ "#s11", [ "#k11", "return ", [ "#l9", "tmp" ], ";" ] ],
        "\n}\n",
        "\n"
      ]
    },
    {
      "id": "PRINT-H",
      "error": "Undefined function 'h'",
      "at": {
        "id": "PRINT-H",
        "request": "kernel.ast.printFunction",
        "data": "h"
      }
    }
  ]
