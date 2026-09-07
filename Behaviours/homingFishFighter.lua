local mx = 0
local my = 0
local target1
local target2
local dx1 = 0
local dy1 = 0
local dx2 = 0
local dy2 = 0
local length1
local length2
local randomX
local randomY
local angle
local cooldownTimer
local homingTimer
local firstShotDelay
local firingChance
local randomChance
local firePattern
local fireSFX
local isSpawned = false
local iFrames = 10

function OnInitialise()
    cooldownTimer = self.commandArgs.GetFieldFloat("homingCooldown", 50)
    homingTimer = self.commandArgs.GetFieldFloat("homingTime", 150)
    if self.commandArgs.HasField("firstShotDelay") then firstShotDelay = self.commandArgs.GetFieldFloat("firstShotDelay") else
        if self.customBehaviourData.HasField("firstShotDelay") then
            local f = self.customBehaviourData.GetFieldIntArray("firstShotDelay")
            firstShotDelay = NewDiffDictInt(f[1], f[2], f[3], f[4], f[5]).Get()
        else firstShotDelay = NewDiffDictInt(80, 40, 20, 20, 20).Get() end
    end
    if self.commandArgs.HasField("x") then
        local x = self.commandArgs.GetFieldIntArray("x")
        randomX = math.random(x[1], x[2])
    else randomX = math.random(700, 800) end
    if self.commandArgs.HasField("y") then
        local y = self.commandArgs.GetFieldIntArray("y")
        randomY = -math.random(y[1], y[2])
    else randomY = -math.random(50, 500) end
    self.lastPosition = { x = AdjustXToWideScreen(randomX), y = randomY }
    self.nextPosition = { x = AdjustXToWideScreen(randomX), y = randomY }
    if randomX > 300 then angle = 180 else angle = 0 end
    if self.commandArgs.HasField("firingChance") then
        local f = self.commandArgs.GetFieldIntArray("firingChance")
        firingChance = NewDiffDictInt(f[1], f[2], f[3], f[4], f[5]).Get()
    else firingChance = NewDiffDictInt(15, 30, 60, 80, 80).Get() end
    randomChance = math.random(0, 99)

    fireSFX = self.customBehaviourData.GetFieldString("fireSFX", "s_laser")
    firePattern = NewFirePatternFromEntityData(self.data)
end

function OnTick()
    target1 = GetPlayer(0)
    if target1.isActive then
        dx1 = target1.worldPosition.x - self.worldPosition.x
        dy1 = target1.worldPosition.y - self.worldPosition.y
        length1 = math.sqrt(dx1 * dx1 + dy1 * dy1)
        dx1 = dx1 / length1
        dy1 = dy1 / length1
    else length1 = 1000 end
    target2 = GetPlayer(1)
    if target2.isActive then
        dx2 = target2.worldPosition.x - self.worldPosition.x
        dy2 = target2.worldPosition.y - self.worldPosition.y
        length2 = math.sqrt(dx2 * dx2 + dy2 * dy2)
        dx2 = dx2 / length2
        dy2 = dy2 / length2
    else length2 = 1000 end
    if cooldownTimer > 0 then cooldownTimer = cooldownTimer - 1 else
        if homingTimer > 0 then
            homingTimer = homingTimer - 1
            if target1.isActive or target2.isActive then
                if length1 > length2 then
                    local sourcePos = self.worldPosition
                    local targetPos = target2.worldPosition
                    local targetAngle = math.deg(math.atan2(targetPos.y - sourcePos.y, targetPos.x - sourcePos.x))
                    angle = MoveTowardsAngle(angle, targetAngle, 4)
                else
                    local sourcePos = self.worldPosition
                    local targetPos = target1.worldPosition
                    local targetAngle = math.deg(math.atan2(targetPos.y - sourcePos.y, targetPos.x - sourcePos.x))
                    angle = MoveTowardsAngle(angle, targetAngle, 4)
                end
            end
        end
        if homingTimer == 0 and self.position.x > 800 or self.position.x < -200 or self.position.y > 200 or self.position.y < -800 then self.Deactivate() end
    end

    local angleRad = math.rad(angle)
    mx = math.cos(angleRad) * self.data.speed
    my = math.sin(angleRad) * self.data.speed
    self.movement = { x = mx, y = my, z = 0 }

    local negativeAngle = -(angle % 360 - 5.625) % 360
    local animatorFrame = math.floor((negativeAngle / (360.0 / self.animator.totalFrames) + self.animator.totalFrames/2 - 0.5) % self.animator.totalFrames)
    self.animator.GoTo(animatorFrame)

    if CanFire() then
        if firstShotDelay > 0 then firstShotDelay = firstShotDelay - 1 end
        firePattern.Tick()

        if firePattern.CanFire() and firstShotDelay == 0 then
            firePattern.MarkFired()
            local fireArgs = NewJSONObject()
            fireArgs.AddFieldFloat("mx", math.cos(angleRad) * 8)
            fireArgs.AddFieldFloat("my", math.sin(angleRad) * 8)
            SpawnEntityWorld("enemyshot_laser", { x = self.worldPosition.x + ( math.cos(angleRad) * 42 ), y = self.worldPosition.y + ( math.sin(angleRad) * 42 )}, fireArgs)
            PlaySound(fireSFX)
        end
    end

    if not isSpawned then
        if self.position.x > 0 and self.position.x < 600 and self.position.y > -600 and self.position.y < 0 then isSpawned = true end
    else
        if iFrames > 0 then iFrames = iFrames - 1 end
    end
end

function CanFire()
    return homingTimer > 0 and cooldownTimer <= 0 and randomChance < firingChance
end

function OnKill()
    self.SpawnShipShards(10, -6, 0, -15, 5, 0, 0, 0, 0, 0, 0)
end

function HasCollision()
    return iFrames <= 5 or mx < 0
end

function ShouldKillPlayerOnTouch()
    return iFrames == 0
end
