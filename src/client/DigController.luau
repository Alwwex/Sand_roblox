--[[
	DigController – ovládání kopání.
	Drž myš / prst (nebo tlačítko na ovladači) s nástrojem v ruce = kopeš.
	Kope se tam, kam míříš. Když míříš moc daleko, kope se před tebou.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local DigController = {}

local player = Players.LocalPlayer
local state = nil
local currentTool: Tool? = nil
local digToken = nil
local lastFire = 0
local pointerKind = "Mouse"
local lastTouchPosition: Vector3? = nil

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local function updateFilter()
	local ignore = {}
	if player.Character then
		table.insert(ignore, player.Character)
	end
	local effects = workspace:FindFirstChild("ClientEffects")
	if effects then
		table.insert(ignore, effects)
	end
	rayParams.FilterDescendantsInstances = ignore
end

local function getTarget(reach: number): Vector3?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local camera = workspace.CurrentCamera
	if not root or not camera then
		return nil
	end
	updateFilter()

	local ray
	if pointerKind == "Touch" and lastTouchPosition then
		ray = camera:ScreenPointToRay(lastTouchPosition.X, lastTouchPosition.Y)
	elseif pointerKind == "Gamepad" then
		local viewport = camera.ViewportSize
		ray = camera:ViewportPointToRay(viewport.X / 2, viewport.Y / 2)
	else
		local mouse = UserInputService:GetMouseLocation()
		ray = camera:ViewportPointToRay(mouse.X, mouse.Y)
	end

	local result = workspace:Raycast(ray.Origin, ray.Direction * 400, rayParams)
	if result and (result.Position - root.Position).Magnitude <= reach then
		return result.Position
	end

	-- Záložní cíl: zem kousek před postavou
	local forward = root.CFrame.LookVector * math.min(4, reach * 0.4)
	local origin = root.Position + forward + Vector3.new(0, 2, 0)
	local down = workspace:Raycast(origin, Vector3.new(0, -14, 0), rayParams)
	if down then
		return down.Position
	end
	return nil
end

local function swing(tool: Tool, toolConfig)
	if not toolConfig.Swing then
		return
	end
	-- Výchozí Animate skript přehraje "sek" nástrojem, když najde tento StringValue
	local anim = Instance.new("StringValue")
	anim.Name = "toolanim"
	anim.Value = "Slash"
	anim.Parent = tool
end

local function startDigging(tool: Tool)
	local token = {}
	digToken = token
	task.spawn(function()
		while digToken == token and tool.Parent == player.Character do
			local toolConfig = Config.ToolsById[tool:GetAttribute("DigToolId")]
			if not toolConfig then
				break
			end
			local speed = if state and state.DigSpeed then state.DigSpeed else 1
			local cooldown = toolConfig.Cooldown / speed
			local waitLeft = lastFire + cooldown - os.clock()
			if waitLeft > 0 then
				task.wait(waitLeft)
				if digToken ~= token then
					break
				end
			end
			local target = getTarget(toolConfig.Reach)
			if target then
				lastFire = os.clock()
				Remotes.Dig:FireServer(target)
				swing(tool, toolConfig)
				task.wait(cooldown)
			else
				task.wait(0.1)
			end
		end
	end)
end

local function stopDigging()
	digToken = nil
end

local watchedTools = setmetatable({}, { __mode = "k" })

local function watchTool(tool: Tool)
	if not tool:GetAttribute("DigToolId") then
		return
	end
	currentTool = tool
	if watchedTools[tool] then
		return
	end
	watchedTools[tool] = true
	tool.Activated:Connect(function()
		startDigging(tool)
	end)
	tool.Deactivated:Connect(stopDigging)
	tool.Unequipped:Connect(stopDigging)
end

local function onCharacter(character: Model)
	stopDigging()
	character.ChildAdded:Connect(function(child)
		if child:IsA("Tool") then
			watchTool(child)
		end
	end)
	for _, child in character:GetChildren() do
		if child:IsA("Tool") then
			watchTool(child)
		end
	end
end

function DigController.setState(newState)
	state = newState
end

function DigController.getTool(): Tool?
	return currentTool
end

function DigController.init()
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if input.UserInputType == Enum.UserInputType.Touch then
			pointerKind = "Touch"
			-- dotyky joysticku/tlačítek ignorujeme, chceme jen "tap do světa"
			if not gameProcessed then
				lastTouchPosition = input.Position
			end
		elseif
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.MouseMovement
		then
			pointerKind = "Mouse"
		elseif input.UserInputType.Name:find("Gamepad") then
			pointerKind = "Gamepad"
		end
	end)
	UserInputService.InputChanged:Connect(function(input, gameProcessed)
		if input.UserInputType == Enum.UserInputType.Touch then
			if not gameProcessed then
				lastTouchPosition = input.Position
			end
		elseif input.UserInputType == Enum.UserInputType.MouseMovement then
			pointerKind = "Mouse"
		end
	end)

	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		onCharacter(player.Character)
	end
end

return DigController
