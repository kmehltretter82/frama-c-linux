:- module(test_parameters).

:- import create_input_val/3 from substitution.

:- export dom/4.
:- export create_input_vals/2.
:- export unquantif_preconds/2.
:- export quantif_preconds/2.
:- export strategy/2.
:- export precondition_of/2.

dom('Merge',cont('t1',_),[],int([-10..10])).
dom('Merge',cont('t2',_),[],int([-10..10])).

create_input_vals('Merge',Ins):-
  create_input_val(dim('t1'),int([0..10]),Ins),
  create_input_val(dim('t2'),int([0..10]),Ins),
  create_input_val(dim('t3'),int([0..20]),Ins),
  create_input_val('l1',int([0..10]),Ins),
  create_input_val('l2',int([0..10]),Ins),
  true.

unquantif_preconds('Merge',
                   [cond(supegal,dim('t1'),'l1',pre),
                    cond(supegal,dim('t2'),'l2',pre),
                    cond(supegal,dim('t3'),+(int(math),'l1','l2'),pre)]).
quantif_preconds('Merge',[uq_cond([UQV3],
             [cond(supegal,UQV3,1,pre)],
             supegal,
             cont('t1',UQV3),
             cont('t1',-(int(math),UQV3,1))),
      uq_cond([UQV4],
              [cond(supegal,UQV4,1,pre)],
              supegal,
              cont('t2',UQV4),
              cont('t2',-(int(math),UQV4,1)))]).

strategy('Merge',[kpath(2)]).

precondition_of(0,0).





































