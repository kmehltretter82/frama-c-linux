
/*@ ensures \forall int i; 0 <= i < length-1 ==> a[i] <= a[i+1];
  @*/
void bubble_sort(int* a, int length)
{
 int auf = 1;
 int ab;
 int fixed_auf = 1;
 

 for (; auf < length; )  
 {  
   //@ assert auf < length;
  fixed_auf = auf;
  ab=auf;
 
  while (0 < ab && a[ab] < a[ab-1])
  {   
    //@ assert 0 < ab;
    //@ assert a[ab] < a[ab-1];
    //@ ghost int old_1 = a[ab];
    //@ ghost int old_2 = a[ab-1];
    int temp = a[ab];
    a[ab] = a[ab-1];
    a[ab-1] = temp;

    //@ assert old_1 == a[ab-1];
    //@ assert old_2 == a[ab];
 
    //@ ghost int old_ab = ab;
    ab = ab-1;            
    //@ assert old_ab - 1 == ab;
  }
  //@ assert 0 >= ab || a[ab] >= a[ab-1];

 //@ ghost int old_auf = auf;
 auf++;
 //@ assert old_auf + 1 == auf;

 fixed_auf = auf;
 }
 //@ assert auf >= length;
}

