--[[============================================================
    GENERIC DATABASE ADAPTER  (Config.Housing.script = 'db')

    Reads the owner straight out of the housing resource own table. This is
    the one adapter that works with EVERY housing script, including escrow
    protected ones that expose no exports and fire no events: their table is
    still readable.

    Finding the three values takes a minute in HeidiSQL or phpMyAdmin: open
    the housing table, look at which column holds the house name/id and which
    one holds the player identifier.

        Config.Housing = {
            enable = true,
            script = 'db',
            db = {
                table       = 'owned_properties',
                houseColumn = 'name',
                ownerColumn = 'owner',
                -- optional, for scripts that keep roommates in a second table
                membersTable       = nil,
                membersHouseColumn = nil,
                membersOwnerColumn = nil,
            },
        }

    Known mappings are listed in config/static.lua (Config.HousingPresets).
============================================================]]--

-- Table and column names cannot be bound as query parameters, they are
-- concatenated into the SQL. They come from the config (server owner
-- controlled, never from a player), but a typo containing a quote would still
-- produce a broken or dangerous statement, so everything is validated against
-- a plain identifier pattern first and rejected otherwise.
local IDENT_PATTERN = '^[%w_]+$'

local function ident(value)
    if type(value) ~= 'string' or value == '' or #value > 64 then return nil end
    if not value:match(IDENT_PATTERN) then return nil end
    return value
end

local warned = false

local function conf()
    local cfg = (Config.Housing or {}).db
    if type(cfg) ~= 'table' then return nil end

    local tbl   = ident(cfg.table)
    local house = ident(cfg.houseColumn)
    local owner = ident(cfg.ownerColumn)

    if not tbl or not house or not owner then
        if not warned then
            warned = true
            print('^1[msk_garage]^0 Housing/db: table, houseColumn or ownerColumn is missing or not a plain '
                .. 'identifier. Adapter disabled, private garages keep using their stored owner.')
        end
        return nil
    end

    return tbl, house, owner, cfg
end

Housing.RegisterAdapter('db', {
    GetOwner = function(houseRef)
        local tbl, house, owner = conf()
        if not tbl then return nil end

        local row = MySQL.single.await(
            ('SELECT `%s` AS owner_id FROM `%s` WHERE `%s` = ? LIMIT 1'):format(owner, tbl, house),
            { houseRef }
        )
        if not row then return nil end

        local id = row.owner_id
        if type(id) ~= 'string' or id == '' then return nil end
        return id
    end,

    -- Only used when the housing script keeps roommates in a table of its own.
    -- Without membersTable this returns nil and msk_garage falls back to its
    -- own access list, which is the normal case.
    GetMembers = function(houseRef)
        local _, _, _, cfg = conf()
        if not cfg then return nil end

        local tbl   = ident(cfg.membersTable)
        local house = ident(cfg.membersHouseColumn)
        local owner = ident(cfg.membersOwnerColumn)
        if not tbl or not house or not owner then return nil end

        local rows = MySQL.query.await(
            ('SELECT `%s` AS owner_id FROM `%s` WHERE `%s` = ?'):format(owner, tbl, house),
            { houseRef }
        ) or {}

        local out = {}
        for _, row in ipairs(rows) do
            if type(row.owner_id) == 'string' and row.owner_id ~= '' then
                out[#out + 1] = row.owner_id
            end
        end
        return out
    end,
})
