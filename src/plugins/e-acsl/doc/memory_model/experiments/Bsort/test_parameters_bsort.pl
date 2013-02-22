:- module(test_parameters).

:- import create_input_val/3 from substitution.

:- export dom/4.
:- export create_input_vals/2.
:- export unquantif_preconds/2.
:- export quantif_preconds/2.
:- export strategy/2.
:- export precondition_of/2.

dom('bsort',cont('table',_),[],int([-100..100])).

create_input_vals('bsort',Ins):-
  create_input_val(dim('table'),int([0..5]),Ins),
  create_input_val('l',int([0..5]),Ins),
  true.

unquantif_preconds('bsort',[cond(egal,dim('table'),'l',pre)]).
quantif_preconds('bsort',[]).

strategy('bsort',[]).

precondition_of(0,0).
