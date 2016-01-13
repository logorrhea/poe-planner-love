var request = require('request');
var fs = require('fs');

function downloadAndTrim() {
    request('http://www.pathofexile.com/passive-skill-tree/', function(error, response, body) {
        if (!error && response.statusCode == 200) {
            var pattern = /var passiveSkillTreeData = [^\n]*/g;
            var matches = body.match(pattern);
            if (matches) {
                var match = matches[0];
                var subPattern = "var passiveSkillTreeData = ";
                var stripped = match.substr(subPattern.length, match.length - subPattern.length - 1);
                fs.writeFile('dat.json', stripped, function(err) {
                    if (err) throw err;
                    console.log('dat.json written');
                });
            } else {
                throw "No matches for RegExp";
            }
        } else {
            throw error;
        }
    });
}

downloadAndTrim();
