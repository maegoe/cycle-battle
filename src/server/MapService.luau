--!strict
local MapService = {}

function MapService.Init()
	print("[MapService] Generating Map...")
	MapService.GenerateMap()
end

function MapService.Start()
	-- 런타임 로직이 필요하면 여기에 작성
end

function MapService.GenerateMap()
	local center = Vector3.new(0, 10, 0)
	local radiusFromCenter = 60
	local islandRadius = 20
	local islandHeight = 2
	
	local islandPositions = {}
	
	-- 1. 섬 3개 생성 (정삼각형 배치)
	for i = 1, 3 do
		local angle = math.rad((i - 1) * 120)
		local offsetX = math.cos(angle) * radiusFromCenter
		local offsetZ = math.sin(angle) * radiusFromCenter
		local position = center + Vector3.new(offsetX, 0, offsetZ)
		
		table.insert(islandPositions, position)
		
		local island = Instance.new("Part")
		island.Name = "Island_" .. i
		island.Shape = Enum.PartType.Cylinder
		island.Anchored = true
		island.Material = Enum.Material.Grass
		island.Color = Color3.fromRGB(75, 151, 75) -- 초록색
		-- Cylinder는 X축이 높이(두께)입니다.
		island.Size = Vector3.new(islandHeight, islandRadius * 2, islandRadius * 2)
		-- 눕혀서 평평하게 만들기 위해 Z축으로 90도 회전
		island.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
		island.Parent = workspace
	end
	
	-- 2. 다리 연결 (1-2, 2-3, 3-1)
	for i = 1, 3 do
		local p1 = islandPositions[i]
		local p2 = islandPositions[(i % 3) + 1]
		
		local distance = (p1 - p2).Magnitude
		local midPoint = (p1 + p2) / 2
		
		local bridge = Instance.new("Part")
		bridge.Name = "Bridge"
		bridge.Anchored = true
		bridge.Material = Enum.Material.Wood
		bridge.Color = Color3.fromRGB(139, 69, 19) -- 갈색
		bridge.Size = Vector3.new(10, 1, distance)
		bridge.CFrame = CFrame.lookAt(midPoint, p2)
		bridge.Parent = workspace
	end
end

return MapService