-- XENO-CROSSING: PLUTOMARS WAR COLONY
-- THE CRIMSON CRADLE: WAR PROTOCOL

-- CORE STATE
local g = {
    prog = 25,
    won = false,
    cam_x = 0, cam_y = 0,
    selected = nil,
    wave = 1,
    enemy_timer = 0,
    aether_timer = 300,
    lv_scav=3, lv_husb=3, lv_synth=3
}

local units = {}
local enemies = {}
local outposts = {}
local particles = {}
local veins = {}
local bullets = {}
local craters = {}

-- SPRITE REFS: Nomad=1, Seed=2, Wraith=3, Devil=4, Cursor=5, Base=6

function _init()
    -- Initialize Units
    add(units, {id=1, x=160, y=120, tx=160, ty=120, hp=100, type="scav", spr=1, name="NOMAD PRIME"})
    add(units, {id=2, x=140, y=100, tx=140, ty=100, hp=100, type="husb", spr=2, name="ANCHOR SEED"})
    add(units, {id=3, x=180, y=140, tx=180, ty=140, hp=100, type="synth", spr=3, name="WRAITH ORACLE"})
    
    -- Spawn initial enemies
    spawn_enemy()
    spawn_enemy()
    
    -- Terrain noise (Craters)
    for i=1,15 do
        add(craters, {x=rnd(320), y=rnd(240), r=2+rnd(4)})
    end
end

function _update()
    if g.won then return end
    
    local mx, my = stat(32), stat(33)
    local mr = stat(34) -- Right Click
    
    -- 1. SELECTION & COMMAND
    if btnp(4) then -- Left Click
        g.selected = nil
        for u in all(units) do
            if abs(mx - u.x) < 8 and abs(my - u.y) < 8 then
                g.selected = u
            end
        end
    end
    
    if mr == 1 and g.selected then
        g.selected.tx = mx
        g.selected.ty = my
        spawn_p(mx, my, 13, 5) -- Command effect
    end
    
    -- 2. UNIT LOGIC
    for u in all(units) do
        -- Movement
        u.x = lerp(u.x, u.tx, 0.05)
        u.y = lerp(u.y, u.ty, 0.05)
        
        if abs(u.x - u.tx) > 1 then
            spawn_p(u.x, u.y, 5, 1) -- Dust
        end
        
        -- Special Behaviors
        if u.type == "scav" then
            if flr(t()*10) % 100 == 0 then
                add(outposts, {x=u.x, y=u.y})
                g.prog = g.prog + 2
                sfx("gather")
            end
        elseif u.type == "husb" then
            if abs(u.x - u.tx) < 2 and abs(u.y - u.ty) < 2 then
                if flr(t()*10) % 30 == 0 then
                    add(veins, {x1=u.x, y1=u.y, x2=u.x+rnd(20)-10, y2=u.y+rnd(20)-10})
                    g.prog = g.prog + 0.5
                    heal_nearby(u.x, u.y)
                end
            end
        elseif u.type == "synth" then
            -- Orbit Logic
            local orbit_target = g.selected or units[1]
            if orbit_target then
                local a = t() * 5
                u.tx = orbit_target.x + sin(a) * 15
                u.ty = orbit_target.y + cos(a) * 15
            end
            -- Auto-fire
            if flr(t()*20) % 10 == 0 then
                local target = find_nearest(u.x, u.y, enemies)
                if target then
                    add(bullets, {x=u.x, y=u.y, tx=target.x, ty=target.y, life=10})
                    target.hp = target.hp - 10
                    sfx("attack")
                end
            end
        end
        
        -- Death
        if u.hp <= 0 then u.hp = 0 end
    end
    
    -- 3. ENEMY LOGIC
    g.enemy_timer = g.enemy_timer + 1
    if g.enemy_timer > 1350 then -- ~45s
        spawn_enemy()
        g.enemy_timer = 0
        g.wave = g.wave + 1
    end
    
    for e in all(enemies) do
        local target = find_nearest(e.x, e.y, units)
        if target then
            e.x = lerp(e.x, target.x, 0.01)
            e.y = lerp(e.y, target.y, 0.01)
            if dist(e.x, e.y, target.x, target.y) < 8 then
                target.hp = target.hp - 0.5
                if flr(t()*10) % 10 == 0 then sfx("damage") end
            end
        end
        if e.hp <= 0 then del(enemies, e) g.prog = g.prog + 1 end
    end
    
    -- 4. CAMERA
    if g.selected then
        g.cam_x = lerp(g.cam_x, g.selected.x - 120, 0.1)
        g.cam_y = lerp(g.cam_y, g.selected.y - 120, 0.1)
    end
    
    -- 5. WIN CONDITION
    if g.prog >= 100 then g.prog = 100 g.won = true end
    
    update_p()
    update_bullets()
end

