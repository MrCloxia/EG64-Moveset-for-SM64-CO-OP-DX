-- name:\\#9457ff\\Elevator Movement 64
-- incompatible: moveset
-- description:A moveset based on the "Super Mario 64 Land" Romhack which is excellent and features over 131 stars, It also contains 2 commands and a popup message (One for all and another for the host). the pop-up message made by \\#55a400\\Blither\\#8a1915\\Dev\\#dcdcdc\\, It is currently on version 2.21, And this is the final version of the moveset. One thing I want to say is that a large part of the code was done by ManIsCat2, Big credit to that person. The moveset includes: \n\n\\#fff305\\Spin Jump [X Button] \n\\#ff05ff\\Ground Pound Jump [A + Z + A] \n\\#00ff00\\Air Dive [Z + B] \n\\#0008f2\\Wall Slide \n\\#0785f2\\No Fall Damage. \n\n\\#dcdcdc\\The developer is:\n\\#ff5400\\MrCho\\#00ff00\\quin7 \n\\#b91c37\\River64\\#ff9000\\Espanol\\#545454\\! \\#dcdcdc\\(Beta Tester)

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
ACT_GROUND_POUND_JUMP = allocate_mario_action(ACT_GROUP_AIRBORNE | ACT_FLAG_AIR | ACT_FLAG_ALLOW_VERTICAL_WIND_ACTION)
ACT_SPIN_JUMP = allocate_mario_action(ACT_GROUP_AIRBORNE | ACT_FLAG_AIR | ACT_FLAG_ALLOW_VERTICAL_WIND_ACTION)
ACT_WALL_SLIDE = allocate_mario_action(ACT_GROUP_AIRBORNE | ACT_FLAG_AIR | ACT_FLAG_MOVING | ACT_FLAG_ALLOW_VERTICAL_WIND_ACTION)
ACT_ROLL = allocate_mario_action(ACT_GROUP_MOVING)
ACT_AIR_DASH = allocate_mario_action(ACT_GROUP_AIRBORNE | ACT_FLAG_AIR | ACT_FLAG_ALLOW_VERTICAL_WIND_ACTION)
local ACT_CUSTOM_AIR_HIT_WALL = allocate_mario_action(ACT_GROUP_AIRBORNE | ACT_FLAG_AIR)

local PACKET_MOVESET = 100

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
    [ACT_SIDE_FLIP] = true,
    [ACT_FLUTTER_KICK] = true,
    [ACT_GROUND_POUND_JUMP] = true,
    [ACT_DIVE] = true,
    [ACT_FORWARD_ROLLOUT] = true,
    [ACT_BACKWARD_ROLLOUT] = true,
    [ACT_WALL_KICK_AIR] = true,
    [ACT_BACKFLIP] = true,
    [ACT_FREEFALL] = true,
    [ACT_FLYING] = true,
    [ACT_WATER_JUMP] = true
}
local fromGround = false

local ANTIDASHACTIONS = {
    [ACT_WALL_KICK_AIR] = true,
    [ACT_GROUND_POUND] = true,
    [ACT_FREEFALL] = true
}

local dashPressy = 0

local gMarioStateExtras = {}

for i = 0, (MAX_PLAYERS - 1) do
    gMarioStateExtras[i] = {}
    local m = gMarioStates[i]
    local e = gMarioStateExtras[i]
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
    e.didSpin = false
    e.didAirDash = false
end

local function limit_angle(a)
    return (a + 0x8000) % 0x10000 - 0x8000
end

-------------------------------------
-- Fall Damage Removal --
-------------------------------------

function no_fall_damage(m)
    if not m or m.playerIndex == nil then return end
    if gGlobalSyncTable.movesetEnabled == false then return end
    m.peakHeight = m.pos.y
end

--------------------------------------------
---------- Spin Jump -----------------
--------------------------------------------

