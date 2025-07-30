ALL: README.md

README.md: README.Rmd bigdata.bib
		Rscript -e "rmarkdown::render('README.Rmd')"

