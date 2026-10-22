local function check(condition, message)
  if not condition then
    error(message)
  end
end

local run
local function resume()
  local ok, err = coroutine.resume(run)
  if not ok then
    io.stderr:write(tostring(err) .. "\n")
    vim.cmd("cquit 1")
  end
end

local function settle()
  vim.defer_fn(resume, 100)
  coroutine.yield()
end

local function keys(input)
  vim.api.nvim_feedkeys(vim.keycode(input), "t", false)
  settle()
end

local function guide()
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_get_name(buf) == "LearnVim://guide" then
      return table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n"), buf
    end
  end
  error("Tutorial guide missing")
end

local function lesson(title)
  check(guide():find(title, 1, true), "Wrong lesson; expected " .. title .. "\n" .. guide())
end

local function next_lesson()
  vim.cmd("LearnVim next")
  settle()
end

run = coroutine.create(function()
  local ok, err = xpcall(function()
    if vim.env.FORGE_TUTORIAL_SOURCE then
      package.loaded["forge.tutorial"] = dofile(vim.env.FORGE_TUTORIAL_SOURCE)
      require("forge.tutorial").setup()
    end
    vim.o.clipboard = ""
    vim.cmd("tabnew")
    vim.cmd("tabprevious")
    local cwd, original_tab, original_buf =
      vim.fn.getcwd(), vim.api.nvim_get_current_tabpage(), vim.api.nvim_get_current_buf()
    vim.api.nvim_buf_set_lines(original_buf, 0, -1, false, { "unsaved original work" })
    vim.cmd("LearnVim restart")
    settle()
    local practice = vim.api.nvim_get_current_buf()
    local directory = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(practice), ":h")
    local state_file = vim.fn.stdpath("state") .. "/forge-learn-vim.json"
    local function progress()
      return vim.json.decode(table.concat(vim.fn.readfile(state_file), "\n"))
    end
    lesson("Your safe playground")
    next_lesson()
    lesson("Type, then stop typing")
    next_lesson()
    lesson("Type, then stop typing")
    check(guide():find("Not quite yet", 1, true), "Premature completion should reveal a hint")
    keys("ihello<Esc>")
    next_lesson()
    lesson("Move without changing text")
    check(progress().completed.insert, "Successful exercise was not saved")
    keys("lllljj")
    next_lesson()
    lesson("Jump by words")
    keys("ww")
    next_lesson()
    lesson("Add to the end of a line")
    keys("A.<Esc>")
    next_lesson()
    lesson("Replace a word in one move")
    keys("ciwcoffee<Esc>")
    next_lesson()
    lesson("Delete, undo, redo")
    keys("dd")
    check(guide():find("[x] Delete with dd", 1, true), "Deletion was not observed")
    keys("u")
    check(
      guide():find("[x] Undo with u", 1, true),
      "Undo was not observed: " .. vim.inspect(vim.api.nvim_buf_get_lines(0, 0, -1, false)) .. "\n" .. guide()
    )
    keys("<C-r>")
    next_lesson()
    lesson("Copy and paste a line")
    keys("yyp")
    next_lesson()
    lesson("Select text, then change it")
    keys("vlllchot<Esc>")
    next_lesson()
    lesson("Find a word in this file")
    keys("/coffee<CR>")
    next_lesson()
    lesson("Save a file")
    keys("A!<Esc>")
    next_lesson()
    lesson("Save a file")
    keys("<Space>w")
    next_lesson()
    lesson("Move between panes")
    keys("<C-h>")
    keys("<C-l>")
    next_lesson()
    lesson("Find and open another file")
    keys("<Space>ff")
    keys("welcome")
    keys("<CR>")
    check(vim.api.nvim_buf_get_name(0) == directory .. "/welcome.txt", "File finder did not open welcome.txt")
    check(vim.fn.maparg("<CR>", "n", false, true).buffer == 1, "Opened practice file lacks tutorial controls")
    next_lesson()
    lesson("Open a terminal and come back")
    keys("<Space>tf")
    settle()
    -- The actual floating terminal must open; use its mapping to close it.
    check(vim.bo.buftype == "terminal", "Floating terminal did not open")
    keys("<Esc><Esc>")
    keys("<Space>tf")
    next_lesson()
    lesson("Ready for your first real file")
    check(vim.tbl_count(progress().completed) == 13, "Not all 13 exercises completed")
    next_lesson()
    check(vim.api.nvim_get_current_tabpage() == original_tab, "Original tab was not restored")
    check(
      vim.deep_equal(vim.api.nvim_buf_get_lines(original_buf, 0, -1, false), { "unsaved original work" }),
      "Original edits changed"
    )
    check(vim.bo[original_buf].modified, "Original modified flag changed")
    check(vim.fn.getcwd() == cwd, "Original working directory changed")
    check(vim.fn.isdirectory(directory) == 0, "Practice directory was not removed")
    vim.cmd("LearnVim")
    lesson("Ready for your first real file")
    vim.cmd("LearnVim restart")
    next_lesson()
    keys("iwrong<Esc>")
    vim.cmd("LearnVim reset")
    check(vim.deep_equal(vim.api.nvim_buf_get_lines(0, 0, -1, false), { "" }), "Retry did not restore the exercise")
    vim.cmd("LearnVim skip")
    check(not progress().completed.insert, "Skipped exercise was marked completed")
    vim.cmd("LearnVim close")
    vim.cmd("LearnVim")
    lesson("Move without changing text")
    vim.cmd("LearnVim back")
    lesson("Type, then stop typing")
    vim.cmd("LearnVim close")
    vim.fn.writefile({ "invalid JSON" }, state_file)
    vim.cmd("LearnVim")
    lesson("Your safe playground")
    vim.cmd("LearnVim close")
    check(vim.v.errmsg == "", "Editor error: " .. vim.v.errmsg)
    print(
      "PASS all 13 tutorial exercises, save validation, retry, skip, resume, corrupt progress and workspace isolation"
    )
  end, debug.traceback)
  if not ok then
    io.stderr:write(err .. "\n")
    vim.cmd("cquit 1")
  else
    vim.cmd("qa!")
  end
end)
vim.defer_fn(resume, 200)
