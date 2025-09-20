local M = {}

local function get_language()
    local buf = vim.api.nvim_get_current_buf()
    local ft = vim.api.nvim_buf_get_option(buf, "filetype")

    local lang_map = {
        c = "c",
        cpp = "cpp",
        rust = "rust",
        go = "go",
        python = "python",
        lua = "lua",
        javascript = "javascript",
        typescript = "typescript",
    }

    return lang_map[ft] or "c"
end

local function get_parser()
    local lang = get_language()
    local buf = vim.api.nvim_get_current_buf()

    if not pcall(require, "nvim-treesitter.parsers") then
        return nil, "Treesitter not available"
    end

    local ok, parser = pcall(vim.treesitter.get_parser, buf, lang)
    if not ok then
        return nil, "Parser not available for " .. lang
    end

    return parser, nil
end

local value_patterns = {
    overflow = {
        "4294967295",
        "18446744073709551615",
        "2147483647",
        "-2147483648",
        "0xffffffff",
        "0xffffffffffffffff",
        "0x7fffffff",
        "0x80000000",
        "4294967296",
        "18446744073709551616",
        "2147483648",
        "-2147483649",
        "65535",
        "65536",
        "32767",
        "32768",
        "-32768",
        "-32769",
        "255",
        "256",
        "127",
        "128",
        "-128",
        "-129",
        "3.40282347e%+38",
        "1.7976931348623157e%+308",
        "-3.40282347e%+38",
        "-1.7976931348623157e%+308",
        "9223372036854775807",
        "9223372036854775808",
        "-9223372036854775808",
        "-9223372036854775809",
    },
    null_ptr = {
        "0x0",
        "<nil>",
        "nil",
        "NULL",
        "(null)",
        "nullptr",
        "0x00000000",
        "0x0000000000000000",
        "null",
        "Null",
        "None",
        "undefined",
        "void",
        "<NULL>",
        "NULL_PTR",
        "INVALID_HANDLE",
    },
    uninitialized = {
        "0xcccccccc",
        "0xdeadbeef",
        "0xbaadf00d",
        "0xfeedface",
        "0xcdcdcdcd",
        "0xabababab",
        "0x12345678",
        "0xdeadc0de",
        "0xcafebabe",
        "0xfacefeed",
        "0x8badf00d",
        "0xa5a5a5a5",
        "0xfeedfeed",
        "0xbeefbeef",
        "0xdadadada",
        "0xfeeefeee",
        "0xaaaaaaaa",
        "0xbbbbbbbb",
        "0x5555555555555555",
        "0xaaaaaaaaaaaaaaaa",
        "0xdeaddeaddeaddead",
        "0xc0c0c0c0",
        "0xf0f0f0f0",
        "0xbadcab1e",
        "0x1badb002",
    },
    nan_inf = {
        "NaN",
        "+Inf",
        "-Inf",
        "Inf",
        "inf",
        "nan",
        "NAN",
        "+INF",
        "-INF",
        "INF",
        "1.#INF",
        "1.#QNAN",
        "QNAN",
        "SNAN",
        "IND",
        "1.#IND",
        "-nan",
        "infinity",
        "INFINITY",
    },
    memory_leak = {
        "leaked",
        "not.*freed",
        "memory.*leak",
        "heap.*leak",
        "still.*reachable",
        "definitely.*lost",
        "possibly.*lost",
        "use.*after.*free",
        "double.*free",
        "invalid.*free",
        "heap.*overflow",
        "heap.*underflow",
        "dangling.*pointer",
        "wild.*pointer",
        "memory.*corruption",
        "heap.*corruption",
        "stack.*corruption",
    },
    buffer_overflow = {
        "buffer overflow",
        "stack smashing",
        "heap corruption",
        "segmentation.*fault",
        "segfault",
        "access.*violation",
        "AddressSanitizer",
        "ASAN",
        "bounds.*violation",
        "stack.*buffer.*overflow",
        "heap.*buffer.*overflow",
        "out.*of.*bounds",
        "array.*index.*out.*of.*bounds",
        "string.*overflow",
        "format.*string",
    },
    race_condition = {
        "race.*condition",
        "data.*race",
        "thread.*unsafe",
        "concurrent.*access",
        "shared.*state.*corruption",
        "deadlock",
        "livelock",
        "priority.*inversion",
        "atomic.*violation",
        "synchronization.*error",
    },
    cryptographic = {
        "weak.*key",
        "predictable.*random",
        "insecure.*random",
        "hardcoded.*key",
        "hardcoded.*password",
        "md5",
        "sha1",
        "des",
        "3des",
        "rc4",
        "insufficient.*entropy",
        "weak.*cipher",
        "deprecated.*crypto",
    },
    input_validation = {
        "injection",
        "xss",
        "csrf",
        "path.*traversal",
        "directory.*traversal",
        "command.*injection",
        "sql.*injection",
        "ldap.*injection",
        "xml.*injection",
        "script.*injection",
        "untrusted.*input",
        "unsanitized.*input",
    },
    resource_exhaustion = {
        "out.*of.*memory",
        "memory.*exhausted",
        "stack.*overflow",
        "too.*many.*open.*files",
        "file.*descriptor.*leak",
        "resource.*leak",
        "handle.*leak",
        "connection.*leak",
        "thread.*leak",
        "excessive.*recursion",
        "infinite.*loop",
        "denial.*of.*service",
    },
    unsafe_cast = {
        "unsafe.*cast",
        "invalid.*cast",
        "truncation.*warning",
        "precision.*loss",
        "sign.*conversion",
        "implicit.*conversion",
        "narrowing.*conversion",
        "type.*punning",
        "aliasing.*violation",
    },
    timing_attack = {
        "timing.*attack",
        "side.*channel",
        "constant.*time.*violation",
        "timing.*leak",
        "cache.*timing",
        "branch.*prediction",
        "speculative.*execution",
    },
    privilege_escalation = {
        "privilege.*escalation",
        "unauthorized.*access",
        "permission.*bypass",
        "sudo.*vulnerability",
        "setuid.*vulnerability",
        "capability.*leak",
        "sandbox.*escape",
    },
    format_string = {
        "%n",
        "%s%s%s%s",
        "AAAA%08x",
        "format.*string.*vulnerability",
        "printf.*vulnerability",
        "sprintf.*vulnerability",
        "uncontrolled.*format.*string",
    },
    integer_issues = {
        "integer.*overflow",
        "integer.*underflow",
        "signed.*overflow",
        "unsigned.*overflow",
        "wraparound",
        "arithmetic.*exception",
        "division.*by.*zero",
        "modulo.*by.*zero",
        "shift.*overflow",
        "shift.*by.*negative",
    },
    unitialized_vars = {
        "uninitialized.*variable",
        "use.*of.*uninitialized",
        "may.*be.*used.*uninitialized",
        "variable.*used.*before.*set",
        "possibly.*uninitialized",
        "conditional.*jump.*depends.*on.*uninitialized",
    },
    suspicious_api = {
        "gets",
        "strcpy",
        "strcat",
        "sprintf",
        "vsprintf",
        "scanf",
        "fscanf",
        "sscanf",
        "system",
        "exec",
        "popen",
        "mktemp",
        "tmpnam",
        "tempnam",
        "realpath",
        "getwd",
    },
    error_handling = {
        "uncaught.*exception",
        "unhandled.*exception",
        "panic",
        "abort",
        "fatal.*error",
        "assertion.*failed",
        "invariant.*violation",
        "precondition.*failed",
        "postcondition.*failed",
        "contract.*violation",
    },
    magic_numbers = {
        "0xDEADBEEF",
        "0xCAFEBABE",
        "0xFEEDFACE",
        "0xDEADC0DE",
        "0xBAADF00D",
        "0x8BADF00D",
        "0xABBABAAD",
        "0xABADCAFE",
        "0xBEEFFACE",
        "0xDEAFBEEF",
        "0xFEEDDEAD",
        "0xDEFEC8ED",
        "0xC0EDBABE",
        "0xFACEFEED",
        "0xB16B00B5",
        "0x12345678",
        "0x87654321",
        "1337",
        "31337",
        "666666",
        "999999",
        "123456789",
        "987654321",
        "0x1337",
        "0xDEAD",
        "0xBEEF",
        "0xFEED",
        "0xCAFE",
    },
    suspicious_strings = {
        "password",
        "passwd",
        "pwd",
        "secret",
        "key",
        "token",
        "api_key",
        "private_key",
        "auth",
        "admin",
        "root",
        "debug",
        "test",
        "temp",
        "tmp",
        "backdoor",
        "exploit",
        "payload",
        "shell",
        "reverse_shell",
        "bind_shell",
    },
    network_security = {
        "man.*in.*the.*middle",
        "mitm",
        "dns.*spoofing",
        "arp.*spoofing",
        "session.*hijacking",
        "replay.*attack",
        "reflection.*attack",
        "amplification.*attack",
        "ssl.*strip",
        "tls.*downgrade",
        "certificate.*pinning.*bypass",
    },
    deserialization = {
        "unsafe.*deserialization",
        "pickle.*load",
        "yaml.*load",
        "xml.*parse",
        "json.*decode.*unsafe",
        "object.*injection",
        "serialization.*vulnerability",
    },
    anti_magic_numbers = {
        common_magic = {
            "42",
            "69",
            "420",
            "1337",
            "31337",
            "666",
            "777",
            "999",
            "1234",
            "5678",
            "9999",
            "12345",
            "54321",
            "123456",
            "654321",
            "1111111",
            "2222222",
            "7777777",
            "8888888",
            "9999999",
        },
        suspicious_constants = {
            "100",
            "200",
            "300",
            "400",
            "500",
            "1000",
            "2000",
            "5000",
            "10000",
            "50000",
            "100000",
            "1000000",
            "86400",
            "3600",
            "60",
            "24",
            "7",
            "365",
            "366",
        },
        hardcoded_sizes = {
            "512",
            "1024",
            "2048",
            "4096",
            "8192",
            "16384",
            "32768",
            "65536",
            "131072",
            "262144",
            "524288",
            "1048576",
        },
        port_numbers = {
            "80",
            "443",
            "21",
            "22",
            "23",
            "25",
            "53",
            "110",
            "143",
            "993",
            "995",
            "3306",
            "5432",
            "6379",
            "27017",
            "8080",
            "8443",
            "9000",
        },
        error_codes = {
            "-1",
            "-2",
            "-99",
            "404",
            "500",
            "503",
            "403",
            "401",
            "200",
            "204",
            "301",
            "302",
        },
        array_bounds = {
            "10",
            "50",
            "256",
            "255",
            "128",
            "64",
            "32",
            "16",
            "8",
            "4",
        },
        timing_values = {
            "1000",
            "5000",
            "10000",
            "30000",
            "60000",
            "300000",
            "600000",
            "3600000",
        },
        version_numbers = {
            "1.0",
            "2.0",
            "3.0",
            "1.1",
            "2.1",
            "0.1",
            "0.9",
            "1.5",
        },
        percentage_values = {
            "0.5",
            "0.25",
            "0.75",
            "0.1",
            "0.9",
            "0.01",
            "0.99",
        },
        coordinate_defaults = {
            "0.0",
            "1.0",
            "-1.0",
            "100.0",
            "50.0",
            "25.0",
            "75.0",
        },
    },
    magic_number_patterns = {
        repeated_digits = "%d%1%1%1+",
        sequential_up = "123456?7?8?9?",
        sequential_down = "987654?3?2?1?",
        round_numbers = "%d*00+$",
        powers_of_two = "^(2|4|8|16|32|64|128|256|512|1024|2048|4096|8192)$",
        hex_patterns = "0x[fF]+$",
        suspicious_hex = "0x[0-9a-fA-F]*([dD][eE][aA][dD]|[bB][eE][eE][fF]|[cC][aA][fF][eE]|[fF][eE][eE][dD])",
    },
}

