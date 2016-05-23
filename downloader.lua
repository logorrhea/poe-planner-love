local http = require 'socket.http'
local json = require 'vendor.dkjson'
local os = require 'os'
local fs = love.filesystem


Downloader = {}
Downloader.__index = Downloader
Downloader.skillTreeURL = 'http://www.pathofexile.com/passive-skill-tree/'
Downloader.cacheLimit = 60*60*24 -- one day

function Downloader.getLuaTree()
  local jsonString

  -- Check for cached file first
  local needNewVersion = true
  if fs.exists('passive-skill-tree.json') then
    local lastModified = fs.getLastModified('passive-skill-tree.json')
    local systemTime = os.time()
    if systemTime - lastModified < Downloader.cacheLimit then
      needNewVersion = false
    end
  end

  -- If cached version is too old, get a new one
  if needNewVersion then
    local body, status, headers = http.request(Downloader.skillTreeURL)
    if status ~= 200 then
      print('oh fuck, errors:', status)
      print(body)
    end
    local json = extractTreeData(body)
    fs.write('passive-skill-tree.json', json)
    jsonString = json
  else
    -- Otherwise read existing cached version
    jsonString, _ = fs.read('passive-skill-tree.json')
  end

  -- Transform json string into lua data
  local tree, err = json.decode(jsonString)
  if err then
    print(err)
  end

  -- Download new versions of the assets
  if needNewVersion then
    -- Make sure assets directory exists
    if not fs.exists('assets') then
      fs.createDirectory('assets')
    end
    -- @TODO: For each of these functions, make sure
    -- the image is png, and if not, encode is as png
    -- using ImageData:encode (i hope =\)
    Downloader.downloadAssets(tree)
    Downloader.downloadSkillSprites(tree)
  end

  return tree
end

-- Download assets
function Downloader.downloadAssets(tree)
  local fullImageRoot = tree.imageRoot..'build-gen/passive-skill-sprite'

  -- Loop through asset data, download largest version of each
  for name, asset in pairs(tree.assets) do
    local largest = 0
    local url = nil

    for s, p in pairs(asset) do
      s = tonumber(s)
      if s > largest then
        largest = s
        url = p
      end
    end

    if url ~= nil then
      local pathParts = ssplit(url, '/')
      local filename = pathParts[#pathParts]
      local response = http.request(url)
      fs.write('assets/'..filename, response)
    end
  end
end

function Downloader.downloadSkillSprites(tree)
  local fullImageRoot = tree.imageRoot .. 'build-gen/passive-skill-sprite/'
  for name, sprites in pairs(tree.skillSprites) do
    local spriteInfo = sprites[#sprites]
    local response = http.request(fullImageRoot..spriteInfo.filename)
    fs.write('assets/'..spriteInfo.filename, response)
  end
end


function extractTreeData(html)
  local pattern = 'var passiveSkillTreeData = '
  local match = html:match(pattern..'.-\n')
  local jsonString = match:sub(#pattern, #match - 2)
  return jsonString
end

function ssplit(str, sep)
  local t = {}
  for m in str:gmatch("([^"..sep.."]+)") do
    t[#t] = m
  end
  return t
end
