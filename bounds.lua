--
-- bounds
--
-- stereo delay/looper with
-- probablistic kinetic sequencer
--
-- k1 = shift
-- k2 = add ball
-- k3 = change selected ball
-- shift + k2 = remove ball
-- shift + k3 = hold buffer
--
-- e2 = rotate ball
-- e3 = ball speed
-- shift + e1 = probability -
--      for the selected ball
-- shift + e2-3 = feedback l/r
--
-- there are many parameters
-- to play with, and 4 LFO's 
--
-- many thanks to @enneff
-- for making rebound, and
-- @zebra for softcut.
--
-- v0.2 @justmat
-- https://llllllll.co/t/23336

local sc = include("lib/tlps_bounds")
sc.file_path = "/home/we/dust/audio/tape/bounds."

local lfo = include("otis/lib/hnds")

-- for lib hnds
local lfo_targets ={
  "none",
  "1vol",
  "2vol",
  "1feedback",
  "2feedback"
}

local balls = {}
local cur_ball = 0
local current_spd = {1, 1}
local spds = {.5, 1}
local shift = false
local buffer_hold = false
local start_time = 0


local function set_hold()
  -- softcut rec on/off based on buffer_hold
  for i = 1, 2 do
    softcut.rec(i, buffer_hold and 0 or 1)
  end
end


local function skip(n)
  if math.random() <= .25 then
    softcut.position(n, 0)
  end
end


local function flip(n)
  -- flip tape direction
  local spd = current_spd[n]
  spd = -spd
  softcut.rate(n, spd)
  current_spd[n] = spd
end
  

local function set_spd(n)
  local rand = math.random(2)
  local speed = params:get(n .. "speed") * spds[rand]
  if params:get(n .. "speed") < 0 then
    speed = -speed
  end
  softcut.rate(n, speed)
  current_spd[n] = speed
end


function lfo.process()
  -- for lib hnds
  for i = 1, 4 do
    local target = params:get(i .. "lfo_target")

    if params:get(i .. "lfo") == 2 then
      -- left/right volume and feedback.
      params:set(lfo_targets[target], lfo.scale(lfo[i].slope, -1.0, 1.0, params:get(i .. "lfo_min"), params:get(i .. "lfo_max")) * 0.01)
    end
  end
end


function init()
  start_time = util.time()
  -- set up tlps/softcut
  sc.init()
  -- set hnds/lfos
  for i = 1, 4 do
    lfo[i].lfo_targets = lfo_targets
  end
  lfo.init()

  screen.aa(1)
  -- ball control
  local u = metro.init()
  u.time = 1/60
  u.count = -1
  u.event = update
  u:start()

  softcut.buffer_clear()
  params:bang()
end


function update()
  for i=1,#balls do
    updateball(balls[i])
  end
  redraw()
end


function enc(n, d)
  if n == 1 and shift and cur_ball > 0 then
    -- probability
    balls[cur_ball].prob = util.clamp(balls[cur_ball].prob + d, 0, 100)
  elseif n == 2 then
    -- feedback left
    if shift then
      params:delta("1feedback", d)
    else
      -- rotate
      for i=1,#balls do
        if i == cur_ball then
          balls[i].a = balls[i].a - d / 10
        end
      end
    end
  elseif n == 3 then
    -- feedback right
    if shift then
      params:delta("2feedback", d)
    else
      -- accelerate
      for i=1,#balls do
        if i == cur_ball then
          balls[i].v = balls[i].v + d / 10
        end
      end
    end
  end
end


function key(n, z)
  -- shift
  if n == 1 then shift = z == 1 end

  if shift then
    if n == 2 and z == 1 then
      table.remove(balls, cur_ball)
      if cur_ball > #balls then
        cur_ball = #balls
      end
    elseif n == 3 and z == 1 then
      buffer_hold = not buffer_hold
      set_hold()
    end
  else
    if n == 2 and z == 1 then
      -- add ball
      table.insert(balls, newball())
      cur_ball = #balls
    elseif n == 3 and z == 1 and #balls > 0 then
      -- select next ball
      cur_ball = cur_ball % #balls + 1
    end
  end
end


function newball()
  return {
    x = 64,
    y = 32,
    v = 0.5*math.random()+0.2,
    a =  math.random()*2*math.pi,
    prob = 100
  }
end


function drawball(b, hilite)
  screen.level(hilite and 15 or 5)
  screen.circle(b.x, b.y, hilite and 2 or 1.5)
  screen.fill()
end


function updateball(b)
  b.x = b.x + math.sin(b.a)*b.v
  b.y = b.y + math.cos(b.a)*b.v

  local minx = 2
  local miny = 2
  local maxx = 126
  local maxy = 62
  if b.x >= maxx then
    b.x = maxx
    b.a = 2*math.pi - b.a
    if b.y >= maxy / 2 then
      if math.random(100) <= b.prob then
        flip(2)
      end
    else
      if math.random(100) <= b.prob then
        set_spd(2)
      end
    end
  elseif b.x <= minx then
    b.x = minx
    b.a = 2*math.pi - b.a
    if b.y >= maxy / 2 then
      if math.random(100) <= b.prob then
        flip(1)
      end
    else
      if math.random(100) <= b.prob then
        set_spd(1)
      end
    end
  elseif b.y >= maxy then
    b.y = maxy
    b.a = math.pi - b.a

  elseif b.y <= miny then
    b.y = miny
    b.a = math.pi - b.a
    if b.x <= maxx / 2 and math.random(100) <= b.prob then
      skip(1)
    else
      skip(2)
    end
  end
end


function redraw()
  screen.clear()
  if util.time() - start_time < 2 then
    screen.font_size(32)
    screen.level(4)
    screen.move(64, 42)
    screen.text_center("bounds")
  end
  if shift then
    -- draw bounds
    screen.level(4)
    screen.line_width(1)
    screen.rect(1, 1, 126, 62)
    screen.stroke()
    -- draw loop info
    screen.level(1)
    screen.move(8, 30)
    screen.font_size(8)
    screen.text("spd: ")
    screen.move(40, 30)
    screen.text( "L : ".. current_spd[1])
    screen.move(8, 40)
    screen.text("fbk: ")
    screen.move(40, 40)
    screen.text("L : " .. params:get("1feedback"))
    screen.move(88, 30)
    screen.text("R : " .. current_spd[2])
    screen.move(88, 40)
    screen.text("R : " .. params:get("2feedback"))
    screen.move(64, 16)
    if #balls > 0 then
      screen.text_center("ball ".. cur_ball .. " prob : " .. balls[cur_ball].prob .. "%")
    else
      screen.text_center("ball - prob :  -")
    end
    screen.move(64, 52)
    screen.text_center(buffer_hold and "held" or "recording...")
  end
  for i=1,#balls do
    drawball(balls[i], i == cur_ball)
  end
  screen.update()
end
