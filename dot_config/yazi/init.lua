--relative-motions.yazi
require("relative-motions"):setup({ show_numbers = "relative", show_motion = true, enter_mode = "first" })


--yamb.yazi
local bookmarks = {}

local path_sep = package.config:sub(1, 1)
local home_path = ya.target_family() == "windows" and os.getenv("USERPROFILE") or os.getenv("HOME")
if ya.target_family() == "windows" then
    table.insert(bookmarks, {
        tag = "Scoop Local",

        path = (os.getenv("SCOOP") or home_path .. "\\scoop") .. "\\",
        key = "p"
    })
    table.insert(bookmarks, {
        tag = "Scoop Global",
        path = (os.getenv("SCOOP_GLOBAL") or "C:\\ProgramData\\scoop") .. "\\",
        key = "P"
    })
end
table.insert(bookmarks, {
    tag = "Desktop",
    path = home_path .. path_sep .. "Desktop" .. path_sep,
    key = "d"
})

--yamb.yazi
require("yamb"):setup {
    -- Optional, the path ending with path seperator represents folder.
    bookmarks = bookmarks,
    -- Optional, recieve notification everytime you jump.
    jump_notify = true,
    -- Optional, the cli of fzf.
    cli = "fzf",
    -- Optional, a string used for randomly generating keys, where the preceding characters have higher priority.
    keys = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ",
    -- Optional, the path of bookmarks
    path = (ya.target_family() == "windows" and os.getenv("APPDATA") .. "\\yazi\\config\\bookmark") or
        (os.getenv("HOME") .. "/.config/yazi/bookmark"),
}

--git.yazi
require("git"):setup()

-- THEME.git = THEME.git or {}
-- THEME.git.modified = ui.Style():fg("blue")
-- THEME.git.deleted = ui.Style():fg("red"):bold()
-- THEME.git.modified_sign = "M"
-- THEME.git.deleted_sign = "D"

--full-border.yazi
require("full-border"):setup {
    -- Available values: ui.Border.PLAIN, ui.Border.ROUNDED
    type = ui.Border.ROUNDED,
}
