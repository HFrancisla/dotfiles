require("relative-motions"):setup({ show_numbers = "relative", show_motion = true, enter_mode = "first" })

local home_path = assert(os.getenv("HOME"))
local bookmarks = {
    { tag = "Desktop", path = home_path .. "/Desktop/", key = "d" },
}

require("yamb"):setup {
    bookmarks = bookmarks,
    jump_notify = true,
    cli = "fzf",
    keys = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ",
    path = home_path .. "/.config/yazi/bookmark",
}

require("git"):setup()

require("full-border"):setup {
    type = ui.Border.ROUNDED,
}
