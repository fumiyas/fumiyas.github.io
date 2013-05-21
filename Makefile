default: build

.PHONY: b build s server css

p push:
	$(MAKE) build
	git push --tags origin master

b build:
	jekyll build

s server:
	jekyll server --watch

css:
	pygmentize -S default -f html > common/css/syntax.css

