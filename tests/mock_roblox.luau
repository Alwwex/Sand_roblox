--!nocheck
-- Minimální mock Roblox API pro spuštění serverové logiky mimo Roblox (smoke test).
-- Nepoužívá se ve hře – jen pro automatické testy (tests/run_tests.py).

local mock = {}
local vclock = 0
mock.now = function()
	return vclock
end

---------------------------------------------------------------------
-- Vector3 / Vector2
---------------------------------------------------------------------
local V3 = {}
V3.__index = function(self, key)
	if key == "Magnitude" then
		return math.sqrt(self.X * self.X + self.Y * self.Y + self.Z * self.Z)
	elseif key == "Unit" then
		local m = math.sqrt(self.X * self.X + self.Y * self.Y + self.Z * self.Z)
		if m == 0 then
			return Vector3.new(0, 0, 0)
		end
		return Vector3.new(self.X / m, self.Y / m, self.Z / m)
	elseif key == "Dot" then
		return function(a, b)
			return a.X * b.X + a.Y * b.Y + a.Z * b.Z
		end
	elseif key == "Cross" then
		return function(a, b)
			return Vector3.new(a.Y * b.Z - a.Z * b.Y, a.Z * b.X - a.X * b.Z, a.X * b.Y - a.Y * b.X)
		end
	end
	return nil
end
local function isV3(v)
	return type(v) == "table" and getmetatable(v) == V3
end
V3.__add = function(a, b)
	return Vector3.new(a.X + b.X, a.Y + b.Y, a.Z + b.Z)
end
V3.__sub = function(a, b)
	return Vector3.new(a.X - b.X, a.Y - b.Y, a.Z - b.Z)
end
V3.__mul = function(a, b)
	if type(a) == "number" then
		return Vector3.new(b.X * a, b.Y * a, b.Z * a)
	elseif type(b) == "number" then
		return Vector3.new(a.X * b, a.Y * b, a.Z * b)
	end
	return Vector3.new(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
V3.__div = function(a, b)
	if type(b) == "number" then
		return Vector3.new(a.X / b, a.Y / b, a.Z / b)
	end
	return Vector3.new(a.X / b.X, a.Y / b.Y, a.Z / b.Z)
end
V3.__unm = function(a)
	return Vector3.new(-a.X, -a.Y, -a.Z)
end
V3.__eq = function(a, b)
	return a.X == b.X and a.Y == b.Y and a.Z == b.Z
end
V3.__tostring = function(a)
	return ("(%g, %g, %g)"):format(a.X, a.Y, a.Z)
end

Vector3 = {
	new = function(x, y, z)
		return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, V3)
	end,
}
Vector3.one = Vector3.new(1, 1, 1)
Vector3.zero = Vector3.new(0, 0, 0)

local V2 = {}
V2.__index = function(self, key)
	if key == "Magnitude" then
		return math.sqrt(self.X * self.X + self.Y * self.Y)
	end
	return nil
end
Vector2 = {
	new = function(x, y)
		return setmetatable({ X = x or 0, Y = y or 0 }, V2)
	end,
}
Vector2.zero = Vector2.new(0, 0)

---------------------------------------------------------------------
-- CFrame s rotací (matice 3x3 po řádcích + pozice)
---------------------------------------------------------------------
local CF = {}
local IDENT = { 1, 0, 0, 0, 1, 0, 0, 0, 1 }
local function mkCF(p, r)
	return setmetatable({ P = p, R = r or IDENT }, CF)
end
local function matMul(a, b)
	local r = {}
	for i = 0, 2 do
		for j = 0, 2 do
			r[i * 3 + j + 1] = a[i * 3 + 1] * b[j + 1] + a[i * 3 + 2] * b[3 + j + 1] + a[i * 3 + 3] * b[6 + j + 1]
		end
	end
	return r
