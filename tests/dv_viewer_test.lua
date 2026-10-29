-- Run from the root of a gen1recomp checkout (ROM-free, fixture data):
--   luajit <path to this mod>/tests/dv_viewer_test.lua
package.path = "./?.lua;./?/init.lua;" .. package.path

-- the mod is loaded from wherever this file sits, so the suite works the same
-- from a clone of this repo, the save folder's mods/ or a checkout's
local here = debug.getinfo(1, "S").source:gsub("^@", ""):gsub("\\", "/")
local root, folder = here:match("^(.*)/([^/]+)/tests/[^/]+$")

local T = require("tests.modkit")
local data = T.fixtures.fresh()
local run = T.sdk.loadMod(folder, { data = data, root = root })
T.eq(#run.errors, 0, "loads clean (" .. tostring(run.errors[1]) .. ")")

local dv = run.loader.exports.dv_viewer or {}

-- ------- the grade

local function dvs(atk, def, spd, spc)
  return { attack = atk, defense = def, speed = spd, special = spc }
end

T.check(type(dv.rate) == "function", "rate is exported")
if type(dv.rate) == "function" then
  T.eq(dv.rate(dvs(15, 15, 15, 15)).total, 60, "the total is the four stored DVs")
  T.eq(dv.rate(dvs(15, 15, 15, 15)).grade, "GREAT", "a perfect mon is GREAT")
  T.eq(dv.rate(dvs(12, 12, 12, 9)).grade, "GREAT", "45 is the GREAT floor")
  T.eq(dv.rate(dvs(11, 11, 11, 11)).grade, "GOOD", "44 is GOOD")
  T.eq(dv.rate(dvs(10, 10, 10, 10)).grade, "GOOD", "40 is the GOOD floor")
  T.eq(dv.rate(dvs(10, 10, 10, 9)).grade, "OK", "39 is OK")
  T.eq(dv.rate(dvs(7, 6, 6, 6)).grade, "OK", "25 is the OK floor")
  T.eq(dv.rate(dvs(6, 6, 6, 6)).grade, "POOR", "24 is POOR")
  T.eq(dv.rate(dvs(0, 0, 0, 0)).grade, "POOR", "zero is POOR")
  local withHp = dvs(15, 15, 15, 15)
  withHp.hp = 15
  T.eq(dv.rate(withHp).total, 60, "the HP DV is not counted twice")
  T.eq(dv.rate(nil), nil, "a mon without DVs has no grade")
end

T.check(type(dv.hpDV) == "function", "hpDV is exported")
if type(dv.hpDV) == "function" then
  T.eq(dv.hpDV(dvs(1, 1, 0, 1)), 13, "a missing HP DV comes from the low bits")
  local stored = dvs(0, 0, 0, 0)
  stored.hp = 15
  T.eq(dv.hpDV(stored), 15, "a stored HP DV is the one the stat formula reads")
end

-- ------- the STATS screen gains a third page

local Font = require("src.render.Font")
Font.load(data)
local SummaryMenu = require("src.ui.SummaryMenu")

local pressed = {}
local game = {
  data = data,
  save = { player = { name = "RED", id = 12345 } },
  input = { wasPressed = function(_, key) return pressed[key] == true end },
  stack = { push = function() end, pop = function() end },
}

local function makeMon()
  local mon = {
    species = T.fixtures.ids.species[1], level = 20, exp = 8000,
    dvs = { attack = 15, defense = 12, speed = 10, special = 8 },
    statExp = { hp = 1234, attack = 65535, defense = 0, speed = 300, special = 7 },
    moves = {}, status = nil,
  }
  require("src.pokemon.Stats").ensure(data.pokemon[mon.species], mon)
  mon.hp = mon.stats.hp
  return mon
end

-- the opening white flash eats input until it ends, as in the cart
local function settle(menu)
  for _ = 1, 120 do
    if not menu.whiteHold or menu.whiteHold <= 0 then return end
    menu:update(1 / 60)
  end
end

local function press(menu, key)
  pressed[key] = true
  menu:update(1 / 60)
  pressed[key] = false
end

local function drawnText(menu)
  local drawn = {}
  local stock = Font.draw
  Font.draw = function(text, x, y)
    drawn[#drawn + 1] = tostring(text)
    return stock(text, x, y)
  end
  local ok, err = pcall(menu.draw, menu)
  Font.draw = stock
  T.check(ok, "the page draws without error (" .. tostring(err) .. ")")
  return table.concat(drawn, "|")
end

local menu = SummaryMenu.new(game, makeMon())
settle(menu)
T.eq(menu.page, 1, "the screen opens on the stats page")
press(menu, "a")
T.eq(menu.page, 2, "A still flips to the moves page")
press(menu, "a")
T.eq(menu.page, 3, "A on the moves page opens the DV page instead of closing")
T.check(not menu.closing, "the screen stays open on the DV page")
press(menu, "a")
T.check(menu.closing, "A on the DV page closes the screen")

local viaB = SummaryMenu.new(game, makeMon())
settle(viaB)
press(viaB, "b")
press(viaB, "b")
T.eq(viaB.page, 3, "B reaches the DV page the same way A does")

local page3 = SummaryMenu.new(game, makeMon())
settle(page3)
page3.page = 3
local text = drawnText(page3)
T.check(text:find("STAT EXP", 1, true), "the DV page labels its Stat Exp column")
T.check(text:find("45/60", 1, true), "the DV page shows the total out of 60")
T.check(text:find("GREAT", 1, true), "the DV page shows the grade")
T.check(text:find("65535", 1, true), "a full Stat Exp value fits")
T.check(text:find("1234", 1, true), "the HP Stat Exp is shown")
T.check(not text:find("EXP POINTS", 1, true), "the moves page is not drawn under it")

local page1 = SummaryMenu.new(game, makeMon())
settle(page1)
T.check(not drawnText(page1):find("STAT EXP", 1, true),
  "the vanilla stats page is left alone")

local noDVs = makeMon()
noDVs.dvs = nil
local bare = SummaryMenu.new(game, noDVs)
settle(bare)
bare.page = 3
T.check(not drawnText(bare):find("/60", 1, true),
  "a mon with no DVs draws no grade rather than a made-up one")

-- ------- a catch opens the DV page

local Runtime = require("src.mods.Runtime")
local queued = {}
local battle = { game = game }
function battle:uiNext(factory) queued[#queued + 1] = factory end

local function catch(destination)
  Runtime.emit("pokemon.caught", {
    battle = battle, mon = makeMon(), species = T.fixtures.ids.species[1],
    isNew = true, destination = destination, game = game,
  })
end

catch("party")
T.eq(#queued, 1, "a catch into the party queues one screen after the catch text")
local caughtScreen = queued[1] and queued[1]()
T.eq(caughtScreen and caughtScreen.page, 3, "the queued screen opens on the DV page")
if caughtScreen then
  settle(caughtScreen)
  press(caughtScreen, "a")
  T.check(caughtScreen.closing, "one A closes it and the battle carries on")
end

catch("box")
T.eq(#queued, 2, "a catch sent to a PC box opens the DV page too")

catch("mod")
T.eq(#queued, 2, "a mon another mod took custody of opens nothing")

run.release()
T.finish("dv_viewer")
