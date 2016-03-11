return {
  id         = 'stats',
  width      = 300,
  height     = 768,
  left       = 0,
  top        = 0,
  wrap       = true,
  background = {1, 1, 1, 240},
  outline    = {255, 255, 255, 255},
  font       = 'fonts/fontin-bold-webfont.ttf',
  size       = 20,
  color = {240, 240, 240},
  {
    id     = 'portraitContainer',
    align  = 'top',
    height = 'auto',
    width  = 'auto',
    flow   = 'x',
    {
      id     = 'portrait',
      margin = 5,
      width  = 120,
      height = 115,
      icon   = 'assets/scion-portrait.png',
    },
    {
      id         = 'baseStats',
      margin     = 5,
      text       = 'B-B-B-B-Base attributes',
      width      = 170,
      height     = 115,
      -- background = {0, 255, 255},
      size       = 15,
      {
        id = 'baseStatsStr',
        text = ''
      }
    }
  },
  {
    id = 'sep1',
    height = 20,
    margin = 5,
    icon = 'assets/LineConnectorNormal.png',
  },
  {
    id = 'keystones',
    text = '- Keystone 1\n- Keystone 2\n- Keystone 3',
    size = 20,
    margin = 5,
    -- background = {255, 0, 255},
  }
}
