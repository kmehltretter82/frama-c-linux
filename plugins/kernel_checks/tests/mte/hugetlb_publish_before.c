/* run.config
   OPT: -eva -eva-slevel 20 -machdep gcc_arm64
*/

/*
 * Reduced model of the folio-granularity invariant shared by
 * kvm_vm_ioctl_mte_copy_tags() and sanitise_mte_tags().
 */

#define FOLIO_PAGES 4

struct mte_folio {
  unsigned char tagged;
  unsigned char initialized[FOLIO_PAGES];
};

static void publish_after_one_page(struct mte_folio *folio,
                                   unsigned int page)
{
  folio->initialized[page] = 1;
  folio->tagged = 1;
}

int main(void)
{
  struct mte_folio folio = { 0 };

  publish_after_one_page(&folio, 1);

  /* A folio-wide tagged bit promises initialized tags on every subpage. */
  /*@ assert folio_wide_validity:
        !folio.tagged ||
        (folio.initialized[0] && folio.initialized[1] &&
         folio.initialized[2] && folio.initialized[3]);
   */
  return 0;
}
