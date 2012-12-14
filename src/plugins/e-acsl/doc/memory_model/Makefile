
BIB=biblio.bib

all: article

article: article.pdf

article.dvi: article.tex $(BIB)
	latex $^
	bibtex article
	latex $^
	latex $^

article.pdf: article.dvi
	dvipdf article.dvi

clean:
	rm *.toc *.aux *.pdf *.log *.bbl *.blg *.dvi *.nav *.out *.snm

