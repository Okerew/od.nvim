local M = {}
local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local conf = require("telescope.config").values
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local parse_debug_output = require("od.parsers.output_parser").parse_debug_output
local analyze_suspicious_patterns = require("od.parsers.variable_analyzer").analyze_suspicious_patterns
local split_into_chunks = require("od.parsers.test_parser").split_into_chunks
local chunks_to_items = require("od.parsers.test_parser").chunks_to_items

local ts = vim.treesitter

M.last_errors = {}
M.last_warnings = {}
M.suspicious_variables = {}
M.last_output = ""
M.breakpoints = {}
M.sign_id_counter = 1

M.config = {
    debuggers = {
        c = {
            cmd = "gcc",
            args = { "-g", "-Wall", "-Wextra", "-fsanitize=address", "-fsanitize=undefined", "-o", "debug_program" },
            run_args = {
                "valgrind",
                "--tool=memcheck",
                "--leak-check=full",
                "--show-leak-kinds=all",
                "--track-origins=yes",
                "./debug_program"
            },
            cmake_configure_args = { "cmake", "-DCMAKE_BUILD_TYPE=Debug", "-DCMAKE_EXPORT_COMPILE_COMMANDS=ON", "." },
            cmake_build_args = { "cmake", "--build", ".", "--config", "Debug" },
            cmake_install_args = { "cmake", "--build", ".", "--target", "install" },
            test_args = { "ctest", "--verbose", "--output-on-failure" },
            -- GDB support
            gdb_args = { "gdb", "--batch", "--ex", "run", "--ex", "bt", "--args" },
            gdb_remote_args = { "gdb", "--batch", "-ex", "target remote :1234", "-ex", "continue", "-ex", "bt" },
            -- LLDB support
            lldb_args = { "lldb", "--batch", "-o", "run", "-o", "bt", "--" },
            lldb_remote_args = { "lldb", "-o", "gdb-remote :1234", "-o", "continue", "-o", "bt" }
        },
        cpp = {
            cmd = "g++",
            args = { "-g", "-Wall", "-Wextra", "-fsanitize=address", "-fsanitize=undefined", "-o", "debug_program" },
            run_args = {
                "valgrind",
                "--tool=memcheck",
                "--leak-check=full",
                "--show-leak-kinds=all",
                "--track-origins=yes",
                "./debug_program"
            },
            cmake_configure_args = { "cmake", "-DCMAKE_BUILD_TYPE=Debug", "-DCMAKE_EXPORT_COMPILE_COMMANDS=ON", "." },
            cmake_build_args = { "cmake", "--build", ".", "--config", "Debug" },
            cmake_install_args = { "cmake", "--build", ".", "--target", "install" },
            test_args = { "ctest", "--verbose", "--output-on-failure" },
            -- GDB support
            gdb_args = { "gdb", "--batch", "--ex", "run", "--ex", "bt", "--args" },
            gdb_remote_args = { "gdb", "--batch", "-ex", "target remote :1234", "-ex", "continue", "-ex", "bt" },
            -- LLDB support
            lldb_args = { "lldb", "--batch", "-o", "run", "-o", "bt", "--" },
            lldb_remote_args = { "lldb", "-o", "gdb-remote :1234", "-o", "continue", "-o", "bt" }
        },
        go = {
            cmd = "go",
            args = { "run" },
            build_args = { "go", "build", "-race", "-gcflags=all=-N -l" },
            test_args = { "go", "test", "-v", "-race" }
        },
        rust = {
            cmd = "cargo",
            args = { "check", "--color=never", "--message-format=short" },
            run_args = { "cargo", "run" },
            test_args = { "cargo", "test", "--color=never" },
            clippy_args = { "cargo", "clippy", "--color=never", "--message-format=short" },
            -- GDB support
            gdb_args = { "gdb", "--batch", "--ex", "run", "--ex", "bt", "--args" },
            gdb_remote_args = { "gdb", "--batch", "-ex", "target remote :1234", "-ex", "continue", "-ex", "bt" },
            -- LLDB support
            lldb_args = { "lldb", "--batch", "-o", "run", "-o", "bt", "--" },
            lldb_remote_args = { "lldb", "-o", "gdb-remote :1234", "-o", "continue", "-o", "bt" }
        },
        lua = { test_args = { "busted", "--verbose" } },
        python = { test_args = { "python", "-m", "unittest", "-v" } },
        javascript = { test_args = { "npm", "test" } }
    },
    executable_patterns = {
        c = { "*.c" },
        cpp = { "*.cpp", "*.cxx", "*.cc" },
        go = { "main.go", "*.go" },
        rust = { "Cargo.toml", "src/main.rs", "src/lib.rs" }
    }
}

local function place_suspicious_signs(suspicious_items)
    -- Clear previous suspicious signs
    vim.fn.sign_unplace("od_suspicious")

    for _, item in ipairs(suspicious_items) do
        if item.filename and item.lnum and tonumber(item.lnum) then
            local bufnr = vim.fn.bufnr(item.filename)
            if bufnr ~= -1 and vim.api.nvim_buf_is_loaded(bufnr) then
                local sign_name = "ODSuspiciousValue"
                vim.fn.sign_place(
                    0,
                    "od_suspicious",
                    sign_name,
                    item.filename,
                    {
                        lnum = tonumber(item.lnum),
                        priority = 15
                    }
                )
            end
        end
    end
end

function M.add_custom_debugger(lang, config)
    M.config.debuggers[lang] = config
end

local function find_source_files(filetype)
    local cwd = vim.fn.getcwd()
    local files = {}

    if filetype == "go" then
        -- For Go, we want to run the current file or main.go
        local current_file = vim.fn.expand("%")
        if current_file:match("%.go$") then
            return { current_file }
        end
        -- Look for main.go
        local main_go = cwd .. "/main.go"
        if vim.fn.filereadable(main_go) == 1 then
            return { "main.go" }
        end
        -- Look for any .go file
        local handle = vim.loop.fs_scandir(cwd)
        if handle then
            while true do
                local name, type = vim.loop.fs_scandir_next(handle)
                if not name then
                    break
                end
                if name:match("%.go$") then
                    table.insert(files, name)
                end
            end
        end
        return files
    elseif filetype == "rust" then
        -- For Rust, check if we're in a Cargo project
        local cargo_toml = cwd .. "/Cargo.toml"
        if vim.fn.filereadable(cargo_toml) == 1 then
            return { "Cargo.toml" }
        end
        -- Look for Rust source files
        local src_dir = cwd .. "/src"
        if vim.fn.isdirectory(src_dir) == 1 then
            local handle = vim.loop.fs_scandir(src_dir)
            if handle then
                while true do
                    local name, type = vim.loop.fs_scandir_next(handle)
                    if not name then
                        break
                    end
                    if name:match("%.rs$") then
                        table.insert(files, "src/" .. name)
                    end
                end
            end
        end
        -- Look for .rs files in current directory
        local handle = vim.loop.fs_scandir(cwd)
        if handle then
            while true do
                local name, type = vim.loop.fs_scandir_next(handle)
                if not name then
                    break
                end
                if name:match("%.rs$") then
                    table.insert(files, name)
                end
            end
        end
        return files
    end

    -- For C/C++, find source files
    local extensions = {}
    if filetype == "c" then
        extensions = { "%.c$" }
    elseif filetype == "cpp" then
        extensions = { "%.cpp$", "%.cxx$", "%.cc$", "%.C$" }
    end
    local handle = vim.loop.fs_scandir(cwd)
    if handle then
        while true do
            local name, type = vim.loop.fs_scandir_next(handle)
            if not name then
                break
            end
            for _, ext in ipairs(extensions) do
                if name:match(ext) then
                    table.insert(files, name)
                    break
                end
            end
        end
    end
    return files
end

local gourinte_counts = {}
local thread_counts = {}

local function create_picker(items, title)
    if #items == 0 then
        vim.notify("No " .. title:lower() .. " found", vim.log.levels.INFO)
        return
    end
    -- Clear previous telescope signs
    local sign_group = "od_telescope_items"
    vim.fn.sign_unplace(sign_group)
    -- Get current line number
    local current_line = vim.api.nvim_win_get_cursor(0)[1]
    -- Place signs on all lines that have telescope items (except current line and first line)
    for _, item in ipairs(items) do
        if item.filename and item.lnum and item.lnum ~= current_line and item.lnum ~= 1 then
            -- Check if buffer is loaded/opened before placing signs
            local bufnr = vim.fn.bufnr(item.filename)
            if bufnr ~= -1 and vim.api.nvim_buf_is_loaded(bufnr) then
                vim.fn.sign_place(
                    0,
                    sign_group,
                    "ODTelescopeItem",
                    item.filename,
                    {
                        lnum = item.lnum,
                        priority = 10
                    }
                )
            end
        end
    end
    pickers.new(
        {},
        {
            prompt_title = title,
            finder = finders.new_table(
                {
                    results = items,
                    entry_maker = function(entry)
                        return {
                            value = entry,
                            display = entry.display,
                            ordinal = entry.display,
                            filename = entry.filename,
                            lnum = entry.lnum,
                            col = 1
                        }
                    end
                }
            ),
            sorter = conf.generic_sorter({}),
            attach_mappings = function(prompt_bufnr)
                actions.select_default:replace(
                    function()
                        actions.close(prompt_bufnr)
                        local selection = action_state.get_selected_entry()
                        if selection then
                            -- Check if file exists and get the correct buffer
                            local bufnr = vim.fn.bufnr(selection.filename)
                            if bufnr == -1 then
                                -- Try to find the buffer by basename if full path didn't work
                                local basename = vim.fn.fnamemodify(selection.filename, ":t")
                                for _, buf in ipairs(vim.api.nvim_list_bufs()) do
                                    local buf_name = vim.api.nvim_buf_get_name(buf)
                                    if vim.fn.fnamemodify(buf_name, ":t") == basename then
                                        bufnr = buf
                                        break
                                    end
                                end
                            end

                            if bufnr ~= -1 then
                                -- Switch to existing buffer
                                vim.api.nvim_set_current_buf(bufnr)
                            else
                                -- Only create new buffer if file doesn't exist in any loaded buffer
                                vim.cmd("edit " .. vim.fn.fnameescape(selection.filename))
                            end

                            -- Validate line number before setting cursor
                            local line_count = vim.api.nvim_buf_line_count(0)
                            local target_line = math.min(selection.lnum, line_count)
                            vim.api.nvim_win_set_cursor(0, { target_line, 0 })
                            vim.cmd("normal! zz")
                            if selection.display:lower():find("goroutine") then
                                -- Check for thread
                                gourinte_counts[selection.display] = (gourinte_counts[selection.display] or 0) + 1
                                local count = gourinte_counts[selection.display]
                                local text_to_copy = "goroutine " .. count
                                vim.notify("Copied to clipboard: " .. text_to_copy, vim.log.levels.INFO)
                                vim.fn.setreg("+", text_to_copy)
                            elseif selection.display:lower():find("thread") then
                                thread_counts[selection.display] = (thread_counts[selection.display] or 0) + 1
                                local count = thread_counts[selection.display]
                                local text_to_copy = "thread " .. count
                                vim.notify("Copied to clipboard: " .. text_to_copy, vim.log.levels.INFO)
                                vim.fn.setreg("+", text_to_copy)
                            end
                        end
                    end
                )
                return true
            end
        }
    ):find()
