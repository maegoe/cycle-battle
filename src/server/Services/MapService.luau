--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local MapService = {}
local islandPositions = {} -- GenerateMap과 SpawnItem에서 공유하기 위해 위로 이동

function MapService.Init()
	print("[MapService] Generating Map...")
	MapService.GenerateMap()
	
	-- 아이템 사용을 위한 RemoteEvent 생성
	if not ReplicatedStorage:FindFirstChild("UseItem") then
		local re = Instance.new("RemoteEvent")
		re.Name = "UseItem"
		re.Parent = ReplicatedStorage
	end

	-- 맵(Y=10)에서 60스터드 아래(-50)로 떨어지면 리스폰(사망) 처리
	workspace.FallenPartsDestroyHeight = -30
	Players.RespawnTime = 0 -- 리스폰 딜레이 제거

	-- 배경 음악(BGM) 추가
	local bgm = Instance.new("Sound")
	bgm.Name = "BackgroundMusic"
	bgm.SoundId = "rbxassetid://1843404009" -- Upbeat Music
	bgm.Looped = true
	bgm.Volume = 0.5
	bgm.Parent = workspace
	bgm:Play()
end

function MapService.Start()
	-- 점수 1등에게 이펙트 부여하는 함수
	local function UpdateTopPlayerEffect()
		local topPlayer = nil
		local maxScore = -1

		-- 현재 최고 점수와 플레이어 찾기
		for _, p in ipairs(Players:GetPlayers()) do
			local ls = p:FindFirstChild("leaderstats")
			local s = ls and ls:FindFirstChild("Score (1000 Win)")
			if s and s.Value > maxScore then
				maxScore = s.Value
				topPlayer = p
			end
		end

		-- 이펙트 적용 및 제거
		for _, p in ipairs(Players:GetPlayers()) do
			local char = p.Character
			local root = char and char:FindFirstChild("HumanoidRootPart")
			if root then
				local effect = root:FindFirstChild("TopPlayerEffect")
				if p == topPlayer and maxScore > 0 then
					if not effect then
						local particles = Instance.new("ParticleEmitter")
						particles.Name = "TopPlayerEffect"
						particles.Texture = "rbxassetid://241556831" -- 별 모양 텍스처
						particles.Color = ColorSequence.new(Color3.fromRGB(255, 215, 0)) -- 금색
						particles.Size = NumberSequence.new(0.5)
						particles.Parent = root
					end
				elseif effect then
					effect:Destroy()
				end
			end
		end
	end

	Players.PlayerRemoving:Connect(UpdateTopPlayerEffect)

	-- 1 & 2. 멀티플레이어 점수판(leaderstats) 초기화
	local function onPlayerAdded(player)
		local leaderstats = Instance.new("Folder")
		leaderstats.Name = "leaderstats"
		leaderstats.Parent = player

		local score = Instance.new("IntValue")
		score.Name = "Score (1000 Win)"
		score.Value = 0
		score.Parent = leaderstats

		score.Changed:Connect(UpdateTopPlayerEffect)
		player.CharacterAdded:Connect(UpdateTopPlayerEffect)

		-- 인벤토리 폴더 생성 (UI 표시용)
		local inventory = Instance.new("Folder")
		inventory.Name = "Inventory"
		inventory.Parent = player

		-- 목표 표시 UI 생성
		task.spawn(function()
			local playerGui = player:WaitForChild("PlayerGui", 10)
			if playerGui then
				local screenGui = Instance.new("ScreenGui")
				screenGui.Name = "GameHUD"
				screenGui.ResetOnSpawn = false
				screenGui.Parent = playerGui
				
				local label = Instance.new("TextLabel")
				label.Name = "TargetLabel"
				label.Size = UDim2.new(0, 400, 0, 50)
				label.Position = UDim2.new(0.5, -200, 0, 10)
				label.BackgroundTransparency = 1
				label.Font = Enum.Font.GothamBlack
				label.TextSize = 32
				label.TextStrokeTransparency = 0
				label.Parent = screenGui
				
				local function updateText()
					local target = player:GetAttribute("NextTargetIsland")
					if target == 1 then
						label.Text = "Next Map: Red Island"
						label.TextColor3 = Color3.fromRGB(255, 80, 80)
					elseif target == 2 then
						label.Text = "Next Map: Blue Island"
						label.TextColor3 = Color3.fromRGB(80, 80, 255)
					elseif target == 3 then
						label.Text = "Next Map: Yellow Island"
						label.TextColor3 = Color3.fromRGB(255, 255, 80)
					else
						label.Text = "준비 중..."
						label.TextColor3 = Color3.new(1, 1, 1)
					end
				end
				
				player:GetAttributeChangedSignal("NextTargetIsland"):Connect(updateText)
				updateText()
			end
		end)

		-- 떨어질 때 비명 소리 추가
		player.CharacterAdded:Connect(function(char)
			local humanoid = char:WaitForChild("Humanoid")
			if humanoid then
				humanoid.WalkSpeed = 48 -- 기본 이동속도 3배
			end
			
			-- 리스폰 시 섬 방문 순서 초기화 (적색 섬에서 시작하므로 Next Map는 노란색)
			player:SetAttribute("NextTargetIsland", 3)

			local root = char:WaitForChild("HumanoidRootPart", 10)
			if not root then return end
			
			local connection
			connection = RunService.Heartbeat:Connect(function()
				if not char.Parent or not root.Parent then connection:Disconnect() return end
				
				if root.Position.Y < -5 and not root:FindFirstChild("ScreamSound") then
					local sound = Instance.new("Sound")
					sound.Name = "ScreamSound"
					sound.SoundId = "rbxassetid://9113601347" -- 비명 소리
					sound.Volume = 1.5
					sound.Parent = root
					sound:Play()
				end
			end)
		end)
	end

	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in ipairs(Players:GetPlayers()) do
		onPlayerAdded(player)
	end
	
	-- 아이템 사용 요청 처리
	ReplicatedStorage:WaitForChild("UseItem").OnServerEvent:Connect(function(player)
		MapService.UseItem(player)
	end)

	-- 아이템 생성 루프 (10~20초 간격)
	task.spawn(function()
		while true do
			task.wait(math.random(5, 10))
			MapService.SpawnRandomItem()
		end
	end)
