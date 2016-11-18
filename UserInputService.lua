-- @author Narrev
-- @original ScriptGuider
-- UserInputService wrapper

-- Services
local GetService = game.GetService
local InputService = GetService(game, "UserInputService")
local RunService = GetService(game, "RunService")
local StarterGui = GetService(game, "StarterGui")
local Players = GetService(game, "Players")

-- Optimize
local GetKeysPressed = InputService.GetKeysPressed
local Connect = InputService.InputBegan.Connect
local Heartbeat = RunService.Heartbeat
local Wait = Heartbeat.Wait
local SetCore = StarterGui.SetCore
local Destroy = game.Destroy
local GetChildren = game.GetChildren

local sub = string.sub
local time = os.time
local find = string.find
local remove = table.remove
local newInstance = Instance.new
local type, select, setmetatable, rawset, tostring, tick = type, select, setmetatable, rawset, tostring, tick

local Fire, Disconnect do
	local Bindable = newInstance("BindableEvent")
	local Connection = Connect(Bindable.Event, function() end)
	Fire, Disconnect = Bindable.Fire, Connection.Disconnect
	Disconnect(Connection)
	Destroy(Bindable)
end

-- Client
local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")
local PlayerMouse = Player:GetMouse()

local function DisconnectConnector(self)
	self.Signal.Main = nil
end

local Disconnector = {Disconnect = DisconnectConnector}
Disconnector.__index = Disconnector

