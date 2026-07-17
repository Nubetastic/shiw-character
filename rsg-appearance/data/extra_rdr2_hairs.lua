-- ==========================================
-- Available textures for RDR2/RDO
-- Note, available in hairs_list
-- ==========================================

local CATEGORY_HAIR = 2253063086
local MaleHairColors = {
    'BLONDE', 'BROWN', 'DARKEST_BROWN', 'DARK_BLONDE', 'DARK_GINGER',
    'DARK_GREY', 'GINGER', 'GREY', 'JET_BLACK', 'LIGHT_BLONDE', 'LIGHT_BROWN',
    'LIGHT_GINGER', 'LIGHT_GREY', 'MEDIUM_BROWN', 'SALT_PEPPER',
    'STRAWBERRY_BLONDE', 'UNCLE_GREY'
}

local FemaleHairColors = MaleHairColors

local function makeEntry(hashname, pedType)
    return {
        category_hash = CATEGORY_HAIR,
        category_hash_dec_signed = -2041904210,
        category_hashname = 'hair',
        hash = GetHashKey(hashname),
        hashname = hashname,
        is_multiplayer = true,
        ped_type = pedType,
    }
end

-- Available options for hairs_list
local function MergeExtraRDR2Hairs(hairs_list)
    -- Male: 026, 027 (Hash name is needed to set to this hair)
    for _, style in ipairs({26, 27}) do
        local styleNum = string.format('%03d', style)
        if not hairs_list.male or not hairs_list.male.hair then
            hairs_list.male = hairs_list.male or {}
            hairs_list.male.hair = hairs_list.male.hair or {}
        end
        local colors = {}
        for i, color in ipairs(MaleHairColors) do
            local hashname = 'CLOTHING_ITEM_M_HAIR_' .. styleNum .. '_' .. color
            colors[i] = makeEntry(hashname, 'male')
        end
        hairs_list.male.hair[style] = colors
    end

    -- Female: 029, 030 (RDO-update available, that hair is used in game)
    for _, style in ipairs({29, 30}) do
        local styleNum = string.format('%03d', style)
        if not hairs_list.female or not hairs_list.female.hair then
            hairs_list.female = hairs_list.female or {}
            hairs_list.female.hair = hairs_list.female.hair or {}
        end
        if not hairs_list.female.hair[style] then
            local colors = {}
            for i, color in ipairs(FemaleHairColors) do
                local hashname = 'CLOTHING_ITEM_F_HAIR_' .. styleNum .. '_' .. color
                colors[i] = makeEntry(hashname, 'female')
            end
            hairs_list.female.hair[style] = colors
        end
    end
end

return {
    MergeExtraRDR2Hairs = MergeExtraRDR2Hairs,
}
