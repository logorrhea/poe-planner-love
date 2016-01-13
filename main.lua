local json = require('vendor/dkjson')
require 'node'
require 'group'

function love.load()

  -- Read data file
  -- file, err = love.filesystem.newFile('data/json/skillTree.json')
  file, err = love.filesystem.newFile('dat.json')
  file:open('r')
  dataString = file:read()
  file:close()

  -- Parse json data into table
  Tree, err = json.decode(dataString)

  -- Create grups
  groups = {}
  for gid, group in pairs(Tree.groups) do
    local id = tonumber(gid)
    groups[id] = Group.create(id, group)
  end

  -- Create nodes
  nodes = {}
  for _, node in pairs(Tree.nodes) do
    local node = Node.create(node, groups[node.g])
    nodes[node.id] = node
  end

end

function love.update(dt)
end

function love.draw()
  love.graphics.push()
  love.graphics.scale(0.1, 0.1)
  for nid, node in pairs(nodes) do
    node:draw()
  end
  love.graphics.pop()

  -- print FPS counter in top-left
  love.graphics.print("Current FPS: "..tostring(love.timer.getFPS( )), 10, 10)
end
