---@param msg string
local notify_warn = function(msg)
    ya.notify { title = "ZFS", content = msg, level = "warn", timeout = 5 }
end

---@param msg string
local notify_error = function(msg)
    ya.notify { title = "ZFS", content = msg, level = "error", timeout = 5 }
end

---@param arr table
---@param elem any
local find_index = function(arr, elem)
    for i, value in ipairs(arr) do
        if value == elem then
            return i
        end
    end
    return nil
end

---@return string
local get_cwd = ya.sync(function()
    return tostring(cx.active.current.cwd)
end)

---@param cwd string
---@return string
local get_dataset = function(cwd)
    local df, _ = Command("df"):args({ "--output=source", cwd }):output()
    local dataset = ""
    for line in df.stdout:gmatch("[^\r\n]+") do
        -- dataset is last line in output
        dataset = line
    end
    return dataset
end

---@param dataset string
---@return string|nil
local get_mountpoint = function(dataset)
    local zfs, _ = Command("zfs"):args({ "get", "-H", "-o", "value", "mountpoint", dataset }):output()

    -- not a dataset!
    if not zfs.status.success then
        return nil
    end

    -- legacy mountpoint, search for actual mountpoint using df
    if zfs.stdout == "legacy\n" then
        local df, _ = Command("df"):output()
        if not df.status.success then
            return nil
        end

        for line in df.stdout:gmatch("[^\r\n]+") do
            -- match start of line
            if string.sub(line, 1, #dataset) == dataset then
                local mountpoint = nil
                for field in line:gmatch("%S+") do
                    -- mountpoint is last field in df output
                    mountpoint = field
                end
                return mountpoint
            end
        end
    else
        return zfs.stdout:gsub("\n$", "")
    end

    -- shouldn't be here
    return nil
end

---@param d string
local is_snapshot_dir = function(d)
    return d:find(".zfs/snapshot") ~= nil
end

-- returns the path relative to the mountpoint / snapshot
---@param cwd string
---@param mountpoint string
local get_relative = function(cwd, mountpoint)
    -- relative path to get mountpoint
    local relative = (cwd:sub(0, #mountpoint) == mountpoint) and cwd:sub(#mountpoint + 1) or cwd

    -- is a snapshot dir, strip everything after "/snapshot"
    if is_snapshot_dir(cwd) then
        local snapshot_pos = cwd:find("/snapshot")

        -- everything after the "/snapshot/"
        local after = cwd:sub(snapshot_pos + #"/snapshot" + 1)
        local first_slash = after:find("/")
        -- root of snapshot?
        if first_slash == nil then
            return "/"
        else
            return after:sub(first_slash)
        end
    end

    return relative
end

---@param dataset string
---@return string[]
local get_snapshots = function(dataset)
    -- -S is for reverse order
    local zfs_snapshots, _ = Command("zfs"):args({ "list", "-H", "-t", "snapshot", "-o", "name", "-S", "creation",
            dataset })
        :output()

    if not zfs_snapshots.status.success then
        return {}
    end

    local snapshots = {}
    for snapshot in zfs_snapshots.stdout:gmatch("[^\r\n]+") do
        -- in the format dataset@snapshot
        local sep = snapshot:find("@")
        table.insert(snapshots, snapshot:sub(sep + 1))
    end
    return snapshots
end

return {
    entry = function(_, args)
        local action = args[1]
        local cwd = get_cwd()

        if action ~= "exit" and action ~= "prev" and action ~= "next" then
            return notify_error("Invalid action: " .. action)
        end

        local dataset = get_dataset(cwd)
        local current_snapshot = ""
        if is_snapshot_dir(cwd) then
            -- in the format dataset@snapshot
            local sep = dataset:find("@")
            current_snapshot = dataset:sub(sep + 1)
            dataset = dataset:sub(1, sep - 1)
        end

        local mountpoint = get_mountpoint(dataset)
        if mountpoint == nil then
            return notify_error("Current directory is not within a ZFS dataset!")
        end

        -- NOTE: relative already has leading "/"
        local relative = get_relative(cwd, mountpoint)

        if action == "exit" then
            ya.manager_emit("cd", { mountpoint .. relative })
            return
        end

        local snapshots = get_snapshots(dataset)
        if #snapshots == 0 then
            return notify_warn("No snapshots found.")
        end

        ---@param start_idx integer
        ---@param end_idx integer
        ---@param step integer
        local find_and_goto_snapshot = function(start_idx, end_idx, step)
            if start_idx == 0 then
                -- going from newest snapshot to current state
                return ya.manager_emit("cd", { mountpoint .. relative })
            elseif start_idx < 0 then
                return notify_warn("No earlier snapshots found.")
            elseif start_idx > #snapshots then
                return notify_warn("No later snapshots found.")
            end

            for i = start_idx, end_idx, step do
                local snapshot_dir = mountpoint .. "/.zfs/snapshot/" .. snapshots[i] .. relative

                -- check if relative path within snapshot exists
                if io.open(snapshot_dir, "r") then
                    return ya.manager_emit("cd", { snapshot_dir })
                end
            end

            local direction = action == "prev" and "earlier" or "later"
            return notify_warn("No " .. direction .. " snapshots found.")
        end

        -- NOTE: latest snapshot is first in list
        if current_snapshot == "" then
            if action == "prev" then
                -- go to latest snapshot
                return find_and_goto_snapshot(1, #snapshots, 1)
            elseif action == "next" then
                return notify_warn("No later snapshots found.")
            end
        end

        -- has current snapshot
        local idx = find_index(snapshots, current_snapshot)
        if idx == nil then
            return notify_error("Snapshot not found.")
        end

        if action == "prev" then
            find_and_goto_snapshot(idx + 1, #snapshots, 1)
        elseif action == "next" then
            find_and_goto_snapshot(1, idx - 1, -1)
        end
    end,
}
