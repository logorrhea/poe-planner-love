local scaleFix = 2.5

local OS = love.system.getOS()
local json   = require 'vendor.dkjson'
local Timer  = require 'vendor.hump.timer'
local lume   = require 'vendor.lume.lume'


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
clickCoords = {x = 0, y = 0, onGUI = false, onStats = false}
visibleNodes = {}
visibleGroups = {}
startNodes = {}
addTrail = {}
removeTrail = {}
ascendancyNodes = {}
orig_r, orig_g, orig_b, orig_a = love.graphics.getColor()

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
local headerFont = love.graphics.newFont('fonts/fontin-bold-webfont.ttf', 20*love.window.getPixelScale())
headerFont:setFilter('nearest', 'nearest')
local font = love.graphics.newFont('fonts/fontin-bold-webfont.ttf', 14*love.window.getPixelScale())
font:setFilter('nearest', 'nearest')

-- Stat window images
local statsShowing = false
local statsTransitioning = false
local charStatLabels = love.graphics.newText(headerFont, 'Str:\nInt:\nDex:')
local charStatText = love.graphics.newText(headerFont, '0\n0\n0')
local generalStatLabels = love.graphics.newText(font, '')
local generalStatText = love.graphics.newText(font, '')
local portrait = love.graphics.newImage('assets/'..Node.Classes[activeClass].name..'-portrait.png')
local divider  = love.graphics.newImage('assets/LineConnectorNormal.png')
local leftIcon = love.graphics.newImage('assets/left.png')
local keystoneLabels = {}
local keystoneDescriptions = {}

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

