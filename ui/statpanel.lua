local suit = require 'lib.suit'
local strings = require 'lib.strings'

local panel = {
  x = 0,
  y = -winHeight,
  status = 'inactive',
  innerContent = 'builds',
  builds = {},
  width = love.window.toPixels(300),
  padding = love.window.toPixels(5),
  buildName = love.graphics.newText(headerFont, ''),
  className = love.graphics.newText(font, '')
}

local divider  = love.graphics.newImage('assets/LineConnectorNormal.png')
local leftIcon = love.graphics.newImage('assets/left.png')
local charStatLabels = love.graphics.newText(headerFont, 'Str:\nInt:\nDex:')
local charStatText = love.graphics.newText(headerFont, '0\n0\n0')
local generalStatLabels = love.graphics.newText(font, '')
local generalStatText = love.graphics.newText(font, '')
local keystoneLabels = {}
local keystoneDescriptions = {}


local plusbutton = love.graphics.newImage('assets/cross100x100.png')

function panel:init(builds)
  self.statText = {
    maxY = love.window.toPixels(125),
    minY = love.window.toPixels(125),
    y    = love.window.toPixels(125),
    yadj = function(self, dy)
      self.y = lume.clamp(self.y+dy, self.minY, self.maxY)
    end
  }

  self.editing = nil
  self.builds = builds
  self:initIcons()
end

function panel:toggle()
  if self.status == 'inactive' then
    self:show()
  elseif self.status == 'active' then
    self:hide()
  end
end

function panel:show()
  self.status = 'opening'
  local duration = 0.5
  Timer.tween(duration, self, {y = 0}, 'out-back')
  Timer.after(duration, function() panel.status = 'active' end)
end

function panel:hide()
  self.status = 'closing'
  local duration = 0.5
  Timer.tween(duration, self, {y = -winHeight}, 'in-back')
  Timer.after(duration, function()
    panel.status = 'inactive'
  end)
end

function panel:isTransitioning()
  return self.status == 'closing' or self.status == 'opening'
end

function panel:isActive()
  return self.status ~= 'inactive'
end

function panel:isExclusive()
  return false
end

function panel:draw(character)
  local five = love.window.toPixels(5)

  love.graphics.setColor(1, 1, 1, 240)
  love.graphics.rectangle('fill', self.x, self.y, self.width, winHeight)

  -- Stat panel outline
  clearColor()
  love.graphics.rectangle('line', self.x, self.y, self.width, winHeight)

  -- Character stats
  love.graphics.draw(charStatLabels, self.x+love.window.toPixels(155), self.y+love.window.toPixels(18))
  love.graphics.draw(charStatText, self.x+love.window.toPixels(155)+charStatLabels:getWidth()*2, self.y+love.window.toPixels(18))

  -- Draw divider
  love.graphics.draw(divider, self.x+five, self.y+love.window.toPixels(115), 0, love.window.toPixels(0.394), 1.0)

  -- Set stat panel scissor
  love.graphics.setScissor(self.x+five, self.y+love.window.toPixels(125), love.window.toPixels(285), winHeight-love.window.toPixels(125))

  if self.innerContent == 'stats' then
    -- Draw keystone node text
    local y = self.statText.y
    for i=1,character.keystoneCount do
      love.graphics.draw(keystoneLabels[i], self.x+five, self.y+y)
      y = y + keystoneLabels[i]:getHeight()
      love.graphics.draw(keystoneDescriptions[i], self.x+five, self.y+y)
      y = y + keystoneDescriptions[i]:getHeight()
    end

    if character.keystoneCount > 0 then
      y = y + headerFont:getHeight()
    end

    -- Draw general stats
    love.graphics.draw(generalStatLabels, self.x+five, self.y+y)
    love.graphics.draw(generalStatText, self.x+five+generalStatLabels:getWidth()*1.5, self.y+y)
  elseif self.innerContent == 'builds' then
    -- Show builds listing
    local y = love.window.toPixels(125)
    love.graphics.setFont(font)
    clearColor()
    for i, build in ipairs(self.builds) do
      -- Build title and class strings
      local c, a = Graph.getClassData(build.nodes)
      self.buildName:set(build.name)
      self.className:set(strings.capitalize(Node.Classes[c].ascendancies[a]))

      -- Draw build title
      if self.editing ~= nil and self.editing.index == i then
        local input = suit.Input(self.editing, {id = 'edit-build-name', font=headerFont}, five, self.y+y)
      else
        if suit.Label(build.name, {font=headerFont}, five, self.y+y).hit then
          changeActiveBuild(i)
        end
      end

      -- Draw edit icon
      self.icons.edit.options.id = 'edit-button-'..tostring(i)
      if suit.SpritesheetButton(self.icons.edit.sheet, self.icons.edit.options, love.window.toPixels(300-70-5), self.y+y).hit then
        if self.editing == nil then
          print("enable editing for "..i)
          self.editing = {
            index = i,
            text = build.name
          }
        else
          self.builds[i].name = self.editing.text
          self.editing = nil
          -- can we do this from here? probably need to rethink this whole graph.export function
          -- i think we need a whole savedata class that keeps track of all this bullshit
          saveData = Graph.export(saveData, currentBuild, activeClass, ascendancyClass, nodes)
        end
      end

      -- Draw delete icon
      if #self.builds > 1 then
        self.icons.delete.options.id = 'delete-button-'..tostring(i)
        if suit.SpritesheetButton(self.icons.delete.sheet, self.icons.delete.options, love.window.toPixels(300-32-5), self.y+y).hit then
          local buttons = {"Cancel", "OK", escapebutton=1, enterbutton=2}
          if love.window.showMessageBox('Delete Build?', 'Are you sure you want to delete "'..build.name..'"?', buttons, 'info', true) == 2 then
            deleteBuild(i)
          end
        end
      end

      -- Draw class name
      y = y + self.buildName:getHeight()
      love.graphics.draw(self.className, five, self.y+y)
      y = y + self.className:getHeight()

      -- Build link (might exclude this)
      -- y = y + five*10
    end

    -- Show new build button
    if suit.ImageButton(plusbutton, {}, five, self.y+y, 0, 0.25, 0.25).hit then
      startNewBuild()
      self:hide()
    end
  end

  -- Reset scissor
  love.graphics.setScissor()

  -- Draw left icon (click to close stats drawer)
  local w, h = leftIcon:getDimensions()
  w, h = love.window.toPixels(w), love.window.toPixels(h)

  local x1 = (self.width-h)/2
  local y1 = self.y+winHeight-w-love.window.toPixels(10)

  -- Draw toggle icon
  love.graphics.setColor(255, 255, 255, 255)
  love.graphics.draw(leftIcon,
                     self.x+self.width/2,
                     self.y+winHeight-w/2-love.window.toPixels(10),
                     math.pi/2,
                     love.window.getPixelScale(),
                     love.window.getPixelScale(),
                     w/2,
                     h/2)

  -- Draw stat button
  local labelHeight = love.window.toPixels(30)
  if suit.Label("Stats", {}, five, self.y+winHeight-labelHeight).hit then
    self.innerContent = 'stats'
  end

  -- Draw builds button
  if suit.Label("Builds", {}, self.width-love.window.toPixels(100), self.y+winHeight-labelHeight).hit then
    self.innerContent = 'builds'
  end
