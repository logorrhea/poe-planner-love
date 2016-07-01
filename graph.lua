local bit    = require 'bit'
local basexx = require 'vendor.basexx.basexx'
local ser    = require 'vendor.Ser.ser'
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
  return route
end

-- Cheaty mc-cheat algorithm: find the node graphically nearest
-- to the current one and move to it. Does some correction to prevent
-- failure if we reach a dead end. Not always the actual shortest route.
function Graph.planRoute(tid)

  -- Find nearest leaf node
  local target = nodes[tid]
  local min, mid = nil, nil
  for nid, node in pairs(nodes) do
    if node.active then
      local hasInactiveNeighbors = false
      for _, nnid in ipairs(node.neighbors) do
        if not nodes[nnid].active then
          -- Node is a leaf, check distance from target
          local dist = Node.distance(nid, tid)
          if min == nil or dist < min then
            min, mid = dist, nid
          end
        end
      end
    end
  end

  -- Make sure we found something I guess?
  if mid == nil then
    return
  end

  -- From start node, travel to neighbor nearest target
  -- until we have reached the target
  local node = nodes[mid]
  if node == nil then
    print('node is nil?', mid)
  end
  local start = mid -- save start node id

  local trail = {}
  local ignore = {}

  -- Try to keep ourselves from getting stuck
  local lastBranch = nil
  local branchTaken = nil

  while node.id ~= tid do
    min, mid = nil, nil
    for _, oid in ipairs(node.neighbors) do
      if oid ~= start and not table.icontains(trail, oid) and not ignore[oid] and not table.icontains(startNodes, oid) then
        local dist = Node.distance(oid, tid)
        if min == nil or dist < min then
          min, mid = dist, oid
        end
      end
    end

    -- If we are stuck, ignore current id and back up to previous
    -- trail position
    if mid == nil then
      ignore[node.id] = true
      if #trail == 1 then
        trail = {}
        mid = start
      else
        mid = trail[#trail-1]
        trail[#trail] = nil
      end
    else
      trail[#trail+1] = mid
    end

    if mid == nil then
      return {}
    end
    node = nodes[mid]
  end

  -- print('Ignoring:')
  -- for _, id in ipairs(ignore) do
  --   print('', id)
  -- end

  -- print('Trail:')
  -- for _, id in ipairs(trail) do
  --   print('', id)
  -- end

  -- Convert trail to truth table and return
  local ttrail = {}
  for _, id in ipairs(trail) do
    ttrail[id] = true
  end

  return ttrail
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

function Graph.import(charString)
  local b64 = string.gsub(string.gsub(charString, '_', '/'), '-', '+')
  local decoded = from_base64(b64)

  local class      = string.byte(decoded:sub(5, 5)) + 1
  local ascendancy = string.byte(decoded:sub(6, 6)) + 1

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

function Graph.export(class, ascendancy, nodes)
  local charString = getCharacterString(class-1, ascendancy-1)

  for nid,node in pairs(nodes) do
    if node.active and #node.startPositionClasses == 0 and not node.isAscendancyStart then
      charString = charString..encodeNID(nid)
    end
  end

  local encoded = string.gsub(string.gsub(to_base64(charString), '/', '_'), '+', '-')

  local character = {name = 'test', nodes = encoded}
  love.filesystem.write('builds.lua', ser(character))
  return encoded
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

function searchNearest(startNodes, level, tiers, visited)
  local tier = {}

  -- Loop through startNodes, adding neighbors to tier if not visited
  for _,i in ipairs(startNodes) do
    for _,j in ipairs(nodes[i].neighbors) do
      if not visited[j] then
        if nodes[j].active then
          found = j
          return j, tiers, visited
        else
          visited[j] = true
          tier[#tier+1] = j
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

-- function getHex(byte)
--   local hexChars = {[10]='A',[11]='B',[12]='C',[13]='D',[14]='E',[15]='F'}
--   local a, b = math.floor(byte/16), byte % 16
--   if a > 9 then
--     a = hexChars[a]
--   end
--   return a..b
-- end