local function evaluate_math_expression(expr, variable_values)
    -- Simple math expression evaluator with variable substitution
    local function substitute_variables(expression)
        local substituted = expression
        for var, value in pairs(variable_values) do
            -- Replace variable names with their values
            substituted = substituted:gsub("%f[%w_]" .. var .. "%f[^%w_]",
                tostring(value))
        end
        return substituted
    end

    -- Evaluate basic math operations safely
    local function safe_eval(math_expr)
        -- Remove whitespace
        math_expr = math_expr:gsub("%s+", "")

        -- Check for dangerous patterns
        if math_expr:match("[^%d%+%-%*%/%%%(%)%.]") then
            return nil, "unsafe_expression"
        end

        -- Simple recursive descent parser for basic math
        local function parse_number(s, pos)
            local num = ""
            while pos <= #s and s:sub(pos, pos):match("[%d%.]") do
                num = num .. s:sub(pos, pos)
                pos = pos + 1
            end
            return tonumber(num), pos
        end

        local function parse_factor(s, pos)
            if pos > #s then return nil, pos end

            local char = s:sub(pos, pos)
            if char == "(" then
                local result, new_pos = parse_expression(s, pos + 1)
                if not result then return nil, new_pos end
                if new_pos > #s or s:sub(new_pos, new_pos) ~= ")" then
                    return nil, new_pos
                end
                return result, new_pos + 1
            elseif char == "-" then
                local result, new_pos = parse_factor(s, pos + 1)
                if not result then return nil, new_pos end
                return -result, new_pos
            elseif char:match("%d") then
                return parse_number(s, pos)
            else
                return nil, pos
            end
        end

        local function parse_term(s, pos)
            local left, new_pos = parse_factor(s, pos)
            if not left then return nil, new_pos end

            while new_pos <= #s do
                local op = s:sub(new_pos, new_pos)
                if op == "*" or op == "/" or op == "%" then
                    local right, next_pos = parse_factor(s, new_pos + 1)
                    if not right then return nil, next_pos end

                    if op == "*" then
                        left = left * right
                    elseif op == "/" then
                        if right == 0 then return nil, "division_by_zero" end
                        left = left / right
                    elseif op == "%" then
                        if right == 0 then return nil, "modulo_by_zero" end
                        left = left % right
                    end
                    new_pos = next_pos
                else
                    break
                end
            end

            return left, new_pos
        end

        function parse_expression(s, pos)
            local left, new_pos = parse_term(s, pos or 1)
            if not left then return nil, new_pos end

            while new_pos <= #s do
                local op = s:sub(new_pos, new_pos)
                if op == "+" or op == "-" then
                    local right, next_pos = parse_term(s, new_pos + 1)
                    if not right then return nil, next_pos end

                    if op == "+" then
                        left = left + right
                    else
                        left = left - right
                    end
                    new_pos = next_pos
                else
                    break
                end
            end

            return left, new_pos
        end

        return parse_expression(math_expr)
    end

    local substituted = substitute_variables(expr)
    local result, error_or_pos = safe_eval(substituted)

    if not result then
        return nil, error_or_pos
    end

    return result, nil
