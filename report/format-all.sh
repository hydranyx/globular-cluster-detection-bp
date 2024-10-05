#!/usr/bin/env bash
set -euo pipefail

echo "Formatting LaTeX sources"
for file in **/*.tex; do
  echo "   ➤ Formatting '$file'"
  latexindent -w -l -s $file
done

echo "Removing generated backup files"
rm ./*.bak*

echo "Formatting BibTeX sources"
for file in **/*.bib; do
  echo "   ➤ Formatting '$file'"
  bibtex-tidy --curly --numeric --space=4 --align=13 --sort=key --duplicates=key --no-escape --sort-fields=title,shorttitle,author,year,month,day,journal,booktitle,location,on,publisher,address,series,volume,number,pages,doi,isbn,issn,url,urldate,copyright,category,note,metadata --trailing-commas --encode-urls --remove-empty-fields $file > /dev/null
done