end

function panel:updateStatText(character)
  -- Update base stats
  charStatText:set(string.format('%i\n%i\n%i', character.str, character.int, character.dex))

  -- Update general stats
  local _labels = {}
  local _stats = {}
  local text
  for desc, n in pairs(character.stats) do
    if n > 0 then
      local width, wrapped = font:getWrap(desc, love.window.toPixels(270))
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

    local _desc = {}
    for _, line in ipairs(descriptions) do
      local width, wrapped = font:getWrap(line, love.window.toPixels(270))
      for _, wrappedLine in ipairs(wrapped) do
        _desc[#_desc+1] = wrappedLine
      end
    end

    label:set(nodes[nid].name)
    desc:set(table.concat(_desc, '\n'))
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
    self.statText.minY = diff
  end
end

function panel:mousepressed(x, y)
  self.mouseOnToggle = self:isMouseOverToggleButton(x, y)
  self.scrolling = self:isMouseInStatSection(x, y) and not self.mouseOnToggle
end

function panel:mousemoved(x, y, dx, dy)
  if not self:isActive() then
    return false
  elseif self.scrolling then
    self:scrolltext(dy)
    return true
  elseif self.mouseOnToggle then
    return true
  else
    return false
  end
end

function panel:containsMouse(x, y)
  if x == nil or y == nil then
    x, y = love.mouse.getPosition()
  end
  return self:isActive() and x < self.width
end

function panel:isMouseInStatSection(x, y)
  if x == nil or y == nil then
    x, y = love.mouse.getPosition()
  end
  return x < self.width and y > love.window.toPixels(125)
end

function panel:isMouseOverToggleButton(x, y)
  love.graphics.draw(leftIcon, self.x+love.window.toPixels(295)-love.window.toPixels(w), (winHeight-love.window.toPixels(h))/2, 0, love.window.getPixelScale(), love.window.getPixelScale())
  local w, h = leftIcon:getDimensions()
  w, h = love.window.toPixels(w), love.window.toPixels(h)

  local x1 = (self.width-h)/2

  local x1 = (self.width-h)/2
  local x2 = (self.width+h)/2
  local y2 = self.y+winHeight-love.window.toPixels(10)
  local y1 = y2-w

  return x > x1 and x < x2 and y > y1 and y < y2
end

function panel:scrolltext(dy)
  self.statText:yadj(dy)
end

function panel:click(x, y)
  -- Check if menu close button was pushed
  if self.mouseOnToggle and self:isMouseOverToggleButton(x, y) then
    self:toggle()
    return true
  end

  -- Need to return t/f for constintency with other GUI elements
  -- Lets the GUI layer processor know whether or not to continue checking elements
  self.mouseAttached = false
  return self:containsMouse(x, y)
end

function panel:setBuilds(builds)
  self.builds = builds
end

function panel:initIcons()
  local editsheet = love.graphics.newImage('icons/edit-button.png')
  local w, h = editsheet:getDimensions()
  self.icons = {
    edit = {
      sheet = editsheet,
      options = {
        id = 'edit-button',
        normal = love.graphics.newQuad(0, 0, 32, 32, w, h),
        active = love.graphics.newQuad(32, 0, 32, 32, w, h),
        hovered = love.graphics.newQuad(64, 0, 32, 32, w, h),
      }
    }
  }

  local deletesheet = love.graphics.newImage('icons/delete-button.png')
  w,h = deletesheet:getDimensions()
  self.icons.delete = {
    sheet = deletesheet,
    options = {
      id = 'delete-button',
      normal = love.graphics.newQuad(0, 0, 32, 32, w, h),
      active = love.graphics.newQuad(64, 0, 32, 32, w, h),
      hovered = love.graphics.newQuad(32, 0, 32, 32, w, h),
    }
  }
end

return panel