end

function M.analyze_math_expressions(variables)
    local math_issues = {}

    -- Check for overflow/underflow in mathematical expressions
    local overflow_bounds = {
        int8 = { min = -128, max = 127 },
        uint8 = { min = 0, max = 255 },
        int16 = { min = -32768, max = 32767 },
        uint16 = { min = 0, max = 65535 },
        int32 = { min = -2147483648, max = 2147483647 },
        uint32 = { min = 0, max = 4294967295 },
        int64 = { min = -9223372036854775808, max = 9223372036854775807 },
        uint64 = { min = 0, max = 18446744073709551615 },
        float32 = { min = -3.40282347e+38, max = 3.40282347e+38 },
        float64 = { min = -1.7976931348623157e+308, max = 1.7976931348623157e+308 },
    }

    -- Extract current variable values from assignments
    local var_values = {}
    for var_name, assignment in pairs(variables.assignments) do
        local value = tonumber(assignment.value_text)
        if value then
            var_values[var_name] = value
        end
    end

    -- Analyze mathematical expressions
    for var_name, expr_info in pairs(variables.expressions) do
        local expr = expr_info.expression
        local result, error_msg = evaluate_math_expression(expr, var_values)

        if error_msg then
            table.insert(math_issues, {
                type = "math_error",
                variable = var_name,
                expression = expr,
                error = error_msg,
                line = expr_info.line,
                source_line = expr_info.source_line,
            })
        elseif result then
            -- Check for overflow conditions
            for type_name, bounds in pairs(overflow_bounds) do
                if result > bounds.max or result < bounds.min then
                    table.insert(math_issues, {
                        type = "potential_overflow",
                        variable = var_name,
                        expression = expr,
                        result = result,
                        overflow_type = type_name,
                        line = expr_info.line,
                        source_line = expr_info.source_line,
                    })
                    break
                end
            end

            -- Check if result matches suspicious patterns
            local result_str = string.format("%.0f", result)
            local result_hex = string.format("0x%x", math.floor(math.abs(result)))

            for ptype, patterns in pairs(value_patterns) do
                if ptype ~= "anti_magic_numbers" and ptype ~= "magic_number_patterns" then
                    for _, pattern in ipairs(patterns) do
                        local pattern_str = tostring(pattern)
                        if result_str == pattern_str or result_hex:lower() == pattern_str:lower() then
                            table.insert(math_issues, {
                                type = "suspicious_math_result",
                                variable = var_name,
                                expression = expr,
                                result = result,
                                result_hex = result_hex,
                                pattern_type = ptype,
                                pattern = pattern,
                                line = expr_info.line,
                                source_line = expr_info.source_line,
                            })
                            break
                        end
                    end
                end
            end

            -- Check for suspicious mathematical operations
            if expr:match("/%s*0") then
                table.insert(math_issues, {
                    type = "division_by_zero",
                    variable = var_name,
                    expression = expr,
                    line = expr_info.line,
                    source_line = expr_info.source_line,
                })
            end

            -- Check for integer truncation issues
            if result ~= math.floor(result) and
                expr_info.source_line:match("int%s+") then
                table.insert(math_issues, {
                    type = "float_to_int_truncation",
                    variable = var_name,
                    expression = expr,
                    result = result,
                    truncated = math.floor(result),
                    line = expr_info.line,
                    source_line = expr_info.source_line,
                })
            end
        end
    end

    return math_issues
end

function M.monitor_variable_assignments(variables)
    local monitored_vars = {}

    -- Create watchpoints for variables that had normal initial values
    for var_name, assignment in pairs(variables.assignments) do
        local initial_value = assignment.value_text

        -- Only monitor if initial value was "normal"
        local is_initially_suspicious = false
        for ptype, patterns in pairs(value_patterns) do
            if ptype ~= "anti_magic_numbers" and ptype ~= "magic_number_patterns" then
                for _, pattern in ipairs(patterns) do
                    if initial_value == pattern or
                        (type(pattern) == "string" and initial_value:match(pattern)) then
                        is_initially_suspicious = true
                        break
                    end
                end
                if is_initially_suspicious then break end
            end
        end

        if not is_initially_suspicious then
            monitored_vars[var_name] = {
                initial_value = initial_value,
                line = assignment.line,
                watch_active = true
            }
        end
    end

    return monitored_vars
end

