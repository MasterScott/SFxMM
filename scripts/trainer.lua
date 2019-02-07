--- General Values ---

-- trainer version
local ver = {}
ver.maj = 0
ver.min = 1
ver.rel = 0
ver.beta = 1
ver.full = string.format("%i.%i.%i", ver.maj, ver.min, ver.rel)
if ver.beta > 0 then
	ver.full = string.format("%s-beta%i", ver.full, ver.beta)
end

-- executable/process to be loaded
local processName = "SFXMMv2_US.exe"

-- instant death
if instantDeath == nil then
	local instantDeath = false
end

-- run as standalone executable
local standalone = TrainerOrigin ~= nil

-- debugging
local log = {}
log.lines = {}


--- Default Values ---

local energyValue1 = 1073741824
local energyValue28 = 1078722560
--local energyValueFull = energyValue28
local energyValueFull = 56

local livesValue0 = 1072693248
local livesValue1 = 1073741824
local livesValue2 = 1074266112
local livesValue3 = 1074790400
local livesValue4 = 1075052544
local livesValue5 = 1075314688
local livesValue6 = 1075576832
local livesValue7 = 1075838976
local livesValue8 = 1075970048
local livesValue9 = 1076101120
local livesValue10 = 1076232192
--local livesValue11 = ???
local livesValue55 = energyValueFull
local livesValueDefault = livesValue2

local etankValue0 = 0
local etankValue1 = livesValue0


--- Memory Address Variables ---

local addressList = getAddressList()

-- player lives value
-- NOTE: SF X MM appears to use multiple pointers for lives attribute
--		 or I haven't found the base pointer yet
--local lives = addressList.getMemoryRecordByDescription("Lives")
--local lives = {}

-- fill in lives table
--[[
local idx = 0
while (idx < addressList.Count) do
	local rec = addressList.getMemoryRecord(idx)
	--if string.sub(rec.Description, 1, 5) == "Lives" then
	if string.sub(rec.Description, 1, 9) == "Lives PTR" then
		table.insert(lives, rec)
	end
	idx = idx + 1
end
]]

-- player energy value
local recEnergy = addressList.getMemoryRecordByDescription("Energy")
local recLives = addressList.getMemoryRecordByDescription("Lives")


--- Timer Used for Instant Death ---

local activeTimers = 0
local timer = createTimer(nil, false)


--- Local Functions ---

local function getTimestamp()
	local a, ms = math.modf(os.clock())
	if ms == 0 then
		ms = "000"
	else
		ms = tostring(ms):sub(3, 5)
	end
	return string.format("%s.%s", os.date("%H:%M:%S"), ms)
end

local function updateLogWindow(msg)
	if msg == nil then
		LogWindow.Text.clear()
		for _, LINE in pairs(log.lines) do
			LogWindow.Text.append(LINE)
		end
	else
		LogWindow.Text.append(msg)
	end
end

-- append to debug log
log.write = function(msg)
	-- add timestamp
	msg = getTimestamp() .. ": " .. msg
	table.insert(log.lines, msg)
	-- update log window if visible
	if LogWindow.Visible then
		updateLogWindow(msg)
	end
end

-- clear debug log
local function clearLog()
	log.lines = {}
	if LogWindow.Visible then
		updateLogWindow()
	end
end

-- display log window
local function showLog()
	updateLogWindow()
	-- FIXME: how to make this window child
	--LogWindow.showModal()
	LogWindow.show()
	Frame.ButtonLog.setCaption("Hide Log")
end

-- hides & clears the log window
local function hideLog()
	LogWindow.Text.clear()
	LogWindow.hide()
	Frame.ButtonLog.setCaption("Show Log")
end

-- sets timer state for instant death
local function enableInstantDeath(enabled)
	-- default is enabled
	if enabled == nil then
		enabled = true
	end

	instantDeath = enabled
	-- update GUI
	if Frame.InstantDeath.Checked ~= instantDeath then
	   Frame.InstantDeath.Checked = instantDeath
	end

	-- set timer state
	timer.setEnabled(instantDeath)