end
local function matVec(a, v)
	return Vector3.new(
		a[1] * v.X + a[2] * v.Y + a[3] * v.Z,
		a[4] * v.X + a[5] * v.Y + a[6] * v.Z,
		a[7] * v.X + a[8] * v.Y + a[9] * v.Z
	)
end
local function transpose(a)
	return { a[1], a[4], a[7], a[2], a[5], a[8], a[3], a[6], a[9] }
end
CF.__index = function(self, key)
	local r = self.R
	if key == "Position" or key == "p" then
		return self.P
	elseif key == "LookVector" then
		return Vector3.new(-r[3], -r[6], -r[9])
	elseif key == "RightVector" then
		return Vector3.new(r[1], r[4], r[7])
	elseif key == "UpVector" then
		return Vector3.new(r[2], r[5], r[8])
	elseif key == "X" then
		return self.P.X
	elseif key == "Y" then
		return self.P.Y
	elseif key == "Z" then
		return self.P.Z
	elseif key == "Rotation" then
		return mkCF(Vector3.new(0, 0, 0), r)
	elseif key == "Inverse" then
		return function(s)
			local rt = transpose(s.R)
			return mkCF(-matVec(rt, s.P), rt)
		end
	elseif key == "Lerp" then
		-- zjednodušeně: lineárně pozice i matice (pro testy stačí)
		return function(s, other, t)
			local m = {}
			for i = 1, 9 do
				m[i] = s.R[i] + (other.R[i] - s.R[i]) * t
			end
			return mkCF(s.P + (other.P - s.P) * t, m)
		end
	elseif key == "GetComponents" then
		return function(s)
			local m = s.R
			return s.P.X, s.P.Y, s.P.Z, m[1], m[2], m[3], m[4], m[5], m[6], m[7], m[8], m[9]
		end
	end
	return nil
end
CF.__mul = function(a, b)
	if isV3(b) then
		return a.P + matVec(a.R, b)
	end
	return mkCF(a.P + matVec(a.R, b.P), matMul(a.R, b.R))
end
CF.__add = function(a, v)
	return mkCF(a.P + v, a.R)
end
CF.__sub = function(a, v)
	return mkCF(a.P - v, a.R)
end
local function rx(t)
	local c, s = math.cos(t), math.sin(t)
	return { 1, 0, 0, 0, c, -s, 0, s, c }
end
local function ry(t)
	local c, s = math.cos(t), math.sin(t)
	return { c, 0, s, 0, 1, 0, -s, 0, c }
end
local function rz(t)
	local c, s = math.cos(t), math.sin(t)
	return { c, -s, 0, s, c, 0, 0, 0, 1 }
end
CFrame = {
	new = function(x, y, z)
		if isV3(x) then
			return mkCF(x)
		end
		return mkCF(Vector3.new(x or 0, y or 0, z or 0))
	end,
	Angles = function(a, b, c)
		return mkCF(Vector3.new(0, 0, 0), matMul(matMul(rx(a or 0), ry(b or 0)), rz(c or 0)))
	end,
	lookAt = function(at, target, up)
		up = up or Vector3.new(0, 1, 0)
		local f = (target - at).Unit
		local right = Vector3.new(f.Y * up.Z - f.Z * up.Y, f.Z * up.X - f.X * up.Z, f.X * up.Y - f.Y * up.X)
		if right.Magnitude < 1e-6 then
			right = Vector3.new(1, 0, 0)
		end
		right = right.Unit
		local u =
			Vector3.new(right.Y * f.Z - right.Z * f.Y, right.Z * f.X - right.X * f.Z, right.X * f.Y - right.Y * f.X)
		return mkCF(at, { right.X, u.X, -f.X, right.Y, u.Y, -f.Y, right.Z, u.Z, -f.Z })
	end,
}
CFrame.fromMatrix = function(pos, vx, vy, vz)
	vz = vz or vx:Cross(vy)
	return mkCF(pos, { vx.X, vy.X, vz.X, vx.Y, vy.Y, vz.Y, vx.Z, vy.Z, vz.Z })
