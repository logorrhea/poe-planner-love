build:
	zip -r -X poe-planner.love . -x ".*" -x "*/.*" -x "Makefile"

love:
	love .
