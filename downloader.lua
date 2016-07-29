local http = require 'socket.http'
local json = require 'vendor.dkjson'
local ser = require 'vendor.Ser.ser'
-- local magick = require 'magick'
local os = require 'os'
local fs = love.filesystem


Downloader = {}
Downloader.__index = Downloader
Downloader.skillTreeURL = 'http://www.pathofexile.com/passive-skill-tree/'
Downloader.cacheLimit = 60*60*24 -- one day

function Downloader.getLuaTree()
  local tree, err

  -- Check for cached file first
  local needNewVersion = true
  if fs.exists('passive-skill-tree.lua') then
    local lastModified = fs.getLastModified('passive-skill-tree.lua')
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

    -- Decode json data into lua
    local jsonString = extractTreeData(body)
    tree, err = json.decode(jsonString)
    if err then
      print(err)
    end

    -- Serialize tree into lua file
    fs.write('passive-skill-tree.lua', ser(tree))

    -- Download new versions of the assets
    -- Make sure assets directory exists
    if not fs.exists('assets') then
      fs.createDirectory('assets')
    end
    Downloader.downloadAssets(tree)
    Downloader.downloadSkillSprites(tree)
    Downloader.convertNonPng()
  else
    -- Otherwise read existing cached version
    tree = require 'passive-skill-tree'
  end

  return tree
end

function Downloader.processNodes(tree)
  local nodes = {}
  local groups = {}
  local startNodes = {}

  -- Create groups
  for gid, group in pairs(Tree.groups) do
    local id = tonumber(gid)
    local group = Group.create(id, group)
    groups[id] = group
  end

  -- Create nodes
  for _, n in pairs(Tree.nodes) do
    local node = Node.create(n, groups[n.g])
    if groups[n.g].type == nil then
      groups[n.g].type = node.orbit
    end
    if groups[n.g].orbit == nil and node.orbit ~= nil then
      groups[n.g].orbit = node.orbit
    end

    -- Add to startNode table if it is one
    if node.type == Node.NT_START then
      local spc = node:startPositionClass()
      startNodes[spc] = node.id
    end

    nodes[node.id] = node
  end

  -- Run through nodes a second time, so we can make links
  -- go both directions
  for nid, node in pairs(nodes) do
    for _, lnid in ipairs(node.out) do
      if lnid ~= nid and nodes[lnid].neighbors[nid] == nil then
        table.insert(nodes[lnid].neighbors, nid)
      end
    end
  end

  local data = {
    groups = groups,
    nodes = nodes
  }

  -- Save serialized tree to file
  local dataString = ser(data)
  love.filesystem.write('processed-tree-data.lua', dataString)

  -- Return processed data
  return data
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
      local fdata = love.filesystem.newFileData(response, filename, 'file')
      fs.write('assets/'..fdata:getFilename(), response)
    end
  end
end

function Downloader.downloadSkillSprites(tree)
  local fullImageRoot = tree.imageRoot .. 'build-gen/passive-skill-sprite/'
  for name, sprites in pairs(tree.skillSprites) do
    local spriteInfo = sprites[#sprites]
    local response = http.request(fullImageRoot..spriteInfo.filename)
    local fdata = love.filesystem.newFileData(response, spriteInfo.filename, 'file')
    fs.write('assets/'..fdata:getFilename(), response)
  end
end

-- Only works on desktops with imagemagick installed
function Downloader.convertNonPng()
  for k, file in ipairs(love.filesystem.getDirectoryItems('assets')) do
    local fdata = love.filesystem.newFileData('assets/'..file)
    if fdata:getExtension() ~= 'png' then
      local newFileName = fdata:getFilename():gsub('.'..fdata:getExtension(), '.png')
      local img = assert(magick.load_image_from_blob(fdata:getString()))
      if img then
        img:set_format('png')
        local data = love.filesystem.newFileData(img:get_blob(), newFileName)
        love.filesystem.write(newFileName, data)
        img:destroy()
      end
    end
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

