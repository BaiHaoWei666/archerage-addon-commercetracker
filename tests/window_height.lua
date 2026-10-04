-- 使用真正的路線查詢、結果事件與主視窗邏輯；只替代遊戲 API 和繪圖元件。
local function Noop() end
local events, widgets = {}, {}
local requestSucceeds = true
local materialPrice = 100
local materialSearches = {}
local icons, lines = {}, {}
local Widget = {}
Widget.__index = Widget

for _, method in ipairs({
    "SetCloseOnEscape", "EnableDrag", "Enable", "Clickable",
    "SetStartAnimation", "StartMoving", "StopMovingOrSizing",
    "SetNormalBackground", "SetHighlightBackground", "SetPushedBackground", "SetDisabledBackground",
}) do
    Widget[method] = Noop
end
function Widget:AddAnchor(point, target, relativePoint, x, y)
    if type(relativePoint) ~= "string" then
        relativePoint, x, y = point, relativePoint, x
    end
    self.anchor = { point = point, target = target, relativePoint = relativePoint, x = x, y = y }
end
function Widget:RemoveAllAnchors() self.anchor = nil end
function Widget:SetExtent(width, height) self.width, self.height = width, height end
function Widget:SetHeight(height) self.height = height end
function Widget:SetAutoResize(enabled) self.autoResize = enabled end
function Widget:Raise() self.raised = true end
function Widget:GetWidth() return self.width or 0 end
local function HorizontalAnchor(point)
    if string.find(point, "LEFT", 1, true) then return 0 end
    if string.find(point, "RIGHT", 1, true) then return 1 end
    return 0.5
end
function Widget:GetLeft()
    if self.anchor == nil then return 0 end
    local target = self.anchor.target
    local left = type(target) == "table" and target:GetLeft() or 0
    local width = type(target) == "table" and target:GetWidth() or 0
    return left + width * HorizontalAnchor(self.anchor.relativePoint) + self.anchor.x
        - self:GetWidth() * HorizontalAnchor(self.anchor.point)
end
function Widget:SetHandler(event, handler) self.handlers[event] = handler end
function Widget:EnablePick(enabled) self.pickEnabled = enabled end
function Widget:IsVisible()
    return self.visible and (self.parent == nil or self.parent:IsVisible())
end
function Widget:IsMouseOver() return self.mouseOver == true end
function Widget:SetVisible(visible) self.visible = visible end
-- 繪製寬度刻意與字型估算不同，避免測試只重複驗證同一個估算公式。
function Widget:SetText(text)
    self.text = text
    if self.kind == "label" then
        self.renderedTextWidth = #text * (self.style.fontSize or 12) + 8
        if self.autoResize ~= false then self.width = self.renderedTextWidth end
    end
end
function Widget:SetOptions(options) self.options = options end
function Widget:Select(value) self.value = value end
function Widget:Show(visible)
    local wasVisible = self.visible
    self.visible = visible
    if visible and not wasVisible and self.handlers.OnShow then
        self.handlers.OnShow(self)
    elseif not visible and wasVisible and self.handlers.OnHide then
        self.handlers.OnHide(self)
    end
end
local function NewWidget(id)
    local style = { SetColor = Noop, SetOutline = Noop, SetAlign = Noop }
    function style:SetFontSize(size) self.fontSize = size end
    function style:GetTextWidth(text) return #text * (self.fontSize or 12) end
    local widget = setmetatable({ visible = false, handlers = {}, style = style }, Widget)
    if type(id) == "string" then widgets[id] = widget end
    return widget
end
function Widget:CreateChildWidget(kind, id)
    local widget = NewWidget(id)
    widget.kind = kind
    widget.parent = self
    return widget
end
function Widget:CreateDrawable() return NewWidget() end
function Widget:CreateColorDrawable()
    local drawable = NewWidget()
    drawable.parent = self
    return drawable
end

