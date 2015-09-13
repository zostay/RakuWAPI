README.md: P6SGI.pod
	perl6 --doc=Markdown P6SGI.pod > README.md.tmp
	perl6 -pe '.=subst(/ "C<<" ( [ <-[ > ]> | ">" <!before ">" > ]+ ) ">>" | "C<" ( <-[ > ]>+ ) ">" /, { "<code>{($$0 // $$1).trim}</code>" })' README.md.tmp > README.md

clean:
	rm -f README.md.tmp
