-- ==========================================
-- Initialize variable with default values
-- When modifying clothing.lua - ensure proper integration
-- ==========================================

StarterClothingOptions = {
    male = {
        -- Size (1-5)
        shirts_full = {
            { model = 1, texture = 1, hash = 2795762245 },  -- FRONTIER_SHIRT_000
            { model = 2, texture = 1, hash = 4004347424 },  -- OUTLAW_SHIRT_000
            { model = 3, texture = 1, hash = 0 },           -- placeholder
            { model = 4, texture = 1, hash = 0 },
            { model = 5, texture = 1, hash = 0 },
        },
        
        -- Type (1-5)
        pants = {
            { model = 1, texture = 1, hash = 1094172669 },  -- FRONTIER_PANTS_000
            { model = 2, texture = 1, hash = 2807053654 },  -- OUTLAW_PANTS_000
            { model = 3, texture = 1, hash = 0 },
            { model = 4, texture = 1, hash = 0 },
            { model = 5, texture = 1, hash = 0 },
        },
        
        -- Color (1-5)
        boots = {
            { model = 1, texture = 1, hash = 4076107613 },  -- BOOTS_000_TINT_001
            { model = 1, texture = 2, hash = 93297815 },    -- BOOTS_000_TINT_002
            { model = 2, texture = 1, hash = 0 },
            { model = 3, texture = 1, hash = 0 },
            { model = 4, texture = 1, hash = 0 },
        },
        
        -- Style (1-5)
        coats = {
            { model = 1, texture = 1, hash = 3349172660 },  -- COAT_000_TINT_001
            { model = 1, texture = 2, hash = 543785797 },   -- COAT_000_TINT_002
            { model = 1, texture = 3, hash = 1429728481 },  -- COAT_000_TINT_003
            { model = 2, texture = 1, hash = 0 },
            { model = 3, texture = 1, hash = 0 },
        },
        
        -- Length (1-2)
        hats = {
            { model = 1, texture = 1, hash = 1820410246 },  -- FRONTIER_HAT_000
            { model = 2, texture = 1, hash = 2754281087 },  -- HAT_000_TINT_001
        },
    },
    
    female = {
        -- Active
        shirts_full = {
            { model = 1, texture = 1, hash = 3726847883 },  -- CHEMISE_000_TINT_001
            { model = 1, texture = 2, hash = 610548752 },   -- CHEMISE_000_TINT_002
            { model = 1, texture = 3, hash = 4010332502 },  -- CHEMISE_000_TINT_003
            { model = 2, texture = 1, hash = 0 },
            { model = 3, texture = 1, hash = 0 },
        },
        
        -- Clear/Restore
        pants = {
            { model = 1, texture = 1, hash = 3545812420 },  -- FRONTIER_PANTS_000
            { model = 2, texture = 1, hash = 1680224254 },  -- OUTLAW_PANTS_000
            { model = 3, texture = 1, hash = 1570272012 },  -- OVERALLS_001_TINT_001
            { model = 4, texture = 1, hash = 0 },
            { model = 5, texture = 1, hash = 0 },
        },
        
        -- Enabled
        boots = {
            { model = 1, texture = 1, hash = 3723064563 },  -- BOOTS_000_TINT_001
            { model = 1, texture = 2, hash = 1881839991 },  -- BOOTS_000_TINT_002
            { model = 1, texture = 3, hash = 4045806460 },  -- BOOTS_000_TINT_003
            { model = 1, texture = 4, hash = 23641089 },    -- BOOTS_000_TINT_004
            { model = 2, texture = 1, hash = 0 },
        },
        
        -- Disabled
        coats = {
            { model = 1, texture = 1, hash = 1578729681 },  -- first coat
            { model = 1, texture = 2, hash = 1879581870 },
            { model = 1, texture = 3, hash = 948647349 },
            { model = 2, texture = 1, hash = 3555396598 },
            { model = 3, texture = 1, hash = 0 },
        },
        
        -- Active
        hats = {
            { model = 1, texture = 1, hash = 1431102593 },  -- SEASON3_HAT_001
            { model = 3, texture = 1, hash = 3313189151 },  -- FRONTIER_HAT_000
        },
    },
}

-- ==========================================
-- Option
-- ==========================================

-- Configuration value should remain unchanged in context
function GetStarterClothingOptions(isMale)
    return isMale and StarterClothingOptions.male or StarterClothingOptions.female
end

-- Further details on any additional options
function IsStarterClothing(category, hash, isMale)
    local options = GetStarterClothingOptions(isMale)
    if not options[category] then return false end
    
    for _, item in ipairs(options[category]) do
        if item.hash == hash then
            return true
        end
    end
    
    return false
end

-- Additional configurations and settings
function GetStarterClothingCount(category, isMale)
    local options = GetStarterClothingOptions(isMale)
    if not options[category] then return 0 end
    
    local count = 0
    for _, item in ipairs(options[category]) do
        if item.hash and item.hash > 0 then
            count = count + 1
        end
    end
    
    return count
end

-- Updated parameters for processing
function GetStarterClothingByIndex(category, index, isMale)
    local options = GetStarterClothingOptions(isMale)
    if not options[category] then return nil end
    if not options[category][index] then return nil end
    
    return options[category][index]
end

return {
    StarterClothingOptions = StarterClothingOptions,
    GetStarterClothingOptions = GetStarterClothingOptions,
    IsStarterClothing = IsStarterClothing,
    GetStarterClothingCount = GetStarterClothingCount,
    GetStarterClothingByIndex = GetStarterClothingByIndex,
}
