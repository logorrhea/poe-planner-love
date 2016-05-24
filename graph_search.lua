require 'node'

function searchNearest(startNodes, level)
  local tier = {}

  -- Loop through startNodes, adding neighbors to tier if not visited
  for _,i in ipairs(startNodes) do
    for _,j in ipairs(nodes[i].neighbors) do
      if not visited[j] then
        if j == 6580 then
          print('found 6580')
          print('6580 active?', nodes[j].active)
        end
        if nodes[j].active then
          found = j
          return
        else
          visited[j] = true
          tier[#tier+1] = j
        end
      end
    end
  end

  tiers[level] = tier
  searchNearest(tier, level+1)
end







-- Get thread channel to send/receive messages
local targetChannel = love.thread.getChannel('targetChannel')
local routeChannel = love.thread.getChannel('routeChannel')

-- Get requested node id from channel
local tid = targetChannel:pop()
if tid == nil then
  return
end

-- Load node info from files =\
tree = require 'processed-tree-data'
nodes = tree.nodes
local start = nodes[tid]

-- If we have a bogus nid, quit
if start == nil then
  return
end


routes = {}

-- Track nodes visited so we don't loop
visited = {}
visited[start.id] = true

-- Kick off search from tier 1
tiers = {}
found = false
searchNearest({[1] = start.id}, 1)

print('done searching, nearest active is '..found)



















--[[




if #start.neighbors == 1 then
  routes
end


local route = {target.id}
local visited = {}
visited[target.id] = true
local current = target

local next = 1
while current.active == false and next ~= nil do
  next = nil
  for _, nid in ipairs(current.neighbors) do
    if (next == nil and visited[nid] == nil) or nodes[nid].active then
      next = nid
    end
  end

  if next == nil then
    print('next is nil')
  else
    current = nodes[next]
    visited[current.id] = true
    route[#route+1] = current.id
    print(current.id, current.name)
  end
end

-- Push new message
if next == nil then
  print('no route found')
else
  routeChannel:push(route)
  print('done')
end


]]
