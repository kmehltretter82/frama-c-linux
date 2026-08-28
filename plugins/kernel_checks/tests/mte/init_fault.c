/* run.config
   OPT: -kernel-checks -eva-slevel 20 -machdep gcc_arm64
*/

typedef unsigned long size_t;

int try_page_mte_tagging(void *page)
{
  (void)page;
  return 1;
}

int folio_try_hugetlb_mte_tagging(void *folio)
{
  (void)folio;
  return 1;
}

void set_page_mte_tagged(void *page)
{
  (void)page;
}

void folio_set_hugetlb_mte_tagged(void *folio)
{
  (void)folio;
}

size_t mte_copy_tags_from_user(void *to, const void *from, size_t count)
{
  (void)to;
  (void)from;
  return count;
}

void mte_copy_tags_from_kernel(void *to, const void *from, size_t count)
{
  (void)to;
  (void)from;
  (void)count;
}

static void vulnerable_import(int hugetlb, void *page, const void *user_tags)
{
  if (hugetlb)
    folio_try_hugetlb_mte_tagging(page);
  else
    try_page_mte_tagging(page);

  mte_copy_tags_from_user(page, user_tags, 256);

  if (hugetlb)
    folio_set_hugetlb_mte_tagged(page);
  else
    set_page_mte_tagged(page);
}

static void safe_prefaulted_import(int hugetlb, void *page,
                                   const void *kernel_tags)
{
  if (hugetlb)
    folio_try_hugetlb_mte_tagging(page);
  else
    try_page_mte_tagging(page);

  mte_copy_tags_from_kernel(page, kernel_tags, 256);

  if (hugetlb)
    folio_set_hugetlb_mte_tagged(page);
  else
    set_page_mte_tagged(page);
}

int main(int selector)
{
  unsigned char page[4096] = { 0 };
  unsigned char tags[256] = { 0 };

  vulnerable_import(selector, page, tags);
  safe_prefaulted_import(selector, page, tags);
  return 0;
}