local function mario_update_spin_input(m)
    if not m or m.playerIndex == nil or not gMarioStateExtras[m.playerIndex] then return end
    if (m.action & ACT_FLAG_AIR) == 0 then return end
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
    common_air_action_step(m, ACT_FREEFALL, MARIO_ANIM_GENERAL_FALL, AIR_STEP_CHECK_LEDGE_GRAB | AIR_STEP_CHECK_HANG)
end

local function act_spin_jump(m)--GALAXY SPIN / SPIN JUMP
    if not m or m.playerIndex == nil or not gMarioStateExtras[m.playerIndex] then
        return false
    end

    m.marioBodyState.handState = MARIO_HAND_OPEN

    update_air_without_turn(m);
    local stepResult = perform_air_step(m, 0)

    if stepResult == AIR_STEP_LANDED then
        if fromGround then
            fromGround = false
        else
            set_mario_action(m, ACT_FREEFALL, 0)
        end
        return
    end

    local e = gMarioStateExtras[m.playerIndex]

    if m.actionTimer == 0 then
        e.spinSpeed = 1
    end

    if e.spinSpeed > 0.02 then
        if stepResult == AIR_STEP_HIT_WALL and not fromGround then
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
        set_mario_animation(m, MARIO_ANIM_GENERAL_FALL)
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
    common_slide_action_with_jump(m,ACT_WALKING,ACT_LONG_JUMP,ACT_FREEFALL,CHAR_ANIM_FORWARD_SPINNING)
    mario_set_forward_vel(m, m.forwardVel * 1.05)

    if (m.input & INPUT_B_PRESSED) ~= 0 then
        spawn_sync_object(id_bhvHorStarParticleSpawner, 0, m.pos.x,m.pos.y,m.pos.z,nil)
        mario_set_forward_vel(m, m.forwardVel + 30)
        play_sound(SOUND_ACTION_TWIRL, m.marioObj.header.gfx.cameraToObject)
        if (m.forwardVel > 120) then
            mario_set_forward_vel(m, 120)
        end
    else
        mario_set_forward_vel(m, m.forwardVel - 0.5)
    end

    if (m.forwardVel < 10) then
        if (m.forwardVel < 0) and AIR_STEP_HIT_WALL then
            set_mario_action(m, ACT_BACKWARD_GROUND_KB, 0)
        else
            set_mario_action(m, ACT_START_CROUCHING, 0)
        end
    end
end

local function act_air_dash(m)--AIR DASH
    common_air_action_step(m, ACT_JUMP_LAND, MARIO_ANIM_SLIDE_KICK, AIR_STEP_NONE)
    local stepResult = perform_air_step(m, 0)

    if m.actionTimer == 0 then
        mario_set_forward_vel(m, 65)
    else
        mario_set_forward_vel(m, math.max(m.forwardVel - 4, 5))
    end
    m.vel.y = -5
    set_mario_particle_flags(m, PARTICLE_DUST, 0)

    if stepResult == AIR_STEP_HIT_WALL then
        stop_sounds_from_source(m.marioObj.header.gfx.cameraToObject)
        play_sound(((m.flags & MARIO_METAL_CAP) ~= 0 and SOUND_ACTION_METAL_BONK or SOUND_ACTION_BONK), m.marioObj.header.gfx.cameraToObject)
        set_mario_action(m, ACT_BACKWARD_AIR_KB, 0)
        spawn_sync_object(id_bhvHorStarParticleSpawner, 0, m.pos.x,m.pos.y,m.pos.z,nil)
    else
        if m.actionTimer >= 20 or (m.controller.buttonDown & A_BUTTON) == 0 then
            stop_sounds_from_source(m.marioObj.header.gfx.cameraToObject)
            set_mario_action(m, ACT_FREEFALL, 0)
        end
        m.actionTimer = m.actionTimer + 1
    end
end

--------------------------------------
-- --------- Wall Slide ----------
--------------------------------------

