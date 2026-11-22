--!nocheck
-- Export pro náhledové obrázky (lobby + UI). Spouští: python3 tests/run_tests.py --preview <složka>
-- Vypisuje řádky "@@JSON <jméno> <json>".

local function isV2(v)
	return type(v) == "table" and v.X ~= nil and v.Y ~= nil and v.Z == nil and v.__type == nil
end

local function norm(v)
	if type(v) ~= "table" then
		return v
	end
	if v.__type == "UDim2" then
		local a = v.args
		if v.__ctor == "new" then
			return { xs = a[1] or 0, xo = a[2] or 0, ys = a[3] or 0, yo = a[4] or 0 }
		elseif v.__ctor == "fromOffset" then
			return { xs = 0, xo = a[1] or 0, ys = 0, yo = a[2] or 0 }
		elseif v.__ctor == "fromScale" then
			return { xs = a[1] or 0, xo = 0, ys = a[2] or 0, yo = 0 }
		end
	elseif v.__type == "UDim" then
		return { s = v.args[1] or 0, o = v.args[2] or 0 }
	elseif v.__type == "Color3" then
		return { v.R, v.G, v.B }
	elseif v.__type == "ColorSequence" then
		local a = v.args
		if type(a[1]) == "table" and a[1].__type == "Color3" then
			return { norm(a[1]), norm(a[2] or a[1]) }
		end
		return nil
	elseif v.__type then
		return nil
	elseif isV2(v) then
		return { v.X, v.Y }
	elseif v.Name and v.EnumType then
		return v.Name
	end
	return nil
end

local function encode(v)
	local t = type(v)
	if t == "nil" then
		return "null"
	elseif t == "boolean" then
		return tostring(v)
	elseif t == "number" then
		if v ~= v or v == math.huge or v == -math.huge then
			return "0"
		end
		return string.format("%.6g", v)
	elseif t == "string" then
		return '"' .. v:gsub('[%c"\\]', function(c)
			if c == "\n" then
				return "\\n"
			elseif c == '"' then
				return '\\"'
			elseif c == "\\" then
				return "\\\\"
			end
			return ""
		end) .. '"'
	elseif t == "table" then
		if #v > 0 then
			local parts = {}
			for _, item in v do
				table.insert(parts, encode(item))
			end
			return "[" .. table.concat(parts, ",") .. "]"
		end
		local parts = {}
		for k, item in v do
			if type(k) == "string" and type(item) ~= "function" then
				table.insert(parts, encode(k) .. ":" .. encode(item))
			end
		end
		return "{" .. table.concat(parts, ",") .. "}"
	end
	return "null"
end

local function emit(name, value)
	print("@@JSON " .. name .. " " .. encode(value))
end

local function partInfo(part)
	local d = mock.dataOf(part)
	local cf = part.CFrame
	local comps = { cf:GetComponents() }
	local hasSphere = false
	for _, child in part:GetChildren() do
		if child.ClassName == "SpecialMesh" then
			hasSphere = true
		end
	end
	return {
		n = d.Name,
		c = d.ClassName,
		s = if type(d.Size) == "table" and d.Size.Z then { d.Size.X, d.Size.Y, d.Size.Z } else { 1, 1, 1 },
		cf = comps,
		col = norm(d.Color) or { 0.6, 0.6, 0.6 },
		m = norm(d.Material) or "Plastic",
		sh = norm(d.Shape),
		t = d.Transparency or 0,
		sp = hasSphere,
	}
end

local function serializeGui(inst)
	local d = mock.dataOf(inst)
	local node = { c = d.ClassName, n = d.Name, p = {}, k = {} }
	for key, value in d do
		if type(key) == "string" and key:sub(1, 2) ~= "__" and key ~= "Parent" and key ~= "ClassName" and key ~= "Name" then
			local nv = norm(value)
			if nv ~= nil and type(nv) ~= "function" then
				node.p[key] = nv
			end
		end
	end
	if inst:IsA("BasePart") then
		node.part = partInfo(inst)
	end
	for _, child in d.__children do
		table.insert(node.k, serializeGui(child))
	end
	return node
end

---------------------------------------------------------------------
-- 1) Lobby a okolí
---------------------------------------------------------------------
local parts = {}
local labels = {}
local signs = {}
local map = workspace:FindFirstChild("Map")
local index = {}
for _, inst in map:GetDescendants() do
	if inst:IsA("BasePart") then
		local p = inst.Position
		if p and math.abs(p.X) < 170 and math.abs(p.Z) < 170 then
			table.insert(parts, partInfo(inst))
			index[inst] = #parts
		end
	end
