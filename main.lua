-- name:\\#ffdd00\\Hybrid \\#ffa600\\Moveset
-- incompatible: moveset
-- description: Placeholder Description

------------------------------
----- Functions ---------
------------------------------

local allocate_mario_action, atan2s, sins, coss, mario_set_forward_vel, set_mario_action, play_mario_sound, play_sound, set_mario_animation, set_anim_to_frame,
check_fall_damage_or_get_stuck, common_air_action_step, perform_air_step, mario_drop_held_object =
    allocate_mario_action, atan2s, sins, coss, mario_set_forward_vel, set_mario_action, play_mario_sound, play_sound, set_mario_animation, set_anim_to_frame,
    check_fall_damage_or_get_stuck, common_air_action_step, perform_air_step, mario_drop_held_object
local math_floor = math.floor

-------------------------------
-------- Actions -----------
-------------------------------

ACT_FAKE_FREEFALL = allocate_mario_action(ACT_GROUP_AIRBORNE | ACT_FLAG_AIR | ACT_FLAG_ALLOW_VERTICAL_WIND_ACTION)
ACT_SPIN_JUMP = allocate_mario_action(ACT_GROUP_AIRBORNE | ACT_FLAG_AIR | ACT_FLAG_ALLOW_VERTICAL_WIND_ACTION)
ACT_WALL_SLIDE = allocate_mario_action(ACT_GROUP_AIRBORNE | ACT_FLAG_AIR | ACT_FLAG_MOVING | ACT_FLAG_ALLOW_VERTICAL_WIND_ACTION)
ACT_ROLL = allocate_mario_action(ACT_GROUP_MOVING)
ACT_AIR_DASH = allocate_mario_action(ACT_GROUP_AIRBORNE | ACT_FLAG_AIR | ACT_FLAG_ALLOW_VERTICAL_WIND_ACTION)
ACT_AIR_DASH_END = allocate_mario_action(ACT_GROUP_AIRBORNE | ACT_FLAG_AIR | ACT_FLAG_ALLOW_VERTICAL_WIND_ACTION)
ACT_DOLPHIN_DIVE = allocate_mario_action(ACT_GROUP_AIRBORNE | ACT_FLAG_AIR | ACT_FLAG_ALLOW_VERTICAL_WIND_ACTION)
ACT_WATER_SPIN = allocate_mario_action(ACT_GROUP_SUBMERGED | ACT_FLAG_SWIMMING)
ACT_WATER_GROUND_POUND = allocate_mario_action(ACT_GROUP_SUBMERGED | ACT_FLAG_SWIMMING)
ACT_WATER_GROUND_POUND_LAND = allocate_mario_action(ACT_GROUP_SUBMERGED | ACT_FLAG_SWIMMING)
ACT_CUSTOM_AIR_HIT_WALL = allocate_mario_action(ACT_GROUP_AIRBORNE | ACT_FLAG_AIR)

--gLevelValues.entryLevel = LEVEL_BOB--LEVEL START DEBUG

-----------------------------------
------------- Extra ------------
----------------------------------

local ANGLE_QUEUE_SIZE = 9
local SPIN_TIMER_SUCCESSFUL_INPUT = 4

local SPINACTIONS = {
    [ACT_IDLE] = true,
    [ACT_WALKING] = true,
    [ACT_JUMP] = true,
    [ACT_DOUBLE_JUMP] = true,
    [ACT_TRIPLE_JUMP] = true,
    [ACT_LONG_JUMP] = true,
    [ACT_JUMP_KICK] = true,
    [ACT_SIDE_FLIP] = true,
    [ACT_DIVE] = true,
    [ACT_FORWARD_ROLLOUT] = true,
    [ACT_BACKWARD_ROLLOUT] = true,
    [ACT_WALL_KICK_AIR] = true,
    [ACT_BACKFLIP] = true,
    [ACT_FREEFALL] = true,
    [ACT_FLYING] = true,
    [ACT_WATER_JUMP] = true,
    [ACT_AIR_DASH_END] = true,
    [ACT_BUTT_SLIDE_AIR] = true
}

local WATERACTIONS = {
    [ACT_WATER_IDLE] = true,
    [ACT_WATER_PUNCH] = true,
    [ACT_WATER_PLUNGE] = true,
    [ACT_BREASTSTROKE] = true,
    [ACT_FLUTTER_KICK] = true,
    [ACT_WATER_ACTION_END] = true
    --[ACT_HOLD_WATER_IDLE] = true,
    --[ACT_HOLD_WATER_ACTION_END] = true,
    --[ACT_HOLD_SWIMMING_END] = true,
    --[ACT_HOLD_BREASTSTROKE] = true
}

local AIRDASHACTIONS = {
    [ACT_JUMP] = true,
    [ACT_DOUBLE_JUMP] = true,
    [ACT_TRIPLE_JUMP] = true,
    [ACT_LONG_JUMP] = true,
    [ACT_DIVE] = true,
    [ACT_FREEFALL] = true,
    [ACT_WALL_KICK_AIR] = true,
    [ACT_SPIN_JUMP] = true
}

local convert_actions = {
    [ACT_AIR_HIT_WALL] = ACT_CUSTOM_AIR_HIT_WALL,
    [ACT_SLIDE_KICK] = ACT_ROLL,
    [ACT_WATER_PUNCH] = ACT_WATER_SPIN
}

local gMarioStateExtras = {}

