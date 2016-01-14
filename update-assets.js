var request = require('request');
var fs = require('fs');

function serialize(table) {
    var destination = 'data/json/skillTree.lua';

    // Write a lua table to file for inclusion later
}

// Expects the "assets" object from the POE info json
function downloadAssets(assets) {
    var assetPaths = {}
    for (asset in assets) {
        var largest = 0
        for (size in assets[asset]) {
            largest = largest < size ? size : largest;
        }

        if (largest !== 0) {
            var path = assets[asset][largest];
            var pathParts = path.split('/');
            var filepath = 'assets/'+pathParts[pathParts.length-1];
            console.log(asset + ' -> ' + filepath);
            request(path).pipe(fs.createWriteStream(filepath));
        } else {
            throw "No size found"
        }
    }

    return assetPaths;
}

function downloadSkillSprites(imageRoot, skillSprites) {
    var fullImageRoot = imageRoot + "build-gen/passive-skill-sprite/"

    for (skillSprite in skillSprites) {
        var sizes = skillSprites[skillSprite];
        var spriteInfo = sizes[sizes.length-1];
        request(fullImageRoot+spriteInfo.filename)
            .pipe(fs.createWriteStream('assets/'+spriteInfo.filename));
    }
}


var readFileOpts = {
    encoding: 'utf8',
    flag: 'r',
}
fs.readFile('dat.json', readFileOpts, function (err, data) {
    if (err) throw err;

    var data = JSON.parse(data);

    // Download new assets
    // var assetData = downloadAssets(data.assets);

    // Download new skill sprites
    // var skillSprites = downloadSkillSprites(data.imageRoot, data.skillSprites);
});


