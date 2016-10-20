-- This file is part of SUIT, copyright (c) 2016 Matthias Richter

local BASE = (...):match('(.-)[^%.]+$')

return function(core, image, ...)
	local opt,x,y,rot,sx,sy = core.getOptionsAndSize(...)
  img = image
	opt.normal = opt.normal or opt[1]
	opt.hovered = opt.hovered or opt[2] or opt.normal
	opt.active = opt.active or opt[3] or opt.hovered
  rot = rot or 0
  sx = sx or 1.0
  sy = sy or 1.0
	assert(opt.normal, "Need at least `normal' state image")
	opt.id = opt.id or image

	opt.state = core:registerMouseHit(opt.id, x,y, function(u,v)
    local quad = opt.normal
    assert(quad:typeOf('Quad'), 'Uh opt.normal should be a Quad')
    u, v = math.floor(u+0.5), math.floor(v+0.5)
    qx, qy, w, h = quad:getViewport()
    return u > 0 and u < w*sx and v > 0 and v < h*sy
	end)

  local quad = opt.normal
	if core:isActive(opt.id) then
		quad = opt.active
	elseif core:isHovered(opt.id) then
		quad = opt.hovered
	end

	core:registerDraw(opt.draw or function(img,quad,x,y, r,g,b,a)
		love.graphics.setColor(r,g,b,a)
		love.graphics.draw(img,quad,x,y,rot,sx,sy)
	end, img,quad,x,y, love.graphics.getColor())

	return {
		id = opt.id,
		hit = core:mouseReleasedOn(opt.id),
		hovered = core:isHovered(opt.id),
		entered = core:isHovered(opt.id) and not core:wasHovered(opt.id),
		left = not core:isHovered(opt.id) and core:wasHovered(opt.id)
	}
end
