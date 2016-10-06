local scaleFix = 2.5

-- Local includes
local OS = love.system.getOS()
local json   = require 'vendor.dkjson'


-- Global includes
Timer  = require 'vendor.hump.timer'
lume   = require 'vendor.lume.lume'
vec = require 'vendor.hump.vector'



require 'downloader'
require 'node'
require 'group'
require 'colors'
require 'graph'

DEBUG = false
pinches = {nil, nil}

camera = require 'camera'

-- Store window width and height. Set highdpi
winWidth, winHeight, flags = love.window.getMode()
flags.highdpi = true
love.window.setMode(winWidth, winHeight, flags)
winWidth = love.window.toPixels(winWidth)
winHeight = love.window.toPixels(winHeight)
scaledWidth, scaledHeight = winWidth/camera.scale, winHeight/camera.scale

maxActive = 123
activeNodes = 0
activeClass = 1
ascendancyClass = 1
clickCoords = {x = 0, y = 0}
visibleNodes = {}
visibleGroups = {}
startNodes = {}
addTrail = {}
removeTrail = {}
ascendancyNodes = {}
orig_r, orig_g, orig_b, orig_a = love.graphics.getColor()

ascendancyTreeOrigins = {}

-- Load GUI layout(s)
local guiButtons = {}

-- Keep track of character stats
local character = {
  str       = 0,
  int       = 0,
  dex       = 0,
  stats     = {},
  keystones = {},
  keystoneCount = 0,
}
characterURL = ''


-- le Fonts
headerFont = love.graphics.newFont('fonts/fontin-bold-webfont.ttf', 20*love.window.getPixelScale())
headerFont:setFilter('nearest', 'nearest')
font = love.graphics.newFont('fonts/fontin-bold-webfont.ttf', 14*love.window.getPixelScale())
font:setFilter('nearest', 'nearest')

-- Stat window images
local statsShowing = false
local statsTransitioning = false
local portrait

-- Dialog Window stuff
local dialogWindowVisible = false
local dialogHeaderText  = love.graphics.newText(headerFont, '')
local dialogContentText = love.graphics.newText(font, '')
local dialogPosition    = {x = 0, y    = 0, w = love.window.toPixels(300), h = love.window.toPixels(150)}
local statPanelLocation = {x = -love.window.toPixels(300), y = 0}
local statTextLocation  = {
  maxY = love.window.toPixels(125),
  minY = love.window.toPixels(125),
  y    = love.window.toPixels(125),
  yadj = function(self, dy)
    self.y = lume.clamp(self.y+dy, self.minY, self.maxY)
  end
}

-- Use to determine whether to plan route/refund or activate nodes
local lastClicked = nil

-- Layers for click handling (lower = higher priority)
local layers = {}