end

-- detaches active process
-- FIXME: not sure how to do this
local function detachGame()
	--process = nil

	if process == nil then
		Frame.ProcessLabel.setCaption("Attached process:")
	else
		Frame.ProcessLabel.setCaption("ERROR: don't know how to detach process")
	end
end

-- attaches the process
local function attachGame()
	-- ensure process is not attached
	detachGame()

	openProcess(processName)

	if process == nil then
		local errMsg = "Process not found: \"" .. processName .. "\""
		showMessage(errMsg)
		log.write(errMsg)

		-- DEBUG:
		local PID = getOpenedProcessID()
		if PID ~= nil then
			errMsg = "ERROR: process not detached: " .. tostring(PID)
			Frame.ProcessLabel.setCaption(errMsg)
			log.write(errMsg)
		end

		return
	end

	local msg = "Attached process: " .. tostring(getOpenedProcessID())
	Frame.ProcessLabel.setCaption(msg)
	log.write(msg)

	-- start instant death timer
	if instantDeath then
		enableInstantDeath(true)
	end
end

-- locks/freezes state of a record
local function lockRecord(record, locked)
	-- record must be explicitely stated
	if record == nil then
		log.msg("WARNING: cannot lock nil record")
		return
	end

	-- default behavior is to lock
	if locked == nil then
	   locked = true
	end
	
	-- find record from string
	local recType = type(record)
	if recType == "string" then
		log.write("Identifying record by description string")
		record = addressList.getMemoryRecordByDescription(record)
	elseif recType == "number" then
		log.write("Identifying record by table index")
		record = addressList.getMemoryRecord(record)
	end

	-- set the record's locked/frozed state
	record.Active = locked

	if record.Active then
		log.write("\"" .. record.Description .. "\" locked")
	else
		log.write("\"" .. record.Description .. "\" unlocked")
	end
end

-- freezes state of all "lives" memory records
-- NOTE: this can be removed if base pointer for lives value
--		 is found
--[[
local function lockLives(locked)
	-- default is to lock
	if locked == nil then
	   locked = true
	end

	for _, rec in pairs(lives) do
		rec.Active = locked
	end
	
	--recLives.Active = locked

	if locked then
		log.write("\"Lives\" locked")
	else
		log.write("\"Lives\" unlocked")
	end
end
]]

-- restores life or weapon energy
local function restoreEnergy(record)
	-- default is life
	if record == nil then
		record = recEnergy
	end

	record.Value = tostring(energyValueFull)

	log.write("\"" .. record.Description .. "\" restored to default value (" .. record.Value .. ")")
end

-- 1-hit death
local function killOnCollision()
	if recEnergy.Value ~= tostring(energyValueFull) and recEnergy.Value ~= "0" then
		recEnergy.Value = "0"
		log.write("instant death event")
	end
end


--- Timer Functions

-- override setEnabled function
timer.setEnabledOrig = timer.setEnabled
timer.setEnabled = function(enabled)
	if enabled then
		activeTimers = activeTimers + 1
	else
		if activeTimers > 0 then
			activeTimers = activeTimers - 1
		end
	end
	timer.setEnabledOrig(enabled)
	-- FIXME: should be a hidden or debug message
	log.write("instant death timer tracking count: " .. activeTimers)
end

-- function called when timer is active
timer.OnTimer = function()
	local processID = getProcessIDFromProcessName(process)
	if processID ~= nil then
		if recEnergy ~= nil and recEnergy.Value ~= "??" then
			killOnCollision()
		end
	else
		timer.setEnabled(false)
	end
end

--- Shutdown & Cleanup ---

-- closes trainer, Cheat Engine, & disables timer
local function shutdown()
	-- ensure that timer is disabled
	timer.setEnabled(false)
	object_destroy(timer)
	-- close GUI
	hideLog()
	Frame.hide()
	-- shutdown Cheat Engine process when run as a standalone application
	if standalone then
		closeCE()
		return caFree
	end
end


--- About Dialog ---