for i = 0, (MAX_PLAYERS - 1) do
    gMarioStateExtras[i] = {}
    local m = gMarioStates[i]
    local e = gMarioStateExtras[i]
    s = gPlayerSyncTable[i]

    s.usingHybird = true

    e.angleDeltaQueue = {}
    for j = 0, (ANGLE_QUEUE_SIZE - 1) do e.angleDeltaQueue[j] = 0 end
    e.rotAngle = 0
    e.boostTimer = 0

    e.stickLastAngle = 0
    e.spinDirection = 0
    e.spinBufferTimer = 0
    e.spinInput = 0
    e.lastIntendedMag = 0

    e.lastPos = {}
    if m and m.pos then
        e.lastPos.x = m.pos.x
        e.lastPos.y = m.pos.y
        e.lastPos.z = m.pos.z
    else
        e.lastPos.x = 0
        e.lastPos.y = 0
        e.lastPos.z = 0
    end

    e.fakeSavedAction = 0
    e.fakeSavedPrevAction = 0
    e.fakeSavedActionTimer = 0
    e.fakeWroteAction = 0
    e.fakeSaved = false

    e.savedWallSlideHeight = 0
    e.savedWallSlide = false

    e.animFrame = 0
    e.spinRiseTimer = 0
    e.groundPoundCooldown = 0
    e.hangSpeed = 0
    e.didSpin = false
    e.didAirDash = false
    e.swimSpinAngle = 0
    e.GPtWP = false
    e.didSwimDive = false

    e.grabEscape = 0
    e.grabStruggle = false
    e.lastAnaDir = 0
end

local hybird_cmd = function(_, value)
    gPlayerSyncTable[0].usingHybird = value
end

local function random_float(min, max)
    return min + math.random() * (max - min)
end

local function limit_angle(a)
    return (a + 0x8000) % 0x10000 - 0x8000
end

function no_fall_damage(m)
    if not m or m.playerIndex == nil then return end
    if not s.usingHybird then return end
    m.peakHeight = m.pos.y
end

local function mario_update_spin_input(m)
    if not m or m.playerIndex == nil or not gMarioStateExtras[m.playerIndex] then 
        return 
    end
    if (m.action & ACT_FLAG_AIR) == 0 then 
        return 
    end
    local e = gMarioStateExtras[m.playerIndex]
    local rawAngle = atan2s(-m.controller.stickY, m.controller.stickX)
    e.spinInput = 0

    if e.lastIntendedMag > 0.5 and m.intendedMag > 0.5 then
        local angleOverFrames = 0
        local thisFrameDelta = 0

        local newDirection = e.spinDirection
        local signedOverflow = 0

        if rawAngle < e.stickLastAngle then
            if e.stickLastAngle - rawAngle > 0x8000 then
                signedOverflow = 1
            end
            if signedOverflow ~= 0 then
                newDirection = 1
            else
                newDirection = -1
            end
        elseif rawAngle > e.stickLastAngle then
            if rawAngle - e.stickLastAngle > 0x8000 then
                signedOverflow = 1
            end
            if signedOverflow ~= 0 then
                newDirection = -1
            else
                newDirection = 1
            end
        end

        if e.spinDirection ~= newDirection then
            for i = 0, (ANGLE_QUEUE_SIZE - 1) do
                e.angleDeltaQueue[i] = 0
            end
            e.spinDirection = newDirection
        else
            for i = (ANGLE_QUEUE_SIZE - 1), 1, -1 do
                e.angleDeltaQueue[i] = e.angleDeltaQueue[i - 1]
                angleOverFrames = angleOverFrames + e.angleDeltaQueue[i]
            end
        end

        if e.spinDirection < 0 then
            if signedOverflow ~= 0 then
                thisFrameDelta = math_floor((1.0 * e.stickLastAngle + 0x10000) - rawAngle)
            else
                thisFrameDelta = e.stickLastAngle - rawAngle
            end
        elseif e.spinDirection > 0 then
            if signedOverflow ~= 0 then
                thisFrameDelta = math_floor(1.0 * rawAngle + 0x10000 - e.stickLastAngle)
            else
                thisFrameDelta = rawAngle - e.stickLastAngle
            end
        end

        e.angleDeltaQueue[0] = thisFrameDelta
        angleOverFrames = angleOverFrames + thisFrameDelta

        if angleOverFrames >= 0xA000 then
            e.spinBufferTimer = SPIN_TIMER_SUCCESSFUL_INPUT
        end

        if e.spinBufferTimer > 0 then
            e.spinInput = 1
            e.spinBufferTimer = e.spinBufferTimer - 1
        end
    else
        e.spinDirection = 0
        e.spinBufferTimer = 0
    end

    e.stickLastAngle = rawAngle
    e.lastIntendedMag = m.intendedMag
end

local function act_fake_freefall(m)
    common_air_action_step(m, ACT_FREEFALL, CHAR_ANIM_GENERAL_FALL, AIR_STEP_CHECK_LEDGE_GRAB | AIR_STEP_CHECK_HANG)
end

