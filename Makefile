default: build

b build:
	jekyll build

s server:
	jekyll server --watch

css:
	pygmentize -S default -f html > common/css/syntax.css

