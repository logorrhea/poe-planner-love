local toggle = {
  x = 10,
  y = 20,
  name = 'Menu Toggle',
  status = 'active',
}

function toggle:init(target)
  self.target = target

  local menu = love.graphics.newImage('icons/menu.png')
  w, h = menu:getDimensions()
  self.icon = {
    sheet = menu,
    options = {
      id = 'search-menu',
      normal = love.graphics.newQuad(0, 0, w/3, w/3, w, h),
      active = love.graphics.newQuad(w*2/3, 0, w/3, w/3, w, h),
      hovered = love.graphics.newQuad(w/3, 0, w/3, w/3, w, h),
    }
  }
end

function toggle:click(mx, my)
  -- stub
end

function toggle:draw()
  if not self.target:isActive() then
    local _, _, w, h = self.icon.options.normal:getViewport()
    w, h = love.window.toPixels(w, h)
    local x, y = love.window.toPixels(self.x, self.y)
    if suit.SpritesheetButton(self.icon.sheet,
                              self.icon.options,
                              x,
                              y,
                              0,
                              love.window.getPixelScale(),
                              love.window.getPixelScale()
                             ).hit then
      self.target:toggle()
    end
  end
end

function toggle:isActive()
  return self.status == 'active'
end

function toggle:isExclusive()
  return false
end

function toggle:toggle()
  if self.state == 'active' then
    self.state = 'inactive'
  else
    self.state = 'active'
  end
end

function toggle:activate()
  self.state = 'active'
end

function toggle:deactivate()
  self.state = 'inactive'
end


return toggle
