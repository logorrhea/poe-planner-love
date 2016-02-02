scaleFix = 2.5

local json = require('vendor.dkjson')
-- local class = require('vendor.middleclass.middleclass')
local Layout = require('vendor.luigi.luigi.layout')

require 'node'
require 'group'
require 'colors'


camera = {
  x         = 0,
  y         = 0,
  scale     = 0.75,
  maxScale  = 1.0,
  minScale  = 0.1,
  scaleStep = 0.05
}

maxActive = 123
activeClass = 1
clickCoords = {x = 0, y = 0}
visibleNodes = {}
startNodes = {}
orig_r, orig_g, orig_b, orig_a = love.graphics.getColor()

-- Load GUI layout(s)
local elements = require('ui.layout')
local layout = Layout(elements)

local dialog = Layout {
  type       = 'panel',
  text       = 'Node information dialog box\nShould have a line break in it, but who knows?',
  width      = 350,
  height     = 150,
  wrap       = true,
  background = {200, 200, 200, 240},
  outline    = {255, 255, 255, 255},
}

-- Adjust UI theme
local dark = require('vendor.luigi.luigi.theme.dark')
layout:setTheme(dark)

local lastClicked = nil

function love.load()

  -- Read data file
  -- file, err = love.filesystem.newFile('data/json/skillTree.json')
  file, err = love.filesystem.newFile('dat.json')
  file:open('r')
  dataString = file:read()
  file:close()

  -- Parse json data into table
  Tree, err = json.decode(dataString)

  -- Cache node count
  local nodeCount = #Tree.nodes

  -- Generate images
  images = {}
  batches = {}

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

      local image = love.graphics.newImage('assets/'..fileName)
      if tableContainsValue(Node.InactiveSkillFrames, name) then
        batches[name] = love.graphics.newSpriteBatch(image, nodeCount)
      elseif tableContainsValue(Node.ActiveSkillFrames, name) then
        batches[name] = love.graphics.newSpriteBatch(image, maxActive)
      elseif name == 'PSGroupBackground3' then
        batches[name] = love.graphics.newSpriteBatch(image, (#Node.classframes)*2)
      elseif name == 'PSStartNodeBackgroundInactive' then
        batches[name] = love.graphics.newSpriteBatch(image, #Node.classframes)
      else
        batches[name] = love.graphics.newSpriteBatch(image, 10)
      end
    end

  end

  -- Get connection images
  images.straight_connector = {
    active       = love.graphics.newImage('assets/LineConnectorActive.png'),
    intermediate = love.graphics.newImage('assets/LineConnectorIntermediate.png'),
    inactive     = love.graphics.newImage('assets/LineConnectorNormal.png')
  }

  spriteQuads = {}
  for name, sizes in pairs(Tree.skillSprites) do
    local spriteInfo = sizes[#sizes]
    local image = love.graphics.newImage('assets/'..spriteInfo.filename)
    local slots = string.match(name, 'Active') ~= nil and maxActive or nodeCount
    batches[name] = love.graphics.newSpriteBatch(image, slots)
    spriteQuads[name] = {}
    for title, coords in pairs(spriteInfo.coords) do
      spriteQuads[name][title] = love.graphics.newQuad(coords.x, coords.y, coords.w, coords.h, image:getDimensions())
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
    node.activeSheet = activeName
    node.inactiveSheet = inactiveName
    node:setQuad(spriteQuads[activeName][node.icon])

    -- Add to startNode table if it is one
    if node.type == Node.NT_START then
      startNodes[#startNodes+1] = node.id
    end

    nodes[node.id] = node
  end

  -- Run through nodes a second time, so we can make links
  -- go both directions
  for nid, node in pairs(nodes) do
    for _, lnid in ipairs(node.out) do
      if lnid ~= nid and nodes[lnid].neighbors[nid] == nil then
        table.insert(nodes[lnid].neighbors, nid)
      end
    end
  end

  -- Use these for culling later
  winWidth, winHeight = love.graphics.getDimensions()
  scaledWidth, scaledHeight = winWidth/camera.scale, winHeight/camera.scale

  -- Set better starting position
  -- @TODO: Set this to look at a character start node
  camera.x = -winWidth/2
  camera.y = -winHeight/2

  -- Create SpriteBatch for background image
  local bgImage = love.graphics.newImage('assets/Background1.png')
  local w, h = bgImage:getDimensions()
  local tilesX, tilesY = math.ceil(winWidth/w), math.ceil(winHeight/h)
  background = love.graphics.newSpriteBatch(bgImage, (tilesX+1)*(tilesY+1), "static")
  for tx = 0, tilesX do
    for ty=0, tilesY do
      background:add(w*tx, h*ty)
    end
  end

  -- Fill up sprite batches
  refillBatches()

  -- Show GUI
  layout:show()
  dialog:hide()
end

function love.update(dt)
  -- countLinesDrawn = 0
end

function love.draw()

  love.graphics.clear(255, 255, 255, 255)
  love.graphics.setColor(255, 255, 255, 230)

  -- Draw background image separate from transformations
  love.graphics.draw(background)
  clearColor()

  -- Store the translation info, for profit
  -- local tx, ty = -camera.x/camera.scale, -camera.y/camera.scale
  local cx, cy = winWidth/(2*camera.scale), winHeight/(2*camera.scale)
  love.graphics.push()
  love.graphics.scale(camera.scale)
  love.graphics.translate(cx, cy)
  love.graphics.translate(-camera.x, -camera.y)

  -- Draw connections first, so they are on the bottom
  love.graphics.setColor(inactiveConnector)
  love.graphics.setLineWidth(1/camera.scale)
  for nid, node in pairs(visibleNodes) do
    node:drawConnections()
  end
  love.graphics.setLineWidth(1)
  clearColor()

  -- Draw the start node decorations first, they should be in the very back
  love.graphics.draw(batches['PSGroupBackground3'])
  love.graphics.draw(batches['PSStartNodeBackgroundInactive'])

  -- Draw skill icons next
  for _, name in pairs(Node.ActiveSkillsheets) do
    love.graphics.draw(batches[name])
  end
  for _, name in pairs(Node.InactiveSkillsheets) do
    love.graphics.draw(batches[name])
  end

  -- Draw frames
  for _, name in pairs(Node.ActiveSkillFrames) do
    love.graphics.draw(batches[name])
  end
  for _, name in pairs(Node.InactiveSkillFrames) do
    love.graphics.draw(batches[name])
  end

  -- Draw active class frames
  for _, name in pairs(Node.classframes) do
    love.graphics.draw(batches[name])
  end

  love.graphics.pop()

  -- print FPS counter in top-left
  local fps, timePerFrame = love.timer.getFPS(), 1000 * love.timer.getAverageDelta()
  love.graphics.setColor(255, 255, 255, 255)
  love.graphics.print(string.format("Current FPS: %.2f | Average frame time: %.3f ms", fps, timePerFrame), 10, 10)
  clearColor()

  -- Print GUI
end

function love.mousepressed(x, y, button, isTouch)
  dialog:hide()
  clickCoords.x, clickCoords.y = x, y
end

function love.mousereleased(x, y, button, isTouch)
  local dx = x - clickCoords.x
  local dy = y - clickCoords.y

  if math.abs(dx) <= 3 and math.abs(dy) <= 3 then
    checkIfNodeClicked(x, y, button, isTouch)
  end

end

function love.mousemoved(x, y, dx, dy)
  if love.mouse.isDown(1) then
    camera.x = camera.x - (dx/camera.scale)
    camera.y = camera.y - (dy/camera.scale)
    refillBatches()
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
    refillBatches()
  elseif key == 'down' then
    camera.scale = camera.scale - camera.scaleStep
    if camera.scale < camera.minScale then
      camera.scale = camera.minScale
    end
    scaledHeight = winHeight/camera.scale
    scaledWidth = winWidth/camera.scale
    refillBatches()
  end
end

function checkIfNodeClicked(x, y, button, isTouch)
  for nid, node in pairs(visibleNodes) do
    local dx = (node.position.x*camera.scale) - camera.x - x
    local dy = (node.position.y*camera.scale) - camera.y - y
    local r = Node.Radii[node.type] * camera.scale
    if dx * dx + dy * dy <= r * r then

      -- Debug
      print(node.id)

      if node.id == lastClicked then
        -- On second click, toggle all nodes in highlighted trail
        if (node.active or node:hasActiveNeighbors()) and node.type ~= Node.NT_START then
          node.active = not node.active
          refillBatches()
        end
      else
        -- On first click, we should give some preview information:
        --  Dialog box diplaying information about the clicked node
        --  Preview a route from closest active node
        print('showing node dialog')
        showNodeDialog(nid)
      end
      return
    end
  end
end

function clearColor()
  love.graphics.setColor(orig_r, orig_g, orig_b, orig_a)
end

function refillBatches()

  -- Clear out batches
  for name, _ in pairs(batches) do
    batches[name]:clear()
  end

  -- Re-calculate visible nodes
  local tx, ty = winWidth/(2*camera.scale)-camera.x, winHeight/(2*camera.scale)-camera.y
  visibleNodes = {}
  for nid, node in pairs(nodes) do
    if node:isVisible(tx, ty) then
      visibleNodes[node.id] = node
    end
  end

  -- Re-fill them batches
  for nid, node in pairs(visibleNodes) do
    node:draw(tx, ty)
  end
end

function tableContainsValue(t, v)
  for _, n in pairs(t) do
    if n == v then
      return true
    end
  end
  return false
end

function showNodeDialog(nid)
  dialog:show()
  lastClicked = nid
end
