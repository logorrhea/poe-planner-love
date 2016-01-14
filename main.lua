local json = require('vendor/dkjson')
require 'node'
require 'group'

local camera = {
  x     = 0,
  y     = 0,
  scale = 0.1
}

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
  love.graphics.scale(camera.scale, camera.scale)
  love.graphics.translate(-camera.x/camera.scale, -camera.y/camera.scale)
  for nid, node in pairs(nodes) do
    node:draw()
  end
  love.graphics.pop()

  -- print FPS counter in top-left
  love.graphics.print("Current FPS: "..tostring(love.timer.getFPS( )), 10, 10)
end

function love.mousepressed(x, y, button, isTouch)
end

function love.mousereleased(x, y, button, isTouch)
end

function love.mousemoved(x, y, dx, dy)
  if love.mouse.isDown(1) then
    camera.x = camera.x - dx
    camera.y = camera.y - dy
  end
end
