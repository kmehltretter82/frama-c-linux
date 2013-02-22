:- module(test_parameters).
:- import create_input_val/3 from substitution.
:- export dom/4.
:- export create_input_vals/2.
:- export unquantif_preconds/2.
:- export quantif_preconds/2.
:- export strategy/2.
:- export precondition_of/2.

dom('fibo', cont('t',_), [], int([-10..10])).
create_input_vals('fibo', Ins):-
  create_input_val('n', int([3..40]),Ins),
  create_input_val(dim('t'), int([3..40]),Ins),
  true.

quantif_preconds('fibo',[]).
unquantif_preconds('fibo',[cond(egal,dim('t'),'n',pre)]).
strategy('fibo',[]).
precondition_of(0,0).
