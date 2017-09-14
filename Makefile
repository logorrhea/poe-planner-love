love:
	love .

build:
	7z a -r -tzip poe-planner.love . "-x!.*" "-x!*/.*" "-x!Makefile" "-x!TODO.org" "-x!pretty.json" "-x!stats.txt" "-x!stat-screen-sample.png" "-x!*.love"
