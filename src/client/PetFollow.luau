--[[
	PetFollow – mazlíčci plynule chodí (nebo létají) za svými hráči.
	Server mazlíčky jen vytvoří ve workspace.Pets/<UserId>, pohyb dělá každý klient sám
	(plynulejší a nezatěžuje server). Navíc se točí vajíčka v Hatchery.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local PetFollow = {}

local hatcheryEggs = {} -- { {Model, Base} }

local function findHatcheryEggs(): boolean
	table.clear(hatcheryEggs)
	local map = workspace:FindFirstChild("Map")
	local hatchery = map and map:FindFirstChild("Hatchery", true)
	if not hatchery then
		return false
	end
	for _, child in hatchery:GetChildren() do
		if child:IsA("Model") and child.Name == "HatcheryEgg" then
			table.insert(hatcheryEggs, { Model = child, Base = child:GetPivot() })
		end
	end
	return #hatcheryEggs > 0
end

function PetFollow.init()
	local t = 0
	-- lobby se může načíst až chvíli po startu klienta – zkoušíme, dokud vajíčka nenajdeme
	task.spawn(function()
		for _ = 1, 30 do
			task.wait(2)
			if findHatcheryEggs() then
				break
			end
		end
	end)

	RunService.RenderStepped:Connect(function(dt)
		t += dt
		local alpha = 1 - math.exp(-dt * 10)
		local petsFolder = workspace:FindFirstChild("Pets")
		if petsFolder then
			for _, folder in petsFolder:GetChildren() do
				local owner = Players:GetPlayerByUserId(tonumber(folder.Name) or 0)
				local character = owner and owner.Character
				local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
				local humanoid = character and character:FindFirstChildOfClass("Humanoid")
				if root and humanoid then
					local models = folder:GetChildren()
					table.sort(models, function(a, b)
						return a.Name < b.Name
					end)
					local n = #models
					local ground = root.Position.Y - (humanoid.HipHeight + root.Size.Y / 2)
					local moving = humanoid.MoveDirection.Magnitude > 0.1
					local look = root.CFrame.LookVector * Vector3.new(1, 0, 1)
					if look.Magnitude < 0.01 then
						look = Vector3.new(0, 0, -1)
					end
					look = look.Unit
					for i, model in models do
						if model:IsA("Model") then
							local column = i - (n + 1) / 2
							local spot = root.CFrame * CFrame.new(column * 3.2, 0, 4.2 + math.abs(column) * 0.8)
							local flying = model:GetAttribute("Flying")
							local bob = if moving
								then math.abs(math.sin(t * 9 + i)) * 0.6
								else math.sin(t * 2 + i) * 0.12 + 0.12
							local y = ground + bob + (if flying then 1.6 + math.sin(t * 2.5 + i) * 0.3 else 0)
							local position = Vector3.new(spot.Position.X, y, spot.Position.Z)
							local target = CFrame.lookAt(position, position + look)
							local current = model:GetPivot()
							if (current.Position - position).Magnitude > 60 then
								model:PivotTo(target) -- teleport (např. do lobby)
							else
								model:PivotTo(current:Lerp(target, alpha))
							end
						end
					end
				end
			end
		end
		-- vajíčka v Hatchery se točí a pohupují
		for i, egg in hatcheryEggs do
			if egg.Model.Parent then
				egg.Model:PivotTo(
					egg.Base * CFrame.new(0, math.sin(t * 1.6 + i) * 0.25 + 0.25, 0) * CFrame.Angles(0, t * 0.7 + i, 0)
				)
			end
		end
	end)
end

return PetFollow
