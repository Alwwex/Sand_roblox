--[[
	Effects – vizuální efekty na klientovi: prach při kopání, vyskakující čísla,
	písečná bouře, zvuky.
]]

local Debris = game:GetService("Debris")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Effects = {}

local SAND_COLOR = Color3.fromRGB(230, 196, 135)
local effectsFolder = Instance.new("Folder")
effectsFolder.Name = "ClientEffects"
effectsFolder.Parent = workspace

local function anchorPart(position: Vector3): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part.Size = Vector3.new(0.2, 0.2, 0.2)
	part.Position = position
	part.Parent = effectsFolder
	return part
end

-- Nastavení z menu Settings
Effects.lowGraphics = false
Effects.popups = true

-- Zatřesení kamerou (přes Humanoid.CameraOffset)
function Effects.shake(intensity: number, duration: number)
	if Effects.lowGraphics then
		return
	end
	local character = game:GetService("Players").LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	task.spawn(function()
		local started = os.clock()
		while os.clock() - started < duration do
			local fade = 1 - (os.clock() - started) / duration
			humanoid.CameraOffset = Vector3.new(
				(math.random() - 0.5) * intensity * fade,
				(math.random() - 0.5) * intensity * fade,
				(math.random() - 0.5) * intensity * fade
			)
			task.wait()
		end
		humanoid.CameraOffset = Vector3.zero
	end)
end

-- Oblak písku při kopání
function Effects.digBurst(position: Vector3, strength: number)
	if Effects.lowGraphics then
		return
	end
	local part = anchorPart(position)
	local size = math.clamp(strength, 0.6, 4)

	local dust = Instance.new("ParticleEmitter")
	dust.Texture = "rbxasset://textures/particles/smoke_main.dds"
	dust.Color = ColorSequence.new(SAND_COLOR)
	dust.Size =
		NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8 * size), NumberSequenceKeypoint.new(1, 2.2 * size) })
	dust.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
	dust.Lifetime = NumberRange.new(0.5, 0.9)
	dust.Speed = NumberRange.new(4, 10)
	dust.SpreadAngle = Vector2.new(70, 70)
	dust.EmissionDirection = Enum.NormalId.Top
	dust.Acceleration = Vector3.new(0, -12, 0)
	dust.Drag = 3
	dust.Rate = 0
	dust.LightInfluence = 1
	dust.Parent = part
	dust:Emit(math.clamp(math.floor(size * 5), 4, 24))

	local grains = Instance.new("ParticleEmitter")
	grains.Color = ColorSequence.new(SAND_COLOR, Color3.fromRGB(200, 160, 100))
	grains.Size = NumberSequence.new(0.18 * size)
	grains.Lifetime = NumberRange.new(0.5, 0.8)
	grains.Speed = NumberRange.new(10, 20)
	grains.SpreadAngle = Vector2.new(45, 45)
	grains.EmissionDirection = Enum.NormalId.Top
	grains.Acceleration = Vector3.new(0, -60, 0)
	grains.Rate = 0
	grains.LightInfluence = 1
	grains.Parent = part
	grains:Emit(math.clamp(math.floor(size * 10), 8, 40))

	Debris:AddItem(part, 1.5)
end

-- Vyskakující text ve světě (+12, +500 coins...)
function Effects.popup(position: Vector3, text: string, color: Color3, scale: number?)
	if not Effects.popups then
		return
	end
	local part = anchorPart(position)
	local s = scale or 1
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(160 * s, 50 * s)
	billboard.StudsOffset = Vector3.new(0, 1.5, 0)
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.Adornee = part
	billboard.Parent = part

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextScaled = true
	label.Font = Enum.Font.LuckiestGuy
	label.TextColor3 = color
	label.Parent = billboard
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = Color3.fromRGB(50, 30, 10)
	stroke.Parent = label

	local info = TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(billboard, info, { StudsOffset = Vector3.new(0, 5, 0) }):Play()
	TweenService:Create(
		label,
		TweenInfo.new(0.5, Enum.EasingStyle.Linear, Enum.EasingDirection.In, 0, false, 0.45),
		{ TextTransparency = 1 }
	):Play()
	TweenService:Create(
		stroke,
		TweenInfo.new(0.5, Enum.EasingStyle.Linear, Enum.EasingDirection.In, 0, false, 0.45),
		{ Transparency = 1 }
	):Play()
	Debris:AddItem(part, 1.1)
