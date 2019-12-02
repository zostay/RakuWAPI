README.md: fixup-markdown RakuWAPI.pod
	perl6 --doc=Markdown RakuWAPI.pod | perl6 fixup-markdown > README.md