end

function MapService.GenerateMap()
	-- 기존(기본) 스폰 포인트 제거
	for _, child in ipairs(workspace:GetChildren()) do
		if child:IsA("SpawnLocation") then
			child:Destroy()
		end
	end

	local center = Vector3.new(0, 10, 0)
	local radiusFromCenter = 120
	local islandRadius = 40
	local islandHeight = 5
	
	local islandColors = {
		Color3.fromRGB(255, 0, 0),   -- 적색
		Color3.fromRGB(0, 0, 255),   -- 파란색
		Color3.fromRGB(255, 255, 0)  -- 노란색
	}
	
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
		island.Color = islandColors[i]
		-- Cylinder는 X축이 높이(두께)입니다.
		island.Size = Vector3.new(islandHeight, islandRadius * 2, islandRadius * 2)
		-- 눕혀서 평평하게 만들기 위해 Z축으로 90도 회전
		island.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
		island.Parent = workspace

		-- 섬 방문 로직 (적색 -> 노란색 -> 파란색 순서)
		island.Touched:Connect(function(hit)
			local player = Players:GetPlayerFromCharacter(hit.Parent)
			if not player or not player.Character or player.Character.Humanoid.Health <= 0 then return end
			
			local nextTarget = player:GetAttribute("NextTargetIsland") or 3
			
			if i == nextTarget then
				if i == 3 then -- 노란색(3) -> 다음 파란색(2)
					player:SetAttribute("NextTargetIsland", 2)
					print(player.Name .. ": 노란색 섬 통과! 다음은 파란색 섬입니다.")
				elseif i == 2 then -- 파란색(2) -> 다음 적색(1)
					player:SetAttribute("NextTargetIsland", 1)
					print(player.Name .. ": 파란색 섬 통과! 다음은 적색 섬입니다.")
				elseif i == 1 then -- 적색(1) -> 완주 -> 다시 노란색(3)
					player:SetAttribute("NextTargetIsland", 3)
					local leaderstats = player:FindFirstChild("leaderstats")
					local score = leaderstats and leaderstats:FindFirstChild("Score (1000 Win)")
					if score then 
						score.Value += 100
						
						-- 승리 조건 체크 (1000점 달성)
						if score.Value >= 1000 then
							print("🏆 " .. player.Name .. " 님이 1000점을 달성하여 승리했습니다! (게임 초기화)")
							-- 모든 플레이어 점수 초기화
							for _, p in ipairs(Players:GetPlayers()) do
								local ls = p:FindFirstChild("leaderstats")
								local s = ls and ls:FindFirstChild("Score (1000 Win)")
								if s then s.Value = 0 end
							end
						end
					end
					print(player.Name .. ": 코스 완주! 100점 획득.")
				end
			end
		end)

		-- 스폰 포인트 추가
		if i == 1 then -- 적색 섬(첫 번째)에만 스폰 생성
			local spawn = Instance.new("SpawnLocation")
			spawn.Name = "SpawnLocation_" .. i
			spawn.Anchored = true
			spawn.Size = Vector3.new(16, 1, 16)
			spawn.Position = position + Vector3.new(0, islandHeight / 2 + 5, 0) -- 스폰 위치 위로 이동
			spawn.Neutral = true
			spawn.Transparency = 1
			spawn.CanCollide = false
			spawn.Parent = workspace
		end
	end
	
	-- 2. 다리 연결 (1-2, 2-3, 3-1) - 곡선 다리 적용
	local bridgeSegments = 20 -- 곡선을 구성할 파트 개수 (조정 가능: 높을수록 부드러움)
	local curvature = 60 -- 곡률 (조정 가능: 클수록 바깥쪽으로 많이 휨)

	local function getBezierPoint(t, p0, p1, p2)
		return (1 - t)^2 * p0 + 2 * (1 - t) * t * p1 + t^2 * p2
	end

	for i = 1, 3 do
		local p0 = islandPositions[i]
		local p2 = islandPositions[(i % 3) + 1]
		
		-- 제어점(Control Point) 계산: 두 섬의 중간 지점에서 중심 반대 방향으로 curvature만큼 이동
		local midPoint = (p0 + p2) / 2
		local dir = (midPoint - center).Unit
		local p1 = midPoint + (dir * curvature)
		
		for j = 1, bridgeSegments do
			local t1 = (j - 1) / bridgeSegments
			local t2 = j / bridgeSegments
			
			local startPos = getBezierPoint(t1, p0, p1, p2)
			local endPos = getBezierPoint(t2, p0, p1, p2)
			local segDist = (endPos - startPos).Magnitude
			local segCenter = (startPos + endPos) / 2
			
			local bridge = Instance.new("Part")
			bridge.Name = "BridgeSegment"
			bridge.Anchored = true
			bridge.Material = Enum.Material.Wood
			bridge.Color = Color3.fromRGB(139, 69, 19) -- 갈색
			bridge.Size = Vector3.new(20, 1, segDist + 0.5) -- 틈새 방지 오버랩
			bridge.CFrame = CFrame.lookAt(segCenter, endPos)
			bridge.Parent = workspace
			
			-- 다리 난간 생성
			if (segCenter - p0).Magnitude > islandRadius and (segCenter - p2).Magnitude > islandRadius then
				local wallHeight = 5
				local wallThickness = 1
				local bridgeWidth = 20
				for _, side in ipairs({-1, 1}) do
					local wall = Instance.new("Part")
					wall.Name = "BridgeWall"
					wall.Anchored = true
					wall.Material = Enum.Material.Wood
					wall.Color = Color3.fromRGB(139, 69, 19)
					wall.Size = Vector3.new(wallThickness, wallHeight, segDist + 0.5)
					wall.CFrame = bridge.CFrame * CFrame.new(side * (bridgeWidth/2 - wallThickness/2), 0.5 + wallHeight/2, 0)
					wall.Parent = workspace
				end
			end
		end
	end
