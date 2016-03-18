local basexx = require 'vendor.basexx.basexx'
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

-- BFS starting at the nearest leaf node,
-- picks candidate with shortest path to selected node
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

  -- From start node, travel to neighbor nearest target
  -- until we have reached the target
  local node = nodes[mid]
  local start = mid -- save start node id

  local trail = {}
  local ignore = {}

  -- Try to keep ourselves from getting stuck
  local lastBranch = nil
  local branchTaken = nil

  -- print('Searching....')
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
        -- print('back to start')
        trail = {}
        mid = start
      else
        -- print('back up')
        mid = trail[#trail-1]
        trail[#trail] = nil
      end
    else
      trail[#trail+1] = mid
    end

    -- print(mid)
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

function Graph.export(class, ascendancy, nodes)
  local charString = getCharacterString(class-1, ascendancy)

  for nid,node in pairs(nodes) do
    if node.active and #node.startPositionClasses == 0 then
      charString = charString..encodeNID(nid)
    end
  end

  local encoded = string.gsub(string.gsub(to_base64(charString), '/', '_'), '+', '-')
  print(encoded)
end

function getCharacterString(class, ascendancy)
  local characterString = '0004'..class..ascendancy..'0';
  local chars = ''

  for i=1,string.len(characterString) do
    chars = chars..string.char(characterString:sub(i, i))
  end

  return chars
end

function encodeNID(nid)
  local bytes = getBytes(nid)
  return string.char(bytes[3])..string.char(bytes[4])
end

function getBytes(n)
  -- 256^3, 256^2, 256^1
  local exp = {16777216, 65536, 256}
  local bytes = {}
  for i, m in ipairs(exp) do
    bytes[i] = select(1, math.modf(n/m))
    n = math.fmod(n, m)
  end
  bytes[#bytes+1] = n
  return bytes
end

-- function getHex(byte)
--   local hexChars = {[10]='A',[11]='B',[12]='C',[13]='D',[14]='E',[15]='F'}
--   local a, b = math.floor(byte/16), byte % 16
--   if a > 9 then
--     a = hexChars[a]
--   end
--   return a..b
-- end
