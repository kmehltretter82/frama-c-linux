#include "mthread_pthread.h"

pthread_t interrupt_thread;
int interrupt_received;

void interrupt(void) {
  interrupt_received = 1;
}

void* interrupt_stub_loop (void* _) {
  while (1) {
    interrupt();
  }
}

void do_something(void) {
  // anything
}

int main () {
  
  pthread_create(&interrupt_thread, 0, interrupt_stub_loop, 0);

  while (1) {
    Frama_C_show_each_locked(interrupt_received);
    if (interrupt_received) {
      Frama_C_show_each(interrupt_received);
      interrupt_received = 0;
      Frama_C_show_each(interrupt_received);
      do_something();
    }
  }
}
