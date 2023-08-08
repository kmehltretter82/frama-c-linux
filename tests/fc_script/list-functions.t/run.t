  $ frama-c-script list-functions find-fun2.c list-functions.c
  [kernel:typing:implicit-function-declaration] find-fun2.c:12: Warning: 
    Calling undeclared function false_positive. Old style K&R code?
  f: defined at find-fun2.c:6 (1 statement);
  g: defined at find-fun2.c:10 (3 statements);
  h: defined at find-fun2.c:15 (2 statements);
  k: defined at list-functions.c:13 (8 statements);
  static_fun: defined at find-fun2.c:24 (1 statement), list-functions.c:4 (7 statements);

  $ frama-c-script list-functions find-fun2.c list-functions.c -list-functions-declarations -list-functions-output ./list-functions2.json -list-functions-debug 1
  [kernel:typing:implicit-function-declaration] find-fun2.c:12: Warning: 
    Calling undeclared function false_positive. Old style K&R code?
  [list-functions] List written to: list-functions2.json

  $ cat list-functions2.json
  [ { "extf": { "declarations": [ "list-functions2.h:1" ] } },
    { "f": { "definitions": [ { "location": "find-fun2.c:6", "statements": 1 } ] } },
    { "false_positive": { "declarations": [ "find-fun2.c:21" ] } },
    { "g": { "definitions": [ { "location": "find-fun2.c:10", "statements": 3 } ] } },
    { "h": { "definitions": [ { "location": "find-fun2.c:15", "statements": 2 } ] } },
    { "k": { "definitions": [ { "location": "list-functions.c:13",
                                "statements": 8 } ] } },
    { "static_fun": { "definitions": [ { "location": "find-fun2.c:24",
                                         "statements": 1 },
                                       { "location": "list-functions.c:4",
                                         "statements": 7 } ] } } ]
