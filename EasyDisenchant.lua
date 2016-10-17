-- ToDo: Design the interface.

local _M = {
	addonName = "EasyDisenchant",
	eventFrame = CreateFrame("FRAME"),
	eventMap = {}, -- Used for internal mapping of events.
	isTradeSkillFrameHooked = false,
};

_M.SetEventHandler = function(self, event, func)
	self.eventMap[event] = func;
	self.eventFrame:RegisterEvent(event);
end

_M.RemoveEventHandler = function(self, event)
	self.eventMap[event] = nil;
	self.eventFrame:UnregisterEvent(event);
end

_M.HookTradeSkillFrame = function(self)
	-- ToDo: Hook.
	self:RemoveEventHandler("ADDON_LOADED");
	self.isTradeSkillFrameHooked = true;
end

_M.OnLoad = function(self)
	SLASH_DISENCHANT1 = "/disenchant";
	SlashCmdList["DISENCHANT"] = _M.OnCommand;

	if not self.isTradeSkillFrameHooked and IsAddOnLoaded("Blizzard_TradeSkillUI") then
		self:HookTradeSkillFrame();
	end
end

_M.OnEvent = function(self, event, ...)
	-- Note: self is not _M in this instance, it's eventFrame.
	local handler = _M.eventMap[event];
	if handler then
		handler(_M, ...);
	end
end

_M.OnCommand = function(text, editBox)
	
end

_M.OnAddonLoaded = function(self, addonName)
	if addonName == self.addonName then
		self:OnLoad();
	elseif addonName == "Blizzard_TradeSkillUI" then
		_M:HookTradeSkillFrame();
	end
end

_M.eventFrame:SetScript("OnEvent", _M.OnEvent);
_M:SetEventHandler("ADDON_LOADED", _M.OnAddonLoaded);