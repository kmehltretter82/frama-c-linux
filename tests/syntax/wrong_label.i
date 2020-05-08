void f() {
  /*@ assert \true; */
}

void main() {
  {_LOR:} // KO: labels can't be at the end of a block.
}
