-- Animate chopper to chase player


--TODO
--Difference in light/darkness

#include "common.lua"

min_wait_time = GetFloatParam("min_wait_time", 30)
max_wait_time = GetFloatParam("max_wait_time", 40)
pSpeed = GetFloatParam("speed", 7)
pStartActive = GetBoolParam("startactive", false)

hoverAngle = nil
aimAngle = 0
angle = nil
chopperVel = nil
outlineAlpha = nil

function rndFloat(mi, ma)
	return mi + (ma-mi)*(math.random(0, 1000000)/1000000.0)
end

function init()
	chopper = FindBody("chopper")
	chopperTransform = GetBodyTransform(chopper)
	
	mainRotor = FindBody("mainrotor")
	mainRotorLocalTransform = TransformToLocalTransform(chopperTransform, GetBodyTransform(mainRotor))

	tailRotor = FindBody("tailrotor")
	tailRotorLocalTransform = TransformToLocalTransform(chopperTransform, GetBodyTransform(tailRotor))

	lightSource = FindLight("light")

	searchLight = FindBody("light")
	searchLightLocalTransform = TransformToLocalTransform(chopperTransform, GetBodyTransform(searchLight))
	
	chopperSound = LoadLoop("chopper-loop.ogg")
	chopperChargeSound = LoadSound("chopper-charge.ogg")
	chopperShootSound = LoadSound("chopper-shoot0.ogg", 16)
	chopperRocketSound = LoadSound("tools/launcher0.ogg")
	
	mysterioCope = LoadSound("MOD/snd/mysterio/lost/VO_BossM_S31_LostTarget0.ogg")
	mysterioSpotted = LoadSound("MOD/snd/mysterio/angry/searchNdestroy/VO_BossM_S31_AlertIdle0.ogg")
	mysterioHappy = LoadSound("MOD/snd/mysterio/death/VO_BossM_S31_Elim0.ogg")
	mysterioShittalk = LoadSound("MOD/snd/mysterio/angry/VO_BossM_S31_FullAlert0.ogg")
	
	chopperStartSound = LoadSound("chopper-start.ogg")
	chopperEndSound = LoadSound("chopper-end.ogg")
	chopperSoundSound = LoadSound("chopper-sound.ogg")
	
	angle = 0.0
	targetPos = chopperTransform

	chopperHeight = 15
	chopperVel = Vec()
	chopperTargetPos = VecAdd(chopperTransform.pos, Vec(0,0,0))
	chopperTargetRot = QuatEuler(0, 0, 0)
	searchLightTargetRot = QuatEuler(0, 0, 0)
	searchLightRot = QuatEuler(0, 0, 0)
	averageSurroundingHeight = 0

	poiPos = Vec()
	poiTimer = 0.0

	playerSeen = false
	timeSinceLastSeen = 0

	shootMode = "search"
	shootTimer = 0
	shootCount = 0
	rocketTimer = 10000.0

	lastPlayerPos = GetPlayerPos()
	playerSpeed = 0

	seenTime = 0

	active = false
	complete = false

	shotsFired = 0
	outlineAlpha = 0

	hoverAngle = 0
	aimAngle = 0

    rand_wait_time = math.random(min_wait_time, max_wait_time)	
	timer = 0
	
end


function getDistanceToPlayer()
	local playerPos = GetPlayerPos()
	return VecLength(VecSub(playerPos, chopperTransform.pos))
end


function getTimeVisibleBeforeBeingSeen()
	local playerPos = GetPlayerPos()
	if IsPointAffectedByLight(lightSource, playerPos) then
		return 0
	end

	local nominalTime = 8

	if GetPlayerVehicle() ~= 0 then
		nominalTime = 3
	end

	--Running reduces detection time by 50%
	local standingStill = 1.0-clamp(playerSpeed / 6, 0.0, 1.0)
	nominalTime = nominalTime * (0.5 + 0.5*standingStill)

	local d = getDistanceToPlayer()
	local distanceLower = 20
	local distanceUpper = 100
	local distanceFactor = 1.0 - clamp(d-distanceLower, 0, distanceUpper-distanceLower)/(distanceUpper-distanceLower)

	local toPlayer = VecNormalize(VecSub(GetPlayerPos(), chopperTransform.pos))
	local forward = TransformToParentVec(chopperTransform, Vec(0, 0, -1))
	local orientationFactor = clamp(VecDot(forward, toPlayer) * 0.7 + 0.3, 0.0, 1.0)
		
	local visibility = distanceFactor * orientationFactor

	--Cut visibility in half if hiding under water
	if IsPointInWater(GetCameraTransform().pos) then
		visibility = visibility * 0.5
	end
	
	--Never allow more than 70% visibility to allow some leeway when in the dark
	visibility = math.min(visibility, 0.7)

	return (1.0-visibility) * nominalTime