local function act_water_spin(m)--GALAXY SWIM / SPIN SWIM
    if not m or m.playerIndex == nil or not gMarioStateExtras[m.playerIndex] then
        return false
    end
    
    local e = gMarioStateExtras[m.playerIndex]

    m.marioBodyState.handState = MARIO_HAND_OPEN

    if m.actionTimer == 0 then
        e.spinSpeed = 1
        play_sound_with_freq_scale(SOUND_ACTION_SWIM_FAST, m.marioObj.header.gfx.cameraToObject, 1.75)
        mario_set_forward_vel(m,math.max(math.min(m.forwardVel+35,90),40))
    end

    e.spinSpeed = e.spinSpeed * 0.78
    set_mario_animation(m, CHAR_ANIM_START_TWIRL)
    set_mario_particle_flags(m, PARTICLE_SPARKLES, 0)

    if m.actionTimer > 20 then
        set_mario_action(m, ACT_WATER_ACTION_END, 0)
    else
        local targetPitch = -252.0 * m.controller.stickY
        local pitchVel;
        if (m.faceAngle.x < 0) then
            pitchVel = 0x100;
        else
            pitchVel = 0x200;
        end

        if (m.faceAngle.x < targetPitch) then
            m.faceAngle.x = m.faceAngle.x + pitchVel
            if (m.faceAngle.x > targetPitch) then
                m.faceAngle.x = targetPitch;
            end
        elseif (m.faceAngle.x > targetPitch) then
            m.faceAngle.x = m.faceAngle.x - pitchVel
            if (m.faceAngle.x < targetPitch) then
                m.faceAngle.x = targetPitch;
            end
        end
        
        local targetYawVel = -(10.0 * m.controller.stickX);

        if (targetYawVel > 0) then
            if (m.angleVel.y < 0) then
                m.angleVel.y = m.angleVel.y + 0x40;
                if (m.angleVel.y > 0x10) then
                    m.angleVel.y = 0x10;
                end
            else
                m.angleVel.y = approach_s32(m.angleVel.y, targetYawVel, 0x10, 0x20);
            end
        elseif (targetYawVel < 0) then
            if (m.angleVel.y > 0) then
                m.angleVel.y = m.angleVel.y - 0x40;
                if (m.angleVel.y < -0x10) then
                    m.angleVel.y = -0x10;
                end
            else
                m.angleVel.y = approach_s32(m.angleVel.y, targetYawVel, 0x20, 0x10);
            end
        else
            m.angleVel.y = approach_s32(m.angleVel.y, 0, 0x40, 0x40);
        end

        m.faceAngle.y = m.faceAngle.y + m.angleVel.y;
        m.faceAngle.z = -m.angleVel.y * 8;

        m.vel.x = m.forwardVel * sins(m.faceAngle.y) * coss(m.faceAngle.x)
        m.vel.y = m.forwardVel * sins(m.faceAngle.x)
        m.vel.z = m.forwardVel * coss(m.faceAngle.y) * coss(m.faceAngle.x)

        local movement = perform_water_step(m)

        function bonk()
            mario_set_forward_vel(m,-20)
            set_mario_action(m,ACT_BACKWARD_WATER_KB,0)
            stop_sounds_from_source(m.marioObj.header.gfx.cameraToObject)
            m.flags = m.flags & ~MARIO_MARIO_SOUND_PLAYED
            m.flags = m.flags & ~MARIO_ACTION_SOUND_PLAYED
            play_sound_with_freq_scale(SOUND_GENERAL_MOVING_WATER, m.marioObj.header.gfx.cameraToObject, 0.85)
            play_mario_sound(m, 0, CHAR_SOUND_OOOF2)
        end

        if movement == WATER_STEP_HIT_FLOOR then
            floorPitch = -find_floor_slope(m, -0x8000);
            if (m.faceAngle.x < floorPitch) then
                m.faceAngle.x = floorPitch
            end
        elseif movement == WATER_STEP_HIT_CEILING then
            if (m.faceAngle.x > -0x3000) then
                m.faceAngle.x = m.faceAngle.x - 0x100
            end
        elseif movement == WATER_STEP_HIT_WALL then
            if (m.controller.stickY == 0.0) then
                if (m.faceAngle.x > 0.0) then
                    m.faceAngle.x = m.faceAngle.x + 0x200
                    if (m.faceAngle.x > 0x3F00) then
                        m.faceAngle.x = 0x3F00
                    end
                else
                    m.faceAngle.x = m.faceAngle.x - 0x200;
                    if (m.faceAngle.x < -0x3F00) then
                        m.faceAngle.x = -0x3F00;
                    end
                end
            end

            local wallAngle = atan2s(m.wallNormal.z, m.wallNormal.x);
            local dWallAngle = wallAngle - m.faceAngle.y;

            if m.forwardVel > 30 and check_wall_kick(mjm) then --Needs a better way to check wall hit
                bonk()
            end
        end

        mario_set_forward_vel(m,m.forwardVel-1)

        
        local probe = m.pos.y + 1.5;

        if (probe >= m.waterLevel - 80) then
            set_mario_action(m, ACT_DOLPHIN_DIVE, 0)--DOLPHIN DIVE
            m.vel.y = m.forwardVel * 2
            mario_set_forward_vel(m,m.forwardVel * 2)
            play_sound_with_freq_scale(SOUND_OBJ_DIVING_INTO_WATER, m.marioObj.header.gfx.cameraToObject, 0.8)
            set_mario_particle_flags(m, PARTICLE_WATER_SPLASH, 0)
            if m.forwardVel > 40 then
                play_mario_sound(m, SOUND_ACTION_SWIM_FAST, CHAR_SOUND_YAHOO_WAHA_YIPPEE)
            else
                play_mario_sound(m, SOUND_ACTION_SWIM_FAST, CHAR_SOUND_HOOHOO)
            end
        end
    end

    e.swimSpinAngle = e.swimSpinAngle + (0x10000 * e.spinSpeed)

    m.marioObj.header.gfx.angle.x = 0x8000 + e.swimSpinAngle--Spins correctly but doesn't go up or down at the momment.
    m.marioObj.header.gfx.angle.y = m.faceAngle.y + 0x4000
    m.marioObj.header.gfx.angle.z = -m.faceAngle.z + 0x3F00
    
    m.actionTimer = m.actionTimer + 1
end

local function act_dolphin_dive(m)--DOLPHIN DIVE
    local stepResult = common_air_action_step(m, ACT_FREEFALL, CHAR_ANIM_DIVE, AIR_STEP_CHECK_LEDGE_GRAB | AIR_STEP_CHECK_HANG)
    -- perform_air_step(m, 0)

    if m.actionTimer < 10 then
        set_mario_particle_flags(m, PARTICLE_SPARKLES, 0)
        spawn_sync_object(id_bhvSnowParticleSpawner, 0, (m.pos.x + math.random(-30, 30)), (m.pos.y + math.random(-30, 30)), (m.pos.z + math.random(-30, 30)), nil)--Snow particles work as water droplets, ha ha.
    end

    if stepResult == AIR_STEP_LANDED then
        set_mario_action(m, ACT_DIVE_SLIDE, 0)
    end

    if (m.pos.y < m.waterLevel - 100) then
        m.faceAngle.x = m.vel.y * 0x100
        set_mario_particle_flags(m, PARTICLE_WATER_SPLASH, 0)
        play_sound(SOUND_ACTION_UNKNOWN432, m.marioObj.header.gfx.cameraToObject)
        set_mario_action(m, ACT_SWIMMING_END, 0)
    end

    m.marioObj.header.gfx.angle.x = m.vel.y * -0x100


    m.actionTimer = m.actionTimer + 1
