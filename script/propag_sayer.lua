min_wait_time = GetFloatParam("min_wait_time", 30)
max_wait_time = GetFloatParam("max_wait_time", 40)

function init()
    rand_wait_time = math.random(min_wait_time, max_wait_time)
    timer = 0

    indoor_trigs = FindTriggers("indoors", true)
    propag_snd_reg = LoadSound("MOD/snd/propag/reg/propag0.ogg")
    propag_snd_muffled = LoadSound("MOD/snd/propag/muffled/propag0.ogg")
end

function tick(dt)
    --DebugWatch("propag timer", timer)
    --DebugWatch("propag wait time", rand_wait_time)

    timer = timer + dt
    
    if timer >= rand_wait_time then
        if IsIndoors() then
            PlaySound(propag_snd_muffled, GetPlayerTransform().pos, 0.3)
        else
            PlaySound(propag_snd_reg, GetPlayerTransform().pos, 0.3)
        end

        timer = 0
        rand_wait_time = math.random(min_wait_time, max_wait_time)
    end
end

function IsIndoors()
    local pos = GetPlayerTransform().pos
    if indoor_trigs == nil then return false end
    for i=1, #indoor_trigs do
        if IsPointInTrigger(indoor_trigs[i], pos) then
            return true
        end
    end
end