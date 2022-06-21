/* run.config
PLUGIN: @EVA_PLUGINS@
STDOPT:
*/

int x;
void main() {
  unsigned char buf[sizeof(unsigned char[1]) + sizeof(x)];
  buf[sizeof(buf)];
}
