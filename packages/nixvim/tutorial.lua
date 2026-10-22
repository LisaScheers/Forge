local M = {}
local session
local group = vim.api.nvim_create_augroup("ForgeLearnVim", { clear = true })
local highlights = vim.api.nvim_create_namespace("ForgeLearnVim")
local progress_file = vim.fn.stdpath("state") .. "/forge-learn-vim.json"

local function lines_equal(s, expected)
  return vim.deep_equal(vim.api.nvim_buf_get_lines(s.buf, 0, -1, false), expected)
end

local function on_target(s, row, col)
  local cursor = vim.api.nvim_win_get_cursor(s.work)
  return cursor[1] == row and cursor[2] == col
end

local function terminal_visible(s)
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(s.tab)) do
    if vim.bo[vim.api.nvim_win_get_buf(win)].buftype == "terminal" then
      return true
    end
  end
  return false
end

local lessons = {
  {
    id = "welcome",
    title = "Your safe playground",
    body = {
      "Read here. Practise in the pane on the right.",
      "To scroll here: Ctrl+h, then j/k. Ctrl+l returns.",
      "These are temporary files, separate from your work.",
      "",
      "Vim has modes, like tools in a toolbox:",
      "  NORMAL: keys move or edit text.",
      "  INSERT: keys type text, like a regular editor.",
      "  VISUAL: keys select text.",
      "",
      "Esc returns you to Normal mode. If lost, press it.",
      "",
      "Read one step, try it, then press Esc and Enter.",
      "You can repeat or skip any exercise.",
      "F1-F4 may need the Fn key on your keyboard.",
    },
    task = "Press Enter to start. No prior knowledge needed.",
    hint = "The Enter/Return key starts the first exercise.",
    lines = { "Your practice area. Let us start small." },
    check = function()
      return true
    end,
  },
  {
    id = "insert",
    title = "Type, then stop typing",
    body = {
      "You start in NORMAL mode. Typing a letter here",
      "usually runs a command instead of adding text.",
      "",
      "1. Tap i to enter INSERT mode.",
      "2. Type hello.",
      "3. Press Esc to return to NORMAL mode.",
      "",
      "Look at the mode indicator in the bottom bar.",
    },
    task = "Make the empty practice line say: hello",
    hint = "Press i, type hello, then press Esc. No quotes.",
    lines = { "" },
    check = function(s)
      return lines_equal(s, { "hello" })
    end,
  },
  {
    id = "move",
    title = "Move without changing text",
    body = {
      "In NORMAL mode, arrows work. So do these keys:",
      "",
      "             k = up",
      "  h = left   j = down   l = right",
      "",
      "The cursor starts on S. Move it onto X.",
      "Arrows are fine; try h/j/k/l when comfortable.",
    },
    task = "Move right four places, then down twice, onto X.",
    hint = "Press l four times, then j twice. Stay in Normal mode.",
    lines = { "S . .", ". . .", ". . X" },
    check = function(s)
      return on_target(s, 3, 4) and lines_equal(s, { "S . .", ". . .", ". . X" })
    end,
  },
  {
    id = "words",
    title = "Jump by words",
    body = {
      "w jumps to the start of the next word.",
      "b jumps back to the start of a word.",
      "0 jumps to the start of the line (the digit zero).",
      "$ jumps to the end of the line.",
      "",
      "You do not need to tap arrows through every letter.",
    },
    task = "From red, jump to the b in blue without editing.",
    hint = "Press w twice. If you overshoot, press 0 and retry.",
    lines = { "red green blue" },
    check = function(s)
      return on_target(s, 1, 10) and lines_equal(s, { "red green blue" })
    end,
  },
  {
    id = "append",
    title = "Add to the end of a line",
    body = {
      "i types BEFORE the cursor.",
      "a types AFTER the cursor.",
      "Shift+a (capital A) types at the END of the line.",
      "",
      "Vim distinguishes lowercase and uppercase keys.",
      "A is handy when adding punctuation or more text.",
    },
    task = "Add a full stop: Nix manages my tools.",
    hint = "Hold Shift and tap a. Type . and press Esc.",
    lines = { "Nix manages my tools" },
    check = function(s)
      return lines_equal(s, { "Nix manages my tools." })
    end,
  },
  {
    id = "change-word",
    title = "Replace a word in one move",
    body = {
      "Small Vim commands fit together:",
      "  c = change     iw = inside this word",
      "",
      "ciw deletes the word under the cursor and enters",
      "INSERT mode, ready for its replacement.",
      "",
      "The cursor is already on tea.",
    },
    task = "Change the sentence to: I prefer coffee.",
    hint = "Tap c i w, type coffee, then press Esc.",
    lines = { "I prefer tea." },
    cursor = { 1, 9 },
    check = function(s)
      return lines_equal(s, { "I prefer coffee." })
    end,
  },
  {
    id = "undo",
    title = "Delete, undo, redo",
    body = {
      "dd deletes the whole line under the cursor.",
      "u undoes the last change.",
      "Ctrl+r redoes a change you undid.",
      "(Hold Ctrl and tap r; do not type a plus sign.)",
      "",
      "Try all three in order, pausing after each:",
      "1. dd removes delete me.",
      "2. u brings it back.",
      "3. Ctrl+r removes it again.",
    },
    task = "Delete the middle line, undo, then redo.",
    hint = "The cursor starts on delete me. Tap d d, then u, then Ctrl+r.",
    lines = { "keep this", "delete me", "keep this too" },
    cursor = { 2, 0 },
    observe = function(s)
      local deleted = lines_equal(s, { "keep this", "keep this too" })
      if deleted and not s.flags.undone then
        s.flags.deleted = true
      end
      if s.flags.deleted and lines_equal(s, { "keep this", "delete me", "keep this too" }) then
        s.flags.undone = true
      end
      if s.flags.undone and deleted then
        s.flags.redone = true
      end
    end,
    checklist = function(s)
      return {
        { s.flags.deleted, "Delete with dd" },
        { s.flags.undone, "Undo with u" },
        { s.flags.redone, "Redo with Ctrl+r" },
      }
    end,
    check = function(s)
      return s.flags.redone == true
    end,
  },
  {
    id = "copy",
    title = "Copy and paste a line",
    body = {
      "Vim calls copying 'yanking'.",
      "yy copies the current line.",
      "p pastes AFTER the cursor (below for whole lines).",
      "",
      "The cursor starts on coffee. Duplicate that line.",
      "You should end up with coffee, coffee, tea.",
    },
    task = "Copy the first line with yy, then paste it with p.",
    hint = "Tap y y p in Normal mode. No need to enter Insert mode.",
    lines = { "coffee", "tea" },
    check = function(s)
      return lines_equal(s, { "coffee", "coffee", "tea" })
    end,
  },
  {
    id = "visual",
    title = "Select text, then change it",
    body = {
      "v enters VISUAL mode: movement now selects text.",
      "c changes the selection and enters INSERT mode.",
      "Esc returns to NORMAL mode.",
      "",
      "1. Press v on the c in cold.",
      "2. Press l three times to include all of cold.",
      "3. Press c, type hot, then press Esc.",
      "",
      "Tip: capital V selects whole lines instead.",
    },
    task = "Make the practice line say: hot coffee",
    hint = "Tap v l l l c, type hot, then press Esc.",
    lines = { "cold coffee" },
    check = function(s)
      return lines_equal(s, { "hot coffee" })
    end,
  },
  {
    id = "search",
    title = "Find a word in this file",
    body = {
      "/ starts a search. Type a word, then press Enter.",
      "n jumps to the next match; Shift+n goes back.",
      "Esc clears the search highlight in this setup.",
      "",
      "Search starts AFTER your current cursor position.",
      "From the first coffee, /coffee jumps to Friday.",
    },
    task = "Search for coffee and land on coffee on Friday.",
    hint = "Type /coffee and press Enter. The slash opens the search prompt.",
    lines = { "coffee on Monday", "tea on Tuesday", "coffee on Friday", "water on Sunday" },
    check = function(s)
      return on_target(s, 3, 0) and vim.fn.getreg("/") == "coffee"
    end,
  },
  {
    id = "save",
    title = "Save a file",
    body = {
      "Changes stay in memory until you save them.",
      "",
      "In this setup: Space, then w saves the file.",
      "The usual Vim command is :w then Enter.",
      "A colon opens a command prompt at the bottom.",
      "",
      "1. Add ! at the end with A, !, Esc.",
      "2. Save with Space then w (or :w then Enter).",
      "",
      "This is a real file in the temporary playground.",
    },
    task = "Make the line Remember to save! and save it.",
    hint = "Press A, type !, Esc, then Space and w separately.",
    lines = { "Remember to save" },
    check = function(s)
      return lines_equal(s, { "Remember to save!" })
        and not vim.bo[s.buf].modified
        and vim.deep_equal(vim.fn.readfile(s.file), { "Remember to save!" })
    end,
  },
  {
    id = "splits",
    title = "Move between panes",
    body = {
      "These two panes are called splits.",
      "Ctrl+h moves to the left split.",
      "Ctrl+l moves to the right split.",
      "Ctrl+j / Ctrl+k move down / up in other layouts.",
      "",
      "1. Hold Ctrl and tap h to visit this guide.",
      "2. Hold Ctrl and tap l to return to practice.",
      "",
      "Your focus changes; the text does not move.",
    },
    task = "Visit the left guide, then return to the right pane.",
    hint = "Ctrl+h, then Ctrl+l. Keep Ctrl held while tapping each letter.",
    lines = { "Return your cursor here after visiting the guide." },
    observe = function(s)
      local win = vim.api.nvim_get_current_win()
      if win == s.guide then
        s.flags.guide = true
      end
      if s.flags.guide and win == s.work then
        s.flags.returned = true
      end
    end,
    check = function(s)
      return s.flags.returned == true
    end,
  },
  {
    id = "files",
    title = "Find and open another file",
    body = {
      "Space is the 'leader': a prefix for shortcuts.",
      "Tap it once and wait to see available keys.",
      "",
      "Space, f, f opens the file finder.",
      "Type part of a filename to narrow the list.",
      "Use arrows to choose; Enter opens the file.",
      "Esc closes the finder if you want to retry.",
      "",
      "The finder is scoped to this practice folder.",
    },
    task = "Use Space f f to find and open welcome.txt.",
    hint = "Tap Space f f, type welcome, then Enter. Press Enter again to continue.",
    lines = { "Find welcome.txt in the same practice folder." },
    observe = function(s)
      if vim.api.nvim_buf_get_name(0) == s.dir .. "/welcome.txt" then
        s.flags.found = true
      end
    end,
    check = function(s)
      return s.flags.found == true
    end,
  },
  {
    id = "terminal",
    title = "Open a terminal and come back",
    body = {
      "Space, t, f toggles a floating terminal.",
      "Inside it, your keys go to the shell.",
      "",
      "1. Open it with Space t f.",
      "2. Press Esc TWICE to enter Terminal Normal mode.",
      "3. Press Space t f again to hide the terminal.",
      "",
      "You do not need to run a shell command here.",
      "The two Esc presses get you back to editor keys.",
    },
    task = "Open the terminal, then hide it and return here.",
    hint = "Space t f -> Esc Esc -> Space t f. Then Enter.",
    lines = { "Your practice pane will still be here." },
    observe = function(s)
      if terminal_visible(s) then
        s.flags.terminal = true
      end
    end,
    check = function(s)
      return s.flags.terminal and not terminal_visible(s)
    end,
  },
  {
    id = "finish",
    title = "Ready for your first real file",
    body = {
      "You can return here whenever you need a refresher.",
      "Some useful next steps in your actual setup:",
      "",
      "Space e      Toggle the file explorer.",
      "Space f w    Find text across your project.",
      "Space f b    Switch between open files (buffers).",
      "Space f k    Search all keybindings.",
      "Space l f    Format code.",
      "gd / K       Go to definition / show docs (code).",
      "Space l r    Rename a symbol (language server).",
      "",
      "To leave Vim: Esc, type :q, then Enter.",
      ":wq saves and quits. :q! discards unsaved edits.",
      "Use :qa to close all windows; save changes first.",
      "",
      "Inside Vim: Space h resumes this tutorial.",
      ":LearnVim restart starts again from the beginning.",
    },
    task = "Press Enter to leave the playground.",
    hint = "You can also click Quit tutorial below or use :LearnVim close.",
    lines = { "Esc -> Normal mode", "i -> type text", "Esc -> stop typing", "Space w -> save", ":q -> quit" },
    check = function()
      return true
    end,
  },
}