function act_wall_slide(m)
    if not m or m.playerIndex == nil or not gMarioStateExtras[m.playerIndex] then return 0 end
    local e = gMarioStateExtras[m.playerIndex]
    e.savedWallSlideHeight = m.pos.y
    e.savedWallSlide = true

    if m.actionTimer == 0 then
        e.animFrame = 0
    end

    if (m.input & INPUT_A_PRESSED) ~= 0 then
        m.vel.y = 52.0
        return set_mario_action(m, ACT_WALL_KICK_AIR, 0)
    end

    mario_set_forward_vel(m, -1)
    m.particleFlags = m.particleFlags | PARTICLE_DUST

    play_sound(SOUND_MOVING_TERRAIN_SLIDE + m.terrainSoundAddend, m.marioObj.header.gfx.cameraToObject)
    set_mario_animation(m, MARIO_ANIM_START_WALLKICK)

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
    if m.vel.y < -15 then
        m.vel.y = -15
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
        if CAT == nil or gPlayerSyncTable[m.playerIndex].activePowerup ~= CAT then
            m.faceAngle.y = limit_angle(m.faceAngle.y + 0x8000)
            m.particleFlags = m.particleFlags | PARTICLE_VERTICAL_STAR
            return set_mario_action(m, ACT_WALL_SLIDE, 0)
        else
            return set_mario_action(m, ACT_CAT_CLIMB, 0)
        end
    else
        m.faceAngle.y = limit_angle(m.faceAngle.y + 0x8000)
        return set_mario_action(m, ACT_WALL_SLIDE, 0)
    end

    return set_mario_animation(m, MARIO_ANIM_START_WALLKICK)
end

local convert_actions = {
    [ACT_AIR_HIT_WALL] = ACT_CUSTOM_AIR_HIT_WALL,
    [ACT_SLIDE_KICK] = ACT_ROLL
}

local function before_set_mario_action(m, action)
    if gGlobalSyncTable.movesetEnabled == false then return action end
    return convert_actions[action] ~= nil and convert_actions[action] or action
end

local function act_ground_pound_jump(m)
    play_mario_sound(m, SOUND_ACTION_TERRAIN_JUMP, CHAR_SOUND_YAHOO)

    -- Ground Pound With Z
    if (m.controller.buttonPressed & Z_TRIG) ~= 0 then
        return set_mario_action(m, ACT_GROUND_POUND, 0)
    end

    -- Now not disabled Input B
    if (m.input & INPUT_B_PRESSED) ~= 0 then
        mario_set_forward_vel(m, math.max(m.forwardVel, 20.0))
        return set_mario_action(m, ACT_DIVE, 0)
    end

    common_air_action_step(m, ACT_TRIPLE_JUMP_LAND, MARIO_ANIM_TRIPLE_JUMP, 0)
    m.actionTimer = m.actionTimer + 1
    return 0
end

local function mario_on_set_action(m)
    if not m or m.playerIndex == nil or not gMarioStateExtras[m.playerIndex] then return end
    if gGlobalSyncTable.movesetEnabled == false then return end
    local e = gMarioStateExtras[m.playerIndex]

    if (m.action & ACT_FLAG_MOVING) ~= 0 then
        e.savedWallSlide = false
    end

    if (m.action & ACT_FLAG_AIR) == 0 then
        e.didAirDash = false
        e.didSpin = false
        dashPressy = 0
    end

    if m.action == ACT_GROUND_POUND_JUMP then
        m.vel.y = 65.0
    elseif m.action == ACT_WALL_SLIDE then
        m.vel.y = 0.0
    elseif m.action == ACT_GROUND_POUND and m.prevAction == ACT_SIDE_FLIP then
        m.marioObj.header.gfx.angle.y = limit_angle(m.marioObj.header.gfx.angle.y - 0x8000)
    elseif m.action == ACT_LEDGE_GRAB then
        e.rotAngle = m.forwardVel
    elseif m.action == ACT_ROLL then
        mario_set_forward_vel(m, 22.2)
    end
end

