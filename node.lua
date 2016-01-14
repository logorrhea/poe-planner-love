Node = {}
Node.__index = Node

-- Define node types so we can use switch
-- statements rather that if/else's
Node.NT_COMMON   = 1
Node.NT_NOTABLE  = 2
Node.NT_MASTERY  = 3
Node.NT_KEYSTONE = 4
Node.NT_START    = 5
Node.NT_JEWEL    = 6

-- Some contants for drawing
Node.SkillsPerOrbit = {1, 6, 12, 12, 12}
Node.OrbitRadii = {0, 82, 162, 335, 493}
Node.Radii = {51, 70, 107, 109, 200, 51}

function Node.arc(node)
  return 2 * math.pi * node.orbitIndex / Node.SkillsPerOrbit[node.orbit]
end

function Node.nodePosition(node)
  local x = 0
  local y = 0

  if node.group ~= nil then
    local r = Node.OrbitRadii[node.orbit]
    local a = Node.arc(node)

    x = node.group.position.x - (r * math.sin(-a))
    y = node.group.position.y - (r * math.cos(-a))
  end

  return {x = x, y = y}
end

-- Create Node from json information, translating
-- some of the parameters to more human-readable names
function Node.create(data, group)
  local node = {group = group}
  setmetatable(node, Node)

  -- Set non-computed attributes
  node.id         = tonumber(data.id)
  node.orbit      = data.o + 1 -- lua arrays are not 0-indexed
  node.orbitIndex = data.oidx
  node.icon       = data.icon
  node.out        = data.out
  node.name       = data.dn
  node.startPositionClasses = data.spc

  -- Set node type
  if #node.startPositionClasses ~= 0 then
    node.type = Node.NT_START
  elseif node.m then
    node.type = Node.NT_MASTERY
  elseif node["not"] then
    node.type = Node.NT_NOTABLE
  elseif node.ks then
    node.type = Node.NT_KEYSTONE
  elseif node.dn == 'Jewel Socket' then
    node.type = Node.NT_JEWEL
  else
    node.type = Node.NT_COMMON
  end

  -- Compute position now, rather than on-the-fly later
  -- since the nodes aren't moving anywhere
  node.position = Node.nodePosition(node)

  return node
end

-- Renders the node (love2d-style)
function Node:draw()
  love.graphics.setColor(255, 255, 255)
  love.graphics.circle('fill', self.position.x, self.position.y, Node.Radii[self.type], 20)
end

return Node
