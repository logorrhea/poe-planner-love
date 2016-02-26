build:
	zip -r -X poe-planner.love . -x ".*" -x "*/.*" -x "Makefile"

build-old:
	zip poe-planner.love -R .	*.lua */*.lua */**/*.lua *.js */**/*.js *.json */**/*.json *.png */**/*.png *.ttf */**/*.ttf
