local classes = {
  'scion',
  'marauder',
  'ranger',
  'witch',
  'duelist',
  'templar',
  'shadow',
}
local totalHeight = #classes * 110
local layout = {
  id    = 'statPicker',
  flow  = 'x',
  width = (#classes * 110),
  height = 105,
  top   = 300,
  left  = 300,
  background = {255, 255, 255},
  -- {
  --   id = 'scion',
  --   width = 110,
  --   height = 105,
  --   icon = 'assets/scion-portrait.png',
  -- }
}

for _, class in ipairs(classes) do
  layout[#layout+1] = {
    id     = class,
    width  = 110,
    height = 105,
    icon   = 'assets/'..class..'-portrait.png',
  }
end

return layout