end
for _, inst in map:GetDescendants() do
	local cls = inst.ClassName
	if cls == "BillboardGui" or cls == "SurfaceGui" then
		local part = inst.Parent
		local label
		for _, child in inst:GetChildren() do
			if child.ClassName == "TextLabel" then
				label = label or child
			end
		end
		if part and index[part] and label then
			local d = mock.dataOf(inst)
			if cls == "BillboardGui" then
				table.insert(labels, {
					i = index[part],
					text = label.Text,
					col = norm(label.TextColor3),
					off = d.StudsOffset and { d.StudsOffset.X, d.StudsOffset.Y, d.StudsOffset.Z } or { 0, 0, 0 },
					size = norm(d.Size),
				})
			else
				table.insert(signs, { i = index[part], text = label.Text, col = norm(label.TextColor3), face = norm(d.Face) or "Front" })
			end
		end
	end
end
local heights = {}
for z = -170, 170, 4 do
	local row = {}
	for x = -170, 170, 4 do
		local hit = workspace:Raycast(Vector3.new(x, 200, z), Vector3.new(0, -300, 0))
		table.insert(row, if hit then hit.Position.Y else 0)
	end
	table.insert(heights, row)
end
emit("lobby", { parts = parts, labels = labels, signs = signs, heights = heights, step = 4, origin = -170 })

---------------------------------------------------------------------
-- 2) UI v různých stavech
---------------------------------------------------------------------
local Players = mock.services.Players
local localPlayer = mock.playerList[#mock.playerList]
mock.localPlayer = localPlayer
mock.dataOf(Players).LocalPlayer = localPlayer
local playerGui = Instance.new("PlayerGui")
playerGui.Name = "PlayerGui"
playerGui.Parent = localPlayer
localPlayer:LoadCharacter()
mock.advance(1)
runClient()
mock.advance(1)

local DataService = require(tree.Services.DataService)
local Remotes = require(tree.Shared.Remotes)
local UI = require(tree.Client.UI)
local session = DataService.get(localPlayer)
-- ukázkový stav hráče
session.Data.Coins = 48250
session.Data.TotalCoins = 912400
session.Data.Sand = 1730
session.Data.EquippedBackpack = "Wheelbarrow"
session.Data.OwnedBackpacks = { Pocket = true, Bucket = true, Sack = true, Wheelbarrow = true }
session.Data.OwnedTools = { Hands = true, Spoon = true, Trowel = true, Shovel = true, Vacuum = true }
session.Data.EquippedTool = "Vacuum"
session.Data.Rebirths = 2
session.Data.Artifacts = { AncientCoin = 3, BronzeBeetle = 1, DesertRose = 1, SunStone = 1 }
session.Data.LastDaily = 0
session.Passes.AutoSell = true
workspace:SetAttribute("DesertCleared", 0.34)
workspace:SetAttribute("StormIn", 754)
workspace:SetAttribute("StormPhase", "Calm")
mock.lastJson = {
	Coins = {
		{ UserId = 1, Name = "SandKing_2013", Value = 98400000 },
		{ UserId = 2, Name = "dunequeen", Value = 41250000 },
		{ UserId = 3, Name = "NoobDigger77", Value = 12800000 },
		{ UserId = 4, Name = "xX_Shovel_Xx", Value = 6100000 },
		{ UserId = 5, Name = "pyramidpro", Value = 2950000 },
		{ UserId = 6, Name = "camel_rider", Value = 1420000 },
		{ UserId = localPlayer.UserId, Name = "Tester", Value = 912400 },
		{ UserId = 8, Name = "goldenspoon", Value = 640000 },
		{ UserId = 9, Name = "Tumbleweed", Value = 210000 },
		{ UserId = 10, Name = "oasis_kid", Value = 98000 },
	},
}

local gui = playerGui:FindFirstChild("DuneDiggersUI")
emit("ui_menu", serializeGui(gui))

-- PLAY
for _, inst in gui:GetDescendants() do
	if inst.ClassName == "TextButton" and inst.Text == "PLAY!" then
		inst.Activated:Fire()
	end
end
mock.advance(2)
Remotes.DataSync.OnClientEvent:Fire(DataService.buildPayload(session))
UI.toast("🐞 Bronze Beetle found! +5% coins forever", "rarity:Rare")
UI.toast("Sold 1,730 sand for 7,785 coins!", "success")
emit("ui_hud", serializeGui(gui))
mock.advance(6)

for _, name in { "Shop", "Store", "Top", "Index", "Rebirth", "Settings" } do
	UI.open(name)
	Remotes.DataSync.OnClientEvent:Fire(DataService.buildPayload(session))
	emit("ui_" .. string.lower(name), serializeGui(gui))
	UI.close()
end