local function read_progress()
  local ok, value = pcall(function()
    return vim.json.decode(table.concat(vim.fn.readfile(progress_file), "\n"))
  end)
  if ok and type(value) == "table" and value.version == 1 and type(value.completed) == "table" then
    return value
  end
  return { version = 1, completed = {}, lesson = "welcome" }
end

local function save_progress(s)
  local index = s.passed and math.min(s.index + 1, #lessons) or s.index
  s.progress.lesson = lessons[index].id
  vim.fn.mkdir(vim.fn.fnamemodify(progress_file, ":h"), "p")
  local ok, result = pcall(vim.fn.writefile, { vim.json.encode(s.progress) }, progress_file)
  if (not ok or result ~= 0) and not s.save_warning then
    s.save_warning = true
    vim.notify("Could not save tutorial progress; you can keep practising.", vim.log.levels.WARN)
  end
end

local function render(s)
  if not vim.api.nvim_buf_is_valid(s.guide_buf) then
    return
  end
  local lesson = lessons[s.index]
  local complete = 0
  for _, item in ipairs(lessons) do
    if item.id ~= "welcome" and item.id ~= "finish" and s.progress.completed[item.id] then
      complete = complete + 1
    end
  end
  local modes = {
    n = "NORMAL: keys run commands",
    i = "INSERT: keys type text",
    v = "VISUAL: text selection",
    V = "VISUAL: line selection",
    c = "COMMAND: type, then Enter",
    t = "TERMINAL: keys go to shell",
  }
  local mode = vim.api.nvim_get_mode().mode
  local text = {
    "  LEARN VIM    " .. s.index .. " / " .. #lessons,
    "  " .. complete .. " / " .. (#lessons - 2) .. " exercises practised",
    "  " .. (modes[mode] or "Press Esc for Normal mode."),
    "  Esc, then Enter: check / next",
    "  F1 hint | F2 retry | F3 back | F4 skip",
    "  [Next] [Hint] [Retry] [Back] [Skip] [Quit]",
    "",
    "  " .. lesson.title,
    "  GOAL: " .. lesson.task,
    "",
  }
  local status = s.message
    or (s.passed and "Done! Esc, then Enter for the next step." or "Try it on the right. Esc is your way back.")
  if lesson.id ~= "welcome" and lesson.id ~= "finish" then
    vim.list_extend(text, { "  " .. status, "" })
  end
  if s.hint then
    vim.list_extend(text, { "  HINT: " .. lesson.hint, "" })
  end
  for _, line in ipairs(lesson.body) do
    text[#text + 1] = "  " .. line
  end
  if lesson.checklist then
    for _, item in ipairs(lesson.checklist(s)) do
      text[#text + 1] = "  " .. (item[1] and "[x] " or "[ ] ") .. item[2]
    end
    text[#text + 1] = ""
  end
  vim.list_extend(
    text,
    { "", "  Leave: :LearnVim close", "  Scroll this guide: Ctrl+h, then j/k.", "  Return to practice: Ctrl+l." }
  )
  if vim.deep_equal(vim.api.nvim_buf_get_lines(s.guide_buf, 0, -1, false), text) then
    return
  end
  vim.bo[s.guide_buf].modifiable = true
  vim.api.nvim_buf_set_lines(s.guide_buf, 0, -1, false, text)
  vim.bo[s.guide_buf].modifiable = false
  vim.bo[s.guide_buf].modified = false
  vim.api.nvim_buf_clear_namespace(s.guide_buf, highlights, 0, -1)
  for row, line in ipairs(text) do
    local hl = (row == 1 or row == 8 or line:find("  GOAL:", 1, true) or line:find("  HINT:", 1, true)) and "Title"
      or (line:find("Done!", 1, true) or line:find("[x]", 1, true)) and "DiagnosticOk"
      or line:find("  [Next]", 1, true) and "Underlined"
    if hl then
      vim.api.nvim_buf_set_extmark(s.guide_buf, highlights, row - 1, 0, { end_col = #line, hl_group = hl })
    end
  end
end

local function update()
  local s = session
  if not s or s.loading or not vim.api.nvim_tabpage_is_valid(s.tab) or vim.api.nvim_get_current_tabpage() ~= s.tab then
    return
  end
  if not vim.api.nvim_win_is_valid(s.work) or not vim.api.nvim_buf_is_valid(s.buf) then
    return
  end
  local lesson = lessons[s.index]
  if lesson.observe then
    lesson.observe(s)
  end
  if not s.passed and vim.api.nvim_get_mode().mode == "n" and lesson.check(s) then
    s.passed, s.message = true, nil
    if lesson.id ~= "welcome" and lesson.id ~= "finish" then
      s.progress.completed[lesson.id] = true
    end
    save_progress(s)
  end
  render(s)
end

local function controls(buf)
  if session.mapped[buf] then
    return
  end
  session.mapped[buf] = true
  local function map(key, action, desc)
    vim.keymap.set("n", key, action, { buffer = buf, silent = true, desc = desc })
  end
  map("<CR>", M.check, "Tutorial: check / next")
  map("<F1>", M.hint, "Tutorial: hint")
  map("<F2>", M.reset, "Tutorial: retry")
  map("<F3>", M.back, "Tutorial: previous step")
  map("<F4>", M.skip, "Tutorial: skip step")
  map("<LeftMouse>", M.click, "Tutorial buttons")
end

function M.click()
  local s = session
  if not s then
    return
  end
  local mouse = vim.fn.getmousepos()
  if mouse.winid ~= s.guide then
    vim.api.nvim_feedkeys(vim.keycode("<LeftMouse>"), "n", false)
    return
  end
  local line = (vim.api.nvim_buf_get_lines(s.guide_buf, mouse.line - 1, mouse.line, false)[1] or "")
  local actions = { Next = M.check, Hint = M.hint, Retry = M.reset, Back = M.back, Skip = M.skip, Quit = M.close }
  for first, name, last in line:gmatch("()%[([%a]+)%]()") do
    if mouse.column >= first and mouse.column < last and actions[name] then
      actions[name]()
      return
    end
  end
  vim.api.nvim_set_current_win(s.guide)
  vim.api.nvim_win_set_cursor(s.guide, { math.max(1, mouse.line), math.max(0, mouse.column - 1) })
end

local function load(index)
  local s = session
  s.loading = true
  s.index, s.flags, s.passed, s.hint, s.message = index, {}, false, false, nil
  vim.api.nvim_set_current_tabpage(s.tab)
  if not vim.api.nvim_win_is_valid(s.work) then
    vim.api.nvim_set_current_win(s.guide)
    vim.cmd("rightbelow vsplit")
    s.work = vim.api.nvim_get_current_win()
  end
  vim.api.nvim_win_set_buf(s.work, s.buf)
  vim.api.nvim_set_current_win(s.work)
  local undo = vim.bo[s.buf].undolevels
  vim.bo[s.buf].undolevels = -1
  vim.api.nvim_buf_set_lines(s.buf, 0, -1, false, lessons[index].lines)
  vim.bo[s.buf].undolevels = undo
  vim.cmd("silent noautocmd write!")
  vim.api.nvim_win_set_cursor(s.work, lessons[index].cursor or { 1, 0 })
  vim.api.nvim_win_call(s.guide, function()
    vim.fn.winrestview({ topline = 1, lnum = 1, col = 0 })
  end)
  vim.wo[s.work].number, vim.wo[s.work].relativenumber = true, false
  vim.wo[s.work].wrap = false
  vim.fn.setreg("/", "")
  s.loading = false
  save_progress(s)
  update()
end

function M.check()
  local s = session
  if not s then
    return
  end
  update()
  if not s.passed then
    s.message, s.hint = "Not quite yet. Try the hint, or retry this step.", true
    render(s)
  elseif s.index == #lessons then
    M.close()
  else
    load(s.index + 1)
  end
end

function M.hint()
  if session then
    session.hint = not session.hint
    render(session)
  end
end

function M.reset()
  if session then
    load(session.index)
  end
end

function M.back()
  if session then
    load(math.max(1, session.index - 1))
  end
end

function M.skip()
  if session then
    if session.index == #lessons then
      M.close()
    else
      load(session.index + 1)
    end
  end
end

function M.close()
  local s = session
  if not s then
    return
  end
  session = nil
  vim.api.nvim_clear_autocmds({ group = group })
  for buf in pairs(s.terminals) do
    if vim.api.nvim_buf_is_valid(buf) then
      local terminal = require("toggleterm.terminal").get(vim.b[buf].toggle_number, true)
      if terminal then
        terminal:shutdown()
      else
        vim.api.nvim_buf_delete(buf, { force = true })
      end
    end
  end
  if vim.api.nvim_tabpage_is_valid(s.tab) then
    vim.api.nvim_set_current_tabpage(s.tab)
    vim.cmd("tabclose!")
  end
  if vim.api.nvim_tabpage_is_valid(s.original_tab) then
    vim.api.nvim_set_current_tabpage(s.original_tab)
    if vim.api.nvim_win_is_valid(s.original_win) then
      vim.api.nvim_set_current_win(s.original_win)
    end
  end
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    local name = vim.api.nvim_buf_get_name(buf)
    if buf == s.guide_buf or name:sub(1, #s.dir + 1) == s.dir .. "/" then
      vim.api.nvim_buf_delete(buf, { force = true })
    end
  end
  vim.fn.delete(s.dir, "rf")
end

function M.open(restart)
  if session then
    if restart then
      session.progress = { version = 1, completed = {} }
      load(1)
    else
      vim.api.nvim_set_current_tabpage(session.tab)
      if vim.api.nvim_win_is_valid(session.work) then
        vim.api.nvim_set_current_win(session.work)
      else
        load(session.index)
      end
    end
    return
  end
  local progress = restart and { version = 1, completed = {} } or read_progress()
  local dir = vim.fn.tempname()
  vim.fn.mkdir(dir, "p")
  dir = vim.fn.resolve(dir)
  vim.fn.writefile(
    { "You found the second file. Well done!", "Press Esc, then Enter to continue the tutorial." },
    dir .. "/welcome.txt"
  )
  local original_tab, original_win = vim.api.nvim_get_current_tabpage(), vim.api.nvim_get_current_win()
  vim.cmd("tabnew")
  local guide, guide_buf = vim.api.nvim_get_current_win(), vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_set_name(guide_buf, "LearnVim://guide")
  vim.bo[guide_buf].buftype, vim.bo[guide_buf].bufhidden = "nofile", "wipe"
  vim.bo[guide_buf].swapfile = false
  vim.bo[guide_buf].filetype = "learnvim"
  vim.wo[guide].number, vim.wo[guide].relativenumber, vim.wo[guide].wrap = false, false, true
  vim.wo[guide].winbar = " Learn Vim | guide"
  vim.cmd("rightbelow vsplit")
  local buf = vim.api.nvim_create_buf(true, false)
  vim.api.nvim_buf_set_name(buf, dir .. "/practice.txt")
  vim.bo[buf].filetype = "text"
  vim.bo[buf].swapfile, vim.bo[buf].undofile = false, false
  vim.bo[buf].bufhidden = "hide"
  local work = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(work, buf)
  vim.api.nvim_win_set_width(guide, math.min(64, math.floor(vim.o.columns * 0.55)))
  vim.wo[work].winbar = " Practice here | Esc = Normal mode"
  session = {
    dir = dir,
    file = dir .. "/practice.txt",
    tab = vim.api.nvim_get_current_tabpage(),
    guide = guide,
    guide_buf = guide_buf,
    work = work,
    buf = buf,
    progress = progress,
    original_tab = original_tab,
    original_win = original_win,
    mapped = {},
    terminals = {},
  }
  vim.cmd("tcd " .. vim.fn.fnameescape(dir))
  controls(guide_buf)
  controls(buf)
  vim.keymap.set("n", "q", M.close, { buffer = guide_buf, silent = true, desc = "Quit tutorial" })
  vim.api.nvim_create_autocmd({
    "TextChanged",
    "TextChangedI",
    "CursorMoved",
    "InsertLeave",
    "ModeChanged",
    "BufWritePost",
    "WinEnter",
    "BufEnter",
    "TermOpen",
    "WinClosed",
  }, {
    group = group,
    callback = function(event)
      if session and vim.api.nvim_get_current_tabpage() == session.tab then
        if event.event == "TermOpen" then
          session.terminals[event.buf] = true
        end
        local current = vim.api.nvim_get_current_buf()
        if vim.api.nvim_buf_get_name(current):sub(1, #session.dir + 1) == session.dir .. "/" then
          controls(current)
        end
        local lesson = lessons[session.index]
        if not session.loading and lesson.observe then
          lesson.observe(session)
        end
      end
      vim.schedule(update)
    end,
  })
  vim.api.nvim_create_autocmd("TabClosed", {
    group = group,
    callback = function()
      vim.schedule(function()
        if session and not vim.api.nvim_tabpage_is_valid(session.tab) then
          M.close()
        end
      end)
    end,
  })
  local index = 1
  for i, lesson in ipairs(lessons) do
    if lesson.id == progress.lesson then
      index = i
      break
    end
  end
  load(index)
end

function M.setup()
  local actions = { hint = M.hint, reset = M.reset, back = M.back, skip = M.skip, next = M.check, close = M.close }
  vim.api.nvim_create_user_command("LearnVim", function(opts)
    if opts.args == "restart" then
      M.open(true)
    elseif opts.args == "" then
      M.open()
    elseif actions[opts.args] then
      actions[opts.args]()
    else
      vim.notify("Use :LearnVim [restart|hint|reset|back|skip|next|close]", vim.log.levels.INFO)
    end
  end, {
    nargs = "?",
    desc = "Interactive introduction to this Nixvim setup",
    complete = function()
      return { "restart", "hint", "reset", "back", "skip", "next", "close" }
    end,
  })
end

return M