end

-- Exploze mincí z truhly
function Effects.chestBurst(position: Vector3, color: Color3)
	local part = anchorPart(position + Vector3.new(0, 1.5, 0))
	local coins = Instance.new("ParticleEmitter")
	coins.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	coins.Color = ColorSequence.new(Color3.fromRGB(255, 215, 70), color)
	coins.LightEmission = 1
	coins.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 0.2) })
	coins.Lifetime = NumberRange.new(0.8, 1.4)
	coins.Speed = NumberRange.new(15, 28)
	coins.SpreadAngle = Vector2.new(40, 40)
	coins.EmissionDirection = Enum.NormalId.Top
	coins.Acceleration = Vector3.new(0, -40, 0)
	coins.Rate = 0
	coins.Parent = part
	coins:Emit(60)
	Debris:AddItem(part, 2)
end

---------------------------------------------------------------------
-- Písečná bouře (jen vizuálně, na klientovi)
---------------------------------------------------------------------

local stormPart: Part? = nil
local stormEmitter: ParticleEmitter? = nil
local stormConnection: RBXScriptConnection? = nil
local defaultAtmosphere = nil

local function getAtmosphere(): Atmosphere?
	return Lighting:FindFirstChildOfClass("Atmosphere")
end

local function ensureStormEmitter()
	if stormPart then
		return
	end
	local part = Instance.new("Part")
	part.Name = "StormVolume"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part.Size = Vector3.new(80, 40, 80)
	part.Parent = effectsFolder

	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
	emitter.Color = ColorSequence.new(Color3.fromRGB(220, 170, 110))
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 6), NumberSequenceKeypoint.new(1, 14) })
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.3, 0.55),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Lifetime = NumberRange.new(2, 3)
	emitter.Speed = NumberRange.new(0, 0)
	emitter.Acceleration = Vector3.new(60, -4, 20)
	emitter.Rate = 0
	emitter.Shape = Enum.ParticleEmitterShape.Box
	emitter.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	emitter.LightInfluence = 1
	emitter.Parent = part

	stormPart = part
	stormEmitter = emitter
	stormConnection = RunService.RenderStepped:Connect(function()
		local camera = workspace.CurrentCamera
		if camera and stormPart then
			stormPart.CFrame = CFrame.new(camera.CFrame.Position + Vector3.new(-25, 0, -10))
		end
	end)
end

function Effects.setStorm(phase: string)
	local atmosphere = getAtmosphere()
	if atmosphere and not defaultAtmosphere then
		defaultAtmosphere = { Density = atmosphere.Density, Color = atmosphere.Color, Haze = atmosphere.Haze }
	end

	local info = TweenInfo.new(3, Enum.EasingStyle.Sine)
	if phase == "Warning" then
		ensureStormEmitter()
		if stormEmitter then
			stormEmitter.Rate = 25
		end
		if atmosphere then
			TweenService:Create(atmosphere, info, { Density = 0.5, Haze = 2.5, Color = Color3.fromRGB(215, 160, 100) })
				:Play()
		end
	elseif phase == "Active" then
		ensureStormEmitter()
		if stormEmitter then
			stormEmitter.Rate = 120
		end
		if atmosphere then
			TweenService:Create(atmosphere, info, { Density = 0.78, Haze = 4, Color = Color3.fromRGB(200, 140, 80) })
				:Play()
		end
	else
		if stormEmitter then
			stormEmitter.Rate = 0
		end
		if atmosphere and defaultAtmosphere then
			TweenService:Create(atmosphere, TweenInfo.new(4, Enum.EasingStyle.Sine), defaultAtmosphere):Play()
		end
		task.delay(4, function()
			if workspace:GetAttribute("StormPhase") == "Calm" and stormPart then
				if stormConnection then
					stormConnection:Disconnect()
					stormConnection = nil
				end
				stormPart:Destroy()
				stormPart = nil
				stormEmitter = nil
			end
		end)
	end
end

return Effects
