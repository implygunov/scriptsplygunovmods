---@diagnostic disable: lowercase-global

script_authors('@lua_builer', '@okak_pon_okak')
script_name('Бот на шахту')
script_description('Бот на шахту для Arizona RP')
script_version('1.0')

local sampev = require("samp.events")
local imgui = require("mimgui")
local inicfg = require("inicfg")
local encoding = require("encoding")
local vector = require("vector3d")

encoding.default = 'CP1251'
local u8 = encoding.UTF8

local directIni = 'minebot.ini'
local ini = inicfg.load({
    main = {
        type = 1, --1-тп 2-шаги
        check_players = true
    },
    render = {
        act = true,
        lines = false
    }
}, directIni)
inicfg.save(ini, directIni)

local window_bool = imgui.new.bool(false)
local act_bool = imgui.new.bool(false)
local type_bool = imgui.new.int(ini.main.type)
local render_bool = imgui.new.bool(ini.render.act)
local render_lines_bool = imgui.new.bool(ini.render.lines)
local check_players_bool = imgui.new.bool(ini.main.check_players)
local font = renderCreateFont("Century Gothic", 6, 5)
local syncblock = false
local tp_speed = 0
local mining_resources = {}
local current_target = nil
local mining_start_time = 0
local is_mining = false
local alt = false
local smoothCameraAngle = 0.0

