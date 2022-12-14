local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local conf = require("telescope.config").values
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")

local maps = {}

local get_current_path = function()
    local current_file_path = vim.api.nvim_buf_get_name(0)
    local current_path
    if current_file_path == nil or current_file_path == "" then
        current_path = vim.fn.getcwd()
    else
        current_path = current_file_path
    end
    return current_path
end

local get_parent_path = function(path)
    local pattern1 = "^(.+)/"
    local pattern2 = "^(.+)\\"

    if string.match(path, pattern1) == nil then
        return string.match(path, pattern2)
    else
        return string.match(path, pattern1)
    end
end

local get_ancestor_path_list = function(path)
    local path_list = { path }
    while path ~= nil and path ~= "" do
        path = get_parent_path(path)
        table.insert(path_list, path)
    end
    return path_list
end

local set_working_directory = function(path)
    local current_tabpage = vim.api.nvim_get_current_tabpage()
    maps[current_tabpage] = path
end

local change_working_directory = function()
    local current_tabpage = vim.api.nvim_get_current_tabpage()
    if maps[current_tabpage] ~= nil then
        vim.cmd("cd " .. maps[current_tabpage])
    end
end

local handle_tabenter = function()
    change_working_directory()
end

local function tabline_path(path)
    return path
end

local function tabline_label(path, config)
    if path == nil then
        return "No name"
    end
    if config.label_type == "path" then
        return tabline_path(path)
    end
    return path
end

local function tabline()
    local s = ""
    for index = 1, vim.fn.tabpagenr("$") do
        s = s .. "%" .. index .. "T"
        if index == vim.fn.tabpagenr() then
            s = s .. "%#TabLineSel#"
        else
            s = s .. "%#TabLine#"
        end
        local path = maps[index]
        local config = {
            label_type = "path",
        }
        s = s .. "[" .. tabline_label(path, config) .. "] "
    end
    return s
end

return require("telescope").register_extension({
    setup = function(ext_config)
        function _G.nvim_tabline()
            return tabline()
        end
        vim.api.nvim_create_autocmd("TabEnter", {
            callback = handle_tabenter,
        })
        vim.o.showtabline = 2
        vim.o.tabline = "%!v:lua.nvim_tabline()"
        vim.g.loaded_nvim_tabline = 1
    end,
    exports = {
        list = function(opts)
            opts = opts or {}
            local current_path = get_current_path()
            local path_list = get_ancestor_path_list(current_path)

            pickers
                .new(opts, {
                    prompt_title = "colors",
                    finder = finders.new_table({
                        results = path_list,
                    }),
                    sorter = conf.generic_sorter(opts),
                    attach_mappings = function(prompt_bufnr, map)
                        actions.select_default:replace(function()
                            actions.close(prompt_bufnr)
                            local selection = action_state.get_selected_entry()
                            local path = selection[1]
                            set_working_directory(path)
                            change_working_directory()
                        end)
                        return true
                    end,
                })
                :find()
        end,
    },
})
