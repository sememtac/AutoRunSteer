-- AutoRunSteer
-- The gamepad "Turn Player with Camera" setting doesn't treat autorun as moving, so the camera
-- stick can't steer an autorun. Keep holding the autorun button for a moment after starting
-- autorun to switch that setting to "always" until the autorun ends; a quick tap is a plain
-- autorun. The temp value never touches the saved setting.

local ADDON_NAME = ...;

local CVAR = "GamePadTurnWithCamera";
local ALWAYS_TURN_WITH_CAMERA = "2";
local DEFAULT_HOLD_TIME = 0.5;
local MIN_HOLD_TIME, MAX_HOLD_TIME = 0.2, 2;
local RUMBLE_INTENSITY, RUMBLE_TIME = 0.5, 0.15;
-- A press that started moving this soon after an autorun hook belongs to that hook.
local HOOK_TO_MOVE_WINDOW = 0.3;

local AUTORUN_BINDINGS = { "TOGGLEAUTORUN", "STARTAUTORUN" };
local PAD_KEYS = {
	"PADLSTICK", "PADRSTICK", "PAD1", "PAD2", "PAD3", "PAD4", "PAD5", "PAD6",
	"PADDUP", "PADDRIGHT", "PADDDOWN", "PADDLEFT", "PADLSHOULDER", "PADRSHOULDER", "PADLTRIGGER", "PADRTRIGGER",
	"PADPADDLE1", "PADPADDLE2", "PADPADDLE3", "PADPADDLE4", "PADFORWARD", "PADBACK", "PADSYSTEM", "PADSOCIAL",
};

local isSteering = false;
local isOverriding = false;
local canOverride = false;

local holdKeys = nil;
local holdElapsed = 0;
local lastHookTime = -math.huge;

local function Print(text)
	print("|cff33ff99AutoRunSteer|r: " .. text);
end

local function Debug(text)
	if AutoRunSteerDB and AutoRunSteerDB.debug then
		Print("|cffaaaaaa" .. text .. "|r");
	end
end

local function IsEnabled()
	return AutoRunSteerDB == nil or AutoRunSteerDB.enabled ~= false;
end

local function GetHoldTime()
	return (AutoRunSteerDB and AutoRunSteerDB.holdTime) or DEFAULT_HOLD_TIME;
end

local function UpdateOverride()
	local shouldOverride = canOverride and isSteering and IsEnabled();
	if shouldOverride == isOverriding then
		return;
	end

	if shouldOverride then
		C_CVar.SetTempCVar(CVAR, ALWAYS_TURN_WITH_CAMERA);
	else
		C_CVar.RemoveTempCVar(CVAR);
	end
	isOverriding = shouldOverride;
end

local function SetSteering(steering)
	isSteering = steering;
	UpdateOverride();
end

-- Keys bound to autorun, from both forms of the lookup Blizzard's code uses.
local function GetAutorunKeys()
	local keys, seen = {}, {};
	for _, binding in ipairs(AUTORUN_BINDINGS) do
		for _, lookup in ipairs({ { GetBindingKey(binding) }, { GetBindingKey(binding, 1) } }) do
			for _, key in ipairs(lookup) do
				if not seen[key] then
					seen[key] = true;
					table.insert(keys, key);
				end
			end
		end
	end
	return keys;
end

local function GetKeysDown(keys)
	local down = {};
	for _, key in ipairs(keys) do
		if IsKeyDown(key) then
			table.insert(down, key);
		end
	end
	return down;
end

local function AnyKeyDown(keys)
	return #GetKeysDown(keys) > 0;
end

local function StartSteering()
	if not IsEnabled() then
		return;
	end
	SetSteering(true);
	if not isOverriding then
		return;
	end

	UIErrorsFrame:AddMessage("Autorun steering on", 0.2, 1, 0.6);
	if C_GamePad and C_GamePad.SetVibration then
		C_GamePad.SetVibration("Low", RUMBLE_INTENSITY);
		C_Timer.After(RUMBLE_TIME, function() C_GamePad.StopVibration(); end);
	end
end

-- After an autorun press, watch the button: released early is a plain toggle, still held after
-- the hold time (and actually running, not a press that stopped autorun) turns steering on.
local holdWatcher = CreateFrame("Frame");
holdWatcher:Hide();
holdWatcher:SetScript("OnUpdate", function(self, elapsed)
	holdElapsed = holdElapsed + elapsed;
	if not AnyKeyDown(holdKeys) then
		self:Hide();
		Debug(("released after %.2fs - plain autorun"):format(holdElapsed));
	elseif holdElapsed >= GetHoldTime() then
		self:Hide();
		local moving = IsPlayerMoving();
		Debug(("held %.2fs, moving=%s"):format(holdElapsed, tostring(moving)));
		if moving then
			StartSteering();
		end
	end
end);

local function WatchForHold(keys)
	holdKeys = keys;
	holdElapsed = 0;
	holdWatcher:Show();
end