CreateEmptyWindow, SettingWindowSkin = NewWidget, Noop
ALIGN_CENTER, ALIGN_RIGHT = 1, 2
ADDON = { ImportAPI = Noop, ImportObject = Noop }
OBJECT_TYPE = {}
API_TYPE = { STORE = { id = 1 }, CRAFT = { id = 2 }, ABILITY = { id = 3 }, LOCALE = { id = 4 } }
UIEVENT_TYPE = { SPECIALTY_RATIO_BETWEEN_INFO = "ratio" }
UIParent = { SetEventHandler = function(_, event, handler) events[event] = handler end }
X2Locale = { GetLocale = function() return "zh_cn" end }
X2Store = { GetSpecialtyRatioBetween = function() return requestSucceeds end }
X2Ability = { GetAllMyActabilityInfos = function() return {} end }
local materialCounts = { [6215] = 3, [6238] = 2, [9610] = 2, [7784] = 4, [11035] = 4 }
X2Craft = {
    GetCraftMaterialInfo = function(_, craft)
        local materials = {}
        for index = 1, assert(materialCounts[craft]) do
            materials[index] = { item_info = { name = "材料" .. index }, amount = 1 }
        end
        return materials
    end,
}
CT = {
    ADDON_PATH = "Addon/commercetracker/",
    Chat = Noop, UI = {}, Favorites = { Show = Noop },
    Auction = {
        Cancel = Noop, PriceOf = function() return materialPrice end,
        IsRunning = function() return false end,
        SearchMaterial = function(material) materialSearches[#materialSearches + 1] = material end,
    },
}
dofile("windows/widgets.lua")
for _, name in ipairs({
    "CreateCaption", "CreateTextButton", "CreateResetButton",
    "CreateCurrency", "CreateIcon", "CreateLine",
}) do
    CT.UI[name] = function(_, id) return NewWidget(id) end
end
CT.UI.CreateIcon = function()
    local icon = NewWidget()
    icons[#icons + 1] = icon
    return icon
end
CT.UI.CreateLine = function()
    local line = NewWidget()
    lines[#lines + 1] = line
    return line
end
CT.UI.CreateComboBox = function(_, id)
    local widget = NewWidget(id)
    widget.trigger = NewWidget()
    return widget
end
CT.UI.SetCurrencyColor, CT.UI.SetIconTexture = Noop, Noop
CT.UI.HideCurrency = function(currency) currency.visible = false end
CT.UI.ShowCurrency = function(_, currency, x, y, amount)
    currency.visible = amount ~= 0
    currency.amount = amount
    currency.y = y
end
dofile("locale.lua")
dofile("data/zones.lua")
dofile("data/specialties.lua")
dofile("data/prices.lua")
dofile("trade.lua")
dofile("windows/main_window.lua")

local window = CT.MainWindow.window
local function CheckHeight(expected, reason)
    assert(window.width == 800)
    assert(window.height == expected,
        string.format("%s：預期高度 %d，實際 %d", reason, expected, window.height))
end
local function Entry(name, ratio)
    return { itemInfo = { name = name }, ratio = ratio or 124 }
end
local routeResult = {
    Entry("Mahadevi Fine Gilda Specialty"), Entry("Mahadevi Fine Specialty"),
    Entry("Mahadevi Fine Local Specialty"), Entry("Mahadevi Fine Fertilizer Specialty"),
    Entry("Mahadevi Pack"), Entry("Mahadevi Fine Aged Honey"),
    Entry("Mahadevi Fine Aged Cheese"), Entry("Mahadevi Fine Aged Salve"),
}
local function CheckPackVisibility(index, returnsVisible)
    local prefix = "ctPack" .. index
    local pack = CT.Trade.packs[index]
    assert(widgets[prefix .. "Name"].visible, "重新整理應保留品項名稱")
    assert(icons[index].visible, "重新整理應保留品項圖示")
    assert(lines[1].visible and lines[index + 1].visible, "重新整理應保留分隔線")
    assert(widgets[prefix .. "Ratio"].visible == returnsVisible, "百分比顯示狀態錯誤")
    assert(widgets[prefix .. "Sale"].visible == returnsVisible, "預測報酬金顯示狀態錯誤")
    if pack.isSpecialty then
        assert(widgets[prefix .. "Profit"].visible == returnsVisible, "收益顯示狀態錯誤")
        assert(widgets[prefix .. "PackCost"].visible, "重新整理應保留總成本")
        for materialIndex in ipairs(pack.materials) do
            local id = prefix .. "Mat" .. materialIndex
            assert(widgets[id].visible and widgets[id .. "Cost"].visible,
                "重新整理應保留材料與材料成本")
            local label = widgets[id]
            local textY = label.anchor.y
            if string.find(label.anchor.relativePoint, "BOTTOM", 1, true) then
                textY = textY + window.height
            elseif not string.find(label.anchor.relativePoint, "TOP", 1, true) then
                textY = textY + window.height / 2
            end
            if string.find(label.anchor.point, "TOP", 1, true) then
                textY = textY + (label.height or 0) / 2
            end
            assert(textY == widgets[id .. "Cost"].y,
                "材料文字中心應與材料成本同列，不因點擊高度向下偏移")
        end
    end
end
local function RefreshRoute()
    local previousPacks = CT.Trade.packs
    CT.Trade.Tick(6000)
    widgets.ctRefresh.handlers.OnClick()
    assert(CT.Trade.packs == previousPacks, "重新整理應保留既有清單")
    for index in ipairs(previousPacks) do
        CheckPackVisibility(index, not requestSucceeds)
    end
end

CheckHeight(575, "建立視窗")
CT.MainWindow.Toggle()
CheckHeight(575, "首次開啟空視窗")
widgets.ctContinentCombo.onSelect("Haranya")
widgets.ctFromCombo.onSelect(9)
CheckHeight(575, "尚未選齊路線")
widgets.ctToCombo.onSelect(4)
CheckHeight(575, "首次查詢等待結果")
events.ratio(routeResult)
CheckHeight(725, "依八個品項與材料展開")
assert(widgets.ctPack1Name.visible and widgets.ctPack1Mat1.visible)
CheckPackVisibility(1, true)
CheckPackVisibility(6, true)
CT.MainWindow.Toggle()
CT.MainWindow.Toggle()
CheckHeight(725, "重新開啟已有資料的視窗")

RefreshRoute()
CheckHeight(725, "重新查詢保留目前高度")
-- 冷卻結束、額外重畫或關閉再開啟，都不能提早顯示尚待更新的數值。
CT.Trade.Tick(6000)
materialPrice = 200
CT.MainWindow.Refresh()
CheckPackVisibility(1, false)
assert(widgets.ctPack1Mat1Cost.amount == 200 and widgets.ctPack1PackCost.amount == 600)
CT.MainWindow.Toggle()
CT.MainWindow.Toggle()
CheckHeight(725, "等待期間重新開啟")
CheckPackVisibility(1, false)
CheckPackVisibility(6, false)
events.ratio({ Entry("Mahadevi Fine Gilda Specialty", 127) })
CheckHeight(225, "收到較少品項仍應縮至內容高度")
CheckPackVisibility(1, true)
assert(widgets.ctPack1Ratio.text == "127%")
assert(widgets.ctPack1Sale.amount == CT.Trade.SalePrice(CT.Trade.packs[1]))
assert(widgets.ctPack1Profit.amount == widgets.ctPack1Sale.amount - 600)
assert(not widgets.ctPack2Name.visible, "縮短清單後應隱藏多餘品項")

-- 查詢失敗時恢復原有數值，不讓三個欄位一直維持隱藏。
RefreshRoute()
events.ratio(nil)
CheckPackVisibility(1, true)
assert(widgets.ctPack1Ratio.text == "127%")
requestSucceeds = false
RefreshRoute()
CheckPackVisibility(1, true)
requestSucceeds = true

RefreshRoute()
events.ratio({})
CheckHeight(225, "空結果保留目前高度")
RefreshRoute()
events.ratio(nil)
CheckHeight(225, "無效結果保留目前高度")
requestSucceeds = false
RefreshRoute()
CheckHeight(225, "查詢未送出仍保留目前高度")
requestSucceeds = true
RefreshRoute()
events.ratio(routeResult)
CheckHeight(725, "查詢恢復後重新展開")

-- 換交貨區域屬於另一條路線，等待時必須隱藏舊品項與材料。
CT.Trade.Tick(6000)
widgets.ctToCombo.onSelect(12)
assert(#CT.Trade.packs == 0)
assert(not widgets.ctPack1Name.visible and not widgets.ctPack1Mat1.visible)
assert(not icons[1].visible and not lines[2].visible)
CheckHeight(725, "切換交貨區域保留高度")
events.ratio(routeResult)

-- 收藏可在冷卻期間切換路線，不能讓保留的清單被當成新路線內容。
RefreshRoute()
CT.MainWindow.ApplyRoute("Haranya", 9, 17)
assert(#CT.Trade.packs == 0, "冷卻期間切換收藏也應清除舊路線")
assert(not widgets.ctPack1Name.visible and not widgets.ctPack1Mat1.visible)
events.ratio(routeResult)
assert(#CT.Trade.packs == 0, "已清除路線的延遲結果不應重新出現")
RefreshRoute()
events.ratio(routeResult)
CheckPackVisibility(1, true)

CT.Trade.Tick(6000)
widgets.ctContinentCombo.onSelect("Nuia")
CheckHeight(725, "切換大陸保留目前高度")
assert(#CT.Trade.packs == 0 and not widgets.ctPack1Name.visible)
assert(not widgets.ctPack1Mat1.visible)
CT.MainWindow.Toggle()
CT.MainWindow.ApplyRoute("Haranya", 9, 4)
CheckHeight(725, "從收藏開啟並等待查詢")
events.ratio({ Entry("Mahadevi Fine Gilda Specialty") })
CheckHeight(225, "收藏路線結果依內容調整")

print("PASS: 主視窗高度、重新整理只隱藏三個欄位、查詢失敗恢復與路線切換")

local label = widgets.ctPack1Mat1
local hitArea = widgets.ctPack1Mat1HitArea
local function Click(button, doubleClick)
    if hitArea.visible and hitArea.pickEnabled
        and (hitArea.width or 0) > 0 and (hitArea.height or 0) > 0 then
        hitArea.handlers.OnClick(hitArea, button, doubleClick)
    end
end
assert(hitArea.pickEnabled, "可交易材料應接受點擊")
Click("LeftButton", false)
Click("LeftButton", nil)
Click("RightButton", true)
Click("MiddleButton", true)
assert(#materialSearches == 0, "單擊與非左鍵雙擊不應搜尋")
Click("LeftButton", true)
assert(materialSearches[1] == CT.Trade.packs[1].materials[1],
    "材料文字必須有可點擊範圍，雙擊才能觸發搜尋")

-- 同一文字元件會在路線更新後重用，搜尋必須跟隨目前顯示的材料。
local pack = CT.Trade.packs[1]
local replacement = { name = "替换材料", itemType = 100, amount = 7 }
pack.materials = { replacement }
CT.MainWindow.Refresh()
assert(widgets.ctPack1Mat1 == label)
assert(label.text == "替换材料 x7")
Click("LeftButton", true)
assert(materialSearches[2] == replacement, "重用材料列不應搜尋舊材料")
assert(not widgets.ctPack1Mat2.visible and not widgets.ctPack1Mat2HitArea.visible and not widgets.ctPack1Mat2HitArea.pickEnabled)
widgets.ctPack1Mat2HitArea.handlers.OnClick(widgets.ctPack1Mat2HitArea, "LeftButton", true)
assert(#materialSearches == 2, "已隱藏的材料列不應保留搜尋動作")

for _, material in ipairs({
    { name = CT.Text("BLUE_SALT_BOND"), amount = 1 },
    { name = "德翡纳之星", itemType = 23633, amount = 2 },
}) do
    pack.materials = { material }
    CT.MainWindow.Refresh()
    assert(hitArea.pickEnabled, "不可交易材料仍應接收滑鼠以顯示懸停高亮")
    Click("LeftButton", true)
    assert(#materialSearches == 2, "不可交易材料不應搜尋")
end

pack.materials = { replacement }
CT.MainWindow.Refresh()
assert(hitArea.pickEnabled, "重用為可交易材料後應恢復點擊")
CT.Trade.Clear()
CT.MainWindow.Refresh()
assert(not label.visible and not hitArea.visible and not hitArea.pickEnabled)
Click("LeftButton", true)
assert(#materialSearches == 2, "清空路線後不應搜尋舊材料")
print("PASS: 材料左鍵雙擊、非賣品排除與材料列重用")

local searchButton = widgets.ctPack1Mat1Search
local secondSearchButton = widgets.ctPack1Mat2Search
local function ClickSearch(target, button, doubleClick)
    target.handlers.OnClick(target, button, doubleClick)
end

pack.materials = { replacement, { name = "第二种材料", amount = 2 } }
CT.Trade.packs = { pack }
CT.MainWindow.Refresh()
local heightWithMaterials = window.height
assert(searchButton:IsVisible() and secondSearchButton:IsVisible(),
    "所有可交易材料應立即顯示各自的放大鏡，不需移入滑鼠")
assert(searchButton ~= secondSearchButton, "不同材料必須有各自的搜尋按鈕")
assert(searchButton.height == label.height and searchButton.width > 0,
    "按鈕必須有尺寸且不跨材料列")
local rowRight = window.width - 20
assert(label.autoResize == false and not label.pickEnabled,
    "文字使用固定欄寬，滑鼠事件交給整列感應區")
assert(hitArea.anchor.x + hitArea.width == rowRight,
    "感應範圍應涵蓋整個材料列，包含金額與右側空白")
local function CheckSearchPosition(button, textLabel)
    assert(button:GetLeft() == textLabel:GetLeft() + textLabel:GetWidth() + 4,
        "放大鏡應對齊材料文字欄位右緣，保留四像素間距")
    assert(button.anchor.y == 0 and button.anchor.relativePoint == "RIGHT",
        "放大鏡應與材料文字垂直置中")
    assert(button.raised, "放大鏡必須在整列感應區上方以接收單擊")
end
CheckSearchPosition(searchButton, label)
CheckSearchPosition(secondSearchButton, widgets.ctPack1Mat2)
assert(searchButton:GetLeft() == secondSearchButton:GetLeft(),
    "不同長度材料的放大鏡應垂直對齊")
CT.MainWindow.Tick(200)
CT.MainWindow.Refresh()
assert(searchButton:IsVisible() and secondSearchButton:IsVisible(),
    "等待與重新整理不應隱藏可交易材料的放大鏡")
assert(window.height == heightWithMaterials, "常駐放大鏡不應增加行距與視窗高度")
local previousSearchX = searchButton:GetLeft()
replacement.name = "较长的测试材料"
replacement.amount = 123
CT.MainWindow.Refresh()
assert(searchButton:GetLeft() == previousSearchX, "名稱與數量變長不應移動欄位右側的放大鏡")
CheckSearchPosition(searchButton, label)
assert(hitArea.anchor.x + hitArea.width == rowRight, "文字長度不應改變整列感應寬度")
ClickSearch(searchButton, "RightButton", false)
ClickSearch(searchButton, "MiddleButton", false)
assert(#materialSearches == 2)
ClickSearch(searchButton, "LeftButton", false)
assert(#materialSearches == 3 and materialSearches[3] == replacement and searchButton:IsVisible(),
    "單擊放大鏡應搜尋該材料並維持顯示")
ClickSearch(searchButton, "LeftButton", true)
assert(#materialSearches == 3, "按鈕雙擊事件不應重複搜尋")
ClickSearch(secondSearchButton, "LeftButton", false)
assert(#materialSearches == 4 and materialSearches[4] == pack.materials[2],
    "各列放大鏡應搜尋各自的材料")

local nextMaterial = { name = "新材料", amount = 5 }
pack.materials = { nextMaterial }
CT.MainWindow.Refresh()
assert(widgets.ctPack1Mat1Search == searchButton and searchButton:IsVisible())
assert(not secondSearchButton:IsVisible(), "清單縮短時應隱藏多餘材料的放大鏡")
ClickSearch(secondSearchButton, "LeftButton", false)
assert(#materialSearches == 4, "已隱藏的放大鏡不應保留舊材料搜尋")
CheckSearchPosition(searchButton, label)
ClickSearch(searchButton, "LeftButton", false)
assert(#materialSearches == 5 and materialSearches[5] == nextMaterial,
    "重用的放大鏡應搜尋更新後的材料")
for _, material in ipairs({
    { name = CT.Text("BLUE_SALT_BOND"), amount = 1 },
    { name = "德翡纳之星", itemType = 23633, amount = 2 },
}) do
    pack.materials = { material }
    CT.MainWindow.Refresh()
    assert(not searchButton:IsVisible(), "不可交易材料不應顯示放大鏡")
    ClickSearch(searchButton, "LeftButton", false)
    assert(#materialSearches == 5)
end
pack.materials = { replacement }
CT.MainWindow.Refresh()
assert(searchButton:IsVisible())
CT.MainWindow.Toggle()
assert(not searchButton:IsVisible(), "放大鏡應隨主視窗隱藏")
CT.MainWindow.Toggle()
assert(searchButton:IsVisible(), "重新開啟視窗應立即顯示放大鏡")
CT.Trade.Clear()
CT.MainWindow.Refresh()
assert(not searchButton:IsVisible(), "清空路線應隱藏放大鏡")
ClickSearch(searchButton, "LeftButton", false)
assert(#materialSearches == 5, "清空路線後不應搜尋舊材料")
print("PASS: 放大鏡常駐顯示、材料文字欄位右側對齊、各列單擊搜尋與材料更新")
