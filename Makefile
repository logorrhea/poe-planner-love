love:
	love .

build:
	zip -r -X poe-planner.love . -x ".*" -x "*/.*" -x "Makefile" -x "TODO.org"
