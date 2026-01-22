--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local MapService = {}
local islandPositions = {} -- GenerateMap과 SpawnItem에서 공유하기 위해 위로 이동
local isGameRunning = false
local gameStartTime = 0
local restartVotes = {}

function MapService.Init()
	print("[MapService] Generating Map...")
	MapService.GenerateMap()
	
	-- 아이템 사용을 위한 RemoteEvent 생성
	if not ReplicatedStorage:FindFirstChild("UseItem") then
		local re = Instance.new("RemoteEvent")
		re.Name = "UseItem"
		re.Parent = ReplicatedStorage
	end
	
	-- 재시작 투표를 위한 RemoteEvent 생성
	if not ReplicatedStorage:FindFirstChild("VoteRestart") then
		local ve = Instance.new("RemoteEvent")
		ve.Name = "VoteRestart"
		ve.Parent = ReplicatedStorage
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
	MapService.RestartGame()
	
	-- 5분 타이머 체크 루프
	task.spawn(function()
		while true do
			task.wait(1)
			if isGameRunning then
				local elapsed = os.time() - gameStartTime
				local remaining = 300 - elapsed
				if remaining < 0 then remaining = 0 end
				
				local timeText = string.format("%02d:%02d", math.floor(remaining/60), remaining%60)
				for _, p in ipairs(Players:GetPlayers()) do
					local gui = p:FindFirstChild("PlayerGui")
					local hud = gui and gui:FindFirstChild("GameHUD")
					local tl = hud and hud:FindFirstChild("TimeLabel")
					if tl then tl.Text = timeText end
				end
				
				if elapsed >= 300 then -- 300초 = 5분
					MapService.EndGameByTime()
				end
			end
		end
	end)

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
				
				-- 남은 시간 표시 UI
				local timeLabel = Instance.new("TextLabel")
				timeLabel.Name = "TimeLabel"
				timeLabel.Size = UDim2.new(0, 100, 0, 40)
				timeLabel.Position = UDim2.new(0.5, -50, 0, 60)
				timeLabel.BackgroundTransparency = 1
				timeLabel.Font = Enum.Font.GothamBold
				timeLabel.TextSize = 28
				timeLabel.TextColor3 = Color3.new(1, 1, 1)
				timeLabel.TextStrokeTransparency = 0
				timeLabel.Text = "05:00"
				timeLabel.Parent = screenGui
				
				-- 승리 메시지 UI
				local winLabel = Instance.new("TextLabel")
				winLabel.Name = "WinLabel"
				winLabel.Size = UDim2.new(1, 0, 0, 100)
				winLabel.Position = UDim2.new(0, 0, 0.4, 0)
				winLabel.BackgroundTransparency = 1
				winLabel.Font = Enum.Font.GothamBlack
				winLabel.TextScaled = true
				winLabel.TextColor3 = Color3.new(1, 0.8, 0)
				winLabel.TextStrokeTransparency = 0
				winLabel.Visible = false
				winLabel.Parent = screenGui

				-- 재시작 투표 버튼
				local voteBtn = Instance.new("TextButton")
				voteBtn.Name = "VoteButton"
				voteBtn.Size = UDim2.new(0, 120, 0, 40)
				voteBtn.Position = UDim2.new(1, -130, 1, -50) -- 우측 하단으로 이동
				voteBtn.Text = "Vote Restart"
				voteBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
				voteBtn.TextColor3 = Color3.new(1, 1, 1)
				voteBtn.Parent = screenGui
				
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
			-- 옵저버인 경우 캐릭터 설정 (투명, 충돌 없음)
			if player:GetAttribute("IsObserver") then
				MapService.SetupObserverCharacter(player, char)
				return
			end

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
	
	-- 이미 접속한 플레이어 처리
	for _, player in ipairs(Players:GetPlayers()) do
		onPlayerAdded(player)
	end
	
	-- 게임 도중 접속자 처리 (옵저버)
	Players.PlayerAdded:Connect(function(player)
		-- 게임 시작 후 10초가 지났다면 옵저버로 설정
		if isGameRunning and (os.time() - gameStartTime > 10) then
			player:SetAttribute("IsObserver", true)
			print(player.Name .. " 님이 게임 도중 접속하여 옵저버가 되었습니다.")
		end
	end)
	
	-- 아이템 사용 요청 처리
	ReplicatedStorage:WaitForChild("UseItem").OnServerEvent:Connect(function(player)
		MapService.UseItem(player)
	end)
	
	-- 재시작 투표 요청 처리
	ReplicatedStorage:WaitForChild("VoteRestart").OnServerEvent:Connect(function(player)
		if not table.find(restartVotes, player) then
			table.insert(restartVotes, player)
			local required = MapService.GetRestartThreshold()
			print(string.format("재시작 투표: %d/%d", #restartVotes, required))
			
			-- 투표 현황 알림 (채팅)
			local msg = string.format("[System] 재시작 투표: %d/%d", #restartVotes, required)
			-- 간단히 서버 로그로 대체하거나 ChatService를 이용할 수 있음
			
			if #restartVotes >= required then
				MapService.RestartGame()
			end
		end
	end)

	-- 아이템 생성 루프 (10~20초 간격)
	task.spawn(function()
		while true do
			task.wait(math.random(5, 10))
			MapService.SpawnRandomItem()
		end
	end)
end

function MapService.GetRestartThreshold()
	local playerCount = #Players:GetPlayers()
	if playerCount <= 2 then return 1 end -- 1명: 즉시, 2명: 1명 동의
	if playerCount <= 4 then return 2 end -- 3~4명: 2명 동의
	if playerCount <= 7 then return 3 end -- 5~7명: 3명 동의
	return 4 -- 8명 이상: 4명 동의
end

function MapService.AnnounceWinner(text)
	isGameRunning = false
	print(text)
	for _, p in ipairs(Players:GetPlayers()) do
		local gui = p:FindFirstChild("PlayerGui")
		local hud = gui and gui:FindFirstChild("GameHUD")
		local winLabel = hud and hud:FindFirstChild("WinLabel")
		if winLabel then
			winLabel.Text = text
			winLabel.Visible = true
		end
	end
	
	task.delay(5, function()
		MapService.RestartGame()
	end)
end

function MapService.RestartGame()
	print("🔄 게임을 재시작합니다!")
	isGameRunning = false
	restartVotes = {}
	
	-- 맵 초기화 (기존 섬, 다리, 아이템 제거)
	for _, child in ipairs(workspace:GetChildren()) do
		if child.Name:match("Island_") or child.Name:match("Bridge") or child.Name == "ItemBox" or child.Name == "Wall" then
			child:Destroy()
		end
	end
	
	MapService.GenerateMap()
	
	-- 플레이어 초기화
	for _, p in ipairs(Players:GetPlayers()) do
		local ls = p:FindFirstChild("leaderstats")
		local s = ls and ls:FindFirstChild("Score (1000 Win)")
		if s then s.Value = 0 end
		
		p:SetAttribute("NextTargetIsland", 0) -- 0으로 초기화 (준비 중)
		p:SetAttribute("IsObserver", nil) -- 옵저버 해제
		p:LoadCharacter() -- 리스폰
		
		-- UI 초기화
		local gui = p:FindFirstChild("PlayerGui")
		local hud = gui and gui:FindFirstChild("GameHUD")
		if hud then
			local winLabel = hud:FindFirstChild("WinLabel")
			if winLabel then winLabel.Visible = false end
		end
	end
	
	task.spawn(function()
		local redIslandPos = islandPositions[1]
		
		-- 5초 카운트다운
		for i = 5, 1, -1 do
			for _, p in ipairs(Players:GetPlayers()) do
				local gui = p:FindFirstChild("PlayerGui")
				local hud = gui and gui:FindFirstChild("GameHUD")
				local targetLabel = hud and hud:FindFirstChild("TargetLabel")
				if targetLabel then
					targetLabel.Text = "Game Starts in " .. i
					targetLabel.TextColor3 = Color3.new(1, 1, 1)
				end
			end
			
			-- 위치 보정 (빨간 섬 밖으로 나가면 복귀)
			local endTime = os.clock() + 1
			while os.clock() < endTime do
				for _, p in ipairs(Players:GetPlayers()) do
					if p:GetAttribute("IsObserver") then continue end
					local char = p.Character
					local root = char and char:FindFirstChild("HumanoidRootPart")
					if root and redIslandPos then
						local dist = (Vector3.new(root.Position.X, 0, root.Position.Z) - Vector3.new(redIslandPos.X, 0, redIslandPos.Z)).Magnitude
						if dist > 40 then
							root.CFrame = CFrame.new(redIslandPos + Vector3.new(0, 5, 0))
						end
					end
				end
				task.wait(0.1)
			end
		end
		
		gameStartTime = os.time()
		isGameRunning = true
		
		-- UI 갱신 (Next Map 표시)
		for _, p in ipairs(Players:GetPlayers()) do
			p:SetAttribute("NextTargetIsland", 3) -- 3으로 설정하여 시작 (노란색 목표)

			local gui = p:FindFirstChild("PlayerGui")
			local hud = gui and gui:FindFirstChild("GameHUD")
			local targetLabel = hud and hud:FindFirstChild("TargetLabel")
			if targetLabel then
				targetLabel.Text = "Next Map: Yellow Island"
				targetLabel.TextColor3 = Color3.fromRGB(255, 255, 80)
			end
		end
	end)
end

function MapService.EndGameByTime()
	local maxScore = -1
	local winners = {}
	
	for _, p in ipairs(Players:GetPlayers()) do
		local ls = p:FindFirstChild("leaderstats")
		local s = ls and ls:FindFirstChild("Score (1000 Win)")
		local score = s and s.Value or 0
		
		if score > maxScore then
			maxScore = score
			winners = {p}
		elseif score == maxScore then
			table.insert(winners, p)
		end
	end
	
	if maxScore <= 0 then
		MapService.AnnounceWinner("No winner : (")
	elseif #winners == 1 then
		MapService.AnnounceWinner(winners[1].Name .. " Win!")
	else
		local names = {}
		for _, w in ipairs(winners) do
			table.insert(names, w.Name)
		end
		MapService.AnnounceWinner(table.concat(names, ", ") .. " Co-Win!")
	end
end

function MapService.SetupObserverCharacter(player, char)
	task.wait(0.1) -- 캐릭터 로드 대기
	for _, part in ipairs(char:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Transparency = 0.5
			part.CanCollide = false
			part.CastShadow = false
		end
	end
	
	local root = char:WaitForChild("HumanoidRootPart")
	if root then
		root.Anchored = false
	end
	
	-- 옵저버는 이름표 숨기기 등 추가 처리 가능
	print(player.Name .. " (옵저버) 스폰 완료")
end

function MapService.GenerateMap()
	islandPositions = {}
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
	local bridgeWidth = 30
	
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
			if not player or not player.Character or player.Character.Humanoid.Health <= 0 or player:GetAttribute("IsObserver") then return end
			
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
							MapService.AnnounceWinner(player.Name .. " Win!")
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
			bridge.Size = Vector3.new(bridgeWidth, 1, segDist + 0.5) -- 틈새 방지 오버랩
			bridge.CFrame = CFrame.lookAt(segCenter, endPos)
			bridge.Parent = workspace
			
			-- 다리 난간 생성
			if (segCenter - p0).Magnitude > islandRadius and (segCenter - p2).Magnitude > islandRadius then
				local wallHeight = 10
				local wallThickness = 1
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

	-- 3. 섬 주위에 벽 생성 (다리 연결 부위 제외)
	local wallHeight = 10
	for i = 1, 3 do
		local currentPos = islandPositions[i]
		local nextIndex = (i % 3) + 1
		local prevIndex = (i - 2) % 3 + 1
		
		local nextPos = islandPositions[nextIndex]
		local prevPos = islandPositions[prevIndex]
		
		-- Outgoing Bridge Control Point (to Next)
		local midOut = (currentPos + nextPos) / 2
		local dirOut = (midOut - center).Unit
		local p1Out = midOut + (dirOut * curvature)
		local vecOut = (p1Out - currentPos) * Vector3.new(1,0,1)
		
		-- Incoming Bridge Control Point (from Prev)
		local midIn = (prevPos + currentPos) / 2
		local dirIn = (midIn - center).Unit
		local p1In = midIn + (dirIn * curvature)
		local vecIn = (p1In - currentPos) * Vector3.new(1,0,1)
		
		local angleOut = math.atan2(vecOut.Z, vecOut.X)
		local angleIn = math.atan2(vecIn.Z, vecIn.X)
		
		local numSegments = 80
		local angleStep = (2 * math.pi) / numSegments
		local gapHalfAngle = math.atan((bridgeWidth / 2 + 2) / islandRadius) -- 다리 너비에 맞춰 각도 계산
		
		local function getAngleDiff(a, b)
			local diff = math.abs(a - b)
			while diff > math.pi do diff = diff - 2 * math.pi end
			return math.abs(diff)
		end
		
		for j = 1, numSegments do
			local angle = (j - 1) * angleStep
			
			if getAngleDiff(angle, angleOut) > gapHalfAngle and getAngleDiff(angle, angleIn) > gapHalfAngle then
				local x = math.cos(angle) * islandRadius
				local z = math.sin(angle) * islandRadius
				-- 섬 표면(Y=12.5) 위에 벽(높이 5)을 올리므로 중심 Y는 12.5 + 2.5 = 15
				local wallPos = currentPos + Vector3.new(x, islandHeight/2 + wallHeight/2, z)
				
				local wall = Instance.new("Part")
				wall.Name = "Island_Wall"
				wall.Anchored = true
				wall.Material = Enum.Material.Wood
				wall.Color = Color3.fromRGB(139, 69, 19)
				wall.Size = Vector3.new(1, wallHeight, (2 * math.pi * islandRadius / numSegments) + 0.5)
				wall.CFrame = CFrame.lookAt(wallPos, currentPos) * CFrame.Angles(0, math.rad(90), 0)
				wall.Parent = workspace
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
		if player and not player:GetAttribute("IsObserver") then
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
	if player:GetAttribute("IsObserver") then return end -- 옵저버는 아이템 사용 불가
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
					local targetHum = hit.Parent:FindFirstChild("Humanoid") -- 옵저버 체크는 물리 충돌 없음으로 자연스럽게 회피됨
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