end

local function find_cmake_project_root()
    local cwd = vim.fn.getcwd()
    local current_dir = cwd

    -- Look for CMakeLists.txt starting from current directory and going up
    while current_dir ~= "/" do
        local cmake_file = current_dir .. "/CMakeLists.txt"
        if vim.fn.filereadable(cmake_file) == 1 then
            return current_dir
        end
        current_dir = vim.fn.fnamemodify(current_dir, ":h")
    end

    -- Check current directory as fallback
    local cmake_file = cwd .. "/CMakeLists.txt"
    if vim.fn.filereadable(cmake_file) == 1 then
        return cwd
    end

    return nil
end

local function run_debugger(source_files, filetype, callback)
    local debugger_config = M.config.debuggers[filetype]
    if not debugger_config then
        return
    end

    -- Check for CMake project for C/C++ files
    if filetype == "c" or filetype == "cpp" then
        local project_root = find_cmake_project_root()
        if project_root and debugger_config.run_args then
            local run_cmd = debugger_config.run_args[1]
            local run_args = vim.list_slice(debugger_config.run_args, 2)
            local runtime_output = ""
            local runtime_stderr = ""
            vim.fn.jobstart(
                vim.list_extend({ run_cmd }, run_args),
                {
                    stdout_buffered = true,
                    stderr_buffered = true,
                    on_stdout = function(_, data)
                        if data then
                            runtime_output = runtime_output .. table.concat(data, "\n")
                        end
                    end,
                    on_stderr = function(_, data)
                        if data then
                            runtime_stderr = runtime_stderr .. table.concat(data, "\n")
                        end
                    end,
                    on_exit = function(_, runtime_code)
                        local runtime_full_output = runtime_output .. "\n" .. runtime_stderr
                        callback(runtime_full_output, runtime_code)
                    end
                }
            )
            return
        end
    end

    if debugger_config.build_command then
        local argv = debugger_config.build_command(
            source_files, filetype)
        local doutput = ""
        local dstderr = ""
        vim.fn.jobstart(argv, {
            stdout_buffered = true,
            stderr_buffered = true,
            on_stdout = function(_, data)
                if data then
                    doutput = doutput .. table.concat(data, "\n")
                end
            end,
            on_stderr = function(_, data)
                if data then
                    dstderr = dstderr .. table.concat(data, "\n")
                end
            end,
            on_exit = function(_, code)
                local dfull_output = doutput .. "\n" .. dstderr
                if debugger_config.process_output then
                    dfull_output = debugger_config.process_output(
                        dfull_output, code)
                end
                callback(dfull_output, code)
            end,
        })
        return
    end

    if debugger_config.cmd and debugger_config.args then
        local cmd = debugger_config.cmd
        local args = vim.deepcopy(debugger_config.args)

        if filetype == "go" then
            table.insert(args, source_files[1])
        elseif filetype ~= "rust" then
            for _, src_file in ipairs(source_files) do
                table.insert(args, src_file)
            end
        end

        local output = ""
        local stderr = ""
        local start_time = vim.fn.reltime()

        vim.fn.jobstart(
            vim.list_extend({ cmd }, args),
            {
                stdout_buffered = true,
                stderr_buffered = true,
                on_stdout = function(_, data)
                    if data then
                        output = output .. table.concat(data, "\n")
                    end
                end,
                on_stderr = function(_, data)
                    if data then
                        stderr = stderr .. table.concat(data, "\n")
                    end
                end,
                on_exit = function(_, code)
                    local elapsed_time = vim.fn.reltimefloat(vim.fn.reltime(start_time))
                    local full_output = output .. "\n" .. stderr

                    if debugger_config.process_output then
                        full_output = debugger_config.process_output(
                            full_output, code)
                    end

                    if debugger_config.on_output then
                        debugger_config.on_output(full_output, code)
                        return
                    end

                    -- Rust build time notification
                    if filetype == "rust" then
                        local threshold = vim.g.rust_build_time_threshold or 60.0
                        if elapsed_time > threshold then
                            vim.notify(
                                string.format(
                                    "Rust build took %.2f seconds (exceeded threshold of %.2fs)",
                                    elapsed_time,
                                    threshold
                                ),
                                vim.log.levels.WARN
                            )
                        end
                    end

                    -- Handle C/C++ runtime execution
                    if (filetype == "c" or filetype == "cpp") and code == 0 and debugger_config.run_args then
                        local run_cmd = debugger_config.run_args[1]
                        local run_args = vim.list_slice(debugger_config.run_args, 2)
                        local runtime_output = ""
                        local runtime_stderr = ""
                        vim.fn.jobstart(
                            vim.list_extend({ run_cmd }, run_args),
                            {
                                stdout_buffered = true,
                                stderr_buffered = true,
                                on_stdout = function(_, data)
                                    if data then
                                        runtime_output = runtime_output .. table.concat(data, "\n")
                                    end
                                end,
                                on_stderr = function(_, data)
                                    if data then
                                        runtime_stderr = runtime_stderr .. table.concat(data, "\n")
                                    end
                                end,
                                on_exit = function(_, runtime_code)
                                    local runtime_full_output = runtime_output .. "\n" .. runtime_stderr
                                    callback(runtime_full_output, runtime_code)
                                end
                            }
                        )
                        return
                    end

                    -- Handle Rust runtime execution
                    if filetype == "rust" and code == 0 and debugger_config.run_args then
                        local run_cmd = debugger_config.run_args[1]
                        local run_args = vim.list_slice(debugger_config.run_args, 2)
                        local runtime_output = ""
                        local runtime_stderr = ""
                        vim.fn.jobstart(
                            vim.list_extend({ run_cmd }, run_args),
                            {
                                stdout_buffered = true,
                                stderr_buffered = true,
                                on_stdout = function(_, data)
                                    if data then
                                        runtime_output = runtime_output .. table.concat(data, "\n")
                                    end
                                end,
                                on_stderr = function(_, data)
                                    if data then
                                        runtime_stderr = runtime_stderr .. table.concat(data, "\n")
                                    end
                                end,
                                on_exit = function(_, runtime_code)
                                    local runtime_full_output = runtime_output .. "\n" .. runtime_stderr
                                    callback(runtime_full_output, runtime_code)
                                end
                            }
                        )
                        return
                    end

                    -- Default callback
                    callback(full_output, code)
                end
            }
        )
    end
end

