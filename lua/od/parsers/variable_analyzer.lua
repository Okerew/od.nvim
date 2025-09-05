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
			"0x100000000",
			"0x10000000000000000",
			"0x80000001",
			"0x7ffffffe",
			"65535",
			"65536",
			"32767",
			"32768",
			"-32768",
			"-32769",
			"0xffff",
			"0x10000",
			"0x7fff",
			"0x8000",
			"0x8001",
			"255",
			"256",
			"127",
			"128",
			"-128",
			"-129",
			"0xff",
			"0x100",
			"0x7f",
			"0x80",
			"0x81",
			-- Float overflow values
			"3.40282347e%+38",
			"1.7976931348623157e%+308",
			"-3.40282347e%+38",
			"-1.7976931348623157e%+308",
			"FLT_MAX",
			"DBL_MAX",
			"LDBL_MAX",
		},
		null_ptr = {
			"0x0",
			"<nil>",
			"nil",
			"NULL",
			"(null)",
			"nullptr",
			-- EXPANDED:
			"0x00000000",
			"0x0000000000000000",
			"0000:0000",
			"null",
			"Null",
			"NULLPTR",
			"void%*%)0",
			"((void%*)0)",
			"(%(%s*void%s*%*%s*%)%s*0%s*)",
		},
		uninitialized = {
			"0xcccccccc",
			"0xdeadbeef",
			"0xbaadf00d",
			"0xfeedface",
			"0xcdcdcdcd",
			"0xabababab",
			"0x12345678",
			"0xcccccccccccccccc",
			"0xdeadbeefdeadbeef",
			"0xbaadf00dbaadf00d",
			"0xfeedfacefeedface",
			"0xcdcdcdcdcdcdcdcd",
			"0xababababababab",
			"0x1234567812345678",
			"0xdeadc0de",
			"0xcafebabe",
			"0xfacefeed",
			"0x8badf00d",
			"0xdeaddead",
			"0xbeefbeef",
			"0xcafecafe",
			"0xa5a5a5a5",
			"0x5a5a5a5a",
			"0xa1a1a1a1",
			"0x1a1a1a1a",
			"0xb16b00b5",
			"0x0d15ea5e",
			"0xc0edbabe",
			"0x0defaced",
			-- Pattern values often used by allocators/debuggers
			"3735928559",
			"3405691582",
			"2864434397",
			"4277009102",
			"-559038737",
			"-889275714",
			"-1430532899",
			"-17958194",
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
			"+inf",
			"-inf",
			"+nan",
			"-nan",
			"1.#INF",
			"1.#QNAN",
			"1.#SNAN",
			"1.#IND",
			"qnan",
			"snan",
			"ind",
			"QNAN",
			"SNAN",
			"IND",
			"inf.*",
			"nan.*",
			".*inf",
			".*nan",
			"0x7ff8000000000000",
			"0x7ff0000000000000",
			"0xfff0000000000000",
			"0x7fc00000",
			"0x7f800000",
			"0xff800000",
		},
		memory_leak = {
			"leaked",
			"not.*freed",
			"memory.*leak",
			"heap.*leak",
			"still.*reachable",
			"definitely.*lost",
			"possibly.*lost",
			"indirectly.*lost",
			"suppressed.*errors",
			"unfreed",
			"unreleased",
			"not.*deallocated",
			"not.*released",
			"orphaned.*memory",
			"dangling.*pointer",
			"use.*after.*free",
			"double.*free",
			"invalid.*free",
			"heap.*corruption",
		},
		buffer_overflow = {
			"buffer overflow",
			"stack smashing",
			"heap corruption",
			"stack.*overflow",
			"heap.*overflow",
			"buffer.*overrun",
			"stack.*overrun",
			"smash.*stack",
			"corrupt.*heap",
			"write.*past.*end",
			"read.*past.*end",
			"bounds.*violation",
			"array.*bounds",
			"out.*of.*bounds",
			"segmentation.*fault",
			"segfault",
			"access.*violation",
			"protection.*fault",
			"stack.*canary",
			"stack.*protector",
			"fortify.*source",
			"AddressSanitizer",
			"ASAN",
			"buffer.*underrun",
			"heap.*buffer.*overflow",
			"stack.*buffer.*overflow",
		},
		format_string = {
			"%s%s%s%s",
			"%d%d%d%d",
			"%x%x%x%x",
			"%n",
			"%n%n",
			"%%%s",
			"%%%d",
			"%%%x",
			"%%%c",
			"%%%p",
			-- Format string vulnerabilities
			"%.*s",
			"%99s",
			"%999s",
			"%9999s",
			"%hn",
			"%hhn",
			"%lln",
			"%zn",
			"%tn",
			"%jn",
		},
		race_condition = {
			"race.*condition",
			"time.*of.*check",
			"time.*of.*use",
			"TOCTOU",
			"thread.*unsafe",
			"not.*thread.*safe",
			"data.*race",
			"concurrent.*access",
			"synchronization.*error",
		},
		crypto_weakness = {
			"MD5",
			"SHA1",
			"DES",
			"RC4",
			"weak.*cipher",
			"weak.*hash",
			"insecure.*random",
			"predictable.*random",
			"weak.*key",
			"hardcoded.*key",
			"default.*password",
			"weak.*password",
		},
		injection = {
			"SQL.*injection",
			"command.*injection",
			"code.*injection",
			"script.*injection",
			"LDAP.*injection",
			"XPath.*injection",
			"eval%(",
			"system%(",
			"exec%(",
			"shell_exec%(",
		},
	}

	-- Language-specific patterns and keywords
	local lang_config = {
		c = {
			comment_patterns = { "//.*", "/%*.*%*/" },
			keywords = {
				["if"] = true,
				["else"] = true,
				["for"] = true,
				["while"] = true,
				["do"] = true,
				["switch"] = true,
				["case"] = true,
				["default"] = true,
				["break"] = true,
				["continue"] = true,
				["return"] = true,
				["goto"] = true,
				["typedef"] = true,
				["sizeof"] = true,
				["int"] = true,
				["float"] = true,
				["double"] = true,
				["char"] = true,
				["void"] = true,
				["short"] = true,
				["long"] = true,
				["signed"] = true,
				["unsigned"] = true,
				["printf"] = true,
				["scanf"] = true,
				["malloc"] = true,
				["free"] = true,
				["calloc"] = true,
				["realloc"] = true,
				["struct"] = true,
				["union"] = true,
				["enum"] = true,
				["const"] = true,
				["static"] = true,
				["extern"] = true,
				["auto"] = true,
				["register"] = true,
				["volatile"] = true,
				["inline"] = true,
				-- Common functions that aren't variables
				["strlen"] = true,
				["strcmp"] = true,
				["strcpy"] = true,
				["strcat"] = true,
				["memcpy"] = true,
				["memset"] = true,
				["fopen"] = true,
				["fclose"] = true,
				["fread"] = true,
				["fwrite"] = true,
				["fprintf"] = true,
				["fscanf"] = true,
				-- Literals and constants
				["true"] = true,
				["false"] = true,
				["TRUE"] = true,
				["FALSE"] = true,
				["NULL"] = true,
			},
			assignment_patterns = {
				"([%a_][%w_]*)%s*=%s*([^;,\n=!<>]+)",
				"([%a_][%w_]*%s*%[[^%]]*%])%s*=%s*([^;,\n=!<>]+)",
				"(%*+%s*[%a_][%w_]*)%s*=%s*([^;,\n=!<>]+)",
				"([%a_][%w_]*%.[%a_][%w_]*)%s*=%s*([^;,\n=!<>]+)",
				"([%a_][%w_]*%->[%a_][%w_]*)%s*=%s*([^;,\n=!<>]+)",
				"const%s+[%w_*%s]+%s+([%a_][%w_]*)%s*=%s*([^;,\n=!<>]+)",
				"static%s+[%w_*%s]+%s+([%a_][%w_]*)%s*=%s*([^;,\n=!<>]+)",
				"extern%s+[%w_*%s]+%s+([%a_][%w_]*)%s*=%s*([^;,\n=!<>]+)",

				-- Multi-dimensional arrays
				"([%a_][%w_]*%s*%[[^%]]*%]%s*%[[^%]]*%])%s*=%s*([^;,\n=!<>]+)",
				"([%a_][%w_]*%s*%[[^%]]*%]%s*%[[^%]]*%]%s*%[[^%]]*%])%s*=%s*([^;,\n=!<>]+)",
				-- Pointer arithmetic assignments
				"(%([%*%s]*[%a_][%w_]*%))%s*=%s*([^;,\n=!<>]+)",
				"(%*%([%a_][%w_]*%s*[%+%-]%s*%d+%))%s*=%s*([^;,\n=!<>]+)",
				-- Function pointer assignments
				"([%a_][%w_]*)%s*=%s*%&?([%a_][%w_]*)",
				-- Compound operators
				"([%a_][%w_]*)%s*%+=%s*([^;,\n=!<>]+)",
				"([%a_][%w_]*)%s*%-=%s*([^;,\n=!<>]+)",
				"([%a_][%w_]*)%s*%*=%s*([^;,\n=!<>]+)",
				"([%a_][%w_]*)%s*/=%s*([^;,\n=!<>]+)",
				"([%a_][%w_]*)%s*%%=%s*([^;,\n=!<>]+)",
				"([%a_][%w_]*)%s*&=%s*([^;,\n=!<>]+)",
				"([%a_][%w_]*)%s*|=%s*([^;,\n=!<>]+)",
				"([%a_][%w_]*)%s*%^=%s*([^;,\n=!<>]+)",
				"([%a_][%w_]*)%s*<<=%s*([^;,\n=!<>]+)",
				"([%a_][%w_]*)%s*>>=%s*([^;,\n=!<>]+)",
				-- Increment/decrement
				"(%+%+[%a_][%w_]*)",
				"([%a_][%w_]*%+%+)",
				"(%-%-[%a_][%w_]*)",
				"([%a_][%w_]*%-%-)",
				-- Multiple variable declarations
				"[%w_*%s]+%s+([%a_][%w_]*)%s*,%s*([%a_][%w_]*)%s*=%s*([^;,\n=!<>]+)",
				"[%w_*%s]+%s+([%a_][%w_]*)%s*=%s*([^;,\n=!<>]+)%s*,%s*([%a_][%w_]*)%s*=%s*([^;,\n=!<>]+)",
				-- Ternary operator assignments
				"([%a_][%w_]*)%s*=%s*([^;,\n]*%?[^;,\n]*:[^;,\n]*)",
				-- Cast assignments
				"([%a_][%w_]*)%s*=%s*%([%w_*%s]+%)%s*([^;,\n=!<>]+)",
				-- Union/struct member assignments in initialization
				"%.([%a_][%w_]*)%s*=%s*([^;,\n=!<>]+)",
				-- Bit field assignments
				"([%a_][%w_]*%.[%a_][%w_]*)%s*=%s*([^;,\n=!<>]+)",
			},
		},
		cpp = {
			comment_patterns = { "//.*", "/%*.*%*/" },
			keywords = {
				["if"] = true,
				["else"] = true,
				["for"] = true,
				["while"] = true,
				["do"] = true,
				["switch"] = true,
				["case"] = true,
				["default"] = true,
				["break"] = true,
				["continue"] = true,
				["return"] = true,
				["goto"] = true,
				["typedef"] = true,
				["sizeof"] = true,
				["int"] = true,
				["float"] = true,
				["double"] = true,
				["char"] = true,
				["void"] = true,
				["bool"] = true,
				["short"] = true,
				["long"] = true,
				["signed"] = true,
				["unsigned"] = true,
				["auto"] = true,
				["class"] = true,
				["struct"] = true,
				["namespace"] = true,
				["public"] = true,
				["private"] = true,
				["protected"] = true,
				["virtual"] = true,
				["override"] = true,
				["const"] = true,
				["static"] = true,
				["extern"] = true,
				["inline"] = true,
				["mutable"] = true,
				["template"] = true,
				["typename"] = true,
				["nullptr"] = true,
				["this"] = true,
				["std"] = true,
				["cout"] = true,
				["cin"] = true,
				["endl"] = true,
				["vector"] = true,
				["string"] = true,
				["map"] = true,
				["set"] = true,
				["list"] = true,
				["new"] = true,
				["delete"] = true,
				["try"] = true,
				["catch"] = true,
				["throw"] = true,
				-- Literals and constants
				["true"] = true,
				["false"] = true,
				["TRUE"] = true,
				["FALSE"] = true,
				["NULL"] = true,
			},
			assignment_patterns = {
				"([%a_][%w_:]*<?[%w_,:%s]*>?)%s*=%s*([^;,\n=!<>]+)",
				"([%a_][%w_]*%s*%[[^%]]*%])%s*=%s*([^;,\n=!<>]+)",
				"(%*+%s*[%a_][%w_]*)%s*=%s*([^;,\n=!<>]+)",
				"([%a_][%w_]*%.[%a_][%w_]*)%s*=%s*([^;,\n=!<>]+)",
				"([%a_][%w_]*%->[%a_][%w_]*)%s*=%s*([^;,\n=!<>]+)",
				"([%a_][%w_]*::[%a_][%w_]*)%s*=%s*([^;,\n=!<>]+)",
				"const%s+[%w_*%s]+%s+([%a_][%w_]*)%s*=%s*([^;,\n=!<>]+)",
				"static%s+[%w_*%s]+%s+([%a_][%w_]*)%s*=%s*([^;,\n=!<>]+)",
				"extern%s+[%w_*%s]+%s+([%a_][%w_]*)%s*=%s*([^;,\n=!<>]+)",

				-- Multi-dimensional arrays
				"([%a_][%w_]*%s*%[[^%]]*%]%s*%[[^%]]*%])%s*=%s*([^;,\n=!<>]+)",
				"([%a_][%w_]*%s*%[[^%]]*%]%s*%[[^%]]*%]%s*%[[^%]]*%])%s*=%s*([^;,\n=!<>]+)",
				-- Pointer arithmetic assignments
				"(%([%*%s]*[%a_][%w_]*%))%s*=%s*([^;,\n=!<>]+)",
				"(%*%([%a_][%w_]*%s*[%+%-]%s*%d+%))%s*=%s*([^;,\n=!<>]+)",
				-- Function pointer assignments
				"([%a_][%w_]*)%s*=%s*%&?([%a_][%w_]*)",
				-- Compound operators
				"([%a_][%w_]*)%s*%+=%s*([^;,\n=!<>]+)",
				"([%a_][%w_]*)%s*%-=%s*([^;,\n=!<>]+)",
				"([%a_][%w_]*)%s*%*=%s*([^;,\n=!<>]+)",
				"([%a_][%w_]*)%s*/=%s*([^;,\n=!<>]+)",
				"([%a_][%w_]*)%s*%%=%s*([^;,\n=!<>]+)",
				"([%a_][%w_]*)%s*&=%s*([^;,\n=!<>]+)",
				"([%a_][%w_]*)%s*|=%s*([^;,\n=!<>]+)",
				"([%a_][%w_]*)%s*%^=%s*([^;,\n=!<>]+)",
				"([%a_][%w_]*)%s*<<=%s*([^;,\n=!<>]+)",
				"([%a_][%w_]*)%s*>>=%s*([^;,\n=!<>]+)",
				-- Increment/decrement
				"(%+%+[%a_][%w_]*)",
				"([%a_][%w_]*%+%+)",
				"(%-%-[%a_][%w_]*)",
				"([%a_][%w_]*%-%-)",
				-- Multiple variable declarations
				"[%w_*%s]+%s+([%a_][%w_]*)%s*,%s*([%a_][%w_]*)%s*=%s*([^;,\n=!<>]+)",
				"[%w_*%s]+%s+([%a_][%w_]*)%s*=%s*([^;,\n=!<>]+)%s*,%s*([%a_][%w_]*)%s*=%s*([^;,\n=!<>]+)",
				-- Ternary operator assignments
				"([%a_][%w_]*)%s*=%s*([^;,\n]*%?[^;,\n]*:[^;,\n]*)",
				-- Cast assignments
				"([%a_][%w_]*)%s*=%s*%([%w_*%s]+%)%s*([^;,\n=!<>]+)",
				-- Union/struct member assignments in initialization
				"%.([%a_][%w_]*)%s*=%s*([^;,\n=!<>]+)",
				-- Bit field assignments
				"([%a_][%w_]*%.[%a_][%w_]*)%s*=%s*([^;,\n=!<>]+)",
			},
		},
		rust = {
			comment_patterns = { "//.*", "/%*.*%*/" },
			keywords = {
				["let"] = true,
				["mut"] = true,
				["const"] = true,
				["static"] = true,
				["fn"] = true,
				["if"] = true,
				["else"] = true,
				["for"] = true,
				["while"] = true,
				["loop"] = true,
				["match"] = true,
				["return"] = true,
				["break"] = true,
				["continue"] = true,
				["struct"] = true,
				["enum"] = true,
				["impl"] = true,
				["trait"] = true,
				["mod"] = true,
				["use"] = true,
				["pub"] = true,
				["crate"] = true,
				["self"] = true,
				["super"] = true,
				["where"] = true,
				["type"] = true,
				["as"] = true,
				["ref"] = true,
				["move"] = true,
				["i8"] = true,
				["i16"] = true,
				["i32"] = true,
				["i64"] = true,
				["i128"] = true,
				["isize"] = true,
				["u8"] = true,
				["u16"] = true,
				["u32"] = true,
				["u64"] = true,
				["u128"] = true,
				["usize"] = true,
				["f32"] = true,
				["f64"] = true,
				["bool"] = true,
				["char"] = true,
				["str"] = true,
				["String"] = true,
				["Vec"] = true,
				["HashMap"] = true,
				["HashSet"] = true,
				["Option"] = true,
				["Result"] = true,
				["Some"] = true,
				["None"] = true,
				["Ok"] = true,
				["Err"] = true,
				["println"] = true,
				["print"] = true,
				["panic"] = true,
				["assert"] = true,
				["debug_assert"] = true,
				-- Literals
				["true"] = true,
				["false"] = true,
			},
			assignment_patterns = {
				"let%s+mut%s+([%a_][%w_]*)%s*=%s*([^;,\n=!<>]+)",
				"let%s+([%a_][%w_]*)%s*=%s*([^;,\n=!<>]+)",
				"([%a_][%w_]*)%s*=%s*([^;,\n=!<>]+)",
				"([%a_][%w_]*%s*%[[^%]]*%])%s*=%s*([^;,\n=!<>]+)",
				"([%a_][%w_]*%.[%a_][%w_]*)%s*=%s*([^;,\n=!<>]+)",
				"(%*+%s*[%a_][%w_]*)%s*=%s*([^;,\n=!<>]+)",
				"const%s+([%a_][%w_]*)%s*:%s*[%w_<>]+%s*=%s*([^;,\n=!<>]+)",
				"static%s+([%a_][%w_]*)%s*:%s*[%w_<>]+%s*=%s*([^;,\n=!<>]+)",
				"static%s+mut%s+([%a_][%w_]*)%s*:%s*[%w_<>]+%s*=%s*([^;,\n=!<>]+)",

				-- Multi-dimensional arrays
				"([%a_][%w_]*%s*%[[^%]]*%]%s*%[[^%]]*%])%s*=%s*([^;,\n=!<>]+)",
				"([%a_][%w_]*%s*%[[^%]]*%]%s*%[[^%]]*%]%s*%[[^%]]*%])%s*=%s*([^;,\n=!<>]+)",
				-- Pointer arithmetic assignments
				"(%([%*%s]*[%a_][%w_]*%))%s*=%s*([^;,\n=!<>]+)",
				"(%*%([%a_][%w_]*%s*[%+%-]%s*%d+%))%s*=%s*([^;,\n=!<>]+)",
				-- Function pointer assignments
				"([%a_][%w_]*)%s*=%s*%&?([%a_][%w_]*)",
				-- Compound operators
				"([%a_][%w_]*)%s*%+=%s*([^;,\n=!<>]+)",
				"([%a_][%w_]*)%s*%-=%s*([^;,\n=!<>]+)",
				"([%a_][%w_]*)%s*%*=%s*([^;,\n=!<>]+)",
				"([%a_][%w_]*)%s*/=%s*([^;,\n=!<>]+)",
				"([%a_][%w_]*)%s*%%=%s*([^;,\n=!<>]+)",
				"([%a_][%w_]*)%s*&=%s*([^;,\n=!<>]+)",
				"([%a_][%w_]*)%s*|=%s*([^;,\n=!<>]+)",
				"([%a_][%w_]*)%s*%^=%s*([^;,\n=!<>]+)",
				"([%a_][%w_]*)%s*<<=%s*([^;,\n=!<>]+)",
				"([%a_][%w_]*)%s*>>=%s*([^;,\n=!<>]+)",
				-- Increment/decrement
				"(%+%+[%a_][%w_]*)",
				"([%a_][%w_]*%+%+)",
				"(%-%-[%a_][%w_]*)",
				"([%a_][%w_]*%-%-)",
				-- Multiple variable declarations
				"[%w_*%s]+%s+([%a_][%w_]*)%s*,%s*([%a_][%w_]*)%s*=%s*([^;,\n=!<>]+)",
				"[%w_*%s]+%s+([%a_][%w_]*)%s*=%s*([^;,\n=!<>]+)%s*,%s*([%a_][%w_]*)%s*=%s*([^;,\n=!<>]+)",
				-- Ternary operator assignments
				"([%a_][%w_]*)%s*=%s*([^;,\n]*%?[^;,\n]*:[^;,\n]*)",
				-- Cast assignments
				"([%a_][%w_]*)%s*=%s*%([%w_*%s]+%)%s*([^;,\n=!<>]+)",
				-- Union/struct member assignments in initialization
				"%.([%a_][%w_]*)%s*=%s*([^;,\n=!<>]+)",
				-- Bit field assignments
				"([%a_][%w_]*%.[%a_][%w_]*)%s*=%s*([^;,\n=!<>]+)",
			},
		},
		go = {
			comment_patterns = { "//.*", "/%*.*%*/" },
			keywords = {
				["var"] = true,
				["const"] = true,
				["func"] = true,
				["type"] = true,
				["package"] = true,
				["import"] = true,
				["if"] = true,
				["else"] = true,
				["for"] = true,
				["range"] = true,
				["switch"] = true,
				["case"] = true,
				["default"] = true,
				["return"] = true,
				["break"] = true,
				["continue"] = true,
				["fallthrough"] = true,
				["go"] = true,
				["defer"] = true,
				["select"] = true,
				["chan"] = true,
				["interface"] = true,
				["struct"] = true,
				["map"] = true,
				["slice"] = true,
				["array"] = true,
				["int"] = true,
				["int8"] = true,
				["int16"] = true,
				["int32"] = true,
				["int64"] = true,
				["uint"] = true,
				["uint8"] = true,
				["uint16"] = true,
				["uint32"] = true,
				["uint64"] = true,
				["uintptr"] = true,
				["float32"] = true,
				["float64"] = true,
				["complex64"] = true,
				["complex128"] = true,
				["bool"] = true,
				["string"] = true,
				["byte"] = true,
				["rune"] = true,
				["error"] = true,
				["nil"] = true,
				["iota"] = true,
				["fmt"] = true,
				["print"] = true,
				["println"] = true,
				["Printf"] = true,
				["Println"] = true,
				["Print"] = true,
				["make"] = true,
				["new"] = true,
				["len"] = true,
				["cap"] = true,
				["copy"] = true,
				["append"] = true,
				-- Literals
				["true"] = true,
				["false"] = true,
			},
			assignment_patterns = {
				"([%a_][%w_]*)%s*:=%s*([^;,\n=!<>]+)",
				"([%a_][%w_]*)%s*=%s*([^;,\n=!<>]+)",
				"var%s+([%a_][%w_]*).*=%s*([^;,\n=!<>]+)",
				"([%a_][%w_]*,%s*[%a_][%w_]*)%s*:=%s*([^;,\n=!<>]+)",
				"([%a_][%w_]*%s*%[[^%]]*%])%s*=%s*([^;,\n=!<>]+)",
				"([%a_][%w_]*%.[%a_][%w_]*)%s*=%s*([^;,\n=!<>]+)",
				"(%*+%s*[%a_][%w_]*)%s*=%s*([^;,\n=!<>]+)",
				"const%s+([%a_][%w_]*)%s*=%s*([^;,\n=!<>]+)",
				"const%s+([%a_][%w_]*)%s+[%w_%[%]%*]+%s*=%s*([^;,\n=!<>]+)",

				-- Multi-dimensional arrays
				"([%a_][%w_]*%s*%[[^%]]*%]%s*%[[^%]]*%])%s*=%s*([^;,\n=!<>]+)",
				"([%a_][%w_]*%s*%[[^%]]*%]%s*%[[^%]]*%]%s*%[[^%]]*%])%s*=%s*([^;,\n=!<>]+)",
				-- Pointer arithmetic assignments
				"(%([%*%s]*[%a_][%w_]*%))%s*=%s*([^;,\n=!<>]+)",
				"(%*%([%a_][%w_]*%s*[%+%-]%s*%d+%))%s*=%s*([^;,\n=!<>]+)",
				-- Function pointer assignments
				"([%a_][%w_]*)%s*=%s*%&?([%a_][%w_]*)",
				-- Compound operators
				"([%a_][%w_]*)%s*%+=%s*([^;,\n=!<>]+)",
				"([%a_][%w_]*)%s*%-=%s*([^;,\n=!<>]+)",
				"([%a_][%w_]*)%s*%*=%s*([^;,\n=!<>]+)",
				"([%a_][%w_]*)%s*/=%s*([^;,\n=!<>]+)",
				"([%a_][%w_]*)%s*%%=%s*([^;,\n=!<>]+)",
				"([%a_][%w_]*)%s*&=%s*([^;,\n=!<>]+)",
				"([%a_][%w_]*)%s*|=%s*([^;,\n=!<>]+)",
				"([%a_][%w_]*)%s*%^=%s*([^;,\n=!<>]+)",
				"([%a_][%w_]*)%s*<<=%s*([^;,\n=!<>]+)",
				"([%a_][%w_]*)%s*>>=%s*([^;,\n=!<>]+)",
				-- Increment/decrement
				"(%+%+[%a_][%w_]*)",
				"([%a_][%w_]*%+%+)",
				"(%-%-[%a_][%w_]*)",
				"([%a_][%w_]*%-%-)",
				-- Multiple variable declarations
				"[%w_*%s]+%s+([%a_][%w_]*)%s*,%s*([%a_][%w_]*)%s*=%s*([^;,\n=!<>]+)",
				"[%w_*%s]+%s+([%a_][%w_]*)%s*=%s*([^;,\n=!<>]+)%s*,%s*([%a_][%w_]*)%s*=%s*([^;,\n=!<>]+)",
				-- Ternary operator assignments
				"([%a_][%w_]*)%s*=%s*([^;,\n]*%?[^;,\n]*:[^;,\n]*)",
				-- Cast assignments
				"([%a_][%w_]*)%s*=%s*%([%w_*%s]+%)%s*([^;,\n=!<>]+)",
				-- Union/struct member assignments in initialization
				"%.([%a_][%w_]*)%s*=%s*([^;,\n=!<>]+)",
				-- Bit field assignments
				"([%a_][%w_]*%.[%a_][%w_]*)%s*=%s*([^;,\n=!<>]+)",
			},
		},
	}

	local function detect_language()
		local filename = vim.fn.expand("%")
		local ext = filename:match("%.([^%.]+)$")

		if ext == "c" or ext == "h" then
			return "c"
		elseif ext == "cpp" or ext == "cxx" or ext == "cc" or ext == "hpp" or ext == "hxx" then
			return "cpp"
		elseif ext == "rs" then
			return "rust"
		elseif ext == "go" then
			return "go"
		else
			return "c" -- default fallback
		end
	end

	local current_lang = detect_language()
	local lang_cfg = lang_config[current_lang]

	local function strip_comments(line)
		local cleaned = line
		for _, comment_pattern in ipairs(lang_cfg.comment_patterns) do
			-- Handle single line comments
			if comment_pattern:match("//") then
				local comment_start = cleaned:find("//")
				if comment_start then
					cleaned = cleaned:sub(1, comment_start - 1)
				end
			-- Handle multi-line comments (simplified)
			elseif comment_pattern:match("/%*") then
				cleaned = cleaned:gsub("/%*.--%*/", "")
			end
		end
		return cleaned:gsub("%s+$", "") -- trim trailing whitespace
	end

	local function is_non_assignment_context(line)
		local trimmed = line:gsub("^%s+", ""):gsub("%s+$", "")

		local non_assignment_patterns = {
			-- Control structures
			"^if%s*%(",
			"^else%s*if%s*%(",
			"^else%s*{?$",
			"^while%s*%(",
			"^for%s*%(",
			"^switch%s*%(",
			"^case%s+",
			"^default%s*:",
			"^do%s*{?$",
			-- Function definitions and declarations
			"^[%w_*%s]+%s+[%a_][%w_]*%s*%([^)]*%)%s*{?$",
			"^[%a_][%w_]*%s*%([^)]*%)%s*{?$",
			"^func%s+[%a_][%w_]*%s*%(",
			"^fn%s+[%a_][%w_]*%s*%(",
			"^pub%s+fn%s+",
			-- Function calls at start of line
			"^[%a_][%w_]*%s*%(",
			"^[%a_][%w_]*%.[%a_][%w_]*%s*%(",
			"^[%a_][%w_]*::[%a_][%w_]*%s*%(",
			-- Print statements and similar
			"printf%s*%(",
			"println%s*%(",
			"cout%s*<<",
			"print%s*%(",
			"fmt%.Print",
			-- Return and control statements
			"^return",
			"^break",
			"^continue",
			"^goto%s+",
			-- Language-specific imports/includes
			"^#include%s+",
			"^from%s+.*import",
			"^use%s+",
			"^mod%s+",
			"^extern%s+",
			"^package%s+",
			"^#include",
			"^#define",
			"^#ifdef",
			"^#ifndef",
			"^#if",
			"^#else",
			"^#endif",
			"^#pragma",
			"^#undef",
			"^import%s+",
			"^use%s+",
			"^from%s+.*import",
			"^package%s+",
			"^extern%s+",
			"^namespace%s+",
			"^using%s+",
			-- Variable declarations without assignment
			"^var%s+[%a_][%w_]*%s*$",
			"^let%s+[%a_][%w_]*%s*$",
			"^const%s+[%a_][%w_]*%s*$",
			"^static%s+",
			"^extern%s+",
			"^typedef%s+",
			-- Type definitions
			"^type%s+",
			"^struct%s+",
			"^enum%s+",
			"^union%s+",
			"^class%s+",
			"^interface%s+",
			"^trait%s+",
			"^impl%s+",
			-- Module and visibility
			"^mod%s+",
			"^pub%s+mod%s+",
			"^pub%s+struct%s+",
			"^pub%s+enum%s+",
			"^pub%s+trait%s+",
			"^pub%s+const%s+",
			"^pub%s+static%s+",
			"^public%s*:",
			"^private%s*:",
			"^protected%s*:",
			-- Comments
			"^//",
			"^/%*",
			"^%*",
			-- Braces and brackets
			"^%s*{%s*$",
			"^%s*}%s*$",
			"^%s*%[%s*$",
			"^%s*%]%s*$",
			-- Labels
			"^[%a_][%w_]*%s*:%s*$",
			-- Comparison operators (to avoid catching == != <= >= etc)
			"[=!<>]=",
			"!=",
			"==",
			"<=",
			">=",
			-- Attribute/annotation patterns
			"^%s*%[%s*derive",
			"^%s*%[%s*cfg",
			"^%s*%[%s*test%s*%]",
			"^%s*@[%a_]",
			-- Error handling patterns
			"^%s*panic!",
			"^%s*assert!",
			"^%s*debug_assert!",
			-- Match expressions
			"^%s*match%s+",
			"^%s*if%s+let%s+",
			-- Channel operations
			"^%s*<%-",
			"^%s*select%s*{",
			-- Generic type definitions
			"^%s*<%s*[%a_]",
			-- Complex expressions and casts
			"^%s*%([%w_*%s]+%)%s*[%a_]",
			-- Template/generic instantiations
			"^%s*[%a_][%w_]*%s*<%s*[%w_,:%s]*%s*>%s*[%a_]",
			-- Lambda expressions (C++)
			"^%s*%[[^%]]*%]%s*%([^%)]*%)",
			"^%s*auto%s+[%a_][%w_]*%s*=%s*%[",
			-- Range-based for loops (C++)
			"^%s*for%s*%(%s*auto",
			"^%s*for%s*%(%s*const%s+auto",
			-- Complex pointer declarations
			"^%s*[%w_]+%s*%*%s*%*+%s*[%a_]",
			"^%s*[%w_]+%s*%(%s*%*%s*[%a_]",
			-- Bit manipulation
			"^%s*[%a_][%w_]*%s*[&|^]=%s*",
			"^%s*[%a_][%w_]*%s*<<=",
			"^%s*[%a_][%w_]*%s*>>=",
			-- Assembly inline
			"^%s*__asm",
			"^%s*asm%s*%(",
			-- Preprocessor advanced
			"^%s*#%s*line%s+",
			"^%s*#%s*error%s+",
			"^%s*#%s*warning%s+",
			"^%s*#%s*region",
			"^%s*#%s*endregion",
			-- Advanced Rust patterns
			"^%s*unsafe%s*{",
			'^%s*extern%s+"C"%s*{',
			"^%s*mod%s+[%a_][%w_]*%s*{",
			"^%s*#%s*%[%s*derive",
			"^%s*#%s*%[%s*cfg",
			"^%s*#%s*%[%s*test%s*%]",
			"^%s*#%s*%[%s*allow",
			"^%s*#%s*%[%s*warn",
			"^%s*#%s*%[%s*deny",
			"^%s*#%s*%[%s*forbid",
			-- Advanced Go patterns
			"^%s*go%s+func%s*%(",
			"^%s*defer%s+[%a_]",
			"^%s*select%s*{",
			"^%s*type%s+[%a_][%w_]*%s+interface",
			"^%s*type%s+[%a_][%w_]*%s+struct",
			"^%s*//go:generate",
			"^%s*//go:build",
			"^%s*//go:embed",
		}

		for _, pattern in ipairs(non_assignment_patterns) do
			if trimmed:match(pattern) then
				return true
			end
		end

		-- Check for comparison operators that might be confused with assignments
		local comparison_ops = { "==", "!=", "<=", ">=", "<", ">" }
		for _, op in ipairs(comparison_ops) do
			if trimmed:find(op, 1, true) and not trimmed:find("=", trimmed:find(op, 1, true) + #op, true) then
				return true
			end
		end

		return false
	end

	local function is_valid_variable(name, context)
		-- Basic validation
		if not name or name == "" then
			return false
		end

		-- Must start with letter or underscore
		if not name:match("^[%a_]") then
			return false
		end

		-- Must only contain alphanumeric and underscores (basic check)
		if not name:match("^[%a_][%w_]*$") then
			-- Allow some special cases for specific contexts
			if context ~= "array_access" and context ~= "member_access" then
				return false
			end
		end

		-- Check against keywords
		if lang_cfg.keywords[name] then
			return false
		end

		-- EXPANDED: Skip common non-variable patterns
		local non_variable_patterns = {
			"^%d+$", -- pure numbers
			"^0x[%da-fA-F]+$", -- hex numbers
			"^%d+%.%d+$", -- floating point numbers
			"^%d+[uUlLfF]+$", -- number suffixes
			-- EXPANDED PATTERNS:
			"^%d+%.%d+[fFlL]$", -- float literals with suffixes
			"^0[0-7]+$", -- octal numbers
			"^0b[01]+$", -- binary numbers
			"^%d+e[%+%-]?%d+$", -- scientific notation
			"^%d+%.%d*e[%+%-]?%d+$", -- scientific notation with decimal
			"^0x%x+%.%x*p[%+%-]?%d+$", -- hex float
			"^'.'$", -- character literals
			"^'\\.'$", -- escaped character literals
			"^'\\x%x%x'$", -- hex character literals
			"^'\\%d+%d+%d+'$", -- octal character literals
			'^L?".*"$', -- string literals
			"^L?'.*'$", -- character string literals
			'^R".*"$', -- raw string literals
			-- Common constants that look like variables
			"^SIZE_T$",
			"^UINT32$",
			"^INT64$",
			"^CHAR$",
			"^VOID$",
			"^MAX_PATH$",
			"^ERROR$",
			"^SUCCESS$",
			"^FAILURE$",
		}

		for _, pattern in ipairs(non_variable_patterns) do
			if name:match(pattern) then
				return false
			end
		end

		if current_lang == "rust" then
			-- Rust allows more characters in variable names in some contexts
			if name:match("^r#") then -- raw identifiers
				return true
			end
			-- Check for valid Rust identifiers
			if not name:match("^[%a_][%w_]*$") and not name:match("^_[%w_]*$") then
				return false
			end
		elseif current_lang == "go" then
			-- Go identifier rules
			if not name:match("^[%a_][%w_]*$") then
				return false
			end
		elseif current_lang == "cpp" then
			-- C++ allows more complex names with namespaces
			if name:match("::") and context == "qualified_name" then
				return true
			end
			-- Template parameter names
			if context == "template" and name:match("^[%a_][%w_]*$") then
				return true
			end
		end

		-- Skip extremely short names that are likely not meaningful variables
		if #name < 2 and name ~= "_" then
			return false
		end

		-- Skip names that are too long (likely generated or corrupted)
		if #name > 64 then
			return false
		end

		return true
	end

	local variable_tracker = {
		assignments = {}, -- var_name -> assignment_info
		expressions = {}, -- var_name -> expression_info
		function_calls = {}, -- var_name -> call_info
		array_access = {}, -- array_expr -> line_num
		arithmetic = {}, -- list of arithmetic_info
		dependencies = {}, -- var_name -> list of dependent vars
	}

	-- Get all lines from current buffer for static analysis
	local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)

	local function extract_variables_from_expression(expr)
		local vars = {}

		-- Clean up the expression
		local cleaned_expr = expr:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")

		-- Skip quoted strings entirely (both single and double quotes)
		if cleaned_expr:match('^".*"$') or cleaned_expr:match("^'.*'$") then
			return vars
		end

		-- Skip import paths and module references
		if cleaned_expr:match('^"[^"]*"$') or cleaned_expr:match("^[%w_/.%-]+/[%w_/.%-]+$") then
			return vars
		end

		-- EXPANDED: Remove string literals from expression before processing
		local expr_no_strings = cleaned_expr
		-- Remove double-quoted strings
		expr_no_strings = expr_no_strings:gsub('"[^"]*"', '""')
		-- Remove single-quoted strings
		expr_no_strings = expr_no_strings:gsub("'[^']*'", "''")
		-- Remove character literals
		expr_no_strings = expr_no_strings:gsub("'\\?.'", "''")

		-- EXPANDED: Extract different types of variable references
		-- 1. Simple variable names
		for token in expr_no_strings:gmatch("[%a_][%w_]*") do
			if is_valid_variable(token) then
				vars[token] = { type = "simple", context = "variable" }
			end
		end

		-- 2. Array access variables
		for array_expr in expr_no_strings:gmatch("([%a_][%w_]*)%s*%[") do
			if is_valid_variable(array_expr, "array_access") then
				vars[array_expr] = { type = "array", context = "array_base" }
			end
		end

		-- 3. Struct/class member access
		for base, member in expr_no_strings:gmatch("([%a_][%w_]*)%.([%a_][%w_]*)") do
			if is_valid_variable(base) then
				vars[base] = { type = "struct", context = "base_object" }
			end
			if is_valid_variable(member, "member_access") then
				vars[member] = { type = "member", context = "member_field" }
			end
		end

		-- 4. Pointer member access
		for base, member in expr_no_strings:gmatch("([%a_][%w_]*)%->([%a_][%w_]*)") do
			if is_valid_variable(base) then
				vars[base] = { type = "pointer", context = "pointer_base" }
			end
			if is_valid_variable(member, "member_access") then
				vars[member] = { type = "member", context = "pointed_member" }
			end
		end

		-- 5. Function call results (but not the function name itself in some contexts)
		for func_name in expr_no_strings:gmatch("([%a_][%w_]*)%s*%([^%)]*%)") do
			if is_valid_variable(func_name) and not lang_cfg.keywords[func_name] then
				vars[func_name] = { type = "function", context = "function_call" }
			end
		end

		-- 6. Dereferenced pointers
		for ptr_var in expr_no_strings:gmatch("%*+%s*([%a_][%w_]*)") do
			if is_valid_variable(ptr_var) then
				vars[ptr_var] = { type = "dereference", context = "dereferenced_pointer" }
			end
		end

		-- 7. Address-of operations
		for addr_var in expr_no_strings:gmatch("&%s*([%a_][%w_]*)") do
			if is_valid_variable(addr_var) then
				vars[addr_var] = { type = "address", context = "address_taken" }
			end
		end

		-- 8. Language-specific patterns
		if current_lang == "cpp" then
			-- Namespace qualified names
			for namespace, var in expr_no_strings:gmatch("([%a_][%w_]*::)([%a_][%w_]*)") do
				local ns_name = namespace:gsub("::", "")
				if is_valid_variable(ns_name) then
					vars[ns_name] = { type = "namespace", context = "namespace_qualifier" }
				end
				if is_valid_variable(var, "qualified_name") then
					vars[var] = { type = "qualified", context = "qualified_variable" }
				end
			end

			-- Template instantiations
			for template_name in expr_no_strings:gmatch("([%a_][%w_]*)%s*<%s*[^>]*%s*>") do
				if is_valid_variable(template_name, "template") then
					vars[template_name] = { type = "template", context = "template_instantiation" }
				end
			end
		elseif current_lang == "rust" then
			-- Module paths
			for module, item in expr_no_strings:gmatch("([%a_][%w_]*)::([%a_][%w_]*)") do
				if is_valid_variable(module) then
					vars[module] = { type = "module", context = "module_path" }
				end
				if is_valid_variable(item) then
					vars[item] = { type = "module_item", context = "module_member" }
				end
			end

			-- Method calls
			for obj, method in expr_no_strings:gmatch("([%a_][%w_]*)%.([%a_][%w_]*)%s*%(") do
				if is_valid_variable(obj) then
					vars[obj] = { type = "object", context = "method_receiver" }
				end
			end
		elseif current_lang == "go" then
			-- Package qualified names
			for package, item in expr_no_strings:gmatch("([%a_][%w_]*)%.([%a_][%w_]*)") do
				if is_valid_variable(package) and not lang_cfg.keywords[package] then
					vars[package] = { type = "package", context = "package_qualifier" }
				end
				if is_valid_variable(item) then
					vars[item] = { type = "package_item", context = "package_member" }
				end
			end
		end

		return vars
	end

	local function evaluate_expression_safety(expr, context_vars)
		local safety_issues = {}

		-- Skip string literals and import paths
		if expr:match('^".*"$') or expr:match("^'.*'$") then
			return safety_issues
		end

		-- Skip import/module paths
		if expr:match("^[%w_/.%-]+/[%w_/.%-]+$") or expr:match('^"[^"]*"$') then
			return safety_issues
		end

		-- Check for division by zero patterns
		if expr:match("/%s*0%s*[^%d%.]") or expr:match("/%s*0%s*$") then
			table.insert(safety_issues, "potential_division_by_zero")
		end

		-- Check for buffer overflow patterns in dynamic allocation
		if
			(expr:match("malloc%s*%(") or expr:match("new%s*%[") or expr:match("make%s*%(")) and expr:match("[%+%-%*/]")
		then
			table.insert(safety_issues, "dynamic_allocation_with_arithmetic")
		end

		-- Check for integer overflow patterns
		if expr:match("0x[fF]+") or expr:match("2147483647") or expr:match("4294967295") then
			table.insert(safety_issues, "potential_integer_overflow")
		end

		-- Only check for uninitialized variables in actual expressions, not strings
		for var in expr:gmatch("[%a_][%w_]*") do
			-- Skip if this is part of a string literal
			local before_var = expr:match("(.-)" .. var)
			if before_var and (before_var:find('"[^"]*$') or before_var:find("'[^']*$")) then
				goto continue
			end

			if
				is_valid_variable(var)
				and context_vars
				and not context_vars[var]
				and not variable_tracker.assignments[var]
			then
				table.insert(safety_issues, "uninitialized_variable_" .. var)
			end
			::continue::
		end

		-- Language-specific checks
		if current_lang == "rust" then
			if expr:match("unwrap%s*%(") or expr:match("expect%s*%(") then
				table.insert(safety_issues, "potential_panic")
			end
		elseif current_lang == "go" then
			if expr:match("%*[%a_][%w_]*") and not expr:match("nil") then
				table.insert(safety_issues, "potential_nil_dereference")
			end
		end

		return safety_issues
	end

	local function is_string_or_import_line(line)
		local trimmed = line:gsub("^%s+", ""):gsub("%s+$", "")

		-- Check for import statements
		if trimmed:match("^import%s+") or trimmed:match("^from%s+.*import") or trimmed:match("^use%s+") then
			return true
		end

		-- Check for string assignments
		if trimmed:match('=%s*"[^"]*"') or trimmed:match("=%s*'[^']*'") then
			return true
		end

		-- Check for module paths
		if trimmed:match('"[%w_/.%-]+/[%w_/.%-]+"') then
			return true
		end

		return false
	end

	local function is_declaration_only(line, lang)
		local trimmed = line:gsub("^%s+", ""):gsub("%s+$", "")

		if lang == "c" or lang == "cpp" then
			-- C/C++ declarations: int x; float y[10]; struct point p;
			if
				trimmed:match("^[%w_*%s]+%s+[%a_][%w_]*%s*;%s*$")
				or trimmed:match("^[%w_*%s]+%s+[%a_][%w_]*%s*%[[^%]]*%]%s*;%s*$")
			then
				return true
			end
		elseif lang == "rust" then
			-- Rust declarations: let x: i32; let mut y: String;
			if
				trimmed:match("^let%s+mut%s+[%a_][%w_]*%s*:%s*[%w_<>]+%s*;%s*$")
				or trimmed:match("^let%s+[%a_][%w_]*%s*:%s*[%w_<>]+%s*;%s*$")
			then
				return true
			end
		elseif lang == "go" then
			-- Go declarations: var x int; var y []string;
			if trimmed:match("^var%s+[%a_][%w_]*%s+[%w_%[%]%*]+%s*$") then
				return true
			end
		end

		return false
	end

	local function parse_assignments(line, line_num)
		local cleaned_line = strip_comments(line)

		-- Skip empty lines after comment removal
		if cleaned_line:match("^%s*$") then
			return
		end

		-- Skip string literals and import statements
		if is_string_or_import_line(cleaned_line) then
			return
		end

		-- Skip declaration-only lines
		if is_declaration_only(cleaned_line, current_lang) then
			return
		end

		-- Skip non-assignment contexts
		if is_non_assignment_context(cleaned_line) then
			return
		end

		for _, pattern in ipairs(lang_cfg.assignment_patterns) do
			for var, val in cleaned_line:gmatch(pattern) do
				-- Clean and normalize value
				val = val:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")

				-- Skip if value is empty or just whitespace
				if val == "" or val:match("^%s*$") then
					goto continue
				end

				-- Skip string literals and import paths
				if val:match('^".*"$') or val:match("^'.*'$") or val:match("^[%w_/.%-]+/[%w_/.%-]+$") then
					goto continue
				end

				-- Handle language-specific variable name extraction
				local clean_var = var
				if current_lang == "rust" then
					clean_var = var:match("([%a_][%w_]*)$") or var
				elseif current_lang == "go" then
					-- Handle multiple assignments: var1, var2 := func()
					if var:find(",") then
						for single_var in var:gmatch("([%a_][%w_]*)") do
							if is_valid_variable(single_var) then
								variable_tracker.assignments[single_var] = {
									value = val,
									line = line_num,
									raw_line = cleaned_line,
								}
							end
						end
						goto continue
					end
					clean_var = var:match("([%a_][%w_]*)") or var
				else
					-- For C/C++, extract the base variable name
					clean_var = var:match("([%a_][%w_]*)") or var
				end

				-- Validate variable name
				if not is_valid_variable(clean_var) then
					goto continue
				end

				-- Store assignment info
				variable_tracker.assignments[clean_var] = {
					value = val,
					line = line_num,
					raw_line = cleaned_line,
				}

				-- Track expressions (but not string literals)
				if
					(val:match("[%+%-%*/%%]") or val:match("%(.*%)"))
					and not val:match('^".*"$')
					and not val:match("^'.*'$")
				then
					local expr_vars = extract_variables_from_expression(val)
					variable_tracker.expressions[clean_var] = {
						expression = val,
						line = line_num,
						variables = expr_vars,
					}

					-- Build dependency graph
					variable_tracker.dependencies[clean_var] = {}
					for dep_var, _ in pairs(expr_vars) do
						table.insert(variable_tracker.dependencies[clean_var], dep_var)
					end
				end

				-- Track function calls
				if
					val:match("[%a_][%w_]*%s*%([^)]*%)")
					or (current_lang == "rust" and val:match("[%a_][%w_]*!%s*%([^)]*%)"))
				then
					variable_tracker.function_calls[clean_var] = {
						call = val,
						line = line_num,
					}
				end

				::continue::
			end
		end
	end

	-- Parse buffer for static analysis
	for line_num, line in ipairs(lines) do
		parse_assignments(line, line_num)

		local cleaned_line = strip_comments(line)

		if not is_non_assignment_context(cleaned_line) then
			for array_access in cleaned_line:gmatch("([%a_][%w_]*%s*%[[^%]]+%])") do
				local var_name = array_access:match("([%a_][%w_]*)")
				if is_valid_variable(var_name) then
					variable_tracker.array_access[array_access] = line_num
				end
			end
		end

		if not is_non_assignment_context(cleaned_line) then
			for arithmetic in cleaned_line:gmatch("([^;=]*[%+%-%*/%%][^;=]*)") do
				-- Make sure it contains valid variables and isn't just a comparison
				if
					arithmetic:match("[%a_][%w_]*")
					and not arithmetic:match("[=!<>]=")
					and not arithmetic:match("!=")
				then
					local safety_issues = evaluate_expression_safety(arithmetic, variable_tracker.assignments)
					if #safety_issues > 0 then
						table.insert(variable_tracker.arithmetic, {
							expr = arithmetic,
							line = line_num,
							safety = safety_issues,
						})
					end
				end
			end
		end
	end

	local function find_related_variables(suspicious_value, tracker)
		local related = {}

		-- Direct value matches
		for var_name, assignment in pairs(tracker.assignments) do
			if assignment.value:find(suspicious_value, 1, true) then
				table.insert(related, {
					name = var_name,
					line = assignment.line,
					type = "direct_assignment",
					value = assignment.value,
				})
			end
		end

		-- Expression matches
		for var_name, expr_info in pairs(tracker.expressions) do
			if expr_info.expression:find(suspicious_value, 1, true) then
				table.insert(related, {
					name = var_name,
					line = expr_info.line,
					type = "expression_result",
					expression = expr_info.expression,
				})
			end
		end

		-- Function call matches (runtime correlation)
		for var_name, call_info in pairs(tracker.function_calls) do
			local pattern = var_name .. ".*" .. suspicious_value:gsub("[%(%)%.%+%-%*%?%[%]%^%$%%]", "%%%1")
			if output:find(pattern) then
				table.insert(related, {
					name = var_name,
					line = call_info.line,
					type = "function_return",
					call = call_info.call,
				})
			end
		end

		return related
	end

	local function build_context_info(var_info, tracker)
		local context = {}

		if var_info.type == "direct_assignment" then
			table.insert(context, "direct assignment")
		elseif var_info.type == "expression_result" then
			table.insert(context, "expression: " .. var_info.expression)
		elseif var_info.type == "function_return" then
			table.insert(context, "function: " .. var_info.call)
		end

		-- Check if variable is used in other expressions
		for other_var, expr_info in pairs(tracker.expressions) do
			if expr_info.variables and expr_info.variables[var_info.name] then
				table.insert(context, "used in " .. other_var)
			end
		end

		-- Check dependencies
		local deps = tracker.dependencies[var_info.name]
		if deps and #deps > 0 then
			table.insert(context, "depends on: " .. table.concat(deps, ", "))
		end

		return table.concat(context, ", ")
	end

	local function determine_severity(pattern_type, context)
		local severity_map = {
			overflow = "error",
			null_ptr = "warning",
			uninitialized = "error",
			nan_inf = "warning",
			memory_leak = "error",
			buffer_overflow = "error",
		}

		local base_severity = severity_map[pattern_type] or "info"

		-- Increase severity if in expression context
		if context and context:match("expression") then
			if base_severity == "warning" then
				return "error"
			end
		end

		return base_severity
	end

	-- Analyze output for suspicious patterns with variable context
	local output_lines = {}
	for line in output:gmatch("[^\r\n]+") do
		table.insert(output_lines, line)
	end

	for line_num, line in ipairs(output_lines) do
		-- Check for suspicious values
		for pattern_type, patterns in pairs(value_patterns) do
			for _, pattern in ipairs(patterns) do
				local matches = {}

				-- Handle regex patterns vs literal patterns
				if pattern_type == "memory_leak" then
					for match in line:gmatch(pattern) do
						table.insert(matches, match)
					end
				else
					if line:find(pattern, 1, true) then
						table.insert(matches, pattern)
					end
				end

				for _, match in ipairs(matches) do
					-- Try to correlate with tracked variables
					local related_vars = find_related_variables(match, variable_tracker)

					if #related_vars > 0 then
						for _, var_info in ipairs(related_vars) do
							local context_info = build_context_info(var_info, variable_tracker)

							table.insert(suspicious, {
								filename = vim.fn.expand("%"),
								lnum = var_info.line,
								col = 1,
								text = string.format(
									"Suspicious %s in variable '%s': %s",
									pattern_type,
									var_info.name,
									context_info
								),
								display = string.format(
									"SUSPICIOUS[%s]: %s:%d - Variable '%s' = %s (%s)",
									pattern_type:upper(),
									vim.fn.fnamemodify(vim.fn.expand("%"), ":t"),
									var_info.line,
									var_info.name,
									match,
									context_info
								),
								severity = determine_severity(pattern_type, context_info),
								context = var_info,
							})
						end
					else
						-- Report suspicious value without variable context
						table.insert(suspicious, {
							filename = vim.fn.expand("%"),
							lnum = line_num,
							col = 1,
							text = string.format("Suspicious %s value detected: %s", pattern_type, match),
							display = string.format(
								"SUSPICIOUS[%s]: %s:%d - Runtime value '%s'",
								pattern_type:upper(),
								vim.fn.fnamemodify(vim.fn.expand("%"), ":t"),
								line_num,
								match
							),
							severity = determine_severity(pattern_type, "runtime_detection"),
						})
					end
				end
			end
		end
	end

	-- Check for expression-based safety issues
	for _, arith_info in ipairs(variable_tracker.arithmetic) do
		if arith_info.safety and #arith_info.safety > 0 then
			for _, safety_issue in ipairs(arith_info.safety) do
				table.insert(suspicious, {
					filename = vim.fn.expand("%"),
					lnum = arith_info.line,
					col = 1,
					text = string.format("Expression safety issue: %s in '%s'", safety_issue, arith_info.expr),
					display = string.format(
						"EXPRESSION[SAFETY]: %s:%d - %s in '%s'",
						vim.fn.fnamemodify(vim.fn.expand("%"), ":t"),
						arith_info.line,
						safety_issue:gsub("_", " "):upper(),
						arith_info.expr
					),
					severity = "warning",
				})
			end
		end
	end

	-- Check tracked expressions for potential issues
	for var_name, expr_info in pairs(variable_tracker.expressions) do
		local expr_safety = evaluate_expression_safety(expr_info.expression, variable_tracker.assignments)

		for _, safety_issue in ipairs(expr_safety) do
			table.insert(suspicious, {
				filename = vim.fn.expand("%"),
				lnum = expr_info.line,
				col = 1,
				text = string.format("Variable expression issue in '%s': %s", var_name, safety_issue),
				display = string.format(
					"VARIABLE[EXPR]: %s:%d - %s in '%s' = %s",
					vim.fn.fnamemodify(vim.fn.expand("%"), ":t"),
					expr_info.line,
					safety_issue:gsub("_", " "):upper(),
					var_name,
					expr_info.expression
				),
				severity = determine_severity("expression", safety_issue),
			})
		end
	end

	return suspicious
end

return M
