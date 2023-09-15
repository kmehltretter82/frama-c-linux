  $ frama-c -no-autoload-plugins -load-plugin server wrong.i -server-batch wrong.json -server-msg-key use-relative-filepath
  [kernel] Parsing wrong.i (no preprocessing)
  [server] Script "wrong.json"
  [server] User Error: [batch] "unknown request": request "kernel.unknown" not found
  [server] [GET] kernel.ast.printFunction
  [server] User Error: [kernel.ast.printFunction] Expected string, got object:
    { "f1": 1, "f2": { "x": 1, "y": 2 }, "f3": null }
  [server] Output "wrong.out.json"
  [server] User Error: Deferred error message was emitted during execution. See above messages for more information.
  [kernel] Plug-in server aborted: invalid user input.
  [1]
  $ cat wrong.out.json
  [
    { "id": "unknown request", "error": "request not found" },
    {
      "id": "wrong data",
      "error": "Expected string, got object:\n{ \"f1\": 1, \"f2\": { \"x\": 1, \"y\": 2 }, \"f3\": null }",
      "at": {
        "id": "wrong data",
        "request": "kernel.ast.printFunction",
        "data": { "f1": 1, "f2": { "x": 1, "y": 2 }, "f3": null },
        "comment": "ident is expected, object is given"
      }
    }
  ]