end
CFrame.identity = CFrame.new()

---------------------------------------------------------------------
-- Ostatní datové typy
---------------------------------------------------------------------
local function dataType(name)
	return setmetatable({}, {
		__index = function(_, key)
			return function(...)
				return { __type = name, __ctor = key, args = { ... } }
			end
		end,
	})
end
Color3 = dataType("Color3")
Color3.new = function(r, g, b)
	return {
		__type = "Color3",
		R = r,
		G = g,
		B = b,
		Lerp = function(self, other, t)
			return Color3.new(
				self.R + (other.R - self.R) * t,
				self.G + (other.G - self.G) * t,
				self.B + (other.B - self.B) * t
			)
		end,
	}
end
Color3.fromRGB = function(r, g, b)
	return Color3.new(r / 255, g / 255, b / 255)
end
Color3.fromHex = function(hex)
	hex = hex:gsub("#", "")
	return Color3.fromRGB(tonumber(hex:sub(1, 2), 16), tonumber(hex:sub(3, 4), 16), tonumber(hex:sub(5, 6), 16))
end
ColorSequence = dataType("ColorSequence")
ColorSequenceKeypoint = dataType("ColorSequenceKeypoint")
NumberSequence = dataType("NumberSequence")
NumberSequenceKeypoint = dataType("NumberSequenceKeypoint")
NumberRange = dataType("NumberRange")
UDim = dataType("UDim")
UDim2 = dataType("UDim2")
TweenInfo = dataType("TweenInfo")

local enumCache = {}
Enum = setmetatable({}, {
	__index = function(_, enumName)
		enumCache[enumName] = enumCache[enumName]
			or setmetatable({}, {
				__index = function(t, itemName)
					local item = { Name = itemName, EnumType = enumName }
					rawset(t, itemName, item)
					return item
				end,
			})
		return enumCache[enumName]
	end,
})

Random = {
	new = function(seedValue)
		local state = seedValue or 12345
		local function nextRaw()
			state = (state * 1103515245 + 12345) % 2147483648
			return state / 2147483648
		end
		return {
			NextNumber = function(_, a, b)
				a = a or 0
				b = b or 1
				return a + (b - a) * nextRaw()
			end,
			NextInteger = function(_, a, b)
				return math.floor(a + (b - a + 1) * nextRaw())
			end,
		}
	end,
}

RaycastParams = {
	new = function()
		return {}
	end,
}

Region3 = {}
local R3 = {}
R3.__index = R3
function Region3.new(min, max)
	return setmetatable({ Min = min, Max = max, CFrame = CFrame.new((min + max) / 2), Size = max - min }, R3)
end
function R3:ExpandToGrid(res)
	local function down(v)
		return math.floor(v / res) * res
	end
	local function up(v)
		return math.ceil(v / res) * res
	end
	return Region3.new(
		Vector3.new(down(self.Min.X), down(self.Min.Y), down(self.Min.Z)),
		Vector3.new(up(self.Max.X), up(self.Max.Y), up(self.Max.Z))
	)
end

---------------------------------------------------------------------
-- Signály a univerzální Instance
---------------------------------------------------------------------
local function newSignal()
	local signal = { connections = {} }
	function signal:Connect(fn)
		table.insert(self.connections, fn)
		return {
			Disconnect = function() end,
		}
	end
	function signal:Fire(...)
		for _, fn in self.connections do
			fn(...)
		end
	end
	function signal:Wait() end
	return signal
end
mock.newSignal = newSignal

