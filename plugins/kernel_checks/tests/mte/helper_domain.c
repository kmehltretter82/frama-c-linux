/* run.config
   OPT: -kernel-checks -kernel-checks-ast-only -machdep gcc_arm64
   FILTER: sed -e 's/[[:space:]]*$//'
*/

struct page;
struct folio;

struct folio *page_folio(struct page *page);
int folio_test_hugetlb(const struct folio *folio);
int folio_test_hugetlb_mte_tagged(struct folio *folio);
int page_mte_tagged(struct page *page);

static int vulnerable_read(struct page *page)
{
  struct folio *folio = page_folio(page);

  return (folio_test_hugetlb(folio) &&
          folio_test_hugetlb_mte_tagged(folio)) ||
         page_mte_tagged(page);
}

static int safe_read(struct page *page)
{
  struct folio *folio = page_folio(page);

  return folio_test_hugetlb(folio) ?
         folio_test_hugetlb_mte_tagged(folio) :
         page_mte_tagged(page);
}

int main(struct page *page)
{
  return vulnerable_read(page) + safe_read(page);
}
