local M = {}

function M.analyze_suspicious_patterns(output)
	local suspicious = {}

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
		},
	}

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

	return suspicious
end

return M
