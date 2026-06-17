//@ pmodel (int) a;
//@ pframe a;
//@ pwhen a;
//@ pinvariant a;
//@ pcase A {}

/*@
 datamodel Error {
    pcase A {
      pcase B {}
    }
    pwhen b;
} 
*/