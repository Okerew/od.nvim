local M = {}

-- We keep the old logic for go, cargo and cmake tests as I find testing with them easier that way.
function M.split_into_chunks(output, lang)
    local chunks = {}

    if lang == "python" then
        local eq_pattern = "\n=+\n"
        local dh_pattern = "\n-+\n"

        local blocks = vim.split(output, eq_pattern)

        for _, block in ipairs(blocks) do
            block =
                block:gsub("\27%[[0-9;]*m", ""):gsub("^%s*\n", ""):gsub("%s*$", "") -- strip ANSI

            if block == "" then
                goto continue
            end

            local sep_start, sep_end = block:find(dh_pattern)

            if sep_start then
                local header = block:sub(1, sep_start - 1):gsub("%s*$", "")

                local traceback = block:sub(sep_end + 1):gsub("^%s*\n", ""):gsub("%s*$", "")

                if
                    header:match("^FAIL:") or header:match("^ERROR:") or header:match("^FAILED") or
                    header:match("^INTERNALERROR")
                then
                    local filename, lnum = traceback:match('File "(.-)", line (%d+)')

                    table.insert(
                        chunks,
                        {
                            header = header,
                            body = traceback,
                            filename = filename,
                            lnum = tonumber(lnum) or 1
                        }
                    )
                end
            end

            for line in block:gmatch("[^\n]+") do
                line = line:gsub("^%s+", ""):gsub("%s+$", "")

                if line:match("^FAILED%s+") then
                    local file = line:match("^FAILED%s+([^:]+%.py)") or vim.fn.expand("%")

                    table.insert(
                        chunks,
                        {
                            header = line,
                            body = line,
                            filename = file,
                            lnum = 1
                        }
                    )
                end
            end

            if
                block:match("Traceback %(most recent call last%)") or block:match("ModuleNotFoundError:") or
                block:match("ImportError:") or
                block:match("SyntaxError:") or
                block:match("AssertionError:") or
                block:match("Exception:")
            then
                local filename, lnum = block:match('File "(.-)", line (%d+)')

                table.insert(
                    chunks,
                    {
                        header = "PYTHON ERROR",
                        body = block,
                        filename = filename or vim.fn.expand("%"),
                        lnum = tonumber(lnum) or 1
                    }
                )
            end

            if
                block:match("^WARNING") or block:match("\nWARNING") or block:match("^Warning:") or
                block:match("\nWarning:")
            then
                table.insert(
                    chunks,
                    {
                        header = "WARNING",
                        body = block,
                        filename = vim.fn.expand("%"),
                        lnum = 1
                    }
                )
            end

            ::continue::
        end
    elseif lang == "lua" then
        local header, body_lines = nil, {}

        local function push_chunk(filename, lnum)
            if header then
                table.insert(
                    chunks,
                    {
                        header = header,
                        body = table.concat(body_lines, "\n"),
                        filename = filename,
                        lnum = lnum or 1
                    }
                )
            end

            header = nil
            body_lines = {}
        end

        for raw_line in output:gmatch("[^\n]+") do
            local line =
                raw_line:gsub("\27%[[0-9;]*m", ""):gsub("%s+$", "")

            local fail_name =
                line:match("^%s*[✗✘x]%s+(.+)") or line:match("^%s*Failure:%s+(.+)") or line:match("^%s*Error:%s+(.+)")

            if fail_name then
                push_chunk()

                header = "FAIL: " .. fail_name
                body_lines = {}
            elseif
                line:match("assertion failed") or line:match("^.-:%d+:%s+attempt to") or line:match("^.-:%d+:%s+module") or
                line:match("^.-:%d+:%s+unexpected") or
                line:match("^.-:%d+:%s+syntax error")
            then
                if not header then
                    header = "RUNTIME ERROR"
                end

                table.insert(body_lines, line)
            elseif line:match("^stack traceback:") or line:match("^Traceback:") then
                if not header then
                    header = "TRACEBACK"
                end

                table.insert(body_lines, line)
            elseif line:match("^.-:%d+:") then
                if not header then
                    header = "FILE ERROR"
                end

                table.insert(body_lines, line)
            elseif line:match("^Warning:") or line:match("^WARNING:") then
                if not header then
                    header = "WARNING"
                end

                table.insert(body_lines, line)
            elseif header and (line:match("^%s+") or line == "") then
                table.insert(body_lines, line)
            elseif header then
                local filename, lnum

                local body = table.concat(body_lines, "\n")

                filename, lnum = body:match("([%w%._/-]+%.lua):(%d+)") or line:match("([%w%._/-]+%.lua):(%d+)")

                push_chunk(filename, tonumber(lnum))
            end
        end

        if header then
            local filename, lnum

            local body = table.concat(body_lines, "\n")

            filename, lnum = body:match("([%w%._/-]+%.lua):(%d+)")

            push_chunk(filename, tonumber(lnum))
        end
    elseif lang == "javascript" or lang == "typescript" then
        local current = nil

        local function push_current()
            if current then
                current.body = table.concat(current.body_lines, "\n")

                table.insert(
                    chunks,
                    {
                        header = current.header,
                        body = current.body,
                        filename = current.filename,
                        lnum = current.lnum,
                        col = current.col,
                        type = current.type
                    }
                )

                current = nil
            end
        end

        local function new_chunk(header, chunk_type, filename, lnum, col)
            push_current()

            current = {
                header = header,
                body_lines = {},
                filename = filename,
                lnum = lnum or 1,
                col = col or 1,
                type = chunk_type or "error"
            }
        end

        for raw_line in output:gmatch("[^\n]+") do
            local line = raw_line:gsub("\27%[[0-9;]*m", "") -- strip ANSI colors

            if line:match("^FAIL%s+") then
                local file = line:match("^FAIL%s+(.+%.[jt]sx?)")

                new_chunk("FAIL: " .. (file or line), "test-fail", file)
            elseif line:match("^%s*● ") then
                local test_name = line:match("^%s*● (.+)") or line

                new_chunk("FAIL: " .. test_name, "assertion-fail")
            elseif line:match("at ") then
                local file, lnum, col = line:match("%((.-):(%d+):(%d+)%)") or line:match("at (.-):(%d+):(%d+)")

                if file then
                    if not current then
                        new_chunk("STACKTRACE: " .. file, "stacktrace", file, tonumber(lnum), tonumber(col))
                    end

                    table.insert(current.body_lines, line)
                elseif current then
                    table.insert(current.body_lines, line)
                end
            elseif line:match("^%s*Expected:") or line:match("^%s*Received:") or line:match("^%s*Difference:") then
                if not current then
                    new_chunk("ASSERTION FAILURE", "assertion-fail")
                end

                table.insert(current.body_lines, line)
            elseif line:match("^Warning:") or line:match("^warning") then
                new_chunk("WARNING", "warning")

                table.insert(current.body_lines, line)
            elseif current and (line:match("^%s+") or line == "") then
                table.insert(current.body_lines, line)
            elseif
                line:match("SyntaxError") or line:match("ReferenceError") or line:match("TypeError") or
                line:match("UnhandledPromiseRejection")
            then
                new_chunk("RUNTIME ERROR", "runtime-error")

                table.insert(current.body_lines, line)
            else
                push_current()
            end
        end

        push_current()
    end

    return chunks