local mainFrame = imgui.OnFrame(
    function() return window_bool[0] end,
    function(player)
        local resX, resY = getScreenResolution()
        local sizeX, sizeY = 500, 400
        imgui.SetNextWindowPos(imgui.ImVec2(resX / 2, resY / 2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
        imgui.SetNextWindowSize(imgui.ImVec2(sizeX, sizeY), imgui.Cond.FirstUseEver)
        imgui.Begin('Mine bot by @lua_builder', window_bool)

        if imgui.Checkbox(u8"Бот активен", act_bool) then
            if act_bool[0] then
                lua_thread.create(bot_main_loop)
            end
        end
        if imgui.RadioButtonIntPtr(u8"Телепорт",type_bool,1) then
            type_bool[0] = 1
            saveIni()
        end
        if imgui.RadioButtonIntPtr(u8"Шагами(может застревать!)",type_bool,2) then
            type_bool[0] = 2
            saveIni()
        end
        if imgui.Checkbox(u8"Проверять игроков рядом с рудой", check_players_bool) then
            saveIni()
        end
        if imgui.Checkbox(u8"Рендер", render_bool) then
            saveIni()
        end
        if render_bool[0] then
            if imgui.Checkbox(u8"Линии в рендере", render_lines_bool) then
                saveIni()
            end
        end
        imgui.End()
    end
)

function main()
    while not isSampAvailable() do wait(0) end
        
    msg("Скрипт загружен. Автор - @lua_builder. Активация - /mbot")
    sampRegisterChatCommand("mbot", function ()
        window_bool[0] = not window_bool[0]
    end)
    while true do
        wait(0)
        mining_resources = {}
        for id = 0, 2048 do
		    if sampIs3dTextDefined(id) then
	 	        local text, color, x, y, z, distance, ignoreWalls, player, vehicle = sampGet3dTextInfoById(id)
	 	        if text:find("Для добычи") then
                    table.insert(mining_resources, {x = x, y = y, z = z, id = id})
	 		        if isPointOnScreen(x, y, z, 3.0) then
	 			        xp, yp, zp = getCharCoordinates(PLAYER_PED)
	 			        x1, y2 = convert3DCoordsToScreen(x, y, z)
	 			        p3, p4 = convert3DCoordsToScreen(xp, yp, zp)
                        if render_bool[0] then
                            local distance = string.format("%.0f", getDistanceBetweenCoords3d(x, y, z, xp, yp, zp))
                            text = (distance)
                            if render_lines_bool[0] then
                                renderDrawLine(x1, y2, p3, p4, 2, 0xB8B8FCFF)
                            end
                            renderFontDrawText(font, text, x1, y2, -1)
                            renderDrawPolygon(x1, y2, 10, 10, 10, 0, 0xB8B8FCFF)
                        end
					end
				end
			end
		end
    end
end

function bot_main_loop()
print(type_bool[0])
    while act_bool[0] do
        wait(100)
        
        if type_bool[0] == 1 and not syncblock and not is_mining then
            local nearest_resource = find_nearest_resource()
            
            if nearest_resource then
                current_target = nearest_resource
                
                if check_players_bool[0] and is_player_near_resource(nearest_resource) then
                    msg("Рядом с рудой есть игрок, ищу другую...")
                    wait(2000)
                else
                    msg("Телепортируюсь к ресурсу...")
                    start_tp(nearest_resource.x, nearest_resource.y, nearest_resource.z)
                    
                    while syncblock do
                        wait(100)
                    end
                    
                    is_mining = true
                    mining_start_time = os.time()
                    print("Начинаю добычу... жду 9 секунд")
                    alt = true
                    wait(1000)
                    sendFrontendClick(8,7,-1, {})
                    wait(9000)
                    
                    is_mining = false
                    current_target = nil
                    msg("Завершил добычу, ищу следующий ресурс...")
                end
            else
                msg("Ресурсы не найдены, жду...")
                wait(5000)
            end
        else
            wait(1000)
        end
        if type_bool[0] == 2 and not syncblock and not is_mining then
            local nearest_resource = find_nearest_resource()
            if nearest_resource then
                current_target = nearest_resource
                
                if check_players_bool[0] and is_player_near_resource(nearest_resource) then
                    msg("Рядом с рудой есть игрок, ищу другую...")
                    wait(2000)
                else
                    msg("Иду к ресурсу...")
                    runToPoint(nearest_resource.x, nearest_resource.y, nearest_resource.z)
                    
                    while syncblock do
                        wait(100)
                    end
                    
                    is_mining = true
                    mining_start_time = os.time()
                    print("Начинаю добычу... жду 9 секунд")
                    alt = true
                    wait(1000)
                    sendFrontendClick(8,7,-1, {})
                    wait(9000)
                    
                    is_mining = false
                    current_target = nil
                    msg("Завершил добычу, ищу следующий ресурс...")
                end
            else
                msg("Ресурсы не найдены, жду...")
                wait(5000)
            end
        else
            wait(1000)
        end 
    end

        
end

function find_nearest_resource()
    if #mining_resources == 0 then
        return nil
    end
    local px, py, pz = getCharCoordinates(PLAYER_PED)
    local nearest = nil
    local min_distance = math.huge
    
    for _, resource in ipairs(mining_resources) do
        local distance = getDistanceBetweenCoords3d(px, py, pz, resource.x, resource.y, resource.z)
        if distance < min_distance then
            min_distance = distance
            nearest = resource
        end
    end
    
    return nearest
end

function is_player_near_resource(resource)
    for i = 0, sampGetMaxPlayerId(false) do
        if sampIsPlayerConnected(i) and i ~= select(2, sampGetPlayerIdByCharHandle(PLAYER_PED)) then
            local result, ped = sampGetCharHandleBySampPlayerId(i)
            if result and doesCharExist(ped) then
                local px, py, pz = getCharCoordinates(ped)
                local distance = getDistanceBetweenCoords3d(px, py, pz, resource.x, resource.y, resource.z)
                if distance < 5.0 then
                    return true
                end
            end
        end
    end
    return false
end

function msg(text)
    sampAddChatMessage("[Mine bot]: "..text, -1)
end

function saveIni()
    ini.main.type = type_bool[0]
    ini.render.act = render_bool[0]
    ini.render.lines = render_lines_bool[0]

    inicfg.save(ini, directIni)
end

--TP
function start_tp(x, y, z)
    coordMaster(x, y, z)
end
function onSendPacket(id)
    if syncblock and (id == 200 or id == 207) then
        return false
    end
end

function coordMaster(x,y,z) 
    local pos = {x,y,z}
    local char = {getCharCoordinates(PLAYER_PED)}
    local vecDist = getDistanceBetweenCoords3d(char[1], char[2], char[3], pos[1], pos[2], pos[3])
    local v = isCharInAnyCar(PLAYER_PED) and storeCarCharIsInNoSave(PLAYER_PED) or -1
    local coef = 4
    local start = os.time()
    local w = 50
    local step = 0
    local stepLimit = 15
    syncblock = true
    while getDistanceBetweenCoords3d(char[1], char[2], char[3], pos[1], pos[2], pos[3]) >= coef and syncblock do
        printStringNow(math.floor(100 - (getDistanceBetweenCoords3d(char[1], char[2], char[3], pos[1], pos[2], pos[3]) / vecDist) * 100).."% = "..tp_speed.."ms - coef -  "..coef, 1555)
        local vector = vector(pos[1] - char[1], pos[2] - char[2], pos[3] - char[3])
        vector:normalize()
        char[1] = char[1] + vector.x * coef
        char[2] = char[2] + vector.y * coef
        char[3] = char[3] + vector.z * coef 
        if isCharInAnyCar(PLAYER_PED) then
            coef = tp_speed == 2 and 7 or 8
            SendVehicleSync(char[1], char[2], char[3])
            w = 50
            stepLimit = -1
        elseif isCharOnFoot(PLAYER_PED) then
            coef = 4
            sendPlayerSync(char[PLAYER_PED], char[2], char[3])
            w = 60
            stepLimit = -1
        end
        tp_speed = tp_speed < (isCharInAnyCar(PLAYER_PED) and 2 or 0.7) and tp_speed + 0.02 or tp_speed 
        wait(w)
        
        step = step + 1
        if step == stepLimit then
            step = 0
            wait(300) 
        end
        if getDistanceBetweenCoords3d(char[1], char[2], char[3], pos[1], pos[2], pos[3]) <= coef then
            tp_speed = 0
            syncblock = false
            setCharCoordinates(PLAYER_PED,x,y,z)
        end
    end
end

function getTargetBlipCoordinatesFixed()
    local bool, x, y, z = getTargetBlipCoordinates(); if not bool then return false end
    requestCollision(x, y); loadScene(x, y, z)
    local bool, x, y, z = getTargetBlipCoordinates()
    return bool, x, y, z
end

function SendVehicleSync(x,y,z)
    local data = samp_create_sync_data("vehicle")
    data.vehicleId = select(2,sampGetVehicleIdByCarHandle(storeCarCharIsInNoSave(PLAYER_PED)))
    data.position = {x,y,z}
    data.moveSpeed = {tp_speed,tp_speed,0.1}
    data.vehicleHealth = getCarHealth(storeCarCharIsInNoSave(PLAYER_PED))
    data.send()
end

function sendPlayerSync(x, y, z)
	local data = samp_create_sync_data("player")
    data.position = {x,y,z}
    data.moveSpeed = {tp_speed,0.1,0.1}
    data.send()
end

function samp_create_sync_data(sync_type, copy_from_player)
    local ffi = require 'ffi'
    local sampfuncs = require 'sampfuncs'
    local raknet = require 'samp.raknet'
    require 'samp.synchronization'

    copy_from_player = copy_from_player or true
    local sync_traits = {
        player = {'PlayerSyncData', raknet.PACKET.PLAYER_SYNC, sampStorePlayerOnfootData},
        vehicle = {'VehicleSyncData', raknet.PACKET.VEHICLE_SYNC, sampStorePlayerIncarData}
    }
    local data = ffi.new('struct ' .. sync_traits[sync_type][1], {})
    local func_send = function()
        local bs = raknetNewBitStream()
        raknetBitStreamWriteInt8(bs, sync_traits[sync_type][2])
        raknetBitStreamWriteBuffer(bs, tonumber(ffi.cast('uintptr_t', ffi.new('struct ' .. sync_traits[sync_type][1] .. '*', data))), ffi.sizeof(data))
        raknetSendBitStreamEx(bs, sampfuncs.HIGH_PRIORITY, sampfuncs.UNRELIABLE_SEQUENCED, 1)
        raknetDeleteBitStream(bs)
    end
    return setmetatable({send = func_send}, {__index = function(t, index) return data[index] end, __newindex = function(t, index, value) data[index] = value end})
end

--Auto capcha
addEventHandler('onReceivePacket', function(id, bs, ...) 
  if id == 220 then
    raknetBitStreamIgnoreBits(bs, 8) 
    local packetType = raknetBitStreamReadInt8(bs)  
    if packetType == 84 then
      local interfaceid = raknetBitStreamReadInt8(bs)
      local subid = raknetBitStreamReadInt8(bs)
      local len = raknetBitStreamReadInt16(bs) 
      local encoded = raknetBitStreamReadInt8(bs)
      local json = (encoded ~= 0) and raknetBitStreamDecodeString(bs, len + encoded) or raknetBitStreamReadString(bs, len)
      
      if tonumber(interfaceid) == 25 then
        lua_thread.create(function()
          
          sendFrontendClick(25, 0, -1, "{}")
          sendFrontendClick(25, 0, -1, "{}")
          sendFrontendClick(25, 0, -1, "{}")
          sendFrontendClick(25, 0, -1, "{}")
        end)
      end 
    end
    if packetType == 62 then
      local interfaceid = raknetBitStreamReadInt8(bs)
      local toggle = raknetBitStreamReadBool(bs)
      
      if tonumber(interfaceid) == 25 then
        lua_thread.create(function()
          
          sendFrontendClick(25, 0, -1, "{}")
          sendFrontendClick(25, 0, -1, "{}")
          sendFrontendClick(25, 0, -1, "{}")
          sendFrontendClick(25, 0, -1, "{}")
        end)
      end 
    end
  end
end)

function sendFrontendClick(interfaceid, id, subid, json_str)
  local bs = raknetNewBitStream()
  raknetBitStreamWriteInt8(bs, 220)
  raknetBitStreamWriteInt8(bs, 63)
  raknetBitStreamWriteInt8(bs, interfaceid)
  raknetBitStreamWriteInt32(bs, id)
  raknetBitStreamWriteInt32(bs, subid)
  raknetBitStreamWriteInt16(bs, #json_str)
  raknetBitStreamWriteString(bs, json_str)
  raknetSendBitStreamEx(bs, 1, 10, 1)
  raknetDeleteBitStream(bs)
end

function sampev.onSendPlayerSync(data)
	if alt then
		lua_thread.create(function()
			data.keys.unknown_walkSlow = 1
			wait(1)
			data.keys.unknown_walkSlow = 0
			alt = false
		end)
	end
end

function runToPoint(tox, toy, z1)
    local x, y, z = getCharCoordinates(PLAYER_PED)
    local angle = getHeadingFromVector2d(tox - x, toy - y)
    local targetAngle = math.rad(angle - 90)
    
    if smoothCameraAngle == 0.0 then
        smoothCameraAngle = targetAngle
    else
        local diff = targetAngle - smoothCameraAngle
        if diff > math.pi then
            diff = diff - 2 * math.pi
        elseif diff < -math.pi then
            diff = diff + 2 * math.pi
        end
        smoothCameraAngle = smoothCameraAngle + diff * 0.1
    end
    
    if getDistanceBetweenCoords2d(x, y, tox, toy) > 1 then 
        setCameraPositionUnfixed(0, smoothCameraAngle) 
    end
    stopRun = false
    
    setGameKeyState(16, 255)
    
    while getDistanceBetweenCoords2d(x, y, tox, toy) > 1 and not stopRun do
        setGameKeyState(1, -255)
        setGameKeyState(16, -255)
        wait(1)
        x, y, z = getCharCoordinates(PLAYER_PED)
        angle = getHeadingFromVector2d(tox - x, toy - y)
        targetAngle = math.rad(angle - 90)
        
        local diff = targetAngle - smoothCameraAngle
        if diff > math.pi then
            diff = diff - 2 * math.pi
        elseif diff < -math.pi then
            diff = diff + 2 * math.pi
        end
        smoothCameraAngle = smoothCameraAngle + diff * 0.1
        
        setCameraPositionUnfixed(0, smoothCameraAngle)
        if stopRun then break end
    end
    setGameKeyState(16, 0)
end