function _draw()
    cls(0)
    
    -- Parallax Background (Red Plains)
    local ox = g.cam_x * 0.2
    local oy = g.cam_y * 0.2
    rectfill(0,0,240,240,1)
    
    -- Craters
    for c in all(craters) do
        rectfill(c.x - ox, c.y - oy, c.x + c.r - ox, c.y + c.r - oy, 0)
    end
    
    -- Veins
    for v in all(veins) do
        line(v.x1 - g.cam_x, v.y1 - g.cam_y, v.x2 - g.cam_x, v.y2 - g.cam_y, 11)
    end
    
    -- Outposts
    for o in all(outposts) do
        spr(6, o.x - g.cam_x - 4, o.y - g.cam_y - 4)
    end
    
    -- Particles
    for p in all(particles) do
        rectfill(p.x - g.cam_x, p.y - g.cam_y, p.x - g.cam_x + 1, p.y - g.cam_y + 1, p.col)
    end
    
    -- Enemies
    for e in all(enemies) do
        spr(e.spr, e.x - g.cam_x - 4, e.y - g.cam_y - 4)
        draw_hp(e.x - g.cam_x, e.y - g.cam_y - 6, e.hp, 30)
    end
    
    -- Units
    for u in all(units) do
        spr(u.spr, u.x - g.cam_x - 4, u.y - g.cam_y - 4)
        draw_hp(u.x - g.cam_x, u.y - g.cam_y - 8, u.hp, 100)
        if g.selected == u then
            rectfill(u.x - g.cam_x - 5, u.y - g.cam_y + 5, u.x - g.cam_x + 5, u.y - g.cam_y + 6, 7)
        end
    end
    
    -- Bullets
    for b in all(bullets) do
        line(b.x - g.cam_x, b.y - g.cam_y, b.tx - g.cam_x, b.ty - g.cam_y, 13)
    end
    
    -- HUD
    rectfill(240, 0, 320, 240, 0)
    rectfill(241, 0, 242, 240, 5) -- Divider
    
    print("WAR PROGRESS", 245, 10, 8)
    rectfill(245, 20, 315, 25, 5)
    rectfill(245, 20, 245 + (g.prog * 0.7), 25, 11)
    
    print("SCAV LVL: "..g.lv_scav, 245, 40, 12)
    print("HUSB LVL: "..g.lv_husb, 245, 50, 7)
    print("SYNTH LVL: "..g.lv_synth, 245, 60, 13)
    
    string_w = #("WAVE "..g.wave) * 4
    print("WAVE "..g.wave, 245, 80, 10)
    
    if g.selected then
        print("SELECTED:", 245, 110, 5)
        print(g.selected.name, 245, 120, 7)
        print("HP: "..flr(g.selected.hp), 245, 130, 8)
    end
    
    -- Cursor
    spr(5, stat(32)-4, stat(33)-4)
    
    if g.won then
        rectfill(40, 100, 200, 140, 0)
        print("MARS CLAIMED", 65, 115, 11)
        print("VICTORY FOR THE GODDESS", 50, 125, 7)
    end
end

-- HELPERS
function spawn_enemy()
    add(enemies, {x=rnd(320), y=rnd(240), hp=30, spr=4})
end

function spawn_p(x, y, col, n)
    for i=1,n do
        add(particles, {x=x, y=y, dx=rnd(2)-1, dy=rnd(2)-1, col=col, life=15+rnd(10)})
    end
end

function update_p()
    for i=#particles,1,-1 do
        local p = particles[i]
        p.x = p.x + p.dx
        p.y = p.y + p.dy
        p.life = p.life - 1
        if p.life <= 0 then table.remove(particles, i) end
    end
end

function update_bullets()
    for i=#bullets,1,-1 do
        bullets[i].life = bullets[i].life - 1
        if bullets[i].life <= 0 then table.remove(bullets, i) end
    end
end

function draw_hp(x, y, val, max)
    rectfill(x-5, y, x+5, y+1, 0)
    rectfill(x-5, y, x-5 + (val/max)*10, y+1, 8)
end

function find_nearest(x, y, list)
    local near = nil
    local d_min = 9999
    for item in all(list) do
        local d = dist(x, y, item.x, item.y)
        if d < d_min then d_min = d near = item end
    end
    return near
end

function heal_nearby(x, y)
    for u in all(units) do
        if dist(x,y, u.x, u.y) < 30 then u.hp = u.hp + 0.1 if u.hp > 100 then u.hp = 100 end end
    end
end

function dist(x1, y1, x2, y2) return sqrt((x2-x1)^2 + (y2-y1)^2) end
function del(t, v) 
    for i, item in ipairs(t) do
        if item == v then table.remove(t, i) break end
    end
end
function all(t)
    local i = 0
    return function()
        i = i + 1
        if i <= #t then return t[i] end
    end
end
