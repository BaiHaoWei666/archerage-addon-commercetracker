-- 透過路線事件與拍賣事件驗證完整資料流程，遊戲 API 以固定資料替代。
local regions = {
    { from = 9, to = 4, craft = 11035, name = "Mahadevi Pack", zh = "蓝盐商会运输品广目天" },
    { from = 25, to = 4, craft = 11036, name = "Silent Forest Pack" },
    { from = 11, to = 4, craft = 11037, name = "Falcorth Pack" },
    { from = 6, to = 5, craft = 11038, name = "Lilyut Pack" },
    { from = 1, to = 5, craft = 11039, name = "Gweonid Pack" },
    { from = 2, to = 5, craft = 11040, name = "Marianople Pack" },
    { from = 18, to = 5, craft = 11041, name = "White Arden Pack" },
    { from = 17, to = 4, craft = 11042, name = "Ynystere Pack", zh = "蓝盐商会运输品伊尼斯泰尔" },
    { from = 20, to = 5, craft = 11043, name = "Cinderstone Pack" },
    { from = 15, to = 4, craft = 11044, name = "Perinoor Pack" },
}

local function Run(locale)
    local events, searches = {}, {}
    local craftResult, craftFails, materialReads = nil, false, {}
    local auctionResult
    local expected = locale == "zh_cn"
        and { "蓝盐商会债券证书", "细须柔顺剂", "胚芽皮革油", "双花翻新剂" }
        or { "Blue Salt Brotherhood Bond", "Small Root Pigment", "Small Seed Oil", "Opaque Polish" }
    ADDON = { ImportAPI = function() end }
    API_TYPE = {
        STORE = { id = 1 }, CRAFT = { id = 2 }, ABILITY = { id = 3 },
        LOCALE = { id = 4 }, AUCTION = { id = 5 },
    }
    UIEVENT_TYPE = { SPECIALTY_RATIO_BETWEEN_INFO = "ratio", AUCTION_ITEM_SEARCHED = "auction" }
    UIParent = { SetEventHandler = function(_, event, handler) events[event] = handler end }
    X2Locale = { GetLocale = function() return locale end }
    X2Store = { GetSpecialtyRatioBetween = function() return true end }
    X2Ability = { GetAllMyActabilityInfos = function() return {} end }
    X2Craft = {
        GetCraftTypeByItemType = function()
            if craftFails then error("模擬配方查詢失敗") end
            return craftResult
        end,
        GetCraftMaterialInfo = function(_, craft)
            materialReads[craft] = (materialReads[craft] or 0) + 1
            if craft ~= 6214 then
                assert(craft >= 11035 and craft <= 11044)
                -- 刻意讓一個地區數量不同，確認材料取自各自配方，未套用共同清單。
                return {
                    { item_info = { name = expected[1], itemType = 999997 }, amount = 1 },
                    { item_info = { name = expected[2], itemType = 19448 }, amount = 1 },
                    { item_info = { name = expected[3], itemType = 19449 }, amount = 1 },
                    { item_info = { name = expected[4], itemType = 19450 }, amount = craft == 11037 and 2 or 1 },
                }
            end
            return {
                { item_info = { name = "切碎的蔬菜", itemType = 100 }, amount = 300 },
                { item_info = { name = "德翡纳之星", itemType = 23633 }, amount = 2 },
            }
        end,
    }
    X2Auction = {
        SearchAuctionArticle = function(_, page, minLevel, maxLevel, grade, category, exact, name)
            searches[#searches + 1] = name
        end,
        GetSearchedItemCount = function() return 1 end,
        GetSearchedItemInfo = function() return auctionResult end,
    }
    CT = {
        Chat = function() end,
        MainWindow = { Refresh = function() end, OnAuctionStateChanged = function() end },
    }
    dofile("locale.lua")
    dofile("data/zones.lua")
    dofile("data/specialties.lua")
    dofile("data/prices.lua")
    dofile("trade.lua")
    dofile("auction.lua")

    local function Receive(from, to, name, itemType)
        CT.Trade.Tick(6000)
        CT.Trade.route.from, CT.Trade.route.to = from, to
        assert(CT.Trade.Request())
        events.ratio({ { itemInfo = { name = name, itemType = itemType }, ratio = 124 } })
        return CT.Trade.packs[1]
    end

    local function CheckMaterials(pack)
        assert(pack.isSpecialty, "債券貨必須顯示材料、成本與利潤")
        assert(#pack.materials == 4)
        for index, material in ipairs(pack.materials) do
            assert(material.name == expected[index])
            local amount = index == 4 and pack.craftType == 11037 and 2 or 1
            assert(material.amount == amount)
            assert(not not CT.Trade.CanQueryMaterial(material) == (index > 1))
        end
        assert(pack.materials[2].itemType == 19448)
        assert(pack.materials[3].itemType == 19449)
        assert(pack.materials[4].itemType == 19450)
    end

    local packs = {}
    for _, region in ipairs(regions) do
        -- 有配方編號時以編號辨識，不要求物品名稱剛好符合翻譯表。
        craftResult, craftFails = tostring(region.craft), false
        local pack = Receive(region.from, region.to, "API 配方辨識", 999999)
        assert(pack.canonicalName == region.name)
        assert(pack.craftType == region.craft)
        CheckMaterials(pack)

        -- 缺少物品編號或配方 API 拋錯時，兩種語系仍能透過包名與地區辨識。
        craftResult, craftFails = nil, true
        local name = locale == "zh_cn" and (region.zh or "蓝盐商会运输品") or region.name
        for _, itemType in ipairs({ false, 999999 }) do
            pack = Receive(region.from, region.to, name, itemType or nil)
            assert(pack.canonicalName == region.name)
            assert(pack.craftType == region.craft)
            assert(pack.basePrice == CT.BASE_PRICES[region.to][region.name])
            assert(pack.freshness == 1)
            assert(CT.Trade.SalePrice(pack) == math.floor(pack.basePrice * 124))
            CheckMaterials(pack)
        end
        packs[#packs + 1] = pack
    end
    for _, region in ipairs(regions) do
        assert(materialReads[region.craft] == 1, "各地區應獨立讀取與快取配方材料")
    end
    assert(packs[1].materials ~= packs[2].materials)
    assert(packs[1].materials[1] ~= packs[2].materials[1])

    -- 合併多個地區的債券貨，三種共同材料各查一次，債券完全不送出查價。
    CT.Auction.StartForPacks(packs)
    for index = 1, 3 do
        assert(searches[index] == expected[index + 1])
        auctionResult = { name = searches[index], bidPrice = index * 10000 }
        events.auction()
        CT.Auction.Tick(1200)
    end
    assert(#searches == 3)
    assert(not CT.Auction.IsRunning())
    for _, pack in ipairs(packs) do
        local cost = 0
        for _, material in ipairs(pack.materials) do
            cost = cost + material.amount * CT.Auction.PriceOf(material)
        end
        assert(CT.Auction.PriceOf(pack.materials[1]) == 0)
        local expectedCost = pack.craftType == 11037 and 90000 or 60000
        assert(cost == expectedCost, "每個地區都應使用各自的配方數量計算成本")
    end

    -- 一般特產仍即時讀取材料；發酵品與未知包不應誤套用債券貨材料。
    craftResult, craftFails = 6214, false
    local regular = Receive(7, 4, "一般特產 API 辨識", 999998)
    assert(regular.canonicalName == "Arcum Iris Commercial Gilda Specialty")
    assert(regular.isSpecialty and #regular.materials == 2)
    assert(regular.materials[1].amount == 300)
    assert(CT.Trade.CanQueryMaterial(regular.materials[1]))
    assert(not CT.Trade.CanQueryMaterial(regular.materials[2]))
    assert(materialReads[6214] == 1)

    craftResult = nil
    local agedName = locale == "zh_cn" and "伊尼斯泰尔基本发酵蜂蜜" or "Ynystere Commercial Aged Honey"
    local aged = Receive(17, 4, agedName)
    assert(not aged.isSpecialty and #aged.materials == 0)
    local unknown = Receive(17, 4, "Unknown Pack")
    assert(not unknown.isSpecialty and #unknown.materials == 0)

    print("PASS: " .. locale .. " 債券貨 10 地區配方、獨立材料與拍賣流程")
end

Run("zh_cn")
Run("en_us")
