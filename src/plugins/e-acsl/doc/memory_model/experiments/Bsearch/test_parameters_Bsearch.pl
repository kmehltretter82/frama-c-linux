:- module(test_parameters).

:- import create_input_val/3 from substitution.

:- export dom/4.
:- export create_input_vals/2.
:- export unquantif_preconds/2.
:- export quantif_preconds/2.
:- export strategy/2.
:- export precondition_of/2.

dom('Bsearch',cont('A',_),[],int([0..100])).
dom('pathcrawler__Bsearch_precond',A,B,C):-
  dom('Bsearch',A,B,C).

create_input_vals('Bsearch',Ins):-
  create_input_val('elem',int([0..100]),Ins),
  create_input_val(dim('A'),int([10]),Ins),
  true.
create_input_vals('Bsearch',Ins):-
  create_input_vals('pathcrawler__Bsearch_precond',Ins).

unquantif_preconds('Bsearch',[]).
quantif_preconds('Bsearch',[]).

strategy('Bsearch',[]).
strategy('pathcrawler__Bsearch_precond',[]).

precondition_of('Bsearch','pathcrawler__Bsearch_precond').