local function showAbout()
	local W = 400
	local H = 480

	-- dialog to display information about trainer
	local aboutDialog = createForm(false)
	aboutDialog.setCaption("About")
	aboutDialog.setSize(W, H)

	-- main panel
	local panel = createPanel(aboutDialog)
	panel.Align = alClient
	panel.BorderStyle = bsNone

	-- description text
	local descr1 = createLabel(panel)
	descr1.setCaption("Trainer for")
	descr1.Top = H / 4
	local descr2 = createLabel(panel)
	descr2.setCaption("Street Fighter X Mega Man")
	for _, d in pairs({descr1, descr2}) do
		d.Font.Size = 12
		--setProperty(d, "alignment", "taCenter")
		d.anchorSideLeft.control = panel
		d.anchorSideLeft.side = asrCenter
	end
	descr2.anchorSideTop.control = descr1
	descr2.anchorSideTop.side = asrBottom
	descr2.Font.Color = 0xFF0000
	descr2.Cursor = -21 -- variable "crHandPoint" does not work
	descr2.OnClick = function(sender)
		shellExecute("http://megaman.capcom.com/sfxmm/")
		descr2.Font.Color = 0x0000FF
	end

	local author = createLabel(panel)
	author.setCaption("Created by Jordan Irwin (AntumDeluge)")
	author.anchorSideLeft.control = panel
	author.anchorSideLeft.side = asrCenter
	author.anchorSideTop.control = descr2
	author.anchorSideTop.side = asrBottom
	author.BorderSpacing.top = 20

	local version = createLabel(panel)
	version.setCaption("Version: " .. ver.full)
	version.anchorSideLeft.control = panel
	version.anchorSideLeft.side = asrCenter
	version.anchorSideTop.control = author
	version.anchorSideTop.side = asrBottom
	version.BorderSpacing.top = 20

	-- Cheat Engine info
	local ceInfo = createLabel(panel)
	ceInfo.setCaption("Made with Cheat Engine 6.8.1 by Dark Byte")
	ceInfo.anchorSideLeft.control = panel
	ceInfo.anchorSideLeft.side = asrCenter
	ceInfo.anchorSideTop.control = version
	ceInfo.anchorSideTop.side = asrBottom
	ceInfo.BorderSpacing.top = 20
	ceInfo.Font.Color = 0xFF0000
	ceInfo.Cursor = -21 -- variable "crHandPoint" does not work
	ceInfo.OnClick = function(sender)
		shellExecute("https://cheatengine.org/")
		ceInfo.Font.Color = 0x0000FF
	end

	-- show the dialog
	aboutDialog.showModal()
	-- free memory after dialog is closed
	aboutDialog.destroy()
end


--- GUI Events ---

LogWindow.OnClose = hideLog
LogWindow.ButtonClear.OnClick = clearLog

Frame.OnClose = shutdown
Frame.ButtonLoad.OnClick = attachGame
Frame.ButtonClose.OnClick = shutdown
Frame.ButtonLog.OnClick = function()
	if LogWindow.Visible then
		hideLog()
	else
		showLog()
	end
end
Frame.ButtonAbout.OnClick = showAbout
Frame.FullHealth.OnClick = function()
	restoreEnergy(recEnergy)
end
Frame.ButtonPause.OnChange = function()
	if Frame.ButtonPause.Checked then
		pause()
	else
		unpause()
	end
end

Frame.Lives.onChange = function()
	lockRecord(recLives, Frame.Lives.Checked)
end

Frame.Energy.onChange = function()
	lockRecord(recEnergy, Frame.Energy.Checked)
end

Frame.InstantDeath.onChange = function()
	enableInstantDeath(Frame.InstantDeath.Checked)
end

--- GUI Startup ---

-- set check box states
if recLives.Active then
   Frame.Lives.State = 1
end
if recEnergy.Active then
	Frame.Energy.State = 1
end
if instantDeath then
	Frame.InstantDeath.State = 1
end

-- make sure log window text is empty
LogWindow.Text.clear()

Frame.show()
