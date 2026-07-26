<h1 style="display: flex; align-items: center;">
  <img src="od.png" width="25" height="25">
  Onto Debug
</h1>

Onto Debug is a neovim plugin designed to help debugging, testing
(so debugging really) but not act as a full debugger protocol or a 
testing framework. It's whole design point is also to run only on demand.

[![Watch the demo](od_showcase.gif)](od_showcase.mov)

## Installation:
To install use your preferred plugin manager I will use here vim plug for 
example. 

**Note** nvim notify doesn't have to be installed for the plugin to work it just looks nice.

```vim
Plug 'nvim-telescope/telescope.nvim'
Plug 'rcarriga/nvim-notify'
Plug 'Okerew/od.nvim'
```
### Also depending on the language you need these tools:

**C/Cpp:**
gcc, lldb or gdb, valgrind, cmake

**Go**:
delve

**Javscript**:
jest

**Lua**:
busted

**Treesitter**:
treesitter parsers for the given language

## Features:
### Run
<img src="diagnostic_sign.png">
Runs the current file with the designed debug path and when encountering
errors, warnings parses them to telescope pickers and allows faster movement
and debugging.

**Through:**
* If clicking enter on a picker select with line attribute goes to that line
* When clicking enter on a goroutine or thread attribute copies the given one
for faster debugging with a counting method
- **Gdb/lldb integration** allows for the same thing that run allows just with Gdb/lldb
output, also provides support for remote gdb/lldb debugging.

### Breakpoints, watchpoints, tracepoints
Although we don't have a full dap integration we still can make using
breakpoints faster and we do, all copies are done to unnamedplus.

**Through:**
* Copies filename:line by default if on if copies `filename:line <if condition>`
, if near a goroutine it copies `if goid == accurence_of_goroutine`, if we are on
a function copies `filename:function_name` for delve and `function_name` for gdb,
if we are on a variable name and we have a watchpoint it does `variable_name`.
* Smartly uses the correct command so `break`, `watch` or `trace`.
* Smartly appends breakpoints to a breakpoints list, allowing to quickly
move in file through a telescope picker.
* Counts breakpoints/watchpoints/tracepoints you put and if calling clear for 
one does `clear iterance_id` for delve and for gdb `del iterance_id`.

### Testing 
<img src="testing_example.png">
Supports testing integration for rust clippy, cargo test, golang, python, jest, 
lua, by using a telescope picker to view error lines, failed tests and allows 
quick hopping to the lines, also allows to run specific tests in file.

### Build
Allows for faster building and debugging of builds for golang, cmake files and
has cmake integration for debugging and run.

## Commands
**Debug:**
* `ODRun`: Compiles and runs the current file along with extracting compile and
runtime errors, warnings to a telescope picker.
* `ODErrors`: Shows the error picker.
* `ODWarnings`: Shows the warning picker.
* `ODOutput`: Shows the raw output of ODRun.
* `ODClearItems`: Clears diagnostic signs placed by OD.
* `ODSuspicious`: Shows suspicious variables in a telescope picker.

**Rust:**
* `ODRustClippy`: Runs clippy for a rust project with picker logic.
* `ODRustTest`: Runs a rust test with picker logic.

**Go:**
* `ODGoBuild`: Builds a go project shows errors, warnings in picker.
* `ODGoTest`: Tests a go test shows errors, warnings in picker.

**CMake:**
* `ODCMakeConfigure`: Congigures CMake shows errors, warnings in picker.
* `ODCMakeBuild`: Builds cmake project shows errors, warnings in picker.
* `ODCMakeTest`:  Runs a cmake test with picker logic.

**GDB:**
* `ODGdbDebug`: Opens a gdb session and shows errors and warnings in picker.
* `ODGdbRemote`:  Opens a remote gdb session and shows errors and warnings in picker.

