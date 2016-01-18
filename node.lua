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

    x = node.group.position.x - r * math.sin(-a)
    y = node.group.position.y - r * math.cos(-a)
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
  node.gid        = tonumber(data.g)
  node.orbit      = data.o + 1 -- lua arrays are not 0-indexed
  node.orbitIndex = data.oidx
  node.icon       = data.icon
  node.out        = data.out
  node.name       = data.dn
  node.startPositionClasses = data.spc

  -- Set nodes to active for now, until we get further along. it's too hard
  -- to see everything otherwise
  node.active = true

  -- Set node type
  if #node.startPositionClasses ~= 0 then
    node.type = Node.NT_START
  elseif data.m then
    node.type = Node.NT_MASTERY
  elseif data["not"] then
    node.type = Node.NT_NOTABLE
  elseif data.ks then
    node.type = Node.NT_KEYSTONE
  elseif data.dn == 'Jewel Socket' then
    node.type = Node.NT_JEWEL
  else
    node.type = Node.NT_COMMON
  end

  -- Set radius based on node type
  node.radius = Node.Radii[node.type]

  -- Compute position now, rather than on-the-fly later
  -- since the nodes aren't moving anywhere
  node.position = Node.nodePosition(node)

  return node
end

-- Renders the node (love2d-style)
function Node:draw(tx, ty)
  if self.position.x + tx <= scaledWidth and self.position.x + tx >= 0 and self.position.y + ty >= 0 and self.position.y + ty <= scaledHeight then

    -- @NOTE: Potential optimization point -- move this positional adjustment into
    -- initialization code.
    local r,g,b,a = love.graphics.getColor()
    love.graphics.setColor(0, 0, 0, 255)
    self:drawConnections()
    love.graphics.setColor(r,g,b,a)
    local sheet = self.active and self.activeSheet or self.inactiveSheet
    local _,_,w,h = self.imageQuad:getViewport()
    love.graphics.draw(sheet, self.imageQuad, self.position.x - w/2, self.position.y - h/2)
  end
end

function Node:drawConnections()
    for _, nid in pairs(self.out) do
      local other = nodes[nid]
      if (self.group.id ~= other.group.id) or (self.orbit ~= other.orbit) then
        self:drawConnection(other)
      else
        self:drawArcedConnection(other)
      end
    end
end

function Node:drawConnection(other)
  -- local dx, dy = self.position.x - other.position.x, self.position.y - other.position.y
  -- local a = math.atan(dy/dx) * 180 / math.pi
  -- love.graphics.draw(images.straight_connector.active, self.position.x, self.position.y, a)
  love.graphics.line(self.position.x, self.position.y, other.position.x, other.position.y)
end

function Node:drawArcedConnection(other)
  local startAngle = Node.arc(self)
  local endAngle = Node.arc(other)

  if startAngle > endAngle then
    startAngle, endAngle = endAngle, startAngle
  end
  local delta = endAngle - startAngle

  if delta > math.pi then
    local c = 2*math.pi - delta
    endAngle = startAngle
    startAngle = endAngle + c
    delta = c
  end

  local center = self.group.position
  local radius = Node.OrbitRadii[self.orbit]
  local steps = math.ceil(30*(delta/(math.pi*2)))
  local stepSize = delta/steps

  local points = {}
  local radians = 0
  endAngle = endAngle - math.pi/2
  for i=0,steps do
    radians = endAngle - stepSize*i
    table.insert(points, radius*math.cos(radians)+center.x)
    table.insert(points, radius*math.sin(radians)+center.y)
  end

  if steps < 0 or #points < 0 then
    return
  end

  -- print("steps", steps)
  -- print("#points", #points)
  love.graphics.line(points)
end

return Node