-- Class picker window stuff
local portraits = {}
local classPickerShowing = false
for _, class in ipairs(Node.Classes) do
  portraits[#portraits+1] = love.graphics.newImage('assets/'..class.name..'-portrait.png')
end

-- Use to determine whether to plan route/refund or activate nodes
local lastClicked = nil

function love.load()
  circleRadius = 10

  -- Get tree data. Will download new version if necessary
  -- Tree = Downloader.getLuaTree()
  -- local data = Downloader.processNodes(Tree)
  Tree = require 'passive-skill-tree'

  -- Read save file
  local savedNodes = {}
  if love.filesystem.exists('builds.lua') then
    local saveDataFunc = love.filesystem.load('builds.lua')
    local saveData = saveDataFunc()
    activeClass, ascendancyClass, savedNodes = Graph.import(saveData.nodes)
    portrait = love.graphics.newImage('assets/'..Node.Classes[activeClass].name..'-portrait.png')
  end

  -- Cache node count
  local nodeCount = #Tree.nodes
  local groupCount = 0
  for gid, group in pairs(Tree.groups) do
    groupCount = groupCount + 1
  end

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

  -- Get connection images
  -- @NOTE: unused; not sure if we should just keep lines or not
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

  -- Set better starting position
  startnid = startNodes[activeClass]
  startNode = nodes[startnid]
  camera.x = startNode.position.x
  camera.y = startNode.position.y

  -- Create SpriteBatch for background image
  tiledBackground()

  -- Fill up sprite batches
  refillBatches()

  -- Show GUI
  guiButtons.menuToggle = {
    x     = love.window.toPixels(10),
    y     = love.window.toPixels(10),
    sx    = 0.1*love.window.getPixelScale(),
    sy    = 0.1*love.window.getPixelScale(),
    image = love.graphics.newImage('assets/menu.png'),
    trigger = (function()
        -- Slide in stats board
        statsShowing = true
        Timer.tween(0.5, statPanelLocation, {x = 0}, 'in-out-quad')
    end)
  }

  -- Create ascendancy button and panel
  ascendancyButton = require 'ui.ascendancybutton'
  ascendancyButton:init(Tree, startnid)
  ascendancyPanel = require 'ui.ascendancypanel'
  ascendancyPanel:init(ascendancyButton, batches)


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

  -- Draw ascendancy node connections
  love.graphics.setColor(inactiveConnector)
  love.graphics.setLineWidth(3/camera.scale)
  local center = {x=0,y=0}
  center.x, center.y = ascendancyPanel:getCenter()
  if ascendancyButton:isActive() then
    for nid, node in pairs(ascendancyNodes) do
      node:drawConnections(center)
    end
  end
  love.graphics.setLineWidth(1)
  clearColor()

  -- Draw ascendancy nodes
  -- @TODO: Looks like 'ascendant' is going to be a special case :(
  if ascendancyButton:isActive() then
    for nid,node in pairs(ascendancyNodes) do
      node:immediateDraw(center, pos)
    end
  end

  -- Pop graphics state to draw UI
  love.graphics.pop()

  -- Draw menuToggle.image button in top-left
  for _, item in pairs(guiButtons) do
    love.graphics.draw(item.image, item.x, item.y, 0, item.sx, item.sy)
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
  if statsShowing then
    drawStatsPanel()
  end

  if dialogWindowVisible then
    drawDialogWindow()
  end

  if classPickerShowing then
    drawClassPickerWindow()
  end
end

if OS == 'iOS' then

  function love.touchpressed(id, x, y, dx, dy, pressure)
    dialogWindowVisible = false
    clickCoords.x, clickCoords.y = x, y
    clickCoords.onGUI = isMouseInGUI(x, y)
    clickCoords.onStats = isMouseInStatSection()
  end

  function love.touchreleased(id, x, y, dx, dy, pressure)
    if not isTouch then
      local dx = x - clickCoords.x
      local dy = y - clickCoords.y

      if math.abs(dx) <= 3 and math.abs(dy) <= 3 then
        if ascendancyButton:click(x, y) then
        else
          local guiItemClicked = checkIfGUIItemClicked(x, y, button, isTouch)
          if not guiItemClicked and not clickCoords.onGUI then
            checkIfNodeClicked(x, y, button, isTouch)
          end
        end
      end
    end
    clickCoords.onGUI = false
    clickCoords.onStats = false
  end

  function love.touchmoved(id, x, y, dx, dy, pressure)
    dialogWindowVisible = false
    local touches = love.touch.getTouches()
    if #touches == 1 then
      if isMouseInGUI(clickCoords.x, clickCoords.y) then
        if isMouseInStatSection(clickCoords.x, clickCoords.y) then
          statTextLocation:yadj(dy)
        end
      else
        camera.x = camera.x - (dx/camera.scale)
        camera.y = camera.y - (dy/camera.scale)
        refillBatches()
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

  -- Non-iOS event listeners
else

  function love.mousepressed(x, y, button, isTouch)
    dialogWindowVisible = false
    clickCoords.x, clickCoords.y = x, y
    clickCoords.onGUI = isMouseInGUI(x, y)
    clickCoords.onStats = isMouseInStatSection()
  end

  function love.mousereleased(x, y, button, isTouch)
    if not isTouch then
      local dx = x - clickCoords.x
      local dy = y - clickCoords.y

      local three = love.window.toPixels(3)
      if math.abs(dx) <= three and math.abs(dy) <= three then
        if ascendancyButton:click(x, y) then
        else
          local guiItemClicked = checkIfGUIItemClicked(x, y, button, isTouch)
          if not guiItemClicked and not clickCoords.onGUI then
            checkIfNodeClicked(x, y, button, isTouch)
          end
        end
      end
    end
    clickCoords.onGUI = false
    clickCoords.onStats = false
  end

  function love.mousemoved(x, y, dx, dy)
    if love.mouse.isDown(1) then
      if isMouseInGUI(clickCoords.x, clickCoords.y) then
        if isMouseInStatSection(clickCoords.x, clickCoords.y) then
          statTextLocation:yadj(dy)
        end
      else
        camera.x = camera.x - (dx/camera.scale)
        camera.y = camera.y - (dy/camera.scale)
        refillBatches()
      end
    else
      local hovered = nil
      if ascendancyButton:isActive() then
        hovered = checkIfAscendancyNodeHovered(x, y)
      end
      if hovered == nil then
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

  function love.wheelmoved(x, y)
    -- if stat panel showing
    if statsShowing and isMouseInGUI() then
      -- and mouse over stat text section, scroll stat text
      if isMouseInStatSection() then
        statTextLocation:yadj(y*love.window.toPixels(5))
      end
    else
      -- otherwise, scroll camera
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
      if statsShowing then
        closeStatPanel()
      else
        guiButtons.menuToggle.trigger()
      end
    elseif key == 'escape' then
      -- local buttons = {"Cancel", "OK", escapebutton=1, enterbutton=2}
      -- if love.window.showMessageBox('Close PoE Planner?', '', buttons, 'info', true) == 2 then
        love.event.quit()
      -- end
    elseif scancode == 'pagedown' then
      statTextLocation:yadj(-love.window.toPixels(125))
    elseif scancode == 'pageup' then
      statTextLocation:yadj(love.window.toPixels(125))
    end
  end

end

function checkIfGUIItemClicked(mx, my, button, isTouch)
  for name, item in pairs(guiButtons) do
    local w, h = item.image:getDimensions()
    w, h = w*item.sx, h*item.sy
    local x1, y1 = item.x, item.y
    local x2, y2 = item.x + w, item.y + h

    if mx >= x1 and mx <= x2 and my >= y1 and my <= y2 then
      item.trigger()
      return true
    end
  end

  if statsShowing then

    -- Check close button clicked
    local w, h = leftIcon:getDimensions()
    local x1, y1 = love.window.toPixels(300)-love.window.toPixels(w), (winHeight-love.window.toPixels(h))/2
    local x2, y2 = x1+love.window.toPixels(w), y1+love.window.toPixels(h)
    if mx >= x1 and mx <= x2 and my >= y1 and my <= y2 then
      closeStatPanel()
      return true
    end

    -- Check class portrait clicked
    if not statsTransitioning then
      local w, h = portrait:getDimensions()
      local x1, y1 = love.window.toPixels(5), love.window.toPixels(5)
      local x2, y2 = x1+love.window.toPixels(w), y1+love.window.toPixels(h)
      if mx >= x1 and mx <= x2 and my >= y1 and my <= y2 then
        classPickerShowing = not classPickerShowing
        return true
      end
    end
  end

  -- Check if any of the other class icons are clicked
  if classPickerShowing then
    local five = love.window.toPixels(5)
    local w, h = love.window.toPixels(110), love.window.toPixels(105)
    local x1, y1 = statPanelLocation.x+w+five, five
    local x2, y2 = x1+w, y1+h
    for i, class in ipairs(Node.Classes) do
      if i ~= activeClass then
        if mx >= x1 and mx <= x2 and my >= y1 and my <= y2 then
          local buttons = {"Cancel", "OK", escapebutton=1, enterbutton=2}
          if love.window.showMessageBox('Change Class?', 'Are you sure you want to change class and reset the skill tree?', buttons, 'info', true) == 2 then
            changeActiveClass(i)
            return true
          end
        end
        x1, x2 = x2, x2 + w
      end
    end
  end

  return false
end

function checkIfNodeHovered(x, y)
  local hovered = nil
  for nid, node in pairs(visibleNodes) do
    if not node:isMastery() and not node:isStart() then
    -- end
    -- if node.type ~= Node.NT_MASTERY and node.type ~= Node.NT_START then
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
  local center = {}
  center.x, center.y = ascendancyPanel:getCenter()
  for nid, node in pairs(ascendancyNodes) do
    if not node.isAscendancyStart then
      local pos = Node.nodePosition(node, center)
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

function checkIfNodeClicked(x, y, button, isTouch)
  local clicked = nil
  if ascendancyButton:isActive() then
    print('checking ascendancy nodes...')
    local center = {}
    center.x, center.y = ascendancyPanel:getCenter()
    for nid, node in pairs(ascendancyNodes) do
      if not node.isAscendancyStart then
        local pos = Node.nodePosition(node, center)
        local wx, wy = cameraCoords(pos.x, pos.y)
        local dx, dy = wx - x, wy - y
        local r = Node.Radii[node.type] * camera.scale
        if dx * dx + dy * dy <= r * r then
          if not node.isAscendancyStart then
            clicked = node
            if DEBUG then
              print('clicked: '..clicked.id)
            end
          end
        end
      end
    end
  end
  if clicked == nil then
    for nid, node in pairs(visibleNodes) do
      local wx, wy = cameraCoords(node.position.x, node.position.y)
      local dx, dy = wx - x, wy - y
      local r = Node.Radii[node.type] * camera.scale
      if dx * dx + dy * dy <= r * r then
        clicked = node
        if DEBUG then
          print('clicked: '..clicked.id)
        end
      end
    end
  end

  if clicked ~= nil then

    -- For mobile, use two-tap node selection system
    if OS == 'iOS' then
      if clicked.id == lastClicked then
        -- On second click, toggle all nodes in highlighted trail
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
      else

        -- On first click, we should give some preview information:
        --  Dialog box diplaying information about the clicked node
        --  Preview a route from closest active node
        if clicked.active then
          addTrail = {}
          removeTrail = Graph.planRefund(nid)
        else
          removeTrail = {}
          addTrail = Graph.planShortestRoute(nid)
        end
        showNodeDialog(nid)
        lastClicked = nid
      end

      -- For desktop OS, we don't need the double-click behavior
    else
      -- Gather nodes for addition or removal
      if clicked.active then
        addTrail = {}
        removeTrail = Graph.planRefund(clicked.id)
      else
        removeTrail = {}
        addTrail = Graph.planShortestRoute(clicked.id)
      end

      -- Check that addTrail doesn't take us over maxActive
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
    return true
  end

  -- Not sure which behavior is better?
  -- Clear trail on empty click, or are they just trying to hide
  -- the dialog window? Maybe make it an option at some point?
  -- OR  - maybe the dialog window should have an obvious close button?
  -- addTrail = {}
  return false
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

function drawStatsPanel()
  local five = love.window.toPixels(5)

  love.graphics.setColor(1, 1, 1, 240)
  love.graphics.rectangle('fill', statPanelLocation.x, 0, love.window.toPixels(300), winHeight)

  -- Stat panel outline
  clearColor()
  love.graphics.rectangle('line', statPanelLocation.x, 0, love.window.toPixels(300), winHeight)

  -- Draw portrait
  love.graphics.draw(portrait, statPanelLocation.x+five, five, 0, love.window.getPixelScale(), love.window.getPixelScale())

  -- Character stats
  love.graphics.draw(charStatLabels, statPanelLocation.x+love.window.toPixels(155), love.window.toPixels(18))
  love.graphics.draw(charStatText, statPanelLocation.x+love.window.toPixels(155)+charStatLabels:getWidth()*2, love.window.toPixels(18))

  -- Draw divider
  love.graphics.draw(divider, statPanelLocation.x+5, love.window.toPixels(115), 0, love.window.toPixels(0.394), 1.0)

  -- Set stat panel scissor
  love.graphics.setScissor(statPanelLocation.x+5, love.window.toPixels(125), love.window.toPixels(285), winHeight-love.window.toPixels(125))

  -- Draw keystone node text
  local y = statTextLocation.y
  for i=1,character.keystoneCount do
    love.graphics.draw(keystoneLabels[i], statPanelLocation.x+five, y)
    y = y + keystoneLabels[i]:getHeight()
    love.graphics.draw(keystoneDescriptions[i], statPanelLocation.x+five, y)
    y = y + keystoneDescriptions[i]:getHeight()
  end

  if character.keystoneCount > 0 then
    y = y + headerFont:getHeight()
  end

  -- Draw general stats
  love.graphics.draw(generalStatLabels, statPanelLocation.x+five, y)
  love.graphics.draw(generalStatText, statPanelLocation.x+five+generalStatLabels:getWidth()*1.5, y)

  -- Reset scissor
  love.graphics.setScissor()

  -- Draw left icon (click to close stats drawer)
  local w, h = leftIcon:getDimensions()
  love.graphics.setColor(255, 255, 255, 255)
  love.graphics.draw(leftIcon, statPanelLocation.x+love.window.toPixels(295)-love.window.toPixels(w), (winHeight-love.window.toPixels(h))/2, 0, love.window.getPixelScale(), love.window.getPixelScale())
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

function drawClassPickerWindow()
  local five = love.window.toPixels(5)
  local w, h = love.window.toPixels(110), love.window.toPixels(105)
  local x, y = statPanelLocation.x+w+five, five
  for i, img in ipairs(portraits) do
    if i ~= activeClass then
      love.graphics.draw(img, x, y, 0, love.window.getPixelScale(), love.window.getPixelScale())
      x = x + w
    end
  end
end

function activateNode(nid)
  nodes[nid].active = true

  -- Add node stats to character stats
  local node = nodes[nid]
  parseDescriptions(node, add)
  updateStatText()
  activeNodes = activeNodes + 1

  -- @TODO: Send to threads that node became active

  characterURL = Graph.export(activeClass, ascendancyClass, nodes)
end

function deactivateNode(nid)
  nodes[nid].active = false

  -- Remove node stats from character stats
  local node = nodes[nid]
  parseDescriptions(node, subtract)
  updateStatText()
  activeNodes = activeNodes - 1

  -- @TODO: Send to threads that node became inactive

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
  return n1-n2
end

function updateStatText()
  -- Update base stats
  charStatText:set(string.format('%i\n%i\n%i', character.str, character.int, character.dex))

  -- Update general stats
  local _labels = {}
  local _stats = {}
  local text
  for desc, n in pairs(character.stats) do
    if n > 0 then
      width, wrapped = font:getWrap(desc, love.window.toPixels(270))
      for i, text in ipairs(wrapped) do
        if i == 1 then
          _labels[#_labels+1] = n
        else
          _labels[#_labels+1] = ' '
        end
        _stats[#_stats+1] = text
      end
    end
  end
  generalStatLabels:set(table.concat(_labels, '\n'))
  generalStatText:set(table.concat(_stats, '\n'))
  local height = generalStatText:getHeight()

  -- Update Keystone Text
  local i = 1
  for nid, descriptions in pairs(character.keystones) do
    -- Recycle labels if possible
    local label = keystoneLabels[i] or love.graphics.newText(headerFont, '')
    local desc = keystoneDescriptions[i] or love.graphics.newText(font, '')
    label:set(nodes[nid].name)
    desc:set(table.concat(descriptions, '\n'))
    keystoneLabels[i] = label
    keystoneDescriptions[i] = desc
    height = height + label:getHeight() + desc:getHeight()
    i = i + 1
  end

  character.keystoneCount = i-1
  if i ~= 0 then
    height = height + headerFont:getHeight()
  end

  local diff = (winHeight - love.window.toPixels(125)) - height
  if diff < 0 then
    statTextLocation.minY = diff
  end
end

function closeStatPanel()
  classPickerShowing = false
  statsTransitioning = true
  Timer.tween(0.5, statPanelLocation, {x = -love.window.toPixels(300)}, 'in-out-quad')
  Timer.after(0.5, function()
                statsTransitioning = false
                statsShowing = false
  end)
end

function changeActiveClass(sel)
  closeStatPanel()
  activeClass = sel
  ascendancyClass = 1 -- @TODO: This should be part of the class change process later
  addTrail    = {}
  removeTrail = {}
  startnid = startNodes[activeClass]
  startNode = nodes[startnid]
  portrait = love.graphics.newImage('assets/'..Node.Classes[activeClass].name..'-portrait.png')
  for nid, node in pairs(nodes) do
    if node.active then
      deactivateNode(nid)
    end
  end
  nodes[startnid].active = true
  camera.x, camera.y = startNode.position.x, startNode.position.y
  ascendancyButton:changeStart(startnid)
  refillBatches()
end

function isMouseInStatSection(x, y)
  if x == nil or y == nil then
    x, y = love.mouse.getPosition()
  end
  return x < love.window.toPixels(300) and y > love.window.toPixels(125)
end

function isMouseInGUI(x, y)
  if x == nil or y == nil then
    x, y = love.mouse.getPosition()
  end

  -- Oversimplified, but should do the job for now
  if statsShowing then
    return x < love.window.toPixels(300)
  else
    if guiButtons.menuToggle then
      local ten = love.window.toPixels(10)
      local w,h = guiButtons.menuToggle.image:getDimensions()
      w = w*guiButtons.menuToggle.sx
      h = h*guiButtons.menuToggle.sy
      return x > ten and x < (ten+w) and y > ten and y < (ten+h)
    else
      return false
    end
  end
end