local function before_mario_update(m)
    if not m or m.playerIndex == nil or not gMarioStateExtras[m.playerIndex] then return end
    if gGlobalSyncTable.movesetEnabled == false then return end
    local e = gMarioStateExtras[m.playerIndex]
    if e.fakeSaved == true then
        if m.action == e.fakeWroteAction and m.prevAction == e.fakeSavedPrevAction and m.actionTimer == e.fakeSavedActionTimer then
            m.action = e.fakeSavedAction
        end
        e.fakeSaved = false
    end
end

local function mario_update(m)
    if not m or m.playerIndex == nil or not gMarioStateExtras[m.playerIndex] then return end

    if gGlobalSyncTable.movesetEnabled == false then 
        if m.action == ACT_SPIN_JUMP or m.action == ACT_WALL_SLIDE or m.action == ACT_GROUND_POUND_JUMP then
            set_mario_action(m, ACT_FREEFALL, 0)
        end
        return 
    end

    local e = gMarioStateExtras[m.playerIndex]

    mario_update_spin_input(m)

    if e.groundPoundCooldown > 0 then
        e.groundPoundCooldown = e.groundPoundCooldown - 1
    end

    --AIR DIVE
    if m.action == ACT_GROUND_POUND and (m.input & INPUT_B_PRESSED) ~= 0 then
        mario_set_forward_vel(m, 22.2)
        m.vel.y = 37.7
        set_mario_action(m, ACT_DIVE, 0)
        m.faceAngle.y = m.intendedYaw
        play_sound(SOUND_GENERAL_SWISH_WATER, m.marioObj.header.gfx.cameraToObject)
    end

    --LONG JUMP GROUNDPOUND
    if m.action == ACT_LONG_JUMP and (m.input & INPUT_Z_PRESSED) ~= 0 then
        set_mario_action(m, ACT_GROUND_POUND, 0)
    end

    --GALAXY SPIN / SPIN JUMP
    if SPINACTIONS[m.action] and ((m.controller.buttonPressed & X_BUTTON) ~= 0) then
        if not e.didSpin then 
            if m.action == ACT_IDLE or m.action == ACT_WALKING then
                m.vel.y = 25
                fromGround = true
            else
                m.vel.y = 50
            end
            set_mario_action(m, ACT_SPIN_JUMP, 1)
            play_sound_with_freq_scale(SOUND_MENU_COLLECT_SECRET, m.marioObj.header.gfx.cameraToObject, 1.75)
            selVoice = math.random(1,2)
            play_mario_sound(m, SOUND_ACTION_TWIRL, (selVoice == 1 and CHAR_SOUND_PUNCH_HOO or CHAR_SOUND_HOOHOO))
            m.faceAngle.y = m.intendedYaw
            e.spinInput = 0
            e.didSpin = true
        end
    end

    --GROUND POUND JUMP
    if m.action == ACT_GROUND_POUND_LAND and (m.input & INPUT_A_PRESSED) ~= 0 then
        if e.groundPoundCooldown <= 0 then
            set_mario_action(m, ACT_GROUND_POUND_JUMP, 0)
            m.faceAngle.y = m.intendedYaw
            m.vel.y = 70.0
            e.groundPoundCooldown = 0
        end
    end

    if not ANTIDASHACTIONS[m.action] then
        if (m.input & INPUT_A_PRESSED) ~= 0 then
            if m.action & ACT_FLAG_AIR ~= 0 then
                dashPressy = dashPressy + 1
            end
        end
    else
        dashPressy = 0
    end

    --AIR DASH
    if not ANTIDASHACTIONS[m.action] and dashPressy >= 2 and not e.didAirDash and (m.input & INPUT_A_DOWN) ~= 0 and m.forwardVel > 33 then
        m.flags = m.flags & ~MARIO_MARIO_SOUND_PLAYED
        play_sound_with_freq_scale(SOUND_ACTION_FLYING_FAST, m.marioObj.header.gfx.cameraToObject, 2.45)
        play_mario_sound(m, SOUND_ACTION_FLYING_FAST, CHAR_SOUND_YAHOO_WAHA_YIPPEE)
        set_mario_action(m, ACT_AIR_DASH, 0)
        m.faceAngle.y = m.intendedYaw
        e.didAirDash = true
    end

    --play_sound_with_freq_scale(SOUND_ACTION_SWIM_FAST, m.marioObj.header.gfx.cameraToObject, 1.75) Saving this for Galaxy Spin in the water

    if m.pos then
        e.lastPos.x = m.pos.x
        e.lastPos.y = m.pos.y
        e.lastPos.z = m.pos.z
    end
