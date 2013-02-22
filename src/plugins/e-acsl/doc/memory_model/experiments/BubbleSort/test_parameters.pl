:- module(test_parameters).
:- import create_input_val/3 from substitution.
:- export dom/4.
:- export create_input_vals/2.
:- export unquantif_preconds/2.
:- export quantif_preconds/2.
:- export strategy/2.
:- export precondition_of/2.

dom('bubble_sort',cont('a',_),[],int([-20..20])).

create_input_vals('bubble_sort',Ins):-
  create_input_val(dim('a'),int([0..6]),Ins),
  create_input_val('length',int([0..6]),Ins),
  true.

unquantif_preconds('bubble_sort',[cond(egal,dim('a'),'length',pre)]).

quantif_preconds('bubble_sort',[]).
strategy('bubble_sort',[]).
precondition_of(0,0).