**Lldb:**
* `ODLldbDebug`: Opens a lldb session and shows errors and warnings in picker.
* `ODLldbRemote` : Opens a remote lldb session and shows errors and warnings in picker.

**Breakpoints, tracepoints, watchpoints:**
* `ODAddBreakpoint`: Adds a breakpoint add the current line and copies the
command for placing a breakpoint.
* `ODRemoveBreakpoint`: Removes a breakpoint assigned to the current line,
copies the command for removing a breakpoint depending on filetype.
* `ODListPoints`: Lists breakpoints, watchpoints, tracepoints in a picker.
* `ODAddWatchpoint`: Adds a watchpoint add the current line and copies the
command for placing a watchpoint.
* `ODRemoveWatchpoint`: Removes a watchpoint assigned to the current line,
copies the command for removing a watchpoint depending on filetype.
* `ODAddTracepoint`: Removes a tracepoint assigned to the current line,
copies the command for removing a tracepoint depending on filetype.
* `ODRemoveTracepoint`: Removes a tracepoint assigned to the current line,
copies the command for removing a watchpoint depending on filetype.
* `ODClearPoints`: Clears breakpoints, watchpoints, tracepoints.
* `ODSavePoints`: Saves breakpoints, watchpoints, tracepoints to a json like file.
* `ODLoadPoints`: Loads breakpoints, watchpoints, tracepoints from a json save file.

**Python, jest, busted tests:**
* `ODPythonTest`: Runs a python test with picker logic.
* `ODJestTest`: Runs a jest test with picker logic.
* `ODBustedTest`: Runs a busted test with picker logic.

**Show test errors/warnings:**
* `ODTestErrors`: Shows the test error picker.
* `ODTestWarnings`: Shows the test warning picker.

## Config
If you just want to start using this plugin copy this config, keybindings are not needed to
use OD, but are useful.

