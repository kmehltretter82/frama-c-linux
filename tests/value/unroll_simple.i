void main (int c) {
  int G=0,i=4;
  int MAX = 12;
  int JMAX=5;
  int j=3;

//@ loop unfold 128;
  do {
    G += i;
    i++;
    j--;
    }
  while (i<=256 || j>=0);

//@ loop unfold 10;
 do
    { if(c) continue;

    if(c--) goto L;
    c++;
  L: c++;
      }
  while(c);
}
