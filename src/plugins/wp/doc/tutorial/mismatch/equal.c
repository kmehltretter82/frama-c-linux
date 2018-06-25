#include "mismatch.h"
#include "../equal/equal.h"
bool equal(const value_type* p, size_type m, const value_type* q)
{
  return mismatch(p, m, q) == m; 
}


