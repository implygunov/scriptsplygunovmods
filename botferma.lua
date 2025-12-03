--автор Kontix
local state = false
local state_taked = false
local state_harvest = false
local wheat_dist = 1.5
local step = {200, 400}
local smoothCameraAngle = 0.0
function GetNearWheat(wheat)
	local table, dist
	for i, k in pairs(wheat) do
		if (not k.peds or (k.dist < wheat_dist and state_harvest)) and (table == nil or k.dist < dist) then
			table, dist = k, k.dist
		end
	end
	return table
end

function WalkEngine(bool, x, y, z)
	state_harvest = true

	setGameKeyState(1,-255)
	if bool then
		runToPoint(x, y, z)
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
    
    setGameKeyState(32, 255)
    
    while getDistanceBetweenCoords2d(x, y, tox, toy) > 1 and not stopRun do
        setGameKeyState(1, -255)
        setGameKeyState(32, 255)
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
    setGameKeyState(32, 0)
end
function StartWork()
	state = not state
	sampAddChatMessage(state and "{DDECFF}Бот на ферму {55FF00}начал работу" or "{DDECFF}Бот на ферму {FF0000}завершил работу", -1)
	state_taked = false
end

function EngineWork()
	local x,y,z = getCharCoordinates(PLAYER_PED)

	if not state_taked then
		local wheat = {}
		for id = 0, 2047 do
			if sampIs3dTextDefined(id) then
				local str,col,x1,y1,z1 = sampGet3dTextInfoById(id)
				if str:find("Куст на ферме") then
					table.insert(wheat, {id = id, x = x1, y = y1, z = z1, peds = findAllRandomCharsInSphere(x1,y1,z1,3,false,true), dist = getDistanceBetweenCoords3d(x,y,z,x1,y1,z1)})
				end
			end
		end

		if #wheat == 0 then return end
		wheat = GetNearWheat(wheat)

		if wheat.dist > wheat_dist then
			--setCameraPositionUnfixed(-0.3, math.rad(getHeadingFromVector2d(wheat.x-x, wheat.y-y))+4.7)
		
			if wheat.dist > wheat_dist and not state_harvest then
				WalkEngine(true, wheat.x, wheat.y, wheat.z)
			else
				WalkEngine(false)
			end
		elseif not state_harvest then
			if sampGetPlayerAnimationId(select(2, sampGetPlayerIdByCharHandle(PLAYER_PED))) == 163 then
				state_harvest = true
			end
		end
	else
		local x1, y1, z1 = -105.60591125488, 100.61192321777, 3.1171875
		if getDistanceBetweenCoords3d(x,y,z,x1,y1,z1) > 1.5 then
			--setCameraPositionUnfixed(-0.3, math.rad(getHeadingFromVector2d(x1-x, y1-y))+4.7)
			WalkEngine(true, x1, y1, z1)
		end
	end
end

function main()
	math.randomseed(os.time())
	while not isSampAvailable() or not sampIsLocalPlayerSpawned() do wait(0) end
	sampAddChatMessage("{E0BA29}[Ferma Bot] {FFFFFF} Бот на ферму загружен! Активация: {E0BA29} /ferma", -1)
	sampRegisterChatCommand("ferma", StartWork)
	while true do wait(0)
		if state then
			EngineWork()
		end
    end
end

function onReceiveRpc(id, bs)
	if state then
		if id == 113 then
			local playerId = raknetBitStreamReadInt16(bs)
			local index = raknetBitStreamReadInt32(bs)
			local create = raknetBitStreamReadBool(bs)
			local model = raknetBitStreamReadInt32(bs)

			if not state_taked and select(2, sampGetPlayerIdByCharHandle(PLAYER_PED)) == playerId and model == 2901 then
				state_taked = true
			end
		elseif id == 93 then
			local color = raknetBitStreamReadInt32(bs)
			local len = raknetBitStreamReadInt32(bs)
			local str = raknetBitStreamReadString(bs, len)

			if state_taked and str:find("{FF6347} Теперь Ваш навык фермерства") then
				state_taked = false
				state_harvest = false
			end
		end
	end
end

function sendCustomPacket(text)
    local bs = raknetNewBitStream()
    raknetBitStreamWriteInt8(bs, 220)
    raknetBitStreamWriteInt8(bs, 18)
    raknetBitStreamWriteInt16(bs, #text)
    raknetBitStreamWriteString(bs, text)
    raknetBitStreamWriteInt32(bs, 0)
    raknetSendBitStream(bs)
    raknetDeleteBitStream(bs)
end

addEventHandler('onReceivePacket', function(id, bs, ...) 
		if id == 220 then
			raknetBitStreamIgnoreBits(bs, 8) 
			type = raknetBitStreamReadInt8(bs)
			if type == 84 then
				interfaceid = raknetBitStreamReadInt8(bs)
				subid = raknetBitStreamReadInt8(bs)
				
				
				if interfaceid == 81 and subid == 0 then
				    sendFrontendClick(81,0,0,{})
				state_taked = true
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