function M.analyze_function_sources(variables, output)
    local function_issues = {}

    -- Extract function definitions using treesitter
    local function extract_function_definitions()
        local parser, err = get_parser()
        if not parser then
            return {}, err
        end

        local tree = parser:parse()[1]
        local root = tree:root()
        local lang = get_language()
        local buf = vim.api.nvim_get_current_buf()

        local functions = {}

        local function_queries = {
            c = [[
                (function_definition
                    declarator: (function_declarator
                        declarator: (identifier) @func_name)
                    body: (compound_statement) @func_body) @function

                (function_definition
                    declarator: (pointer_declarator
                        declarator: (function_declarator
                            declarator: (identifier) @func_name))
                    body: (compound_statement) @func_body) @function
            ]],

            cpp = [[
                (function_definition
                    declarator: (function_declarator
                        declarator: (identifier) @func_name)
                    body: (compound_statement) @func_body) @function

                (function_definition
                    declarator: (pointer_declarator
                        declarator: (function_declarator
                            declarator: (identifier) @func_name))
                    body: (compound_statement) @func_body) @function
            ]],

            python = [[
                (function_definition
                    name: (identifier) @func_name
                    body: (_) @func_body) @function
            ]],

            javascript = [[
                (function_declaration
                    name: (identifier) @func_name
                    body: (statement_block) @func_body) @function

                (function_expression
                    name: (identifier) @func_name
                    body: (statement_block) @func_body) @function
            ]],

            go = [[
                (function_declaration
                    name: (identifier) @func_name
                    body: (block) @func_body) @function
            ]],

            rust = [[
                (function_item
                    name: (identifier) @func_name
                    body: (block) @func_body) @function
            ]],
        }

        local query_string = function_queries[lang]
        if not query_string then
            return functions, "No function query for language: " .. lang
        end

        local ok, query = pcall(vim.treesitter.query.parse, lang, query_string)
        if not ok then
            return functions, "Failed to parse function query"
        end

        for id, node, metadata in query:iter_captures(root, buf, 0, -1) do
            local capture_name = query.captures[id]
            if capture_name == "function" then
                local func_name_node = nil
                local func_body_node = nil

                -- Find function name and body nodes
                for child_id, child_node in query:iter_captures(node, buf, 0, -1) do
                    local child_capture = query.captures[child_id]
                    if child_capture == "func_name" then
                        func_name_node = child_node
                    elseif child_capture == "func_body" then
                        func_body_node = child_node
                    end
                end

                if func_name_node and func_body_node then
                    local func_name = vim.treesitter.get_node_text(func_name_node, buf)
                    local func_body = vim.treesitter.get_node_text(func_body_node, buf)
                    local start_line = func_name_node:start() + 1
                    local end_line = func_body_node:end_() + 1

                    functions[func_name] = {
                        name = func_name,
                        body = func_body,
                        start_line = start_line,
                        end_line = end_line,
                        name_node = func_name_node,
                        body_node = func_body_node,
                    }
                end
            end
        end

        return functions, nil
    end

    -- Analyze function body for suspicious patterns
    local function analyze_function_body(func_info)
        local body_issues = {}
        local body = func_info.body

        -- Check for hardcoded suspicious values in function
        for pattern_type, patterns in pairs(value_patterns) do
            if pattern_type ~= "anti_magic_numbers" and pattern_type ~= "magic_number_patterns" then
                for _, pattern in ipairs(patterns) do
                    for match in body:gmatch(pattern) do
                        table.insert(body_issues, {
                            type = "hardcoded_suspicious_value",
                            pattern_type = pattern_type,
                            value = match,
                            function_name = func_info.name,
                            line = func_info.start_line,
                        })
                    end
                end
            end
        end

        -- Check for suspicious operations
        local suspicious_ops = {
            { pattern = "malloc%s*%(%s*0%s*%)",                    type = "zero_allocation" },
            { pattern = "free%s*%(%s*0x0%s*%)",                    type = "null_free" },
            { pattern = "memcpy%s*%([^,]*,%s*[^,]*,%s*0xffffffff", type = "overflow_copy" },
            { pattern = "strcpy%s*%([^,]*,%s*[^)]*0x",             type = "hex_string_copy" },
            { pattern = "return%s+0xdeadbeef",                     type = "suspicious_return" },
            { pattern = "return%s+0xbaadf00d",                     type = "suspicious_return" },
            { pattern = "return%s+%-1",                            type = "error_return" },
            { pattern = "goto%s+[%w_]*error",                      type = "error_handling" },
        }

        for _, op in ipairs(suspicious_ops) do
            for match in body:gmatch(op.pattern) do
                table.insert(body_issues, {
                    type = op.type,
                    match = match,
                    function_name = func_info.name,
                    line = func_info.start_line,
                })
            end
        end

        -- Check for buffer operations without bounds checking
        local buffer_ops = {
            "strcpy", "strcat", "sprintf", "gets", "scanf"
        }

        for _, op in ipairs(buffer_ops) do
            if body:find(op) and not body:find("strlen") and not body:find("sizeof") then
                table.insert(body_issues, {
                    type = "unchecked_buffer_operation",
                    operation = op,
                    function_name = func_info.name,
                    line = func_info.start_line,
                })
            end
        end

        -- Check for mathematical operations that could overflow
        local math_patterns = {
            { pattern = "([%w_]+)%s*%+%s*([%w_]+)", type = "addition" },
            { pattern = "([%w_]+)%s*%*%s*([%w_]+)", type = "multiplication" },
            { pattern = "([%w_]+)%s*<<%s*([%d]+)",  type = "left_shift" },
            { pattern = "([%w_]+)%s*>>%s*([%d]+)",  type = "right_shift" },
        }

        for _, math_op in ipairs(math_patterns) do
            for var1, var2 in body:gmatch(math_op.pattern) do
                -- Check if variables could cause overflow
                if math_op.type == "left_shift" and tonumber(var2) and tonumber(var2) >= 32 then
                    table.insert(body_issues, {
                        type = "potential_shift_overflow",
                        operation = math_op.type,
                        operands = { var1, var2 },
                        function_name = func_info.name,
                        line = func_info.start_line,
                    })
                elseif math_op.type == "multiplication" and (var1:match("0x") or var2:match("0x")) then
                    table.insert(body_issues, {
                        type = "hex_multiplication",
                        operation = math_op.type,
                        operands = { var1, var2 },
                        function_name = func_info.name,
                        line = func_info.start_line,
                    })
                end
            end
        end

        -- Check for recursive calls without proper termination
        if body:find(func_info.name .. "%s*%(") then
            local has_base_case = body:find("return") and
                (body:find("if") or body:find("while") or body:find("for"))
            if not has_base_case then
                table.insert(body_issues, {
                    type = "potential_infinite_recursion",
                    function_name = func_info.name,
                    line = func_info.start_line,
                })
            end
        end

        return body_issues
    end

    -- Get function definitions
    local functions, err = extract_function_definitions()
    if err then
        table.insert(function_issues, {
            type = "analysis_error",
            error = err,
            line = 1,
        })
    end

    -- Analyze each function that's called by variables
    for var_name, call_info in pairs(variables.function_calls) do
        local func_name = call_info.function_name
        local func_def = functions[func_name]

        if func_def then
            local issues = analyze_function_body(func_def)
            for _, issue in ipairs(issues) do
                issue.called_by_variable = var_name
                issue.call_line = call_info.line
                table.insert(function_issues, issue)
            end
        else
            -- Check if it's a library function that might be suspicious
            local suspicious_lib_funcs = {
                malloc = "dynamic_allocation",
                free = "memory_management",
                system = "command_execution",
                exec = "command_execution",
                gets = "unsafe_input",
                strcpy = "unsafe_copy",
                sprintf = "unsafe_formatting",
            }

            local suspicion_type = suspicious_lib_funcs[func_name]
            if suspicion_type then
                table.insert(function_issues, {
                    type = "suspicious_library_call",
                    function_name = func_name,
                    suspicion_type = suspicion_type,
                    called_by_variable = var_name,
                    call_line = call_info.line,
                })
            end
        end
    end

    -- Check debug output for function-related issues
    for line in output:gmatch("[^\r\n]+") do
        local patterns = {
            "Function%s+([%w_]+)%s+returned%s+suspicious%s+value:%s+([%w%-%+%.x]+)",
            "([%w_]+)%(%)%s+->%s+([%w%-%+%.x]+)%s+%(suspicious%)",
            "Stack%s+corruption%s+in%s+function%s+([%w_]+)",
            "Heap%s+corruption%s+after%s+([%w_]+)%(%)%s+call",
        }

        for _, pattern in ipairs(patterns) do
            local matches = { line:match(pattern) }
            if #matches > 0 then
                table.insert(function_issues, {
                    type = "runtime_function_issue",
                    function_name = matches[1],
                    details = matches[2] or "corruption_detected",
                    line = 1,
                    debug_line = line,
                })
            end
        end
    end

    return function_issues
end

