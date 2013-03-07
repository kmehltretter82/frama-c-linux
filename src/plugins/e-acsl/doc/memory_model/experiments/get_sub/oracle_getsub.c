
#include "string.h"

void oracle_getsub(char* Pre_arg, char* arg, char* Pre_sub, char* sub, int r) {
  char* tmp_arg = Pre_arg;
  char* tmp_sub = sub;
  while(*tmp_arg != 0) {
    if(*tmp_arg == '&') {
      if(*tmp_sub != -1) {pathcrawler_verdict_failure();return;}
      tmp_arg++; tmp_sub++;
    }
    else if(*tmp_arg == '@' && *(tmp_arg+1) == '\0') {
      if(*tmp_sub != '@') {pathcrawler_verdict_failure();return;}
      tmp_arg++; tmp_sub++;
    }
    else if(*tmp_arg == '@' && *(tmp_arg+1) == 'n') {
      if(*tmp_sub != 10) {pathcrawler_verdict_failure();return;}
      tmp_arg += 2; tmp_sub++;
    }
    else if(*tmp_arg == '@' && *(tmp_arg+1) == 't') {
      if(*tmp_sub != 9) {pathcrawler_verdict_failure();return;}
      tmp_arg += 2; tmp_sub++;
    }
    else if(*tmp_arg == '@') {
      if(*tmp_sub != *(tmp_arg+1)) {pathcrawler_verdict_failure();return;}
      tmp_arg += 2; tmp_sub++;
    }
    else {
      if(*tmp_sub != *tmp_arg) {pathcrawler_verdict_failure();return;}
      tmp_arg++; tmp_sub++;
    }
  }
      
  pathcrawler_verdict_success();
  return;
}