``` lua
-- NECESSARY THESE LINES MUST BE DEFINED FOR OD TO WORK
vim.fn.sign_define("ODBreakpointSign", { text = "●", texthl = "ErrorSign" })
vim.fn.sign_define("ODTelescopeItem", {
		text = "▶",
		texthl = "DiagnosticSignWarn",
		numhl = "DiagnosticSignWarn",})
vim.fn.sign_define("ODSuspiciousValue", {
	text = "⁉",
	texthl = "DiagnosticSignWarn",
	culhl = "DiagnosticSignWarn",
})
local od = require('od')
od:setup()
-- END OF NECESSARY LINES

vim.g.rust_build_time_threshold = 60.0

-- General OD mappings
vim.keymap.set("n", "<leader>odr", function() od:debug() end, { desc = "Run debugger" })
vim.keymap.set("n", "<leader>ode", function() od:show_errors() end, { desc = "Show errors" })
vim.keymap.set("n", "<leader>odw", function() od:show_warnings() end, { desc = "Show warnings" })
vim.keymap.set("n", "<leader>ote", function() od:show_test_errors() end, { desc = "Show test errors" })
vim.keymap.set("n", "<leader>otw", function() od:show_test_warnings() end, { desc = "Show test warnings" })
vim.keymap.set("n", "<leader>odo", function() od:show_output() end, { desc = "Show output" })
vim.keymap.set("n", "<leader>oci", function() od:clear_telescope_items() end, { desc = "Clear Items" })
vim.keymap.set("n", "<leader>os", function() od:show_suspicious_variables() end, { desc = "Shows suspicious variables" })

-- Rust-specific
vim.keymap.set("n", "<leader>orc", function() od:rust_clippy() end, { desc = "Run Rust Clippy" })
vim.keymap.set("n", "<leader>otr", function() od:rust_test() end, { desc = "Run Rust Test" })

-- Go-specific
vim.keymap.set("n", "<leader>ogb", function() od:go_build() end, { desc = "Go Build" })
vim.keymap.set("n", "<leader>ogt", function() od:go_test() end, { desc = "Go Test" })

-- CMake
vim.keymap.set("n", "<leader>occ", function() od:cmake_configure() end, { desc = "CMake Configure" })
vim.keymap.set("n", "<leader>ocb", function() od:cmake_build() end, { desc = "CMake Build" })
vim.keymap.set("n", "<leader>otc", function() od:ctest() end, { desc = "Run CMake Test" })

-- GDB and LLDB
vim.keymap.set("n", "<leader>ogdb", function() od:gdb_debug() end, { desc = "GDB Debug" })
vim.keymap.set("n", "<leader>ogr", function() od:gdb_remote() end, { desc = "GDB Remote" })
vim.keymap.set("n", "<leader>oldb", function() od:lldb_debug() end, { desc = "LLDB Debug" })
vim.keymap.set("n", "<leader>olr", function() od:lldb_remote() end, { desc = "LLDB Remote" })

-- Copy breakpoints, watchpoints, tracepoints (You didnt think I would programm a whole dap logic now did you :)
vim.keymap.set("n", "<leader>oab", function() od:copy_breakpoint() end, { desc = "Add breakpoint" })
vim.keymap.set("n", "<leader>orb", function() od:copy_clear_breakpoint() end, { desc = "Remove breakpoint" })
vim.keymap.set("n", "<leader>oca", function() od:clear_breakpoints() end, { desc = "Clears breakpoints, watchpoints, tracepoints" })
vim.keymap.set("n", "<leader>ols", function() od:show_breakpoints_picker() end, { desc = "List brakpoints, watchpoints, tracepoints" })
vim.keymap.set("n", "<leader>oaw", function() od:copy_watchpoint() end, { desc = "Add watchpoint" })
vim.keymap.set("n", "<leader>orw", function() od:copy_clear_watchpoint() end, { desc = "Remove watchpoint" })
vim.keymap.set("n", "<leader>oat", function() od:copy_tracepoint() end, { desc = "Add tracepoint" })
vim.keymap.set("n", "<leader>ort", function() od:copy_clear_tracepoint() end, { desc = "Remove tracepoint" })
vim.keymap.set("n", "<leader>olp", function() od:load_breakpoints() end, { desc = "Load points" })
vim.keymap.set("n", "<leader>oas", function() od:save_breakpoints() end, { desc = "Saves points" })

-- Test integration for python, javascript/typepescript, lua
vim.keymap.set("n", "<leader>otp", function() od:python_test() end, { desc = "Run Python Test" })
vim.keymap.set("n", "<leader>otj", function() od:js_test() end, { desc = "Run Jest Test" })
vim.keymap.set("n", "<leader>otb", function() od:busted_test() end, { desc = "Run Busted Test" })
```

**Default debugger configs** it's not recommended to modify them unless you
know what you are doing, note these are setup by default when calling od setup

```lua
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
```

## Extending OD

OD is designed to be extensible. You can add custom debuggers, test
handlers, output parsers, and analyzer patterns through the setup function.

### Custom debugger with callbacks

For tools that need a different command-building strategy or custom output
processing, use the `build_command`, `process_output`, and `on_output`
callbacks instead of the standard cmd/args fields:

```lua
local od = require("od")
od.setup({
  debuggers = {
    mylang = {
      -- Instead of cmd + args, provide build_command which receives
      -- (source_files, filetype) and returns the full argv table
      build_command = function(source_files, filetype)
        return { "mycompiler", "--output", "out", source_files[1] }
      end,
      -- Transform raw output before it's parsed
      process_output = function(output, exit_code)
        return output:gsub("\27%[[0-9;]*m", "") -- strip ANSI
      end,
      -- Fully replace the compile→run chaining (e.g. no valgrind needed)
      on_output = function(output, exit_code)
        local errors, warnings =
          require("od.parsers.output_parser")
            .parse_debug_output(output, "mylang")
        -- custom handling...
      end,
    },
  },
})
```

### Custom test handler