end

function M.chunks_to_items(chunks, lang, fallback_file)
    local errors, warnings = {}, {}

    for _, chunk in ipairs(chunks) do
        local full_block = chunk.header .. "\n" .. chunk.body
        local file, line_num

        if lang == "python" then
            for f, l in chunk.body:gmatch('File "([^"]+)", line (%d+)') do
                file = f
                line_num = l
            end
        elseif lang == "lua" then
            file, line_num = chunk.body:match("([^%s]+%.lua):(%d+)")
        elseif lang == "javascript" or lang == "typescript" then
            file, line_num = chunk.body:match("([^%(]+%.[jt]sx?):(%d+):%d+")
            if file then
                file = file:match("^%s*(.-)%s*$")
            end
        end

        local short_header = chunk.header:match("[^\n]+") or "error"
        local display =
            string.format(
                "%s  (%s:%s)",
                short_header:sub(1, 50),
                file and vim.fn.fnamemodify(file, ":t") or "?",
                line_num or "?"
            )

        local item = {
            filename = file or fallback_file,
            lnum = tonumber(line_num) or 1,
            text = full_block,
            log = full_block,
            display = display
        }

        if chunk.header:match("^WARN") then
            table.insert(warnings, item)
        else
            table.insert(errors, item)
        end
    end

    return errors, warnings
end

return M
