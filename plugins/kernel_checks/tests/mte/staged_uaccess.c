/* run.config
   OPT: -kernel-checks -eva-slevel 20 -machdep gcc_arm64
*/

typedef unsigned long size_t;

int try_page_mte_tagging(void *page)
{
  (void)page;
  return 1;
}

void set_page_mte_tagged(void *page)
{
  (void)page;
}

size_t copy_from_user(void *to, const void *from, size_t count)
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

static void staged_import(void *page, const void *user_tags)
{
  unsigned char tag_buf[256];

  copy_from_user(tag_buf, user_tags, sizeof(tag_buf));
  try_page_mte_tagging(page);
  mte_copy_tags_from_kernel(page, tag_buf, sizeof(tag_buf));
  set_page_mte_tagged(page);
}

static void misplaced_staging(void *page, const void *user_tags)
{
  unsigned char tag_buf[256];

  try_page_mte_tagging(page);
  copy_from_user(tag_buf, user_tags, sizeof(tag_buf));
  mte_copy_tags_from_kernel(page, tag_buf, sizeof(tag_buf));
  set_page_mte_tagged(page);
}

int main(void)
{
  unsigned char page[4096] = { 0 };
  unsigned char tags[256] = { 0 };

  staged_import(page, tags);
  misplaced_staging(page, tags);
  return 0;
}
