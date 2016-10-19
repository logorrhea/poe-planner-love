local bit    = require 'bit'
local basexx = require 'lib.basexx'
local ser    = require 'lib.ser'
local to_base64, from_base64 = basexx.to_base64, basexx.from_base64

Graph = {}
Graph.__index = Graph

function table.icontains(t, needle)
  for _, v in ipairs(t) do
    if v == needle then
      return true
    end
  end
  return false
end

function table.contains(t, needle)
  for _, v in pairs(t) do
    if v == needle then
      return true
    end
  end
  return false
end

function Graph.planShortestRoute(tid)
  local found, tiers, visited = searchNearest({[1]=tid}, 1, {}, {})
  local route = getRouteFromTiers(found, tiers, tid)
  -- print('----------------------------------------------------------------')
  return route
end

function Graph.planRefund(rid)
  local rnode = nodes[rid]
  local reachable = {}
  local unreachable = {}

  local root = startNodes[activeClass]
  findReachable(root, reachable, rid)

  for nid, node in pairs(nodes) do
    if node.active and not reachable[nid] then
      unreachable[nid] = true
    end
  end

  return unreachable
end

function findReachable(from, reachable, clicked)
  reachable[from] = true
  local f = nodes[from]
  for _, nid in ipairs(f.neighbors) do
    local node = nodes[nid]
    if node.active and node.id ~= clicked and reachable[nid] == nil then
      findReachable(nid, reachable, clicked)
    end
  end
end

function Graph.import(saveData)
  -- Update to new save format if necessary
  if saveData.version == nil then
    print('updating save data')
    saveData = Graph.update(saveData)
  else
    print('save file already using most recent configuration')
  end

  -- Grab data about last viewed build
  print(saveData.lastOpened)
  local build = saveData.builds[saveData.lastOpened]
  local charString = build.nodes

  return Graph.parse(charString)
end

function Graph.parse(encoded)
  local b64 = string.gsub(string.gsub(encoded, '_', '/'), '-', '+')
  local decoded = from_base64(b64)

  local class      = string.byte(decoded:sub(5, 5)) + 1
  local ascendancy = string.byte(decoded:sub(6, 6))

  local nids = {}
  local i = 8
  while i < string.len(decoded) do
    local s1 = string.byte(decoded:sub(i, i))
    local s2 = string.byte(decoded:sub(i+1, i+1))
    local nid = decodeNID(s1, s2)
    nids[#nids+1] = nid
    i = i + 2
  end

  return class, ascendancy, nids
end

function Graph.update(build)
  local data = {
    version = VERSION,
    lastOpened = build.name,
    builds = {
      [build.name] = {
        name = build.name,
        nodes = build.nodes,
      }
    }
  }
  love.filesystem.write('builds.lua', ser(data))
  return data
end

function Graph.export(saveData, name, class, ascendancy, nodes)
  local charString = getCharacterString(class-1, ascendancy)

  for nid,node in pairs(nodes) do
    if node.active and #node.startPositionClasses == 0 and not node.isAscendancyStart then
      charString = charString..encodeNID(nid)
    end
  end

  local encoded = string.gsub(string.gsub(to_base64(charString), '/', '_'), '+', '-')

  -- Update necessary information
  saveData.version = VERSION
  saveData.lastOpened = name
  if saveData.builds == nil then saveData.builds = {} end
  saveData.builds[name] = {
    name = name,
    nodes = encoded
  }

  -- Write changes to file
  love.filesystem.write('builds.lua', ser(saveData))

  -- Return build code
  return saveData
end

function getCharacterString(class, ascendancy)
  local characterString = '0004'..class..ascendancy..'0'
  local chars = ''

  for i=1,string.len(characterString) do
    chars = chars..string.char(characterString:sub(i, i))
  end

  return chars
end

function encodeNID(nid)
  local bytes = getBytes(nid)
  local b1, b2 = string.char(bytes[3]), string.char(bytes[4])
  return b1..b2
end

function decodeNID(b1, b2)
  return b1*256 + b2
end

function getBytes(n)
  local bytes = {}
  local i = 4
  while i > 0 do
    bytes[i] = bit.band(n, 255)
    n = bit.rshift(n, 8)
    i = i - 1
  end
  return bytes
end

function searchNearest(currentNodes, level, tiers, visited)
  local tier = {}
  -- print(level)

  -- Loop through currentNodes, adding neighbors to tier if not visited
  for _,i in ipairs(currentNodes) do
    for _,j in ipairs(nodes[i].neighbors) do
      local node = nodes[j]
      -- if not visited[j] and not node:isStart() and not node:isMastery() then
      if not visited[j] and (node.id == startnid or not node:isStart()) then
        if nodes[j].active then
          found = j
          return j, tiers, visited
        else
          if not node:isPathOf() or node.active then
            visited[j] = true
            tier[#tier+1] = j
          end
        end
      end
    end
  end

  tiers[level] = tier
  return searchNearest(tier, level+1, tiers, visited)
end

function getRouteFromTiers(found, tiers, tid)
  local current = nodes[found]
  local route = {[tid]=true}

  for i=#tiers,1,-1 do
    local n = nil
    for _,nid in ipairs(tiers[i]) do
      if n == nil then
        if table.icontains(current.neighbors, nid) then
          -- print(nodes[nid].name, nid, nodes[nid].type)
          n = nid
        end
      end
    end
    if n == nil then
      print('Something went wrong...')
      return route
    else
      route[n] = true
      current = nodes[n]
    end
  end
  return route
end