local function ConnectSignal(self, func)
	-- Bind first function to this thread
	-- Bind additional functions to bindable
	assert(func, "Please connect a function to " .. self.KeyCode.Name)
	if self.Main then
		local Bindable = self.Bindable
		if Bindable then
			local Connections = self.Connections
			local Connection = Connect(Bindable.Event, func)
			if Connections then
				Connections[#Connections + 1] = Connection
			else
				self.Connections = {Connection}
			end
			return Connection
		else
			local Bindable = newInstance("BindableEvent")
			self.Bindable = Bindable
			local Connection = Connect(Bindable.Event, func)
			self.Connections = {Connection}
			return Connection
		end
	else
		self.Main = func
		return setmetatable({Signal = self}, Disconnector)
	end
end

local function DisconnectSignal(self)
	self.Main = nil
	local Connections = self.Connections
	if Connections then
		for a = 1, #Connections do
			Disconnect(Connections[a])
		end
		self.Connections = nil
	end
end

local function WaitSignal(self)
	local Bindable = self.Bindable
	if Bindable then
		Wait(Bindable.Event)
	else
		Bindable = newInstance("BindableEvent")
		self.Bindable = Bindable
		Wait(Bindable.Event)
		if not self.Connections then
			self.Bindable = Destroy(Bindable)
		end
	end
end

local function FireSignal(self)
	local Main, Bindable = self.Main, self.Bindable
	if Bindable then
		Fire(Bindable)
	end
	if Main then
		Main()
	end
end

local Signal = {
	Wait = WaitSignal;
	Fire = FireSignal;
	Press = FireSignal;
	Connect = ConnectSignal;
	Disconnect = DisconnectSignal;
}

local function newSignal(KeyCode)
	return setmetatable({KeyCode = KeyCode}, Signal)
end

local function AddSignals(a, b) -- This looks way scarier than it is
	a, b = a.KeyDown or a, b.KeyDown or b
	local KeyCodes, Combination, NumberOfKeyCodes = a.KeyCode
	local KeyCodeIsTable = type(KeyCodes) == "table"

	if KeyCodeIsTable then
		Combination = {}
		NumberOfKeyCodes = #KeyCodes
		for a = 1, NumberOfKeyCodes do
			Combination[a] = KeyCodes[a]
		end
		Combination[NumberOfKeyCodes + 1] = b.KeyCode
	else
		Combination = {KeyCodes, b.KeyCode}
	end

	Combination = newSignal(Combination)
	ConnectSignal(b, function()
		if #Combination > 0 then -- Save on gas mileage
			local KeysPressed = GetKeysPressed(InputService)
			local NumberOfKeysPressed = #KeysPressed
			local AllButtonsArePressed = true

			if KeyCodeIsTable then
				for c = 1, NumberOfKeyCodes do
					if AllButtonsArePressed then
						AllButtonsArePressed = false
						local KeyCode = KeyCodes[c]
						for d = 1, NumberOfKeysPressed do
							if KeysPressed[d].KeyCode == KeyCode then
								AllButtonsArePressed = true
								break
							end
						end
					else break
					end
				end
			else
				AllButtonsArePressed = false
				for e = 1, NumberOfKeysPressed do
					if KeysPressed[e].KeyCode == KeyCodes then
						AllButtonsArePressed = true
						break
					end
				end
			end

			if AllButtonsArePressed then
				FireSignal(Combination)
			end
		end
	end)

	return Combination
end
Signal.__add = AddSignals
Signal.__index = Signal

-- Library & Input
local RegisteredKeys = {}
local Keys  = {}
local Mouse = {__newindex = PlayerMouse}
local Key = {__add = AddSignals}

function Key:__index(i)
	local KeyDown = self.KeyDown
	local Method = KeyDown[i]
	local function Wrap(_, ...)
		return Method(KeyDown, ...)
	end
	self[i] = Wrap
	return Wrap
end

function Keys:__index(v)
	assert(type(v) == "string", "Table Keys should be indexed by a string")
	local Connections = setmetatable({
		KeyUp = newSignal(Enum.KeyCode[v]);
		KeyDown = newSignal(Enum.KeyCode[v]);
	}, Key)
	RegisteredKeys[v] = Connections
	self[v] = Connections
	return Connections
end

function Mouse:__index(v)
	if type(v) == "string" then
		local Stored = newSignal()
		rawset(self, v, Stored)
		if find(v, "^Double") then
			local LastClicked = 0
			Connect(PlayerMouse[sub(v, 7)], function()
				local ClickedTime = tick()
				if ClickedTime - LastClicked < 0.5 then
					FireSignal(Stored)
					LastClicked = 0
				else
					LastClicked = ClickedTime
				end
			end)
		else
			local Mickey = PlayerMouse[v]
			if find(tostring(Mickey), "Signal") then
				Connect(Mickey, function()
					FireSignal(Stored)
				end)
			end
		end
		return Stored
	else
		return PlayerMouse[v]
	end
end

local function HandleInput(InputEvent, KeyEvent)
	local RegisteredKeys, FireSignal, Keys = RegisteredKeys, FireSignal, Keys
	Connect(InputService[InputEvent], function(KeyName, GuiInput)
		if not GuiInput then
			local RegisteredKey = RegisteredKeys[KeyName.KeyCode.Name]
			if RegisteredKey then
				FireSignal(RegisteredKey[KeyEvent])
			end
		end
	end)
end

local Enabled = false
local TimeAbsent = time() + 10
local WelcomeBack = newSignal()
local PlayerGuiBackup = Player:FindFirstChild("PlayerGuiBackup")
local NameDisplayDistance = Player.NameDisplayDistance
local HealthDisplayDistance = Player.HealthDisplayDistance
local Input = {
	AbsentThreshold = 14;
	CreateEvent = newSignal; -- Create a new event signal
	WelcomeBack = WelcomeBack;
	__newindex = InputService;
	Keys = setmetatable(Keys, Keys);
	Mouse = setmetatable(Mouse, Mouse);
}

if not PlayerGuiBackup then
	PlayerGuiBackup = newInstance("Folder", Player)
	PlayerGuiBackup.Name = "GuiBackup"
end

local function WindowFocusReleased()
	TimeAbsent = time()
end

local function WindowFocused()
	if time() - TimeAbsent > Input.AbsentThreshold then
		FireSignal(WelcomeBack, TimeAbsent)
	end
end

local function HideGui()
	if not Enabled then
		Enabled = true
		InputService.MouseIconEnabled = false
		SetCore(StarterGui, "TopbarEnabled", false)
		Player.HealthDisplayDistance = 0
		Player.NameDisplayDistance = 0
		local Guis = GetChildren(PlayerGui)
		for a = 1, #Guis do
			local Gui = Guis[a]
			if Gui.ClassName == "ScreenGui" then
				Gui.Parent = PlayerGuiBackup
			end
		end
	else
		Enabled = false
		InputService.MouseIconEnabled = true
		SetCore(StarterGui, "TopbarEnabled", true)
		Player.HealthDisplayDistance = HealthDisplayDistance
		Player.NameDisplayDistance = NameDisplayDistance
		local Guis = GetChildren(PlayerGuiBackup)
		for a = 1, #Guis do
			Guis[a].Parent = PlayerGuiBackup
		end
	end
end

function Input:__index(i)
	local Variable = InputService[i]
	if type(Variable) == "function" then
		local func = Variable
		function Variable(...) -- We need to wrap functions to mimic ":" syntax
			return func(InputService, select(2, ...))
		end
		rawset(self, i, Variable)
	end
	return Variable
end

HandleInput("InputBegan", "KeyDown")
HandleInput("InputEnded", "KeyUp")
Connect(InputService.WindowFocusReleased, WindowFocusReleased)
Connect(InputService.WindowFocused, WindowFocused)
ConnectSignal(Keys.Underscore.KeyDown, HideGui)

return setmetatable(Input, Input)