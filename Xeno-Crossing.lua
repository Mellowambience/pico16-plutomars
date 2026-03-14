-- XENO-CROSSING: PLUTOMARS COLONY
-- THE MASTER CARTRIDGE

-- CORE STATE
local p = {
    x=40, y=120, 
    tx=40, ty=120, 
    spd=0.08, 
    lv_scav=1, lv_husb=1, lv_synth=1,
    xp_scav=0,
    moving=false
}

local nodes = {}
local particles = {}

function _init()
    -- Generate Martian Map with OSRS-style Resource Nodes
    for i=1,10 do
        add(nodes, {
            x=30+flr(rnd(150)), 
            y=20+flr(rnd(200)), 
            type=flr(rnd(3)), 
            respawn=0
        })
    end
end

function _update()
    -- 1. POINT-AND-CLICK LOGIC
    local mx, my = stat(32), stat(33)
    if btnp(4) then -- Left Click
        if mx < 240 then -- Clicked World
            p.tx = mx
            p.ty = my
            p.moving = true
            spawn_click_effect(mx, my)
        end
    end

    -- 2. MOVEMENT ENGINE
    if p.moving then
        p.x = lerp(p.x, p.tx, p.spd)
        p.y = lerp(p.y, p.ty, p.spd)
        if abs(p.x - p.tx) < 2 and abs(p.y - p.ty) < 2 then 
            p.x = p.tx
            p.y = p.ty
            p.moving = false 
            check_interactions()
        end
    end

    -- 3. PARTICLES
    update_particles()
end

function _draw()
    cls(0) -- Deep Space
    
    -- Mars Ground
    rectfill(0,0,240,240,1) 

    -- Draw Nodes
    for n in all(nodes) do
        local col = 5
        if n.type == 0 then col = 10 end -- Gold/Metal
        if n.type == 1 then col = 12 end -- Aether
        rectfill(n.x-2, n.y-2, n.x+2, n.y+2, col)
    end
    
    -- Draw Player & AetherCell
    spr(1, p.x-4, p.y-4, 1, 1)
    -- Companion hovers
    local hx = p.x + 10 + sin(t()*2)*4
    local hy = p.y - 10 + sin(t()*3)*2
    spr(16, hx-4, hy-4, 1, 1) 

    -- Draw Particles
    for part in all(particles) do
        rectfill(part.x, part.y, part.x+1, part.y+1, part.col)
    end

    -- OSRS Sidebar UI
    rectfill(240, 0, 320, 240, 0) -- Sidebar BG
    rectfill(241, 0, 242, 240, 5) -- Border
    
    print("PLUTOMARS COLONY", 245, 10, 1)
    print("----------------", 245, 18, 5)
    
    print("SCAV LVL: "..p.lv_scav, 245, 30, 7)
    print("PROGRESS: "..p.xp_scav.."%", 245, 38, 5)
    
    print("HUSB LVL: "..p.lv_husb, 245, 50, 11)
    print("SYNTH LVL: "..p.lv_synth, 245, 60, 12)
    
    print("MOUSE: "..flr(stat(32))..","..flr(stat(33)), 245, 220, 5)
end

-- UTILS
function rnd(n) return (t()*1000 % 1000) / 1000 * n end

function add(t, v) t[#t+1] = v end

function all(t)
    local i = 0
    return function()
        i = i + 1
        if i <= #t then return t[i] end
    end
end

function spawn_click_effect(x, y)
    for i=1,5 do
        add(particles, {x=x, y=y, dx=rnd(2)-1, dy=rnd(2)-1, life=10, col=13})
    end
end

function update_particles()
    for i=#particles, 1, -1 do
        local part = particles[i]
        part.x = part.x + part.dx
        part.y = part.y + part.dy
        part.life = part.life - 1
        if part.life <= 0 then table.remove(particles, i) end
    end
end

function check_interactions()
    for n in all(nodes) do
        if abs(p.x - n.x) < 5 and abs(p.y - n.y) < 5 then
            p.xp_scav = p.xp_scav + 10
            if p.xp_scav >= 100 then
                p.xp_scav = 0
                p.lv_scav = p.lv_scav + 1
            end
            -- Reset node position
            n.x = 30 + flr(rnd(150))
            n.y = 20 + flr(rnd(200))
        end
    end
end