end


function choosePatrolTarget()
	local dir = VecNormalize(Vec(rndFloat(-1,1), 0, rndFloat(-1,1)))
	local r = rndFloat(15, 30)
	targetPos = VecAdd(GetPlayerPos(), VecScale(dir, r))
	timeSinceLastSeen = 0
end


function canSeePlayer()
	local playerPos = GetPlayerPos()

	--Direction to player
	local dir = VecSub(playerPos, chopperTransform.pos)
	local dist = VecLength(dir)
	dir = VecNormalize(dir)

	QueryRejectVehicle(GetPlayerVehicle())
	QueryRejectBody(chopper)
	return not QueryRaycast(chopperTransform.pos, dir, dist, 0, true)
end


function getSoundVolume(pos)
	local d = VecLength(VecSub(pos, chopperTransform.pos))
	local dir = VecNormalize(VecSub(pos, chopperTransform.pos))
	local distanceLower = 20
	local distanceUpper = 100
	local distanceFactor = 1.0 - clamp(d-distanceLower, 0, distanceUpper-distanceLower)/(distanceUpper-distanceLower)
		
	local origin = chopperTransform.pos
	local dist = d - 2
	local blockedFactor = 1.0
	QueryRejectBody(chopper)
	if QueryRaycast(origin, dir, dist) then
		blockedFactor = 0.5
	end

	return blockedFactor * distanceFactor
end


function shoot()
	PlaySound(chopperShootSound, chopperTransform.pos, 5, false)

	local p = chopperTransform.pos
	local d = VecNormalize(VecSub(targetPos, p))
	local spread = 0.03
	d[1] = d[1] + (math.random()-0.5)*2*spread
	d[2] = d[2] + (math.random()-0.5)*2*spread
	d[3] = d[3] + (math.random()-0.5)*2*spread
	d = VecNormalize(d)
	p = VecAdd(p, VecScale(d, 5))
	Shoot(p, d, "bullet")	
	shotsFired = shotsFired + 1
end


function rocket()
	PlaySound(chopperRocketSound, chopperTransform.pos, 5, false)

	local p = chopperTransform.pos
	local d = VecNormalize(VecSub(targetPos, p))
	local spread = 0.03
	d[1] = d[1] + (math.random()-0.5)*2*spread
	d[2] = d[2] + (math.random()-0.5)*2*spread
	d[3] = d[3] + (math.random()-0.5)*2*spread
	d = VecNormalize(d)
	p = VecAdd(p, VecScale(d, 5))
	Shoot(p, d, "rocket")
end


function tickShooting(dt)
	if GetFloat("game.player.health") == 0.0 or GetString("level.state") ~= "" then
		if not pleasured then
			PlaySound(mysterioHappy, chopperTransform.pos, 5, false)
			pleasured = true
		end
		return
	elseif GetFloat("game.player.health") > 0.0 then
		pleasured = false
	end

	if shootTimer > 0 then
		shootTimer = shootTimer - dt
		return
	end
	if shootMode == "search" then
		if playerSeen and getDistanceToPlayer() < 60 then
			shootMode = "charge"
			shootTimer = 1
			PlaySound(mysterioSpotted, chopperTransform.pos, 5, false)
			PlaySound(chopperChargeSound, chopperTransform.pos, 2, false)
		end
	elseif shootMode == "charge" then
		shootMode = "shoot"
		shootCount = math.random(3, 6)
	elseif shootMode == "shoot" then
		if shootCount > 0 then
			shootCount = shootCount - 1
			shoot();
			shootTimer = 0.2
		else
			if playerSeen then
				shootMode = "charge"
				shootTimer = 1
			else
				shootMode = "search"
				shootTimer = 1
			end
		end
	end