end

-- 아이템 종류 정의
local ITEM_TYPES = {"SpeedBoost", "StunGun", "Wall"}

function MapService.SpawnRandomItem()
	if #islandPositions == 0 then return end
	
	-- 아이템이 없는 섬 찾기
	local availableIslands = {}
	for _, pos in ipairs(islandPositions) do
		local isOccupied = false
		local checkPos = pos + Vector3.new(0, 3, 0)
		local parts = workspace:GetPartBoundsInRadius(checkPos, 5)
		for _, part in ipairs(parts) do
			if part.Name == "ItemBox" then
				isOccupied = true
				break
			end
		end
		if not isOccupied then
			table.insert(availableIslands, pos)
		end
	end

	if #availableIslands == 0 then return end

	local randomIslandPos = availableIslands[math.random(1, #availableIslands)]
	local itemType = ITEM_TYPES[math.random(1, #ITEM_TYPES)]
	
	local itemPart = Instance.new("Part")
	itemPart.Name = "ItemBox"
	itemPart.Size = Vector3.new(2, 2, 2)
	itemPart.Position = randomIslandPos + Vector3.new(0, 3, 0)
	itemPart.Color = Color3.fromRGB(255, 0, 255) -- 보라색 박스
	itemPart.Material = Enum.Material.Neon
	itemPart.Anchored = false
	itemPart.Parent = workspace
	
	-- 아이템 텍스트 표시
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.new(0, 100, 0, 50)
	billboard.Adornee = itemPart
	billboard.AlwaysOnTop = true
	billboard.Parent = itemPart
	
	local textLabel = Instance.new("TextLabel")
	textLabel.Size = UDim2.new(1, 0, 1, 0)
	textLabel.BackgroundTransparency = 1
	textLabel.Text = itemType
	textLabel.TextColor3 = Color3.new(1, 1, 1)
	textLabel.TextStrokeTransparency = 0
	textLabel.Parent = billboard

	-- 획득 로직
	local collected = false
	itemPart.Touched:Connect(function(hit)
		if collected then return end
		local player = Players:GetPlayerFromCharacter(hit.Parent)
		if player then
			-- 인벤토리 확인 (Folder 사용)
			local inventory = player:FindFirstChild("Inventory")
			if not inventory then
				inventory = Instance.new("Folder")
				inventory.Name = "Inventory"
				inventory.Parent = player
			end
			
			if #inventory:GetChildren() < 2 then
				collected = true
				local itemValue = Instance.new("StringValue")
				itemValue.Name = "Item"
				itemValue.Value = itemType
				itemValue.Parent = inventory
				
				itemPart:Destroy()
				print(player.Name .. " 님이 아이템 획득: " .. itemType)
			end
		end
	end)
	
	Debris:AddItem(itemPart, 30) -- 30초 후 삭제 (청소)
end

function MapService.UseItem(player)
	local inventory = player:FindFirstChild("Inventory")
	if not inventory then return end
	
	local items = inventory:GetChildren()
	if #items > 0 then
		local itemToUse = items[1] -- 첫 번째 아이템 사용 (FIFO)
		local itemType = itemToUse.Value
		itemToUse:Destroy() -- 인벤토리에서 제거
		
		local char = player.Character
		if not char then return end
		local root = char:FindFirstChild("HumanoidRootPart")
		local humanoid = char:FindFirstChild("Humanoid")
		
		print(player.Name .. " 아이템 사용: " .. itemType)
		
		local sound = Instance.new("Sound")
		sound.SoundId = "rbxassetid://12221967" -- 아이템 사용 효과음
		sound.Parent = root
		sound:Play()
		Debris:AddItem(sound, 1)

		if itemType == "SpeedBoost" then
			-- 1. 이동속도 증가 (3초간 3배)
			local originalSpeed = humanoid.WalkSpeed
			humanoid.WalkSpeed = originalSpeed * 3
			task.delay(3, function()
				if humanoid then humanoid.WalkSpeed = originalSpeed end
			end)
			
		elseif itemType == "StunGun" then
			-- 3. 스턴총 (투사체 발사)
			if root then
				local bullet = Instance.new("Part")
				bullet.Size = Vector3.new(1, 1, 2)
				bullet.Color = Color3.fromRGB(255, 255, 0)
				bullet.Material = Enum.Material.Neon
				bullet.CFrame = root.CFrame * CFrame.new(0, 0, -3)
				bullet.Velocity = root.CFrame.LookVector * 100
				bullet.CanCollide = false
				bullet.Parent = workspace
				
				bullet.Touched:Connect(function(hit)
					if hit.Parent == char then return end -- 자기 자신 무시
					local targetHum = hit.Parent:FindFirstChild("Humanoid")
					if targetHum then
						local targetRoot = hit.Parent:FindFirstChild("HumanoidRootPart")
						if targetRoot then
							targetRoot.Anchored = true
							task.delay(3, function()
								if targetRoot then targetRoot.Anchored = false end
							end)
							bullet:Destroy()
						end
					end
				end)
				Debris:AddItem(bullet, 3) -- 3초 후(맵 벗어나면) 삭제
			end
			
		elseif itemType == "Wall" then
			-- 4. 벽 생성
			if root then
				local wall = Instance.new("Part")
				wall.Size = Vector3.new(30, 30, 2)
				wall.CFrame = root.CFrame * CFrame.new(0, 0, 10)
				wall.Anchored = true
				wall.BrickColor = BrickColor.new("Dark stone grey")
				wall.Parent = workspace
				
				-- 8초 후 서서히 투명해지며 사라짐 (총 10초 지속)
				task.delay(8, function()
					if wall and wall.Parent then
						local tween = TweenService:Create(wall, TweenInfo.new(2), {Transparency = 1})
						tween:Play()
						tween.Completed:Connect(function()
							wall:Destroy()
						end)
					end
				end)
			end
		end
	end
end

return MapService