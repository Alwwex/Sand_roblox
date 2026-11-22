--[[
	HatchFx – animace líhnutí: vajíčko se třese, praskne (záblesk), objeví se mazlíček,
	jeho rarita, bonus, "NEW!" a konfety.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local PetFactory = require(ReplicatedStorage.Shared.PetFactory)
local UIKit = require(script.Parent.UIKit)

local T = UIKit.Theme
local new = UIKit.new

local HatchFx = {}

local CONFETTI = { T.Orange, T.Gold, T.Cyan, T.Pink, T.Green, T.Purple, T.Blue }

local function viewport(parent: Instance, zIndex: number)
	local vp = new("ViewportFrame", {
		Size = UDim2.fromOffset(300, 300),
		BackgroundTransparency = 1,
		Ambient = Color3.fromRGB(185, 175, 165),
		LightColor = Color3.fromRGB(255, 245, 230),
		LightDirection = Vector3.new(-1, -1.5, -1),
		ZIndex = zIndex,
		Parent = parent,
	})
	local camera = new("Camera", { FieldOfView = 32, Parent = vp })
	camera.CFrame = CFrame.lookAt(Vector3.new(2.2, 2.6, -8.6), Vector3.new(0, 1.45, 0))
	vp.CurrentCamera = camera
	return vp
end

local function confetti(layer: Frame, count: number)
	for _ = 1, count do
		local startX = math.random()
		local piece = new("Frame", {
			Size = UDim2.fromOffset(math.random(10, 18), math.random(6, 12)),
			Position = UDim2.new(startX, 0, 0, -20),
			BackgroundColor3 = CONFETTI[math.random(1, #CONFETTI)],
			Rotation = math.random(0, 360),
			ZIndex = 78,
			Parent = layer,
		})
		UIKit.corner(piece, 3)
		local duration = 1.6 + math.random() * 1.2
		TweenService:Create(piece, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = UDim2.new(startX + (math.random() - 0.5) * 0.2, 0, 1.1, 0),
			Rotation = piece.Rotation + math.random(-400, 400),
		}):Play()
		task.delay(duration + 0.1, function()
			piece:Destroy()
		end)
	end
end

-- results = { {PetId, New}, ... }
function HatchFx.play(gui: ScreenGui, results, eggId: string, sfx)
	local overlay = new("TextButton", {
		Name = "HatchFx",
		Text = "",
		AutoButtonColor = false,
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.35,
		ZIndex = 70,
		Parent = gui,
	})
	local count = #results
	local cards = {}
	for i, result in results do
		local card = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, (i - (count + 1) / 2) * 320, 0.48, 0),
			Size = UDim2.fromOffset(300, 420),
			BackgroundTransparency = 1,
			ZIndex = 71,
			Parent = overlay,
		})
		local vp = viewport(card, 72)
		local egg = PetFactory.egg(eggId, 1.0)
		egg.Parent = vp
		local pet = Config.PetsById[result.PetId]
		local rarity = Config.Rarities[pet.Rarity]
		local name = UIKit.text({
			Text = string.upper(pet.Name),
			Position = UDim2.fromOffset(0, 300),
			Size = UDim2.new(1, 0, 0, 44),
			Font = UIKit.Font.Title,
			TextColor3 = rarity.Color,
			Stroke = 3,
			Visible = false,
			ZIndex = 73,
			Parent = card,
		})
		local info = UIKit.text({
			Text = string.upper(pet.Rarity) .. ("  •  +%d%% COINS"):format(math.floor(pet.Coins * 100 + 0.5)),
			Position = UDim2.fromOffset(0, 346),
			Size = UDim2.new(1, 0, 0, 30),
			Font = UIKit.Font.Title,
			Stroke = 2,
			Visible = false,
			ZIndex = 73,
			Parent = card,
		})
		local badge = UIKit.text({
			Text = "NEW!",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 10),
			Size = UDim2.fromOffset(140, 40),
			Font = UIKit.Font.Title,
			TextColor3 = T.Gold,
			Rotation = -8,
			Stroke = 3,
			Visible = false,
			ZIndex = 74,
			Parent = card,
		})
		table.insert(cards, {
			Card = card,
			Viewport = vp,
			Egg = egg,
			Name = name,
			Info = info,
			Badge = badge,
			Result = result,
			Rarity = rarity,
		})
	end
	local flash = new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 1,
		ZIndex = 77,
		Parent = overlay,
	})

	local done = false
	local function finish()
		if done then
			return
		end
		done = true
		TweenService:Create(overlay, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play()
		task.delay(0.3, function()
			overlay:Destroy()
		end)
	end

	task.spawn(function()
		-- 1) třesení
		local started = os.clock()
		local shake = RunService.RenderStepped:Connect(function()
			local elapsed = os.clock() - started
			local amplitude = math.min(elapsed / 1.4, 1) * 0.35
			for i, c in cards do
				if c.Egg.Parent then
					c.Egg:PivotTo(CFrame.Angles(0, 0, math.sin(elapsed * 28 + i) * amplitude))
				end
			end
		end)
		for k = 1, 4 do
			task.wait(0.33)
			sfx("Click", 0.5, 0.8 + k * 0.15)
		end
		shake:Disconnect()
		-- 2) záblesk a odhalení
		flash.BackgroundTransparency = 0
		TweenService:Create(flash, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
		local best = 1
		for _, c in cards do
			c.Egg:Destroy()
			local model = PetFactory.build(c.Result.PetId)
			model.Parent = c.Viewport
			c.Pet = model
			c.Name.Visible = true
			c.Info.Visible = true
			c.Badge.Visible = c.Result.New == true
			UIKit.pop(c.Card, 0.6)
			best = math.max(best, c.Rarity.Order)
		end
		sfx(if best >= 3 then "Rare" else "Chest", 0.9)
		confetti(overlay, if best >= 4 then 80 else 40)
		-- mazlíček se pomalu otáčí
		local spinStart = os.clock()
		local spin = RunService.RenderStepped:Connect(function()
			for _, c in cards do
				if c.Pet and c.Pet.Parent then
					c.Pet:PivotTo(CFrame.Angles(0, math.sin((os.clock() - spinStart) * 1.5) * 0.6, 0))
				end
			end
		end)
		overlay.Activated:Connect(finish)
		task.wait(3)
		spin:Disconnect()
		finish()
	end)
	return overlay
end

return HatchFx