For languages not built-in, provide an `args_fn` and `parse_fn`:

```lua
od.setup({
  test_handlers = {
    mylang = {
      args_fn = function(args, current_func)
        if current_func and current_func:match("^test") then
          table.insert(args, "--filter")
          table.insert(args, current_func)
          vim.notify("Running specific test: " .. current_func)
        end
      end,
      parse_fn = function(full_output)
        local errors, warnings = {}, {}
        for line in full_output:gmatch("[^\n]+") do
          if line:match("FAIL") then
            table.insert(errors, {
              filename = vim.fn.expand("%"),
              lnum = 1,
              text = line,
              display = "FAIL: " .. line,
            })
          end
        end
        return errors, warnings
      end,
      title = "MyLang tests",
      attach_log = true,
      exec_fallback = function(cmd)
        -- optional: try alternative executables
        return cmd
      end,
    },
  },
})
```

Alternatively, register imperatively:

```lua
od.add_test_handler("mylang", {
  args_fn = function(args, func) -- ... end,
  parse_fn = function(out) return {}, {} end,
  title = "MyLang tests",
})
```

### Custom output parser

For languages that produce output in a non-standard format, register a
line handler:

```lua
local op = require("od.parsers.output_parser")
op.register_parser("mylang", function(line, ctx)
  local file, lnum, msg = line:match(
    "([^:]+):(%d+):%s*(.+)")
  if file and lnum and msg then
    table.insert(ctx.errors, {
      filename = file,
      lnum = tonumber(lnum),
      text = msg,
      display = string.format("%s:%s: %s",
        vim.fn.fnamemodify(file, ":t"), lnum, msg),
    })
  end
end)
```

You can also extend the pattern tables for built-in languages:

```lua
op.add_error_keywords("go", { "my custom error" })
op.add_warning_patterns("cpp", {
  { pattern = "my warning pattern", type = "MY-WARN" },
})
op.set_default_parser(function(line, ctx)
  -- fallback for unrecognised filetypes
end)
op.set_on_parse(function(output, filetype, errors, warnings)
  -- post-processing hook, runs after every parse
end)
```

### Custom analyzer patterns and languages

Add suspicious value patterns or register a new language for tree-sitter
variable analysis:

```lua
local va = require("od.parsers.variable_analyzer")
va.add_value_pattern("overflow", "0xdeadbeef")
va.add_suspicious_op({ pattern = "mybad%.*", type = "BAD" })

va.register_language("zig", {
  filetypes = { "zig" },
  query = [[
    (assignment_expression
      left: (identifier) @var
      right: (_) @value) @assignment
    (identifier) @identifier
  ]],
  function_query = [[
    (function_item
      name: (identifier) @func_name
      body: (block) @func_body) @function
  ]],
})
```

All the above can also be passed through `setup()`:

```lua
od.setup({
  debuggers = { zig = { cmd = "zig", args = { "build" } } },
  test_handlers = { zig = { args_fn = ..., parse_fn = ..., title = "Zig" } },
  parsers = { zig = function(line, ctx) ... end },
  analyzer = {
    value_patterns = { my_cat = { "0x1337" } },
    languages = { zig = { filetypes = { "zig" }, query = ..., function_query = ... } },
  },
})
```

## Notes:
* This is not a full debugger protocol for that use https://github.com/mfussenegger/nvim-dap,
it's also not a full testing framework for that use https://github.com/nvim-neotest/neotest.
* This plugin is designed to work mostly out of the box but also supports
extending with custom debuggers, test runners, parsers and analyzers.
* I made this plugin because I didn't want a full debugger or a full tester in my nvim but something
that could help me debug and test faster without being to beefy.
* I will never support java, just use intellij idea for it,
also I would never recommend using neovim for java, it just sucks for it.
* The gdb, lldb commands DON'T spawn a full debugging session they just spawn gdb or lldb
and run the bt command.