end


function considerRocket()
	if math.random() < 0.4 and shotsFired > 10 then
		rocketTimer = 1 + math.random()*2
	else
		rocketTimer = 0
	end
end


function computeSurroundingHeight()
	QueryRejectBody(chopper)
	QueryRejectBody(mainRotor)
	QueryRejectBody(tailRotor)
	QueryRejectBody(searchLight)
	local probe = VecCopy(chopperTargetPos)
	probe[1] = probe[1] + math.random(-10, 10)
	probe[2] = 100
	probe[3] = probe[3] + math.random(-10, 10)
	local hit, dist = QueryRaycast(probe, Vec(0,-1,0), 100, 2.0)
	local hitHeight = 0
	if hit then
		hitHeight = 100 - dist
	end
	averageSurroundingHeight = math.max(hitHeight, averageSurroundingHeight - GetTimeStep()*2)
end

function tick(dt)

	if not active and (GetInt("level.cleared") > 1 or GetInt("level.dispatch") == 1 or pStartActive) then
		PlaySound(chopperStartSound)
		active = true
		targetPos = GetPlayerPos()
		chopperTransform.pos[2] = chopperHeight
	end

	if not active then
		return
	end

	if not complete and GetFloat("game.player.health") == 0.0 then
		complete = true
		PlaySound(chopperEndSound)
		return
	end

	
	--Always detect player when hacking
	if GetBool("level.hacking") then
		targetPos = GetPlayerPos()
		timeSinceLastSeen = 0
		SetBool("level.hacking", false)
	end

	angle = angle + 0.6

	playerSpeed = VecLength(VecSub(GetPlayerPos(), lastPlayerPos)) / dt

	playerSeen = false
	local lineOfSightToPlayer = canSeePlayer()
	if lineOfSightToPlayer then
		seenTime = seenTime + dt
		local limit = getTimeVisibleBeforeBeingSeen()
		if seenTime > limit then
			targetPos = GetPlayerPos()
			playerSeen = true
			considerRocket()
		end
	else
		seenTime = math.max(0.0, math.min(1.0, seenTime) - dt)
	end

	if playerSeen then
		coped = false
		timeSinceLastSeen = 0
	else
		timeSinceLastSeen = timeSinceLastSeen + dt
	end
	
	--Let the chopper see player for one extra second if recently seen
	if timeSinceLastSeen < 0.75 and seenTime > 0 then
		playerSeen = true
		targetPos = GetPlayerPos()
	end

	if timeSinceLastSeen > 10 then
		choosePatrolTarget()
	end

	if timeSinceLastSeen > 3 then
		local volume, pos = GetLastSound();
		if volume > 0.5 then
	 		local v = getSoundVolume(pos) * volume
			if v > 0.5 then
				targetPos = pos
				timeSinceLastSeen = 0
				PlaySound(chopperSoundSound)
			end
		end
	end

	if not playerSeen and rocketTimer > 0 then
		rocketTimer = rocketTimer - dt
		if rocketTimer <= 0.0 then
			rocket()
			considerRocket()
		end
	end

	tickShooting(dt)
	
    --DebugWatch("Mysterio Shittalk Timer", timer)
    --DebugWatch("Mysterio Shittalk Wait Time", rand_wait_time)

	timer = timer + dt
	
    if timer >= rand_wait_time then
        PlaySound(mysterioShittalk, chopperTransform.pos, 2, false)
        timer = 0
        rand_wait_time = math.random(min_wait_time, max_wait_time)
    end		

	--Hover around last seen point when searching
	local hoverPos = VecCopy(targetPos)
	if not playerSeen then
		if not coped then
			PlaySound(mysterioCope, chopperTransform.pos, 5, false)
			coped = true
		end
		local radius = clamp(10 + timeSinceLastSeen, 10, 20)
		if not hoverAngle then hoverAngle = 0 end
		hoverAngle = hoverAngle + dt*0.25
		local x = math.cos(hoverAngle) * radius
		local z = math.sin(hoverAngle) * radius
		hoverPos = VecAdd(hoverPos, Vec(x, 0, z))
	end

	local toPlayer = VecSub(hoverPos, chopperTargetPos)
	toPlayer[2] = 0
	local l = VecLength(toPlayer)
	local minDist = 1.0
	if l > minDist then
		local speed = (l-minDist)
		if speed > pSpeed then
			speed = pSpeed
		end
		toPlayer = VecNormalize(toPlayer)
		chopperTargetPos = VecAdd(chopperTargetPos, VecScale(toPlayer, speed*dt))
	end

	computeSurroundingHeight()

	local currentHeight = chopperHeight
	QueryRejectBody(chopper)
	QueryRejectBody(mainRotor)
	QueryRejectBody(tailRotor)
	QueryRejectBody(searchLight)
	local probe = VecCopy(chopperTargetPos)
	probe[2] = 100
	local hit, dist = QueryRaycast(probe, Vec(0,-1,0), 100, 2.0)
	if hit then
		currentHeight = currentHeight + (100 - dist)
	end
	currentHeight = math.max(currentHeight, averageSurroundingHeight)
	chopperTargetPos[2] = currentHeight + math.sin(GetTime()*0.7)*5

	local toTarget = VecNormalize(VecSub(targetPos, chopperTargetPos))
	toTarget[2] = clamp(toTarget[2], -0.1, 0.1);
	local lookPoint = VecAdd(chopperTargetPos, toTarget);
	lookPoint[2] = chopperTargetPos[2]
	local rot = QuatLookAt(chopperTargetPos, lookPoint)
	rot = QuatRotateQuat(rot, QuatEuler(math.sin(angle*0.053)*10, math.sin(angle*0.04)*10, 0))
	chopperTargetRot = rot

	SetBodyTransform(chopper, chopperTransform)
	PlayLoop(chopperSound, chopperTransform.pos, 8, false)
	
	mainRotorLocalTransform.rot = QuatEuler(0, angle*57, 0)
	SetBodyTransform(mainRotor, TransformToParentTransform(chopperTransform, mainRotorLocalTransform))

	tailRotorLocalTransform.rot = QuatEuler(angle*57, 0, 0)
	SetBodyTransform(tailRotor, TransformToParentTransform(chopperTransform, tailRotorLocalTransform))

	--Searchlight
	local aimPos = VecCopy(targetPos)
	local radius = clamp(timeSinceLastSeen, 0, 10)
	aimAngle = aimAngle + dt*1.0
	local x = math.cos(aimAngle) * radius
	local z = math.sin(aimAngle*1.7) * radius
	aimPos = VecAdd(aimPos, Vec(x, 0, z))

	if poiTimer > 0.0 then
		poiTimer = poiTimer - dt
		aimPos = poiPos
	end

	local lightTransform = TransformToParentTransform(chopperTransform, searchLightLocalTransform)
	searchLightTargetRot = QuatLookAt(lightTransform.pos, aimPos)
	lightTransform.rot = searchLightRot
	SetBodyTransform(searchLight, lightTransform)

	local alpha = 0.0
	if not lineOfSightToPlayer then
		alpha = clamp(1.0 - (getDistanceToPlayer()-50) / 50, 0.0, 0.5)
		if alpha < 0.1 then
			alpha = 0.0
		end
	end
	outlineAlpha = outlineAlpha + clamp(alpha - outlineAlpha, -0.01, 0.01)
	if outlineAlpha > 0.0 then
		DrawBodyOutline(chopper, outlineAlpha)
		DrawBodyOutline(mainRotor, outlineAlpha)
		DrawBodyOutline(tailRotor, outlineAlpha)
	end

	lastPlayerPos = GetPlayerPos()
end

function update(dt)
	if not active then
		return
	end

	--Move chopper towards target position smoothly
	local acc = VecSub(chopperTargetPos, chopperTransform.pos)
	chopperVel = VecAdd(chopperVel, VecScale(acc, dt))
	chopperVel = VecScale(chopperVel, 0.98)
	chopperTransform.pos = VecAdd(chopperTransform.pos, VecScale(chopperVel, dt))

	--Rotate chopper smoothly towards target rotation
	chopperTransform.rot = QuatSlerp(chopperTransform.rot, chopperTargetRot, 0.02)

	--Rotate search light smoothly towards target rotation
	searchLightRot = QuatSlerp(searchLightRot, searchLightTargetRot, 0.05)
end