end

local function act_spin_jump(m)--GALAXY SPIN / SPIN JUMP
    if not m or m.playerIndex == nil or not gMarioStateExtras[m.playerIndex] then
        return false
    end

    m.marioBodyState.handState = MARIO_HAND_OPEN

    update_air_without_turn(m);
    local stepResult = perform_air_step(m, 0)

    local e = gMarioStateExtras[m.playerIndex]
    
    if stepResult == AIR_STEP_LANDED then
        if e.fromGround then
            e.fromGround = false
        else
            set_mario_action(m, ACT_IDLE, 0)
        end
        return
    end


    if m.actionTimer == 0 then
        e.spinSpeed = 1
    end

    if e.spinSpeed > 0.02 then
        if stepResult == AIR_STEP_HIT_WALL and not e.fromGround then
            stop_sounds_from_source(m.marioObj.header.gfx.cameraToObject)
            mario_bonk_reflection(m, false)
            m.flags = m.flags & ~MARIO_MARIO_SOUND_PLAYED
            play_mario_sound(m, 0, CHAR_SOUND_UH)
            e.spinSpeed = 0
        end
        e.spinSpeed = e.spinSpeed * 0.78
        m.marioObj.header.gfx.angle.y = limit_angle(m.faceAngle.y + (65535 * e.spinSpeed))
        set_mario_animation(m, CHAR_ANIM_START_TWIRL)
        set_mario_particle_flags(m, PARTICLE_SPARKLES, 0)
    else
        set_mario_animation(m, CHAR_ANIM_GENERAL_FALL)
        m.marioObj.header.gfx.angle.y = limit_angle(m.faceAngle.y)

        if (m.input & INPUT_B_PRESSED) ~= 0 then
            if m.forwardVel < 35 then
                m.faceAngle.y = m.intendedYaw
                m.vel.y = 45
                mario_set_forward_vel(m, m.forwardVel * 1.35)
                set_mario_action(m, ACT_JUMP_KICK, 0)
            else
                set_mario_action(m, ACT_DIVE, 0)
                return false
            end
        elseif (m.controller.buttonPressed & Z_TRIG) ~= 0 then
            set_mario_action(m, ACT_GROUND_POUND, 0)
            return false
        end
    end

    m.actionTimer = m.actionTimer + 1
    return false
end