function M.track_variable_changes(debug_output)
    local runtime_changes = {}

    local tracking_patterns = {
        "Variable%s+'([%w_]+)'%s+changed%s+to:%s+([%w%-%+%.x]+)%s+at%s+line%s+(%d+)",
        "([%w_]+)%s+=%s+(.-)%s+=%s+([%w%-%+%.x]+)%s+at%s+line%s+(%d+)",
        "Overflow%s+detected%s+in%s+([%w_]+):%s+([%w%-%+%.x]+)%s+->%s+([%w%-%+%.x]+)%s+at%s+line%s+(%d+)",
        "Underflow%s+detected%s+in%s+([%w_]+):%s+([%w%-%+%.x]+)%s+->%s+([%w%-%+%.x]+)%s+at%s+line%s+(%d+)",
        "Expression%s+'([^']+)'%s+in%s+([%w_]+)%s+evaluated%s+to:%s+([%w%-%+%.x]+)%s+at%s+line%s+(%d+)",
    }

    for line in debug_output:gmatch("[^\r\n]+") do
        for _, pattern in ipairs(tracking_patterns) do
            local matches = { line:match(pattern) }
            if #matches > 0 then
                local var_name, new_value, line_num
                local operation_type = "change"
                local expression = nil

                if pattern:find("Overflow") then
                    var_name, _, new_value, line_num = matches[1], matches[2],
                        matches[3], matches[4]
                    operation_type = "overflow"
                elseif pattern:find("Underflow") then
                    var_name, _, new_value, line_num = matches[1], matches[2],
                        matches[3], matches[4]
                    operation_type = "underflow"
                elseif pattern:find("Expression") then
                    expression, var_name, new_value, line_num = matches[1],
                        matches[2], matches[3], matches[4]
                    operation_type = "expression_result"
                elseif #matches >= 4 and
                    matches[2]:match("[%+%-%*/%%%(%)%d%w_%.]+") then
                    var_name, expression, new_value, line_num = matches[1],
                        matches[2], matches[3], matches[4]
                    operation_type = "math_operation"
                else
                    var_name, new_value, line_num = matches[1],
                        matches[2] or matches[3],
                        matches[3] or matches[2]
                end

                if var_name and new_value and line_num then
                    local is_suspicious = false
                    local pattern_type = nil
                    local numeric_value = tonumber(new_value) or
                        tonumber(new_value:gsub("0x", ""), 16)

                    for ptype, ppatterns in pairs(value_patterns) do
                        if ptype ~= "anti_magic_numbers" and
                            ptype ~= "magic_number_patterns" then
                            for _, ppattern in ipairs(ppatterns) do
                                if new_value == ppattern or
                                    (type(ppattern) == "string" and
                                        new_value:match(ppattern)) then
                                    is_suspicious = true
                                    pattern_type = ptype
                                    break
                                end
                            end
                            if is_suspicious then break end
                        end
                    end

                    if numeric_value then
                        local overflow_values = { 4294967295,
                            18446744073709551615, 2147483647, -2147483648,
                            65535, 32767, 255, 127 }
                        for _, overflow_val in ipairs(overflow_values) do
                            if numeric_value == overflow_val or
                                numeric_value == overflow_val + 1 then
                                is_suspicious = true
                                pattern_type = "overflow_boundary"
                                break
                            end
                        end

                        if numeric_value > 0 then
                            local hex_str = string.format("%x", numeric_value):lower()
                            if hex_str:match("^[faf]+$") or
                                hex_str:match("dead") or hex_str:match("beef") or
                                hex_str:match("cafe") or hex_str:match("feed") then
                                is_suspicious = true
                                pattern_type = "suspicious_bit_pattern"
                            end
                        end

                        local powers_of_2 = { 256, 512, 1024, 2048, 4096,
                            8192, 16384, 32768, 65536 }
                        for _, power in ipairs(powers_of_2) do
                            if numeric_value == power - 1 or
                                numeric_value == power or
                                numeric_value == power + 1 then
                                is_suspicious = true
                                pattern_type = "buffer_boundary"
                                break
                            end
                        end
                    end

                    if is_suspicious then
                        table.insert(runtime_changes, {
                            variable = var_name,
                            new_value = new_value,
                            numeric_value = numeric_value,
                            line = tonumber(line_num),
                            pattern_type = pattern_type,
                            change_type = operation_type,
                            expression = expression,
                            original_line = line,
                        })
                    end
                end
            end
        end
    end

    return runtime_changes
end