function M.debug()
    local filetype = vim.bo.filetype
    local source_files = find_source_files(filetype)
    if #source_files == 0 then
        vim.notify("No source files found", vim.log.levels.ERROR)
        return
    end
    run_debugger(
        source_files,
        filetype,
        function(output, code)
            M.last_output = output
            local errors, warnings = parse_debug_output(output, filetype)
            M.last_errors = errors
            M.last_warnings = warnings
            M.suspicious_variables = analyze_suspicious_patterns(output)
            place_suspicious_signs(M.suspicious_variables)

            if #M.suspicious_variables > 0 then
                vim.notify(string.format("Found %d suspicious patterns", #M.suspicious_variables), vim.log.levels.WARN)
            end
            vim.notify(string.format("Debug done. Errors: %d, Warnings: %d", #errors, #warnings))
            if #errors > 0 then
                create_picker(errors, "Debug Errors")
            elseif #warnings > 0 then
                create_picker(warnings, "Debug Warnings")
            else
                vim.notify("No errors or warnings found")
            end
        end
    )
end

function M.rust_clippy()
    local filetype = vim.bo.filetype
    if filetype ~= "rust" then
        vim.notify("Clippy is only available for Rust projects", vim.log.levels.ERROR)
        return
    end

    local debugger_config = M.config.debuggers.rust
    if not debugger_config.clippy_args then
        vim.notify("Clippy not configured", vim.log.levels.ERROR)
        return
    end

    local cmd = debugger_config.cmd
    local args = vim.deepcopy(debugger_config.clippy_args)

    vim.notify("Running Clippy: " .. cmd .. " " .. table.concat(args, " "))
    local output = ""
    local stderr = ""

    vim.fn.jobstart(
        vim.list_extend({ cmd }, args),
        {
            stdout_buffered = true,
            stderr_buffered = true,
            on_stdout = function(_, data)
                if data then
                    output = output .. table.concat(data, "\n")
                end
            end,
            on_stderr = function(_, data)
                if data then
                    stderr = stderr .. table.concat(data, "\n")
                end
            end,
            on_exit = function(_, code)
                local full_output = output .. "\n" .. stderr
                M.last_output = full_output
                local errors, warnings = parse_debug_output(full_output, "rust")
                M.last_errors = errors
                M.last_warnings = warnings
                M.suspicious_variables = analyze_suspicious_patterns(output)
                place_suspicious_signs(M.suspicious_variables)

                if #M.suspicious_variables > 0 then
                    vim.notify(
                        string.format("Found %d suspicious patterns", #M.suspicious_variables),
                        vim.log.levels.WARN
                    )
                end
                vim.notify(string.format("Clippy done. Errors: %d, Warnings: %d", #errors, #warnings))
                if #warnings > 0 then
                    create_picker(warnings, "Clippy Warnings")
                elseif #errors > 0 then
                    create_picker(errors, "Clippy Errors")
                else
                    vim.notify("No clippy issues found")
                end
            end
        }
    )
end

function M.show_errors()
    create_picker(M.last_errors, "Debug Errors")
end

function M.show_warnings()
    create_picker(M.last_warnings, "Debug Warnings")
end

function M.show_output()
    if M.last_output == "" then
        vim.notify("No debug output", vim.log.levels.INFO)
        return
    end
    local lines = {}
    for line in M.last_output:gmatch("[^\n]+") do
        table.insert(lines, line)
    end
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.api.nvim_buf_set_option(buf, "filetype", "text")
    vim.api.nvim_buf_set_option(buf, "buftype", "nofile")
    vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
    vim.cmd("split")
    vim.api.nvim_win_set_buf(0, buf)
    vim.cmd("resize 15") -- Make the output window smaller
end

function M.go_build()
    local filetype = vim.bo.filetype
    if filetype ~= "go" then
        vim.notify("Go build is only available for Go projects", vim.log.levels.ERROR)
        return
    end

    local debugger_config = M.config.debuggers.go
    if not debugger_config.build_args then
        vim.notify("Go build not configured", vim.log.levels.ERROR)
        return
    end

    local cmd = debugger_config.build_args[1]
    local args = vim.list_slice(debugger_config.build_args, 2)

    vim.notify("Building Go project: " .. cmd .. " " .. table.concat(args, " "))
    local output = ""
    local stderr = ""

    vim.fn.jobstart(
        vim.list_extend({ cmd }, args),
        {
            stdout_buffered = true,
            stderr_buffered = true,
            on_stdout = function(_, data)
                if data then
                    output = output .. table.concat(data, "\n")
                end
            end,
            on_stderr = function(_, data)
                if data then
                    stderr = stderr .. table.concat(data, "\n")
                end
            end,
            on_exit = function(_, code)
                local full_output = output .. "\n" .. stderr
                M.last_output = full_output
                local errors, warnings = parse_debug_output(full_output, "go")
                M.last_errors = errors
                M.last_warnings = warnings
                M.suspicious_variables = analyze_suspicious_patterns(output)
                place_suspicious_signs(M.suspicious_variables)

                if #M.suspicious_variables > 0 then
                    vim.notify(
                        string.format("Found %d suspicious patterns", #M.suspicious_variables),
                        vim.log.levels.WARN
                    )
                end
                vim.notify(
                    string.format("Go build done. Errors: %d, Warnings: %d, Exit Code: %d", #errors, #warnings, code)
                )
                if #errors > 0 then
                    create_picker(errors, "Build Errors")
                elseif #warnings > 0 then
                    create_picker(warnings, "Build Warnings")
                else
                    vim.notify("Build successful!")
                end
            end
        }
    )
end

local function create_test_picker(items, title)
    if #items == 0 then
        vim.notify(
            "No " .. title:lower() .. " found",
            vim.log.levels.INFO
        )
        return
    end

    -- Clear previous telescope signs
    local sign_group = "od_telescope_items"
    vim.fn.sign_unplace(sign_group)

    -- Get current line number
    local current_line = vim.api.nvim_win_get_cursor(0)[1]

    -- Place signs on all lines that have telescope items
    -- (except current line and first line)
    for _, item in ipairs(items) do
        if item.filename
            and item.lnum
            and item.lnum ~= current_line
            and item.lnum ~= 1
        then
            -- Check if buffer is loaded/opened before placing signs
            local bufnr = vim.fn.bufnr(item.filename)
            if bufnr ~= -1
                and vim.api.nvim_buf_is_loaded(bufnr)
            then
                vim.fn.sign_place(
                    0,
                    sign_group,
                    "ODTelescopeItem",
                    item.filename,
                    { lnum = item.lnum, priority = 10 }
                )
            end
        end
    end

    local ok, _ = pcall(require, "telescope")
    if not ok then
        vim.notify("Telescope not found", vim.log.levels.ERROR)
        return
    end

    local previewers = require("telescope.previewers")
    local previewer = previewers.new_buffer_previewer({
        title = "Traceback",
        define_preview = function(self, entry)
            local lines = vim.split(
                entry.value.log or "(no traceback)",
                "\n"
            )
            vim.api.nvim_buf_set_lines(
                self.state.bufnr, 0, -1, false, lines
            )
            vim.bo[self.state.bufnr].filetype = "text"
        end
    })

    pickers.new({}, {
        prompt_title    = title,
        finder          = finders.new_table({
            results = items,
            entry_maker = function(item)
                return {
                    value   = item,
                    display = item.display,
                    ordinal = item.display,
                    path    = item.filename,
                    lnum    = item.lnum,
                    col     = item.col
                }
            end
        }),
        sorter          = conf.generic_sorter({}),
        previewer       = previewer,
        attach_mappings = function(buf, _)
            actions.select_default:replace(function()
                actions.close(buf)
                local sel = action_state.get_selected_entry()
                if sel and sel.path then
                    vim.cmd("edit " .. sel.path)
                    vim.api.nvim_win_set_cursor(
                        0,
                        { sel.lnum or 1, (sel.col or 1) - 1 }
                    )
                end
            end)
            return true
        end
    }):find()
end

function M.show_test_errors()
    create_test_picker(M.last_errors, "Test Errors")
end

function M.show_test_warnings()
    create_test_picker(M.last_warnings, "Test Warnings")
end

-- This function exists so go, rust, cmake test logic works with the test picker
local function attach_log(items, full_output)
    for _, item in ipairs(items) do
        if not item.log then
            item.log = full_output
        end
    end
end

local function get_current_function()
    local bufnr = vim.api.nvim_get_current_buf()
    local cursor = vim.api.nvim_win_get_cursor(0)
    local row, col = cursor[1] - 1, cursor[2] -- Convert to 0-based indexing

    -- Get the parser for current buffer
    local parser = ts.get_parser(bufnr)
    if not parser then
        return nil
    end

    local tree = parser:parse()[1]
    local root = tree:root()

    -- Get the node at cursor position
    local node = root:descendant_for_range(row, col, row, col)

    -- Traverse up the tree to find a function node
    while node do
        local node_type = node:type()

        -- Check for function-like nodes based on language
        if
            node_type:match("function") or node_type:match("method") or node_type == "func_declaration" or -- Go
            node_type == "function_declaration" or                                                         -- JavaScript/TypeScript
            node_type == "function_definition" or                                                          -- Python/C/C++
            node_type == "function_item" or                                                                -- Rust
            node_type == "method_definition" or                                                            -- C++/Ruby
            node_type == "arrow_function" or                                                               -- JavaScript
            node_type == "lambda_expression"
        then                                                                                               -- Various languages
            -- Try to extract function name
            local name_node = nil

            -- Different languages have different patterns for function names
            for child in node:iter_children() do
                local child_type = child:type()
                if child_type == "identifier" or child_type == "name" or child_type == "function_name" then
                    name_node = child
                    break
                end
            end

            -- If we didn't find a direct identifier, look deeper
            if not name_node then
                for child in node:iter_children() do
                    for grandchild in child:iter_children() do
                        if grandchild:type() == "identifier" then
                            name_node = grandchild
                            break
                        end
                    end
                    if name_node then
                        break
                    end
                end
            end

            if name_node then
                local name = ts.get_node_text(name_node, bufnr)
                return name
            end
        end

        node = node:parent()
    end

    return nil
end

-- We keep the old logic for go, cargo and cmake tests as I find testing
-- with them easier that way.
M.test_handlers = {}

local function run_test(filetype, handler)
    local debugger_config = M.config.debuggers[filetype]
    if not debugger_config or not debugger_config.test_args then
        vim.notify("Test not configured for " .. filetype,
            vim.log.levels.ERROR)
        return
    end

    local cmd = debugger_config.test_args[1]
    if handler.exec_fallback then
        cmd = handler.exec_fallback(cmd)
        if not cmd then return end
    end

    local args = vim.list_slice(debugger_config.test_args, 2)
    local current_func = get_current_function()
    handler.args_fn(args, current_func)

    vim.notify("Command: " .. cmd .. " " .. table.concat(args, " "))
    local output = ""
    local stderr = ""

    local job_cmd = type(cmd) == "string" and vim.split(cmd, "%s+")
        or { cmd }
    vim.fn.jobstart(vim.list_extend(job_cmd, args), {
        stdout_buffered = true,
        stderr_buffered = true,
        on_stdout = function(_, data)
            if data then
                output = output ..
                    table.concat(data, "\n")
            end
        end,
        on_stderr = function(_, data)
            if data then
                stderr = stderr ..
                    table.concat(data, "\n")
            end
        end,
        on_exit = function(_, code)
            local full_output = output .. "\n" .. stderr
            M.last_output = full_output
            local errors, warnings = handler.parse_fn(
                full_output)
            M.last_errors = errors
            M.last_warnings = warnings
            M.suspicious_variables =
                analyze_suspicious_patterns(output)
            place_suspicious_signs(M.suspicious_variables)
            if #M.suspicious_variables > 0 then
                vim.notify(string.format(
                        "Found %d suspicious patterns",
                        #M.suspicious_variables),
                    vim.log.levels.WARN)
            end
            local err_count = #errors
            local warn_count = #warnings
            local title = handler.title or "Test"
            vim.notify(string.format(
                "%s done. Errors: %d, Warnings: %d",
                title, err_count, warn_count))
            if err_count > 0 then
                if handler.attach_log then
                    attach_log(errors, full_output)
                end
                create_test_picker(
                    errors, title .. " Errors")
            elseif warn_count > 0 then
                if handler.attach_log then
                    attach_log(warnings, full_output)
                end
                create_test_picker(
                    warnings, title .. " Warnings")
            else
                vim.notify("All tests passed!")
            end
        end,
    })
end

function M.add_test_handler(lang, handler)
    M.test_handlers[lang] = handler
    -- javascript -> typescript fallback
    if lang == "javascript" then
        M.test_handlers.typescript = handler
    end
end

M.test_handlers.go = {
    args_fn = function(args, current_func)
        if current_func and current_func:match("^Test") then
            table.insert(args, "-run")
            table.insert(args, "^" .. current_func .. "$")
            vim.notify("Running specific Go test: " .. current_func)
        else
            vim.notify("Running all Go tests")
        end
    end,
    parse_fn = function(full_output)
        local test_errors = {}
        local test_warnings = {}
        for line in full_output:gmatch("[^\n]+") do
            if line:match("FAIL") and line:match("%.go:%d+") then
                local file, line_num = line:match(
                    "([^%s]+%.go):(%d+)")
                if file and line_num then
                    table.insert(test_errors, {
                        filename = file,
                        lnum = tonumber(line_num),
                        text = line,
                        display = string.format(
                            "TEST-FAIL: %s:%s: %s",
                            vim.fn.fnamemodify(
                                file, ":t"),
                            line_num, line),
                    })
                else
                    table.insert(test_errors, {
                        filename = vim.fn.expand("%"),
                        lnum = 1,
                        text = line,
                        display = "TEST-FAIL: " .. line,
                    })
                end
            elseif line:match("--- FAIL:") then
                local test_name = line:match(
                    "--- FAIL: ([^%s]+)")
                table.insert(test_errors, {
                    filename = vim.fn.expand("%"),
                    lnum = 1,
                    text = line,
                    display = "TEST-FAILED: "
                        .. (test_name or line),
                })
            elseif line:match("WARNING: DATA RACE") then
                table.insert(test_errors, {
                    filename = vim.fn.expand("%"),
                    lnum = 1,
                    text = line,
                    display = "RACE-DETECTED: " .. line,
                })
            elseif line:match("testing: warning:") then
                table.insert(test_warnings, {
                    filename = vim.fn.expand("%"),
                    lnum = 1,
                    text = line,
                    display = "TEST-WARNING: " .. line,
                })
            end
        end
        local errors, warnings =
            parse_debug_output(full_output, "go")
        for _, err in ipairs(test_errors) do
            table.insert(errors, err)
        end
        for _, warn in ipairs(test_warnings) do
            table.insert(warnings, warn)
        end
        return errors, warnings
    end,
    attach_log = true,
    title = "Go tests",
}

function M.go_test()
    local ft = vim.bo.filetype
    if ft ~= "go" then
        vim.notify("Go tests are only available for Go projects",
            vim.log.levels.ERROR)
        return
    end
    run_test("go", M.test_handlers.go)
end

M.test_handlers.python = {
    exec_fallback = function(cmd)
        if vim.fn.executable(cmd) == 0 then
            if cmd == "python"
                and vim.fn.executable("python3") == 1 then
                return "python3"
            end
            vim.notify(
                "Python executable not found: " .. cmd,
                vim.log.levels.ERROR)
            return nil
        end
        return cmd
    end,
    args_fn = function(args, current_func)
        if current_func
            and current_func:match("^test_") then
            local current_file =
                vim.fn.expand("%:t:r")
            local class_name = nil
            local c_line = vim.fn.line(".")
            local lines = vim.api.nvim_buf_get_lines(
                0, 0, c_line, false)
            for i = #lines, 1, -1 do
                local line = lines[i]
                local cm = line:match(
                    "^class%s+([%w_]+)")
                if cm then
                    class_name = cm
                    break
                end
            end
            local test_selector
            if class_name then
                test_selector = current_file .. "."
                    .. class_name .. "."
                    .. current_func
            else
                test_selector = current_file .. "."
                    .. current_func
            end
            if vim.tbl_contains(args, "-m")
                and vim.tbl_contains(args, "pytest") then
                table.insert(args,
                    "::" .. test_selector)
            elseif vim.tbl_contains(args, "-m")
                and vim.tbl_contains(args,
                    "unittest") then
                table.insert(args, test_selector)
            else
                table.insert(args,
                    vim.fn.expand("%"))
                if class_name then
                    table.insert(args, class_name
                        .. "." .. current_func)
                end
            end
            vim.notify("Running specific Python test: "
                .. current_func)
        else
            vim.notify("Running all Python tests")
        end
    end,
    parse_fn = function(full_output)
        local chunks = split_into_chunks(
            full_output, "python")
        return chunks_to_items(
            chunks, "python", vim.fn.expand("%"))
    end,
    title = "Python tests",
}

function M.python_test()
    local ft = vim.bo.filetype
    if ft ~= "python" then
        vim.notify(
            "Python tests are only available for Python projects",
            vim.log.levels.ERROR)
        return
    end
    run_test("python", M.test_handlers.python)
end

M.test_handlers.javascript = {
    exec_fallback = function(cmd)
        if vim.fn.executable(cmd) == 0 then
            local fallbacks = {
                jest = { "npx", "yarn", "pnpm" },
                npm = { "yarn", "pnpm" },
                yarn = { "npm", "pnpm" },
                pnpm = { "npm", "yarn" },
                node = { "nodejs" },
                nodejs = { "node" },
            }
            if fallbacks[cmd] then
                for _, fb in ipairs(fallbacks[cmd]) do
                    if vim.fn.executable(fb) == 1 then
                        cmd = fb
                        break
                    end
                end
            end
            if vim.fn.executable(cmd) == 0 then
                vim.notify("JS/TS executable not found",
                    vim.log.levels.ERROR)
                return nil
            end
        end
        return cmd
    end,
    args_fn = function(args, current_func)
        if current_func and (current_func:match("^test")
                or current_func:match("^it")
                or current_func:match("^describe")) then
            table.insert(args, "--testNamePattern")
            table.insert(args, current_func)
            vim.notify(
                "Running specific JS/TS test: "
                .. current_func)
        else
            vim.notify("Running all JS/TS tests")
        end
    end,
    parse_fn = function(full_output)
        local lang = vim.bo.filetype:match("typescript")
            and "typescript" or "javascript"
        local chunks = split_into_chunks(full_output, lang)
        return chunks_to_items(
            chunks, lang, vim.fn.expand("%"))
    end,
    title = "JS/TS tests",
}

function M.js_test()
    local ft = vim.bo.filetype
    if ft ~= "javascript" and ft ~= "typescript"
        and ft ~= "javascriptreact"
        and ft ~= "typescriptreact" then
        vim.notify(
            "JS/TS tests are only available for JS/TS projects",
            vim.log.levels.ERROR)
        return
    end
    run_test("javascript", M.test_handlers.javascript)
end

M.test_handlers.lua = {
    exec_fallback = function(cmd)
        if vim.fn.executable(cmd) == 0 then
            local fbs = { "lua -l busted",
                "luarocks exec busted" }
            for _, fb in ipairs(fbs) do
                if vim.fn.executable(
                        fb:match("^%S+")) == 1 then
                    return fb
                end
            end
            vim.notify(
                "Busted not found. Please install Busted.",
                vim.log.levels.ERROR)
            return nil
        end
        return cmd
    end,
    args_fn = function(args, current_func)
        if current_func
            and (current_func:match("^test_")
                or current_func:match("^it")
                or current_func:match("^describe")) then
            table.insert(args, "--filter")
            table.insert(args, current_func)
            vim.notify(
                "Running specific Busted test: "
                .. current_func)
        else
            vim.notify("Running all Busted tests")
        end
    end,
    parse_fn = function(full_output)
        local chunks = split_into_chunks(
            full_output, "lua")
        return chunks_to_items(
            chunks, "lua", vim.fn.expand("%"))
    end,
    title = "Busted tests",
}

function M.busted_test()
    local ft = vim.bo.filetype
    if ft ~= "lua" then
        vim.notify(
            "Lua tests are only available for Lua projects",
            vim.log.levels.ERROR)
        return
    end
    run_test("lua", M.test_handlers.lua)
end

M.test_handlers.rust = {
    args_fn = function(args, current_func)
        if current_func
            and current_func:match("^test_") then
            table.insert(args, current_func)
            vim.notify(
                "Running specific Rust test: "
                .. current_func)
        else
            vim.notify("Running all Rust tests")
        end
    end,
    parse_fn = function(full_output)
        local test_errors = {}
        local test_warnings = {}
        for line in full_output:gmatch("[^\n]+") do
            if line:match("test .* %.%.%. FAILED") then
                local test_name = line:match(
                    "test ([^%.]+)")
                table.insert(test_errors, {
                    filename = vim.fn.expand("%"),
                    lnum = 1,
                    text = line,
                    display = "TEST-FAILED: "
                        .. (test_name or line),
                })
            elseif line:match("---- .* stdout ----") then
                local test_name = line:match(
                    "---- (.*) stdout ----")
                table.insert(test_errors, {
                    filename = vim.fn.expand("%"),
                    lnum = 1,
                    text = line,
                    display = "TEST-OUTPUT: "
                        .. (test_name or line),
                })
            elseif line:match(
                    "thread '.*' panicked at") then
                local panic_info = line:match(
                    "panicked at (.+)")
                local file, lnum = line:match(
                    "([^%s]+%.rs):(%d+):")
                if file and lnum then
                    table.insert(test_errors, {
                        filename = file,
                        lnum = tonumber(lnum),
                        text = line,
                        display = string.format(
                            "TEST-PANIC: %s:%s: %s",
                            vim.fn.fnamemodify(
                                file, ":t"),
                            lnum,
                            panic_info or line),
                    })
                else
                    table.insert(test_errors, {
                        filename = vim.fn.expand("%"),
                        lnum = 1,
                        text = line,
                        display = "TEST-PANIC: "
                            .. line,
                    })
                end
            elseif line:match("assertion failed")
                or line:match("assert_eq!")
                or line:match("assert!") then
                table.insert(test_errors, {
                    filename = vim.fn.expand("%"),
                    lnum = 1,
                    text = line,
                    display = "TEST-ASSERTION: " .. line,
                })
            elseif line:match("warning:") then
                local file, lnum = line:match(
                    "([^%s]+%.rs):(%d+):")
                if file and lnum then
                    table.insert(test_warnings, {
                        filename = file,
                        lnum = tonumber(lnum),
                        text = line,
                        display = string.format(
                            "WARNING: %s:%s: %s",
                            vim.fn.fnamemodify(
                                file, ":t"),
                            lnum, line),
                    })
                else
                    table.insert(test_warnings, {
                        filename = vim.fn.expand("%"),
                        lnum = 1,
                        text = line,
                        display = "TEST-WARNING: "
                            .. line,
                    })
                end
            end
        end
        local errors, warnings =
            parse_debug_output(full_output, "rust")
        for _, err in ipairs(test_errors) do
            table.insert(errors, err)
        end
        for _, warn in ipairs(test_warnings) do
            table.insert(warnings, warn)
        end
        return errors, warnings
    end,
    attach_log = true,
    title = "Rust tests",
}

function M.rust_test()
    local ft = vim.bo.filetype
    if ft ~= "rust" then
        vim.notify(
            "Rust tests are only available for Rust projects",
            vim.log.levels.ERROR)
        return
    end
    run_test("rust", M.test_handlers.rust)
end

M.test_handlers.c = {
    args_fn = function(args, current_func)
        if current_func
            and (current_func:match("^test_")
                or current_func:match("^TEST_")) then
            table.insert(args, "-R")
            table.insert(args, current_func)
            vim.notify(
                "Running specific CTest: " .. current_func)
        else
            vim.notify("Running all CTests")
        end
    end,
    parse_fn = function(full_output)
        local test_errors = {}
        local test_warnings = {}
        for line in full_output:gmatch("[^\n]+") do
            if line:match("%*%*%*Failed")
                or line:match("FAILED") then
                local test_name = line:match(
                    "Test%s+#%d+:%s+([^%s]+)")
                if test_name then
                    table.insert(test_errors, {
                        filename = vim.fn.expand("%"),
                        lnum = 1,
                        text = line,
                        display = "CTEST-FAIL: "
                            .. test_name,
                    })
                else
                    table.insert(test_errors, {
                        filename = vim.fn.expand("%"),
                        lnum = 1,
                        text = line,
                        display = "CTEST-FAIL: " .. line,
                    })
                end
            elseif line:match(
                    "Required regular expression not found") then
                table.insert(test_errors, {
                    filename = vim.fn.expand("%"),
                    lnum = 1,
                    text = line,
                    display = "CTEST-REGEX-FAIL: " .. line,
                })
            elseif line:match("Timeout") then
                table.insert(test_errors, {
                    filename = vim.fn.expand("%"),
                    lnum = 1,
                    text = line,
                    display = "CTEST-TIMEOUT: " .. line,
                })
            elseif line:match("Exception")
                or line:match("Segmentation fault") then
                table.insert(test_errors, {
                    filename = vim.fn.expand("%"),
                    lnum = 1,
                    text = line,
                    display = "CTEST-EXCEPTION: " .. line,
                })
            elseif line:match("Warning")
                or line:match("warning:") then
                table.insert(test_warnings, {
                    filename = vim.fn.expand("%"),
                    lnum = 1,
                    text = line,
                    display = "CTEST-WARNING: " .. line,
                })
            end
        end
        local errors, warnings =
            parse_debug_output(full_output, "c")
        for _, err in ipairs(test_errors) do
            table.insert(errors, err)
        end
        for _, warn in ipairs(test_warnings) do
            table.insert(warnings, warn)
        end
        return errors, warnings
    end,
    attach_log = true,
    title = "CTest",
}

function M.ctest()
    local ft = vim.bo.filetype
    if ft ~= "c" and ft ~= "cpp" then
        vim.notify(
            "CTest is only available for C/C++ projects",
            vim.log.levels.ERROR)
        return
    end
    run_test("c", M.test_handlers.c)
end

local function find_cmake_executables()
    local project_root = find_cmake_project_root()
    if not project_root then
        return {}
    end

    local executables = {}
    local build_dir = project_root .. "/build"

    -- Look for executables in build directory
    if vim.fn.isdirectory(build_dir) == 1 then
        local handle = vim.loop.fs_scandir(build_dir)
        if handle then
            while true do
                local name, type = vim.loop.fs_scandir_next(handle)
                if not name then
                    break
                end

                if type == "file" then
                    local file_path = build_dir .. "/" .. name
                    -- Check if file is executable (basic check)
                    if vim.fn.executable(file_path) == 1 and not name:match("%.") then
                        table.insert(executables, file_path)
                    end
                end
            end
        end
    end

    return executables
end

function M.cmake_configure()
    local filetype = vim.bo.filetype
    if filetype ~= "c" and filetype ~= "cpp" then
        vim.notify("CMake is only available for C/C++ projects", vim.log.levels.ERROR)
        return
    end

    local project_root = find_cmake_project_root()
    if not project_root then
        vim.notify("No CMakeLists.txt found in current directory or parent directories", vim.log.levels.ERROR)
        return
    end

    local debugger_config = M.config.debuggers[filetype]
    if not debugger_config.cmake_configure_args then
        vim.notify("CMake configure not configured", vim.log.levels.ERROR)
        return
    end

    -- Change to project root
    local original_cwd = vim.fn.getcwd()
    vim.cmd("cd " .. vim.fn.fnameescape(project_root))

    -- Create build directory if it doesn't exist
    local build_dir = project_root .. "/build"
    if vim.fn.isdirectory(build_dir) == 0 then
        vim.fn.mkdir(build_dir, "p")
    end

    -- Change to build directory
    vim.cmd("cd " .. vim.fn.fnameescape(build_dir))

    local cmd = debugger_config.cmake_configure_args[1]
    local args = vim.list_slice(debugger_config.cmake_configure_args, 2)

    vim.notify("Configuring CMake project: " .. cmd .. " " .. table.concat(args, " "))
    local output = ""
    local stderr = ""

    vim.fn.jobstart(
        vim.list_extend({ cmd }, args),
        {
            stdout_buffered = true,
            stderr_buffered = true,
            on_stdout = function(_, data)
                if data then
                    output = output .. table.concat(data, "\n")
                end
            end,
            on_stderr = function(_, data)
                if data then
                    stderr = stderr .. table.concat(data, "\n")
                end
            end,
            on_exit = function(_, code)
                -- Restore original directory
                vim.cmd("cd " .. vim.fn.fnameescape(original_cwd))

                local full_output = output .. "\n" .. stderr
                M.last_output = full_output
                local errors, warnings = parse_debug_output(full_output, filetype)
                M.last_errors = errors
                M.last_warnings = warnings
                M.suspicious_variables = analyze_suspicious_patterns(output)
                place_suspicious_signs(M.suspicious_variables)

                if #M.suspicious_variables > 0 then
                    vim.notify(
                        string.format("Found %d suspicious patterns", #M.suspicious_variables),
                        vim.log.levels.WARN
                    )
                end
                vim.notify(
                    string.format(
                        "CMake configure done. Errors: %d, Warnings: %d, Exit Code: %d",
                        #errors,
                        #warnings,
                        code
                    )
                )
                if #errors > 0 then
                    create_picker(errors, "CMake Configure Errors")
                elseif #warnings > 0 then
                    create_picker(warnings, "CMake Configure Warnings")
                else
                    vim.notify("CMake configuration successful!")
                end
            end
        }
    )
end

function M.cmake_build()
    local filetype = vim.bo.filetype
    if filetype ~= "c" and filetype ~= "cpp" then
        vim.notify("CMake is only available for C/C++ projects", vim.log.levels.ERROR)
        return
    end

    local project_root = find_cmake_project_root()
    if not project_root then
        vim.notify("No CMakeLists.txt found in current directory or parent directories", vim.log.levels.ERROR)
        return
    end

    local debugger_config = M.config.debuggers[filetype]
    if not debugger_config.cmake_build_args then
        vim.notify("CMake build not configured", vim.log.levels.ERROR)
        return
    end

    -- Change to project root
    local original_cwd = vim.fn.getcwd()
    vim.cmd("cd " .. vim.fn.fnameescape(project_root))

    local cmd = debugger_config.cmake_build_args[1]
    local args = vim.list_slice(debugger_config.cmake_build_args, 2)

    vim.notify("Building CMake project: " .. cmd .. " " .. table.concat(args, " "))
    local output = ""
    local stderr = ""

    vim.fn.jobstart(
        vim.list_extend({ cmd }, args),
        {
            stdout_buffered = true,
            stderr_buffered = true,
            on_stdout = function(_, data)
                if data then
                    output = output .. table.concat(data, "\n")
                end
            end,
            on_stderr = function(_, data)
                if data then
                    stderr = stderr .. table.concat(data, "\n")
                end
            end,
            on_exit = function(_, code)
                -- Restore original directory
                vim.cmd("cd " .. vim.fn.fnameescape(original_cwd))

                local full_output = output .. "\n" .. stderr
                M.last_output = full_output
                local errors, warnings = parse_debug_output(full_output, filetype)
                M.last_errors = errors
                M.last_warnings = warnings
                M.suspicious_variables = analyze_suspicious_patterns(output)
                place_suspicious_signs(M.suspicious_variables)

                if #M.suspicious_variables > 0 then
                    vim.notify(
                        string.format("Found %d suspicious patterns", #M.suspicious_variables),
                        vim.log.levels.WARN
                    )
                end
                vim.notify(
                    string.format("CMake build done. Errors: %d, Warnings: %d, Exit Code: %d", #errors, #warnings, code)
                )
                if #errors > 0 then
                    create_picker(errors, "Build Errors")
                elseif #warnings > 0 then
                    create_picker(warnings, "Build Warnings")
                else
                    vim.notify("Build successful!")
                end
            end
        }
    )
end

function M.gdb_debug()
    local filetype = vim.bo.filetype
    if filetype ~= "c" and filetype ~= "cpp" and filetype ~= "rust" then
        vim.notify("GDB is only available for C/C++ projects", vim.log.levels.ERROR)
        return
    end

    local debugger_config = M.config.debuggers[filetype]
    if not debugger_config.gdb_args then
        vim.notify("GDB not configured", vim.log.levels.ERROR)
        return
    end

    -- Find executable to debug
    local executable = nil
    local executables = find_cmake_executables()

    if #executables == 0 then
        -- Fallback to looking for debug_program
        local debug_program = vim.fn.getcwd() .. "/debug_program"
        if vim.fn.executable(debug_program) == 1 then
            executable = debug_program
        else
            vim.notify("No executable found. Build project first.", vim.log.levels.ERROR)
            return
        end
    elseif #executables == 1 then
        executable = executables[1]
    else
        -- Multiple executables found, let user choose
        vim.ui.select(
            executables,
            {
                prompt = "Select executable to debug:",
                format_item = function(item)
                    return vim.fn.fnamemodify(item, ":t")
                end
            },
            function(choice)
                if choice then
                    M.gdb_debug_executable(choice)
                end
            end
        )
        return
    end

    M.gdb_debug_executable(executable)
end

function M.gdb_debug_executable(executable)
    local filetype = vim.bo.filetype
    local debugger_config = M.config.debuggers[filetype]

    local cmd = debugger_config.gdb_args[1]
    local args = vim.deepcopy(debugger_config.gdb_args)
    table.remove(args, 1) -- Remove cmd from args
    table.insert(args, executable)

    vim.notify("Starting GDB debug: " .. cmd .. " " .. table.concat(args, " "))
    local output = ""
    local stderr = ""

    vim.fn.jobstart(
        vim.list_extend({ cmd }, args),
        {
            stdout_buffered = true,
            stderr_buffered = true,
            on_stdout = function(_, data)
                if data then
                    output = output .. table.concat(data, "\n")
                end
            end,
            on_stderr = function(_, data)
                if data then
                    stderr = stderr .. table.concat(data, "\n")
                end
            end,
            on_exit = function(_, code)
                local full_output = output .. "\n" .. stderr
                M.last_output = full_output
                local errors, warnings = parse_debug_output(full_output, filetype)
                M.last_errors = errors
                M.last_warnings = warnings
                M.suspicious_variables = analyze_suspicious_patterns(output)
                place_suspicious_signs(M.suspicious_variables)

                if #M.suspicious_variables > 0 then
                    vim.notify(
                        string.format("Found %d suspicious patterns", #M.suspicious_variables),
                        vim.log.levels.WARN
                    )
                end
                vim.notify(string.format("GDB session ended. Errors: %d, Warnings: %d", #errors, #warnings))
                if #errors > 0 then
                    create_picker(errors, "GDB Debug Errors")
                elseif #warnings > 0 then
                    create_picker(warnings, "GDB Debug Warnings")
                else
                    M.show_output()
                end
            end
        }
    )
end

function M.gdb_remote()
    local filetype = vim.bo.filetype
    if filetype ~= "c" and filetype ~= "cpp" and filetype ~= "rust" then
        vim.notify("GDB is only available for C/C++ projects", vim.log.levels.ERROR)
        return
    end

    -- Get remote target from user
    local target = vim.fn.input("Enter remote target (default: :1234): ")
    if target == "" then
        target = ":1234"
    end

    local debugger_config = M.config.debuggers[filetype]
    if not debugger_config.gdb_remote_args then
        vim.notify("GDB remote not configured", vim.log.levels.ERROR)
        return
    end

    -- Find executable for symbols
    local executable = nil
    local executables = find_cmake_executables()

    if #executables == 1 then
        executable = executables[1]
    elseif #executables > 1 then
        -- Multiple executables found, let user choose
        vim.ui.select(
            executables,
            {
                prompt = "Select executable for symbols:",
                format_item = function(item)
                    return vim.fn.fnamemodify(item, ":t")
                end
            },
            function(choice)
                if choice then
                    M.gdb_remote_executable(choice, target)
                end
            end
        )
        return
    end

    M.gdb_remote_executable(executable, target)
end

function M.gdb_remote_executable(executable, target)
    local filetype = vim.bo.filetype
    local debugger_config = M.config.debuggers[filetype]

    local cmd = debugger_config.gdb_remote_args[1]
    local args = vim.deepcopy(debugger_config.gdb_remote_args)
    table.remove(args, 1) -- Remove cmd from args

    -- Replace :1234 with actual target
    for i, arg in ipairs(args) do
        if arg:match(":1234") then
            args[i] = arg:gsub(":1234", target)
        end
    end

    if executable then
        table.insert(args, executable)
    end

    vim.notify("Connecting GDB to remote target " .. target .. ": " .. cmd .. " " .. table.concat(args, " "))
    local output = ""
    local stderr = ""

    vim.fn.jobstart(
        vim.list_extend({ cmd }, args),
        {
            stdout_buffered = true,
            stderr_buffered = true,
            on_stdout = function(_, data)
                if data then
                    output = output .. table.concat(data, "\n")
                end
            end,
            on_stderr = function(_, data)
                if data then
                    stderr = stderr .. table.concat(data, "\n")
                end
            end,
            on_exit = function(_, code)
                local full_output = output .. "\n" .. stderr
                M.last_output = full_output
                local errors, warnings = parse_debug_output(full_output, filetype)
                M.last_errors = errors
                M.last_warnings = warnings
                M.suspicious_variables = analyze_suspicious_patterns(output)
                place_suspicious_signs(M.suspicious_variables)

                if #M.suspicious_variables > 0 then
                    vim.notify(
                        string.format("Found %d suspicious patterns", #M.suspicious_variables),
                        vim.log.levels.WARN
                    )
                end
                vim.notify(string.format("GDB remote session ended. Errors: %d, Warnings: %d", #errors, #warnings))
                if #errors > 0 then
                    create_picker(errors, "GDB Remote Debug Errors")
                elseif #warnings > 0 then
                    create_picker(warnings, "GDB Remote Debug Warnings")
                else
                    M.show_output()
                end
            end
        }
    )
end

function M.lldb_debug()
    local filetype = vim.bo.filetype
    if filetype ~= "c" and filetype ~= "cpp" and filetype ~= "rust" then
        vim.notify("LLDB is only available for C/C++/Rust projects", vim.log.levels.ERROR)
        return
    end

    local debugger_config = M.config.debuggers[filetype]
    if not debugger_config.lldb_args then
        vim.notify("LLDB not configured", vim.log.levels.ERROR)
        return
    end

    local executable = nil
    local executables = find_cmake_executables()

    if #executables == 0 then
        local debug_program = vim.fn.getcwd() .. "/debug_program"
        if vim.fn.executable(debug_program) == 1 then
            executable = debug_program
        else
            vim.notify("No executable found. Build project first.", vim.log.levels.ERROR)
            return
        end
    elseif #executables == 1 then
        executable = executables[1]
    else
        vim.ui.select(
            executables,
            {
                prompt = "Select executable to debug:",
                format_item = function(item)
                    return vim.fn.fnamemodify(item, ":t")
                end
            },
            function(choice)
                if choice then
                    M.lldb_debug_executable(choice)
                end
            end
        )
        return
    end

    M.lldb_debug_executable(executable)
end

function M.lldb_debug_executable(executable)
    local filetype = vim.bo.filetype
    local debugger_config = M.config.debuggers[filetype]

    local cmd = debugger_config.lldb_args[1]
    local args = vim.deepcopy(debugger_config.lldb_args)
    table.remove(args, 1)
    table.insert(args, executable)

    vim.notify("Starting LLDB debug: " .. cmd .. " " .. table.concat(args, " "))
    local output = ""
    local stderr = ""

    vim.fn.jobstart(
        vim.list_extend({ cmd }, args),
        {
            stdout_buffered = true,
            stderr_buffered = true,
            on_stdout = function(_, data)
                if data then
                    output = output .. table.concat(data, "\n")
                end
            end,
            on_stderr = function(_, data)
                if data then
                    stderr = stderr .. table.concat(data, "\n")
                end
            end,
            on_exit = function(_, code)
                local full_output = output .. "\n" .. stderr
                M.last_output = full_output
                local errors, warnings = parse_debug_output(full_output, filetype)
                M.last_errors = errors
                M.last_warnings = warnings
                M.suspicious_variables = analyze_suspicious_patterns(output)
                place_suspicious_signs(M.suspicious_variables)

                if #M.suspicious_variables > 0 then
                    vim.notify(
                        string.format("Found %d suspicious patterns", #M.suspicious_variables),
                        vim.log.levels.WARN
                    )
                end
                vim.notify(string.format("LLDB session ended. Errors: %d, Warnings: %d", #errors, #warnings))
                if #errors > 0 then
                    create_picker(errors, "LLDB Debug Errors")
                elseif #warnings > 0 then
                    create_picker(warnings, "LLDB Debug Warnings")
                else
                    M.show_output()
                end
            end
        }
    )
end

function M.lldb_remote()
    local filetype = vim.bo.filetype
    if filetype ~= "c" and filetype ~= "cpp" and filetype ~= "rust" then
        vim.notify("LLDB is only available for C/C++/Rust projects", vim.log.levels.ERROR)
        return
    end

    local target = vim.fn.input("Enter remote target (default: :1234): ")
    if target == "" then
        target = ":1234"
    end

    local debugger_config = M.config.debuggers[filetype]
    if not debugger_config.lldb_remote_args then
        vim.notify("LLDB remote not configured", vim.log.levels.ERROR)
        return
    end

    local executable = nil
    local executables = find_cmake_executables()

    if #executables == 1 then
        executable = executables[1]
    elseif #executables > 1 then
        vim.ui.select(
            executables,
            {
                prompt = "Select executable for symbols:",
                format_item = function(item)
                    return vim.fn.fnamemodify(item, ":t")
                end
            },
            function(choice)
                if choice then
                    M.lldb_remote_executable(choice, target)
                end
            end
        )
        return
    end

    M.lldb_remote_executable(executable, target)
end

function M.lldb_remote_executable(executable, target)
    local filetype = vim.bo.filetype
    local debugger_config = M.config.debuggers[filetype]

    local cmd = debugger_config.lldb_remote_args[1]
    local args = vim.deepcopy(debugger_config.lldb_remote_args)
    table.remove(args, 1)

    for i, arg in ipairs(args) do
        if arg:match(":1234") then
            args[i] = arg:gsub(":1234", target)
        end
    end

    if executable then
        table.insert(args, executable)
    end

    vim.notify("Connecting LLDB to remote target " .. target .. ": " .. cmd .. " " .. table.concat(args, " "))
    local output = ""
    local stderr = ""

    vim.fn.jobstart(
        vim.list_extend({ cmd }, args),
        {
            stdout_buffered = true,
            stderr_buffered = true,
            on_stdout = function(_, data)
                if data then
                    output = output .. table.concat(data, "\n")
                end
            end,
            on_stderr = function(_, data)
                if data then
                    stderr = stderr .. table.concat(data, "\n")
                end
            end,
            on_exit = function(_, code)
                local full_output = output .. "\n" .. stderr
                M.last_output = full_output
                local errors, warnings = parse_debug_output(full_output, filetype)
                M.last_errors = errors
                M.last_warnings = warnings
                M.suspicious_variables = analyze_suspicious_patterns(output)
                place_suspicious_signs(M.suspicious_variables)

                if #M.suspicious_variables > 0 then
                    vim.notify(
                        string.format("Found %d suspicious patterns", #M.suspicious_variables),
                        vim.log.levels.WARN
                    )
                end
                vim.notify(string.format("LLDB remote session ended. Errors: %d, Warnings: %d", #errors, #warnings))
                if #errors > 0 then
                    create_picker(errors, "LLDB Remote Debug Errors")
                elseif #warnings > 0 then
                    create_picker(warnings, "LLDB Remote Debug Warnings")
                else
                    M.show_output()
                end
            end
        }
    )
end

local function current_file_line()
    local file = vim.fn.expand("%") -- current file path
    local line = vim.fn.line(".")   -- current line number
    return file, line
end

local function extract_condition_from_node(node, bufnr)
    -- Look for condition child node in if statements
    for child in node:iter_children() do
        local child_type = child:type()
        if
            child_type == "condition" or child_type == "parenthesized_expression" or child_type == "binary_expression" or
            child_type == "comparison_operator"
        then
            return ts.get_node_text(child, bufnr)
        end
    end
    return nil
end

local function extract_function_name(node, bufnr)
    for child in node:iter_children() do
        if child:type() == "identifier" or child:type() == "name" then
            return ts.get_node_text(child, bufnr)
        end
    end
    return nil
end

local function extract_variable_name(node, bufnr)
    -- Variable declarations can have complex structures
    -- Look for identifier nodes that represent the variable name
    for child in node:iter_children() do
        local child_type = child:type()
        if child_type == "identifier" then
            return ts.get_node_text(child, bufnr)
        elseif child_type == "variable_declarator" or child_type == "init_declarator" then
            -- Nested structure, look deeper
            for grandchild in child:iter_children() do
                if grandchild:type() == "identifier" then
                    return ts.get_node_text(grandchild, bufnr)
                end
            end
        end
    end
    return nil
end

local function get_context()
    local bufnr = vim.api.nvim_get_current_buf()
    local cursor = vim.api.nvim_win_get_cursor(0)
    local row, col = cursor[1] - 1, cursor[2]

    local parser = ts.get_parser(bufnr)
    if not parser then
        return "line"
    end

    local tree = parser:parse()[1]
    local root = tree:root()
    local node = root:descendant_for_range(row, col, row, col)

    -- Get the current line for fallback
    local line_text = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1] or ""

    while node do
        local node_type = node:type()

        -- Check for conditional statements
        if node_type == "if_statement" or node_type == "if_expression" or node_type == "conditional_expression" then
            return "if", extract_condition_from_node(node, bufnr)
        end

        -- Check for function definitions
        if
            node_type:match("function") or node_type == "func_declaration" or node_type == "function_declaration" or
            node_type == "function_definition" or
            node_type == "function_item"
        then
            local func_name = extract_function_name(node, bufnr)
            if func_name then
                return "function", func_name
            end
        end

        -- Check for variable declarations
        if
            node_type == "variable_declaration" or node_type == "let_declaration" or node_type == "const_declaration" or
            node_type == "var_declaration" or
            node_type == "short_var_declaration"
        then -- Go
            local var_name = extract_variable_name(node, bufnr)
            if var_name then
                return "variable", var_name
            end
        end

        node = node:parent()
    end

    return "line"
end

local function extract_condition()
    local bufnr = vim.api.nvim_get_current_buf()
    local cursor = vim.api.nvim_win_get_cursor(0)
    local row, col = cursor[1] - 1, cursor[2]

    local parser = vim.treesitter.get_parser(bufnr)
    local tree = parser:parse()[1]
    local root = tree:root()
    local node = root:named_descendant_for_range(row, col, row, col) or root:descendant_for_range(row, col, row, col)

    while node do
        local t = node:type()
        if t == "if_statement" or t == "if_expression" or t == "conditional_expression" then
            return extract_condition_from_node(node, bufnr)
        end
        node = node:parent()
    end

    return nil
end

function M.copy_breakpoint()
    local file, line = current_file_line()
    local ctx, name = get_context()
    local is_go = file:match("%.go$")
    local cmd

    if ctx == "if" then
        local condition = extract_condition()
        if is_go then
            -- Delve conditional breakpoint
            if condition then
                cmd = string.format("break %s:%d if %s", file, line, condition)
            else
                cmd = string.format("break %s:%d if <condition>", file, line)
            end
        else
            -- GDB conditional breakpoint for C/C++
            if condition then
                cmd = string.format("break %s:%d if %s", file, line, condition)
            else
                cmd = string.format("break %s:%d if <condition>", file, line)
            end
        end
    elseif ctx == "function" then
        if is_go then
            -- For Go functions, use filename_without_extension.function_name
            local filename_no_ext = file:match("([^/\\]+)%.go$") or file:gsub("%.go$", "")
            filename_no_ext = filename_no_ext:gsub("%.go$", "")
            local function_name = name or vim.fn.expand("<cword>")
            cmd = string.format("break %s.%s", filename_no_ext, function_name)
        else
            -- GDB function breakpoint for C/C++
            cmd = string.format("break %s", name or vim.fn.expand("<cword>"))
        end
    elseif ctx == "goroutine" then
        if is_go then
            local goid = 1
            local current_line = line
            for lineno = 1, current_line do
                local linetext = vim.fn.getline(lineno)
                if linetext:match("goroutine") or linetext:match("// dlv:goroutine") then
                    goid = goid + 1
                end
            end

            cmd = string.format("break %s:%d if goid == %d", file, line, goid)
        else
            vim.notify("GDB does not support goroutine breakpoints", vim.log.levels.WARN)
            cmd = string.format("break %s:%d", file, line)
        end
    elseif ctx == "variable" then
        if is_go then
            -- In Go/Delve, variable breakpoints are line-based
            cmd = string.format("break %s:%d", file, line)
        else
            -- In GDB, you can break on variable changes with watchpoints
            cmd = string.format("break %s:%d", file, line)
        end
    else
        -- Default line breakpoint
        cmd = string.format("break %s:%d", file, line)
    end

    -- copy to clipboard
    vim.fn.setreg("+", cmd)
    vim.notify("Copied breakpoint command: " .. cmd, vim.log.levels.INFO)

    -- add the breakpoint sign
    local sign_id = M.sign_id_counter
    vim.fn.sign_place(sign_id, "breakpoint_group", "ODBreakpointSign", file, { lnum = line })
    M.sign_id_counter = M.sign_id_counter + 1

    -- store in breakpoints list
    table.insert(
        M.breakpoints,
        {
            cmd = cmd,
            file = file,
            line = line,
            ctx = ctx,
            sign_id = sign_id
        }
    )
end

function M.copy_watchpoint()
    local file, line = current_file_line()
    local ctx, name = get_context()
    local is_go = file:match("%.go$")
    local cmd

    if is_go then
        if ctx == "if" then
            local condition = extract_condition()
            if condition then
                cmd = string.format("watch %s:%d if %s", file, line, condition)
            else
                cmd = string.format("watch %s:%d if <condition>", file, line)
            end
        elseif ctx == "function" then
            -- For Go functions, use filename_without_extension.function_name
            local filename_no_ext = file:match("([^/\\]+)%.go$") or file:gsub("%.go$", "")
            filename_no_ext = filename_no_ext:gsub("%.go$", "")
            cmd = string.format("watch %s.%s", filename_no_ext, name)
        elseif ctx == "goroutine" then
            local goid = 1
            local current_line = line
            for lineno = 1, current_line do
                local linetext = vim.fn.getline(lineno)
                if linetext:match("goroutine") or linetext:match("// dlv:goroutine") then
                    goid = goid + 1
                end
            end
            cmd = string.format("watch -w <variable> if goid == %d", goid)
        elseif ctx == "variable" then
            cmd = string.format("watch -rw %s", name)
        else
            cmd = string.format("watch %s:%d", file, line)
        end
    else
        -- C/C++ and other languages (GDB)
        if ctx == "if" then
            local condition = extract_condition()
            if condition then
                cmd = string.format("watch <variable> if %s", condition)
            else
                cmd = string.format("watch <variable> if <condition>")
            end
        elseif ctx == "function" then
            cmd = string.format("watch %s", name)
        elseif ctx == "variable" then
            cmd = string.format("watch %s", name)
        else
            cmd = string.format("watch <variable>")
        end
    end

    vim.fn.setreg("+", cmd)
    vim.notify("Copied watchpoint command: " .. cmd, vim.log.levels.INFO)

    local sign_id = M.sign_id_counter
    vim.fn.sign_place(sign_id, "breakpoint_group", "ODBreakpointSign", file, { lnum = line })
    M.sign_id_counter = M.sign_id_counter + 1

    table.insert(
        M.breakpoints,
        {
            cmd = cmd,
            file = file,
            line = line,
            ctx = "watchpoint",
            sign_id = sign_id
        }
    )
end

function M.copy_tracepoint()
    local file, line = current_file_line()
    local ctx, func_name = get_context()
    local is_go = file:match("%.go$")
    local cmd

    if is_go then
        -- Go logic (Delve)
        if ctx == "if" then
            local condition = extract_condition()
            if condition then
                cmd = string.format("trace %s:%d if %s", file, line, condition)
            else
                cmd = string.format("trace %s:%d if <condition>", file, line)
            end
        elseif ctx == "function" then
            -- For Go functions, use filename_without_extension.function_name
            local filename_no_ext = file:match("([^/\\]+)%.go$") or file:gsub("%.go$", "")
            filename_no_ext = filename_no_ext:gsub("%.go$", "")
            local function_name = func_name or vim.fn.expand("<cword>")
            cmd = string.format("trace %s.%s", filename_no_ext, function_name)
        elseif ctx == "goroutine" then
            local goid = 1
            local current_line = line
            for lineno = 1, current_line do
                local linetext = vim.fn.getline(lineno)
                if linetext:match("goroutine") or linetext:match("// dlv:goroutine") then
                    goid = goid + 1
                end
            end
            cmd = string.format("trace %s:%d if goid == %d", file, line, goid)
        elseif ctx == "variable" then
            cmd = string.format("trace %s:%d", file, line) -- Variables use line-based tracing
        else
            cmd = string.format("trace %s:%d", file, line)
        end
    else
        -- C/C++ and other languages (GDB)
        if ctx == "if" then
            local condition = extract_condition()
            if condition then
                cmd = string.format("trace %s:%d if %s", file, line, condition)
            else
                cmd = string.format("trace %s:%d if <condition>", file, line)
            end
        elseif ctx == "function" then
            cmd = string.format("trace %s", func_name or vim.fn.expand("<cword>"))
        elseif ctx == "variable" then
            vim.notify("In GDB you can only put a tracepoint on a function", vim.log.levels.WARN)
            cmd = string.format("trace %s:%d", file, line) -- Fallback to line
        else
            cmd = string.format("trace %s:%d", file, line)
        end
    end

    vim.fn.setreg("+", cmd)
    vim.notify("Copied tracepoint command: " .. cmd, vim.log.levels.INFO)

    local sign_id = M.sign_id_counter
    vim.fn.sign_place(sign_id, "breakpoint_group", "ODBreakpointSign", file, { lnum = line })
    M.sign_id_counter = M.sign_id_counter + 1

    table.insert(
        M.breakpoints,
        {
            cmd = cmd,
            file = file,
            line = line,
            ctx = "tracepoint",
            sign_id = sign_id
        }
    )
end

local function get_clear_command(bp_number, file)
    local extension = file:match("%.([^%.]+)$")

    if extension == "go" then
        return "clear " .. bp_number
    else
        return "del " .. bp_number
    end
end

local function get_breakpoint_number(file, line, ctx_filter)
    local count = 0
    for i, bp in ipairs(M.breakpoints) do
        if ctx_filter == nil or bp.ctx == ctx_filter then
            count = count + 1
            if bp.file == file and bp.line == line then
                return count, i
            end
        end
    end
    return nil, nil
end

function M.copy_clear_tracepoint()
    local file, line = current_file_line()
    local bp_number, table_index = get_breakpoint_number(file, line, "tracepoint")

    if bp_number then
        local clear_cmd = get_clear_command(bp_number, file)
        vim.fn.setreg("+", clear_cmd)
        vim.notify("Copied clear tracepoint: " .. clear_cmd, vim.log.levels.INFO)

        local bp = M.breakpoints[table_index]
        vim.fn.sign_unplace("breakpoint_group", { id = bp.sign_id, buffer = bp.file })
        table.remove(M.breakpoints, table_index)
        return
    end

    vim.notify("No tracepoint found at this line", vim.log.levels.WARN)
end

function M.copy_clear_watchpoint()
    local file, line = current_file_line()
    local bp_number, table_index = get_breakpoint_number(file, line, "watchpoint")

    if bp_number then
        local clear_cmd = get_clear_command(bp_number, file)
        vim.fn.setreg("+", clear_cmd)
        vim.notify("Copied clear watchpoint: " .. clear_cmd, vim.log.levels.INFO)

        local bp = M.breakpoints[table_index]
        vim.fn.sign_unplace("breakpoint_group", { id = bp.sign_id, buffer = bp.file })
        table.remove(M.breakpoints, table_index)
        return
    end

    vim.notify("No watchpoint found at this line", vim.log.levels.WARN)
end

function M.copy_clear_breakpoint()
    local file, line = current_file_line()
    local bp_number, table_index = get_breakpoint_number(file, line, nil) -- nil = any context

    if bp_number then
        local clear_cmd = get_clear_command(bp_number, file)
        vim.fn.setreg("+", clear_cmd)
        vim.notify("Copied clear command: " .. clear_cmd, vim.log.levels.INFO)

        local bp = M.breakpoints[table_index]
        vim.fn.sign_unplace("breakpoint_group", { id = bp.sign_id, buffer = bp.file })
        table.remove(M.breakpoints, table_index)
        return
    end

    vim.notify("No breakpoint found at this line", vim.log.levels.WARN)
end

function M.show_breakpoints_picker()
    if #M.breakpoints == 0 then
        vim.notify("No breakpoints set", vim.log.levels.INFO)
        return
    end

    pickers.new(
        {},
        {
            prompt_title = "Breakpoints",
            finder = finders.new_table(
                {
                    results = M.breakpoints,
                    entry_maker = function(entry)
                        return {
                            value = entry,
                            display = string.format("[%s] %s:%d", entry.ctx, entry.file, entry.line),
                            ordinal = entry.file .. ":" .. entry.line
                        }
                    end
                }
            ),
            sorter = conf.generic_sorter({}),
            attach_mappings = function(prompt_bufnr)
                actions.select_default:replace(
                    function()
                        actions.close(prompt_bufnr)
                        local selection = action_state.get_selected_entry()
                        if selection then
                            local bp = selection.value
                            vim.cmd("edit " .. vim.fn.fnameescape(bp.file))
                            local line = tonumber(bp.line) or 1
                            vim.api.nvim_win_set_cursor(0, { line, 0 })
                            vim.cmd("normal! zz") -- center screen
                        end
                    end
                )
                return true
            end
        }
    ):find()
end

function M.clear_breakpoints()
    local file, line = current_file_line()
    local is_go = file:match("%.go$")
    -- remove all placed signs
    for _, bp in ipairs(M.breakpoints) do
        if bp.sign_id and bp.file then
            pcall(vim.fn.sign_unplace, "breakpoint_group", { buffer = bp.file, id = bp.sign_id })
        end
    end
    if is_go then
        vim.fn.setreg("+", "clearall")
        vim.notify("Coppied clearall command for delve to clipboard")
    else
        vim.fn.setreg("+", "delete")
        vim.notify("Coppied delete command for gdb to clipboard")
    end

    M.breakpoints = {}

    M.sign_id_counter = 1

    vim.notify("All breakpoints, watchpoints, tracepoints cleared", vim.log.levels.INFO)
end

function M.clear_telescope_items()
    -- Clear previous telescope signs
    local sign_group = "od_telescope_items"
    vim.fn.sign_unplace(sign_group)
    local sign_group2 = "od_suspicious"
    vim.fn.sign_unplace(sign_group2)
end

function M.show_suspicious_variables()
    if #M.suspicious_variables == 0 then
        vim.notify("No suspicious variables detected", vim.log.levels.INFO)
        return
    end

    pickers.new(
        {},
        {
            prompt_title = "Suspicious Variables & Values",
            finder = finders.new_table(
                {
                    results = M.suspicious_variables,
                    entry_maker = function(entry)
                        return {
                            value = entry,
                            display = entry.display,
                            ordinal = entry.display,
                            filename = entry.filename,
                            lnum = entry.lnum,
                            col = entry.col or 1
                        }
                    end
                }
            ),
            sorter = conf.generic_sorter({}),
            attach_mappings = function(prompt_bufnr)
                actions.select_default:replace(
                    function()
                        actions.close(prompt_bufnr)
                        local selection = action_state.get_selected_entry()
                        if selection then
                            -- Check if file exists and get the correct buffer
                            local bufnr = vim.fn.bufnr(selection.filename)
                            if bufnr == -1 then
                                -- Try to find the buffer by basename if full path didn't work
                                local basename = vim.fn.fnamemodify(selection.filename, ":t")
                                for _, buf in ipairs(vim.api.nvim_list_bufs()) do
                                    local buf_name = vim.api.nvim_buf_get_name(buf)
                                    if vim.fn.fnamemodify(buf_name, ":t") == basename then
                                        bufnr = buf
                                        break
                                    end
                                end
                            end

                            if bufnr ~= -1 then
                                -- Switch to existing buffer
                                vim.api.nvim_set_current_buf(bufnr)
                            else
                                -- Only create new buffer if file doesn't exist in any loaded buffer
                                vim.cmd("edit " .. vim.fn.fnameescape(selection.filename))
                            end

                            -- Validate line number before setting cursor
                            local line_count = vim.api.nvim_buf_line_count(0)
                            local target_line = math.min(selection.lnum, line_count)
                            vim.api.nvim_win_set_cursor(0, { target_line, selection.col or 0 })
                            vim.cmd("normal! zz")

                            vim.notify(
                                "Jumped to suspicious pattern: " .. (selection.value.text or ""),
                                vim.log.levels.INFO
                            )
                        end
                    end
                )
                return true
            end
        }
    ):find()
end

function M.save_breakpoints()
    if #M.breakpoints == 0 then
        vim.notify("No breakpoints to save", vim.log.levels.WARN)
        return
    end

    -- Ask for save location
    local save_path = vim.fn.input("Save breakpoints to: ", vim.fn.getcwd() .. "/breakpoints.json")
    if save_path == "" then
        vim.notify("Save cancelled", vim.log.levels.INFO)
        return
    end

    -- Prepare data for saving
    local save_data = {
        version = "1.0",
        timestamp = os.date("%Y-%m-%d %H:%M:%S"),
        breakpoints = {}
    }

    for _, bp in ipairs(M.breakpoints) do
        table.insert(
            save_data.breakpoints,
            {
                cmd = bp.cmd,
                file = bp.file,
                line = bp.line,
                ctx = bp.ctx
            }
        )
    end

    -- Convert to JSON string
    local json_str = vim.fn.json_encode(save_data)

    -- Write to file
    local file = io.open(save_path, "w")
    if not file then
        vim.notify("Failed to create save file: " .. save_path, vim.log.levels.ERROR)
        return
    end

    file:write(json_str)
    file:close()

    vim.notify(string.format("Saved %d breakpoints to %s", #M.breakpoints, save_path), vim.log.levels.INFO)
end

function M.load_breakpoints()
    -- Ask for load location
    local load_path = vim.fn.input("Load breakpoints from: ", vim.fn.getcwd() .. "/breakpoints.json")
    if load_path == "" then
        vim.notify("Load cancelled", vim.log.levels.INFO)
        return
    end

    -- Check if file exists
    local file = io.open(load_path, "r")
    if not file then
        vim.notify("File not found: " .. load_path, vim.log.levels.ERROR)
        return
    end

    -- Read file content
    local content = file:read("*all")
    file:close()

    -- Parse JSON
    local ok, data = pcall(vim.fn.json_decode, content)
    if not ok or not data or not data.breakpoints then
        vim.notify("Invalid breakpoint file format", vim.log.levels.ERROR)
        return
    end

    -- Clear existing breakpoints first
    M.clear_breakpoints()

    local loaded_count = 0
    local failed_count = 0

    -- Load each breakpoint
    for _, bp_data in ipairs(data.breakpoints) do
        -- Check if file exists
        if vim.fn.filereadable(bp_data.file) == 1 then
            -- Add sign to the buffer
            local sign_id = M.sign_id_counter
            vim.fn.sign_place(sign_id, "breakpoint_group", "ODBreakpointSign", bp_data.file, { lnum = bp_data.line })
            M.sign_id_counter = M.sign_id_counter + 1

            -- Store in breakpoints list
            table.insert(
                M.breakpoints,
                {
                    cmd = bp_data.cmd,
                    file = bp_data.file,
                    line = bp_data.line,
                    ctx = bp_data.ctx,
                    sign_id = sign_id
                }
            )

            vim.fn.setreg("+", bp_data.cmd)

            -- Small delay to allow clipboard operations
            vim.cmd("sleep 50m")

            loaded_count = loaded_count + 1
        else
            vim.notify(string.format("File not found, skipping: %s", bp_data.file), vim.log.levels.WARN)
            failed_count = failed_count + 1
        end
    end

    local message = string.format("Loaded %d breakpoints", loaded_count)
    if failed_count > 0 then
        message = message .. string.format(" (%d failed)", failed_count)
    end

    vim.notify(message, vim.log.levels.INFO)

    if loaded_count > 0 then
        vim.notify("Last breakpoint command copied to clipboard", vim.log.levels.INFO)
    end
end

local output_parser = require("od.parsers.output_parser")
local variable_analyzer = require("od.parsers.variable_analyzer")

function M.setup(opts)
    opts = opts or {}
    if opts.debuggers then
        for lang, config in pairs(opts.debuggers) do
            M.add_custom_debugger(lang, config)
        end
    end
    if opts.test_handlers then
        for lang, handler in pairs(opts.test_handlers) do
            M.add_test_handler(lang, handler)
        end
    end
    if opts.parsers then
        for lang, fn in pairs(opts.parsers) do
            output_parser.register_parser(lang, fn)
        end
    end
    if opts.analyzer then
        local a = opts.analyzer
        if a.value_patterns then
            for cat, patterns in pairs(a.value_patterns) do
                for _, p in ipairs(patterns) do
                    variable_analyzer.add_value_pattern(cat, p)
                end
            end
        end
        if a.languages then
            for lang, cfg in pairs(a.languages) do
                variable_analyzer.register_language(lang, cfg)
            end
        end
    end
    M.config = vim.tbl_deep_extend("force", M.config, opts)

    -- Create user commands
    vim.api.nvim_create_user_command("ODRun", M.debug, {})
    vim.api.nvim_create_user_command("ODErrors", M.show_errors, {})
    vim.api.nvim_create_user_command("ODWarnings", M.show_warnings, {})
    vim.api.nvim_create_user_command("ODTestErrors", M.show_test_errors, {})
    vim.api.nvim_create_user_command("ODTestWarnings", M.show_test_warnings, {})
    vim.api.nvim_create_user_command("ODOutput", M.show_output, {})
    vim.api.nvim_create_user_command("ODClearItems", M.clear_telescope_items, {})
    vim.api.nvim_create_user_command("ODSuspicious", M.show_suspicious_variables, {})

    -- Rust-specific commands
    vim.api.nvim_create_user_command("ODRustClippy", M.rust_clippy, {})
    vim.api.nvim_create_user_command("ODRustTest", M.rust_test, {})

    -- Go-specific commands
    vim.api.nvim_create_user_command("ODGoBuild", M.go_build, {})
    vim.api.nvim_create_user_command("ODGoTest", M.go_test, {})

    -- CMake-specific commands
    vim.api.nvim_create_user_command("ODCMakeConfigure", M.cmake_configure, {})
    vim.api.nvim_create_user_command("ODCMakeBuild", M.cmake_build, {})
    vim.api.nvim_create_user_command("ODCMakeTest", M.ctest, {})

    -- GDB-specific commands
    vim.api.nvim_create_user_command("ODGdbDebug", M.gdb_debug, {})
    vim.api.nvim_create_user_command("ODGdbRemote", M.gdb_remote, {})
    -- LLDB-specific commands
    vim.api.nvim_create_user_command("ODLldbDebug", M.lldb_debug, {})
    vim.api.nvim_create_user_command("ODLldbRemote", M.lldb_remote, {})

    -- Copy breakpoints, watchpoints, tracepoints (You didn't think I would programm a whole dap logic now did you :)
    vim.api.nvim_create_user_command("ODAddBreakpoint", M.copy_breakpoint, {})
    vim.api.nvim_create_user_command("ODRemoveBreakpoint", M.copy_clear_breakpoint, {})
    vim.api.nvim_create_user_command("ODListPoints", M.show_breakpoints_picker, {})
    vim.api.nvim_create_user_command("ODAddWatchpoint", M.copy_watchpoint, {})
    vim.api.nvim_create_user_command("ODRemoveWatchpoint", M.copy_clear_watchpoint, {})
    vim.api.nvim_create_user_command("ODAddTracepoint", M.copy_tracepoint, {})
    vim.api.nvim_create_user_command("ODRemoveTracepoint", M.copy_clear_tracepoint, {})
    vim.api.nvim_create_user_command("ODClearPoints", M.clear_breakpoints, {})
    vim.api.nvim_create_user_command("ODSavePoints", M.save_breakpoints, {})
    vim.api.nvim_create_user_command("ODLoadPoints", M.load_breakpoints, {})

    -- Test integration for python, javascript/typepescrit, lua
    vim.api.nvim_create_user_command("ODPythonTest", M.python_test, {})
    vim.api.nvim_create_user_command("ODJestTest", M.js_test, {})
    vim.api.nvim_create_user_command("ODBustedTest", M.busted_test, {})
end

return M