local function OnAutorunHook(source)
	lastHookTime = GetTime();
	local boundKeys = GetAutorunKeys();
	local keys = GetKeysDown(boundKeys);
	local padDown = GetKeysDown(PAD_KEYS);
	if AutoRunSteerDB and AutoRunSteerDB.debug then
		-- Raw controller state, to tell "IsKeyDown can't see pad buttons" apart from "nothing held".
		local rawDown = 0;
		local state = C_GamePad and C_GamePad.GetDeviceMappedState and C_GamePad.GetDeviceMappedState(C_GamePad.GetActiveDeviceID());
		for _, down in pairs(state and state.buttons or {}) do
			if down then
				rawDown = rawDown + 1;
			end
		end
		Debug(("%s: bound=[%s] boundDown=[%s] padDown=[%s] rawButtonsDown=%d"):format(source, table.concat(boundKeys, ","),
			table.concat(keys, ","), table.concat(padDown, ","), rawDown));
	end
	-- If the bound-key lookup comes up empty, whatever pad button is held is the one that fired.
	if #keys == 0 then
		keys = padDown;
	end
	if #keys > 0 then
		WatchForHold(keys);
	end
end

-- Autorun is started/stopped through these binding functions; post-hooks keep Blizzard's call secure.
hooksecurefunc("ToggleAutoRun", function() OnAutorunHook("ToggleAutoRun"); end);
hooksecurefunc("StartAutoRun", function() OnAutorunHook("StartAutoRun"); end);
hooksecurefunc("StopAutoRun", function() Debug("StopAutoRun"); SetSteering(false); end);
-- Pressing forward or back cancels autorun.
for _, functionName in ipairs({ "MoveForwardStart", "MoveBackwardStart" }) do
	if _G[functionName] then
		hooksecurefunc(functionName, function() SetSteering(false); end);
	end
end

-- Fallback for an autorun that never went through the hooks above: movement starting while the
-- autorun button (or a left stick click) is held.
local function OnStartedMoving()
	local fromHook = (GetTime() - lastHookTime) <= HOOK_TO_MOVE_WINDOW;
	local candidates = GetAutorunKeys();
	table.insert(candidates, "PADLSTICK");
	local keys = GetKeysDown(candidates);
	Debug(("started moving: autorun hook just fired=%s, autorun/L3 held=[%s]"):format(tostring(fromHook), table.concat(keys, ",")));
	if not fromHook and not holdWatcher:IsShown() and #keys > 0 then
		WatchForHold(keys);
	end
end

local frame = CreateFrame("Frame");
frame:RegisterEvent("ADDON_LOADED");
frame:RegisterEvent("PLAYER_LOGIN");
frame:RegisterEvent("PLAYER_ENTERING_WORLD");
frame:RegisterEvent("PLAYER_STARTED_MOVING");
frame:RegisterEvent("PLAYER_STOPPED_MOVING");
frame:RegisterEvent("PLAYER_LOGOUT");
frame:SetScript("OnEvent", function(self, event, ...)
	if event == "ADDON_LOADED" then
		if ... == ADDON_NAME then
			AutoRunSteerDB = AutoRunSteerDB or { enabled = true };
		end
	elseif event == "PLAYER_LOGIN" then
		local value, _, _, _, _, isSecure = C_CVar.GetCVarInfo(CVAR);
		canOverride = value ~= nil and not isSecure and C_CVar.SetTempCVar ~= nil;
		if not canOverride then
			Print("can't override " .. CVAR .. " on this client, so autorun steering is unavailable.");
		end
	elseif event == "PLAYER_STARTED_MOVING" then
		OnStartedMoving();
	else
		-- Steering lasts until the character stops; loading screens and logout end it too.
		if event == "PLAYER_STOPPED_MOVING" and isSteering then
			Debug("stopped moving - steering off");
		end
		SetSteering(false);
	end
end);

SLASH_AUTORUNSTEER1 = "/autorunsteer";
SlashCmdList.AUTORUNSTEER = function(msg)
	msg = strtrim(msg or ""):lower();
	local holdArg = msg:match("^hold%s+([%d%.]+)$");
	if holdArg then
		local seconds = tonumber(holdArg);
		if not seconds or seconds < MIN_HOLD_TIME or seconds > MAX_HOLD_TIME then
			Print(("hold time must be between %.1f and %.1f seconds."):format(MIN_HOLD_TIME, MAX_HOLD_TIME));
			return;
		end
		AutoRunSteerDB.holdTime = seconds;
		Print(("hold the autorun button %.1f seconds to steer."):format(seconds));
	elseif msg == "debug" then
		AutoRunSteerDB.debug = not AutoRunSteerDB.debug;
		Print("debug output " .. (AutoRunSteerDB.debug and "on" or "off") .. ".");
	elseif msg == "on" or msg == "off" or msg == "" then
		if msg == "" then
			AutoRunSteerDB.enabled = not IsEnabled();
		else
			AutoRunSteerDB.enabled = (msg == "on");
		end
		UpdateOverride();
		Print(IsEnabled() and ("on - hold the autorun button %.1f seconds to steer with the camera stick."):format(GetHoldTime()) or "off.");
	else
		Print(("enabled=%s, holdTime=%.1f, steering=%s, %s=%s, autorun keys=[%s]"):format(tostring(IsEnabled()), GetHoldTime(),
			tostring(isOverriding), CVAR, tostring(C_CVar.GetCVar(CVAR)), table.concat(GetAutorunKeys(), ",")));
	end
end;
