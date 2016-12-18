# lunPDF
## pure lua pdf page splitter 

As help material I used a PyPDF2 sources  
https://github.com/mstamy2/PyPDF2 
and ISO32000
https://en.wikipedia.org/wiki/Portable_Document_Format

Run:
```
lua pdfsplit.lua YOURNAME.pdf
```
as a result you get pdf files with YOURNAME-N.pdf names. Where N is number from 1 to number of pages in source pdf file.
Splitter is absolutlely not universal and tested only on LibreOffice and unknown scanner pdf docs.

