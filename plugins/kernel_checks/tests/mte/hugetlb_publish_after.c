/* run.config
   OPT: -eva -eva-slevel 20 -machdep gcc_arm64
*/

#define FOLIO_PAGES 4

struct mte_folio {
  unsigned char tagged;
  unsigned char initialized[FOLIO_PAGES];
};

static void publish_after_whole_folio(struct mte_folio *folio,
                                      unsigned int page)
{
  unsigned int index;

  for (index = 0; index < FOLIO_PAGES; index++)
    folio->initialized[index] = 1;

  /* The selected page's imported tags replace its cleared tags here. */
  folio->initialized[page] = 1;
  folio->tagged = 1;
}

int main(void)
{
  struct mte_folio folio = { 0 };

  publish_after_whole_folio(&folio, 1);

  /*@ assert folio_wide_validity:
        !folio.tagged ||
        (folio.initialized[0] && folio.initialized[1] &&
         folio.initialized[2] && folio.initialized[3]);
   */
  return 0;
}