function act_roll(m)--ROLL (ELEVATOR GAME 64's ROLL)
    common_slide_action_with_jump(m, ACT_WALKING, ACT_LONG_JUMP, ACT_FREEFALL, CHAR_ANIM_FORWARD_SPINNING)

    local intendedDYaw = m.intendedYaw - m.slideYaw;
    local forward = coss(intendedDYaw);
    if (forward < 0.0 and m.forwardVel >= 0.0) then
        forward = forward * (0.5 + 0.5 * m.forwardVel / 100.0)
    end
    
    local floor_type = mario_get_floor_class(m)

    if floor_type == SURFACE_CLASS_VERY_SLIPPERY then
        accel = 10.0;
        lossFactor = m.intendedMag / 32.0 * forward * 0.02 + 0.99;
    elseif floor_type == SURFACE_CLASS_SLIPPERY then
        accel = 8.0;
        lossFactor = m.intendedMag / 32.0 * forward * 0.02 + 0.98;
    elseif floor_type == SURFACE_CLASS_NOT_SLIPPERY then
        accel = 5.0;
        lossFactor = m.intendedMag / 32.0 * forward * 0.02 + 0.96;
    else
        accel = 7.0;
        lossFactor = m.intendedMag / 32.0 * forward * 0.02 + 0.96;
    end

    if (m.input & INPUT_B_PRESSED) ~= 0 then
        spawn_sync_object(id_bhvHorStarParticleSpawner, 0, m.pos.x, m.pos.y, m.pos.z, nil)
        mario_set_forward_vel(m, math.max(math.min(120, m.forwardVel + 30), 30))
        play_sound(SOUND_ACTION_TWIRL, m.marioObj.header.gfx.cameraToObject)
    end

    mario_set_forward_vel(m, m.forwardVel + lossFactor / 2)

    if (m.forwardVel < 10) then
        if (m.forwardVel < 0) and AIR_STEP_HIT_WALL then
            set_mario_action(m, ACT_BACKWARD_GROUND_KB, 0)
        else
            set_mario_action(m, ACT_START_CROUCHING, 0)
        end
    end
end

local function act_air_dash(m)--AIR DASH
    common_air_action_step(m, ACT_SLIDE_KICK_SLIDE, CHAR_ANIM_SLIDE_KICK, AIR_STEP_NONE)
    local stepResult = perform_air_step(m, 0)

    if m.actionTimer == 0 then
        mario_set_forward_vel(m, math.max(64, m.forwardVel))
    else
        mario_set_forward_vel(m, math.max(m.forwardVel - 4, 5))
        if m.forwardVel <= 5 then
            set_mario_action(m, ACT_AIR_DASH_END, 0)
        end
    end
    m.vel.y = -5
    set_mario_particle_flags(m, PARTICLE_DUST, 0)

    if stepResult == AIR_STEP_HIT_WALL then
        stop_sounds_from_source(m.marioObj.header.gfx.cameraToObject)
        --play_sound(((m.flags & MARIO_METAL_CAP) ~= 0 and SOUND_ACTION_METAL_BONK or SOUND_ACTION_BONK), m.marioObj.header.gfx.cameraToObject)
        --set_mario_action(m, ACT_BACKWARD_AIR_KB, 0)
        --spawn_sync_object(id_bhvHorStarParticleSpawner, 0, m.pos.x, m.pos.y ,m.pos.z, nil)
    else
        if m.actionTimer >= 20 or (m.controller.buttonDown & A_BUTTON) == 0 then
            stop_sounds_from_source(m.marioObj.header.gfx.cameraToObject)
            set_mario_action(m, ACT_AIR_DASH_END, 0)
        end
        m.actionTimer = m.actionTimer + 1
    end

    if (m.input & INPUT_Z_PRESSED) ~= 0 then
        set_mario_action(m, ACT_GROUND_POUND, 0)
    end
end

local function act_air_dash_end(m)--AIR DASH END
    m.vel.y = m.vel.y - 0.5
    set_mario_animation(m, CHAR_ANIM_FALL_FROM_SLIDE_KICK)
    local stepResult = perform_air_step(m, 0)
    if stepResult == AIR_STEP_NONE then
        if m.intendedMag > 0 then
            local dirDif = m.intendedYaw - m.faceAngle.y
            if dirDif > 0x8000 then
                dirDif = dirDif - 0x10000
            elseif dirDif < -0x8000 then
                dirDif = dirDif + 0x10000
            end
            if math.abs(dirDif) < 0x4000 then--Holding forward.
                mario_set_forward_vel(m, math.max(m.forwardVel, 20))
            elseif math.abs(dirDif) > 0x4000 then--Holding backward.
                mario_set_forward_vel(m, math.max(m.forwardVel - 1, -2))
            end
        end
    elseif stepResult == AIR_STEP_LANDED then
        set_mario_action(m, ACT_FREEFALL_LAND, 0)
    end

    if stepResult == AIR_STEP_HIT_WALL and (m.input & INPUT_A_PRESSED) ~= 0 then
        set_mario_action(m, ACT_AIR_HIT_WALL, 0)
    end

    if (m.input & INPUT_Z_PRESSED) ~= 0 then
        set_mario_action(m, ACT_GROUND_POUND, 0)
    end
end

local function act_water_ground_pound(m)--WATER GROUND POUND
    local e = gMarioStateExtras[m.playerIndex]
    m.forwardVel = 0
    m.vel.x = 0
    m.vel.z = 0
    m.faceAngle.z = 0

    --if (m.input & INPUT_B_PRESSED) ~= 0 then--WATER DIVE (Can be done better than how it is right now.)
        --mario_set_forward_vel(m, 1000)
        --e.GPtWP = false
        --e.didSwimDive = true
        --stop_sounds_from_source(m.marioObj.header.gfx.cameraToObject)
        --m.flags = m.flags & ~MARIO_MARIO_SOUND_PLAYED
        --m.flags = m.flags & ~MARIO_ACTION_SOUND_PLAYED
        --set_mario_action(m, ACT_BREASTSTROKE, 0)
        --return
    --end

    if m.actionTimer == 0 and not e.GPtWP then
        m.faceAngle.x = 0 
        m.vel.y = 0
        set_mario_animation(m,CHAR_ANIM_START_GROUND_POUND)
        play_sound(SOUND_GENERAL_SWISH_WATER, m.marioObj.header.gfx.cameraToObject)
    elseif (m.actionTimer == 11 and not e.GPtWP) or (e.GPtWP and m.actionTimer == 0) then
        m.vel.y = -40
        
        set_mario_animation(m,CHAR_ANIM_GROUND_POUND)
        if not e.GPtWP then
            play_mario_sound(m, 0, CHAR_SOUND_GROUND_POUND_WAH)
        end
        play_sound_with_freq_scale(SOUND_GENERAL_MOVING_WATER, m.marioObj.header.gfx.cameraToObject, 2)
    elseif m.actionTimer >= 13 or e.GPtWP then
        set_mario_particle_flags(m, PARTICLE_PLUNGE_BUBBLE, 0)
    end

    local waterResult = perform_water_step(m)

    if m.actionTimer > 30 then
        set_mario_action(m, ACT_WATER_IDLE, 0)
    elseif waterResult == WATER_STEP_HIT_FLOOR then
        play_sound(SOUND_ACTION_TERRAIN_HEAVY_LANDING, m.marioObj.header.gfx.cameraToObject)
        spawn_sync_object(id_bhvHorStarParticleSpawner, 0, m.pos.x, m.pos.y, m.pos.z, nil)
        set_mario_action(m, ACT_WATER_GROUND_POUND_LAND, 0)
    end
    
    m.actionTimer = m.actionTimer + 1
end

local function act_water_ground_pound_land(m)--WATER GROUND POUND LAND
    local waterResult = perform_water_step(m)

    if waterResult == WATER_STEP_HIT_FLOOR then
        set_mario_animation(m, CHAR_ANIM_STOP_SLIDE)
    end

    if m.actionTimer > 20 then
        set_mario_action(m, ACT_WATER_IDLE, 0)
    end

    m.actionTimer = m.actionTimer + 1
end

function act_wall_slide(m)--WALL SLIDE
    if not m or m.playerIndex == nil or not gMarioStateExtras[m.playerIndex] then return 0 end
    local e = gMarioStateExtras[m.playerIndex]
    e.savedWallSlideHeight = m.pos.y
    e.savedWallSlide = true

    if m.actionTimer == 0 then
        e.animFrame = 0
        e.stored_wall_speed = m.forwardVel
    end

    if (m.input & INPUT_A_PRESSED) ~= 0 then
        m.vel.y = 52.0
        mario_set_forward_vel(m, e.stored_wall_speed)
        return set_mario_action(m, ACT_WALL_KICK_AIR, 0)
    end

    e.stored_wall_speed = math.max(-1,e.stored_wall_speed - 5)
    mario_set_forward_vel(m, -1)
    m.particleFlags = m.particleFlags | PARTICLE_DUST

    play_sound(SOUND_MOVING_TERRAIN_SLIDE + m.terrainSoundAddend, m.marioObj.header.gfx.cameraToObject)
    set_mario_animation(m, CHAR_ANIM_START_WALLKICK)

    if perform_air_step(m, 0) == AIR_STEP_LANDED then
        mario_set_forward_vel(m, 0.0)
        if check_fall_damage_or_get_stuck(m, ACT_HARD_BACKWARD_GROUND_KB) == 0 then
            return set_mario_action(m, ACT_FREEFALL_LAND, 0)
        end
    end

    m.actionTimer = m.actionTimer + 1
    if not m.wall and m.actionTimer > 2 then
        mario_set_forward_vel(m, 0.0)
        return set_mario_action(m, ACT_FREEFALL, 0)
    end

    return 0
end

local function act_wall_slide_gravity(m)
    m.vel.y = m.vel.y - 2
    if m.vel.y < -30 then
        m.vel.y = -30
    end
end

local function act_air_hit_wall(m)
    if m.heldObj ~= 0 then
        mario_drop_held_object(m)
    end

    m.actionTimer = m.actionTimer + 1
    if m.actionTimer <= 1 and (m.input & INPUT_A_PRESSED) ~= 0 then
        m.vel.y = 52.0
        m.faceAngle.y = limit_angle(m.faceAngle.y + 0x8000)
        return set_mario_action(m, ACT_WALL_KICK_AIR, 0)
    elseif m.forwardVel >= 38.0 then
        if m.vel.y > 0.0 then
            m.vel.y = 0.0
        end
        m.faceAngle.y = limit_angle(m.faceAngle.y + 0x8000)
        m.particleFlags = m.particleFlags | PARTICLE_VERTICAL_STAR
        return set_mario_action(m, ACT_WALL_SLIDE, 0)
    else
        m.faceAngle.y = limit_angle(m.faceAngle.y + 0x8000)
        return set_mario_action(m, ACT_WALL_SLIDE, 0)
    end

    return set_mario_animation(m, CHAR_ANIM_START_WALLKICK)
end

local function approach_yaw(current, target, maxTurn)
    local diff = (target - current) % 65536
    if diff > 32768 then
        diff = diff - 65536
    end

    if diff > maxTurn then
        diff = maxTurn
    elseif diff < -maxTurn then
        diff = -maxTurn
    end

    return (current + diff) % 65536
end

local function before_set_mario_action(m, action)
    local s = gPlayerSyncTable[m.playerIndex]
    if not s.usingHybird then 
        return action 
    end
    return convert_actions[action] ~= nil and convert_actions[action] or action
end

local function mario_on_set_action(m)
    local s = gPlayerSyncTable[m.playerIndex]
    if not m or m.playerIndex == nil or not gMarioStateExtras[m.playerIndex] then 
        return 
    end
    if not s.usingHybird then 
        return 
    end
    local e = gMarioStateExtras[m.playerIndex]

    if (m.action & ACT_FLAG_MOVING) ~= 0 then
        e.savedWallSlide = false
    end

    if (m.action & ACT_FLAG_AIR) == 0 then
        e.didAirDash = false
        e.didSpin = false
        e.dashPress = 0
    end

    if m.action == ACT_WALL_SLIDE then
        m.vel.y = 0.0
    elseif m.action == ACT_GROUND_POUND and m.prevAction == ACT_SIDE_FLIP then
        m.marioObj.header.gfx.angle.y = limit_angle(m.marioObj.header.gfx.angle.y - 0x8000)
    elseif m.prevAction == ACT_GROUND_POUND and (m.action & ACT_FLAG_SWIMMING) ~= 0 then
        e.GPtWP = true
        set_mario_action(m, ACT_WATER_GROUND_POUND, 0)
    elseif m.action == ACT_WATER_IDLE  then
        e.GPtWP = false
        e.didSwimDive = false
    elseif m.action == ACT_LEDGE_GRAB then
        e.rotAngle = m.forwardVel
    elseif m.action ~= ACT_GRABBED then
        e.grabEscape = 0
        e.grabStruggle = false
        e.lastAnaDir = 0
    elseif m.action == ACT_ROLL then
        mario_set_forward_vel(m, math.max(m.forwardVel * 1.05, 30))
    end
end

local function before_mario_update(m)
    local s = gPlayerSyncTable[m.playerIndex]
    if not m or m.playerIndex == nil or not gMarioStateExtras[m.playerIndex] then 
        return 
    end
    if not s.usingHybird then 
        return 
    end
    local e = gMarioStateExtras[m.playerIndex]
    if e.fakeSaved == true then
        if m.action == e.fakeWroteAction and m.prevAction == e.fakeSavedPrevAction and m.actionTimer == e.fakeSavedActionTimer then
            m.action = e.fakeSavedAction
        end
        e.fakeSaved = false
    end
end

local function mario_update(m)
    local s = gPlayerSyncTable[m.playerIndex]
    if not m or m.playerIndex == nil or not gMarioStateExtras[m.playerIndex] then 
        return 
    end

    if not s.usingHybird then 
        if m.action == ACT_SPIN_JUMP or m.action == ACT_WALL_SLIDE then
            set_mario_action(m, ACT_FREEFALL, 0)
        end
        return 
    end

    local e = gMarioStateExtras[m.playerIndex]

    mario_update_spin_input(m)

    if e.groundPoundCooldown > 0 then
        e.groundPoundCooldown = e.groundPoundCooldown - 1
    end

    --ESCAPE OUT OF BEING GRABBED
    if m.action == ACT_GRABBED then
        if m.heldByObj ~= nil then
            m.pos.x = m.heldByObj.oPosX
            m.pos.y = m.heldByObj.oPosY + 50
            m.pos.z = m.heldByObj.oPosZ
        end

        if math.abs(m.controller.stickX) > math.abs(m.controller.stickY) then
            if m.controller.stickX > 30 then
                anaDir = 1
            elseif m.controller.stickX < -30 then
                anaDir = 2
            end
        else
            if m.controller.stickY > 30 then
                anaDir = 3
            elseif m.controller.stickY < -30 then
                anaDir = 4
            end
        end

        if anaDir ~= 0 and anaDir ~= e.lastAnaDir then
            e.grabStruggle = true
            e.lastAnaDir = anaDir
        elseif e.lastAnaDir == anaDir then
            e.grabStruggle = false
        elseif anaDir == 0 then
            e.lastAnaDir = 0
        end

        if (m.input & INPUT_A_PRESSED) ~= 0 or (m.input & INPUT_B_PRESSED) ~= 0 or e.grabStruggle then
            if e.grabEscape <= 33 then
                e.grabEscape = e.grabEscape + 1
                poundSFXs = {SOUND_GENERAL_SHORT_POUND1, SOUND_GENERAL_SHORT_POUND2, SOUND_GENERAL_SHORT_POUND3, SOUND_GENERAL_SHORT_POUND4, SOUND_GENERAL_SHORT_POUND5, SOUND_GENERAL_SHORT_POUND6}
                play_sound_with_freq_scale(poundSFXs[math.random(1, 6)], m.marioObj.header.gfx.cameraToObject, random_float(0.63, 1.33))
                if e.grabEscape > 1 then
                    play_sound_with_freq_scale(SOUND_MENU_YOSHI_GAIN_LIVES, m.marioObj.header.gfx.cameraToObject, (e.grabEscape / 100) + 0.98)
                end
                if e.grabEscape > 0 and e.grabEscape % 5 == 0 then
                    selVoice = math.random(1, 3)
                    strugVoices = {CHAR_SOUND_EEUH, CHAR_SOUND_UH, CHAR_SOUND_HRMM}
                    play_mario_sound(m, 0, strugVoices[selVoice])
                end
                set_camera_shake_from_hit(SHAKE_SHOCK)
            else
                play_sound_with_freq_scale(SOUND_GENERAL_RACE_GUN_SHOT, m.marioObj.header.gfx.cameraToObject, 2)
                set_mario_action(m, ACT_HARD_FORWARD_AIR_KB, 0)
                m.vel.y = 23
                e.grabEscape = 0
                e.grabStruggle = false
                e.lastAnaDir = 0
                return
            end
        end
    end

    --FASTER MONKEY BARS
    if m.action == ACT_HANG_MOVING then
        local mag = math.sqrt(m.controller.stickX * m.controller.stickX + m.controller.stickY * m.controller.stickY)
        if mag > 5 then
            local stickStrength = math.min(mag / 64, 1)
            m.faceAngle.y = approach_yaw(m.faceAngle.y, m.intendedYaw, 0x800)
            e.hangSpeed = math.min(e.hangSpeed + (0.5 * stickStrength), 10)

            m.pos.x = m.pos.x + stickStrength * e.hangSpeed * sins(m.faceAngle.y)
            m.pos.z = m.pos.z + stickStrength * e.hangSpeed * coss(m.faceAngle.y)
        else
            e.hangSpeed = math.max(e.hangSpeed - 0.8, 0)
        end
    end

    --LONG JUMP GROUND POUND
    if m.action == ACT_LONG_JUMP and (m.input & INPUT_Z_PRESSED) ~= 0 then
        set_mario_action(m, ACT_GROUND_POUND, 0)
    end

    --AIR DIVE
    if m.action == ACT_GROUND_POUND and (m.input & INPUT_B_PRESSED) ~= 0 then
        mario_set_forward_vel(m, 22.2)
        m.vel.y = 37.7
        set_mario_action(m, ACT_DIVE, 0)
        m.faceAngle.y = m.intendedYaw
        play_sound(SOUND_GENERAL_SWISH_WATER, m.marioObj.header.gfx.cameraToObject)
    end

    --GROUND POUND JUMP
    if m.action == ACT_GROUND_POUND_LAND and (m.input & INPUT_A_PRESSED) ~= 0 then
        if e.groundPoundCooldown <= 0 then
            set_mario_action(m, ACT_TRIPLE_JUMP, 0)
            m.faceAngle.y = m.intendedYaw
            m.vel.y = 70.0
            e.groundPoundCooldown = 0
        end
    end

    --GALAXY SPIN / SPIN JUMP
    if SPINACTIONS[m.action] and ((m.controller.buttonPressed & X_BUTTON) ~= 0) then
        if not e.didSpin then 
            if m.action == ACT_IDLE or m.action == ACT_WALKING then
                m.vel.y = 25
                e.fromGround = true
            else
                m.vel.y = 50
            end
            play_sound_with_freq_scale(SOUND_MENU_COLLECT_SECRET, m.marioObj.header.gfx.cameraToObject, 1.75)
            set_mario_action(m, ACT_SPIN_JUMP, 1)
            selVoice = math.random(1, 2)
            play_mario_sound(m, SOUND_ACTION_TWIRL, (selVoice == 1 and CHAR_SOUND_PUNCH_HOO or CHAR_SOUND_HOOHOO))
            mario_set_forward_vel(m,math.abs(m.forwardVel))
            m.faceAngle.y = m.intendedYaw
            e.spinInput = 0
            e.didSpin = true
        end
    end

    --AIR DASH
    if AIRDASHACTIONS[m.action] and not e.didAirDash and (m.input & INPUT_A_PRESSED) ~= 0 then
        if m.forwardVel < 35 and m.vel.y <= 10 then
            m.faceAngle.y = m.intendedYaw
            mario_set_forward_vel(m, m.forwardVel * 1.35)
            set_mario_action(m, ACT_JUMP_KICK, 0)
        end

        if e.dashPress < 1 then
            if m.action & ACT_FLAG_AIR ~= 0 then
                e.dashPress = e.dashPress + 1
            end
        elseif m.forwardVel > 35 and m.vel.y <= 10 then
            m.flags = m.flags & ~MARIO_MARIO_SOUND_PLAYED
            play_sound_with_freq_scale(SOUND_ACTION_FLYING_FAST, m.marioObj.header.gfx.cameraToObject, 2.45)
            play_mario_sound(m, SOUND_ACTION_FLYING_FAST, CHAR_SOUND_YAHOO_WAHA_YIPPEE)
            set_mario_action(m, ACT_AIR_DASH, 0)
            m.faceAngle.y = m.intendedYaw
            e.didAirDash = true
        end
    end

    if WATERACTIONS[m.action] then
        if (m.input & INPUT_Z_PRESSED) ~= 0 and (m.pos.y - m.floorHeight) > 180 then--WATER GROUND POUND
            set_mario_action(m, ACT_WATER_GROUND_POUND, 0)
        end
    end

    --DEBUG SPAWN
    if (m.controller.buttonPressed & Y_BUTTON) ~= 0 then
        --spawn_sync_object(id_bhvKingBobomb, E_MODEL_KING_BOBOMB, m.pos.x - 300, m.pos.y, m.pos.z - 300, nil)
        --set_water_level(0, 10000, true)
    end

    if m.pos then
        e.lastPos.x = m.pos.x
        e.lastPos.y = m.pos.y
        e.lastPos.z = m.pos.z
    end
end

------------------------------------------------------
-- -------------- Commands ----------------------
------------------------------------------------------

local function inputs_command(msg)
    local s = gPlayerSyncTable[0]
    djui_chat_message_create([[
\#b7ffa1\Ground Moveset:
\#ffbb80\(X)\#ffffff\ - Galaxy Spin | \#ff7a7a\(A)\#d1e3ff\ in mid-air\#ffffff\ - Air Dash
\#c0abff\(Z)\#ffdd00\ + \#7591ff\(B)\#ffffff\ - Roll | \#c0abff\(Z)\#ffdd00\ + \#7591ff\(B)\#d1e3ff\ in mid-air\#ffffff\ - Air Dive
\#c0abff\(Z)\#ffdd00\ + \#ff7a7a\(A)\#ffffff\ - Ground Pound Jump

\#b5edff\Water Moveset:
\#7591ff\(B)\#ffffff\ - Galaxy Swim | \#7591ff\(B)\#d1e3ff\ on water surface\#ffffff\ - Dolphin Dive]])
    if not s.usingHybird then
        djui_chat_message_create([[
\#ff7a7a\(!) - You're currently not using the moveset in order to perform these actions.
\#ffdd00\(?) - If you wish to use them, please go into Pause/Mod Menu to enable them.]])
    play_sound(SOUND_MENU_LET_GO_MARIO_FACE, gGlobalSoundSource)
    end
    return true-- = not an global message
end

---------------------- POP-UP ------------------------

local shownOnce = false

hook_event(HOOK_ON_PLAYER_CONNECTED, function(p)
    if shownOnce then return end
    shownOnce = true
    djui_popup_create("\n\\#ffdd00\\Hybrid \\#ffa600\\Moveset\n\\#ffffff\\created by:\n\\#ff91ca\\Sibottle\\#ffffff\\ and \\#46ff40\\MrCloxia\n\n\\#ffffff\\Type \\#ffc75e\\'/inputs'\\#ffffff\\ to know more about the moveset.", 5)
end)

---------------
-- Hooks --
---------------

hook_mod_menu_checkbox("Use moveset", gPlayerSyncTable[0].usingHybird, hybird_cmd)
hook_chat_command("inputs", "- Moveset Info", inputs_command)

hook_event(HOOK_BEFORE_MARIO_UPDATE, before_mario_update)
hook_event(HOOK_MARIO_UPDATE, mario_update)
hook_event(HOOK_MARIO_UPDATE, no_fall_damage)
hook_event(HOOK_ON_SET_MARIO_ACTION, mario_on_set_action)
hook_event(HOOK_BEFORE_SET_MARIO_ACTION, before_set_mario_action)

hook_mario_action(ACT_FAKE_FREEFALL, { every_frame = act_fake_freefall })
hook_mario_action(ACT_SPIN_JUMP, { every_frame = act_spin_jump }, INT_KICK)
hook_mario_action(ACT_WALL_SLIDE, { every_frame = act_wall_slide, gravity = act_wall_slide_gravity })
hook_mario_action(ACT_ROLL, { every_frame = act_roll}, INT_TRIP)
hook_mario_action(ACT_AIR_DASH, { every_frame = act_air_dash}, INT_SLIDE_KICK)
hook_mario_action(ACT_AIR_DASH_END, { every_frame = act_air_dash_end})
hook_mario_action(ACT_DOLPHIN_DIVE, { every_frame = act_dolphin_dive}, INT_SLIDE_KICK)
hook_mario_action(ACT_WATER_SPIN, { every_frame = act_water_spin}, INT_FAST_ATTACK_OR_SHELL)
hook_mario_action(ACT_WATER_GROUND_POUND, { every_frame = act_water_ground_pound }, INT_GROUND_POUND)
hook_mario_action(ACT_WATER_GROUND_POUND_LAND, { every_frame = act_water_ground_pound_land }, INT_GROUND_POUND)
hook_mario_action(ACT_CUSTOM_AIR_HIT_WALL, { every_frame = act_air_hit_wall })