end


------------------------------------------------------
-- -------------- Commands ----------------------
------------------------------------------------------

if gGlobalSyncTable.movesetEnabled == nil then
    gGlobalSyncTable.movesetEnabled = true
end

local function moveset_packet(data)
    if data.type ~= PACKET_MOVESET then return end

    if data.enabled then
        djui_chat_message_create("Moveset \\#ff5400\\64 \\#00ff00\\Land \\#00d2f2\\ON")
    else
        djui_chat_message_create("Moveset \\#ff5400\\64 \\#00ff00\\Land \\#ff0000\\OFF")
    end
end

local function toggle_moveset_command(msg)
    if not network_is_server() then
        djui_chat_message_create("\\#ff0000\\You are not the host, please don't try this command again, Ok?")
        return true
    end

    gGlobalSyncTable.movesetEnabled = not gGlobalSyncTable.movesetEnabled

    local packet = {
        type = PACKET_MOVESET,
        enabled = gGlobalSyncTable.movesetEnabled
    }

    network_send(true, packet)
    moveset_packet(packet)

    return true
end

local function inputs_command(msg)
    djui_chat_message_create("\\#00ff00\\English:")
    djui_chat_message_create("X = Galaxy Spin, Z + B on ground = Roll, Z + B in mid-air = Air Dive, A + Z + A = Ground Pound Jump ||| No Fall Damage And Wall Slide")
    return true -- = not mesagge global
end

---------------------- POP-UP ------------------------

local shownOnce = false

hook_event(HOOK_ON_PLAYER_CONNECTED, function(p)
    if shownOnce then return end

    shownOnce = true

    djui_popup_create(
        "\n Elevator Movement 64 created by:\n\\#ff91ca\\Sibottle\n\\#46ff40\\MrCloxia \n\n\\#dcdcdc\\If you want to know more about the moveset, write: \n/inputs",
        6
    )
end)

---------------
-- Hooks --
---------------

hook_event(HOOK_ON_PACKET_RECEIVE, moveset_packet)
hook_event(HOOK_BEFORE_MARIO_UPDATE, before_mario_update)
hook_event(HOOK_MARIO_UPDATE, mario_update)
hook_event(HOOK_MARIO_UPDATE, no_fall_damage)
hook_event(HOOK_ON_SET_MARIO_ACTION, mario_on_set_action)
hook_event(HOOK_BEFORE_SET_MARIO_ACTION, before_set_mario_action)

hook_mario_action(ACT_FAKE_FREEFALL, { every_frame = act_fake_freefall })
hook_mario_action(ACT_SPIN_JUMP, { every_frame = act_spin_jump }, INT_KICK)
hook_mario_action(ACT_GROUND_POUND_JUMP, { every_frame = act_ground_pound_jump })
hook_mario_action(ACT_WALL_SLIDE, { every_frame = act_wall_slide, gravity = act_wall_slide_gravity })
hook_mario_action(ACT_ROLL, { every_frame = act_roll}, INT_TRIP)
hook_mario_action(ACT_AIR_DASH, { every_frame = act_air_dash}, INT_SLIDE_KICK)
hook_mario_action(ACT_CUSTOM_AIR_HIT_WALL, { every_frame = act_air_hit_wall })

--hook_chat_command("inputs", "- Moveset Info", inputs_command)
--hook_chat_command("moveset", "- Toggle The Moveset", toggle_moveset_command)