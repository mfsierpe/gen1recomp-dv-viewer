-- DV Viewer: a third STATS page with each DV and Stat Exp, graded, and that
-- page opened right after every catch.

-- the grade's floors over the four stored DVs (0-60); a wild mon rolls
-- GREAT about 1 in 17, GOOD 1 in 10, OK half the time, POOR 1 in 4
local GRADES = {
  { floor = 45, label = "GREAT" },
  { floor = 40, label = "GOOD" },
  { floor = 25, label = "OK" },
  { floor = 0, label = "POOR" },
}

-- Gen 1 stores no HP DV: it is the low bit of each other DV, ATK first
-- (Stats.randomDVs).  A stored one wins because that is what Stats.calc reads.
local function hpDV(dvs)
  if type(dvs.hp) == "number" then return dvs.hp end
  return ((dvs.attack or 0) % 2) * 8 + ((dvs.defense or 0) % 2) * 4
       + ((dvs.speed or 0) % 2) * 2 + ((dvs.special or 0) % 2)
end

-- HP is left out of the total: it is derived from the other four, so
-- counting it would weigh their low bits twice
local function rate(dvs)
  if type(dvs) ~= "table" then return nil end
  local total = (dvs.attack or 0) + (dvs.defense or 0)
              + (dvs.speed or 0) + (dvs.special or 0)
  for _, g in ipairs(GRADES) do
    if total >= g.floor then return { total = total, grade = g.label } end
  end
end

local ROWS = {
  { "HP", "hp" }, { "ATK", "attack" }, { "DEF", "defense" },
  { "SPD", "speed" }, { "SPC", "special" },
}

-- a 7x7 star marks a perfect 15; the Gen 1 font has no glyph for one
local STAR = {
  "...#...",
  "..###..",
  "#######",
  ".#####.",
  "..###..",
  ".##.##.",
  "##...##",
}

local function drawStar(x, y)
  for row, line in ipairs(STAR) do
    for col = 1, #line do
      if line:sub(col, col) == "#" then
        love.graphics.rectangle("fill", x + col - 1, y + row - 1, 1, 1)
      end
    end
  end
end

return function(mod)
  local Font = require("src.render.Font")
  local HudTiles = require("src.render.HudTiles")
  local PaletteFX = require("src.render.PaletteFX")
  local SummaryMenu = require("src.ui.SummaryMenu")

  mod.exports.rate = rate
  mod.exports.hpDV = hpDV

  -- SummaryMenu's own DrawLineBox, which is local to it
  local function drawLineBox(tx, ty, b, c)
    for i = 0, b - 1 do HudTiles.statusTile(0x78, tx * 8, (ty + i) * 8) end
    HudTiles.statusTile(0x77, tx * 8, (ty + b) * 8)
    for i = 1, c do HudTiles.statusTile(0x76, (tx - i) * 8, (ty + b) * 8) end
    HudTiles.statusTile(0x6F, (tx - c - 1) * 8, (ty + b) * 8)
  end

  -- right-aligned so it ends against the line box at column 19
  local function drawRight(text, y)
    Font.draw(text, 152 - #text * 8, y)
  end

  -- page 3: the header pages 1 and 2 share, then the DV table
  local function drawDVPage(menu)
    local mon, data = menu.mon, menu.game.data
    local def = data.pokemon[mon.species]
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle("fill", 0, 0, 160, 144)
    if menu.sprite then
      local pw, ph = menu.sprite:getDimensions()
      local py = math.max(0, 56 - ph)
      local px = 8 + math.max(0, 56 - math.floor((8 - pw / 8) / 2) * 8 - pw)
      love.graphics.draw(menu.sprite, px + pw, py, 0, -1, 1)
      if menu.spriteTrueColor then PaletteFX.markTrueColor(px, py, pw, ph) end
    end
    love.graphics.setColor(0, 0, 0, 1)
    Font.draw(mon.nickname or def.name, 72, 8)
    HudTiles.statusTile(0x74, 8, 56)  -- №
    Font.drawCode(0xF2, 16, 56)       -- <DOT>
    Font.draw(("%03d"):format(def.dex or 0), 24, 56)

    drawLineBox(19, 1, 6, 10)
    local rating = rate(mon.dvs)
    if rating then
      Font.draw("DV TOTAL", 72, 24)
      drawRight(("%d/60"):format(rating.total), 32)
      drawRight(rating.grade, 48)
    end

    Font.drawBox(0, 8, 20, 10)
    Font.draw("DV", 48, 72)
    Font.draw("STAT EXP", 80, 72)
    local statExp = mon.statExp or {}
    for i, row in ipairs(ROWS) do
      local y = 80 + i * 8
      Font.draw(row[1], 8, y)
      local value
      if type(mon.dvs) == "table" then
        value = row[2] == "hp" and hpDV(mon.dvs) or (mon.dvs[row[2]] or 0)
      end
      Font.draw(value and ("%2d"):format(value) or "--", 48, y)
      if value == 15 then drawStar(65, y) end
      Font.draw(("%5d"):format(statExp[row[2]] or 0), 104, y)
    end

    love.graphics.setColor(1, 1, 1, 1)
    if menu.whiteHold and menu.whiteHold > 0 then
      love.graphics.rectangle("fill", 0, 0, 160, 144)
    end
  end

  -- A or B on the moves page goes on to the DV page; the stock update closes
  -- from any page past 1, so the DV page closes the screen as page 2 did
  local stockUpdate = SummaryMenu.update
  function SummaryMenu:update(dt)
    if self.page == 2 and not self.closing
       and (not self.whiteHold or self.whiteHold <= 0) then
      local input = self.game.input
      if input:wasPressed("a") or input:wasPressed("b") then
        self.page = 3
        return
      end
    end
    return stockUpdate(self, dt)
  end

  local stockDraw = SummaryMenu.draw
  function SummaryMenu:draw(...)
    if self.page == 3 then return drawDVPage(self) end
    return stockDraw(self, ...)
  end

  -- The battle has already queued the catch text, the dex page and the
  -- nickname question when this fires, so uiNext lands the DV page after
  -- them, with the nickname set.  A mon another mod took custody of
  -- (destination "mod") is that mod's to present.
  mod.events:on("pokemon.caught", function(ev)
    if not ev or (ev.destination ~= "party" and ev.destination ~= "box") then return end
    local battle, mon = ev.battle, ev.mon
    if not (battle and battle.uiNext and mon) then return end
    battle:uiNext(function()
      local menu = SummaryMenu.new(battle.game or ev.game, mon)
      menu.page = 3
      return menu
    end)
  end)
end