local SIGNAL_NAMES = {
	Touched = true,
	Triggered = true,
	OnServerEvent = true,
	OnClientEvent = true,
	PlayerAdded = true,
	PlayerRemoving = true,
	CharacterAdded = true,
	Heartbeat = true,
	RenderStepped = true,
	Died = true,
	ChildAdded = true,
	ChildRemoved = true,
	AncestryChanged = true,
	Activated = true,
	Deactivated = true,
	Unequipped = true,
	PromptGamePassPurchaseFinished = true,
	Completed = true,
	MouseButton1Down = true,
	MouseButton1Up = true,
	MouseLeave = true,
	InputBegan = true,
	InputChanged = true,
	Changed = true,
	MouseEnter = true,
	InputEnded = true,
}

local Instance_ = {}
local function newInstance(className, name)
	local data = {
		ClassName = className,
		Name = name or className,
		__children = {},
		__attributes = {},
		__signals = {},
	}
	local obj = {}
	local methods = {}
	function methods:IsA(cls)
		if cls == "BasePart" then
			return data.ClassName == "Part"
				or data.ClassName == "SpawnLocation"
				or data.ClassName == "WedgePart"
				or data.ClassName == "MeshPart"
		end
		if cls == "GuiObject" then
			return data.ClassName == "Frame" or data.ClassName == "TextLabel" or data.ClassName == "TextButton"
		end
		return data.ClassName == cls
	end
	function methods:GetChildren()
		return table.clone(data.__children)
	end
	function methods:GetDescendants()
		local out = {}
		local function walk(o)
			for _, c in o:GetChildren() do
				table.insert(out, c)
				walk(c)
			end
		end
		walk(obj)
		return out
	end
	function methods:FindFirstChild(n)
		for _, c in data.__children do
			if c.Name == n then
				return c
			end
		end
		return nil
	end
	function methods:WaitForChild(n)
		return obj:FindFirstChild(n)
	end
	function methods:Clone()
		local copy = newInstance(data.ClassName, data.Name)
		local cd = mock.dataOf(copy)
		for key, value in data do
			if type(key) == "string" and key:sub(1, 2) ~= "__" and key ~= "Parent" then
				cd[key] = value
			end
		end
		for key, value in data.__attributes do
			cd.__attributes[key] = value
		end
		for _, child in data.__children do
			child:Clone().Parent = copy
		end
		return copy
	end
	function methods:FindFirstChildOfClass(cls)
		for _, c in data.__children do
			if c.ClassName == cls then
				return c
			end
		end
		return nil
	end
	function methods:IsDescendantOf()
		return true
	end
	function methods:SetAttribute(k, v)
		data.__attributes[k] = v
	end
	function methods:GetAttribute(k)
		return data.__attributes[k]
	end
	function methods:GetAttributeChangedSignal()
		return newSignal()
	end
	function methods:GetPropertyChangedSignal()
		return newSignal()
	end
	function methods:Destroy()
		obj.Parent = nil
		data.__destroyed = true
	end
	function methods:ClearAllChildren()
		for _, c in table.clone(data.__children) do
			c:Destroy()
		end
	end
	function methods:GetPivot()
		if data.CFrame then
			return obj.CFrame
		end
		if data.__pivot then
			return data.__pivot
		end
		local primary = data.PrimaryPart
		if primary then
			return primary.CFrame
		end
		return CFrame.new()
	end
	function methods:PivotTo(cf)
		data.__pivot = cf
		if data.CFrame or data.Position then
			obj.CFrame = cf
			return
		end
		local parts = {}
		for _, d in obj:GetDescendants() do
			if d:IsA("BasePart") then
				table.insert(parts, d)
			end
		end
		local pivotPart = data.PrimaryPart or parts[1]
		if not pivotPart then
			return
		end
		local delta = cf * pivotPart.CFrame:Inverse()
		for _, part in parts do
			part.CFrame = delta * part.CFrame
		end
	end
	function methods:FireClient(...)
		data.__fired = data.__fired or {}
		table.insert(data.__fired, { ... })
	end
	function methods:FireAllClients(...)
		data.__fired = data.__fired or {}
		table.insert(data.__fired, { "ALL", ... })
	end
	function methods:InvokeServer(...)
		return data.OnServerInvoke(mock.localPlayer, ...)
	end
	function methods:FireServer(...)
		obj.OnServerEvent:Fire(mock.localPlayer, ...)
	end
	function methods:AddItem() end
	function methods:Pause() end
	function methods:Stop() end
	function methods:GetMouseLocation()
		return Vector2.new(400, 300)
	end
	function methods:Emit() end
	function methods:Play() end
	function methods:EquipTool(tool)
		tool.Parent = data.Parent
	end
	function methods:UnequipTools()
		local character = data.Parent
		local player = mock.services.Players:GetPlayerFromCharacter(character)
		local backpack = player and player:FindFirstChildOfClass("Backpack")
		for _, child in character:GetChildren() do
			if child.ClassName == "Tool" and backpack then
				child.Parent = backpack
			end
		end
	end
	function methods:SetCoreGuiEnabled(kind, enabled)
		mock.coreGui = mock.coreGui or {}
		mock.coreGui[kind.Name] = enabled
	end
	data.__methods = methods

	setmetatable(obj, {
		__index = function(_, key)
			if methods[key] then
				return methods[key]
			end
			if data[key] ~= nil then
				return data[key]
			end
			if key == "Position" and data.CFrame then
				return data.CFrame.Position
			elseif key == "CFrame" and data.Position then
				return CFrame.new(data.Position)
			end
			if SIGNAL_NAMES[key] then
				data.__signals[key] = data.__signals[key] or newSignal()
				return data.__signals[key]
			end
			for _, c in data.__children do
				if c.Name == key then
					return c
				end
			end
			return nil
		end,
		__newindex = function(_, key, value)
			if key == "Position" and data.CFrame and isV3(value) then
				data.CFrame = CFrame.new(value) * data.CFrame.Rotation
				return
			elseif key == "CFrame" then
				data.Position = nil
			end
			if key == "Value" and string.sub(data.ClassName, -5) == "Value" then
				data.Value = value
				if data.__signals.Changed then
					data.__signals.Changed:Fire(value)
				end
				return
			end
			if key == "Parent" then
				local old = data.Parent
				if old then
					local siblings = Instance_.childrenOf(old)
					local idx = table.find(siblings, obj)
					if idx then
						table.remove(siblings, idx)
					end
				end
				data.Parent = value
				if value then
					table.insert(Instance_.childrenOf(value), obj)
				end
			else
				data[key] = value
			end
		end,
		__tostring = function()
			return data.ClassName .. ":" .. tostring(data.Name)
		end,
	})
	Instance_.registry[obj] = data
	return obj
