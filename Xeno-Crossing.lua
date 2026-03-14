-- XENO-CROSSING: PLUTOMARS COLONY
-- MASTER CARTRIDGE: THE CRIMSON CRADLE AWAKENING

-- CORE STATE
local p = {
    lv_scav=2, xp_scav=33,
    lv_husb=2, xp_husb=33,
    lv_synth=2, xp_synth=33
}

-- ENTITY DEFINITIONS
local scav_nomad = {x=120, y=120, tx=120, ty=120, spd=0.02}
local husb_anchor = {x=160, y=80, rooted=false, terra_timer=0}
local synth_wraith = {x=0, y=0, orbit_a=0, orbit_r=20}

local trails = {}
local bio_veins = {}
local craters = {}
local arcs = {}
local aether_timer = 200 -- Initial delay for first wind

function _init()
    -- Initial state established by the Goddess of War
end

function _update()
    local mx, my = stat(32), stat(33)
    local dt = t()
    
    -- 1. SCAV-NOMAD PRIME LOGIC
    if abs(scav_nomad.x - scav_nomad.tx) < 2 then
        scav_nomad.tx = 30 + rnd(180)
        scav_nomad.ty = 20 + rnd(200)
    end
    scav_nomad.x = lerp(scav_nomad.x, scav_nomad.tx, scav_nomad.spd)
    scav_nomad.y = lerp(scav_nomad.y, scav_nomad.ty, scav_nomad.spd)
    
    -- Leave white trail
    if flr(dt*10) % 5 == 0 then
        add(trails, {x=scav_nomad.x, y=scav_nomad.y, life=50})
        p.xp_scav = p.xp_scav + 0.1 -- Gradual drift (15% per "collection" simulated by logic below)
    end
    
    -- 2. HUSB-ANCHOR SEED LOGIC
    local dx = mx - husb_anchor.x
    local dy = my - husb_anchor.y
    if abs(dx) < 15 and abs(dy) < 15 then
        husb_anchor.rooted = true
        husb_anchor.terra_timer = husb_anchor.terra_timer + 1
        if husb_anchor.terra_timer % 60 == 0 then
            add(bio_veins, {x=husb_anchor.x, y=husb_anchor.y, tx=husb_anchor.x+rnd(40)-20, ty=husb_anchor.y+rnd(40)-20})
            p.xp_husb = p.xp_husb + 1
        end
    else
        husb_anchor.rooted = false
    end

    -- 3. SYNTH-WRAITH ORACLE LOGIC
    synth_wraith.orbit_a = synth_wraith.orbit_a + 0.1
    synth_wraith.x = mx + sin(synth_wraith.orbit_a) * synth_wraith.orbit_r
    synth_wraith.y = my + cos(synth_wraith.orbit_a) * synth_wraith.orbit_r
    
    -- Data Stream Sync (Energy Arcs)
    local boost = 1.0
    if dist(synth_wraith.x, synth_wraith.y, scav_nomad.x, scav_nomad.y) < 40 or
       dist(synth_wraith.x, synth_wraith.y, husb_anchor.x, husb_anchor.y) < 40 then
        boost = 1.1
        if flr(dt*20) % 2 == 0 then
            add(arcs, {x1=synth_wraith.x, y1=synth_wraith.y, x2=scav_nomad.x, y2=scav_nomad.y, life=3})
        end
    end
    
    -- Apply Global Pulse
    p.xp_scav = p.xp_scav + (0.01 * boost)
    p.xp_husb = p.xp_husb + (0.01 * boost)
    p.xp_synth = p.xp_synth + (0.01 * boost)
    
    -- 4. AETHER WINDS (Every 25-40 seconds)
    aether_timer = aether_timer - 1
    if aether_timer <= 0 then
        aether_timer = 750 + rnd(450) -- ~25-40s at 30fps baseline
        apply_aether_drift()
    end
    
    update_entities()
end

function _draw()
    cls(0)
    rectfill(0,0,240,240,1) -- Red Plains
    
    -- Draw Craters
    for c in all(craters) do
        rectfill(c.x-c.r, c.y-c.r, c.x+c.r, c.y+c.r, 10)
    end
    
    -- Draw Trails
    for t in all(trails) do rectfill(t.x, t.y, t.x+1, t.y+1, 7) end
    
    -- Draw Bio-Veins
    for v in all(bio_veins) do line(v.x, v.y, v.tx, v.ty, 11) end
    
    -- Draw Energy Arcs
    for a in all(arcs) do line(a.x1, a.y1, a.x2, a.y2, 13) end

    -- Draw Entities
    rectfill(scav_nomad.x-3, scav_nomad.y-3, scav_nomad.x+3, scav_nomad.y+3, 12) -- Purple Nomad
    rectfill(husb_anchor.x-4, husb_anchor.y-4, husb_anchor.x+4, husb_anchor.y+4, 7) -- White Anchor
    rectfill(synth_wraith.x-1, synth_wraith.y-1, synth_wraith.x+1, synth_wraith.y+1, 13) -- Blue Dot

    -- UI SIDEBAR
    rectfill(240, 0, 320, 240, 0)
    print("CRIMSON CRADLE", 245, 10, 8)
    print("----------------", 245, 18, 5)
    print("SCAV LVL: "..p.lv_scav, 245, 40, 12)
    print("PROG: "..flr(p.xp_scav).."%", 245, 48, 5)
    print("HUSB LVL: "..p.lv_husb, 245, 70, 7)
    print("PROG: "..flr(p.xp_husb).."%", 245, 78, 5)
    print("SYNTH LVL: "..p.lv_synth, 245, 100, 13)
    print("PROG: "..flr(p.xp_synth).."%", 245, 108, 5)
end

-- HELPER FUNCTIONS
function apply_aether_drift()
    local dx, dy = rnd(40)-20, rnd(40)-20
    scav_nomad.x = scav_nomad.x + dx
    husb_anchor.x = husb_anchor.x + dx
    -- Reveal Crater
    add(craters, {x=120+dx, y=120+dy, r=rnd(5)+2, life=100})
end

function update_entities()
    for i=#trails,1,-1 do trails[i].life = trails[i].life - 1 if trails[i].life<=0 then table.remove(trails,i) end end
    for i=#arcs,1,-1 do arcs[i].life = arcs[i].life - 1 if arcs[i].life<=0 then table.remove(arcs,i) end end
    for i=#craters,1,-1 do craters[i].life = craters[i].life - 1 if craters[i].life<=0 then table.remove(craters,i) end end
end

function dist(x1,y1,x2,y2) return sqrt((x2-x1)^2 + (y2-y1)^2) end
function rnd(n) return (t()*1337 % 1000) / 1000 * n end
function add(t, v) t[#t+1] = v end
function all(t)
    local i = 0
    return function()
        i = i + 1
        if i <= #t then return t[i] end
    end
end
function line(x1,y1,x2,y2,c)
    -- Simplified line drawing via points
    local d = dist(x1,y1,x2,y2)
    for i=0,d,2 do
        local r = i/d
        rectfill(x1+(x2-x1)*r, y1+(y2-y1)*r, x1+(x2-x1)*r+1, y1+(y2-y1)*r+1, c)
    end
end
