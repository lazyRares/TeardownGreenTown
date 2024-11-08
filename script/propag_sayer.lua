function init()
    min_wait_time = GetFloatParam(min_wait_time, 30)
    max_wait_time = GetFloatParam(max_wait_time, 40)
    rand_wait_time = math.random(min_wait_time, max_wait_time)
    propag_snd = LoadSound("MOD/snd/propag/propag0.ogg")
    timer = 0
end

function tick(dt)
    --DebugWatch("propag timer", timer)
    --DebugWatch("propag wait time", rand_wait_time)

    timer = timer + dt
    
    if timer >= rand_wait_time then
        PlaySound(propag_snd, GetPlayerTransform().pos, 0.3)
        timer = 0
        rand_wait_time = math.random(min_wait_time, max_wait_time)
    end
end