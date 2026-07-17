-- ==========================================
-- HAIR AND BEARD DATA FOR BARBERSHOP
-- ==========================================

HairsData = {}

-- Hair colors (order is important for indexing!)
HairColorOrder = {
    "BLONDE",
    "BROWN",
    "DARKEST_BROWN",
    "DARK_BLONDE",
    "DARK_GINGER",
    "DARK_GREY",
    "GINGER",
    "GREY",
    "JET_BLACK",
    "LIGHT_BLONDE",
    "RED_GINGER"
}

HairColorNames = {
    ["BLONDE"] = "Blonde",
    ["BROWN"] = "Brown",
    ["DARKEST_BROWN"] = "Dark Brown",
    ["DARK_BLONDE"] = "Dark Blonde",
    ["DARK_GINGER"] = "Dark Red",
    ["DARK_GREY"] = "Dark Gray",
    ["GINGER"] = "Red",
    ["GREY"] = "Gray",
    ["JET_BLACK"] = "Jet Black",
    ["LIGHT_BLONDE"] = "Light Blonde",
    ["RED_GINGER"] = "Red-Orange"
}

-- Function to get hair hash by name
function GetHairHashByName(hashname)
    return GetHashKey(hashname)
end

-- Color indexes for reverse conversion
HairColorIndex = {
    ["BLONDE"] = 1,
    ["BROWN"] = 2,
    ["DARKEST_BROWN"] = 3,
    ["DARK_BLONDE"] = 4,
    ["DARK_GINGER"] = 5,
    ["DARK_GREY"] = 6,
    ["GINGER"] = 7,
    ["GREY"] = 8,
    ["JET_BLACK"] = 9,
    ["LIGHT_BLONDE"] = 10,
    ["RED_GINGER"] = 11,
}

-- Function to get color index from suffix
function GetColorIndexFromSuffix(suffix)
    return HairColorIndex[suffix] or 1
end

-- Function to get color suffix from index
function GetColorSuffixFromIndex(index)
    return HairColorOrder[index] or "JET_BLACK"
end