end
Instance_.registry = setmetatable({}, { __mode = "k" })
function Instance_.childrenOf(obj)
	return Instance_.registry[obj].__children
end
mock.dataOf = function(obj)
	return Instance_.registry[obj]
end

Instance = {
	new = function(className)
		return newInstance(className)
	end,
}

---------------------------------------------------------------------
-- Terrain s opravdovým voxelovým úložištěm
---------------------------------------------------------------------
local voxels = {} -- key "x,y,z" -> occupancy (jen Sand)
mock.voxels = voxels
local function vkey(ix, iy, iz)
	return ix .. "," .. iy .. "," .. iz
end

local function makeTerrain()
	local terrain = newInstance("Terrain", "Terrain")
	local methods = mock.dataOf(terrain).__methods
	function methods:Clear()
		table.clear(voxels)
	end
	function methods:SetMaterialColor() end
	function methods:FillBlock(cframe, size, material)
		mock.waterFilled = (mock.waterFilled or 0) + 1
	end
	function methods:WriteVoxels(region, res, materials, occupancy)
		assert(res == 4, "resolution must be 4")
		local size = (region.Max - region.Min) / res
		assert(size.X % 1 == 0 and size.Y % 1 == 0 and size.Z % 1 == 0, "region not aligned")
		assert(region.Min.X % 4 == 0 and region.Min.Y % 4 == 0 and region.Min.Z % 4 == 0, "region min not aligned")
		assert(#materials == size.X, "materials X size mismatch " .. #materials .. " vs " .. size.X)
		for x = 1, size.X do
			assert(#materials[x] == size.Y, "materials Y size mismatch")
			for y = 1, size.Y do
				assert(#materials[x][y] == size.Z, "materials Z size mismatch")
				for z = 1, size.Z do
					local ix = region.Min.X / 4 + x - 1
					local iy = region.Min.Y / 4 + y - 1
					local iz = region.Min.Z / 4 + z - 1
					local mat = materials[x][y][z]
					local occ = occupancy[x][y][z]
					assert(type(occ) == "number", "occupancy must be number")
					if mat == Enum.Material.Sand and occ > 0 then
						voxels[vkey(ix, iy, iz)] = occ
					else
						voxels[vkey(ix, iy, iz)] = nil
					end
				end
			end
		end
	end
	function methods:ReadVoxels(region, res)
		assert(res == 4)
		local size = (region.Max - region.Min) / res
		local mats, occs = {}, {}
		for x = 1, size.X do
			mats[x], occs[x] = {}, {}
			for y = 1, size.Y do
				mats[x][y], occs[x][y] = {}, {}
				for z = 1, size.Z do
					local ix = region.Min.X / 4 + x - 1
					local iy = region.Min.Y / 4 + y - 1
					local iz = region.Min.Z / 4 + z - 1
					local occ = voxels[vkey(ix, iy, iz)]
					mats[x][y][z] = if occ then Enum.Material.Sand else Enum.Material.Air
					occs[x][y][z] = occ or 0
				end
			end
		end
		mats.Size = size
		return mats, occs
	end
	function methods:FillBall(center, radius, material)
		assert(material == Enum.Material.Air)
		local r = radius + 2
		for ix = math.floor((center.X - r) / 4), math.floor((center.X + r) / 4) do
			for iy = math.floor((center.Y - r) / 4), math.floor((center.Y + r) / 4) do
				for iz = math.floor((center.Z - r) / 4), math.floor((center.Z + r) / 4) do
					local c = Vector3.new(ix * 4 + 2, iy * 4 + 2, iz * 4 + 2)
					local d = (c - center).Magnitude
					local coverage = math.clamp((radius + 2 - d) / 4, 0, 1)
					local key = vkey(ix, iy, iz)
					if voxels[key] and coverage > 0 then
						local new = voxels[key] - coverage
						voxels[key] = if new > 0.01 then new else nil
					end
				end
			end
		end
	end
	return terrain
end

---------------------------------------------------------------------
-- Služby
---------------------------------------------------------------------
local services = {}

workspace = newInstance("Workspace", "Workspace")
local terrain = makeTerrain()
terrain.Parent = workspace
mock.dataOf(workspace).Terrain = terrain
mock.dataOf(workspace).__methods.Raycast = function(_, origin, direction)
	-- jen svislé paprsky dolů do terénu
	local ix, iz = math.floor(origin.X / 4), math.floor(origin.Z / 4)
	for iy = 20, 0, -1 do
		local occ = voxels[vkey(ix, iy, iz)]
		if occ and occ > 0.05 then
			return { Position = Vector3.new(origin.X, iy * 4 + occ * 4, origin.Z), Instance = terrain }
		end
	end
	return nil
end
mock.dataOf(workspace).__methods.BindToClose = function() end

local players = newInstance("Players", "Players")
mock.playerList = {}
mock.dataOf(players).__methods.GetPlayers = function()
	return table.clone(mock.playerList)
end
mock.dataOf(players).__methods.GetPlayerFromCharacter = function(_, character)
	for _, p in mock.playerList do
		if p.Character == character then
			return p
		end
	end
	return nil
end
mock.dataOf(players).__methods.GetPlayerByUserId = function(_, id)
	-- odzadu: po znovupřipojení platí nejnovější hráč
	for i = #mock.playerList, 1, -1 do
		local p = mock.playerList[i]
		if p.UserId == id then
			return p
		end
	end
	return nil
end
mock.dataOf(players).__methods.GetNameFromUserIdAsync = function(_, id)
	return "User" .. id
end
mock.dataOf(players).__methods.CreateHumanoidModelFromUserId = function()
	error("not available in mock")
end
services.Players = players

local stores = {}
mock.stores = stores
local dataStoreService = newInstance("DataStoreService")
mock.dataOf(dataStoreService).__methods.GetDataStore = function(_, name)
	stores[name] = stores[name] or {}
	local backing = stores[name]
	return {
		UpdateAsync = function(_, key, fn)
			local result = fn(backing[key])
			if result ~= nil then
				backing[key] = result
			end
			return result
		end,
		GetAsync = function(_, key)
			return backing[key]
		end,
	}
end
mock.ordered = {}
mock.dataOf(dataStoreService).__methods.GetOrderedDataStore = function(_, name)
	mock.ordered[name] = mock.ordered[name] or {}
	local backing = mock.ordered[name]
	return {
		SetAsync = function(_, key, value)
			assert(type(value) == "number" and value == math.floor(value), "ordered value must be integer")
			backing[key] = value
		end,
		GetSortedAsync = function(_, ascending, pageSize)
			local list = {}
			for k, v in backing do
				table.insert(list, { key = k, value = v })
			end
			table.sort(list, function(a, b)
				return if ascending then a.value < b.value else a.value > b.value
			end)
			while #list > pageSize do
				table.remove(list)
			end
			return {
				GetCurrentPage = function()
					return list
				end,
			}
		end,
	}
end
services.DataStoreService = dataStoreService

local http = newInstance("HttpService")
mock.dataOf(http).__methods.JSONEncode = function(_, value)
	mock.lastJson = value
	return "<json>"
end
mock.dataOf(http).__methods.JSONDecode = function(_, text)
	return mock.lastJson or {}
end
services.HttpService = http

local runService = newInstance("RunService")
mock.dataOf(runService).__methods.IsStudio = function()
	return false
end
mock.dataOf(runService).__methods.IsServer = function()
	return true
end
mock.dataOf(runService).__methods.IsClient = function()
	return false
end
services.RunService = runService

local tweenService = newInstance("TweenService")
mock.dataOf(tweenService).__methods.Create = function(_, instance, _info, goals)
	local tween = newInstance("Tween")
	mock.dataOf(tween).__methods.Play = function()
		-- v mocku animace hned skončí (náhledy pak ukazují koncový stav)
		for key, value in goals or {} do
			instance[key] = value
		end
	end
	return tween
end
services.TweenService = tweenService

local marketplace = newInstance("MarketplaceService")
mock.dataOf(marketplace).__methods.UserOwnsGamePassAsync = function()
	return false
end
mock.dataOf(marketplace).__methods.PromptGamePassPurchase = function(_, _, id)
	mock.lastPrompt = { "Pass", id }
end
mock.dataOf(marketplace).__methods.PromptProductPurchase = function(_, _, id)
	mock.lastPrompt = { "Product", id }
end
mock.dataOf(marketplace).__methods.GetProductInfo = function()
	return { PriceInRobux = 199 }
end
services.MarketplaceService = marketplace

for _, name in
	{
		"ReplicatedStorage",
		"Lighting",
		"Debris",
		"SoundService",
		"ServerStorage",
		"TextChatService",
		"UserInputService",
		"StarterGui",
	}
do
	services[name] = newInstance(name, name)
end

game = newInstance("DataModel", "Game")
mock.dataOf(game).JobId = "test-job"
mock.dataOf(game).__methods.GetService = function(_, name)
	local s = services[name]
	assert(s, "unknown service " .. tostring(name))
	return s
end
mock.dataOf(game).__methods.BindToClose = function() end
mock.dataOf(game).__methods.IsLoaded = function()
	return true
end
mock.services = services

---------------------------------------------------------------------
-- task scheduler s virtuálním časem
---------------------------------------------------------------------
local sleeping = {}
local function schedule(co, at, ...)
	table.insert(sleeping, { co = co, at = at, args = { ... } })
end
local function resume(co, ...)
	local ok, err = coroutine.resume(co, ...)
	if not ok then
		error("coroutine error: " .. tostring(err), 0)
	end
end
task = {
	wait = function(t)
		t = t or 0
		local co = coroutine.running()
		if co and coroutine.isyieldable() then
			schedule(co, vclock + math.max(t, 0.001))
			coroutine.yield()
		else
			vclock += t
		end
		return t
	end,
	spawn = function(fn, ...)
		local co = if type(fn) == "thread" then fn else coroutine.create(fn)
		resume(co, ...)
		return co
	end,
	defer = function(fn, ...)
		local co = coroutine.create(fn)
		schedule(co, vclock, ...)
		return co
	end,
	delay = function(t, fn, ...)
		local co = coroutine.create(fn)
		schedule(co, vclock + t, ...)
		return co
	end,
}
mock.advance = function(seconds)
	local target = vclock + seconds
	while true do
		table.sort(sleeping, function(a, b)
			return a.at < b.at
		end)
		local nextItem = sleeping[1]
		if not nextItem or nextItem.at > target then
			break
		end
		table.remove(sleeping, 1)
		vclock = math.max(vclock, nextItem.at)
		if coroutine.status(nextItem.co) == "suspended" then
			resume(nextItem.co, table.unpack(nextItem.args))
		end
	end
	vclock = target
end

os.clock = function()
	return vclock
end
local realTime = os.time
os.time = function(t)
	if t then
		return realTime(t)
	end
	return 1700000000 + math.floor(vclock)
end

warn = function(...)
	print("[warn]", ...)
end
typeof = function(v)
	if isV3(v) then
		return "Vector3"
	end
	return type(v)
end

---------------------------------------------------------------------
-- Moduly (require)
---------------------------------------------------------------------
local moduleSources = {}
local moduleCache = {}
mock.defineModule = function(name, fn)
	moduleSources[name] = fn
end
mock.moduleScript = function(name, parent)
	local m = newInstance("ModuleScript", name)
	mock.dataOf(m).__module = name
	if parent then
		m.Parent = parent
	end
	return m
end
require = function(m)
	local data = mock.dataOf(m)
	local name = data.__module
	assert(name, "require of non-module " .. tostring(m))
	if moduleCache[name] == nil then
		moduleCache[name] = moduleSources[name](m)
	end
	return moduleCache[name]
end

mock.newPlayer = function(userId, name)
	local p = newInstance("Player", name)
	mock.dataOf(p).UserId = userId
	mock.dataOf(p).DisplayName = name
	mock.dataOf(p).__methods.Kick = function(_, msg)
		error("KICKED: " .. tostring(msg))
	end
	mock.dataOf(p).__methods.IsInGroup = function()
		return false
	end
	mock.dataOf(p).__methods.LoadCharacter = function(self)
		local character = newInstance("Model", name)
		local root = newInstance("Part", "HumanoidRootPart")
		root.Position = Vector3.new(0, 34, 8)
		root.Parent = character
		root.Size = Vector3.new(2, 2, 1)
		local humanoid = newInstance("Humanoid", "Humanoid")
		humanoid.Health = 100
		humanoid.HipHeight = 2
		humanoid.MoveDirection = Vector3.new(0, 0, 0)
		humanoid.Parent = character
		local backpack = newInstance("Backpack", "Backpack")
		backpack.Parent = self
		self.Character = character
		character.Parent = workspace
		self.CharacterAdded:Fire(character)
	end
	p.Parent = players
	table.insert(mock.playerList, p)
	return p
end

return mock
