--- General Values ---

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

local livesValue0 = 1072693248
local livesValue1 = 1073741824
local livesValue2 = 1074266112
--local livesValue3 = ???
local livesValue4 = 1090465504
local livesValueDefault = livesValue2
local energyValueDefault = 1078722560


--- Memory Address Variables ---

local addressList = getAddressList()

-- player lives value
-- NOTE: SF X MM appears to use multiple pointers for lives attribute
--		 or I haven't found the base pointer yet
--local lives = addressList.getMemoryRecordByDescription("Lives")
local lives = {}

-- fill in lives table
local idx = 0
while (idx < addressList.Count) do
	local rec = addressList.getMemoryRecord(idx)
	if string.sub(rec.Description, 1, 5) == "Lives" then
		table.insert(lives, rec)
	end
	idx = idx + 1
end

-- player energy value
local energy = addressList.getMemoryRecordByDescription("Energy")


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
local function lockLives(locked)
	-- default is to lock
	if locked == nil then
	   locked = true
	end

	for _, rec in pairs(lives) do
		rec.Active = locked
	end

	if locked then
		log.write("\"Lives\" locked")
	else
		log.write("\"Lives\" unlocked")
	end
end

-- restores life or weapon energy
local function restoreEnergy(record)
	-- default is life
	if record == nil then
		record = energy
	end

	record.Value = tostring(energyValueDefault)

	log.write("\"" .. record.Description .. "\" restored to default value (" .. record.Value .. ")")
end

-- 1-hit death
local function killOnCollision()
	if energy.Value ~= tostring(energyValueDefault) and energy.Value ~= "0" then
		energy.Value = "0"
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
		if energy ~= nil and energy.Value ~= "??" then
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
	--[[
    local function center(control)
	    local pWidth = control.Parent.getWidth()
		local pHeight = control.Parent.getHeight()
		local x = (pWidth / 2) - (control.getWidth())
		
		-- TEMP:
		y = 0
		
		control.setPosition(x, y)
	end
	]]
	
	local aboutDialog = createForm(false)
	aboutDialog.setCaption("About")
	aboutDialog.setSize(400, 480)
	aboutDialog.Alignment = taCenter
	aboutDialog.Layout = tlCenter
	aboutDialog.BorderStyle = bsDialog
	
	-- background panel
	local panel = createPanel(aboutDialog)
	panel.Align = alClient
	panel.Alignment = taCenter
	panel.Layout = tlCenter
	
	-- description text
	local descr = createLabel(panel)
	descr.setCaption("CE Trainer for Street Fighter X Mega Man v2.0")
	descr.Align = alClient
	descr.Layout = tlCenter
	descr.Alignment = taCenter
	descr.AutoSize = false
	
	aboutDialog.showModal()

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
	restoreEnergy(energy)
end

Frame.Lives.onChange = function()
	lockLives(Frame.Lives.Checked)
end

Frame.Energy.onChange = function()
	lockRecord(energy, Frame.Energy.Checked)
end

Frame.InstantDeath.onChange = function()
	enableInstantDeath(Frame.InstantDeath.Checked)
end

--- GUI Startup ---

-- set check box states
if lives.Active then
   Frame.Lives.State = 1
end
if energy.Active then
	Frame.Energy.State = 1
end
if instantDeath then
	Frame.InstantDeath.State = 1
end

-- make sure log window text is empty
LogWindow.Text.clear()

Frame.show()
