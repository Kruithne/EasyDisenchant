-- [[ Globals ]] --
local PlaySound = PlaySound;
local HideUIPanel = HideUIPanel;

local _K = Krutilities;
local _M = {
	addonName = "EasyDisenchant",
	eventFrame = CreateFrame("FRAME"),
	eventMap = {}, -- Used for internal mapping of events.
	isTradeSkillFrameHooked = false,
	tradeSkillID = 333, -- CHARACTER_PROFESSION_ENCHANTING
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
	self:SetEventHandler("TRADE_SKILL_DATA_SOURCE_CHANGED", _M.CheckTradeSkillButton);
	self.isTradeSkillFrameHooked = true;
end

_M.CreateTradeSkillButton = function(self)
	self.tradeSkillButton = _K:Frame({
		name = "EasyDisenchantTradeSkillButton",
		parent = TradeSkillFrame,
		enableMouse = true,
		size = {256, 78},
		points = {
			point = "TOPRIGHT",
			relativePoint = "BOTTOMRIGHT",
		},
		textures = {
			{
				texture = [[Interface\Transmogrify\TransmogToast]],
				texCoord = {0, 1, 0, 0.609375}
			},
			{
				texture = [[Interface\ICONS\INV_Enchant_Disenchant]],
				subLevel = -1,
				size = 45,
				points = {
					point = "LEFT", x = 15,
				}
			}
		},
		texts = {
			text = "EasyDisenchant",
			inherit = "GameFontHighlight",
			points = {
				point = "LEFT", x = 72
			}
		},
		scripts = {
			OnMouseUp = self.InvokeWindowOpen
		}
	});
end

_M.CheckTradeSkillButton = function(self)
	if C_TradeSkillUI.GetTradeSkillLine() == self.tradeSkillID then
		if not self.tradeSkillButton then
			self:CreateTradeSkillButton();
		end

		self.tradeSkillButton:Show();
	else
		if self.tradeSkillButton then
			self.tradeSkillButton:Hide();
		end
	end
end

_M.CreateDisenchantFrame = function(self)
	local bgAnchor = {
		{ point = "TOPLEFT", x = 8, y = -8 },
		{ point = "BOTTOMRIGHT", x = -8, y = 8 }
	};

	local cornerMixin = {
		layer = "BACKGROUND",
		size = 64,
		subLevel = -2,
		texture = [[Interface\Transmogrify\Textures]]
	};

	local edgeXMixin = {
		tileX = true,
		subLevel = -3,
		size = {64, 23},
		layer = "BACKGROUND",
		texture = [[Interface\Transmogrify\HorizontalTiles]]
	};

	local edgeYMixin = {
		tileY = true,
		subLevel = -3,
		size = {23, 64},
		layer = "BACKGROUND",
		texture = [[Interface\Transmogrify\VerticalTiles]]
	};

	self.disenchantFrame = _K:Frame({
		name = "EasyDisenchantFrame",
		size = {418, 236},
		frames = {
			{ -- Close Button
				type = "BUTTON",
				parentName = "CloseButton",
				inherit = "UIPanelCloseButton",
				points = { point = "TOPRIGHT", x = -20, y = -25 }
			}
		},
		textures = {
			{ -- Background.
				layer = "BACKGROUND",
				subLevel = -6,
				texture = [[Interface\FrameGeneral\UI-Background-Marble]],
				tile = true,
				points = bgAnchor,
				color = {0.302, 0.102, 0.204, 0.8}
			},
			{ -- Corner: Top Left
				parentName = "CornerTL",
				mixin = cornerMixin,
				points = "TOPLEFT",
				texCoord = {0.00781250, 0.50781250, 0.00195313, 0.12695313}
			},
			{ -- Corner: Top Right
				parentName = "CornerTR",
				mixin = cornerMixin,
				points = "TOPRIGHT", 
				texCoord = {0.00781250, 0.50781250, 0.38476563, 0.50781250}
			},
			{ -- Corner: Bottom Left
				parentName = "CornerBL",
				mixin = cornerMixin,
				points = "BOTTOMLEFT",
				texCoord = {0.0078125, 0.5078125, 0.2578125, 0.38085938}
			},
			{ -- Corner: Bottom Right
				parentName = "CornerBR",
				mixin = cornerMixin,
				points = "BOTTOMRIGHT",
				texCoord = {0.0078125, 0.5078125, 0.13085938, 0.25390625}
			},
			{ -- Edge: Top
				parentName = "TopEdge",
				mixin = edgeXMixin,
				points = {
					{ point = "TOPLEFT", relativeTo = "$parentCornerTL", relativePoint = "TOPRIGHT", x = -30, y = -5 },
					{ point = "TOPRIGHT", relativeTo = "$parentCornerTR", relativePoint = "TOPLEFT", x = 30, y = -5 }
				},
				texCoord = {0, 1, 0.40625, 0.765625}
			},
			{ -- Edge: Bottom
				parentName = "BottomEdge",
				mixin = edgeXMixin,
				points = {
					{ point = "BOTTOMLEFT", relativeTo = "$parentCornerBL", relativePoint = "BOTTOMRIGHT", x = -30, y = 4 },
					{ point = "BOTTOMRIGHT", relativeTo = "$parentCornerBR", relativePoint = "BOTTOMLEFT", x = 30, y = 4 }
				},
				texCoord = {0, 1, 0.015625, 0.375}
			},
			{ -- Edge: Left
				parentName = "LeftEdge",
				mixin = edgeYMixin,
				points = {
					{ point = "TOPLEFT", relativeTo = "$parentCornerTL", relativePoint = "BOTTOMLEFT", x = 4, y = 16 },
					{ point = "BOTTOMLEFT", relativeTo = "$parentCornerBL", relativePoint = "TOPLEFT", x = 4, y = -16 }
				},
				texCoord = {0.40625, 0.765625, 0, 1}
			},
			{ -- Edge: Right
				parentName = "RightEdge",
				mixin = edgeYMixin,
				points = {
					{ point = "TOPRIGHT", relativeTo = "$parentCornerTR", relativePoint = "BOTTOMRIGHT", x = -4, y = 16 },
					{ point = "BOTTOMRIGHT", relativeTo = "$parentCornerBR", relativePoint = "TOPRIGHT", x = -4, y = -16 }
				},
				texCoord = {0.015625, 0.375, 0, 1}
			}
		}
	});
end

_M.OpenWindow = function(self)
	HideUIPanel(TradeSkillFrame);

	if not self.disenchantFrame then
		self:CreateDisenchantFrame();
	end

	self.disenchantFrame:Show();
	PlaySound("UI_EtherealWindow_Open");
end

_M.OnLoad = function(self)
	-- Register command.
	SLASH_DISENCHANT1 = "/disenchant";
	SlashCmdList["DISENCHANT"] = self.InvokeWindowOpen;

	-- Hook to TradeSkillFrame.
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

_M.InvokeWindowOpen = function()
	_M:OpenWindow();
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