times = {}
function love.load()
  times.start = love.timer.getTime()

  circleRadius = 10

  -- Get tree data. Will download new version if necessary
  -- Tree = Downloader.getLuaTree()
  -- local data = Downloader.processNodes(Tree)
  Tree = require 'passive-skill-tree'
  times.tree = love.timer.getTime()

  -- Read save file
  local savedNodes = {}
  if love.filesystem.exists('builds.lua') then
    local saveDataFunc = love.filesystem.load('builds.lua')
    local saveData = saveDataFunc()
    activeClass, ascendancyClass, savedNodes = Graph.import(saveData.nodes)
    if ascendancyClass == 0 then
      ascendancyClass = 1
    end
  end
  times.save = love.timer.getTime()

  -- Cache node count
  local nodeCount = #Tree.nodes
  local groupCount = 0
  for gid, group in pairs(Tree.groups) do
    groupCount = groupCount + 1
  end
  times.nodeCount = love.timer.getTime()

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

      local fileData = love.filesystem.newFileData('assets/'..fileName)
      local imageData = love.image.newImageData(fileData)
      local image = love.graphics.newImage(imageData)
      if lume.find(Node.InactiveSkillFrames, name) then
        batches[name] = love.graphics.newSpriteBatch(image, nodeCount)
      elseif lume.find(Node.ActiveSkillFrames, name) then
        batches[name] = love.graphics.newSpriteBatch(image, maxActive)
      elseif name == 'PSGroupBackground1' then
        batches[name] = love.graphics.newSpriteBatch(image, groupCount)
      elseif name == 'PSGroupBackground2' then
        batches[name] = love.graphics.newSpriteBatch(image, groupCount)
      elseif name == 'PSGroupBackground3' then
        batches[name] = love.graphics.newSpriteBatch(image, (#Node.Classes + groupCount)*2)
      elseif name == 'PSStartNodeBackgroundInactive' then
        batches[name] = love.graphics.newSpriteBatch(image, #Node.Classes)
      else
        batches[name] = love.graphics.newSpriteBatch(image, 10)
      end
    end

  end
  times.batches = love.timer.getTime()


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
  times.quads = love.timer.getTime()

  -- Create groups
  groups = {}
  for gid, group in pairs(Tree.groups) do
    local id = tonumber(gid)
    local group = Group.create(id, group)
    groups[id] = group
  end

  -- Create nodes
  nodes = {}
  for _, n in ipairs(Tree.nodes) do
    local node = Node.create(n, groups[n.g])
    if groups[n.g].type == nil then
      groups[n.g].type = node.orbit
    end
    if groups[n.g].orbit == nil and node.orbit ~= nil then
      groups[n.g].orbit = node.orbit
    end

    -- Determine sprite sheet to use
    local activeName = Node.ActiveSkillsheets[node.type]
    local inactiveName = Node.InactiveSkillsheets[node.type]
    if activeName and inactiveName then
      node.activeSheet = activeName
      node.inactiveSheet = inactiveName
      node:setQuad(spriteQuads[activeName][node.icon])
    end

    -- Add to startNode table if it is one
    if node.type == Node.NT_START then
      local spc = node:startPositionClass()
      startNodes[spc] = node.id
    end

    nodes[node.id] = node
  end
  times.nodes = love.timer.getTime()

  -- Set better starting position
  startnid = startNodes[activeClass]
  startNode = nodes[startnid]
  camera:setPosition(startNode.position.x, startNode.position.y)

  -- Create ascendancy button and panel
  ascendancyButton = require 'ui.ascendancybutton'
  ascendancyButton:init(Tree, startnid)
  ascendancyPanel = require 'ui.ascendancypanel'
  ascendancyPanel:init(ascendancyButton, batches)

  -- Ascendancy class picker
  ascendancyClassPicker = require 'ui.ascendancyclasspicker'
  ascendancyClassPicker:init()
  times.gui = love.timer.getTime()

  -- Create class picker
  classPicker = require 'ui.classpicker'
  classPicker:init(ascendancyClassPicker)
  -- portrait = classPicker:getPortrait(activeClass)

  -- Create stats panel
  menu = require 'ui.statpanel'
  menu:init()

  -- Create portrait
  portrait = require 'ui.portrait'
  portrait:init(classPicker:getPortrait(activeClass), menu, classPicker)

  -- Create menu toggle
  menuToggle = require 'ui.menutoggle'
  menuToggle:init(menu)

  -- Set up click/touch handler layers
  layers[1] = ascendancyClassPicker
  layers[2] = classPicker
  layers[3] = portrait
  layers[4] = menu
  layers[5] = menuToggle

  -- Activate nodes saved in user data
  for _, nid in ipairs(savedNodes) do
    activateNode(nid)
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
  times.links = love.timer.getTime()

  -- Create SpriteBatch for background image
  tiledBackground()
  times.background = love.timer.getTime()

  -- Fill up sprite batches
  refillBatches()
  times.refill = love.timer.getTime()

  -- Show GUI
  guiButtons.menuToggle = {
    x     = love.window.toPixels(10),
    y     = love.window.toPixels(10),
    sx    = 0.1*love.window.getPixelScale(),
    sy    = 0.1*love.window.getPixelScale(),
    image = love.graphics.newImage('assets/menu.png'),
    name = 'Menu Toggle',
    click = function(t, mx, my)
      local w, h = t.image:getDimensions()
      w, h = w*t.sx, h*t.sy
      local x1, y1 = t.x, t.y
      local x2, y2 = t.x + w, t.y + h
      return mx >= x1 and mx <= x2 and my >= y1 and my <= y2
    end,
    process = function()
      statsShowing = true
      Timer.tween(0.5, statPanelLocation, {x = 0}, 'out-back')
    end,
    trigger = function()
        -- Slide in stats board
        statsShowing = true
        -- Timer.tween(0.5, statPanelLocation, {x = 0}, 'in-out-quad')
        Timer.tween(0.5, statPanelLocation, {x = 0}, 'out-back')
    end,
    isActive = function()
      return statsShowing == false
    end,
  }

  -- print('tree',       1000*(times.tree - times.start))
  -- print('save',       1000*(times.save - times.tree))
  -- print('nodecount',  1000*(times.nodeCount - times.save))
  -- print('batches',    1000*(times.batches - times.nodeCount))
  -- print('quads',      1000*(times.quads - times.batches))
  -- print('nodes',      1000*(times.nodes - times.quads))
  -- print('links',      1000*(times.links - times.nodes))
  -- print('background', 1000*(times.background - times.links))
  -- print('refill',     1000*(times.refill - times.background))
  -- print('gui',        1000*(times.gui - times.refill))
  -- print('total', 1000*(times.gui - times.start))
end

function love.update(dt)
  require('vendor.lovebird').update()
  Timer.update(dt)
end

function love.resize(w, h)
  winWidth, winHeight = w, h
  scaledWidth, scaledHeight = winWidth/camera.scale, winHeight/camera.scale

  -- Regenerate tiled background
  tiledBackground()

  -- Regenerate sprite batches
  refillBatches()

  -- Reset centers on class picker
  ascendancyClassPicker:setCenters()
  classPicker:setCenters()

  print(w, h)
end

function love.draw()

  love.graphics.clear(255, 255, 255, 255)
  love.graphics.setColor(255, 255, 255, 230)

  -- Draw background image separate from transformations
  love.graphics.draw(background)
  clearColor()

  -- Store the translation info, for profit
  local cx, cy = winWidth/(2*camera.scale), winHeight/(2*camera.scale)
  love.graphics.push()
  love.graphics.scale(camera.scale)
  love.graphics.translate(cx, cy)
  love.graphics.translate(-camera.x, -camera.y)

  -- Draw group backgrounds
  love.graphics.draw(batches['PSGroupBackground1'])
  love.graphics.draw(batches['PSGroupBackground2'])
  love.graphics.draw(batches['PSGroupBackground3'])

  -- Draw connections
  love.graphics.setColor(inactiveConnector)
  love.graphics.setLineWidth(3/camera.scale)
  for nid, node in pairs(visibleNodes) do
    node:drawConnections()
  end
  love.graphics.setLineWidth(1)
  clearColor()

  -- Draw the start node decorations first, they should be in the very back
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
  for _, class in pairs(Node.Classes) do
    love.graphics.draw(batches[class.frame])
  end

  -- Ascendancy graph
  if ascendancyButton:isActive() then
    ascendancyPanel:draw()
  end

  -- Ascendancy bubble toggler
  ascendancyButton:draw()

  love.graphics.push()
  local center = {x=0,y=0}
  center.x, center.y = ascendancyPanel:getCenter()
  local ascendancyTreeStart = ascendancyTreeOrigins[Node.getAscendancyClassName()]
  if ascendancyTreeStart then
    love.graphics.translate(center.x-ascendancyTreeStart.position.x, center.y-ascendancyTreeStart.position.y)

    -- Draw ascendancy node connections
    love.graphics.setColor(inactiveConnector)
    love.graphics.setLineWidth(3/camera.scale)
    if ascendancyButton:isActive() then
      for nid, node in pairs(ascendancyNodes) do
        node:drawConnections()
      end
    end
    love.graphics.setLineWidth(1)
    clearColor()

    -- Draw ascendancy nodes
    if ascendancyButton:isActive() then
      for nid,node in pairs(ascendancyNodes) do
        node:immediateDraw()
      end
    end
  end
  love.graphics.pop()

  -- Pop graphics state to draw UI
  love.graphics.pop()

  -- Draw menuToggle.image button in top-left
  if menuToggle:isActive() then
    menuToggle:draw()
  end

  if DEBUG then
    -- print FPS counter in top-left
    local fps, timePerFrame = love.timer.getFPS(), 1000 * love.timer.getAverageDelta()
    love.graphics.setColor(255, 255, 255, 255)
    love.graphics.print(string.format("Current FPS: %.2f | Average frame time: %.3f ms", fps, timePerFrame), winWidth - love.window.toPixels(400), love.window.toPixels(10))

    -- Print character URL below
    love.graphics.print(characterURL, winWidth-love.window.toPixels(400), love.window.toPixels(30))
    clearColor()
  end

  -- Draw UI
  if menu:isActive() then
    menu:draw(character)
    portrait:draw()
  end

  if dialogWindowVisible then
    drawDialogWindow()
  end

  if classPicker:isActive() then
    classPicker:draw()
  end

  if ascendancyClassPicker:isActive() then
    ascendancyClassPicker:draw()
  end
end

  -- function love.touchpressed(id, x, y, dx, dy, pressure)
  --   dialogWindowVisible = false
  --   clickCoords.x, clickCoords.y = x, y
  --   clickCoords.onGUI = isMouseInGUI(x, y)
  --   clickCoords.onStats = isMouseInStatSection()
  -- end

  -- function love.touchreleased(id, x, y, dx, dy, pressure)
  --   if not isTouch then
  --     local dx = x - clickCoords.x
  --     local dy = y - clickCoords.y

  --     if math.abs(dx) <= 3 and math.abs(dy) <= 3 then
  --       if ascendancyClassPicker:isActive() then
  --         local choice = ascendancyClassPicker:click(x, y)
  --         ascendancyClassPicker:toggle()
  --         if choice then
  --           local buttons = {"Cancel", "OK", escapebutton=1, enterbutton=2}
  --           if love.window.showMessageBox('Change Class?', 'Are you sure you want to change class and reset the skill tree?', buttons, 'info', true) == 2 then
  --             changeActiveClass(newClass, choice)
  --           end
  --         else
  --           newClass = nil
  --         end
  --       elseif classPicker:isActive() then
  --         local choice = classPicker:click(x, y)
  --         print('class choice: ', Node.Classes[choice].name)
  --         if choice then
  --           closeStatPanel()
  --           newClass = choice
  --           ascendancyClassPicker:setOptions(choice)
  --           ascendancyClassPicker:activate()
  --         end
  --       else
  --         if not ascendancyButton:click(x, y) then
  --           local guiItemClicked = checkIfGUIItemClicked(x, y, button, isTouch)
  --           if not guiItemClicked and not clickCoords.onGUI then
  --             checkIfNodeClicked(x, y, button, isTouch)
  --           end
  --         end
  --       end
  --     end
  --   end
  --   clickCoords.onGUI = false
  --   clickCoords.onStats = false
  -- end

  function love.touchmoved(id, x, y, dx, dy, pressure)
    dialogWindowVisible = false
    local touches = love.touch.getTouches()
    if #touches == 1 then
      if classPicker:isActive() or ascendancyClassPicker:isActive() then return end
      if not menu:mousemoved(x, y, dx, dy) then
        camera:setPosition(camera.x - (dx/camera.scale), camera.y - (dy/camera.scale))
      end
    elseif #touches == 2 then
      -- @TODO: handle zooming in and out with multitouch
      local ox, oy = nil, nil
      for tid, touch in pairs(touches) do
        if tid ~= id then
          ox, oy = love.touch.getPosition(touch)
        end
      end
      local d1 = dist({x=ox, y=oy}, {x=x, y=y})
      local d2 = dist({x=ox, y=oy}, {x=x+dx, y=y+dy})
      camera:pinch(d2-d1)
    elseif #touches == 5 then
      local buttons = {"Cancel", "OK", escapebutton=1, enterbutton=2}
      if love.window.showMessageBox('Close PoE Planner?', '', buttons, 'info', true) == 2 then
        love.event.quit()
      end
    end
  end


function love.mousepressed(x, y, button, isTouch)
  dialogWindowVisible = false
  clickCoords.x, clickCoords.y = x, y
  menu:mousepressed(x, y)
end

function love.mousereleased(x, y, button, isTouch)
  local clickResult = false
  local i = 1
  local layer
  while clickResult == false and i <= #layers do
    layer = layers[i]
    if layer:isActive() then
      clickResult = layer:click(x, y)
      if clickResult or layer:isExclusive() then return end
    end
    i = i + 1
  end

  -- Try ascendancy tree toggle button
  if ascendancyButton:click(x, y) then return end

  -- Try ascendancy nodes
  if not clickResult then
    for nid, node in pairs(ascendancyNodes) do
      if node:click(x, y) then
        toggleNodes(nid)
        return
      end
    end
  end

  -- Try regular nodes
  if not clickResult and (not ascendancyButton:isActive() or not ascendancyPanel:containsMouse(x, y)) then
    for nid, node in pairs(nodes) do
      if node:click(x, y) then
        toggleNodes(nid)
        return
      end
    end
  end
end

function love.mousemoved(x, y, dx, dy, isTouch)
  if isTouch then return end
  -- Bail if either classpicker is active
  if classPicker:isActive() or ascendancyClassPicker:isActive() then return end

  if love.mouse.isDown(1) then
    -- Check if we are scrolling stat text
    if not menu:mousemoved(x, y, dx, dy) then
      -- Otherwise pan camera
      camera:setPosition(camera.x - (dx/camera.scale), camera.y - (dy/camera.scale))
      refillBatches()
    end
    return
  end

  if not isTouch then
    -- If mouse not down, see if we are hovering over a node
    local mouseInAscendancyPanel = ascendancyButton:isActive() and ascendancyPanel:containsMouse(x, y)
    local mouseInMenu = menu:isActive() and menu:containsMouse(x, y)
    if not mouseInMenu then
      local hovered = nil
      if ascendancyButton:isActive() then
        if ascendancyButton:isActive() then
          hovered = checkIfAscendancyNodeHovered(x, y)
        end
      end
      if hovered == nil and not mouseInAscendancyPanel then
        hovered = checkIfNodeHovered(x, y)
      end
      if hovered == nil then
        lastClicked = nil
        addTrail = {}
        removeTrail = {}
        dialogWindowVisible = false
      end
    end
  end
end

function love.wheelmoved(x, y)
  if menu:isActive() and menu:isMouseInStatSection() then
    menu:scrolltext(y*love.window.toPixels(5))
  else
    if y > 0 then
      camera:zoomIn()
    elseif y < 0 then
      camera:zoomOut()
    end
  end
end

function love.keypressed(key, scancode, isRepeat)
  if key == 'up' then
    camera:zoomIn()
  elseif key == 'down' then
    camera:zoomOut()
  elseif key == 'p' then
    if lastClicked then
      graphSearchThread = Graph.planShortestRoute(lastClicked)
    end
  elseif key == 'f1' then
    DEBUG = not DEBUG
  elseif scancode == '[' then
    if not ascendancyClassPicker:isActive() and not classPicker:isActive() and not menu:isTransitioning() then
      menu:toggle()
    end
  elseif key == 'escape' then
    Graph.export(activeClass, ascendancyClass, nodes)
    love.event.quit()
  elseif scancode == 'pagedown' then
    if menu:isActive() then
      menu:scrolltext(-love.window.toPixels(125))
    end
  elseif scancode == 'pageup' then
    if menu:isActive() then
      menu:scrolltext(love.window.toPixels(125))
    end
  end
end


function checkIfNodeHovered(x, y)
  local hovered = nil
  for nid, node in pairs(visibleNodes) do
    if not node:isMastery() and not node:isStart() then
      local wx, wy = cameraCoords(node.position.x, node.position.y)
      local dx, dy = wx - x, wy - y
      local r = Node.Radii[node.type] * camera.scale
      if dx * dx + dy * dy <= r * r then
        hovered = nid
        showNodeDialog(nid)
      end
    end
  end

  -- Do route planning on hover, since desktop OS
  -- doesn't use the two-click method of activating nodes
  if hovered == nil then
    lastClicked = nil
    addTrail = {}
    removeTrail = {}
    dialogWindowVisible = false
  elseif hovered ~= lastClicked then
    if DEBUG then
      print(hovered..' hovered')
    end
    lastClicked = hovered
    addTrail = {}
    removeTrail = {}
    if nodes[hovered].active then
      removeTrail = Graph.planRefund(hovered) or {}
    else
      addTrail = Graph.planShortestRoute(hovered) or {}
    end
  end

  return hovered
end

function checkIfAscendancyNodeHovered(x, y, button, isTouch)
  local hovered = nil

  local ascendancyTreeStart = ascendancyTreeOrigins[Node.getAscendancyClassName()]
  if ascendancyTreeStart == nil then return nil end
  local center = {}
  center.x, center.y = ascendancyPanel:getCenter()

  local offset = {}
  offset.x, offset.y = center.x-ascendancyTreeStart.position.x, center.y-ascendancyTreeStart.position.y

  for nid, node in pairs(ascendancyNodes) do
    if not node.isAscendancyStart then
      local pos = {
        x = node.position.x + offset.x,
        y = node.position.y + offset.y,
      }
      local wx, wy = cameraCoords(pos.x, pos.y)
      local dx, dy = wx - x, wy - y
      local r = Node.Radii[node.type] * camera.scale
      if dx * dx + dy * dy <= r * r then
        if not node.isAscendancyStart then
          hovered = nid
          showNodeDialog(nid, wx, wy)
        end
      end
    end
  end

  if hovered == nil then
    lastClicked = nil
    addTrail = {}
    removeTrail = {}
    dialogWindowVisible = false
  elseif hovered ~= lastClicked then
    if DEBUG then
      print(hovered..' hovered')
    end
    lastClicked = hovered
    addTrail = {}
    removeTrail = {}
    if nodes[hovered].active then
      removeTrail = Graph.planRefund(hovered) or {}
    else
      addTrail = Graph.planShortestRoute(hovered) or {}
    end
  end

  return hovered
end

function clearColor()
  love.graphics.setColor(orig_r, orig_g, orig_b, orig_a)
end

function tiledBackground()
  if background then
    background:clear()
  end
  local bgImage = love.graphics.newImage('assets/Background1.png')
  local w, h = bgImage:getDimensions()
  local tilesX, tilesY = math.ceil(winWidth/w), math.ceil(winHeight/h)
  background = love.graphics.newSpriteBatch(bgImage, (tilesX+1)*(tilesY+1), "static")
  for tx = 0, tilesX do
    for ty=0, tilesY do
      background:add(w*tx, h*ty)
    end
  end
end

function refillBatches()

  -- Clear out batches
  for name, _ in pairs(batches) do
    batches[name]:clear()
  end

  -- Re-calculate visible nodes
  local tx, ty = winWidth/(2*camera.scale)-camera.x, winHeight/(2*camera.scale)-camera.y
  visibleNodes = {}
  visibleGroups = {}
  ascendancyNodes = {}
  for nid, node in pairs(nodes) do
    if node:isVisible(tx, ty) then
      visibleNodes[node.id] = node
      if visibleGroups[node.gid] == nil then
        visibleGroups[node.gid] = groups[node.gid]
      end
    end

    -- Fill ascendancy node table
    if node.type > 6 and node.ascendancyName == Node.getAscendancyClassName() then
      -- ascendancyNodes[#ascendancyNodes] = node
      ascendancyNodes[nid] = node
      if node.isAscendancyStart then
        ascendancyTreeOrigins[node.ascendancyName] = node
      end
    end
  end

  -- Re-fill them batches
  for nid, node in pairs(visibleNodes) do
    node:draw()
  end

  for gid, group in pairs(visibleGroups) do
    group:draw()
  end

end

function showNodeDialog(nid, x, y)
  local node = nodes[nid]

  -- Update text and calculate dialog box position
  local contentText = ''
  dialogHeaderText:set(node.name)

  -- Add all description texts to dialog
  for _, desc in ipairs(node.descriptions) do
    contentText = contentText .. '\n' .. desc
  end
  dialogContentText:set(contentText)

  -- Update dialog window dimensions based on new text
  local w1, h1 = dialogHeaderText:getDimensions()
  local w2, h2 = dialogContentText:getDimensions()
  if w1 > w2 then
    dialogPosition.w = w1
  else
    dialogPosition.w = w2
  end
  dialogPosition.w = dialogPosition.w + 10
  dialogPosition.h = 5*3 + h1 + h2

  -- Get position of node in camera coords, and adjust it so that
  -- the whole window will always fit on the screen
  if x == nil or y == nil then
    x, y = cameraCoords(node.position.x, node.position.y)
  end
  x, y = adjustDialogPosition(x, y, dialogPosition.w, dialogPosition.h, 20)
  dialogPosition.x, dialogPosition.y = x, y

  -- Set window to visible
  dialogWindowVisible = true
end

function screenToWorldCoords(x, y)
  x, y = (x - winWidth/2) / camera.scale, (y - winHeight/2) / camera.scale
  return x + camera.x, y + camera.y
end

function cameraCoords(x, y)
  x, y = x - camera.x, y - camera.y
  return x * camera.scale + winWidth/2, y * camera.scale + winHeight/2
end

function adjustDialogPosition(x, y, w, h, offset)
  local dx, dy = x, y
  local hx, hy = winWidth/2, winHeight/2

  if x < hx and y < hy then         -- Upper-left quadrant
    dx, dy = x + offset, y + offset
  elseif x > hx and y < hy then     -- Upper-right quadrant
    dx, dy = x - w - offset, y + offset
  elseif x < hx and y > hy then     -- Lower-left quadrant
    dx, dy = x + offset, y - h - offset
  else                              -- Lower-right quadrant
    dx, dy = x - w - offset, y - h - offset
  end

  -- Some of the dialog boxes are super-wide
  if dx + w > winWidth then
    dx = winWidth - w - offset
  elseif dx - w < 0 then
    dx = offset
  end

  return dx, dy
end

function dist(v1, v2)
  return math.sqrt((v2.x - v1.x)*(v2.x - v1.x) + (v2.y - v1.y)*(v2.y - v1.y))
end

function drawDialogWindow()
  local five = love.window.toPixels(5)

  -- Inner and outer rectangles
  love.graphics.setColor(1, 1, 1, 240)
  love.graphics.rectangle('fill', dialogPosition.x, dialogPosition.y, dialogPosition.w, dialogPosition.h)
  clearColor()
  love.graphics.rectangle('line', dialogPosition.x, dialogPosition.y, dialogPosition.w, dialogPosition.h)

  -- Draw text
  love.graphics.draw(dialogHeaderText, dialogPosition.x + five, dialogPosition.y + five)
  love.graphics.draw(dialogContentText, dialogPosition.x + five, dialogPosition.y + five*4)
end

function activateNode(nid)
  nodes[nid].active = true

  -- Add node stats to character stats
  local node = nodes[nid]
  parseDescriptions(node, add)
  menu:updateStatText(character)
  activeNodes = activeNodes + 1

  characterURL = Graph.export(activeClass, ascendancyClass, nodes)
end

function deactivateNode(nid)
  nodes[nid].active = false

  -- Remove node stats from character stats
  local node = nodes[nid]
  parseDescriptions(node, subtract)
  menu:updateStatText(character)
  activeNodes = activeNodes - 1

  characterURL = Graph.export(activeClass, ascendancyClass, nodes)
end

function parseDescriptions(node, op)
  local found = {}
  if node.type == Node.NT_KEYSTONE then
    if op == subtract then
      character.keystones[node.id] = nil
    else
      character.keystones[node.id] = node.descriptions
    end
  else
    for i, desc in ipairs(node.descriptions) do
      for n,s in desc:gmatch("(%d+) (%a[%s%a]*)") do
        found[#found+1] = s
        if DEBUG then
          print('s: '..s, 'n: '..n)
        end
        n = tonumber(n)
        if s == 'to Strength' then
          character.str = op(character.str, n)
        elseif s == 'to Intelligence' then
          character.int = op(character.int, n)
        elseif s == 'to Dexterity' then
          character.dex = op(character.dex, n)
        elseif s == 'to Dexterity and Intelligence' or s == 'to Intelligence and Dexterity' then
          character.dex = op(character.dex, n)
          character.int = op(character.int, n)
        elseif s == 'to Strength and Intelligence' or s == 'to Intelligence and Strength' then
          character.str = op(character.str, n)
          character.int = op(character.int, n)
        elseif s == 'to Strength and Dexterity' or s == 'to Dexterity and Strength' then
          character.str = op(character.str, n)
          character.dex = op(character.dex, n)
        else
          local v = character.stats[s] or 0
          v = op(v, n)
          if v == 0 then
            v = nil
          end
          character.stats[s] = v
        end
      end

      if #found ~= i then
        for n,s in desc:gmatch("(%d+)(%%? %a[%s%a]*)") do
          found[#found+1] = s
          local v = character.stats[s] or 0
          v = op(v, n)
          if v == 0 then
            v = nil
          end
          character.stats[s] = v
        end
      end

      if #found ~= i then
        print('Still not found :(')
        print(desc)
      end

    end
  end
end

-- Helper functions so that I can use + or - as arguments
-- to other functions
function add(n1, n2)
  if DEBUG then
    print('Adding '..n1..' to '..n2)
  end
  return n1+n2
end

function subtract(n1, n2)
  if DEBUG then
    print('Subtracting '..n1..' from '..n2)
  end
  return n1-n2
end

function changeActiveClass(class, aclass)
  -- Don't do anything if not new class
  if class == activeClass and aclass == ascendancyClass then return false end

  -- Provide confirmation dialog
  local buttons = {"Cancel", "OK", escapebutton=1, enterbutton=2}
  if love.window.showMessageBox('Change Class?', 'Are you sure you want to change class and reset the skill tree?', buttons, 'info', true) ~= 2 then return end

  addTrail    = {}
  removeTrail = {}

  -- Only reset tree if main class changed
  if activeClass ~= class then
    activeClass = class
    startnid = startNodes[activeClass]
    startNode = nodes[startnid]
    portrait = classPicker:getPortrait(activeClass)
    menu:updatePortrait(portrait)

    for nid, node in pairs(nodes) do
      if node.active then
        deactivateNode(nid)
      end
    end

    nodes[startnid].active = true
    camera:setPosition(startNode.position.x, startNode.position.y)
    ascendancyButton:changeStart(startnid)
  end

  -- Probably don't need this check, but whatever
  if ascendancyClass ~= aclass then
    ascendancyClass = aclass
    for nid, node in pairs(ascendancyNodes) do
      deactivateNode(nid)
    end
  end

  -- Always refill the batches
  refillBatches()
end

function toggleNodes(nid)
  local clicked = nodes[nid]
  if clicked.active then
    addTrail = {}
    removeTrail = Graph.planRefund(clicked.id)
  else
    removeTrail = {}
    addTrail = Graph.planShortestRoute(clicked.id)
  end

  -- Add nodes in addTrail
  for id,_ in pairs(addTrail) do
    if not nodes[id].active then
      activateNode(id)
    end
  end
  addTrail = {}

  -- Remove all nodes in removeTrail
  for id,_ in pairs(removeTrail) do
    deactivateNode(id)
  end
  removeTrail = {}
  refillBatches()
  lastClicked = nil
end

