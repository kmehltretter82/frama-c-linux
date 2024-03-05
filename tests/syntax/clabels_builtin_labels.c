int x;

void named(void){
  x = 4;
Init: Pre: Old: Post: Here: LoopCurrent: LoopEntry: A:;
  x = 5;
X: Y: ;
  x = 6;
Z: T: ;
  x = 7;
}

void post_over_old_1(void){ Old: Post: ;}
void post_over_old_2(void){ Post: Old: ;}

void post_over_loop_1(void){ LoopEntry: Post: ;}
void post_over_loop_2(void){ Post: LoopCurrent: ;}

void post_over_other_1(void){ Here: Post: ;}
void post_over_other_2(void){ Post: Pre: ;}
void post_over_other_3(void){ Init: Post: Pre: ;}

void old_over_loop_1(void){ LoopEntry: Old: ;}
void old_over_loop_2(void){ Old: LoopCurrent: ;}

void old_over_other_1(void){ Here: Old: ;}
void old_over_other_2(void){ Old: Pre: ;}
void old_over_other_3(void){ Init: Old: Pre: ;}

void loop_over_other_1(void){ Here: LoopEntry: ;}
void loop_over_other_2(void){ LoopCurrent: Pre: ;}
void loop_over_other_3(void){ Init: LoopEntry: Pre: ;}

void arbitray_other_1(void){ Here: Init: ;}
void arbitray_other_2(void){ Init: Pre: ;}
void arbitray_other_3(void){ Pre: Here: Init: ;}
