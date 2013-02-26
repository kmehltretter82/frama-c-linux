:- module(test_parameters).

:- import create_input_val/3 from substitution.

:- export dom/4.
:- export create_input_vals/2.
:- export unquantif_preconds/2.
:- export quantif_preconds/2.
:- export strategy/2.
:- export precondition_of/2.

dom('Multiply',dim(cont('A',_)),[],int([0..100])).
dom('Multiply',dim(cont('B',_)),[],int([0..100])).
dom('Multiply',dim(cont('Res',_)),[],int([0..100])).
dom('Multiply',cont(cont('A',_),_),[],int([-100..100])).
dom('Multiply',cont(cont('B',_),_),[],int([-100..100])).
dom('Multiply',cont(cont('Res',_),_),[],int([0])).

create_input_vals('Multiply',Ins):-
  create_input_val(dim('A'),int([0..100]),Ins),
  create_input_val(dim('B'),int([0..100]),Ins),
  create_input_val(dim('Res'),int([0..100]),Ins),
  create_input_val('n',int([2..10]),Ins),
  true.

unquantif_preconds('Multiply',[
  cond(egal,'n',dim('A'),pre),
  cond(egal,'n',dim('B'),pre),
  cond(egal,'n',dim('Res'),pre)
]).
quantif_preconds('Multiply',[
  uq_cond([I],[cond(supegal,I,0,pre),cond(inf,I,'n',pre)],
          egal,'n',dim(cont('A',I))),
  uq_cond([I],[cond(supegal,I,0,pre),cond(inf,I,'n',pre)],
          egal,'n',dim(cont('B',I))),
  uq_cond([I],[cond(supegal,I,0,pre),cond(inf,I,'n',pre)],
          egal,'n',dim(cont('Res',I)))
]).
strategy('Multiply',[]).
precondition_of(0,0).
