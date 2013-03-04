:- module(test_parameters).

:- import create_input_val/3 from substitution.

:- export dom/4.
:- export create_input_vals/2.
:- export unquantif_preconds/2.
:- export quantif_preconds/2.
:- export strategy/2.
:- export precondition_of/2.

:- export disable_label_history/1.
disable_label_history(yes).
dom('getsub',cont('arg__getsub',_),[],int([-128..127])).
dom('getsub',cont('sub__getsub',_),[],int([-128..127])).
% add new array domain e.g.:
%  dom('yourFunName',cont('yourArray',_),[],int([min..max])).

create_input_vals('getsub',Ins):-
  create_input_val(dim('sub__getsub'),int([5..5]),Ins),
  create_input_val(dim('arg__getsub'),int([7..7]),Ins),
  true.
% add new variable domain e.g.:
%  create_input_val(yourVarName,int([min..max]),Ins), 


unquantif_preconds('getsub',[cond(egal,cont('sub__getsub',4),0,pre),
                             cond(egal,cont('arg__getsub',6),0,pre)]).

quantif_preconds('getsub',[]).

strategy('getsub',[]).

precondition_of(0,0).


