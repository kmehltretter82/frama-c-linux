/* run.config
   ENABLED_IF: (<> %{system} macosx)
   STDOPT: #"-std=c23 -cpp-extra-args='-Wno-trigraphs'"
   STDOPT: #"-std=c23 -cpp-extra-args='-Wno-trigraphs -trigraphs'"
*/
int main() {
  char *s1 = "??";
  char *s2 = "??=";
  char *s3 = "???";
  char *s4 = "????";
  char *s5 = "?\?\?=";
  char *s6 = "??\?=";
  char *s7 = "?\??\???=?\?=\\??=?";
  char *s8 = "??\\??=";
  return 0;
}
