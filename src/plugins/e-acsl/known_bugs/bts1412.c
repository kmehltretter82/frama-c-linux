
typedef unsigned size_t;
extern void* malloc(size_t);
extern void free(void*);
#define NULL 0
#define LEN 5

unsigned long T[LEN];

struct list {
  int element;
  struct list * next;
};

struct list * merge_sort(struct list *);


/*@ behavior null:
  @  assumes l == \null;
  @  ensures \result == \null;
  @ behavior not_null:
  @  ensures \valid(\result);
  @*/
struct list * merge_sort(struct list * l) {
  if(l == NULL)
    return l;
  if(l->next == NULL)
    return l;
  
  /* SPLIT */
  int cpt = 0;
  struct list * L1 = l, * L2 = l->next, * next, * ret = NULL,
    * tmp = L2->next, * iterL1 = L1, * iterL2 = L2;
  L1->next = L2->next = NULL;
  
  while(tmp != NULL) {
    struct list * new = malloc(sizeof(struct list));
    new->element = tmp->element;
    new->next = NULL;
    
    next = tmp->next;
    if(cpt % 2)
      iterL2 = (iterL2->next = new);
    else
      iterL1 = (iterL1->next = new);
    free(tmp);
    tmp = next;
    cpt++;
  }
  
  /* RECURSION */
  L1 = merge_sort(L1);
  L2 = merge_sort(L2);
  
  /* MERGE */
  if(L1->element < L2->element) {
    ret = L1;
    L1 = L1->next;
  } else {
    ret = L2;
    L2 = L2->next;
  }
  tmp = ret;
  
  while(L1 != NULL || L2 != NULL) {
    if(L1 == NULL) {
      tmp->next = L2;
      break;
    }
    if(L2 == NULL) {
      tmp->next = L1;
      break;
    }
    struct list * new = malloc(sizeof(struct list));
    
    if(L1->element < L2->element) {
      new->element = L1->element;
      new->next = NULL;
      tmp->next = new;
      next = L1->next;
      free(L1);
      L1 = next;
    } else {
      new->element = L2->element;
      new->next = NULL;
      tmp->next = new;
      next = L2->next;
      free(L2);
      L2 = next;
    }
    tmp = new;
  }
  
  return l;
}


/*@ ensures \valid(\result);
  @ ensures \result->element == i;
  @ ensures \result->next == \old(l);
  @*/
struct list * add(struct list * l, int i) {
  struct list * new;
  new = malloc(sizeof(struct list));
  new->element = i;
  new->next = l;
  return new;
}

/*@ ensures \result == \null;
  @*/
struct list * erase(struct list * l) {
  struct list * tmp = l;
  while(tmp != NULL) {
    struct list * next = tmp->next;
    //@ assert \valid(tmp);
    free(tmp);
    tmp = next;
  }
  return tmp;
}

int main() {
  struct list * L = NULL;
  int i = 0;

  //@ assert 0 <= i <= LEN;
  /*@ loop invariant 0 <= i <= LEN;
    @ loop assigns i, T[0..(LEN-1)];
    @ loop variant LEN-i;
    @*/
  for(; i < LEN;) {
    T[i] = i+LEN%32*i;
    i++;
    //@ assert 0 <= i <= LEN;
  }
  
  i = 0;
  //@ assert 0 <= i <= LEN;
  /*@ loop invariant 0 <= i <= LEN;
    @ loop assigns i, L;
    @ loop variant LEN-i;
    @*/
  for(; i < LEN;) {
    L = add(L, T[i]);
    i++;
    //@ assert 0 <= i <= LEN;
  }
  L = merge_sort(L);
  L = erase(L);

  return 0;
}

