--
--  rebound as softcut
--                  controller
--              yay!
--
--
--  docs to follow
-- v0.1

local sc = include("otis/lib/tlps")
local lfo = include("otis/lib/hnds")

-- for lib hnds
local lfo_targets ={
  "none",
  "1vol",
  "2vol",
  "1pan",
  "2pan",
  "1feedback",
  "2feedback"
}


local balls = {}
local cur_ball = 0

local spds = {.5, 1}

local shift = false
local rec1 = true
local rec2 = true


local function skip(n)
  if math.random() <= .25 then
    softcut.position(n, 0)
  end
end


local function flip(n)
  -- flip tape direction
  local spd = params:get(n .. "speed")
  spd = -spd
  params:set(n .. "speed", spd)
end


local function set_rec()
  if rec1 then
    softcut.rec(1, 0)
  else softcut.rec(1, 1) end
  
  if rec2 then
    softcut.rec(2, 0)
  else softcut.rec(2, 1) end
end
  

local function set_spd(n)
  local rand = math.random(2)
  local speed = spds[rand]
  if params:get(n .. "speed") < 0 then
    speed = -speed
  end
  params:set(n .. "speed", speed)
end


function lfo.process()
  -- for lib hnds
  for i = 1, 4 do
    local target = params:get(i .. "lfo_target")

    if params:get(i .. "lfo") == 2 then
      -- left/right volume, panning, and feedback.
      params:set(lfo_targets[target], lfo.scale(lfo[i].slope, -1.0, 1.0, params:get(i .. "lfo_min"), params:get(i .. "lfo_max")) * 0.01)
    end
  end
end


function init()
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
  if n == 1 then
    -- shift
    shift = z == 1
  elseif n == 2 and z == 1 then
    if shift then
      -- remove ball
      table.remove(balls, cur_ball)
      if cur_ball > #balls then
        cur_ball = #balls
      end
    else
      -- add ball
      table.insert(balls, newball())
      cur_ball = #balls
    end
  elseif n == 3 and z == 1 and #balls > 0 then
    -- select next ball
    cur_ball = cur_ball % #balls + 1
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
  if shift then
    screen.level(5)
    screen.line_width(1)
    screen.rect(1, 1, 126, 62)
    screen.stroke()
    
    screen.move(64, 16)
    if #balls > 0 then
      screen.text_center("prob : " .. balls[cur_ball].prob .. "%")
    else
      screen.text_center("prob :  -")
    end
    screen.move(64, 32)
    screen.text_center("fdbk L : " .. params:get("1feedback"))
    screen.move(64, 48)
    screen.text_center("fdbk R : " .. params:get("2feedback"))
  end
  for i=1,#balls do
    drawball(balls[i], i == cur_ball)
  end
  screen.update()
end
