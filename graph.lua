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

  print('Searching....')
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
        print('back to start')
        trail = {}
        mid = start
      else
        print('back up')
        mid = trail[#trail-1]
        trail[#trail] = nil
      end
    else
      trail[#trail+1] = mid
    end

    print(mid)
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

