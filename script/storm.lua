function init()
    form = LoadSound("MOD/snd/storm/storm_forming.ogg")
    advance = LoadSound("MOD/snd/storm/storm_advance.ogg")

    timer = 0
    next_advance = 60
    formed = false
end

function tick(dt)
    timer = timer + dt

    if timer > 7 and not formed then
        timer = 0
        formed = true
        PlaySound(form, GetPlayerTransform().pos, 0.2)
    end

    if timer > next_advance then
        timer = 0
        PlaySound(advance)
        next_advance = math.random(75, 180)
    end
end