local json = require('vendor/dkjson')

require 'node'
require 'group'

camera = {
  x         = 0,
  y         = 0,
  scale     = 0.25,
  maxScale  = 1.0,
  minScale  = 0.1,
  scaleStep = 0.05
}

clickCoords = {x = 0, y = 0}
visibleNodes = {}
orig_r, orig_g, orig_b, orig_a = love.graphics.getColor()

function love.load()

  -- Read data file
  -- file, err = love.filesystem.newFile('data/json/skillTree.json')
  file, err = love.filesystem.newFile('dat.json')
  file:open('r')
  dataString = file:read()
  file:close()

  -- Parse json data into table
  Tree, err = json.decode(dataString)

  -- Generate images
  -- @TODO: Store all this shit as SpriteBatches
  images = {}
  for name, sizes in pairs(Tree.assets) do
    local filePath = nil
    local largest = 0
    for size, sizeFilePath in pairs(sizes) do
      if tonumber(size) > largest then
        largest = tonumber(size)
        filePath = sizeFilePath
      end
    end

    if filePath ~= nil then
      local fileName = nil
      for match in filePath:gmatch("[^/%.]+%.[^/%.]+") do
        fileName = match
      end
      fileName = fileName:gsub(".gif", ".png") -- this needs a better solution, probably
      images[name] = love.graphics.newImage('assets/'..fileName)
    end

  end

  -- Get connection images
  images.straight_connector = {
    active = love.graphics.newImage('assets/LineConnectorActive.png'),
    intermediate = love.graphics.newImage('assets/LineConnectorIntermediate.png'),
    inactive = love.graphics.newImage('assets/LineConnectorNormal.png')
  }

  spriteQuads = {}
  for name, sizes in pairs(Tree.skillSprites) do
    local spriteInfo = sizes[#sizes]
    local sheet = love.graphics.newImage('assets/'..spriteInfo.filename)
    images[name] = sheet
    spriteQuads[name] = {}
    for title, coords in pairs(spriteInfo.coords) do
      spriteQuads[name][title] = love.graphics.newQuad(coords.x, coords.y, coords.w, coords.h, sheet:getDimensions())
    end
  end

  -- Create groups
  groups = {}
  for gid, group in pairs(Tree.groups) do
    local id = tonumber(gid)
    groups[id] = Group.create(id, group)
  end

  -- Create nodes
  nodes = {}
  for _, n in pairs(Tree.nodes) do
    local node = Node.create(n, groups[n.g])
    if groups[n.g].orbit == nil and node.orbit ~= nil then
      groups[n.g].orbit = node.orbit
    end

    -- Determine sprite sheet to use
    local activeName = Node.ActiveSkillsheets[node.type]
    local inactiveName = Node.InactiveSkillsheets[node.type]
    node.activeSheet = images[activeName]
    node.inactiveSheet = images[inactiveName]
    node:setQuad(spriteQuads[activeName][node.icon])

    nodes[node.id] = node
  end

  -- Use these for culling later
  winWidth, winHeight = love.graphics.getDimensions()
  scaledWidth, scaledHeight = winWidth/camera.scale, winHeight/camera.scale

  -- Set better starting position
  -- @TODO: Set this to look at a character start node
  camera.x = -winWidth/2
  camera.y = -winHeight/2
end

function love.update(dt)
end

function love.draw()
  love.graphics.clear(255, 255, 255, 255)
  love.graphics.push()
  love.graphics.scale(camera.scale, camera.scale)

  -- Store the translation info, for profit
  local tx, ty = -camera.x/camera.scale, -camera.y/camera.scale
  love.graphics.translate(tx, ty)

  -- @TODO: Once we move everything over to SpriteBatches, we can probably
  -- do these comparisons at SpriteBatch-creation-time. Simply leave out all
  -- the ones that don't need to drawn

  -- Draw connections first, so they are on the bottom
  love.graphics.setColor(0, 0, 0, 255)
  love.graphics.setLineWidth(1/camera.scale)
  for nid, node in pairs(nodes) do
    node:drawConnections()
  end
  love.graphics.setLineWidth(1)
  clearColor()

  -- Draw each node
  for nid, node in pairs(nodes) do
    node:draw(tx, ty)
  end

  love.graphics.pop()

  -- print FPS counter in top-left
  love.graphics.setColor(0, 0, 0, 255)
  love.graphics.print(string.format("Current FPS: %.2f | Average frame time: %.3f ms", love.timer.getFPS(), 1000 * love.timer.getAverageDelta()), 10, 10)
  clearColor()
end

function love.mousepressed(x, y, button, isTouch)
  clickCoords.x, clickCoords.y = x, y
end

function love.mousereleased(x, y, button, isTouch)
  local dx = x - clickCoords.x
  local dy = y - clickCoords.y

  if math.abs(dx) <= 3 and math.abs(dy) <= 3 then
    checkIfNodeClicked(x, y, button, isTouch)
  else
    visibleNodes = {}
  end
end

function love.mousemoved(x, y, dx, dy)
  if love.mouse.isDown(1) then
    camera.x = camera.x - dx
    camera.y = camera.y - dy
  end
end

function love.keypressed(key, scancode, isRepeat)
  if key == 'up' then
    camera.scale = camera.scale + camera.scaleStep
    if camera.scale > camera.maxScale then
      camera.scale = camera.maxScale
    end
    scaledHeight = winHeight/camera.scale
    scaledWidth = winWidth/camera.scale
  elseif key == 'down' then
    camera.scale = camera.scale - camera.scaleStep
    if camera.scale < camera.minScale then
      camera.scale = camera.minScale
    end
    scaledHeight = winHeight/camera.scale
    scaledWidth = winWidth/camera.scale
  end
end

function checkIfNodeClicked(x, y, button, isTouch)
  for nid, node in pairs(visibleNodes) do
    local dx = (node.position.x*camera.scale) - camera.x - x
    local dy = (node.position.y*camera.scale) - camera.y - y
    local r = Node.Radii[node.type] * camera.scale
    if dx * dx + dy * dy <= r * r then
      print(node.id)
      node.active = not node.active
      return
    end
  end
end

function clearColor()
  love.graphics.setColor(orig_r, orig_g, orig_b, orig_a)
end