function M.analyze_runtime_patterns(output, variables)
    local runtime_suspicious = {}

    -- Analyze mathematical expressions first
    local math_issues = M.analyze_math_expressions(variables)

    for _, issue in ipairs(math_issues) do
        local severity = "warning"
        if issue.type == "division_by_zero" or issue.type == "potential_overflow" then
            severity = "error"
        elseif issue.type == "math_error" then
            severity = "error"
        end

        local text = ""
        if issue.type == "math_error" then
            text = string.format(
                "Mathematical error in '%s': %s in expression '%s'",
                issue.variable,
                issue.error:gsub("_", " "),
                issue.expression
            )
        elseif issue.type == "potential_overflow" then
            text = string.format(
                "Potential overflow in '%s': Result %.0f exceeds %s bounds in expression '%s'",
                issue.variable,
                issue.result,
                issue.overflow_type,
                issue.expression
            )
        elseif issue.type == "suspicious_math_result" then
            text = string.format(
                "Suspicious math result in '%s': Expression '%s' = %.0f (%s) matches %s pattern",
                issue.variable,
                issue.expression,
                issue.result,
                issue.result_hex,
                issue.pattern_type
            )
        elseif issue.type == "division_by_zero" then
            text = string.format(
                "Division by zero detected in '%s': Expression '%s'",
                issue.variable,
                issue.expression
            )
        elseif issue.type == "float_to_int_truncation" then
            text = string.format(
                "Float truncation in '%s': %.2f -> %.0f in expression '%s'",
                issue.variable,
                issue.result,
                issue.truncated,
                issue.expression
            )
        end

        table.insert(runtime_suspicious, {
            filename = vim.fn.expand("%"),
            lnum = issue.line,
            col = 1,
            text = text,
            display = string.format(
                "MATH[%s]: %s:%d - %s",
                issue.type:upper(),
                vim.fn.fnamemodify(vim.fn.expand("%"), ":t"),
                issue.line,
                text:sub(1, 80) .. (text:len() > 80 and "..." or "")
            ),
            severity = severity,
        })
    end

    -- Analyze functions that variables come from
    local function_issues = M.analyze_function_sources(variables, output)

    for _, issue in ipairs(function_issues) do
        local severity = "info"
        if issue.type == "potential_infinite_recursion" or
            issue.type == "unchecked_buffer_operation" or
            issue.type == "potential_shift_overflow" then
            severity = "warning"
        elseif issue.type == "hardcoded_suspicious_value" or
            issue.type == "runtime_function_issue" then
            severity = "error"
        end

        local text = ""
        if issue.type == "hardcoded_suspicious_value" then
            text = string.format(
                "Function '%s' contains hardcoded %s value: %s%s",
                issue.function_name,
                issue.pattern_type,
                issue.value,
                issue.called_by_variable and (" (called by variable '" .. issue.called_by_variable .. "')") or ""
            )
        elseif issue.type == "unchecked_buffer_operation" then
            text = string.format(
                "Function '%s' uses unsafe '%s' without bounds checking%s",
                issue.function_name,
                issue.operation,
                issue.called_by_variable and (" (affects variable '" .. issue.called_by_variable .. "')") or ""
            )
        elseif issue.type == "suspicious_library_call" then
            text = string.format(
                "Variable '%s' calls suspicious library function '%s' (%s)",
                issue.called_by_variable,
                issue.function_name,
                issue.suspicion_type:gsub("_", " ")
            )
        elseif issue.type == "runtime_function_issue" then
            text = string.format(
                "Runtime issue in function '%s': %s",
                issue.function_name,
                issue.details:gsub("_", " ")
            )
        elseif issue.type == "potential_shift_overflow" then
            text = string.format(
                "Function '%s' has potential shift overflow: %s << %s%s",
                issue.function_name,
                issue.operands[1],
                issue.operands[2],
                issue.called_by_variable and (" (affects '" .. issue.called_by_variable .. "')") or ""
            )
        end

        table.insert(runtime_suspicious, {
            filename = vim.fn.expand("%"),
            lnum = issue.call_line or issue.line or 1,
            col = 1,
            text = text,
            display = string.format(
                "FUNCTION[%s]: %s:%d - %s",
                issue.type:upper():sub(1, 12),
                vim.fn.fnamemodify(vim.fn.expand("%"), ":t"),
                issue.call_line or issue.line or 1,
                text:sub(1, 60) .. (text:len() > 60 and "..." or "")
            ),
            severity = severity,
        })
    end

    -- Track variable changes from debug output
    local changes = M.track_variable_changes(output)

    for _, change in ipairs(changes) do
        local context = ""
        if change.expression then
            context = string.format(" (from expression: %s)", change.expression)
        end

        local change_desc = change.change_type:gsub("_", " ")

        table.insert(runtime_suspicious, {
            filename = vim.fn.expand("%"),
            lnum = change.line,
            col = 1,
            text = string.format(
                "Runtime %s detected: Variable '%s' changed to suspicious %s value: %s%s",
                change_desc,
                change.variable,
                change.pattern_type,
                change.new_value,
                context
            ),
            display = string.format(
                "RUNTIME[%s]: %s:%d - '%s' -> %s (%s)%s",
                change.pattern_type:upper(),
                vim.fn.fnamemodify(vim.fn.expand("%"), ":t"),
                change.line,
                change.variable,
                change.new_value,
                change_desc,
                change.expression and " [EXPR]" or ""
            ),
            severity = (change.change_type == "overflow" or change.change_type == "underflow") and "error" or "warning",
        })
    end

    -- Monitor for value corruption patterns in output
    local corruption_patterns = {
        "Variable%s+([%w_]+)%s+corrupted%s+from%s+([%w%-%+%.x]+)%s+to%s+([%w%-%+%.x]+)",
        "Memory%s+corruption%s+detected%s+in%s+([%w_]+)%s+at%s+([%w%-%+%.x]+)",
        "Stack%s+variable%s+([%w_]+)%s+overwritten%s+with%s+([%w%-%+%.x]+)"
    }

    for _, pattern in ipairs(corruption_patterns) do
        for match in output:gmatch(pattern) do
            local parts = { match:match(pattern) }
            if #parts >= 2 then
                local var_name = parts[1]
                local corrupted_value = parts[#parts]

                -- Check if corrupted value is suspicious
                for ptype, ppatterns in pairs(value_patterns) do
                    if ptype ~= "anti_magic_numbers" and ptype ~= "magic_number_patterns" then
                        for _, ppattern in ipairs(ppatterns) do
                            if corrupted_value == ppattern or corrupted_value:match(ppattern) then
                                table.insert(runtime_suspicious, {
                                    filename = vim.fn.expand("%"),
                                    lnum = 1,
                                    col = 1,
                                    text = string.format(
                                        "Runtime corruption: Variable '%s' corrupted with %s pattern: %s",
                                        var_name,
                                        ptype,
                                        corrupted_value
                                    ),
                                    display = string.format(
                                        "CORRUPTION[%s]: Variable '%s' -> %s",
                                        ptype:upper(),
                                        var_name,
                                        corrupted_value
                                    ),
                                    severity = "error",
                                })
                                break
                            end
                        end
                    end
                end
            end
        end
    end

    return runtime_suspicious
end

function M.analyze_suspicious_patterns(output)
    local suspicious = {}

    local function get_source_lines()
        local buf = vim.api.nvim_get_current_buf()
        local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
        return lines
    end

    local function find_line_with_pattern(lines, pattern, start_line)
        start_line = start_line or 1

        -- First try exact pattern match
        for i = start_line, #lines do
            if lines[i]:find(pattern, 1, true) then
                return i
            end
        end

        -- Then try escaped pattern for regex patterns
        local escaped_pattern = pattern:gsub("[%(%)%.%+%-%*%?%[%]%^%$%%]", "%%%1")
        for i = start_line, #lines do
            if lines[i]:find(escaped_pattern) then
                return i
            end
        end

        return nil
    end

    local function validate_line_mapping(line_num, variable_name, suspicious_value)
        local lines = get_source_lines()
        if line_num < 1 or line_num > #lines then
            return false, nil
        end

        local line_content = lines[line_num]

        -- Check if the line contains both the variable and the suspicious value
        local has_variable = variable_name and line_content:find(variable_name, 1, true)
        local has_value = line_content:find(suspicious_value, 1, true)

        -- For uninitialized patterns, just check if the variable is on this line
        if suspicious_value:match("0x[0-9a-fA-F]+") then
            return has_variable ~= nil, line_content
        end

        return (has_variable and has_value) or has_value, line_content
    end

    local function extract_variables_with_treesitter()
        local parser, err = get_parser()
        if not parser then
            return {}, err
        end

        local tree = parser:parse()[1]
        local root = tree:root()
        local lang = get_language()

        local variables = {
            assignments = {},
            expressions = {},
            function_calls = {},
            references = {},
            debug_info = {}, -- For debugging line mappings
        }

        local queries = {
            c = [[
				(assignment_expression
					left: (identifier) @var
					right: (_) @value) @assignment
				
				(init_declarator
					declarator: (identifier) @var
					value: (_) @value) @declaration
				
				(call_expression
					function: (identifier) @func
					arguments: (_) @args) @call
				
				(identifier) @identifier
			]],

            cpp = [[
				(assignment_expression
					left: (identifier) @var
					right: (_) @value) @assignment
				
				(init_declarator
					declarator: (identifier) @var
					value: (_) @value) @declaration
				
				(call_expression
					function: (identifier) @func
					arguments: (_) @args) @call
				
				(identifier) @identifier
			]],

            rust = [[
				(assignment_expression
					left: (identifier) @var
					right: (_) @value) @assignment
				
				(let_declaration
					pattern: (identifier) @var
					value: (_) @value) @declaration
				
				(call_expression
					function: (identifier) @func
					arguments: (_) @args) @call
				
				(identifier) @identifier
			]],

            go = [[
				(assignment_statement
					left: (expression_list (identifier) @var)
					right: (_) @value) @assignment
				
				(short_var_declaration
					left: (expression_list (identifier) @var)
					right: (_) @value) @declaration
				
				(call_expression
					function: (identifier) @func
					arguments: (_) @args) @call
				
				(identifier) @identifier
			]],

            python = [[
				(assignment
					left: (identifier) @var
					right: (_) @value) @assignment
				
				(call
					function: (identifier) @func
					arguments: (_) @args) @call
				
				(identifier) @identifier
			]],

            lua = [[
				(assignment_statement
					(variable_list (identifier) @var)
					(expression_list (_) @value)) @assignment
				
				(local_variable_declaration
					(variable_list (identifier) @var)
					(expression_list (_) @value)) @declaration
				
				(function_call
					name: (identifier) @func
					arguments: (_) @args) @call
				
				(identifier) @identifier
			]],

            javascript = [[
				(assignment_expression
					left: (identifier) @var
					right: (_) @value) @assignment
				
				(variable_declarator
					name: (identifier) @var
					value: (_) @value) @declaration
				
				(call_expression
					function: (identifier) @func
					arguments: (_) @args) @call
				
				(identifier) @identifier
			]],
        }

        local query_string = queries[lang]
        if not query_string then
            return variables, "No query available for language: " .. lang
        end

        local ok, query = pcall(vim.treesitter.query.parse, lang, query_string)
        if not ok then
            return variables, "Failed to parse query for " .. lang
        end

        local buf = vim.api.nvim_get_current_buf()
        local lines = get_source_lines()

        for id, node, metadata in query:iter_captures(root, buf, 0, -1) do
            local capture_name = query.captures[id]
            local row, col = node:start()
            local text = vim.treesitter.get_node_text(node, buf)
            local line_num = row + 1

            -- Store debug info for line validation
            variables.debug_info[text] = variables.debug_info[text] or {}
            table.insert(variables.debug_info[text], {
                capture = capture_name,
                line = line_num,
                node_text = text,
                source_line = lines[line_num] or "",
            })

            if capture_name == "var" then
                local parent = node:parent()
                local parent_type = parent:type()

                if parent_type:match("assignment") or parent_type:match("declaration") then
                    local value_node = nil
                    for child in parent:iter_children() do
                        if
                            child ~= node
                            and not child:type():match("operator")
                            and not child:type():match("punctuation")
                        then
                            value_node = child
                            break
                        end
                    end

                    if value_node then
                        local value_text = vim.treesitter.get_node_text(value_node, buf)
                        local value_line = value_node:start() + 1

                        variables.assignments[text] = {
                            node = node,
                            line = line_num,
                            value_text = value_text,
                            value_node = value_node,
                            value_line = value_line,
                            source_line = lines[line_num] or "",
                        }

                        if value_text:match("[%+%-%*/%%]") or value_text:match("%(.*%)") then
                            variables.expressions[text] = {
                                node = node,
                                line = line_num,
                                expression = value_text,
                                expression_node = value_node,
                                source_line = lines[line_num] or "",
                            }
                        end
                    end
                end
            elseif capture_name == "func" then
                local parent = node:parent()
                local grandparent = parent:parent()

                if
                    grandparent and (grandparent:type():match("assignment") or grandparent:type():match("declaration"))
                then
                    local var_node = nil
                    for child in grandparent:iter_children() do
                        if child:type() == "identifier" and child ~= node then
                            var_node = child
                            break
                        end
                    end

                    if var_node then
                        local var_name = vim.treesitter.get_node_text(var_node, buf)
                        local var_line = var_node:start() + 1

                        variables.function_calls[var_name] = {
                            node = var_node,
                            line = var_line,
                            function_name = text,
                            call_node = parent,
                            source_line = lines[var_line] or "",
                        }
                    end
                end
            elseif capture_name == "identifier" then
                if not variables.references[text] then
                    variables.references[text] = {}
                end
                table.insert(variables.references[text], {
                    node = node,
                    line = line_num,
                    col = col + 1,
                    source_line = lines[line_num] or "",
                })
            end
        end

        return variables, nil
    end

    local function analyze_expression_safety(expr_text, expr_node, variables)
        local safety_issues = {}

        if expr_text:match('^".*"$') or expr_text:match("^'.*'$") then
            return safety_issues
        end

        if expr_text:match("/%s*0%s*[^%d%.]") or expr_text:match("/%s*0%s*$") then
            table.insert(safety_issues, "potential_division_by_zero")
        end

        local buf = vim.api.nvim_get_current_buf()
        local parser, _ = get_parser()
        if parser then
            local lang = get_language()
            local identifier_query = vim.treesitter.query.parse(lang, "(identifier) @id")

            for id, id_node in identifier_query:iter_captures(expr_node, buf) do
                local var_name = vim.treesitter.get_node_text(id_node, buf)
                local expr_line = expr_node:start() + 1
                local var_assignment = variables.assignments[var_name]

                if not var_assignment or var_assignment.line >= expr_line then
                    table.insert(safety_issues, "uninitialized_variable_" .. var_name)
                end
            end
        end

        local lang = get_language()
        if lang == "c" or lang == "cpp" then
            if expr_text:match("malloc") or expr_text:match("new%s*%[") then
                table.insert(safety_issues, "dynamic_allocation")
            end
        elseif lang == "rust" then
            if expr_text:match("unwrap") or expr_text:match("expect") then
                table.insert(safety_issues, "potential_panic")
            end
        elseif lang == "go" then
            if expr_text:match("%*") and not expr_text:match("nil") then
                table.insert(safety_issues, "potential_nil_dereference")
            end
        end

        return safety_issues
    end

    local function detect_magic_numbers_in_source(variables)
        local magic_issues = {}

        if not variables or not variables.assignments or not variables.expressions then
            return magic_issues
        end

        local function is_likely_constant_name(var_name)
            return var_name:match("^[A-Z_][A-Z0-9_]*$") or
                var_name:match("^k[A-Z]") or
                var_name:match("CONST") or
                var_name:match("MAX") or
                var_name:match("MIN") or
                var_name:match("SIZE") or
                var_name:match("COUNT") or
                var_name:match("LIMIT")
        end

        local function is_contextual_constant(value, context_line)
            local context_lower = context_line:lower()

            if value == "80" and context_lower:match("port") then return true end
            if value == "443" and context_lower:match("https") then return true end
            if value == "22" and context_lower:match("ssh") then return true end
            if value == "3306" and context_lower:match("mysql") then return true end
            if value == "5432" and context_lower:match("postgres") then return true end

            if value == "24" and context_lower:match("hour") then return true end
            if value == "60" and (context_lower:match("minute") or context_lower:match("second")) then return true end
            if value == "365" and context_lower:match("day") then return true end

            if value == "100" and context_lower:match("percent") then return true end
            if value == "1000" and context_lower:match("milli") then return true end

            return false
        end

        for var_name, assignment in pairs(variables.assignments) do
            if assignment.value_text and assignment.value_text:match("^%-?%d+%.?%d*$") then
                local numeric_value = assignment.value_text
                local source_line = assignment.source_line or ""

                if is_likely_constant_name(var_name) then
                    goto continue
                end

                if is_contextual_constant(numeric_value, source_line) then
                    goto continue
                end

                for category, values in pairs(value_patterns.anti_magic_numbers) do
                    for _, magic_val in ipairs(values) do
                        if numeric_value == magic_val then
                            table.insert(magic_issues, {
                                type = "magic_number",
                                category = category,
                                variable = var_name,
                                value = numeric_value,
                                line = assignment.line,
                                source_line = source_line,
                                suggestion = string.format("Consider using a named constant for %s", magic_val),
                            })
                            break
                        end
                    end
                end

                for pattern_name, pattern in pairs(value_patterns.magic_number_patterns) do
                    if numeric_value:match(pattern) then
                        table.insert(magic_issues, {
                            type = "magic_pattern",
                            pattern = pattern_name,
                            variable = var_name,
                            value = numeric_value,
                            line = assignment.line,
                            source_line = source_line,
                            suggestion = string.format("Suspicious %s pattern in number %s", pattern_name, numeric_value),
                        })
                    end
                end
            end

            ::continue::
        end

        for var_name, expr_info in pairs(variables.expressions) do
            local expr = expr_info.expression
            local source_line = expr_info.source_line or ""

            for magic_val in expr:gmatch("%d+") do
                if is_contextual_constant(magic_val, source_line) then
                    goto continue_expr
                end

                for category, values in pairs(value_patterns.anti_magic_numbers) do
                    for _, check_val in ipairs(values) do
                        if magic_val == check_val then
                            table.insert(magic_issues, {
                                type = "magic_in_expression",
                                category = category,
                                variable = var_name,
                                value = magic_val,
                                expression = expr,
                                line = expr_info.line,
                                source_line = source_line,
                                suggestion = string.format("Magic number %s in expression", magic_val),
                            })
                            break
                        end
                    end
                end

                ::continue_expr::
            end
        end

        return magic_issues
    end

    local function find_best_source_line(suspicious_value, variables)
        local candidates = {}
        local lines = get_source_lines()

        -- Check assignments
        for var_name, assignment in pairs(variables.assignments) do
            if assignment.value_text and assignment.value_text:find(suspicious_value, 1, true) then
                local valid, line_content = validate_line_mapping(assignment.line, var_name, suspicious_value)
                if valid then
                    table.insert(candidates, {
                        type = "assignment",
                        variable = var_name,
                        line = assignment.line,
                        value = assignment.value_text,
                        confidence = 3, -- High confidence
                        source_line = line_content,
                    })
                end
            end
        end

        -- Check expressions
        for var_name, expression in pairs(variables.expressions) do
            if expression.expression:find(suspicious_value, 1, true) then
                local valid, line_content = validate_line_mapping(expression.line, var_name, suspicious_value)
                if valid then
                    table.insert(candidates, {
                        type = "expression",
                        variable = var_name,
                        line = expression.line,
                        expression = expression.expression,
                        confidence = 2, -- Medium confidence
                        source_line = line_content,
                    })
                end
            end
        end

        -- Check function calls - be more precise
        for var_name, call_info in pairs(variables.function_calls) do
            local source_line = call_info.source_line
            if source_line:find(var_name, 1, true) and source_line:find(call_info.function_name, 1, true) then
                -- Only consider if the suspicious value appears in nearby output context
                -- This is more conservative than the original heuristic
                table.insert(candidates, {
                    type = "function_call",
                    variable = var_name,
                    line = call_info.line,
                    function_name = call_info.function_name,
                    confidence = 1, -- Lower confidence
                    source_line = source_line,
                })
            end
        end

        -- Fallback: search source lines directly
        if #candidates == 0 then
            local found_line = find_line_with_pattern(lines, suspicious_value)
            if found_line then
                table.insert(candidates, {
                    type = "direct_match",
                    variable = nil,
                    line = found_line,
                    value = suspicious_value,
                    confidence = 2,
                    source_line = lines[found_line],
                })
            end
        end

        -- Sort by confidence and return the best match
        table.sort(candidates, function(a, b)
            return a.confidence > b.confidence
        end)

        return candidates[1] -- Return the best candidate, or nil if none found
    end

    -- Main analysis
    local variables, parse_error = extract_variables_with_treesitter()

    if parse_error then
        table.insert(suspicious, {
            filename = vim.fn.expand("%"),
            lnum = 1,
            col = 1,
            text = "Treesitter analysis failed: " .. parse_error .. " (using basic analysis)",
            severity = "info",
        })
    end

    local magic_numbers = detect_magic_numbers_in_source(variables)
    for _, issue in ipairs(magic_numbers) do
        local severity = "info"
        if issue.category == "suspicious_constants" or
            issue.type == "magic_pattern" then
            severity = "warning"
        end

        table.insert(suspicious, {
            filename = vim.fn.expand("%"),
            lnum = issue.line,
            col = 1,
            text = string.format(
                "Magic number detected in '%s': %s (%s)",
                issue.variable or "expression",
                issue.value,
                issue.suggestion
            ),
            display = string.format(
                "MAGIC[%s]: %s:%d - %s = %s (%s)",
                (issue.category or issue.pattern or "PATTERN"):upper(),
                vim.fn.fnamemodify(vim.fn.expand("%"), ":t"),
                issue.line,
                issue.variable or "expr",
                issue.value,
                issue.category or issue.pattern or "unknown"
            ),
            severity = severity,
        })
    end

    -- Analyze expressions for safety issues
    for var_name, expr_info in pairs(variables.expressions) do
        local safety_issues = analyze_expression_safety(expr_info.expression, expr_info.expression_node, variables)

        for _, issue in ipairs(safety_issues) do
            table.insert(suspicious, {
                filename = vim.fn.expand("%"),
                lnum = expr_info.line,
                col = 1,
                text = string.format("Expression safety issue in '%s': %s", var_name, issue),
                display = string.format(
                    "EXPRESSION[SAFETY]: %s:%d - %s in '%s' = %s",
                    vim.fn.fnamemodify(vim.fn.expand("%"), ":t"),
                    expr_info.line,
                    issue:gsub("_", " "):upper(),
                    var_name,
                    expr_info.expression
                ),
                severity = "warning",
            })
        end
    end

    -- Analyze output for suspicious patterns
    for pattern_type, patterns in pairs(value_patterns) do
        for _, pattern in ipairs(patterns) do
            local matches = {}

            if pattern_type == "memory_leak" then
                for match in output:gmatch(pattern) do
                    table.insert(matches, match)
                end
            else
                if output:find(pattern, 1, true) then
                    table.insert(matches, pattern)
                end
            end

            for _, match in ipairs(matches) do
                local best_match = find_best_source_line(match, variables)

                if best_match then
                    local context = ""
                    if best_match.type == "assignment" then
                        context = "assigned: " .. best_match.value
                    elseif best_match.type == "expression" then
                        context = "expression: " .. best_match.expression
                    elseif best_match.type == "function_call" then
                        context = "from function: " .. best_match.function_name
                    elseif best_match.type == "direct_match" then
                        context = "found in source: " .. (best_match.source_line or ""):sub(1, 50)
                    end

                    table.insert(suspicious, {
                        filename = vim.fn.expand("%"),
                        lnum = best_match.line,
                        col = 1,
                        text = string.format(
                            "Suspicious %s%s: %s",
                            pattern_type,
                            best_match.variable and (" in variable '" .. best_match.variable .. "'") or "",
                            context
                        ),
                        display = string.format(
                            "SUSPICIOUS[%s]: %s:%d%s - %s",
                            pattern_type:upper(),
                            vim.fn.fnamemodify(vim.fn.expand("%"), ":t"),
                            best_match.line,
                            best_match.variable and (" Variable '" .. best_match.variable .. "'") or "",
                            context
                        ),
                        severity = pattern_type == "overflow" and "error" or "warning",
                    })
                else
                    -- Only report without line context if we genuinely can't find the source
                    -- This reduces false positives from random output line mappings
                    table.insert(suspicious, {
                        filename = vim.fn.expand("%"),
                        lnum = 1, -- Default to line 1 instead of random output line
                        col = 1,
                        text = string.format(
                            "Suspicious %s value in output (source location unknown): %s",
                            pattern_type,
                            match
                        ),
                        display = string.format(
                            "SUSPICIOUS[%s]: Runtime value '%s' (source unknown)",
                            pattern_type:upper(),
                            match
                        ),
                        severity = "info",
                    })
                end
            end
        end
    end

    local runtime_issues = M.analyze_runtime_patterns(output, variables)
    for _, issue in ipairs(runtime_issues) do
        table.insert(suspicious, issue)
    end

    return suspicious
end

return M
