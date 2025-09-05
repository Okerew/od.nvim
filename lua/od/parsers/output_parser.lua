local M = {}

function M.parse_debug_output(output, filetype)
	local errors = {}
	local warnings = {}

	for line in output:gmatch("[^\n]+") do
		if line ~= nil then
			local file, line_num, msg

			if filetype == "c" or filetype == "cpp" then
				file, line_num, msg = line:match("([^:]+%.[ch]p*p*):(%d+):%d*:?%s*(.+)")
				if not file or not line_num then
					-- Alternative pattern for different compiler formats
					file, line_num, msg = line:match("In file included from ([^:]+%.[ch]p*p*):(%d+)")
					if not file then
						file, line_num, msg = line:match("([^%s]+%.[ch]p*p*):(%d+):?%s*(.+)")
					end
					if not file then
						file, line_num, msg = line:match("([^%s]+%.[ch]p*p*)%((%d+)%): (.+)")
					end
					if not file then
						-- MSVC format
						file, line_num, msg = line:match("([^%(]+%.[ch]p*p*)%((%d+)%): (.+)")
					end
				end

				if file and line_num and msg then
					local item = {
						filename = file,
						lnum = tonumber(line_num),
						text = msg,
						display = string.format("%s:%s: %s", vim.fn.fnamemodify(file, ":t"), line_num, msg),
					}

					local cpp_error_keywords = {
						-- Syntax and parse errors
						"syntax error",
						"parse error",
						"expected",
						"unexpected",
						"missing",
						"unterminated",
						"invalid syntax",
						"malformed",
						"stray",
						"expected '.*' before",
						"expected '.*' after",
						"expected identifier before",
						"expected unqualified%-id before",
						"expected '%;' before",
						"expected '%{' before",
						"expected '%}' before",
						"expected '%)' before",
						"expected '%(' before",
						"expected '%]' before",
						"expected '%[' before",
						"missing terminating",
						"missing binary operator",
						"missing template arguments",
						"invalid preprocessing directive",
						"invalid character",
						"invalid token",
						"invalid suffix",
						"invalid operand",
						"invalid operator",
						"invalid conversion",
						"invalid cast",
						"invalid initialization",
						"invalid declarator",
						"invalid type specifier",
						"invalid storage class",
						"invalid function definition",
						"expected declaration before",
						"expected expression before",
						"expected primary%-expression",
						"expected constant%-expression",
						"expected statement",

						-- Undeclared/undefined errors
						"undeclared",
						"not declared",
						"undefined reference",
						"undefined symbol",
						"undefined identifier",
						"undefined function",
						"undefined variable",
						"undefined type",
						"undefined class",
						"undefined struct",
						"undefined enum",
						"undefined macro",
						"undefined label",
						"was not declared",
						"has not been declared",
						"not found in this scope",
						"is not a member of",
						"does not name a type",
						"does not name a class",
						"does not name a namespace",
						"is not a template",
						"is not a class template",
						"is not a function template",
						"unresolved external symbol",
						"unresolved reference",
						"cannot find symbol",
						"symbol.*undefined",

						-- Type errors
						"type mismatch",
						"incompatible types",
						"conflicting types",
						"invalid type",
						"unknown type",
						"incomplete type",
						"abstract type",
						"void type",
						"array type",
						"function type",
						"pointer type",
						"reference type",
						"cannot convert",
						"no suitable conversion",
						"conversion from.*to.*is ambiguous",
						"cannot convert from",
						"cannot convert to",
						"no matching function",
						"no matching constructor",
						"no matching operator",
						"no viable conversion",
						"no known conversion",
						"invalid conversion",
						"invalid use of",
						"invalid application of",
						"invalid operands to",
						"invalid argument",
						"invalid parameter",
						"invalid return type",
						"return type mismatch",
						"assignment from incompatible pointer type",
						"initialization from incompatible pointer type",
						"passing.*from incompatible pointer type",
						"comparison between pointer and integer",
						"comparison of distinct pointer types",

						-- Template errors
						"template argument",
						"template parameter",
						"template instantiation",
						"template specialization",
						"template deduction",
						"no matching template",
						"ambiguous template",
						"invalid template",
						"template.*does not match",
						"substitution failure",
						"SFINAE",
						"template argument deduction failed",
						"template parameter.*not used",
						"template.*is not a template",
						"too many template arguments",
						"too few template arguments",
						"invalid explicit template arguments",
						"explicit template arguments not allowed",
						"template argument list",
						"template instantiation depth",
						"recursive template instantiation",
						"variadic template",
						"parameter pack",
						"template template parameter",
						"non%-type template parameter",
						"template argument.*invalid",
						"requires.*concept",
						"concept.*not satisfied",
						"constraint.*not satisfied",

						-- Memory and pointer errors
						"segmentation fault",
						"segfault",
						"memory access violation",
						"access violation",
						"null pointer",
						"nullptr",
						"dangling pointer",
						"buffer overflow",
						"buffer underflow",
						"stack overflow",
						"heap corruption",
						"double free",
						"use after free",
						"memory leak",
						"invalid pointer",
						"invalid memory access",
						"invalid read",
						"invalid write",
						"uninitialized",
						"uninitialized variable",
						"uninitialized memory",
						"may be used uninitialized",
						"pointer.*may be used before",
						"reading.*bytes after",
						"writing.*bytes after",
						"invalid free",
						"mismatched free",
						"array bounds",
						"out of bounds",
						"subscript out of range",
						"index out of bounds",

						-- Class and object errors
						"no default constructor",
						"no copy constructor",
						"no assignment operator",
						"no destructor",
						"abstract class",
						"pure virtual function",
						"virtual function.*is private",
						"cannot instantiate abstract class",
						"object of abstract class",
						"multiple inheritance",
						"ambiguous base class",
						"virtual base class",
						"diamond inheritance",
						"virtual function table",
						"vtable",
						"class.*incomplete",
						"class.*not defined",
						"class.*forward declared",
						"circular dependency",
						"recursive class",
						"friend class",
						"private member",
						"protected member",
						"inaccessible",
						"not accessible",
						"access control",
						"visibility",

						-- Function and method errors
						"too many arguments",
						"too few arguments",
						"wrong number of arguments",
						"argument mismatch",
						"parameter mismatch",
						"no matching function call",
						"no matching method",
						"ambiguous function call",
						"ambiguous method call",
						"call to.*is ambiguous",
						"overload resolution failed",
						"no viable overload",
						"no suitable function",
						"function.*not defined",
						"method.*not defined",
						"function redefinition",
						"method redefinition",
						"multiple definitions",
						"conflicting declaration",
						"previous declaration",
						"redeclaration",
						"function signature",
						"method signature",
						"virtual function",
						"override",
						"final",
						"pure virtual",
						"abstract method",

						-- Namespace errors
						"namespace.*not found",
						"namespace.*undefined",
						"using directive",
						"using declaration",
						"namespace alias",
						"qualified name",
						"unqualified name",
						"name lookup",
						"scope resolution",
						"nested namespace",
						"namespace.*already defined",
						"ambiguous namespace",

						-- Preprocessor errors
						"macro.*not defined",
						"macro redefinition",
						"macro.*already defined",
						"#include.*not found",
						"#include.*no such file",
						"header.*not found",
						"recursive #include",
						"#ifdef",
						"#ifndef",
						"#if",
						"#else",
						"#elif",
						"#endif",
						"conditional compilation",
						"preprocessor directive",
						"#define",
						"#undef",
						"#pragma",
						"#line",
						"#error",
						"#warning",

						-- Linker errors
						"linker error",
						"link error",
						"ld:",
						"collect2:",
						"undefined reference to",
						"cannot find library",
						"library.*not found",
						"multiple definition",
						"duplicate symbol",
						"symbol multiply defined",
						"relocation truncated",
						"relocation.*out of range",
						"text relocation",
						"section.*overlaps",
						"cannot create executable",
						"permission denied",
						"file format not recognized",
						"archive has no index",
						"shared library",
						"dynamic linking",
						"static linking",
						"symbol versioning",
						"weak symbol",
						"strong symbol",

						-- Standard library errors
						"std::",
						"vector",
						"string",
						"map",
						"set",
						"list",
						"deque",
						"array",
						"unordered_map",
						"unordered_set",
						"shared_ptr",
						"unique_ptr",
						"weak_ptr",
						"iterator",
						"algorithm",
						"exception",
						"runtime_error",
						"logic_error",
						"invalid_argument",
						"out_of_range",
						"length_error",
						"domain_error",
						"range_error",
						"overflow_error",
						"underflow_error",
						"bad_alloc",
						"bad_cast",
						"bad_typeid",
						"bad_exception",

						-- C++11/14/17/20 specific errors
						"auto",
						"decltype",
						"lambda",
						"nullptr",
						"constexpr",
						"static_assert",
						"noexcept",
						"move semantics",
						"perfect forwarding",
						"rvalue reference",
						"variadic template",
						"range%-based for",
						"uniform initialization",
						"delegating constructor",
						"inheriting constructor",
						"default.*delete",
						"=.*default",
						"=.*delete",
						"override",
						"final",
						"alignas",
						"alignof",
						"thread_local",
						"atomic",
						"mutex",
						"condition_variable",
						"future",
						"promise",
						"async",
						"consteval",
						"constinit",
						"concept",
						"requires",
						"co_await",
						"co_yield",
						"co_return",
						"coroutine",
						"module",
						"import",
						"export",

						-- Warnings that should be treated as errors
						"warning:.*may be used uninitialized",
						"warning:.*comparison.*always",
						"warning:.*array subscript",
						"warning:.*deprecated",
						"warning:.*format",
						"warning:.*conversion",
						"warning:.*sign",
						"warning:.*overflow",
						"warning:.*unused",
						"warning:.*shadow",
						"warning:.*parentheses",

						-- Compiler-specific errors
						-- GCC specific
						"internal compiler error",
						"ICE",
						"sorry, unimplemented",
						"confused by earlier errors",
						"too many errors",
						"compilation terminated",

						-- Clang specific
						"clang: error:",
						"fatal error:",
						"note: candidates are",
						"note: candidate",
						"note: in instantiation",
						"note: expanded from",

						-- MSVC specific
						"fatal error C",
						"error C",
						"warning C",
						"note C",
						"C1083:",
						"C2011:",
						"C2065:",
						"C2143:",
						"C2144:",
						"C2146:",
						"C2182:",
						"C2365:",
						"C2371:",
						"C2440:",
						"C2664:",
						"C2679:",
						"C2760:",
						"C3861:",
						"C4996:",
						"LNK2001:",
						"LNK2005:",
						"LNK2019:",
						"LNK2020:",
						"LNK1120:",

						-- Static analysis errors
						"static assertion failed",
						"static_assert",
						"constraint.*not satisfied",
						"concept.*not satisfied",
						"requires clause",
						"SFINAE",
						"substitution failure",
						"deduction failure",

						-- Runtime errors
						"assertion failed",
						"abort",
						"terminate",
						"unexpected",
						"exception",
						"signal",
						"SIGSEGV",
						"SIGABRT",
						"SIGFPE",
						"SIGILL",
						"SIGTERM",
						"SIGKILL",
						"SIGPIPE",
						"SIGHUP",
						"SIGINT",

						-- Thread and concurrency errors
						"data race",
						"race condition",
						"thread safety",
						"deadlock",
						"livelock",
						"mutex",
						"semaphore",
						"atomic",
						"memory order",
						"memory_order",
						"synchronization",
						"thread local",
						"thread_local",
						"concurrent access",
						"shared data",
						"critical section",

						-- Modern C++ errors
						"structured binding",
						"if constexpr",
						"fold expression",
						"inline variable",
						"deduction guide",
						"class template argument deduction",
						"CTAD",
						"designated initializer",
						"immediate function",
						"consteval",
						"constinit",
						"three%-way comparison",
						"spaceship operator",
						"<=>",
					}

					local is_error = false
					for _, keyword in ipairs(cpp_error_keywords) do
						if msg:match(keyword) then
							is_error = true
							break
						end
					end

					if is_error then
						table.insert(errors, item)
					else
						table.insert(warnings, item)
					end
				end

				local cpp_warning_patterns = {
					-- Format string warnings
					{ pattern = "format.*expects argument of type", type = "FORMAT-TYPE-MISMATCH" },
					{ pattern = "format.*too many arguments", type = "FORMAT-TOO-MANY-ARGS" },
					{ pattern = "format.*too few arguments", type = "FORMAT-TOO-FEW-ARGS" },
					{ pattern = "format string is not a string literal", type = "FORMAT-NOT-LITERAL" },
					{ pattern = "zero%-length.*format string", type = "FORMAT-EMPTY" },
					{ pattern = "unknown conversion type character", type = "FORMAT-UNKNOWN-CONVERSION" },
					{ pattern = "incomplete format specifier", type = "FORMAT-INCOMPLETE-SPEC" },
					{ pattern = "precision.*used with.*conversion", type = "FORMAT-PRECISION-INVALID" },
					{ pattern = "field width.*used with.*conversion", type = "FORMAT-WIDTH-INVALID" },
					{ pattern = "flag.*used with.*conversion", type = "FORMAT-FLAG-INVALID" },
					{ pattern = "length modifier.*used with.*conversion", type = "FORMAT-LENGTH-INVALID" },

					-- Conversion warnings
					{ pattern = "conversion from.*to.*may alter its value", type = "CONVERSION-VALUE-CHANGE" },
					{ pattern = "implicit conversion", type = "CONVERSION-IMPLICIT" },
					{ pattern = "narrowing conversion", type = "CONVERSION-NARROWING" },
					{ pattern = "lossy conversion", type = "CONVERSION-LOSSY" },
					{ pattern = "conversion.*loses precision", type = "CONVERSION-PRECISION-LOSS" },
					{ pattern = "signed.*unsigned conversion", type = "CONVERSION-SIGN-CHANGE" },
					{ pattern = "integer.*pointer conversion", type = "CONVERSION-INT-PTR" },
					{ pattern = "pointer.*integer conversion", type = "CONVERSION-PTR-INT" },
					{ pattern = "float.*integer conversion", type = "CONVERSION-FLOAT-INT" },
					{ pattern = "double.*float conversion", type = "CONVERSION-DOUBLE-FLOAT" },
					{ pattern = "conversion between function pointers", type = "CONVERSION-FUNC-PTR" },
					{ pattern = "const.*non%-const conversion", type = "CONVERSION-CONST-LOSS" },
					{ pattern = "volatile.*non%-volatile conversion", type = "CONVERSION-VOLATILE-LOSS" },

					-- Unused variable/function warnings
					{ pattern = "unused variable", type = "UNUSED-VARIABLE" },
					{ pattern = "unused parameter", type = "UNUSED-PARAMETER" },
					{ pattern = "unused function", type = "UNUSED-FUNCTION" },
					{ pattern = "unused value", type = "UNUSED-VALUE" },
					{ pattern = "unused result", type = "UNUSED-RESULT" },
					{ pattern = "unused label", type = "UNUSED-LABEL" },
					{ pattern = "unused typedef", type = "UNUSED-TYPEDEF" },
					{ pattern = "unused class", type = "UNUSED-CLASS" },
					{ pattern = "unused struct", type = "UNUSED-STRUCT" },
					{ pattern = "unused enum", type = "UNUSED-ENUM" },
					{ pattern = "unused namespace", type = "UNUSED-NAMESPACE" },
					{ pattern = "unused local variable", type = "UNUSED-LOCAL-VAR" },
					{ parameter = "unused member variable", type = "UNUSED-MEMBER-VAR" },
					{ pattern = "unused static function", type = "UNUSED-STATIC-FUNC" },
					{ pattern = "unused private field", type = "UNUSED-PRIVATE-FIELD" },
					{ pattern = "unused template parameter", type = "UNUSED-TEMPLATE-PARAM" },

					-- Uninitialized warnings
					{ pattern = "may be used uninitialized", type = "UNINITIALIZED-MAYBE" },
					{ pattern = "is used uninitialized", type = "UNINITIALIZED-DEFINITE" },
					{ pattern = "uninitialized variable", type = "UNINITIALIZED-VAR" },
					{ pattern = "uninitialized member", type = "UNINITIALIZED-MEMBER" },
					{ pattern = "uninitialized const", type = "UNINITIALIZED-CONST" },
					{ pattern = "uninitialized reference", type = "UNINITIALIZED-REF" },
					{ pattern = "reading uninitialized", type = "UNINITIALIZED-READ" },
					{ pattern = "potentially uninitialized", type = "UNINITIALIZED-POTENTIAL" },

					-- Array and pointer warnings
					{ pattern = "array subscript.*above array bounds", type = "ARRAY-BOUNDS-ABOVE" },
					{ pattern = "array subscript.*below array bounds", type = "ARRAY-BOUNDS-BELOW" },
					{ pattern = "array subscript.*type.*char", type = "ARRAY-SUBSCRIPT-CHAR" },
					{ pattern = "comparison between pointer and zero", type = "POINTER-ZERO-COMPARE" },
					{ pattern = "ordered comparison of pointer with", type = "POINTER-ORDERED-COMPARE" },
					{ pattern = "null pointer dereference", type = "NULL-POINTER-DEREF" },
					{ pattern = "use of null pointer", type = "NULL-POINTER-USE" },
					{ pattern = "possible null pointer dereference", type = "NULL-POINTER-POSSIBLE" },
					{ pattern = "returning reference to local", type = "REFERENCE-LOCAL-RETURN" },
					{ pattern = "returning address of local", type = "ADDRESS-LOCAL-RETURN" },
					{ pattern = "dangling pointer", type = "DANGLING-POINTER" },
					{ pattern = "buffer overflow", type = "BUFFER-OVERFLOW" },
					{ pattern = "buffer underflow", type = "BUFFER-UNDERFLOW" },
					{ pattern = "out of bounds", type = "OUT-OF-BOUNDS" },

					-- Comparison warnings
					{ pattern = "comparison.*always.*true", type = "COMPARISON-ALWAYS-TRUE" },
					{ pattern = "comparison.*always.*false", type = "COMPARISON-ALWAYS-FALSE" },
					{ pattern = "comparison.*constant", type = "COMPARISON-CONSTANT" },
					{ pattern = "comparison.*signed.*unsigned", type = "COMPARISON-SIGN-MISMATCH" },
					{ pattern = "comparison.*float.*equal", type = "COMPARISON-FLOAT-EQUAL" },
					{ pattern = "comparison.*string.*literals", type = "COMPARISON-STRING-LITERAL" },
					{ pattern = "self%-comparison", type = "COMPARISON-SELF" },
					{ pattern = "tautological comparison", type = "COMPARISON-TAUTOLOGICAL" },
					{ pattern = "redundant comparison", type = "COMPARISON-REDUNDANT" },

					-- Assignment warnings
					{ pattern = "assignment.*condition", type = "ASSIGNMENT-IN-CONDITION" },
					{ pattern = "assignment.*return", type = "ASSIGNMENT-IN-RETURN" },
					{ pattern = "assignment.*self", type = "ASSIGNMENT-SELF" },
					{ pattern = "assignment.*makes.*from.*without a cast", type = "ASSIGNMENT-CAST-NEEDED" },
					{ pattern = "assignment discards qualifiers", type = "ASSIGNMENT-QUALIFIER-LOSS" },
					{ pattern = "assignment from incompatible pointer type", type = "ASSIGNMENT-INCOMPATIBLE-PTR" },

					-- Parentheses and precedence warnings
					{ pattern = "suggest parentheses", type = "PARENTHESES-SUGGEST" },
					{ pattern = "precedence of.*and.*will be inverted", type = "PRECEDENCE-INVERTED" },
					{ pattern = "operator precedence", type = "PRECEDENCE-UNCLEAR" },
					{ pattern = "suggest explicit braces", type = "BRACES-SUGGEST" },
					{ pattern = "ambiguous.*else", type = "ELSE-AMBIGUOUS" },
					{ pattern = "misleading indentation", type = "INDENTATION-MISLEADING" },

					-- Type warnings
					{ pattern = "enum.*int.*conversion", type = "ENUM-INT-CONVERSION" },
					{ pattern = "passing.*incompatible pointer", type = "INCOMPATIBLE-POINTER-PASSING" },
					{ pattern = "return.*incompatible pointer", type = "INCOMPATIBLE-POINTER-RETURN" },
					{ pattern = "type.*declared inside parameter", type = "TYPE-IN-PARAMETER" },
					{ pattern = "anonymous.*declared inside parameter", type = "ANONYMOUS-IN-PARAMETER" },
					{ pattern = "struct.*declared inside parameter", type = "STRUCT-IN-PARAMETER" },
					{ pattern = "enum.*declared inside parameter", type = "ENUM-IN-PARAMETER" },

					-- Switch statement warnings
					{ pattern = "case label.*not within a switch", type = "CASE-OUTSIDE-SWITCH" },
					{ pattern = "switch.*has no case", type = "SWITCH-NO-CASE" },
					{ pattern = "enumeration value.*not handled", type = "SWITCH-ENUM-NOT-HANDLED" },
					{ pattern = "case.*not in enumerated type", type = "CASE-NOT-IN-ENUM" },
					{ pattern = "switch.*covers all enumeration", type = "SWITCH-COVERS-ALL" },
					{ pattern = "default label.*not within a switch", type = "DEFAULT-OUTSIDE-SWITCH" },
					{ pattern = "duplicate case", type = "DUPLICATE-CASE" },
					{ pattern = "case.*after default", type = "CASE-AFTER-DEFAULT" },

					-- Function warnings
					{ pattern = "function.*no return statement", type = "FUNCTION-NO-RETURN" },
					{ pattern = "function.*returns address of local", type = "FUNCTION-RETURN-LOCAL-ADDR" },
					{ pattern = "function.*return type defaults to", type = "FUNCTION-DEFAULT-RETURN-TYPE" },
					{ pattern = "function.*declared but never defined", type = "FUNCTION-DECLARED-NOT-DEFINED" },
					{ pattern = "function.*defined but not used", type = "FUNCTION-DEFINED-NOT-USED" },
					{ pattern = "missing function prototypes", type = "FUNCTION-MISSING-PROTOTYPE" },
					{ pattern = "old%-style function", type = "FUNCTION-OLD-STYLE" },
					{ pattern = "function call has aggregate value", type = "FUNCTION-CALL-AGGREGATE" },
					{ pattern = "implicit declaration of function", type = "FUNCTION-IMPLICIT-DECLARATION" },
					{ pattern = "conflicting types for function", type = "FUNCTION-CONFLICTING-TYPES" },

					-- Memory management warnings
					{ pattern = "memory leak", type = "MEMORY-LEAK" },
					{ pattern = "possible memory leak", type = "MEMORY-LEAK-POSSIBLE" },
					{ pattern = "double free", type = "MEMORY-DOUBLE-FREE" },
					{ pattern = "use after free", type = "MEMORY-USE-AFTER-FREE" },
					{ pattern = "invalid free", type = "MEMORY-INVALID-FREE" },
					{ pattern = "mismatched.*free", type = "MEMORY-MISMATCHED-FREE" },
					{ pattern = "malloc.*size.*zero", type = "MALLOC-ZERO-SIZE" },
					{ pattern = "realloc.*size.*zero", type = "REALLOC-ZERO-SIZE" },
					{ pattern = "potential null pointer", type = "MEMORY-NULL-POINTER-POTENTIAL" },

					-- C++ specific warnings
					{ pattern = "virtual.*destructor", type = "VIRTUAL-DESTRUCTOR" },
					{ pattern = "abstract class", type = "ABSTRACT-CLASS" },
					{ pattern = "pure virtual function", type = "PURE-VIRTUAL-FUNCTION" },
					{ pattern = "override.*virtual", type = "OVERRIDE-VIRTUAL" },
					{ pattern = "hiding virtual function", type = "HIDING-VIRTUAL" },
					{ pattern = "overloaded virtual function", type = "OVERLOADED-VIRTUAL" },
					{ pattern = "delete.*incomplete", type = "DELETE-INCOMPLETE" },
					{ pattern = "new.*delete.*mismatch", type = "NEW-DELETE-MISMATCH" },
					{ pattern = "exception.*not handled", type = "EXCEPTION-NOT-HANDLED" },
					{ pattern = "exception specification", type = "EXCEPTION-SPECIFICATION" },
					{ pattern = "throw.*destructor", type = "THROW-IN-DESTRUCTOR" },
					{ pattern = "multiple inheritance", type = "MULTIPLE-INHERITANCE" },
					{ pattern = "virtual base", type = "VIRTUAL-BASE" },
					{ pattern = "diamond.*inheritance", type = "DIAMOND-INHERITANCE" },

					-- Template warnings
					{ pattern = "template.*instantiation", type = "TEMPLATE-INSTANTIATION" },
					{ pattern = "template.*specialization", type = "TEMPLATE-SPECIALIZATION" },
					{ pattern = "template.*argument", type = "TEMPLATE-ARGUMENT" },
					{ pattern = "template.*parameter.*unused", type = "TEMPLATE-PARAM-UNUSED" },
					{ pattern = "template.*recursive", type = "TEMPLATE-RECURSIVE" },
					{ pattern = "instantiation.*too deep", type = "TEMPLATE-INSTANTIATION-DEPTH" },
					{ pattern = "template.*ambiguous", type = "TEMPLATE-AMBIGUOUS" },

					-- Modern C++ warnings (C++11/14/17/20)
					{ pattern = "auto.*deduced.*void", type = "AUTO-DEDUCED-VOID" },
					{ pattern = "lambda.*capture", type = "LAMBDA-CAPTURE" },
					{ pattern = "lambda.*unused", type = "LAMBDA-UNUSED" },
					{ pattern = "range%-based.*loop", type = "RANGE-BASED-LOOP" },
					{ pattern = "nullptr.*comparison", type = "NULLPTR-COMPARISON" },
					{ pattern = "move.*after.*move", type = "MOVE-AFTER-MOVE" },
					{ pattern = "use after move", type = "USE-AFTER-MOVE" },
					{ pattern = "redundant.*move", type = "REDUNDANT-MOVE" },
					{ pattern = "perfect forwarding", type = "PERFECT-FORWARDING" },
					{ pattern = "structured binding", type = "STRUCTURED-BINDING" },
					{ pattern = "if constexpr", type = "IF-CONSTEXPR" },
					{ pattern = "fold expression", type = "FOLD-EXPRESSION" },
					{ pattern = "constexpr.*not.*constant", type = "CONSTEXPR-NOT-CONSTANT" },
					{ pattern = "consteval", type = "CONSTEVAL" },
					{ pattern = "constinit", type = "CONSTINIT" },
					{ pattern = "concept.*not.*satisfied", type = "CONCEPT-NOT-SATISFIED" },
					{ pattern = "requires.*clause", type = "REQUIRES-CLAUSE" },
					{ pattern = "coroutine", type = "COROUTINE" },
					{ pattern = "co_await", type = "CO-AWAIT" },
					{ pattern = "co_yield", type = "CO-YIELD" },
					{ pattern = "co_return", type = "CO-RETURN" },
					{ pattern = "module", type = "MODULE" },
					{ pattern = "export", type = "EXPORT" },
					{ pattern = "import", type = "IMPORT" },

					-- Thread safety warnings
					{ pattern = "thread safety", type = "THREAD-SAFETY" },
					{ pattern = "data race", type = "DATA-RACE" },
					{ pattern = "race condition", type = "RACE-CONDITION" },
					{ pattern = "atomic.*operation", type = "ATOMIC-OPERATION" },
					{ pattern = "mutex.*lock", type = "MUTEX-LOCK" },
					{ pattern = "deadlock", type = "DEADLOCK" },
					{ pattern = "livelock", type = "LIVELOCK" },
					{ pattern = "thread.*local", type = "THREAD-LOCAL" },
					{ pattern = "shared.*data", type = "SHARED-DATA" },
					{ pattern = "synchronization", type = "SYNCHRONIZATION" },

					-- Performance warnings
					{ pattern = "inefficient.*copy", type = "INEFFICIENT-COPY" },
					{ pattern = "unnecessary.*copy", type = "UNNECESSARY-COPY" },
					{ pattern = "pass.*by.*reference", type = "PASS-BY-REFERENCE" },
					{ pattern = "return.*value.*optimization", type = "RVO" },
					{ pattern = "named.*return.*value.*optimization", type = "NRVO" },
					{ pattern = "inline.*function", type = "INLINE-FUNCTION" },
					{ pattern = "virtual.*inline", type = "VIRTUAL-INLINE" },
					{ pattern = "expensive.*operation.*in.*loop", type = "EXPENSIVE-OPERATION-LOOP" },
					{ pattern = "allocation.*in.*loop", type = "ALLOCATION-IN-LOOP" },
					{ pattern = "string.*concatenation.*loop", type = "STRING-CONCAT-LOOP" },

					-- Deprecated warnings
					{ pattern = "deprecated", type = "DEPRECATED" },
					{ pattern = "obsolete", type = "OBSOLETE" },
					{ pattern = "legacy", type = "LEGACY" },
					{ pattern = "removed.*in.*C", type = "REMOVED-FEATURE" },
					{ pattern = "auto_ptr.*deprecated", type = "AUTO-PTR-DEPRECATED" },
					{ pattern = "register.*keyword.*deprecated", type = "REGISTER-DEPRECATED" },
					{ pattern = "throw.*specification.*deprecated", type = "THROW-SPEC-DEPRECATED" },
					{ pattern = "trigraphs.*deprecated", type = "TRIGRAPHS-DEPRECATED" },

					-- Security warnings
					{ pattern = "buffer.*overflow.*possible", type = "SECURITY-BUFFER-OVERFLOW" },
					{ pattern = "format.*string.*attack", type = "SECURITY-FORMAT-STRING" },
					{ pattern = "gets.*unsafe", type = "SECURITY-GETS-UNSAFE" },
					{ pattern = "strcpy.*unsafe", type = "SECURITY-STRCPY-UNSAFE" },
					{ pattern = "sprintf.*unsafe", type = "SECURITY-SPRINTF-UNSAFE" },
					{ pattern = "scanf.*unsafe", type = "SECURITY-SCANF-UNSAFE" },
					{ pattern = "rand.*predictable", type = "SECURITY-RAND-PREDICTABLE" },
					{ pattern = "temporary.*file.*race", type = "SECURITY-TEMP-FILE-RACE" },
					{ pattern = "shell.*injection", type = "SECURITY-SHELL-INJECTION" },
					{ pattern = "path.*traversal", type = "SECURITY-PATH-TRAVERSAL" },
					{ pattern = "integer.*overflow.*possible", type = "SECURITY-INTEGER-OVERFLOW" },
					{ pattern = "signed.*integer.*overflow", type = "SECURITY-SIGNED-OVERFLOW" },
					{ pattern = "uncontrolled.*format.*string", type = "SECURITY-FORMAT-UNCONTROLLED" },

					-- Static analysis warnings
					{ pattern = "potential.*null.*dereference", type = "STATIC-NULL-DEREF" },
					{ pattern = "potential.*buffer.*overflow", type = "STATIC-BUFFER-OVERFLOW" },
					{ pattern = "potential.*memory.*leak", type = "STATIC-MEMORY-LEAK" },
					{ pattern = "potential.*use.*after.*free", type = "STATIC-USE-AFTER-FREE" },
					{ pattern = "potential.*double.*free", type = "STATIC-DOUBLE-FREE" },
					{ pattern = "potential.*infinite.*loop", type = "STATIC-INFINITE-LOOP" },
					{ pattern = "potential.*stack.*overflow", type = "STATIC-STACK-OVERFLOW" },
					{ pattern = "dead.*code", type = "STATIC-DEAD-CODE" },
					{ pattern = "unreachable.*code", type = "STATIC-UNREACHABLE-CODE" },
					{ pattern = "code.*will.*never.*be.*executed", type = "STATIC-NEVER-EXECUTED" },

					-- Compiler-specific warnings
					-- GCC warnings
					{ pattern = "suggest.*explicit.*braces", type = "GCC-SUGGEST-BRACES" },
					{ pattern = "suggest.*parentheses", type = "GCC-SUGGEST-PARENTHESES" },
					{ pattern = "maybe%-uninitialized", type = "GCC-MAYBE-UNINITIALIZED" },
					{ pattern = "stringop%-overflow", type = "GCC-STRINGOP-OVERFLOW" },
					{ pattern = "stringop%-truncation", type = "GCC-STRINGOP-TRUNCATION" },
					{ pattern = "array%-bounds", type = "GCC-ARRAY-BOUNDS" },
					{ pattern = "restrict", type = "GCC-RESTRICT" },
					{ pattern = "builtin%-declaration%-mismatch", type = "GCC-BUILTIN-MISMATCH" },
					{ pattern = "cast%-function%-type", type = "GCC-CAST-FUNCTION-TYPE" },
					{ pattern = "missing%-field%-initializers", type = "GCC-MISSING-FIELD-INIT" },
					{ pattern = "sign%-compare", type = "GCC-SIGN-COMPARE" },
					{ pattern = "type%-limits", type = "GCC-TYPE-LIMITS" },
					{ pattern = "unused%-but%-set", type = "GCC-UNUSED-BUT-SET" },
					{ pattern = "sequence%-point", type = "GCC-SEQUENCE-POINT" },
					{ pattern = "strict%-aliasing", type = "GCC-STRICT-ALIASING" },
					{ pattern = "strict%-overflow", type = "GCC-STRICT-OVERFLOW" },
					{ pattern = "uninitialized", type = "GCC-UNINITIALIZED" },
					{ pattern = "maybe%-uninitialized", type = "GCC-MAYBE-UNINITIALIZED" },
					{ pattern = "aggressive%-loop%-optimizations", type = "GCC-AGGRESSIVE-LOOP-OPT" },
					{ pattern = "pedantic", type = "GCC-PEDANTIC" },
					{ pattern = "extra", type = "GCC-EXTRA" },
					{ pattern = "Wall", type = "GCC-WALL" },
					{ pattern = "Wextra", type = "GCC-WEXTRA" },

					-- Clang warnings
					{ pattern = "unused%-private%-field", type = "CLANG-UNUSED-PRIVATE-FIELD" },
					{ pattern = "potential%-evaluated%-expression", type = "CLANG-POTENTIAL-EVAL-EXPR" },
					{ pattern = "unused%-lambda%-capture", type = "CLANG-UNUSED-LAMBDA-CAPTURE" },
					{ pattern = "inconsistent%-missing%-override", type = "CLANG-MISSING-OVERRIDE" },
					{ pattern = "delete%-non%-virtual%-dtor", type = "CLANG-DELETE-NON-VIRTUAL-DTOR" },
					{ pattern = "infinite%-recursion", type = "CLANG-INFINITE-RECURSION" },
					{ pattern = "tautological%-compare", type = "CLANG-TAUTOLOGICAL-COMPARE" },
					{ pattern = "self%-assign", type = "CLANG-SELF-ASSIGN" },
					{ pattern = "self%-move", type = "CLANG-SELF-MOVE" },
					{ pattern = "dangling%-else", type = "CLANG-DANGLING-ELSE" },
					{ pattern = "logical%-op%-parentheses", type = "CLANG-LOGICAL-OP-PARENTHESES" },
					{ pattern = "bitwise%-op%-parentheses", type = "CLANG-BITWISE-OP-PARENTHESES" },
					{ pattern = "shift%-op%-parentheses", type = "CLANG-SHIFT-OP-PARENTHESES" },
					{ pattern = "overloaded%-shift%-op%-parentheses", type = "CLANG-OVERLOADED-SHIFT-OP" },
					{ pattern = "missing%-braces", type = "CLANG-MISSING-BRACES" },
					{ pattern = "missing%-field%-initializers", type = "CLANG-MISSING-FIELD-INIT" },
					{ pattern = "gnu%-extensions", type = "CLANG-GNU-EXTENSIONS" },
					{ pattern = "microsoft%-extensions", type = "CLANG-MICROSOFT-EXTENSIONS" },
					{ pattern = "c%+%+98%-compat", type = "CLANG-CPP98-COMPAT" },
					{ pattern = "c%+%+11%-compat", type = "CLANG-CPP11-COMPAT" },
					{ pattern = "c%+%+14%-compat", type = "CLANG-CPP14-COMPAT" },
					{ pattern = "c%+%+17%-compat", type = "CLANG-CPP17-COMPAT" },
					{ pattern = "c%+%+20%-compat", type = "CLANG-CPP20-COMPAT" },

					-- MSVC warnings
					{ pattern = "C4101.*unreferenced.*local.*variable", type = "MSVC-UNREFERENCED-LOCAL" },
					{
						pattern = "C4189.*local.*variable.*initialized.*not.*referenced",
						type = "MSVC-LOCAL-INIT-NOT-REF",
					},
					{ pattern = "C4996.*deprecated", type = "MSVC-DEPRECATED" },
					{ pattern = "C4244.*conversion.*possible.*loss.*of.*data", type = "MSVC-CONVERSION-DATA-LOSS" },
					{ pattern = "C4267.*conversion.*possible.*loss.*of.*data", type = "MSVC-SIZE-T-CONVERSION" },
					{ pattern = "C4305.*truncation.*from.*to", type = "MSVC-TRUNCATION" },
					{ pattern = "C4100.*unreferenced.*formal.*parameter", type = "MSVC-UNREFERENCED-PARAM" },
					{ pattern = "C4702.*unreachable.*code", type = "MSVC-UNREACHABLE-CODE" },
					{ pattern = "C4706.*assignment.*within.*conditional", type = "MSVC-ASSIGNMENT-IN-CONDITIONAL" },
					{ pattern = "C4709.*comma.*operator.*within.*array.*index", type = "MSVC-COMMA-IN-ARRAY-INDEX" },
					{ pattern = "C4715.*not.*all.*control.*paths.*return", type = "MSVC-NOT-ALL-PATHS-RETURN" },
					{ pattern = "C4700.*uninitialized.*local.*variable", type = "MSVC-UNINITIALIZED-LOCAL" },
					{
						pattern = "C4701.*potentially.*uninitialized.*local.*variable",
						type = "MSVC-POTENTIALLY-UNINITIALIZED",
					},
					{
						pattern = "C4703.*potentially.*uninitialized.*local.*pointer",
						type = "MSVC-POTENTIALLY-UNINITIALIZED-PTR",
					},
					{ pattern = "C4389.*signed.*unsigned.*mismatch", type = "MSVC-SIGNED-UNSIGNED-MISMATCH" },
					{ pattern = "C4018.*signed.*unsigned.*mismatch", type = "MSVC-SIGNED-UNSIGNED-COMPARISON" },
					{ pattern = "C4309.*truncation.*of.*constant.*value", type = "MSVC-CONSTANT-TRUNCATION" },
					{ pattern = "C4310.*cast.*truncates.*constant.*value", type = "MSVC-CAST-TRUNCATES-CONSTANT" },
					{ pattern = "C4146.*unary.*minus.*applied.*to.*unsigned", type = "MSVC-UNARY-MINUS-UNSIGNED" },
					{ pattern = "C4804.*unsafe.*use.*of.*type.*bool", type = "MSVC-UNSAFE-BOOL" },
					{ pattern = "C4805.*unsafe.*mix.*of.*type.*and.*type", type = "MSVC-UNSAFE-MIX" },
					{ pattern = "C4806.*unsafe.*operation", type = "MSVC-UNSAFE-OPERATION" },
					{ pattern = "C4800.*implicit.*conversion.*from.*to.*bool", type = "MSVC-IMPLICIT-BOOL-CONVERSION" },

					-- Intel Compiler warnings
					{ pattern = "remark.*loop.*was.*vectorized", type = "INTEL-LOOP-VECTORIZED" },
					{ pattern = "remark.*loop.*was.*not.*vectorized", type = "INTEL-LOOP-NOT-VECTORIZED" },
					{ pattern = "remark.*LOOP.*WAS.*VECTORIZED", type = "INTEL-LOOP-VECTORIZED-CAPS" },
					{ pattern = "warning.*declared.*but.*never.*referenced", type = "INTEL-DECLARED-NOT-REFERENCED" },
					{ pattern = "warning.*variable.*was.*set.*but.*never.*used", type = "INTEL-SET-NOT-USED" },

					-- Linker warnings
					{ pattern = "ld.*warning", type = "LINKER-WARNING" },
					{ pattern = "link.*warning", type = "LINK-WARNING" },
					{ pattern = "duplicate.*symbol", type = "LINKER-DUPLICATE-SYMBOL" },
					{ pattern = "weak.*symbol", type = "LINKER-WEAK-SYMBOL" },
					{ pattern = "undefined.*symbol.*weak", type = "LINKER-UNDEFINED-WEAK" },
					{ pattern = "relocation.*truncated", type = "LINKER-RELOCATION-TRUNCATED" },
					{ pattern = "text.*relocation", type = "LINKER-TEXT-RELOCATION" },
					{ pattern = "direct.*access.*in.*function", type = "LINKER-DIRECT-ACCESS" },
					{ pattern = "creating.*DT_TEXTREL", type = "LINKER-DT-TEXTREL" },
					{ pattern = "missing.*needed.*library", type = "LINKER-MISSING-LIBRARY" },
					{ pattern = "library.*not.*found", type = "LINKER-LIBRARY-NOT-FOUND" },
					{ pattern = "cannot.*find.*entry.*symbol", type = "LINKER-NO-ENTRY-SYMBOL" },

					-- Sanitizer warnings (AddressSanitizer, ThreadSanitizer, etc.)
					{ pattern = "AddressSanitizer", type = "ASAN-WARNING" },
					{ pattern = "ThreadSanitizer", type = "TSAN-WARNING" },
					{ pattern = "MemorySanitizer", type = "MSAN-WARNING" },
					{ pattern = "UndefinedBehaviorSanitizer", type = "UBSAN-WARNING" },
					{ pattern = "LeakSanitizer", type = "LSAN-WARNING" },
					{ pattern = "heap%-buffer%-overflow", type = "ASAN-HEAP-BUFFER-OVERFLOW" },
					{ pattern = "stack%-buffer%-overflow", type = "ASAN-STACK-BUFFER-OVERFLOW" },
					{ pattern = "global%-buffer%-overflow", type = "ASAN-GLOBAL-BUFFER-OVERFLOW" },
					{ pattern = "use%-after%-free", type = "ASAN-USE-AFTER-FREE" },
					{ pattern = "use%-after%-return", type = "ASAN-USE-AFTER-RETURN" },
					{ pattern = "use%-after%-scope", type = "ASAN-USE-AFTER-SCOPE" },
					{ pattern = "double%-free", type = "ASAN-DOUBLE-FREE" },
					{ pattern = "invalid%-free", type = "ASAN-INVALID-FREE" },
					{ pattern = "alloc%-dealloc%-mismatch", type = "ASAN-ALLOC-DEALLOC-MISMATCH" },
					{ pattern = "data.*race", type = "TSAN-DATA-RACE" },
					{ pattern = "race.*on.*vptr", type = "TSAN-VPTR-RACE" },
					{ pattern = "use.*of.*uninitialized.*value", type = "MSAN-UNINITIALIZED" },
					{ pattern = "signed.*integer.*overflow", type = "UBSAN-SIGNED-OVERFLOW" },
					{ pattern = "unsigned.*integer.*overflow", type = "UBSAN-UNSIGNED-OVERFLOW" },
					{ pattern = "division.*by.*zero", type = "UBSAN-DIVISION-BY-ZERO" },
					{ pattern = "null.*pointer.*dereference", type = "UBSAN-NULL-DEREF" },
					{ pattern = "misaligned.*address", type = "UBSAN-MISALIGNED" },
					{ pattern = "load.*of.*null.*pointer", type = "UBSAN-LOAD-NULL" },
					{ pattern = "store.*to.*null.*pointer", type = "UBSAN-STORE-NULL" },
					{ pattern = "member.*access.*within.*null.*pointer", type = "UBSAN-MEMBER-ACCESS-NULL" },
					{ pattern = "member.*call.*on.*null.*pointer", type = "UBSAN-MEMBER-CALL-NULL" },
					{ pattern = "downcast.*of.*address", type = "UBSAN-BAD-DOWNCAST" },
					{ pattern = "upcast.*of.*address", type = "UBSAN-BAD-UPCAST" },
					{ pattern = "cast.*to.*virtual.*base", type = "UBSAN-CAST-VIRTUAL-BASE" },
					{ pattern = "invalid.*enum.*value", type = "UBSAN-INVALID-ENUM" },
					{ pattern = "invalid.*boolean.*value", type = "UBSAN-INVALID-BOOL" },
					{ pattern = "shift.*exponent.*too.*large", type = "UBSAN-SHIFT-EXPONENT" },
					{ pattern = "shift.*of.*negative.*value", type = "UBSAN-SHIFT-NEGATIVE" },
					{ pattern = "left.*shift.*of.*negative.*value", type = "UBSAN-LEFT-SHIFT-NEGATIVE" },
					{ pattern = "negation.*of.*unsigned.*value", type = "UBSAN-NEGATE-UNSIGNED" },
					{ pattern = "subtraction.*overflow", type = "UBSAN-SUB-OVERFLOW" },
					{ pattern = "addition.*overflow", type = "UBSAN-ADD-OVERFLOW" },
					{ pattern = "multiplication.*overflow", type = "UBSAN-MUL-OVERFLOW" },
					{ pattern = "invalid.*vla.*bound", type = "UBSAN-INVALID-VLA-BOUND" },
					{
						pattern = "variable.*length.*array.*bound.*not.*positive",
						type = "UBSAN-VLA-BOUND-NOT-POSITIVE",
					},

					-- Valgrind warnings
					{ pattern = "Valgrind", type = "VALGRIND-WARNING" },
					{ pattern = "Invalid.*read.*of.*size", type = "VALGRIND-INVALID-READ" },
					{ pattern = "Invalid.*write.*of.*size", type = "VALGRIND-INVALID-WRITE" },
					{
						pattern = "Conditional.*jump.*or.*move.*depends.*on.*uninitialised",
						type = "VALGRIND-UNINIT-CONDITIONAL",
					},
					{ pattern = "Use.*of.*uninitialised.*value", type = "VALGRIND-USE-UNINIT" },
					{ pattern = "Syscall.*param.*contains.*uninitialised", type = "VALGRIND-SYSCALL-UNINIT" },
					{ pattern = "definitely.*lost.*in.*loss.*record", type = "VALGRIND-DEFINITELY-LOST" },
					{ pattern = "possibly.*lost.*in.*loss.*record", type = "VALGRIND-POSSIBLY-LOST" },
					{ pattern = "still.*reachable.*in.*loss.*record", type = "VALGRIND-STILL-REACHABLE" },
					{ pattern = "HEAP.*SUMMARY", type = "VALGRIND-HEAP-SUMMARY" },
					{ pattern = "LEAK.*SUMMARY", type = "VALGRIND-LEAK-SUMMARY" },
					{ pattern = "blocks.*are.*definitely.*lost", type = "VALGRIND-BLOCKS-LOST" },
					{ pattern = "blocks.*are.*indirectly.*lost", type = "VALGRIND-BLOCKS-INDIRECT" },
					{ pattern = "blocks.*are.*possibly.*lost", type = "VALGRIND-BLOCKS-POSSIBLE" },
					{ pattern = "blocks.*are.*still.*reachable", type = "VALGRIND-BLOCKS-REACHABLE" },
				}

				-- Apply warning patterns

				for _, p in ipairs(cpp_warning_patterns) do
					if type(line) == "string" then
						local ok, matched = pcall(line.match, line, p.pattern)
						if ok and matched then
							table.insert(warnings, {
								filename = vim.fn.expand("%"),
								lnum = 1,
								text = line,
								display = p.type .. ": " .. line,
							})
							break
						end
					end
				end

				local runtime_patterns = {
					-- Signal-based errors
					{ pattern = "SIGSEGV", type = "SEGFAULT" },
					{ pattern = "Segmentation fault", type = "SEGFAULT" },
					{ pattern = "segmentation fault", type = "SEGFAULT" },
					{ pattern = "Program received signal SIGSEGV", type = "SEGFAULT" },
					{ pattern = "Process terminated with signal SIGSEGV", type = "SEGFAULT" },
					{ pattern = "Segmentation violation", type = "SEGFAULT" },
					{ pattern = "Access violation", type = "SEGFAULT" },
					{ pattern = "Memory access violation", type = "SEGFAULT" },
					{ pattern = "Invalid memory reference", type = "SEGFAULT" },
					{ pattern = "Memory protection fault", type = "SEGFAULT" },

					{ pattern = "SIGABRT", type = "ABORT" },
					{ pattern = "Aborted", type = "ABORT" },
					{ pattern = "abort%(%) called", type = "ABORT" },
					{ pattern = "Program aborted", type = "ABORT" },
					{ pattern = "Process aborted", type = "ABORT" },
					{ pattern = "Abnormal termination", type = "ABORT" },
					{ pattern = "Program terminated abnormally", type = "ABORT" },
					{ pattern = "Fatal error: Aborted", type = "ABORT" },
					{ pattern = "terminate called after throwing", type = "ABORT" },
					{ pattern = "terminate called without an active exception", type = "ABORT" },
					{ pattern = "std::terminate called", type = "ABORT" },

					{ pattern = "SIGFPE", type = "FLOATING_POINT_EXCEPTION" },
					{ pattern = "Floating point exception", type = "FLOATING_POINT_EXCEPTION" },
					{ pattern = "Division by zero", type = "FLOATING_POINT_EXCEPTION" },
					{ pattern = "Arithmetic overflow", type = "FLOATING_POINT_EXCEPTION" },
					{ pattern = "Arithmetic underflow", type = "FLOATING_POINT_EXCEPTION" },
					{ pattern = "Invalid floating point operation", type = "FLOATING_POINT_EXCEPTION" },
					{ pattern = "Floating point overflow", type = "FLOATING_POINT_EXCEPTION" },
					{ pattern = "Floating point underflow", type = "FLOATING_POINT_EXCEPTION" },
					{ pattern = "Floating point divide by zero", type = "FLOATING_POINT_EXCEPTION" },
					{ pattern = "Inexact floating point result", type = "FLOATING_POINT_EXCEPTION" },
					{ pattern = "Invalid floating point result", type = "FLOATING_POINT_EXCEPTION" },
					{ pattern = "NaN result in floating point operation", type = "FLOATING_POINT_EXCEPTION" },
					{ pattern = "Infinity result in floating point operation", type = "FLOATING_POINT_EXCEPTION" },

					{ pattern = "SIGILL", type = "ILLEGAL_INSTRUCTION" },
					{ pattern = "Illegal instruction", type = "ILLEGAL_INSTRUCTION" },
					{ pattern = "Invalid instruction", type = "ILLEGAL_INSTRUCTION" },
					{ pattern = "Privileged instruction", type = "ILLEGAL_INSTRUCTION" },
					{ pattern = "Undefined instruction", type = "ILLEGAL_INSTRUCTION" },
					{ pattern = "Illegal opcode", type = "ILLEGAL_INSTRUCTION" },
					{ pattern = "Invalid opcode", type = "ILLEGAL_INSTRUCTION" },
					{ pattern = "Instruction decode error", type = "ILLEGAL_INSTRUCTION" },
					{ pattern = "Malformed instruction", type = "ILLEGAL_INSTRUCTION" },
					{ pattern = "Reserved instruction", type = "ILLEGAL_INSTRUCTION" },

					{ pattern = "SIGBUS", type = "BUS_ERROR" },
					{ pattern = "Bus error", type = "BUS_ERROR" },
					{ pattern = "Alignment error", type = "BUS_ERROR" },
					{ pattern = "Memory bus error", type = "BUS_ERROR" },
					{ pattern = "Hardware error", type = "BUS_ERROR" },
					{ pattern = "Unaligned memory access", type = "BUS_ERROR" },
					{ pattern = "Invalid memory alignment", type = "BUS_ERROR" },
					{ pattern = "Memory parity error", type = "BUS_ERROR" },
					{ pattern = "Non%-existent physical address", type = "BUS_ERROR" },
					{ pattern = "Object specific hardware error", type = "BUS_ERROR" },

					{ pattern = "SIGPIPE", type = "BROKEN_PIPE" },
					{ pattern = "Broken pipe", type = "BROKEN_PIPE" },
					{ pattern = "Write on a pipe with no reader", type = "BROKEN_PIPE" },
					{ pattern = "EPIPE", type = "BROKEN_PIPE" },
					{ pattern = "Pipe broken", type = "BROKEN_PIPE" },
					{ pattern = "Write to broken pipe", type = "BROKEN_PIPE" },

					{ pattern = "SIGTERM", type = "TERMINATED" },
					{ pattern = "Terminated", type = "TERMINATED" },
					{ pattern = "Process terminated", type = "TERMINATED" },
					{ pattern = "Program terminated", type = "TERMINATED" },
					{ pattern = "Termination requested", type = "TERMINATED" },
					{ pattern = "Graceful termination", type = "TERMINATED" },
					{ pattern = "Software termination signal", type = "TERMINATED" },

					{ pattern = "SIGKILL", type = "KILLED" },
					{ pattern = "Killed", type = "KILLED" },
					{ pattern = "Process killed", type = "KILLED" },
					{ pattern = "Program killed", type = "KILLED" },
					{ pattern = "Forcefully terminated", type = "KILLED" },
					{ pattern = "Process forcibly killed", type = "KILLED" },
					{ pattern = "Kill signal received", type = "KILLED" },

					{ pattern = "SIGTRAP", type = "TRAP" },
					{ pattern = "Trace trap", type = "TRAP" },
					{ pattern = "Breakpoint trap", type = "TRAP" },
					{ pattern = "Debug trap", type = "TRAP" },
					{ pattern = "Trace/breakpoint trap", type = "TRAP" },
					{ pattern = "Process trace", type = "TRAP" },
					{ pattern = "Breakpoint hit", type = "TRAP" },

					{ pattern = "SIGCHLD", type = "CHILD_PROCESS" },
					{ pattern = "Child exited", type = "CHILD_PROCESS" },
					{ pattern = "Child process terminated", type = "CHILD_PROCESS" },
					{ pattern = "Child process stopped", type = "CHILD_PROCESS" },
					{ pattern = "Child process continued", type = "CHILD_PROCESS" },
					{ pattern = "Child status changed", type = "CHILD_PROCESS" },

					{ pattern = "SIGALRM", type = "ALARM" },
					{ pattern = "Alarm clock", type = "ALARM" },
					{ pattern = "Timer expired", type = "ALARM" },
					{ pattern = "Timeout", type = "ALARM" },
					{ pattern = "Real%-time timer expired", type = "ALARM" },
					{ pattern = "Virtual timer expired", type = "ALARM" },
					{ pattern = "Profiling timer expired", type = "ALARM" },

					{ pattern = "SIGUSR1", type = "USER_SIGNAL_1" },
					{ pattern = "SIGUSR2", type = "USER_SIGNAL_2" },
					{ pattern = "User defined signal 1", type = "USER_SIGNAL_1" },
					{ pattern = "User defined signal 2", type = "USER_SIGNAL_2" },

					{ pattern = "SIGQUIT", type = "QUIT" },
					{ pattern = "Quit", type = "QUIT" },
					{ pattern = "Quit signal", type = "QUIT" },
					{ pattern = "Quit from keyboard", type = "QUIT" },
					{ pattern = "Keyboard quit", type = "QUIT" },

					{ pattern = "SIGTSTP", type = "TERMINAL_STOP" },
					{ pattern = "Stopped", type = "TERMINAL_STOP" },
					{ pattern = "Terminal stop", type = "TERMINAL_STOP" },
					{ pattern = "Keyboard stop", type = "TERMINAL_STOP" },
					{ pattern = "Process stopped", type = "TERMINAL_STOP" },

					{ pattern = "SIGCONT", type = "CONTINUE" },
					{ pattern = "Continued", type = "CONTINUE" },
					{ pattern = "Process continued", type = "CONTINUE" },
					{ pattern = "Resume execution", type = "CONTINUE" },

					{ pattern = "SIGWINCH", type = "WINDOW_CHANGE" },
					{ pattern = "Window size changed", type = "WINDOW_CHANGE" },
					{ pattern = "Terminal window changed", type = "WINDOW_CHANGE" },

					{ pattern = "SIGIO", type = "IO_POSSIBLE" },
					{ pattern = "I/O possible", type = "IO_POSSIBLE" },
					{ pattern = "Asynchronous I/O", type = "IO_POSSIBLE" },
					{ pattern = "SIGPOLL", type = "IO_POSSIBLE" },
					{ pattern = "Pollable event", type = "IO_POSSIBLE" },

					{ pattern = "SIGURG", type = "URGENT_CONDITION" },
					{ pattern = "Urgent condition", type = "URGENT_CONDITION" },
					{ pattern = "Socket urgent condition", type = "URGENT_CONDITION" },
					{ pattern = "Out%-of%-band data", type = "URGENT_CONDITION" },

					-- Stack and heap errors
					{ pattern = "Stack overflow", type = "STACK_OVERFLOW" },
					{ pattern = "stack overflow", type = "STACK_OVERFLOW" },
					{ pattern = "Stack smashing detected", type = "STACK_SMASH" },
					{ pattern = "__stack_chk_fail", type = "STACK_SMASH" },
					{ pattern = "Stack buffer overflow", type = "STACK_OVERFLOW" },
					{ pattern = "Call stack overflow", type = "STACK_OVERFLOW" },
					{ pattern = "Maximum recursion depth exceeded", type = "STACK_OVERFLOW" },
					{ pattern = "Infinite recursion detected", type = "STACK_OVERFLOW" },
					{ pattern = "Stack exhausted", type = "STACK_OVERFLOW" },
					{ pattern = "Stack space exhausted", type = "STACK_OVERFLOW" },

					{ pattern = "Heap corruption", type = "HEAP_CORRUPTION" },
					{ pattern = "Heap overflow", type = "HEAP_CORRUPTION" },
					{ pattern = "Heap underflow", type = "HEAP_CORRUPTION" },
					{ pattern = "Corrupted heap", type = "HEAP_CORRUPTION" },
					{ pattern = "Invalid heap pointer", type = "HEAP_CORRUPTION" },
					{ pattern = "Heap block corrupted", type = "HEAP_CORRUPTION" },
					{ pattern = "Free list corrupted", type = "HEAP_CORRUPTION" },
					{ pattern = "Heap metadata corrupted", type = "HEAP_CORRUPTION" },

					-- Exception handling
					{ pattern = "Unhandled exception", type = "UNHANDLED_EXCEPTION" },
					{ pattern = "Uncaught exception", type = "UNHANDLED_EXCEPTION" },
					{ pattern = "Exception not handled", type = "UNHANDLED_EXCEPTION" },
					{ pattern = "std::exception", type = "STD_EXCEPTION" },
					{ pattern = "std::runtime_error", type = "RUNTIME_ERROR" },
					{ pattern = "std::logic_error", type = "LOGIC_ERROR" },
					{ pattern = "std::invalid_argument", type = "INVALID_ARGUMENT" },
					{ pattern = "std::out_of_range", type = "OUT_OF_RANGE" },
					{ pattern = "std::length_error", type = "LENGTH_ERROR" },
					{ pattern = "std::domain_error", type = "DOMAIN_ERROR" },
					{ pattern = "std::range_error", type = "RANGE_ERROR" },
					{ pattern = "std::overflow_error", type = "OVERFLOW_ERROR" },
					{ pattern = "std::underflow_error", type = "UNDERFLOW_ERROR" },
					{ pattern = "std::bad_alloc", type = "BAD_ALLOC" },
					{ pattern = "std::bad_cast", type = "BAD_CAST" },
					{ pattern = "std::bad_typeid", type = "BAD_TYPEID" },
					{ pattern = "std::bad_exception", type = "BAD_EXCEPTION" },
					{ pattern = "std::bad_weak_ptr", type = "BAD_WEAK_PTR" },
					{ pattern = "std::bad_function_call", type = "BAD_FUNCTION_CALL" },
					{ pattern = "std::bad_array_new_length", type = "BAD_ARRAY_NEW_LENGTH" },
					{ pattern = "std::system_error", type = "SYSTEM_ERROR" },
					{ pattern = "std::ios_base::failure", type = "IOS_FAILURE" },
					{ pattern = "std::future_error", type = "FUTURE_ERROR" },
					{ pattern = "std::regex_error", type = "REGEX_ERROR" },
					{ pattern = "std::filesystem::filesystem_error", type = "FILESYSTEM_ERROR" },

					-- Memory allocation errors
					{ pattern = "Out of memory", type = "OUT_OF_MEMORY" },
					{ pattern = "Memory allocation failed", type = "OUT_OF_MEMORY" },
					{ pattern = "Cannot allocate memory", type = "OUT_OF_MEMORY" },
					{ pattern = "malloc failed", type = "MALLOC_FAILED" },
					{ pattern = "calloc failed", type = "CALLOC_FAILED" },
					{ pattern = "realloc failed", type = "REALLOC_FAILED" },
					{ pattern = "new failed", type = "NEW_FAILED" },
					{ pattern = "operator new failed", type = "NEW_FAILED" },
					{ pattern = "Memory exhausted", type = "OUT_OF_MEMORY" },
					{ pattern = "Virtual memory exhausted", type = "OUT_OF_MEMORY" },
					{ pattern = "Address space exhausted", type = "OUT_OF_MEMORY" },

					-- System resource errors
					{ pattern = "Too many open files", type = "TOO_MANY_FILES" },
					{ pattern = "File descriptor table full", type = "TOO_MANY_FILES" },
					{ pattern = "Resource temporarily unavailable", type = "RESOURCE_UNAVAILABLE" },
					{ pattern = "Resource limit exceeded", type = "RESOURCE_LIMIT" },
					{ pattern = "Process limit exceeded", type = "PROCESS_LIMIT" },
					{ pattern = "Thread limit exceeded", type = "THREAD_LIMIT" },
					{ pattern = "Maximum number of processes reached", type = "PROCESS_LIMIT" },
					{ pattern = "System overloaded", type = "SYSTEM_OVERLOAD" },
					{ pattern = "Quota exceeded", type = "QUOTA_EXCEEDED" },
					{ pattern = "Disk quota exceeded", type = "DISK_QUOTA" },
					{ pattern = "File size limit exceeded", type = "FILE_SIZE_LIMIT" },

					-- Critical system errors
					{ pattern = "Kernel panic", type = "KERNEL_PANIC" },
					{ pattern = "System halted", type = "SYSTEM_HALT" },
					{ pattern = "Blue screen", type = "BLUE_SCREEN" },
					{ pattern = "BSOD", type = "BLUE_SCREEN" },
					{ pattern = "Machine check exception", type = "MACHINE_CHECK" },
					{ pattern = "Hardware error", type = "HARDWARE_ERROR" },
					{ pattern = "CPU exception", type = "CPU_EXCEPTION" },
					{ pattern = "Page fault", type = "PAGE_FAULT" },
					{ pattern = "General protection fault", type = "PROTECTION_FAULT" },
					{ pattern = "Invalid TSS", type = "INVALID_TSS" },
					{ pattern = "Segment not present", type = "SEGMENT_NOT_PRESENT" },
					{ pattern = "Stack segment fault", type = "STACK_SEGMENT_FAULT" },

					-- Process state errors
					{ pattern = "Zombie process", type = "ZOMBIE_PROCESS" },
					{ pattern = "Orphan process", type = "ORPHAN_PROCESS" },
					{ pattern = "Process deadlock", type = "DEADLOCK" },
					{ pattern = "Process timeout", type = "PROCESS_TIMEOUT" },
					{ pattern = "Process hang", type = "PROCESS_HANG" },
					{ pattern = "Process frozen", type = "PROCESS_FROZEN" },
					{ pattern = "Process not responding", type = "PROCESS_NOT_RESPONDING" },
					{ pattern = "Process blocked", type = "PROCESS_BLOCKED" },

					-- Runtime library errors
					{ pattern = "Runtime error", type = "RUNTIME_ERROR" },
					{ pattern = "Library not found", type = "LIBRARY_NOT_FOUND" },
					{ pattern = "Shared library error", type = "SHARED_LIBRARY_ERROR" },
					{ pattern = "Dynamic linker error", type = "DYNAMIC_LINKER_ERROR" },
					{ pattern = "Symbol not found", type = "SYMBOL_NOT_FOUND" },
					{ pattern = "Version mismatch", type = "VERSION_MISMATCH" },
					{ pattern = "ABI incompatibility", type = "ABI_INCOMPATIBILITY" },

					-- Network and I/O errors
					{ pattern = "Connection refused", type = "CONNECTION_REFUSED" },
					{ pattern = "Connection timeout", type = "CONNECTION_TIMEOUT" },
					{ pattern = "Connection reset", type = "CONNECTION_RESET" },
					{ pattern = "Network unreachable", type = "NETWORK_UNREACHABLE" },
					{ pattern = "Host unreachable", type = "HOST_UNREACHABLE" },
					{ pattern = "Permission denied", type = "PERMISSION_DENIED" },
					{ pattern = "File not found", type = "FILE_NOT_FOUND" },
					{ pattern = "Directory not found", type = "DIRECTORY_NOT_FOUND" },
					{ pattern = "No such file or directory", type = "FILE_NOT_FOUND" },
					{ pattern = "Input/output error", type = "IO_ERROR" },
					{ pattern = "Device not ready", type = "DEVICE_NOT_READY" },
					{ pattern = "No space left on device", type = "NO_SPACE" },
					{ pattern = "Read%-only file system", type = "READ_ONLY_FILESYSTEM" },

					-- Threading and concurrency errors
					{ pattern = "Thread creation failed", type = "THREAD_CREATION_FAILED" },
					{ pattern = "Mutex lock failed", type = "MUTEX_LOCK_FAILED" },
					{ pattern = "Condition variable error", type = "CONDITION_VARIABLE_ERROR" },
					{ pattern = "Semaphore error", type = "SEMAPHORE_ERROR" },
					{ pattern = "Race condition detected", type = "RACE_CONDITION" },
					{ pattern = "Data race", type = "DATA_RACE" },
					{ pattern = "Thread deadlock", type = "THREAD_DEADLOCK" },
					{ pattern = "Thread starvation", type = "THREAD_STARVATION" },
					{ pattern = "Priority inversion", type = "PRIORITY_INVERSION" },
				}

				for _, p in ipairs(runtime_patterns) do
					if line:match(p.pattern) then
						table.insert(errors, {
							filename = vim.fn.expand("%"),
							lnum = 1,
							text = line,
							display = p.type .. ": " .. line,
						})
						break
					end
				end

				if line:match("ERROR: AddressSanitizer") then
					local asan_type = "ASAN"
					if line:match("heap%-buffer%-overflow") then
						asan_type = "ASAN-HEAP-OVERFLOW"
					elseif line:match("stack%-buffer%-overflow") then
						asan_type = "ASAN-STACK-OVERFLOW"
					elseif line:match("global%-buffer%-overflow") then
						asan_type = "ASAN-GLOBAL-OVERFLOW"
					elseif line:match("use%-after%-free") then
						asan_type = "ASAN-USE-AFTER-FREE"
					elseif line:match("heap%-use%-after%-free") then
						asan_type = "ASAN-HEAP-USE-AFTER-FREE"
					elseif line:match("stack%-use%-after%-scope") then
						asan_type = "ASAN-STACK-USE-AFTER-SCOPE"
					elseif line:match("stack%-use%-after%-return") then
						asan_type = "ASAN-STACK-USE-AFTER-RETURN"
					elseif line:match("double%-free") then
						asan_type = "ASAN-DOUBLE-FREE"
					elseif line:match("alloc%-dealloc%-mismatch") then
						asan_type = "ASAN-ALLOC-DEALLOC-MISMATCH"
					elseif line:match("initialization%-order%-fiasco") then
						asan_type = "ASAN-INIT-ORDER-FIASCO"
					elseif line:match("memcpy%-param%-overlap") then
						asan_type = "ASAN-MEMCPY-OVERLAP"
					elseif line:match("negative%-size%-param") then
						asan_type = "ASAN-NEGATIVE-SIZE"
					elseif line:match("bad%-free") then
						asan_type = "ASAN-BAD-FREE"
					elseif line:match("attempting free on address which was not malloc") then
						asan_type = "ASAN-INVALID-FREE"
					end

					table.insert(errors, {
						filename = vim.fn.expand("%"),
						lnum = 1,
						text = line,
						display = asan_type .. ": " .. line,
					})
				end

				if line:match("runtime error:") and not line:match("go") then
					local ubsan_type = "UBSAN"
					if line:match("signed integer overflow") then
						ubsan_type = "UBSAN-INT-OVERFLOW"
					elseif line:match("unsigned integer overflow") then
						ubsan_type = "UBSAN-UINT-OVERFLOW"
					elseif line:match("index .* out of bounds") then
						ubsan_type = "UBSAN-OUT-OF-BOUNDS"
					elseif line:match("null pointer") then
						ubsan_type = "UBSAN-NULL-POINTER"
					elseif line:match("misaligned address") then
						ubsan_type = "UBSAN-MISALIGNED"
					elseif line:match("division by zero") then
						ubsan_type = "UBSAN-DIV-BY-ZERO"
					elseif line:match("shift exponent .* is too large") then
						ubsan_type = "UBSAN-SHIFT-OVERFLOW"
					elseif line:match("left shift of negative value") then
						ubsan_type = "UBSAN-SHIFT-NEGATIVE"
					elseif line:match("load of null pointer") then
						ubsan_type = "UBSAN-NULL-LOAD"
					elseif line:match("store to null pointer") then
						ubsan_type = "UBSAN-NULL-STORE"
					elseif line:match("nan") then
						ubsan_type = "UBSAN-NAN"
					elseif line:match("inf") then
						ubsan_type = "UBSAN-INF"
					elseif line:match("invalid bool load") then
						ubsan_type = "UBSAN-INVALID-BOOL"
					elseif line:match("invalid enum value") then
						ubsan_type = "UBSAN-INVALID-ENUM"
					elseif line:match("call to function through pointer to incorrect type") then
						ubsan_type = "UBSAN-FUNCTION-TYPE-MISMATCH"
					elseif line:match("downcast of address") then
						ubsan_type = "UBSAN-INVALID-DOWNCAST"
					end

					table.insert(errors, {
						filename = vim.fn.expand("%"),
						lnum = 1,
						text = line,
						display = ubsan_type .. ": " .. line,
					})
				end

				local valgrind_patterns = {
					-- Memory access violations
					{ pattern = "Invalid read", type = "VALGRIND-INVALID-READ" },
					{ pattern = "Invalid write", type = "VALGRIND-INVALID-WRITE" },
					{ pattern = "Use of uninitialised", type = "VALGRIND-UNINIT" },
					{ pattern = "Conditional jump or move depends on uninitialised", type = "VALGRIND-UNINIT-COND" },
					{ pattern = "Source and destination overlap", type = "VALGRIND-OVERLAP" },
					{ pattern = "Invalid free%(%) / delete", type = "VALGRIND-INVALID-FREE" },
					{ pattern = "Mismatched free%(%) / delete", type = "VALGRIND-MISMATCHED-FREE" },
					{ pattern = "Syscall param .* contains uninitialised", type = "VALGRIND-SYSCALL-UNINIT" },
					{ pattern = "Jump to the invalid address", type = "VALGRIND-INVALID-JUMP" },
					{ pattern = "Address .* is not stack'd", type = "VALGRIND-NOT-STACK" },
					{ pattern = "Address .* is .* bytes after a block", type = "VALGRIND-BLOCK-OVERRUN" },
					{ pattern = "Address .* is .* bytes before a block", type = "VALGRIND-BLOCK-UNDERRUN" },
					{ pattern = "Address .* is .* bytes inside a block", type = "VALGRIND-BLOCK-INTERIOR" },
					{ pattern = "Address .* is on thread .* stack", type = "VALGRIND-ON-STACK" },
					{ pattern = "Address .* is .* bytes from start of", type = "VALGRIND-BYTES-FROM-START" },
					{ pattern = "Process terminating with default action", type = "VALGRIND-PROCESS-TERMINATING" },

					-- Thread and synchronization errors
					{ pattern = "Thread .* .* lock .* currently held by thread", type = "VALGRIND-LOCK-ORDER" },
					{ pattern = "Possible data race", type = "VALGRIND-DATA-RACE" },
					{ pattern = "Lock at .* was first observed", type = "VALGRIND-LOCK-OBSERVED" },
					{ pattern = "This conflicts with a previous read", type = "VALGRIND-CONFLICTS-READ" },
					{ pattern = "This conflicts with a previous write", type = "VALGRIND-CONFLICTS-WRITE" },
					{ pattern = "Possible data race during read", type = "VALGRIND-DATA-RACE-READ" },
					{ pattern = "Possible data race during write", type = "VALGRIND-DATA-RACE-WRITE" },
					{ pattern = "Thread .* created a new thread", type = "VALGRIND-THREAD-CREATED" },
					{ pattern = "Thread .* finished", type = "VALGRIND-THREAD-FINISHED" },
					{ pattern = "Conflicting store by thread", type = "VALGRIND-CONFLICTING-STORE" },
					{ pattern = "Conflicting load by thread", type = "VALGRIND-CONFLICTING-LOAD" },
					{ pattern = "Location .* is .* bytes inside", type = "VALGRIND-LOCATION-INSIDE" },
					{ pattern = "Location .* has never been written to", type = "VALGRIND-NEVER-WRITTEN" },

					-- Memory management errors
					{ pattern = "Argument .* of function .* has a fishy", type = "VALGRIND-FISHY-ARGUMENT" },
					{ pattern = "Warning: set address range perms", type = "VALGRIND-SET-PERMS" },
					{ pattern = "Warning: noted but unhandled ioctl", type = "VALGRIND-UNHANDLED-IOCTL" },
					{ pattern = "Bad permissions for mapped region", type = "VALGRIND-BAD-PERMISSIONS" },
					{ pattern = "Argument .* is not a valid file descriptor", type = "VALGRIND-INVALID-FD" },
					{ pattern = "Argument .* points to unaddressable byte%(s%)", type = "VALGRIND-UNADDRESSABLE" },
					{ pattern = "Argument .* points to uninitialised byte%(s%)", type = "VALGRIND-UNINIT-BYTES" },

					-- System call errors
					{ pattern = "Syscall param .* points to unaddressable", type = "VALGRIND-SYSCALL-UNADDRESSABLE" },
					{ pattern = "Syscall param .* points to uninitialised", type = "VALGRIND-SYSCALL-UNINIT-PARAM" },
					{ pattern = "Warning: bad signal number", type = "VALGRIND-BAD-SIGNAL" },
					{ pattern = "Warning: client switching stacks", type = "VALGRIND-SWITCHING-STACKS" },
					{ pattern = "Warning: specified range .* exceeds", type = "VALGRIND-RANGE-EXCEEDS" },

					-- Heap corruption
					{ pattern = "Heap block .* has been corrupted", type = "VALGRIND-HEAP-CORRUPTED" },
					{ pattern = "Heap summary:", type = "VALGRIND-HEAP-SUMMARY" },
					{ pattern = "Block was alloc'd at", type = "VALGRIND-BLOCK-ALLOCATED" },
					{ pattern = "Address .* is .* bytes inside a block of size", type = "VALGRIND-INSIDE-BLOCK" },
					{ pattern = "by 0x.*: malloc", type = "VALGRIND-MALLOC-TRACE" },
					{ pattern = "by 0x.*: calloc", type = "VALGRIND-CALLOC-TRACE" },
					{ pattern = "by 0x.*: realloc", type = "VALGRIND-REALLOC-TRACE" },
					{ pattern = "by 0x.*: free", type = "VALGRIND-FREE-TRACE" },
					{ pattern = "by 0x.*: new", type = "VALGRIND-NEW-TRACE" },
					{ pattern = "by 0x.*: delete", type = "VALGRIND-DELETE-TRACE" },

					-- Stack traces and debugging info
					{ pattern = "== at 0x.*:", type = "VALGRIND-STACK-FRAME" },
					{ pattern = "== by 0x.*:", type = "VALGRIND-STACK-TRACE" },
					{ pattern = "== Address 0x.*", type = "VALGRIND-ADDRESS-INFO" },
					{ pattern = "== %d+", type = "VALGRIND-PROCESS-ID" },
					{ pattern = "ERROR SUMMARY:", type = "VALGRIND-ERROR-SUMMARY" },
					{ pattern = "FATAL:", type = "VALGRIND-FATAL" },
					{ pattern = "Tool: memcheck", type = "VALGRIND-MEMCHECK" },
					{ pattern = "Tool: helgrind", type = "VALGRIND-HELGRIND" },
					{ pattern = "Tool: drd", type = "VALGRIND-DRD" },
					{ pattern = "Tool: massif", type = "VALGRIND-MASSIF" },
					{ pattern = "Tool: cachegrind", type = "VALGRIND-CACHEGRIND" },
					{ pattern = "Tool: callgrind", type = "VALGRIND-CALLGRIND" },
					{ pattern = "For more details, rerun with:", type = "VALGRIND-RERUN-HINT" },
					{ pattern = "To debug this error", type = "VALGRIND-DEBUG-HINT" },
					{ pattern = "Use --track%-origins=yes", type = "VALGRIND-TRACK-ORIGINS-HINT" },

					-- Performance analysis (Cachegrind/Callgrind)
					{ pattern = "I   refs:", type = "VALGRIND-INSTRUCTION-REFS" },
					{ pattern = "I1  misses:", type = "VALGRIND-I1-MISSES" },
					{ pattern = "LLi misses:", type = "VALGRIND-LLI-MISSES" },
					{ pattern = "I1  miss rate:", type = "VALGRIND-I1-MISS-RATE" },
					{ pattern = "LLi miss rate:", type = "VALGRIND-LLI-MISS-RATE" },
					{ pattern = "D   refs:", type = "VALGRIND-DATA-REFS" },
					{ pattern = "D1  misses:", type = "VALGRIND-D1-MISSES" },
					{ pattern = "LLd misses:", type = "VALGRIND-LLD-MISSES" },
					{ pattern = "D1  miss rate:", type = "VALGRIND-D1-MISS-RATE" },
					{ pattern = "LLd miss rate:", type = "VALGRIND-LLD-MISS-RATE" },
					{ pattern = "LL refs:", type = "VALGRIND-LL-REFS" },
					{ pattern = "LL misses:", type = "VALGRIND-LL-MISSES" },
					{ pattern = "LL miss rate:", type = "VALGRIND-LL-MISS-RATE" },
					{ pattern = "Branches:", type = "VALGRIND-BRANCHES" },
					{ pattern = "Mispredicts:", type = "VALGRIND-MISPREDICTS" },
					{ pattern = "Mispred rate:", type = "VALGRIND-MISPRED-RATE" },
				}

				for _, p in ipairs(valgrind_patterns) do
					if line:match(p.pattern) then
						table.insert(errors, {
							filename = vim.fn.expand("%"),
							lnum = 1,
							text = line,
							display = p.type .. ": " .. line,
						})
						break
					end
				end

				local leak_patterns = {
					-- Valgrind memory leak patterns
					{ pattern = "definitely lost", type = "LEAK-DEFINITE" },
					{ pattern = "indirectly lost", type = "LEAK-INDIRECT" },
					{ pattern = "possibly lost", type = "LEAK-POSSIBLE" },
					{ pattern = "still reachable", type = "LEAK-REACHABLE" },
					{ pattern = "suppressed", type = "LEAK-SUPPRESSED" },
					{ pattern = "blocks are definitely lost", type = "LEAK-BLOCKS-DEFINITE" },
					{ pattern = "blocks are indirectly lost", type = "LEAK-BLOCKS-INDIRECT" },
					{ pattern = "blocks are possibly lost", type = "LEAK-BLOCKS-POSSIBLE" },
					{ pattern = "blocks are still reachable", type = "LEAK-BLOCKS-REACHABLE" },
					{ pattern = "bytes are definitely lost", type = "LEAK-BYTES-DEFINITE" },
					{ pattern = "bytes are indirectly lost", type = "LEAK-BYTES-INDIRECT" },
					{ pattern = "bytes are possibly lost", type = "LEAK-BYTES-POSSIBLE" },
					{ pattern = "bytes are still reachable", type = "LEAK-BYTES-REACHABLE" },
					{ pattern = "HEAP SUMMARY", type = "LEAK-HEAP-SUMMARY" },
					{ pattern = "LEAK SUMMARY", type = "LEAK-SUMMARY" },
					{ pattern = "All heap blocks were freed", type = "LEAK-ALL-FREED" },
					{ pattern = "ERROR SUMMARY:", type = "LEAK-ERROR-SUMMARY" },
					{ pattern = "in use at exit", type = "LEAK-IN-USE-AT-EXIT" },
					{ pattern = "total heap usage", type = "LEAK-TOTAL-HEAP-USAGE" },
					{ pattern = "allocs, .* frees", type = "LEAK-ALLOC-FREE-COUNT" },
					{ pattern = "For a detailed leak analysis", type = "LEAK-DETAILED-HINT" },
					{ pattern = "Use --leak-check=full", type = "LEAK-CHECK-HINT" },
					{ pattern = "Rerun with --leak-check=full", type = "LEAK-RERUN-HINT" },

					-- AddressSanitizer leak patterns
					{ pattern = "LeakSanitizer: detected memory leaks", type = "LSAN-DETECTED" },
					{ pattern = "Direct leak of .* byte%(s%)", type = "LSAN-DIRECT-LEAK" },
					{ pattern = "Indirect leak of .* byte%(s%)", type = "LSAN-INDIRECT-LEAK" },
					{ pattern = "SUMMARY: LeakSanitizer:", type = "LSAN-SUMMARY" },
					{ pattern = "Suppressions used:", type = "LSAN-SUPPRESSIONS" },
					{ pattern = "leaked in .* allocation%(s%)", type = "LSAN-LEAK-COUNT" },
					{ pattern = "The following memory was never freed:", type = "LSAN-NEVER-FREED" },

					-- Static analysis memory leak patterns
					{ pattern = "Memory leak:", type = "STATIC-MEMORY-LEAK" },
					{ pattern = "Potential memory leak", type = "STATIC-POTENTIAL-LEAK" },
					{ pattern = "Resource leak:", type = "STATIC-RESOURCE-LEAK" },
					{ pattern = "File handle leak", type = "STATIC-FILE-HANDLE-LEAK" },
					{ pattern = "Socket leak", type = "STATIC-SOCKET-LEAK" },
					{ pattern = "Thread leak", type = "STATIC-THREAD-LEAK" },
					{ pattern = "Mutex leak", type = "STATIC-MUTEX-LEAK" },
					{ pattern = "Reference leak", type = "STATIC-REF-LEAK" },
					{ pattern = "Object leak", type = "STATIC-OBJECT-LEAK" },

					-- Application-specific leak patterns
					{ pattern = "malloc.*not freed", type = "APP-MALLOC-NOT-FREED" },
					{ pattern = "new.*without delete", type = "APP-NEW-WITHOUT-DELETE" },
					{ pattern = "fopen.*without fclose", type = "APP-FILE-NOT-CLOSED" },
					{ pattern = "socket.*not closed", type = "APP-SOCKET-NOT-CLOSED" },
					{ pattern = "pthread_create.*without pthread_join", type = "APP-THREAD-NOT-JOINED" },
					{ pattern = "mutex.*not destroyed", type = "APP-MUTEX-NOT-DESTROYED" },
					{ pattern = "sem_open.*without sem_close", type = "APP-SEMAPHORE-NOT-CLOSED" },
					{ pattern = "mmap.*without munmap", type = "APP-MMAP-NOT-UNMAPPED" },
					{ pattern = "dlopen.*without dlclose", type = "APP-LIBRARY-NOT-CLOSED" },

					-- Language-specific leak patterns
					{ pattern = "OutOfMemoryError", type = "JAVA-OOM" },
					{ pattern = "Memory usage exceeded", type = "GENERIC-MEMORY-EXCEEDED" },
					{ pattern = "Too many open files", type = "GENERIC-FILE-LIMIT" },
					{ pattern = "Cannot allocate memory", type = "GENERIC-ALLOC-FAILED" },
					{ pattern = "Virtual memory exhausted", type = "GENERIC-VM-EXHAUSTED" },
				}

				for _, p in ipairs(leak_patterns) do
					if line:match(p.pattern) then
						table.insert(warnings, {
							filename = vim.fn.expand("%"),
							lnum = 1,
							text = line,
							display = p.type .. ": " .. line,
						})
						break
					end
				end

				-- Additional debugging tool patterns
				local debug_tool_patterns = {
					-- GDB patterns
					{ pattern = "Program received signal", type = "GDB-SIGNAL" },
					{ pattern = "Program terminated with signal", type = "GDB-TERMINATED" },
					{ pattern = "Breakpoint .* hit", type = "GDB-BREAKPOINT" },
					{ pattern = "Watchpoint .* triggered", type = "GDB-WATCHPOINT" },
					{ pattern = "Hardware watchpoint .* deleted", type = "GDB-HW-WATCHPOINT" },
					{ pattern = "Thread .* hit Breakpoint", type = "GDB-THREAD-BREAKPOINT" },
					{ pattern = "Temporary breakpoint .* at", type = "GDB-TEMP-BREAKPOINT" },
					{ pattern = "Catchpoint .* .*exception", type = "GDB-CATCHPOINT" },
					{ pattern = "Remote debugging", type = "GDB-REMOTE" },
					{ pattern = "warning: .* has changed", type = "GDB-WARNING" },
					{ pattern = "No symbol table", type = "GDB-NO-SYMBOLS" },
					{ pattern = "Inferior .* exited", type = "GDB-EXIT" },
					{ pattern = "Reading symbols from", type = "GDB-SYMBOLS" },
					{ pattern = "Starting program:", type = "GDB-START" },
					{ pattern = "Detaching from program", type = "GDB-DETACH" },
					{ pattern = "Cannot access memory at address", type = "GDB-MEMORY-ERROR" },

					-- Static analysis patterns
					{ pattern = "cppcheck:", type = "CPPCHECK" },
					{ pattern = "clang%-tidy:", type = "CLANG-TIDY" },
					{ pattern = "PC%-lint:", type = "PC-LINT" },
					{ pattern = "Splint:", type = "SPLINT" },
					{ pattern = "scan%-build:", type = "SCAN-BUILD" },
					{ pattern = "PVS%-Studio:", type = "PVS-STUDIO" },
					{ pattern = "CodeQL:", type = "CODEQL" },
					{ pattern = "Coverity:", type = "COVERITY" },
					{ pattern = "SonarQube:", type = "SONARQUBE" },
					{ pattern = "Infer:", type = "INFER" },
					{ pattern = "flawfinder:", type = "FLAWFINDER" },
					{ pattern = "rats:", type = "RATS" },
					{ pattern = "bandit:", type = "BANDIT" },
					{ pattern = "semgrep:", type = "SEMGREP" },
					{ pattern = "CodeChecker:", type = "CODECHECKER" },

					-- Sanitizer initialization patterns
					{ pattern = "==.*==ERROR: LeakSanitizer", type = "LSAN-ERROR" },
					{ pattern = "==.*==ERROR: ThreadSanitizer", type = "TSAN-ERROR" },
					{ pattern = "==.*==WARNING: ThreadSanitizer", type = "TSAN-WARNING" },
					{ pattern = "==.*==ERROR: MemorySanitizer", type = "MSAN-ERROR" },
					{ pattern = "==.*==WARNING: MemorySanitizer", type = "MSAN-WARNING" },
					{ pattern = "==.*==ERROR: AddressSanitizer", type = "ASAN-ERROR" },
					{ pattern = "==.*==WARNING: AddressSanitizer", type = "ASAN-WARNING" },
					{ pattern = "==.*==ERROR: UndefinedBehaviorSanitizer", type = "UBSAN-ERROR" },
					{ pattern = "==.*==WARNING: UndefinedBehaviorSanitizer", type = "UBSAN-WARNING" },
					{ pattern = "==.*==ERROR: DataFlowSanitizer", type = "DFSAN-ERROR" },
					{ pattern = "==.*==ERROR: HWAddressSanitizer", type = "HWASAN-ERROR" },
					{ pattern = "==.*==ERROR: Control Flow Integrity", type = "CFI-ERROR" },
					{ pattern = "==.*==ERROR: SafeStack", type = "SAFESTACK-ERROR" },
					{ pattern = "SUMMARY: .*Sanitizer", type = "SANITIZER-SUMMARY" },

					-- Runtime error patterns
					{ pattern = "runtime error:", type = "RUNTIME-ERROR" },
					{ pattern = "Segmentation fault", type = "SEGFAULT" },
					{ pattern = "Bus error", type = "BUS-ERROR" },
					{ pattern = "Floating point exception", type = "FPE" },
					{ pattern = "Illegal instruction", type = "ILLEGAL-INSTRUCTION" },
					{ pattern = "Aborted", type = "ABORTED" },
					{ pattern = "Killed", type = "KILLED" },
					{ pattern = "Trace/breakpoint trap", type = "TRACE-TRAP" },
					{ pattern = "core dumped", type = "CORE-DUMP" },

					-- Profiling tools
					{ pattern = "perf record", type = "PERF-RECORD" },
					{ pattern = "perf report", type = "PERF-REPORT" },
					{ pattern = "gprof:", type = "GPROF" },
					{ pattern = "callgrind:", type = "CALLGRIND" },
					{ pattern = "Intel VTune", type = "VTUNE" },
					{ pattern = "Google pprof", type = "PPROF" },
					{ pattern = "Massif:", type = "MASSIF" },
					{ pattern = "Cachegrind:", type = "CACHEGRIND" },
					{ pattern = "Helgrind:", type = "HELGRIND" },
					{ pattern = "DRD:", type = "DRD" },

					-- Build system debug
					{ pattern = "ninja: build stopped", type = "NINJA-STOPPED" },
					{ pattern = "make: .*Error", type = "MAKE-ERROR" },
					{ pattern = "CMake Error", type = "CMAKE-ERROR" },
					{ pattern = "CMake Warning", type = "CMAKE-WARNING" },
					{ pattern = "configure: error:", type = "CONFIGURE-ERROR" },
					{ pattern = "autoreconf:", type = "AUTORECONF" },
					{ pattern = "libtool:", type = "LIBTOOL" },

					-- Language-specific runtime errors
					{ pattern = "java.lang..*Exception", type = "JAVA-EXCEPTION" },
					{ pattern = "Exception in thread", type = "JAVA-THREAD-EXCEPTION" },
					{ pattern = "Traceback %(most recent call last%):", type = "PYTHON-TRACEBACK" },
					{ pattern = ".*Error:.*at line", type = "PYTHON-ERROR" },
					{ pattern = "panic:", type = "GO-PANIC" },
					{ pattern = "fatal error:", type = "GO-FATAL" },
					{ pattern = "thread '.*' panicked at", type = "RUST-PANIC" },
					{ pattern = "Error:.*Stack trace:", type = "DART-ERROR" },
				}

				for _, p in ipairs(debug_tool_patterns) do
					if line:match(p.pattern) then
						local target_table = p.type:match("WARNING") and warnings or errors
						table.insert(target_table, {
							filename = vim.fn.expand("%"),
							lnum = 1,
							text = line,
							display = p.type .. ": " .. line,
						})
						break
					end
				end

				file, line_num = line:match("#%d+.* at ([^:]+):(%d+)")
				if file and line_num then
					table.insert(errors, {
						filename = file,
						lnum = tonumber(line_num),
						text = line,
						display = string.format("STACK: %s:%s: %s", vim.fn.fnamemodify(file, ":t"), line_num, line),
					})
				end

				-- Valgrind stack traces
				file, line_num = line:match("at 0x%w+: .* %(([^:]+):(%d+)%)")
				if file and line_num then
					table.insert(errors, {
						filename = file,
						lnum = tonumber(line_num),
						text = line,
						display = string.format(
							"VALGRIND-STACK: %s:%s: %s",
							vim.fn.fnamemodify(file, ":t"),
							line_num,
							line
						),
					})
				end

				-- AddressSanitizer stack traces
				file, line_num = line:match("#%d+.* ([^%s]+):(%d+)")
				if file and line_num and line:match("#%d+") then
					if file:match("/") or file:match("%.c$") or file:match("%.cpp$") or file:match("%.h$") then
						table.insert(errors, {
							filename = file,
							lnum = tonumber(line_num),
							text = line,
							display = string.format(
								"ASAN-STACK: %s:%s: %s",
								vim.fn.fnamemodify(file, ":t"),
								line_num,
								line
							),
						})
					end
				end

				local assert_patterns = {
					-- Standard assertion failures
					{ pattern = "Assertion .* failed", type = "ASSERT-FAILED" },
					{ pattern = "assert%(.*%)", type = "ASSERT" },
					{ pattern = "__assert_fail", type = "ASSERT-INTERNAL" },
					{ pattern = "Aborted %(core dumped%)", type = "ASSERT-CORE-DUMP" },
					{ pattern = "Assertion `.*' failed", type = "ASSERT-FAILED" },
					{ pattern = "assertion failed:", type = "ASSERT-FAILED" },
					{ pattern = "ASSERTION FAILED:", type = "ASSERT-FAILED" },
					{ pattern = "Assert failed:", type = "ASSERT-FAILED" },
					{ pattern = "ASSERT FAILED:", type = "ASSERT-FAILED" },
					{ pattern = "Assertation failed", type = "ASSERT-FAILED" }, -- Common typo

					-- Different assertion types
					{ pattern = "static_assert", type = "STATIC-ASSERT" },
					{ pattern = "static assertion failed", type = "STATIC-ASSERT" },
					{ pattern = "_Static_assert", type = "STATIC-ASSERT" },
					{ pattern = "compile%-time assertion failed", type = "STATIC-ASSERT" },
					{ pattern = "cassert", type = "C-ASSERT" },
					{ pattern = "debug assert", type = "DEBUG-ASSERT" },
					{ pattern = "DEBUG_ASSERT", type = "DEBUG-ASSERT" },
					{ pattern = "ASSERT_DEBUG", type = "DEBUG-ASSERT" },
					{ pattern = "runtime assert", type = "RUNTIME-ASSERT" },
					{ pattern = "RUNTIME_ASSERT", type = "RUNTIME-ASSERT" },

					-- Assertion macros from different frameworks
					{ pattern = "ASSERT_EQ", type = "ASSERT-EQUAL" },
					{ pattern = "ASSERT_NE", type = "ASSERT-NOT-EQUAL" },
					{ pattern = "ASSERT_LT", type = "ASSERT-LESS-THAN" },
					{ pattern = "ASSERT_LE", type = "ASSERT-LESS-EQUAL" },
					{ pattern = "ASSERT_GT", type = "ASSERT-GREATER-THAN" },
					{ pattern = "ASSERT_GE", type = "ASSERT-GREATER-EQUAL" },
					{ pattern = "ASSERT_TRUE", type = "ASSERT-TRUE" },
					{ pattern = "ASSERT_FALSE", type = "ASSERT-FALSE" },
					{ pattern = "ASSERT_NULL", type = "ASSERT-NULL" },
					{ pattern = "ASSERT_NOT_NULL", type = "ASSERT-NOT-NULL" },
					{ pattern = "ASSERT_STREQ", type = "ASSERT-STRING-EQUAL" },
					{ pattern = "ASSERT_STRNE", type = "ASSERT-STRING-NOT-EQUAL" },
					{ pattern = "ASSERT_STRCASEEQ", type = "ASSERT-STRING-CASE-EQUAL" },
					{ pattern = "ASSERT_STRCASENE", type = "ASSERT-STRING-CASE-NOT-EQUAL" },
					{ pattern = "ASSERT_FLOAT_EQ", type = "ASSERT-FLOAT-EQUAL" },
					{ pattern = "ASSERT_DOUBLE_EQ", type = "ASSERT-DOUBLE-EQUAL" },
					{ pattern = "ASSERT_NEAR", type = "ASSERT-NEAR" },

					-- Expect macros (non-fatal assertions)
					{ pattern = "EXPECT_EQ", type = "EXPECT-EQUAL" },
					{ pattern = "EXPECT_NE", type = "EXPECT-NOT-EQUAL" },
					{ pattern = "EXPECT_LT", type = "EXPECT-LESS-THAN" },
					{ pattern = "EXPECT_LE", type = "EXPECT-LESS-EQUAL" },
					{ pattern = "EXPECT_GT", type = "EXPECT-GREATER-THAN" },
					{ pattern = "EXPECT_GE", type = "EXPECT-GREATER-EQUAL" },
					{ pattern = "EXPECT_TRUE", type = "EXPECT-TRUE" },
					{ pattern = "EXPECT_FALSE", type = "EXPECT-FALSE" },
					{ pattern = "EXPECT_NULL", type = "EXPECT-NULL" },
					{ pattern = "EXPECT_NOT_NULL", type = "EXPECT-NOT-NULL" },
					{ pattern = "EXPECT_STREQ", type = "EXPECT-STRING-EQUAL" },
					{ pattern = "EXPECT_STRNE", type = "EXPECT-STRING-NOT-EQUAL" },
					{ pattern = "EXPECT_STRCASEEQ", type = "EXPECT-STRING-CASE-EQUAL" },
					{ pattern = "EXPECT_STRCASENE", type = "EXPECT-STRING-CASE-NOT-EQUAL" },
					{ pattern = "EXPECT_FLOAT_EQ", type = "EXPECT-FLOAT-EQUAL" },
					{ pattern = "EXPECT_DOUBLE_EQ", type = "EXPECT-DOUBLE-EQUAL" },
					{ pattern = "EXPECT_NEAR", type = "EXPECT-NEAR" },

					-- Exception-related assertions
					{ pattern = "ASSERT_THROW", type = "ASSERT-THROW" },
					{ pattern = "ASSERT_NO_THROW", type = "ASSERT-NO-THROW" },
					{ pattern = "ASSERT_ANY_THROW", type = "ASSERT-ANY-THROW" },
					{ pattern = "EXPECT_THROW", type = "EXPECT-THROW" },
					{ pattern = "EXPECT_NO_THROW", type = "EXPECT-NO-THROW" },
					{ pattern = "EXPECT_ANY_THROW", type = "EXPECT-ANY-THROW" },

					-- Death tests
					{ pattern = "ASSERT_DEATH", type = "ASSERT-DEATH" },
					{ pattern = "ASSERT_EXIT", type = "ASSERT-EXIT" },
					{ pattern = "EXPECT_DEATH", type = "EXPECT-DEATH" },
					{ pattern = "EXPECT_EXIT", type = "EXPECT-EXIT" },

					-- Custom assertion macros
					{ pattern = "VERIFY", type = "VERIFY" },
					{ pattern = "CHECK", type = "CHECK" },
					{ pattern = "DCHECK", type = "DEBUG-CHECK" },
					{ pattern = "REQUIRE", type = "REQUIRE" },
					{ pattern = "ENSURE", type = "ENSURE" },
					{ pattern = "PRECONDITION", type = "PRECONDITION" },
					{ pattern = "POSTCONDITION", type = "POSTCONDITION" },
					{ pattern = "INVARIANT", type = "INVARIANT" },

					-- Framework-specific assertions
					{ pattern = "QT_ASSERT", type = "QT-ASSERT" },
					{ pattern = "Q_ASSERT", type = "QT-ASSERT" },
					{ pattern = "Q_ASSERT_X", type = "QT-ASSERT-X" },
					{ pattern = "BOOST_ASSERT", type = "BOOST-ASSERT" },
					{ pattern = "BOOST_VERIFY", type = "BOOST-VERIFY" },
					{ pattern = "MFC_ASSERT", type = "MFC-ASSERT" },
					{ pattern = "ATL_ASSERT", type = "ATL-ASSERT" },
					{ pattern = "WIN32_ASSERT", type = "WIN32-ASSERT" },
					{ pattern = "_ASSERT", type = "MSVC-ASSERT" },
					{ pattern = "_ASSERTE", type = "MSVC-ASSERT-EXPR" },
					{ pattern = "_ASSERT_EXPR", type = "MSVC-ASSERT-EXPR" },

					-- Contract programming
					{ pattern = "Contract violation", type = "CONTRACT-VIOLATION" },
					{ pattern = "Precondition violation", type = "PRECONDITION-VIOLATION" },
					{ pattern = "Postcondition violation", type = "POSTCONDITION-VIOLATION" },
					{ pattern = "Invariant violation", type = "INVARIANT-VIOLATION" },
					{ pattern = "Contract failed", type = "CONTRACT-FAILED" },

					-- Language-specific assertions
					{ pattern = "NSAssert", type = "OBJC-ASSERT" },
					{ pattern = "NSParameterAssert", type = "OBJC-PARAMETER-ASSERT" },
					{ pattern = "NSCAssert", type = "OBJC-C-ASSERT" },
					{ pattern = "NSCParameterAssert", type = "OBJC-C-PARAMETER-ASSERT" },

					-- Unit testing framework assertions
					{ pattern = "TEST_ASSERT", type = "TEST-ASSERT" },
					{ pattern = "CPPUNIT_ASSERT", type = "CPPUNIT-ASSERT" },
					{ pattern = "CPPUNIT_ASSERT_EQUAL", type = "CPPUNIT-ASSERT-EQUAL" },
					{ pattern = "CPPUNIT_ASSERT_MESSAGE", type = "CPPUNIT-ASSERT-MESSAGE" },
					{ pattern = "CPPUNIT_FAIL", type = "CPPUNIT-FAIL" },

					-- Assertion context information
					{ pattern = "at line %d+ of file", type = "ASSERT-LOCATION" },
					{ pattern = "in function.*at line", type = "ASSERT-FUNCTION-LOCATION" },
					{ pattern = "Assertion failed in", type = "ASSERT-CONTEXT" },
					{ pattern = "Failed assertion:", type = "ASSERT-FAILED-DETAIL" },
					{ pattern = "Assertion error:", type = "ASSERT-ERROR" },

					-- Kernel and system assertions
					{ pattern = "kernel assertion failed", type = "KERNEL-ASSERT" },
					{ pattern = "kernel panic.*assertion", type = "KERNEL-PANIC-ASSERT" },
					{ pattern = "BUG_ON", type = "KERNEL-BUG-ON" },
					{ pattern = "WARN_ON", type = "KERNEL-WARN-ON" },
					{ pattern = "BUILD_BUG_ON", type = "KERNEL-BUILD-BUG" },

					-- Assertion with error codes
					{ pattern = "assertion failed.*errno", type = "ASSERT-ERRNO" },
					{ pattern = "assertion failed.*error code", type = "ASSERT-ERROR-CODE" },
					{ pattern = "assertion failed.*last error", type = "ASSERT-LAST-ERROR" },

					-- Memory-related assertions
					{ pattern = "assertion failed.*null pointer", type = "ASSERT-NULL-POINTER" },
					{ pattern = "assertion failed.*invalid pointer", type = "ASSERT-INVALID-POINTER" },
					{ pattern = "assertion failed.*memory", type = "ASSERT-MEMORY" },
					{ pattern = "assertion failed.*buffer", type = "ASSERT-BUFFER" },

					-- Assertion messages with conditions
					{ pattern = "assertion failed: %w+ == %w+", type = "ASSERT-EQUALITY" },
					{ pattern = "assertion failed: %w+ != %w+", type = "ASSERT-INEQUALITY" },
					{ pattern = "assertion failed: %w+ < %w+", type = "ASSERT-LESS-THAN" },
					{ pattern = "assertion failed: %w+ > %w+", type = "ASSERT-GREATER-THAN" },
					{ pattern = "assertion failed: %w+ <= %w+", type = "ASSERT-LESS-EQUAL" },
					{ pattern = "assertion failed: %w+ >= %w+", type = "ASSERT-GREATER-EQUAL" },
				}

				local build_error_patterns = {
					-- Make errors
					{ pattern = "make: %*%*%* No rule to make target", type = "MAKE-NO-RULE" },
					{ pattern = "make: %*%*%* No such file or directory", type = "MAKE-FILE-NOT-FOUND" },
					{ pattern = "make: %*%*%* .* failed", type = "MAKE-FAILED" },
					{ pattern = "make: %*%*%* Circular .* dependency dropped", type = "MAKE-CIRCULAR-DEP" },
					{ pattern = "make: warning: overriding recipe", type = "MAKE-OVERRIDE-RECIPE" },
					{ pattern = "make: warning: ignoring old recipe", type = "MAKE-IGNORE-OLD-RECIPE" },
					{ pattern = "make: %*%*%* missing separator", type = "MAKE-MISSING-SEPARATOR" },
					{
						pattern = "make: %*%*%* commands commence before first target",
						type = "MAKE-COMMANDS-BEFORE-TARGET",
					},
					{ pattern = "make: %*%*%* multiple target patterns", type = "MAKE-MULTIPLE-TARGET-PATTERNS" },
					{
						pattern = "make: %*%*%* target .* doesn't match the target pattern",
						type = "MAKE-TARGET-PATTERN-MISMATCH",
					},
					{ pattern = "make: %*%*%* prerequisite .* is newer than target", type = "MAKE-PREREQUISITE-NEWER" },
					{ pattern = "make: %*%*%* virtual memory exhausted", type = "MAKE-MEMORY-EXHAUSTED" },
					{ pattern = "make: %*%*%* recipe for target .* failed", type = "MAKE-RECIPE-FAILED" },
					{ pattern = "make: Leaving directory", type = "MAKE-LEAVING-DIR" },
					{ pattern = "make: Entering directory", type = "MAKE-ENTERING-DIR" },
					{ pattern = "make: %*%*%* Stop", type = "MAKE-STOP" },
					{ pattern = "make: %*%*%* Interrupt", type = "MAKE-INTERRUPT" },
					{ pattern = "make: %*%*%* Terminated", type = "MAKE-TERMINATED" },
					{ pattern = "make: %*%*%* Killed", type = "MAKE-KILLED" },
					{ pattern = "make: %*%*%* Clock skew detected", type = "MAKE-CLOCK-SKEW" },
					{
						pattern = "make: %*%*%* Warning: File .* has modification time .* in the future",
						type = "MAKE-FUTURE-TIME",
					},
					{ pattern = "make: Nothing to be done for", type = "MAKE-NOTHING-TO-DO" },
					{ pattern = "make: Target .* not remade because of errors", type = "MAKE-NOT-REMADE" },
					{ pattern = "make: %*%*%* wait: No child processes", type = "MAKE-NO-CHILD-PROCESSES" },
					{ pattern = "make: %*%*%* read jobs pipe", type = "MAKE-JOBS-PIPE-ERROR" },
					{ pattern = "make: %*%*%* write jobserver", type = "MAKE-JOBSERVER-ERROR" },

					-- Makefile syntax errors
					{ pattern = "Makefile:.*: %*%*%* missing separator", type = "MAKEFILE-SYNTAX-SEPARATOR" },
					{
						pattern = "Makefile:.*: %*%*%* commands commence before first target",
						type = "MAKEFILE-SYNTAX-COMMANDS",
					},
					{
						pattern = "Makefile:.*: %*%*%* mixed implicit and static pattern rules",
						type = "MAKEFILE-SYNTAX-MIXED-RULES",
					},
					{
						pattern = "Makefile:.*: %*%*%* target .* given more than once",
						type = "MAKEFILE-DUPLICATE-TARGET",
					},
					{ pattern = "Makefile:.*: %*%*%* multiple target patterns", type = "MAKEFILE-MULTIPLE-PATTERNS" },
					{ pattern = "Makefile:.*: %*%*%* mixed implicit and normal rules", type = "MAKEFILE-MIXED-RULES" },

					-- CMake errors
					{ pattern = "CMake Error", type = "CMAKE-ERROR" },
					{ pattern = "CMake Warning", type = "CMAKE-WARNING" },
					{ pattern = "-- Could NOT find", type = "CMAKE-PACKAGE-NOT-FOUND" },
					{ pattern = "CMake Error at .* %(find_package%)", type = "CMAKE-FIND-PACKAGE-ERROR" },
					{ pattern = "No CMAKE_.* could be found", type = "CMAKE-COMPILER-NOT-FOUND" },
					{ pattern = "The .* compiler .* is not able to compile", type = "CMAKE-COMPILER-TEST-FAIL" },
					{ pattern = "CMake Error: Generator", type = "CMAKE-GENERATOR-ERROR" },
					{ pattern = "CMake Error: CMAKE_BUILD_TYPE", type = "CMAKE-BUILD-TYPE-ERROR" },
					{ pattern = "CMake Error: Error in configuration files", type = "CMAKE-CONFIG-ERROR" },
					{ pattern = "CMake Error: INSTALL%(%) given unknown argument", type = "CMAKE-INSTALL-ERROR" },
					{ pattern = "CMake Error: Cannot find source file", type = "CMAKE-SOURCE-NOT-FOUND" },
					{ pattern = "CMake Error: Cannot determine link language", type = "CMAKE-LINK-LANGUAGE-ERROR" },
					{
						pattern = "CMake Error: Target .* requires the language dialect .* to be compiled",
						type = "CMAKE-LANGUAGE-DIALECT-ERROR",
					},
					{
						pattern = "CMake Error: No known features for .* compiler",
						type = "CMAKE-COMPILER-FEATURES-ERROR",
					},
					{
						pattern = "CMake Error: CMake can not determine linker language",
						type = "CMAKE-LINKER-LANGUAGE-ERROR",
					},
					{
						pattern = "CMake Error: add_executable cannot create target .* because another target with the same name already exists",
						type = "CMAKE-DUPLICATE-TARGET",
					},
					{
						pattern = "CMake Error: Cannot find a source file for target",
						type = "CMAKE-TARGET-SOURCE-ERROR",
					},
					{
						pattern = "CMake Error: INTERFACE_INCLUDE_DIRECTORIES property contains path",
						type = "CMAKE-INTERFACE-INCLUDE-ERROR",
					},
					{ pattern = "CMake Error: Policy .* is not set", type = "CMAKE-POLICY-ERROR" },
					{ pattern = "CMake Error: CMAKE_.*_COMPILER_ID is not set", type = "CMAKE-COMPILER-ID-ERROR" },
					{
						pattern = "CMake Error: Feature .* is not supported by the .* compiler",
						type = "CMAKE-FEATURE-NOT-SUPPORTED",
					},
					{
						pattern = "CMake Error: The following variables are used in this project",
						type = "CMAKE-UNDEFINED-VARIABLES",
					},

					-- CMake configuration errors
					{ pattern = "CMake Error: Could not create named generator", type = "CMAKE-GENERATOR-NOT-FOUND" },
					{ pattern = "CMake Error: CMAKE_.*_COMPILER not set", type = "CMAKE-COMPILER-NOT-SET" },
					{
						pattern = "CMake Error: your .* compiler: .* was not found",
						type = "CMAKE-COMPILER-NOT-FOUND-DETAILED",
					},
					{
						pattern = "CMake Error: CMAKE_.*_COMPILER_WORKS was set to FALSE",
						type = "CMAKE-COMPILER-NOT-WORKING",
					},
					{
						pattern = "CMake Error: The source directory .* does not appear to contain CMakeLists%.txt",
						type = "CMAKE-NO-CMAKELISTS",
					},
					{
						pattern = "CMake Error: The binary directory .* is the same as the source directory",
						type = "CMAKE-IN-SOURCE-BUILD",
					},
					{
						pattern = "CMake Error: The current CMakeCache%.txt directory .* is different than the directory",
						type = "CMAKE-CACHE-DIRECTORY-MISMATCH",
					},

					-- CMake warnings
					{
						pattern = "CMake Warning .*: Manually%-specified variables were not used by the project",
						type = "CMAKE-UNUSED-VARIABLES",
					},
					{
						pattern = "CMake Warning: The source directory .* is a subdirectory of the binary directory",
						type = "CMAKE-SOURCE-IN-BINARY",
					},
					{ pattern = "CMake Warning: Policy .* is not set", type = "CMAKE-POLICY-WARNING" },
					{ pattern = "CMake Warning: No source or binary directory provided", type = "CMAKE-NO-DIRECTORY" },

					-- Autotools errors
					{ pattern = "autoconf: error:", type = "AUTOCONF-ERROR" },
					{ pattern = "automake: error:", type = "AUTOMAKE-ERROR" },
					{ pattern = "autoheader: error:", type = "AUTOHEADER-ERROR" },
					{ pattern = "autoreconf: error:", type = "AUTORECONF-ERROR" },
					{ pattern = "aclocal: error:", type = "ACLOCAL-ERROR" },
					{ pattern = "libtoolize: error:", type = "LIBTOOLIZE-ERROR" },
					{ pattern = "configure: error:", type = "CONFIGURE-ERROR" },
					{ pattern = "./configure: No such file or directory", type = "CONFIGURE-NOT-FOUND" },
					{ pattern = "configure: WARNING:", type = "CONFIGURE-WARNING" },
					{ pattern = "config%.status: error:", type = "CONFIG-STATUS-ERROR" },

					-- Autotools configuration errors
					{
						pattern = "configure: error: .*compiler cannot create executables",
						type = "CONFIGURE-COMPILER-BROKEN",
					},
					{
						pattern = "configure: error: installation or configuration problem",
						type = "CONFIGURE-INSTALLATION-PROBLEM",
					},
					{ pattern = "configure: error: cannot guess build type", type = "CONFIGURE-BUILD-TYPE-ERROR" },
					{ pattern = "configure: error: cannot run .*config%.sub", type = "CONFIGURE-CONFIG-SUB-ERROR" },
					{ pattern = "configure: error: invalid value .* for --.*", type = "CONFIGURE-INVALID-OPTION" },
					{
						pattern = "configure: error: unrecognized option: %-%-.*",
						type = "CONFIGURE-UNRECOGNIZED-OPTION",
					},
					{ pattern = "configure: error: cannot find install%-sh", type = "CONFIGURE-INSTALL-SH-NOT-FOUND" },

					-- Package manager build errors
					{ pattern = "dpkg%-buildpackage: error:", type = "DPKG-BUILD-ERROR" },
					{ pattern = "debuild: fatal error", type = "DEBUILD-FATAL-ERROR" },
					{ pattern = "rpmbuild: error:", type = "RPMBUILD-ERROR" },
					{ pattern = "emerge: there are no ebuilds", type = "EMERGE-NO-EBUILDS" },
					{ pattern = "portage: .* failed", type = "PORTAGE-FAILED" },
					{ pattern = "yum: Error:", type = "YUM-ERROR" },
					{ pattern = "apt%-get: .* failed", type = "APT-GET-FAILED" },
					{ pattern = "pip install .* failed", type = "PIP-INSTALL-FAILED" },
					{ pattern = "npm install .* failed", type = "NPM-INSTALL-FAILED" },
					{ pattern = "cargo build .* failed", type = "CARGO-BUILD-FAILED" },

					-- Build system specific errors
					{ pattern = "ninja: error:", type = "NINJA-ERROR" },
					{ pattern = "ninja: build stopped", type = "NINJA-BUILD-STOPPED" },
					{ pattern = "ninja: fatal:", type = "NINJA-FATAL" },
					{ pattern = "bazel: error:", type = "BAZEL-ERROR" },
					{ pattern = "BUILD failed", type = "BAZEL-BUILD-FAILED" },
					{ pattern = "ERROR: Analysis of target", type = "BAZEL-ANALYSIS-ERROR" },
					{ pattern = "scons: %*%*%* error", type = "SCONS-ERROR" },
					{ pattern = "waf: error:", type = "WAF-ERROR" },
					{ pattern = "qmake: error:", type = "QMAKE-ERROR" },
					{ pattern = "msbuild: error:", type = "MSBUILD-ERROR" },
					{ pattern = "xcodebuild: error:", type = "XCODEBUILD-ERROR" },

					-- Language-specific build errors
					{ pattern = "javac: error:", type = "JAVAC-ERROR" },
					{ pattern = "scalac: error:", type = "SCALAC-ERROR" },
					{ pattern = "kotlinc: error:", type = "KOTLINC-ERROR" },
					{ pattern = "dotnet build failed", type = "DOTNET-BUILD-FAILED" },
					{ pattern = "go build failed", type = "GO-BUILD-FAILED" },
					{ pattern = "rustc: error:", type = "RUSTC-ERROR" },
					{ pattern = "ghc: error:", type = "GHC-ERROR" },
					{ pattern = "ocamlc: error:", type = "OCAMLC-ERROR" },
					{ pattern = "erlc: error:", type = "ERLC-ERROR" },
					{ pattern = "elixirc: error:", type = "ELIXIRC-ERROR" },
					{ pattern = "dmd: error:", type = "DMD-ERROR" },
					{ pattern = "gdc: error:", type = "GDC-ERROR" },
					{ pattern = "ldc2: error:", type = "LDC2-ERROR" },

					-- Cross-compilation errors
					{ pattern = "cross%-compilation failed", type = "CROSS-COMPILE-FAILED" },
					{ pattern = "target platform.*not supported", type = "TARGET-PLATFORM-NOT-SUPPORTED" },
					{ pattern = "cross%-compiler not found", type = "CROSS-COMPILER-NOT-FOUND" },
					{ pattern = "sysroot.*not found", type = "SYSROOT-NOT-FOUND" },
					{ pattern = "toolchain.*not found", type = "TOOLCHAIN-NOT-FOUND" },

					-- Dependency errors
					{ pattern = "dependency.*not found", type = "DEPENDENCY-NOT-FOUND" },
					{ pattern = "missing dependency", type = "MISSING-DEPENDENCY" },
					{ pattern = "unresolved dependency", type = "UNRESOLVED-DEPENDENCY" },
					{ pattern = "circular dependency", type = "CIRCULAR-DEPENDENCY" },
					{ pattern = "version conflict", type = "VERSION-CONFLICT" },
					{ pattern = "incompatible version", type = "INCOMPATIBLE-VERSION" },
					{ pattern = "package.*not found", type = "PACKAGE-NOT-FOUND" },
					{ pattern = "library.*not found", type = "LIBRARY-NOT-FOUND-BUILD" },
					{ pattern = "header.*not found", type = "HEADER-NOT-FOUND-BUILD" },

					-- Permission and filesystem errors
					{ pattern = "Permission denied.*build", type = "BUILD-PERMISSION-DENIED" },
					{ pattern = "Cannot create directory.*build", type = "BUILD-CANNOT-CREATE-DIR" },
					{ pattern = "Cannot write.*build", type = "BUILD-CANNOT-WRITE" },
					{ pattern = "Disk full.*build", type = "BUILD-DISK-FULL" },
					{ pattern = "No space left.*build", type = "BUILD-NO-SPACE" },
					{ pattern = "File system full.*build", type = "BUILD-FILESYSTEM-FULL" },

					-- Parallel build errors
					{ pattern = "parallel build failed", type = "PARALLEL-BUILD-FAILED" },
					{ pattern = "make: %*%*%* .* Error.*parallel", type = "MAKE-PARALLEL-ERROR" },
					{ pattern = "race condition in build", type = "BUILD-RACE-CONDITION" },
					{ pattern = "parallel job.*failed", type = "PARALLEL-JOB-FAILED" },
					{ pattern = "make: %*%*%* write jobserver", type = "MAKE-JOBSERVER-WRITE-ERROR" },
					{ pattern = "make: %*%*%* read jobs pipe", type = "MAKE-JOBS-PIPE-READ-ERROR" },

					-- Resource exhaustion during build
					{ pattern = "build: virtual memory exhausted", type = "BUILD-MEMORY-EXHAUSTED" },
					{ pattern = "build: out of memory", type = "BUILD-OUT-OF-MEMORY" },
					{ pattern = "build: cannot allocate memory", type = "BUILD-CANNOT-ALLOCATE" },
					{ pattern = "build: resource limit exceeded", type = "BUILD-RESOURCE-LIMIT" },
					{ pattern = "build: timeout", type = "BUILD-TIMEOUT" },

					-- Code generation errors
					{ pattern = "code generation failed", type = "CODE-GENERATION-FAILED" },
					{ pattern = "template instantiation.*failed", type = "TEMPLATE-INSTANTIATION-FAILED" },
					{ pattern = "macro expansion.*failed", type = "MACRO-EXPANSION-FAILED" },
					{ pattern = "preprocessing failed", type = "PREPROCESSING-FAILED" },
					{ pattern = "semantic analysis failed", type = "SEMANTIC-ANALYSIS-FAILED" },
					{ pattern = "syntax analysis failed", type = "SYNTAX-ANALYSIS-FAILED" },
					{ pattern = "parse error.*build", type = "BUILD-PARSE-ERROR" },

					-- Archive and packaging errors
					{ pattern = "ar: .*failed", type = "AR-FAILED" },
					{ pattern = "ranlib: .*failed", type = "RANLIB-FAILED" },
					{ pattern = "strip: .*failed", type = "STRIP-FAILED" },
					{ pattern = "objcopy: .*failed", type = "OBJCOPY-FAILED" },
					{ pattern = "tar: .*failed.*build", type = "TAR-BUILD-FAILED" },
					{ pattern = "zip: .*failed.*build", type = "ZIP-BUILD-FAILED" },
					{ pattern = "packaging failed", type = "PACKAGING-FAILED" },
					{ pattern = "archive creation failed", type = "ARCHIVE-CREATION-FAILED" },

					-- Installation errors during build
					{ pattern = "install: .*failed", type = "INSTALL-FAILED" },
					{ pattern = "installation failed", type = "INSTALLATION-FAILED" },
					{ pattern = "make install.*failed", type = "MAKE-INSTALL-FAILED" },
					{ pattern = "cannot install.*permission denied", type = "INSTALL-PERMISSION-DENIED" },
					{ pattern = "install prefix.*not found", type = "INSTALL-PREFIX-NOT-FOUND" },
					{ pattern = "staged install failed", type = "STAGED-INSTALL-FAILED" },
				}

				for _, p in ipairs(assert_patterns) do
					if line:match(p.pattern) then
						table.insert(errors, {
							filename = vim.fn.expand("%"),
							lnum = 1,
							text = line,
							display = p.type .. ": " .. line,
						})
						break
					end
				end

				for _, p in ipairs(build_error_patterns) do
					if line:match(p.pattern) then
						if p.type:match("WARNING") then
							table.insert(warnings, {
								filename = vim.fn.expand("%"),
								lnum = 1,
								text = line,
								display = p.type .. ": " .. line,
							})
						else
							table.insert(errors, {
								filename = vim.fn.expand("%"),
								lnum = 1,
								text = line,
								display = p.type .. ": " .. line,
							})
						end
						break
					end
				end
			elseif filetype == "go" then
				file, line_num, msg = line:match("%.?/?([^:]+%.go):(%d+):%d*:?%s*(.+)")
				if file and line_num and msg then
					local item = {
						filename = file,
						lnum = tonumber(line_num),
						text = msg,
						display = string.format("%s:%s: %s", vim.fn.fnamemodify(file, ":t"), line_num, msg),
					}

					local error_keywords = {
						-- Syntax and parse errors
						"undefined:",
						"cannot use",
						"undeclared name",
						"syntax error",
						"expected",
						"missing",
						"invalid operation",
						"type .* is not an expression",
						"imported and not used",
						"declared and not used",
						"not enough arguments",
						"too many arguments",
						"cannot assign to",
						"cannot take the address of",
						"non%-name .* on left side of :=",
						"no new variables on left side of :=",
						"multiple%-value .* in single%-value context",
						"cannot use .* as .* value",
						"cannot convert",
						"invalid indirect",
						"invalid memory address",
						"assignment mismatch",
						"function ends without a return statement",
						"unreachable code",
						"duplicate",
						"redeclared",
						"cannot refer to unexported",

						-- Type system errors
						"type .* has no field or method",
						"ambiguous selector",
						"type assertion failed",
						"invalid type assertion",
						"impossible type assertion",
						"type switch on non%-interface value",
						"duplicate case .* in type switch",
						"mismatched types",
						"invalid receiver type",
						"invalid method signature",
						"method .* has pointer receiver",
						"method .* has non%-pointer receiver",
						"cannot use .* as type",
						"invalid type .* for",
						"type .* is not comparable",
						"cannot compare",
						"cannot slice",
						"cannot index",
						"cannot range over",
						"invalid operation .* %(.*%)",

						-- Interface errors
						"does not implement",
						"missing method",
						"wrong type for method",
						"interface contains embedded non%-interface",
						"duplicate method",
						"invalid recursive type",
						"embedded field .* has methods with names conflicting",

						-- Generic type errors (Go 1.18+)
						"type parameter",
						"type constraint",
						"type inference failed",
						"cannot infer",
						"type argument .* does not satisfy",
						"generic function cannot be called without instantiation",
						"cannot use generic type .* without instantiation",
						"type set is empty",
						"overlapping terms",
						"invalid use of type parameter",
						"type parameter .* has no structural type",

						-- Control flow errors
						"break statement not within",
						"continue statement not within",
						"fallthrough statement out of place",
						"goto .* jumps over declaration",
						"goto .* jumps into block",
						"label .* defined and not used",
						"label .* not defined",
						"label .* already defined",

						-- Constant errors
						"constant .* overflows",
						"invalid constant type",
						"division by zero",
						"shift count .* must be unsigned integer",
						"invalid shift count",
						"constant not representable",
						"truncated to",

						-- Array and slice errors
						"array length must be constant",
						"invalid array bound",
						"array bound must be non%-negative",
						"array too large",
						"slice bounds out of range",
						"invalid slice index",
						"slice of unaddressable value",

						-- Map errors
						"invalid map key type",
						"cannot delete from nil map",
						"assignment to entry in nil map",

						-- Channel errors
						"send to nil channel",
						"receive from nil channel",
						"close of nil channel",
						"close of closed channel",
						"send on closed channel",
						"invalid channel direction",
						"cannot range over",

						-- Struct errors
						"unknown field",
						"cannot use .* as .* value in struct literal",
						"too few values in struct initializer",
						"too many values in struct initializer",
						"mixture of field:value and value initializers",
						"duplicate field name",
						"invalid struct tag",

						-- Pointer errors
						"cannot take address of",
						"invalid indirect of",
						"cannot dereference",

						-- Package and import errors
						"imported but not used",
						"package .* imported but not used",
						"no package clause",
						"package .* expects import",
						"local import .* in non%-local package",

						-- Build constraint errors
						"malformed build constraint",
						"build constraints exclude all Go files",
					}

					local is_error = false
					for _, keyword in ipairs(error_keywords) do
						if msg:match(keyword) then
							is_error = true
							break
						end
					end

					if is_error then
						table.insert(errors, item)
					else
						table.insert(warnings, item)
					end
				end

				if line:match("go: warning:") or line:match("vet:") then
					file, line_num, msg = line:match("([^:]+%.go):(%d+): (.+)")
					if file and line_num and msg then
						table.insert(warnings, {
							filename = file,
							lnum = tonumber(line_num),
							text = msg,
							display = string.format("VET: %s:%s: %s", vim.fn.fnamemodify(file, ":t"), line_num, msg),
						})
					end
				end

				if line:match("panic:") then
					local panic_type = "PANIC"
					if line:match("runtime error: index out of range %[%d+%] with length %d+") then
						panic_type = "PANIC-INDEX-OUT-OF-RANGE-WITH-LENGTH"
					elseif line:match("runtime error: index out of range") then
						panic_type = "PANIC-INDEX-OUT-OF-RANGE"
					elseif line:match("runtime error: slice bounds out of range %[:%d+%] with capacity %d+") then
						panic_type = "PANIC-SLICE-CAPACITY"
					elseif line:match("runtime error: slice bounds out of range %[%d*:%d*%] with capacity %d+") then
						panic_type = "PANIC-SLICE-BOUNDS-WITH-CAPACITY"
					elseif line:match("runtime error: slice bounds out of range") then
						panic_type = "PANIC-SLICE-BOUNDS"
					elseif line:match("runtime error: invalid memory address or nil pointer dereference") then
						panic_type = "PANIC-NIL-POINTER"
					elseif line:match("runtime error: integer divide by zero") then
						panic_type = "PANIC-DIV-BY-ZERO"
					elseif line:match("runtime error: integer overflow") then
						panic_type = "PANIC-INTEGER-OVERFLOW"
					elseif line:match("runtime error: hash of unhashable type") then
						panic_type = "PANIC-UNHASHABLE-TYPE"
					elseif line:match("interface conversion: .* is not .*") then
						panic_type = "PANIC-INTERFACE-CONVERSION"
					elseif line:match("interface .* is nil, not") then
						panic_type = "PANIC-NIL-INTERFACE"
					elseif line:match("send on closed channel") then
						panic_type = "PANIC-SEND-CLOSED-CHANNEL"
					elseif line:match("close of closed channel") then
						panic_type = "PANIC-CLOSE-CLOSED-CHANNEL"
					elseif line:match("close of nil channel") then
						panic_type = "PANIC-CLOSE-NIL-CHANNEL"
					elseif line:match("send on nil channel") then
						panic_type = "PANIC-SEND-NIL-CHANNEL"
					elseif line:match("receive from nil channel") then
						panic_type = "PANIC-RECEIVE-NIL-CHANNEL"
					elseif line:match("assignment to entry in nil map") then
						panic_type = "PANIC-NIL-MAP-ASSIGN"
					elseif line:match("range over nil map") then
						panic_type = "PANIC-RANGE-NIL-MAP"
					elseif line:match("negative array length") then
						panic_type = "PANIC-NEGATIVE-ARRAY-LENGTH"
					elseif line:match("makeslice: len out of range") then
						panic_type = "PANIC-MAKESLICE-LEN-OUT-OF-RANGE"
					elseif line:match("makeslice: cap out of range") then
						panic_type = "PANIC-MAKESLICE-CAP-OUT-OF-RANGE"
					elseif line:match("makechan: size out of range") then
						panic_type = "PANIC-MAKECHAN-SIZE-OUT-OF-RANGE"
					elseif line:match("runtime error: comparing uncomparable type") then
						panic_type = "PANIC-UNCOMPARABLE-TYPE"
					elseif line:match("runtime error: go routine has exceeded the stack limit") then
						panic_type = "PANIC-STACK-OVERFLOW"
					elseif line:match("runtime error: map assignment to entry in nil map") then
						panic_type = "PANIC-NIL-MAP-WRITE"
					end

					table.insert(errors, {
						filename = vim.fn.expand("%"),
						lnum = 1,
						text = line,
						display = panic_type .. ": " .. line,
					})
				end

				if line:match("runtime error:") then
					local error_type = "RUNTIME-ERROR"
					if line:match("index out of range %[%d+%] with length %d+") then
						error_type = "INDEX-OUT-OF-RANGE-WITH-LENGTH"
					elseif line:match("index out of range") then
						error_type = "INDEX-OUT-OF-RANGE"
					elseif line:match("nil pointer dereference") then
						error_type = "NIL-POINTER"
					elseif line:match("slice bounds out of range %[%d*:%d*%] with capacity %d+") then
						error_type = "SLICE-BOUNDS-WITH-CAPACITY"
					elseif line:match("slice bounds out of range") then
						error_type = "SLICE-BOUNDS"
					elseif line:match("invalid memory address") then
						error_type = "INVALID-MEMORY"
					elseif line:match("integer divide by zero") then
						error_type = "DIVIDE-BY-ZERO"
					elseif line:match("integer overflow") then
						error_type = "INTEGER-OVERFLOW"
					elseif line:match("stack overflow") then
						error_type = "STACK-OVERFLOW"
					elseif line:match("makeslice: len out of range") then
						error_type = "MAKESLICE-OUT-OF-RANGE"
					elseif line:match("makeslice: cap out of range") then
						error_type = "MAKESLICE-CAP-OUT-OF-RANGE"
					elseif line:match("makemap: size out of range") then
						error_type = "MAKEMAP-SIZE-OUT-OF-RANGE"
					elseif line:match("makechan: size out of range") then
						error_type = "MAKECHAN-SIZE-OUT-OF-RANGE"
					elseif line:match("hash of unhashable type") then
						error_type = "UNHASHABLE-TYPE"
					elseif line:match("comparing uncomparable type") then
						error_type = "UNCOMPARABLE-TYPE"
					elseif line:match("type assertion failed") then
						error_type = "TYPE-ASSERTION-FAILED"
					elseif line:match("method call on nil interface value") then
						error_type = "METHOD-CALL-NIL-INTERFACE"
					elseif line:match("reflect: call of") then
						error_type = "REFLECTION-ERROR"
					end

					table.insert(errors, {
						filename = vim.fn.expand("%"),
						lnum = 1,
						text = line,
						display = error_type .. ": " .. line,
					})
				end

				local go_error_patterns = {
					-- Fatal errors
					{ pattern = "fatal error: all goroutines are asleep", type = "DEADLOCK" },
					{ pattern = "fatal error: concurrent map", type = "CONCURRENT-MAP" },
					{ pattern = "fatal error: stack overflow", type = "STACK-OVERFLOW" },
					{ pattern = "fatal error: runtime: out of memory", type = "OUT-OF-MEMORY" },
					{ pattern = "fatal error: runtime: memory corruption", type = "MEMORY-CORRUPTION" },
					{ pattern = "fatal error: checkptr", type = "CHECKPTR-VIOLATION" },
					{ pattern = "fatal error: unexpected signal", type = "UNEXPECTED-SIGNAL" },
					{ pattern = "fatal error: runtime: cannot map pages", type = "CANNOT-MAP-PAGES" },
					{ pattern = "fatal error: runtime: address space conflict", type = "ADDRESS-SPACE-CONFLICT" },
					{ pattern = "fatal error: runtime: out of system threads", type = "OUT-OF-THREADS" },
					{ pattern = "fatal error: runtime: unable to commit memory", type = "UNABLE-COMMIT-MEMORY" },
					{ pattern = "fatal error: morestack on g0", type = "MORESTACK-G0" },
					{ pattern = "fatal error: newosproc", type = "NEWOSPROC-ERROR" },
					{ pattern = "fatal error: cgo argument has Go pointer", type = "CGO-GO-POINTER" },
					{ pattern = "fatal error: cgo result has Go pointer", type = "CGO-RESULT-POINTER" },

					-- Race conditions and concurrency
					{ pattern = "WARNING: DATA RACE", type = "RACE" },
					{ pattern = "Found %d+ data race%(s%)", type = "RACE-SUMMARY" },
					{ pattern = "Previous write at", type = "RACE-PREVIOUS-WRITE" },
					{ pattern = "Previous read at", type = "RACE-PREVIOUS-READ" },
					{ pattern = "Goroutine %d+ %(running%)", type = "RACE-GOROUTINE-RUNNING" },
					{ pattern = "Goroutine %d+ %(finished%)", type = "RACE-GOROUTINE-FINISHED" },
					{ pattern = "==================", type = "RACE-SEPARATOR" },

					-- HTTP and network errors
					{ pattern = "http: panic serving", type = "HTTP-PANIC" },
					{ pattern = "dial tcp.*: connection refused", type = "CONNECTION-REFUSED" },
					{ pattern = "dial tcp.*: timeout", type = "CONNECTION-TIMEOUT" },
					{ pattern = "dial tcp.*: no such host", type = "DNS-RESOLUTION-FAILED" },
					{ pattern = "dial tcp.*: network is unreachable", type = "NETWORK-UNREACHABLE" },
					{ pattern = "dial tcp.*: permission denied", type = "CONNECTION-PERMISSION-DENIED" },
					{ pattern = "dial tcp.*: address already in use", type = "ADDRESS-IN-USE" },
					{ pattern = "EOF", type = "UNEXPECTED-EOF" },
					{ pattern = "connection reset by peer", type = "CONNECTION-RESET" },
					{ pattern = "broken pipe", type = "BROKEN-PIPE" },
					{ pattern = "no such host", type = "DNS-RESOLUTION-FAILED" },
					{ pattern = "i/o timeout", type = "IO-TIMEOUT" },
					{ pattern = "context deadline exceeded", type = "CONTEXT-DEADLINE-EXCEEDED" },
					{ pattern = "TLS handshake timeout", type = "TLS-HANDSHAKE-TIMEOUT" },
					{ pattern = "certificate verify failed", type = "TLS-CERT-VERIFY-FAILED" },
					{ pattern = "x509: certificate", type = "X509-CERTIFICATE-ERROR" },

					-- Import and module errors
					{ pattern = "import cycle not allowed", type = "IMPORT-CYCLE" },
					{ pattern = "package .* is not in GOROOT", type = "PACKAGE-NOT-FOUND" },
					{ pattern = "go: cannot find main module", type = "MODULE-NOT-FOUND" },
					{ pattern = "go mod download", type = "MODULE-DOWNLOAD-ERROR" },
					{ pattern = "go: updates to go.mod needed", type = "MODULE-UPDATE-NEEDED" },
					{ pattern = "go: inconsistent vendoring", type = "INCONSISTENT-VENDORING" },
					{ pattern = "go: module .* found, but does not contain package", type = "MODULE-MISSING-PACKAGE" },
					{ pattern = "ambiguous import", type = "AMBIGUOUS-IMPORT" },
					{ pattern = "go: module .* requires Go", type = "MODULE-GO-VERSION-REQUIRED" },
					{ pattern = "go: go.mod file not found", type = "GO-MOD-NOT-FOUND" },
					{ pattern = "go: cannot use path@version syntax", type = "INVALID-MODULE-SYNTAX" },
					{ pattern = "go: .* has been replaced", type = "MODULE-REPLACED" },
					{ pattern = "go: .* is retracted", type = "MODULE-RETRACTED" },
					{ pattern = "go: .* has non%-go build constraints", type = "NON-GO-BUILD-CONSTRAINTS" },
					{ pattern = "go: .* invalid version", type = "INVALID-MODULE-VERSION" },
					{ pattern = "go: checksum mismatch", type = "CHECKSUM-MISMATCH" },
					{ pattern = "go: verifying .* checksum", type = "CHECKSUM-VERIFICATION-FAILED" },

					-- Build and compilation errors
					{ pattern = "build constraints exclude all Go files", type = "BUILD-CONSTRAINTS" },
					{ pattern = "no Go files in", type = "NO-GO-FILES" },
					{ pattern = "expected 'package'", type = "MISSING-PACKAGE-DECL" },
					{ pattern = "can't load package", type = "PACKAGE-LOAD-ERROR" },
					{ pattern = "build cache is required", type = "BUILD-CACHE-REQUIRED" },
					{ pattern = "go: unknown subcommand", type = "UNKNOWN-SUBCOMMAND" },
					{ pattern = "flag provided but not defined", type = "UNKNOWN-FLAG" },
					{ pattern = "go build .*: no such file or directory", type = "BUILD-FILE-NOT-FOUND" },
					{ pattern = "go: GOPATH entry is relative", type = "RELATIVE-GOPATH" },
					{ pattern = "go: cannot build using the vendor directory", type = "VENDOR-BUILD-ERROR" },
					{ pattern = "pattern .* matches no packages", type = "PATTERN-NO-MATCHES" },
					{ pattern = "named files must be .go files", type = "NON-GO-FILE-IN-BUILD" },

					-- CGO errors
					{ pattern = "could not determine kind of name for C", type = "CGO-NAME-ERROR" },
					{ pattern = "C source files not allowed when not using cgo", type = "CGO-NOT-ENABLED" },
					{ pattern = "malformed #cgo argument", type = "CGO-MALFORMED-ARG" },
					{ pattern = "C\\..*: undefined reference", type = "CGO-UNDEFINED-REFERENCE" },
					{ pattern = "C compiler .* not found", type = "CGO-COMPILER-NOT-FOUND" },
					{ pattern = "cgo: C compiler not found", type = "CGO-NO-COMPILER" },
					{ pattern = "cgo: error setting CPATH", type = "CGO-CPATH-ERROR" },
					{ pattern = "package must be in $GOROOT", type = "CGO-PACKAGE-LOCATION-ERROR" },

					-- Assembly errors
					{ pattern = "asm: .* undefined", type = "ASM-UNDEFINED" },
					{ pattern = "asm: .* redefined", type = "ASM-REDEFINED" },
					{ pattern = "asm: .* is not a register", type = "ASM-NOT-REGISTER" },
					{ pattern = "asm: unknown instruction", type = "ASM-UNKNOWN-INSTRUCTION" },
					{ pattern = "asm: bad addressing mode", type = "ASM-BAD-ADDRESSING-MODE" },

					-- Version and compatibility errors
					{ pattern = "go version .* does not match", type = "VERSION-MISMATCH" },
					{ pattern = "requires go .* or later", type = "GO-VERSION-TOO-OLD" },
					{ pattern = "unsupported GOOS/GOARCH pair", type = "UNSUPPORTED-PLATFORM" },
					{ pattern = "minimum supported Go version", type = "MIN-GO-VERSION-NOT-MET" },

					-- Plugin and dynamic loading errors
					{ pattern = "plugin: symbol .* not found", type = "PLUGIN-SYMBOL-NOT-FOUND" },
					{
						pattern = "plugin was built with a different version of package",
						type = "PLUGIN-VERSION-MISMATCH",
					},
					{ pattern = "runtime: failed to create new OS thread", type = "THREAD-CREATION-FAILED" },
					{ pattern = "plugin.Open.*: file does not exist", type = "PLUGIN-FILE-NOT-FOUND" },

					-- Generic/type parameter errors (Go 1.18+)
					{ pattern = "instantiation cycle", type = "GENERIC-INSTANTIATION-CYCLE" },
					{ pattern = "type parameter .* not found", type = "GENERIC-TYPE-PARAM-NOT-FOUND" },
					{ pattern = "type constraint not satisfied", type = "GENERIC-CONSTRAINT-NOT-SATISFIED" },
					{ pattern = "cannot infer .* for", type = "GENERIC-TYPE-INFERENCE-FAILED" },

					-- Memory and GC errors
					{ pattern = "GC.*spent.*% of time", type = "GC-EXCESSIVE-TIME" },
					{ pattern = "scavenge.*heap.*MB", type = "MEMORY-SCAVENGE" },
					{ pattern = "MADV_DONTNEED", type = "MADV-DONTNEED-ERROR" },

					-- Signal errors
					{ pattern = "signal SIGSEGV:", type = "SEGMENTATION-FAULT" },
					{ pattern = "signal SIGABRT:", type = "ABORT-SIGNAL" },
					{ pattern = "signal SIGKILL:", type = "KILL-SIGNAL" },
					{ pattern = "signal SIGTERM:", type = "TERM-SIGNAL" },
					{ pattern = "signal SIGINT:", type = "INTERRUPT-SIGNAL" },
					{ pattern = "signal SIGPIPE:", type = "PIPE-SIGNAL" },

					-- Database and SQL errors
					{ pattern = "sql: no rows in result set", type = "SQL-NO-ROWS" },
					{ pattern = "sql: Scan error", type = "SQL-SCAN-ERROR" },
					{ pattern = "sql: database is closed", type = "SQL-DB-CLOSED" },
					{
						pattern = "sql: transaction has already been committed or rolled back",
						type = "SQL-TX-FINISHED",
					},

					-- JSON and encoding errors
					{ pattern = "json: cannot unmarshal", type = "JSON-UNMARSHAL-ERROR" },
					{ pattern = "json: unsupported type", type = "JSON-UNSUPPORTED-TYPE" },
					{ pattern = "json: unsupported value", type = "JSON-UNSUPPORTED-VALUE" },
					{ pattern = "invalid character.*looking for", type = "JSON-INVALID-CHARACTER" },

					-- Template errors
					{ pattern = "template: .* is an incomplete or empty template", type = "TEMPLATE-INCOMPLETE" },
					{ pattern = "template: .* is undefined", type = "TEMPLATE-UNDEFINED" },
					{ pattern = "template: .* has no field or method", type = "TEMPLATE-NO-FIELD" },

					-- Reflection errors
					{ pattern = "reflect: call of .* on zero Value", type = "REFLECT-ZERO-VALUE" },
					{ pattern = "reflect: .* using unaddressable value", type = "REFLECT-UNADDRESSABLE" },
					{
						pattern = "reflect: .* using value obtained using unexported field",
						type = "REFLECT-UNEXPORTED",
					},

					-- Context errors
					{ pattern = "context canceled", type = "CONTEXT-CANCELED" },
					{ pattern = "context: deadline exceeded", type = "CONTEXT-DEADLINE-EXCEEDED" },

					-- File system errors
					{ pattern = "no such file or directory", type = "FILE-NOT-FOUND" },
					{ pattern = "permission denied", type = "PERMISSION-DENIED" },
					{ pattern = "file already exists", type = "FILE-EXISTS" },
					{ pattern = "is a directory", type = "IS-DIRECTORY" },
					{ pattern = "not a directory", type = "NOT-DIRECTORY" },
					{ pattern = "directory not empty", type = "DIRECTORY-NOT-EMPTY" },
					{ pattern = "too many open files", type = "TOO-MANY-OPEN-FILES" },
				}

				for _, p in ipairs(go_error_patterns) do
					if line:match(p.pattern) then
						table.insert(errors, {
							filename = vim.fn.expand("%"),
							lnum = 1,
							text = line,
							display = p.type .. ": " .. line,
						})
						break
					end
				end

				-- Expanded Go warning patterns
				local go_warning_patterns = {
					-- Context warnings
					{ pattern = "context deadline exceeded", type = "CONTEXT-TIMEOUT" },
					{ pattern = "context canceled", type = "CONTEXT-CANCELED" },

					-- Testing warnings
					{ pattern = "testing: warning:", type = "TEST-WARNING" },
					{ pattern = "testing: .* left running", type = "GOROUTINE-LEAK" },
					{ pattern = "testing: .* ran for", type = "TEST-TIMEOUT" },
					{ pattern = "testing: .* called Runtime.Goexit", type = "TEST-GOEXIT" },
					{ pattern = "testing: allocator check failed", type = "TEST-ALLOC-CHECK-FAILED" },

					-- Benchmark warnings
					{ pattern = "testing: warning:", type = "BENCHMARK-WARNING" },
					{ pattern = "BenchmarkTimeout", type = "BENCHMARK-TIMEOUT" },
					{ pattern = "testing: .* before Benchmark", type = "BENCHMARK-ISSUE" },
					{ pattern = "benchmark ran only .* times", type = "BENCHMARK-LOW-COUNT" },

					-- Code quality warnings
					{ pattern = "ineffective assignment to", type = "INEFFECTIVE-ASSIGNMENT" },
					{ pattern = "should have comment", type = "MISSING-COMMENT" },
					{ pattern = "exported .* should have comment", type = "EXPORTED-NO-COMMENT" },
					{ pattern = "don't use underscores", type = "UNDERSCORE-NAMING" },
					{ pattern = "should be .* instead of", type = "NAMING-CONVENTION" },
					{ pattern = "cyclomatic complexity .* of func .* is high", type = "HIGH-COMPLEXITY" },
					{ pattern = "function .* is too long", type = "FUNCTION-TOO-LONG" },
					{ pattern = "cognitive complexity .* of func", type = "HIGH-COGNITIVE-COMPLEXITY" },
					{ pattern = "cyclomatic complexity .* exceeds max", type = "COMPLEXITY-EXCEEDED" },

					-- Performance warnings
					{ pattern = "string .* has .* occurrences, make it const", type = "STRING-SHOULD-BE-CONST" },
					{ pattern = "should replace loop with", type = "LOOP-OPTIMIZATION" },
					{ pattern = "redundant type from array, slice, or map composite literal", type = "REDUNDANT-TYPE" },
					{ pattern = "should use make.*instead of", type = "MAKE-OPTIMIZATION" },
					{ pattern = "unnecessary conversion", type = "UNNECESSARY-CONVERSION" },
					{ pattern = "should use raw string", type = "RAW-STRING-SUGGESTION" },

					-- Security warnings
					{ pattern = "potential hardcoded credentials", type = "HARDCODED-CREDENTIALS" },
					{ pattern = "Errors unhandled", type = "UNHANDLED-ERROR" },
					{ pattern = "defer .* in loop", type = "DEFER-IN-LOOP" },
					{ pattern = "potential DoS vulnerability", type = "POTENTIAL-DOS" },
					{ pattern = "weak random number generator", type = "WEAK-RNG" },
					{ pattern = "insecure random number source", type = "INSECURE-RANDOM" },
					{ pattern = "SQL injection", type = "SQL-INJECTION-RISK" },
					{ pattern = "XSS vulnerability", type = "XSS-VULNERABILITY" },
					{ pattern = "hardcoded password", type = "HARDCODED-PASSWORD" },
					{ pattern = "use of insecure MD5", type = "INSECURE-MD5" },
					{ pattern = "use of insecure SHA1", type = "INSECURE-SHA1" },

					-- Linter warnings (golint, staticcheck, gosec, etc.)
					{ pattern = "exported function .* should have comment", type = "LINT-EXPORTED-FUNC-COMMENT" },
					{ pattern = "exported type .* should have comment", type = "LINT-EXPORTED-TYPE-COMMENT" },
					{ pattern = "exported const .* should have comment", type = "LINT-EXPORTED-CONST-COMMENT" },
					{ pattern = "exported var .* should have comment", type = "LINT-EXPORTED-VAR-COMMENT" },
					{ pattern = "var .* should be", type = "LINT-VAR-NAMING" },
					{ pattern = "type .* should be", type = "LINT-TYPE-NAMING" },
					{ pattern = "func .* should be", type = "LINT-FUNC-NAMING" },
					{ pattern = "const .* should be", type = "LINT-CONST-NAMING" },
					{ pattern = "if block ends with a return statement", type = "LINT-UNNECESSARY-ELSE" },
					{ pattern = "should use .* instead of", type = "LINT-BETTER-ALTERNATIVE" },
					{ pattern = "should omit type .* from declaration", type = "LINT-OMIT-TYPE" },
					{ pattern = "should not use ALL_CAPS", type = "LINT-ALL-CAPS" },
					{ pattern = "should not use dot imports", type = "LINT-DOT-IMPORT" },
					{ pattern = "should use blank import", type = "LINT-BLANK-IMPORT" },
					{ pattern = "should have signature", type = "LINT-SIGNATURE" },

					-- Staticcheck warnings
					{ pattern = "SA%d+:", type = "STATICCHECK-WARNING" },
					{ pattern = "ST%d+:", type = "STATICCHECK-STYLE" },
					{ pattern = "S%d+:", type = "STATICCHECK-SIMPLE" },
					{ pattern = "QF%d+:", type = "STATICCHECK-QUICKFIX" },
					{ pattern = "U%d+:", type = "STATICCHECK-UNUSED" },

					-- gosec warnings
					{ pattern = "G%d+:", type = "GOSEC-WARNING" },
					{ pattern = "CWE%-%d+:", type = "GOSEC-CWE" },

					-- Vet warnings
					{ pattern = "possible misuse of unsafe.Pointer", type = "VET-UNSAFE-POINTER" },
					{ pattern = "composite literal uses unkeyed fields", type = "VET-UNKEYED-FIELDS" },
					{ pattern = "should not use built%-in name", type = "VET-BUILTIN-NAME" },
					{ pattern = "Printf call needs %d+ arg", type = "VET-PRINTF-ARGS" },
					{ pattern = "Printf format %.*s reads arg", type = "VET-PRINTF-FORMAT" },
					{ pattern = "unreachable code", type = "VET-UNREACHABLE" },
					{ pattern = "result of .* is not used", type = "VET-RESULT-NOT-USED" },
					{ pattern = "assignment to nil map", type = "VET-NIL-MAP-ASSIGNMENT" },
					{ pattern = "range over .* copies lock", type = "VET-RANGE-LOCK-COPY" },
					{ pattern = "call of .* copies lock", type = "VET-CALL-LOCK-COPY" },
					{ pattern = "defer .* copies lock", type = "VET-DEFER-LOCK-COPY" },
					{ pattern = "struct field .* has json tag but is not exported", type = "VET-UNEXPORTED-JSON" },
					{ pattern = "struct field .* repeats json tag", type = "VET-DUPLICATE-JSON-TAG" },

					-- Go modules warnings
					{ pattern = "go: warning: .* sum in go.sum is missing", type = "GO-MOD-MISSING-SUM" },
					{ pattern = "go: warning: .* sum in go.sum is incorrect", type = "GO-MOD-INCORRECT-SUM" },
					{ pattern = "go: updates to go.sum needed", type = "GO-MOD-SUM-UPDATE" },
					{ pattern = "go: downloading", type = "GO-MOD-DOWNLOADING" },
					{ pattern = "go: finding", type = "GO-MOD-FINDING" },
					{ pattern = "go: extracting", type = "GO-MOD-EXTRACTING" },

					-- Build warnings
					{ pattern = "warning: GOPATH set to GOROOT", type = "BUILD-GOPATH-GOROOT" },
					{ pattern = "warning: ignoring symlink", type = "BUILD-IGNORE-SYMLINK" },
					{ pattern = "warning: vendor directory", type = "BUILD-VENDOR-WARNING" },

					-- CGO warnings
					{ pattern = "warning: passing argument", type = "CGO-ARG-WARNING" },
					{ pattern = "warning: assignment", type = "CGO-ASSIGNMENT-WARNING" },
					{ pattern = "warning: function declaration", type = "CGO-FUNC-DECL-WARNING" },
					{ pattern = "warning: implicit declaration", type = "CGO-IMPLICIT-DECL" },
					{ pattern = "warning: incompatible pointer types", type = "CGO-INCOMPATIBLE-POINTERS" },

					-- Race detector warnings
					{ pattern = "WARNING: ThreadSanitizer", type = "RACE-THREAD-SANITIZER" },
					{ pattern = "WARNING: DATA RACE", type = "RACE-DATA-RACE" },
					{ pattern = "Race at", type = "RACE-LOCATION" },

					-- Memory warnings
					{ pattern = "GC forced", type = "MEMORY-GC-FORCED" },
					{ pattern = "runtime: marked", type = "MEMORY-MARKED" },
					{ pattern = "runtime: swept", type = "MEMORY-SWEPT" },
					{ pattern = "runtime: scvg.*MB", type = "MEMORY-SCAVENGE" },

					-- HTTP warnings
					{ pattern = "http: multiple response.WriteHeader calls", type = "HTTP-MULTIPLE-WRITEHEADER" },
					{ pattern = "http: superfluous response.WriteHeader", type = "HTTP-SUPERFLUOUS-WRITEHEADER" },
					{ pattern = "http: request body too large", type = "HTTP-BODY-TOO-LARGE" },
					{ pattern = "http: Handler timeout", type = "HTTP-HANDLER-TIMEOUT" },

					-- TLS/Security warnings
					{ pattern = "tls: oversized record received", type = "TLS-OVERSIZED-RECORD" },
					{ pattern = "tls: unsupported SSLv2 handshake", type = "TLS-UNSUPPORTED-SSL" },
					{ pattern = "crypto/tls: alert", type = "TLS-ALERT" },

					-- Generic/Generics warnings (Go 1.18+)
					{ pattern = "instantiation.*may cause infinite recursion", type = "GENERIC-INFINITE-RECURSION" },
					{ pattern = "type parameter.*not used", type = "GENERIC-UNUSED-TYPE-PARAM" },
					{ pattern = "type constraint.*has no type terms", type = "GENERIC-EMPTY-CONSTRAINT" },

					-- Deprecation warnings
					{ pattern = "deprecated:", type = "DEPRECATED" },
					{ pattern = "Deprecated:", type = "DEPRECATED-COMMENT" },
					{ pattern = "is deprecated", type = "DEPRECATED-USAGE" },

					-- Package warnings
					{ pattern = "package .* without import comment", type = "PACKAGE-NO-IMPORT-COMMENT" },
					{ pattern = "should have package comment", type = "PACKAGE-NO-COMMENT" },

					-- Documentation warnings
					{ pattern = "missing return comment", type = "DOC-MISSING-RETURN" },
					{ pattern = "missing parameter comment", type = "DOC-MISSING-PARAM" },
					{ pattern = "comment should be of the form", type = "DOC-FORM-INCORRECT" },

					-- Import warnings
					{ pattern = "import.*not used", type = "IMPORT-NOT-USED" },
					{ pattern = "should not import.*and", type = "IMPORT-CONFLICT" },

					-- Goroutine warnings
					{ pattern = "goroutine.*blocked.*on", type = "GOROUTINE-BLOCKED" },
					{ pattern = "goroutine leak", type = "GOROUTINE-LEAK" },

					-- Channel warnings
					{ pattern = "possible deadlock.*channel", type = "CHANNEL-DEADLOCK" },
					{ pattern = "channel.*never closed", type = "CHANNEL-NEVER-CLOSED" },

					-- Error handling warnings
					{ pattern = "error returned from.*is not checked", type = "ERROR-NOT-CHECKED" },
					{ pattern = "should check returned error", type = "ERROR-CHECK-MISSING" },
					{ pattern = "Error return value.*not checked", type = "ERROR-RETURN-UNCHECKED" },

					-- Variable/constant warnings
					{ pattern = "var.*is unused", type = "VAR-UNUSED" },
					{ pattern = "const.*is unused", type = "CONST-UNUSED" },
					{ pattern = "func.*is unused", type = "FUNC-UNUSED" },
					{ pattern = "type.*is unused", type = "TYPE-UNUSED" },
					{ pattern = "field.*is unused", type = "FIELD-UNUSED" },
					{ pattern = "parameter.*seems to be unused", type = "PARAM-UNUSED" },

					-- Style warnings
					{ pattern = "don't use underscores in Go names", type = "STYLE-UNDERSCORE" },
					{ pattern = "should not use MixedCaps", type = "STYLE-MIXED-CAPS" },
					{ pattern = "should be.*not", type = "STYLE-NAMING" },
					{ pattern = "receiver name.*should be", type = "STYLE-RECEIVER-NAME" },

					-- Configuration warnings
					{ pattern = "go: .* requires minimum go version", type = "CONFIG-MIN-VERSION" },
					{ pattern = "go: .* uses newer go version", type = "CONFIG-NEWER-VERSION" },

					-- Tool warnings
					{ pattern = "go fmt", type = "TOOL-GO-FMT" },
					{ pattern = "goimports", type = "TOOL-GOIMPORTS" },
					{ pattern = "golint", type = "TOOL-GOLINT" },
					{ pattern = "govet", type = "TOOL-GOVET" },
				}

				for _, p in ipairs(go_warning_patterns) do
					if line:match(p.pattern) then
						table.insert(warnings, {
							filename = vim.fn.expand("%"),
							lnum = 1,
							text = line,
							display = p.type .. ": " .. line,
						})
						break
					end
				end

				if line:match("^=== PAUSE") then
					-- Test pause
					local test_name = line:match("^=== PAUSE%s+(.+)")
					table.insert(warnings, {
						filename = vim.fn.expand("%"),
						lnum = 1,
						text = line,
						display = "TEST-PAUSED: " .. (test_name or line),
					})
				elseif line:match("^=== CONT") then
					-- Test continue
					local test_name = line:match("^=== CONT%s+(.+)")
					table.insert(warnings, {
						filename = vim.fn.expand("%"),
						lnum = 1,
						text = line,
						display = "TEST-CONTINUED: " .. (test_name or line),
					})
				elseif line:match("FAIL") and line:match("%.go:%d+") then
					local test_file, test_line_num = line:match("([^%s]+%.go):(%d+)")
					if test_file and test_line_num then
						table.insert(errors, {
							filename = test_file,
							lnum = tonumber(test_line_num),
							text = line,
							display = string.format(
								"TEST-FAIL: %s:%s: %s",
								vim.fn.fnamemodify(test_file, ":t"),
								test_line_num,
								line
							),
						})
					else
						table.insert(errors, {
							filename = vim.fn.expand("%"),
							lnum = 1,
							text = line,
							display = "TEST-FAIL: " .. line,
						})
					end
				elseif line:match("--- FAIL:") then
					local test_name, duration = line:match("--- FAIL: ([^%s%(]+)%s*%(([^%)]+)%)")
					if not test_name then
						test_name = line:match("--- FAIL: ([^%s%(]+)")
					end
					table.insert(errors, {
						filename = vim.fn.expand("%"),
						lnum = 1,
						text = line,
						display = "TEST-FAILED: "
							.. (test_name or line)
							.. (duration and " (" .. duration .. ")" or ""),
					})
				elseif line:match("--- SKIP:") then
					local test_name, reason = line:match("--- SKIP: ([^%s%(]+)%s*%(([^%)]+)%)")
					if not test_name then
						test_name = line:match("--- SKIP: ([^%s%(]+)")
					end
					table.insert(warnings, {
						filename = vim.fn.expand("%"),
						lnum = 1,
						text = line,
						display = "TEST-SKIPPED: " .. (test_name or line) .. (reason and " (" .. reason .. ")" or ""),
					})
				elseif line:match("--- PASS:") then
					local test_name, duration = line:match("--- PASS: ([^%s%(]+)%s*%(([^%)]+)%)")
					if not test_name then
						test_name = line:match("--- PASS: ([^%s%(]+)")
					end
				-- Usually don't add PASS as warnings, but could be useful for verbose output
				-- Uncomment if you want to see passing tests
				--[[
		table.insert(warnings, {
			filename = vim.fn.expand("%"),
			lnum = 1,
			text = line,
			display = "TEST-PASSED: " .. (test_name or line) .. (duration and " (" .. duration .. ")" or ""),
		})
		--]]
				elseif line:match("FAIL%s+[^%s]+%s+%d+%.%d+s") then
					local pkg, duration = line:match("FAIL%s+([^%s]+)%s+(%d+%.%d+s)")
					if pkg then
						table.insert(errors, {
							filename = vim.fn.expand("%"),
							lnum = 1,
							text = line,
							display = "PACKAGE-FAIL: " .. pkg .. " (" .. (duration or "unknown time") .. ")",
						})
					end
				elseif line:match("ok%s+[^%s]+%s+%d+%.%d+s") then
					local pkg, duration = line:match("ok%s+([^%s]+)%s+(%d+%.%d+s)")
				-- Usually don't add OK as warnings, but could be useful for verbose output
				--[[
		if pkg then
			table.insert(warnings, {
				filename = vim.fn.expand("%"),
				lnum = 1,
				text = line,
				display = "PACKAGE-OK: " .. pkg .. " (" .. (duration or "unknown time") .. ")",
			})
		end
		--]]
				elseif line:match("^%s*[^%s]+_test%.go:%d+:") then
					local test_file, test_line_num, test_msg = line:match("^%s*([^%s]+_test%.go):(%d+):%s*(.+)")
					if test_file and test_line_num and test_msg then
						table.insert(errors, {
							filename = test_file,
							lnum = tonumber(test_line_num),
							text = test_msg,
							display = string.format(
								"TEST-ASSERT: %s:%s: %s",
								vim.fn.fnamemodify(test_file, ":t"),
								test_line_num,
								test_msg
							),
						})
					end
				elseif line:match("testing: warning:") then
					table.insert(warnings, {
						filename = vim.fn.expand("%"),
						lnum = 1,
						text = line,
						display = "TEST-WARNING: " .. line,
					})
				elseif line:match("panic.*test") then
					table.insert(errors, {
						filename = vim.fn.expand("%"),
						lnum = 1,
						text = line,
						display = "TEST-PANIC: " .. line,
					})
				elseif line:match("^Error Trace:") then
					table.insert(errors, {
						filename = vim.fn.expand("%"),
						lnum = 1,
						text = line,
						display = "TEST-ERROR-TRACE: " .. line,
					})
				elseif line:match("^Error:%s") then
					table.insert(errors, {
						filename = vim.fn.expand("%"),
						lnum = 1,
						text = line,
						display = "TEST-ERROR: " .. line,
					})
				elseif line:match("^Test:%s") then
					table.insert(errors, {
						filename = vim.fn.expand("%"),
						lnum = 1,
						text = line,
						display = "TEST-INFO: " .. line,
					})
				end

				if line:match("^Benchmark") and line:match("%d+%.%d+ ns/op") then
				-- Benchmark results - could be used for performance tracking later perhaps
				elseif line:match("testing: .* before Benchmark") then
					table.insert(warnings, {
						filename = vim.fn.expand("%"),
						lnum = 1,
						text = line,
						display = "BENCHMARK-ISSUE: " .. line,
					})
				elseif line:match("BenchmarkTimeout") then
					table.insert(warnings, {
						filename = vim.fn.expand("%"),
						lnum = 1,
						text = line,
						display = "BENCHMARK-TIMEOUT: " .. line,
					})
				elseif line:match("benchmark.*allocations") then
					table.insert(warnings, {
						filename = vim.fn.expand("%"),
						lnum = 1,
						text = line,
						display = "BENCHMARK-ALLOC: " .. line,
					})
				elseif line:match("benchmark.*too fast") then
					table.insert(warnings, {
						filename = vim.fn.expand("%"),
						lnum = 1,
						text = line,
						display = "BENCHMARK-TOO-FAST: " .. line,
					})
				end

				if line:match("^=== FUZZ") then
					local fuzz_name = line:match("^=== FUZZ%s+(.+)")
					if line:match("FAIL") then
						table.insert(errors, {
							filename = vim.fn.expand("%"),
							lnum = 1,
							text = line,
							display = "FUZZ-FAIL: " .. (fuzz_name or line),
						})
					end
				elseif line:match("fuzz: elapsed:") then
				-- Fuzz progress info
				elseif line:match("fuzz: minimizing") then
					table.insert(warnings, {
						filename = vim.fn.expand("%"),
						lnum = 1,
						text = line,
						display = "FUZZ-MINIMIZING: " .. line,
					})
				elseif line:match("fuzz: seed corpus entry") then
					table.insert(warnings, {
						filename = vim.fn.expand("%"),
						lnum = 1,
						text = line,
						display = "FUZZ-SEED-CORPUS: " .. line,
					})
				end

				-- Stack trace patterns with more detail
				file, line_num = line:match("([^%s]+%.go):(%d+) %+0x")
				if file and line_num then
					local func_name = line:match("([^%.%s]+)%(")
					table.insert(errors, {
						filename = file,
						lnum = tonumber(line_num),
						text = line,
						display = string.format(
							"STACK: %s:%s%s: %s",
							vim.fn.fnamemodify(file, ":t"),
							line_num,
							func_name and " in " .. func_name or "",
							line
						),
					})
				end

				-- Goroutine stack traces
				if line:match("^goroutine %d+") then
					local goroutine_id, state = line:match("^goroutine (%d+) %[([^%]]+)%]")
					if goroutine_id and state then
						table.insert(errors, {
							filename = vim.fn.expand("%"),
							lnum = 1,
							text = line,
							display = string.format(
								"GOROUTINE-%s: goroutine %s [%s]",
								state:upper(),
								goroutine_id,
								state
							),
						})
					end
				end

				-- Created by patterns
				if line:match("created by") and line:match("%.go:%d+") then
					file, line_num = line:match("([^%s]+%.go):(%d+)")
					if file and line_num then
						table.insert(warnings, {
							filename = file,
							lnum = tonumber(line_num),
							text = line,
							display = string.format(
								"CREATED-BY: %s:%s: %s",
								vim.fn.fnamemodify(file, ":t"),
								line_num,
								line
							),
						})
					end
				end
			elseif filetype == "rust" then
				-- File location pattern (updates last error/warning with location info)
				file, line_num, msg = line:match("([^:]+%.rs):(%d+):%d+:%s*(.+)")
				if file and line_num and msg then
					local item = {
						filename = file,
						lnum = tonumber(line_num),
						text = msg,
						display = string.format("%s:%s: %s", vim.fn.fnamemodify(file, ":t"), line_num, msg),
					}
					-- Determine if it's an error or warning based on content
					if line:match("^%s*error") then
						table.insert(errors, item)
					elseif line:match("^%s*warning") then
						table.insert(warnings, item)
					else
						-- Default to error for unclassified items with file locations
						table.insert(errors, item)
					end
				else
					-- Handle error/warning codes and messages without direct file info
					local error_code, rust_msg = line:match("^%s*error%[([^%]]+)%]:%s*(.+)")
					if error_code and rust_msg then
						table.insert(errors, {
							filename = vim.fn.expand("%"),
							lnum = 1,
							text = rust_msg,
							display = string.format("ERROR[%s]: %s", error_code, rust_msg),
						})
					else
						local warning_code, warning_msg = line:match("^%s*warning%[([^%]]+)%]:%s*(.+)")
						if warning_code and warning_msg then
							table.insert(warnings, {
								filename = vim.fn.expand("%"),
								lnum = 1,
								text = warning_msg,
								display = string.format("WARNING[%s]: %s", warning_code, warning_msg),
							})
						else
							-- Basic warnings without codes
							warning_msg = line:match("^%s*warning:%s*(.+)")
							if warning_msg and not line:match("^%s*warning:%s*%d+ warning") then
								table.insert(warnings, {
									filename = vim.fn.expand("%"),
									lnum = 1,
									text = warning_msg,
									display = "WARNING: " .. warning_msg,
								})
							end
						end
					end
				end

				local cargo_error_patterns = {
					-- Compilation errors
					{ pattern = "^%s*error: could not compile", type = "CARGO-COMPILE-ERROR" },
					{ pattern = "^%s*error: aborting due to", type = "COMPILE-ABORT" },
					{ pattern = "^%s*error: failed to run custom build command", type = "BUILD-SCRIPT-ERROR" },
					{ pattern = "^%s*error: build failed", type = "BUILD-FAILED" },
					{ pattern = "^%s*error: could not document", type = "DOC-GENERATION-ERROR" },

					-- Linker errors
					{ pattern = "^%s*error: linker .* not found", type = "LINKER-NOT-FOUND" },
					{ pattern = "^%s*error: linking with .* failed", type = "LINK-FAILED" },
					{ pattern = "^%s*error: could not find native static library", type = "NATIVE-LIB-NOT-FOUND" },
					{ pattern = "^%s*error: failed to run `rustc`", type = "RUSTC-FAILED" },
					{ pattern = "^%s*error: Microsoft Visual Studio not found", type = "MSVC-NOT-FOUND" },
					{ pattern = "^%s*error: failed to run `link%.exe`", type = "LINK-EXE-FAILED" },

					-- Dependencies and registry errors
					{ pattern = "^%s*error: could not find .* in registry", type = "CRATE-NOT-FOUND" },
					{ pattern = "^%s*error: no matching package named", type = "PACKAGE-NOT-FOUND" },
					{ pattern = "^%s*error: package .* cannot be built", type = "PACKAGE-BUILD-ERROR" },
					{ pattern = "^%s*error: failed to parse lock file", type = "LOCK-FILE-ERROR" },
					{ pattern = "^%s*error: failed to get .* as a dependency", type = "DEPENDENCY-ERROR" },
					{ pattern = "^%s*error: cyclic package dependency", type = "CYCLIC-DEPENDENCY" },
					{ pattern = "^%s*error: failed to load source for dependency", type = "DEPENDENCY-SOURCE-ERROR" },
					{ pattern = "^%s*error: unable to get packages from source", type = "SOURCE-PACKAGES-ERROR" },

					-- Target and platform errors
					{ pattern = "^%s*error: target .* not found", type = "TARGET-NOT-FOUND" },
					{ pattern = "^%s*error: can't find crate for", type = "CRATE-NOT-FOUND-FOR-TARGET" },
					{ pattern = "^%s*error: cannot produce .* for crate", type = "CRATE-TYPE-ERROR" },
					{
						pattern = "^%s*error: cross compilation is not yet supported",
						type = "CROSS-COMPILE-NOT-SUPPORTED",
					},

					-- Workspace and manifest errors
					{ pattern = "^%s*error: failed to parse manifest", type = "MANIFEST-PARSE-ERROR" },
					{ pattern = "^%s*error: could not find `Cargo.toml`", type = "MANIFEST-NOT-FOUND" },
					{ pattern = "^%s*error: workspace member .* is not valid", type = "WORKSPACE-MEMBER-INVALID" },
					{ pattern = "^%s*error: virtual manifests must be configured", type = "VIRTUAL-MANIFEST-ERROR" },
					{
						pattern = "^%s*error: current package believes it's in a workspace",
						type = "WORKSPACE-DETECTION-ERROR",
					},

					-- Feature and version errors
					{ pattern = "^%s*error: feature .* is required", type = "FEATURE-REQUIRED" },
					{
						pattern = "^%s*error: version requirement .* does not match",
						type = "VERSION-REQUIREMENT-ERROR",
					},
					{ pattern = "^%s*error: package .* does not have feature", type = "FEATURE-NOT-FOUND" },
					{ pattern = "^%s*error: unable to find a version", type = "VERSION-RESOLUTION-ERROR" },

					-- Testing and benchmarking errors
					{ pattern = "^%s*error: test failed", type = "TEST-FAILED" },
					{ pattern = "^%s*error: bench failed", type = "BENCH-FAILED" },
					{ pattern = "^%s*error: doctest failed", type = "DOCTEST-FAILED" },

					-- Publication and registry errors
					{ pattern = "^%s*error: failed to publish", type = "PUBLISH-FAILED" },
					{ pattern = "^%s*error: the registry .* does not support", type = "REGISTRY-NOT-SUPPORTED" },
					{ pattern = "^%s*error: authentication required", type = "AUTH-REQUIRED" },

					-- Tool and subcommand errors
					{ pattern = "^%s*error: no such subcommand", type = "UNKNOWN-SUBCOMMAND" },
					{ pattern = "^%s*error: Invalid value .* for", type = "INVALID-ARGUMENT-VALUE" },
					{ pattern = "^%s*error: The argument .* cannot be used with", type = "INCOMPATIBLE-ARGUMENTS" },
					{ pattern = "^%s*error: rustfmt not found", type = "RUSTFMT-NOT-FOUND" },
					{ pattern = "^%s*error: clippy not found", type = "CLIPPY-NOT-FOUND" },
				}

				for _, p in ipairs(cargo_error_patterns) do
					if line:match(p.pattern) then
						table.insert(errors, {
							filename = vim.fn.expand("%"),
							lnum = 1,
							text = line,
							display = p.type .. ": " .. line,
						})
						break
					end
				end

				local panic_patterns = {
					-- Basic panics
					{ pattern = "thread '.*' panicked at", type = "PANIC" },
					{ pattern = "panicked at 'explicit panic", type = "PANIC-EXPLICIT" },
					{ pattern = "panicked at '.*', src/", type = "PANIC-WITH-LOCATION" },

					-- Index and bounds panics
					{ pattern = "panicked at 'index out of bounds", type = "PANIC-INDEX-OUT-OF-BOUNDS" },
					{
						pattern = "panicked at 'range end index .* out of range for slice of length",
						type = "PANIC-RANGE-END-OUT-OF-BOUNDS",
					},
					{
						pattern = "panicked at 'range start index .* out of range for slice of length",
						type = "PANIC-RANGE-START-OUT-OF-BOUNDS",
					},
					{
						pattern = "panicked at 'byte index .* is out of bounds",
						type = "PANIC-BYTE-INDEX-OUT-OF-BOUNDS",
					},
					{
						pattern = "panicked at 'byte index .* is not a char boundary",
						type = "PANIC-BYTE-NOT-CHAR-BOUNDARY",
					},
					{ pattern = "panicked at 'slice index starts at .* but ends at", type = "PANIC-SLICE-INDEX-ORDER" },

					-- Arithmetic panics
					{ pattern = "panicked at 'attempt to add with overflow", type = "PANIC-ADD-OVERFLOW" },
					{ pattern = "panicked at 'attempt to subtract with overflow", type = "PANIC-SUB-OVERFLOW" },
					{ pattern = "panicked at 'attempt to multiply with overflow", type = "PANIC-MUL-OVERFLOW" },
					{ pattern = "panicked at 'attempt to divide by zero", type = "PANIC-DIVIDE-BY-ZERO" },
					{
						pattern = "panicked at 'attempt to calculate the remainder with a divisor of zero",
						type = "PANIC-REMAINDER-BY-ZERO",
					},
					{ pattern = "panicked at 'attempt to negate with overflow", type = "PANIC-NEGATE-OVERFLOW" },
					{
						pattern = "panicked at 'attempt to shift left with overflow",
						type = "PANIC-SHIFT-LEFT-OVERFLOW",
					},
					{
						pattern = "panicked at 'attempt to shift right with overflow",
						type = "PANIC-SHIFT-RIGHT-OVERFLOW",
					},
					{ pattern = "panicked at 'attempt to convert integer", type = "PANIC-INT-CONVERSION-OVERFLOW" },

					-- Option and Result panics
					{ pattern = "panicked at 'called `Option::unwrap%(%)` on a `None`", type = "PANIC-UNWRAP-NONE" },
					{ pattern = "panicked at 'called `Result::unwrap%(%)` on an `Err`", type = "PANIC-UNWRAP-ERR" },
					{ pattern = "panicked at 'called `Option::expect%(%)` on a `None`", type = "PANIC-EXPECT-NONE" },
					{ pattern = "panicked at 'called `Result::expect%(%)` on an `Err`", type = "PANIC-EXPECT-ERR" },
					{
						pattern = "panicked at 'called `Result::unwrap_err%(%)` on an `Ok`",
						type = "PANIC-UNWRAP-ERR-ON-OK",
					},
					{
						pattern = "panicked at 'called `Option::unwrap_or_else%(%)` on a `None`",
						type = "PANIC-UNWRAP-OR-ELSE-NONE",
					},

					-- Assertion panics
					{ pattern = "panicked at 'assertion failed", type = "PANIC-ASSERTION-FAILED" },
					{ pattern = "panicked at 'assertion failed: left == right", type = "PANIC-ASSERT-EQ-FAILED" },
					{ pattern = "panicked at 'assertion failed: left != right", type = "PANIC-ASSERT-NE-FAILED" },
					{ pattern = "panicked at 'debug_assert", type = "PANIC-DEBUG-ASSERT" },

					-- Memory and allocation panics
					{ pattern = "panicked at 'memory allocation of .* bytes failed", type = "PANIC-ALLOCATION-FAILED" },
					{ pattern = "panicked at 'capacity overflow", type = "PANIC-CAPACITY-OVERFLOW" },
					{ pattern = "panicked at 'out of memory", type = "PANIC-OUT-OF-MEMORY" },
					{ pattern = "panicked at 'layout error", type = "PANIC-LAYOUT-ERROR" },

					-- Thread and concurrency panics
					{ pattern = "panicked at 'poison error", type = "PANIC-POISON-ERROR" },
					{ pattern = "panicked at 'attempted to leave a critical section", type = "PANIC-CRITICAL-SECTION" },
					{ pattern = "panicked at 'cannot access a Thread", type = "PANIC-THREAD-ACCESS" },
					{ pattern = "panicked at 'deadlock", type = "PANIC-DEADLOCK" },
					{ pattern = "panicked at 'would block", type = "PANIC-WOULD-BLOCK" },
					{ pattern = "panicked at 'lock poisoned", type = "PANIC-LOCK-POISONED" },
					{ pattern = "panicked at 'channel", type = "PANIC-CHANNEL-ERROR" },
					{ pattern = "panicked at 'receiver disconnected", type = "PANIC-RECEIVER-DISCONNECTED" },

					-- I/O and system panics
					{ pattern = "panicked at 'failed to write whole buffer", type = "PANIC-WRITE-BUFFER" },
					{ pattern = "panicked at 'formatter error", type = "PANIC-FORMATTER-ERROR" },
					{ pattern = "panicked at 'broken pipe", type = "PANIC-BROKEN-PIPE" },
					{ pattern = "panicked at 'No such file or directory", type = "PANIC-FILE-NOT-FOUND" },
					{ pattern = "panicked at 'Permission denied", type = "PANIC-PERMISSION-DENIED" },
					{ pattern = "panicked at 'Connection refused", type = "PANIC-CONNECTION-REFUSED" },
					{ pattern = "panicked at 'timed out", type = "PANIC-TIMEOUT" },

					-- String and UTF-8 panics
					{
						pattern = "panicked at 'called `String::from_utf8%(%)` on an invalid",
						type = "PANIC-INVALID-UTF8",
					},
					{ pattern = "panicked at 'invalid utf%-8 sequence", type = "PANIC-UTF8-SEQUENCE" },
					{ pattern = "panicked at 'incomplete utf%-8 byte sequence", type = "PANIC-INCOMPLETE-UTF8" },
					{ pattern = "panicked at 'string slice index", type = "PANIC-STRING-SLICE-INDEX" },

					-- Collection panics
					{ pattern = "panicked at 'called `Vec::pop%(%)` on an empty vector", type = "PANIC-VEC-POP-EMPTY" },
					{
						pattern = "panicked at 'called `BinaryHeap::pop%(%)` on an empty heap",
						type = "PANIC-HEAP-POP-EMPTY",
					},
					{
						pattern = "panicked at 'called `VecDeque::pop_front%(%)` on an empty deque",
						type = "PANIC-DEQUE-POP-EMPTY",
					},
					{ pattern = "panicked at 'HashMap entry", type = "PANIC-HASHMAP-ENTRY" },
					{ pattern = "panicked at 'BTreeMap entry", type = "PANIC-BTREEMAP-ENTRY" },

					-- Network and async panics
					{ pattern = "panicked at 'async", type = "PANIC-ASYNC" },
					{ pattern = "panicked at 'future", type = "PANIC-FUTURE" },
					{ pattern = "panicked at 'executor", type = "PANIC-EXECUTOR" },
					{ pattern = "panicked at 'runtime", type = "PANIC-RUNTIME" },
					{ pattern = "panicked at 'spawn", type = "PANIC-SPAWN" },

					-- FFI and unsafe panics
					{ pattern = "panicked at 'unsafe", type = "PANIC-UNSAFE" },
					{ pattern = "panicked at 'null pointer", type = "PANIC-NULL-POINTER" },
					{ pattern = "panicked at 'ffi", type = "PANIC-FFI" },
					{ pattern = "panicked at 'C string", type = "PANIC-C-STRING" },
					{ pattern = "panicked at 'OsString", type = "PANIC-OS-STRING" },

					-- Type conversion and parsing panics
					{ pattern = "panicked at 'called `.*::parse%(%)` on", type = "PANIC-PARSE-ERROR" },
					{ pattern = "panicked at 'TryFrom", type = "PANIC-TRY-FROM" },
					{ pattern = "panicked at 'TryInto", type = "PANIC-TRY-INTO" },
					{ pattern = "panicked at 'FromStr", type = "PANIC-FROM-STR" },

					-- Custom panic types
					{ pattern = "panicked at 'not implemented", type = "PANIC-NOT-IMPLEMENTED" },
					{ pattern = "panicked at 'unreachable", type = "PANIC-UNREACHABLE" },
					{ pattern = "panicked at 'todo", type = "PANIC-TODO" },
					{ pattern = "panicked at 'unimplemented", type = "PANIC-UNIMPLEMENTED" },
				}

				for _, p in ipairs(panic_patterns) do
					if line:match(p.pattern) then
						table.insert(errors, {
							filename = vim.fn.expand("%"),
							lnum = 1,
							text = line,
							display = p.type .. ": " .. line,
						})
						break
					end
				end

				local rust_error_patterns = {
					-- Syntax errors
					{ pattern = "expected .*, found", type = "SYNTAX-EXPECTED-TOKEN" },
					{ pattern = "unexpected token", type = "SYNTAX-UNEXPECTED-TOKEN" },
					{ pattern = "unterminated", type = "SYNTAX-UNTERMINATED" },
					{ pattern = "unclosed delimiter", type = "SYNTAX-UNCLOSED-DELIMITER" },
					{ pattern = "mismatched closing delimiter", type = "SYNTAX-MISMATCHED-DELIMITER" },
					{ pattern = "invalid token", type = "SYNTAX-INVALID-TOKEN" },

					-- Borrow checker errors
					{ pattern = "cannot borrow .* as mutable", type = "BORROW-CANNOT-BORROW-MUT" },
					{ pattern = "cannot borrow .* as immutable", type = "BORROW-CANNOT-BORROW-IMMUT" },
					{
						pattern = "borrowed value does not live long enough",
						type = "BORROW-VALUE-NOT-LIVE-LONG-ENOUGH",
					},
					{ pattern = "cannot move out of", type = "BORROW-CANNOT-MOVE-OUT" },
					{ pattern = "use of moved value", type = "BORROW-USE-OF-MOVED-VALUE" },
					{ pattern = "value borrowed here after move", type = "BORROW-BORROWED-AFTER-MOVE" },
					{ pattern = "cannot return reference to", type = "BORROW-CANNOT-RETURN-REFERENCE" },
					{ pattern = "lifetime may not live long enough", type = "LIFETIME-MAY-NOT-LIVE-LONG-ENOUGH" },
					{ pattern = "closure may outlive", type = "LIFETIME-CLOSURE-OUTLIVE" },

					-- Type errors
					{ pattern = "mismatched types", type = "TYPE-MISMATCH" },
					{ pattern = "expected .*, found .*", type = "TYPE-EXPECTED-FOUND" },
					{ pattern = "cannot find .* in this scope", type = "TYPE-NOT-IN-SCOPE" },
					{ pattern = "no method named", type = "TYPE-NO-METHOD" },
					{ pattern = "no field .* on type", type = "TYPE-NO-FIELD" },
					{ pattern = "the trait .* is not implemented", type = "TYPE-TRAIT-NOT-IMPLEMENTED" },
					{ pattern = "type annotations needed", type = "TYPE-ANNOTATIONS-NEEDED" },
					{ pattern = "cannot infer type", type = "TYPE-CANNOT-INFER" },
					{ pattern = "recursive type has infinite size", type = "TYPE-RECURSIVE-INFINITE-SIZE" },

					-- Pattern matching errors
					{ pattern = "pattern .* not covered", type = "PATTERN-NOT-COVERED" },
					{ pattern = "unreachable pattern", type = "PATTERN-UNREACHABLE" },
					{ pattern = "non%-exhaustive patterns", type = "PATTERN-NON-EXHAUSTIVE" },
					{ pattern = "refutable pattern", type = "PATTERN-REFUTABLE" },

					-- Function and method errors
					{
						pattern = "this function takes .* arguments but .* were supplied",
						type = "FUNCTION-WRONG-ARG-COUNT",
					},
					{ pattern = "cannot call non%-const fn", type = "FUNCTION-NON-CONST-CALL" },
					{ pattern = "calls in constant functions are limited", type = "FUNCTION-CONST-LIMITED-CALLS" },
					{ pattern = "cannot return value referencing", type = "FUNCTION-RETURN-REFERENCE" },

					-- Trait and generic errors
					{ pattern = "the trait bound .* is not satisfied", type = "TRAIT-BOUND-NOT-SATISFIED" },
					{ pattern = "type parameter .* must be used", type = "GENERIC-UNUSED-TYPE-PARAM" },
					{ pattern = "unconstrained type parameter", type = "GENERIC-UNCONSTRAINED-TYPE-PARAM" },
					{ pattern = "conflicting implementations", type = "TRAIT-CONFLICTING-IMPL" },
					{ pattern = "coherence", type = "TRAIT-COHERENCE-ERROR" },

					-- Module and visibility errors
					{ pattern = "function .* is private", type = "VISIBILITY-FUNCTION-PRIVATE" },
					{ pattern = "struct .* is private", type = "VISIBILITY-STRUCT-PRIVATE" },
					{ pattern = "field .* is private", type = "VISIBILITY-FIELD-PRIVATE" },
					{ pattern = "module .* is private", type = "VISIBILITY-MODULE-PRIVATE" },
					{ pattern = "unresolved import", type = "MODULE-UNRESOLVED-IMPORT" },
					{ pattern = "maybe a missing", type = "MODULE-MAYBE-MISSING" },

					-- Macro errors
					{ pattern = "macro .* is not defined", type = "MACRO-NOT-DEFINED" },
					{ pattern = "no rules expected", type = "MACRO-NO-RULES-EXPECTED" },
					{ pattern = "unexpected end of macro invocation", type = "MACRO-UNEXPECTED-END" },
					{ pattern = "proc%-macro derive panicked", type = "MACRO-PROC-MACRO-PANIC" },

					-- Unsafe and FFI errors
					{ pattern = "use of unsafe", type = "UNSAFE-USE-OF-UNSAFE" },
					{ pattern = "dereference of raw pointer", type = "UNSAFE-RAW-POINTER-DEREF" },
					{ pattern = "call to unsafe function", type = "UNSAFE-FUNCTION-CALL" },
					{ pattern = "access to union field", type = "UNSAFE-UNION-FIELD-ACCESS" },
					{ pattern = "extern .* fn", type = "FFI-EXTERN-FN-ERROR" },

					-- Attribute and derive errors
					{ pattern = "attribute .* is currently unknown", type = "ATTRIBUTE-UNKNOWN" },
					{ pattern = "derive .* cannot be applied", type = "DERIVE-CANNOT-BE-APPLIED" },
					{ pattern = "custom derive", type = "DERIVE-CUSTOM-ERROR" },

					-- Const and static errors
					{ pattern = "const fn", type = "CONST-FN-ERROR" },
					{ pattern = "constant evaluation", type = "CONST-EVAL-ERROR" },
					{ pattern = "static .* contains", type = "STATIC-CONTAINS-ERROR" },
					{ pattern = "cannot mutate statics", type = "STATIC-CANNOT-MUTATE" },

					-- Feature gate errors
					{ pattern = "feature .* is unstable", type = "FEATURE-UNSTABLE" },
					{ pattern = "use of unstable", type = "FEATURE-USE-OF-UNSTABLE" },
					{ pattern = "experimental", type = "FEATURE-EXPERIMENTAL" },

					-- Target-specific errors
					{ pattern = "linking with .* failed", type = "TARGET-LINKING-FAILED" },
					{ pattern = "target feature", type = "TARGET-FEATURE-ERROR" },
					{ pattern = "inline assembly", type = "TARGET-ASM-ERROR" },
				}

				for _, p in ipairs(rust_error_patterns) do
					if line:match(p.pattern) then
						table.insert(errors, {
							filename = vim.fn.expand("%"),
							lnum = 1,
							text = line,
							display = p.type .. ": " .. line,
						})
						break
					end
				end

				local rust_warning_patterns = {
					-- Unused code warnings
					{ pattern = "unused variable", type = "WARNING-UNUSED-VAR" },
					{ pattern = "unused function", type = "WARNING-UNUSED-FUNC" },
					{ pattern = "unused import", type = "WARNING-UNUSED-IMPORT" },
					{ pattern = "unused extern crate", type = "WARNING-UNUSED-EXTERN-CRATE" },
					{ pattern = "unused macro", type = "WARNING-UNUSED-MACRO" },
					{ pattern = "unused attribute", type = "WARNING-UNUSED-ATTRIBUTE" },
					{ pattern = "unused struct", type = "WARNING-UNUSED-STRUCT" },
					{ pattern = "unused enum", type = "WARNING-UNUSED-ENUM" },
					{ pattern = "unused type alias", type = "WARNING-UNUSED-TYPE-ALIAS" },
					{ pattern = "unused const", type = "WARNING-UNUSED-CONST" },
					{ pattern = "unused static", type = "WARNING-UNUSED-STATIC" },
					{ pattern = "unused mut", type = "WARNING-UNUSED-MUT" },
					{ pattern = "unused unsafe", type = "WARNING-UNUSED-UNSAFE" },
					{ pattern = "unused label", type = "WARNING-UNUSED-LABEL" },
					{ pattern = "unused lifetime", type = "WARNING-UNUSED-LIFETIME" },
					{ pattern = "unused generic parameter", type = "WARNING-UNUSED-GENERIC-PARAM" },
					{ pattern = "unused result", type = "WARNING-UNUSED-RESULT" },
					{ pattern = "unused must_use", type = "WARNING-UNUSED-MUST-USE" },
					{ pattern = "unused braces", type = "WARNING-UNUSED-BRACES" },
					{ pattern = "unused parens", type = "WARNING-UNUSED-PARENS" },
					{ pattern = "unused allocation", type = "WARNING-UNUSED-ALLOCATION" },
					{ pattern = "unused doc comment", type = "WARNING-UNUSED-DOC-COMMENT" },

					-- Deprecated warnings
					{ pattern = "use of deprecated", type = "WARNING-DEPRECATED" },
					{ pattern = "deprecated attribute", type = "WARNING-DEPRECATED-ATTRIBUTE" },
					{ pattern = "deprecated function", type = "WARNING-DEPRECATED-FUNCTION" },
					{ pattern = "deprecated method", type = "WARNING-DEPRECATED-METHOD" },
					{ pattern = "deprecated struct", type = "WARNING-DEPRECATED-STRUCT" },
					{ pattern = "deprecated enum", type = "WARNING-DEPRECATED-ENUM" },
					{ pattern = "deprecated macro", type = "WARNING-DEPRECATED-MACRO" },

					-- Style and naming warnings
					{ pattern = "should have a snake_case name", type = "WARNING-SNAKE-CASE" },
					{ pattern = "should have a PascalCase name", type = "WARNING-PASCAL-CASE" },
					{ pattern = "should have an upper_case name", type = "WARNING-UPPER-CASE" },
					{ pattern = "non_camel_case_types", type = "WARNING-NON-CAMEL-CASE-TYPES" },
					{ pattern = "non_snake_case", type = "WARNING-NON-SNAKE-CASE" },
					{ pattern = "non_upper_case_globals", type = "WARNING-NON-UPPER-CASE-GLOBALS" },
					{ pattern = "should start with a lowercase letter", type = "WARNING-CASE-START-LOWERCASE" },
					{ pattern = "should start with an uppercase letter", type = "WARNING-CASE-START-UPPERCASE" },

					-- Code quality warnings
					{ pattern = "redundant semicolon", type = "WARNING-REDUNDANT-SEMICOLON" },
					{ pattern = "unnecessary parentheses", type = "WARNING-UNNECESSARY-PARENS" },
					{ pattern = "redundant clone", type = "WARNING-REDUNDANT-CLONE" },
					{ pattern = "needless pass by value", type = "WARNING-NEEDLESS-PASS-BY-VALUE" },
					{ pattern = "single character pattern", type = "WARNING-SINGLE-CHAR-PATTERN" },
					{ pattern = "needless return", type = "WARNING-NEEDLESS-RETURN" },
					{ pattern = "redundant closure", type = "WARNING-REDUNDANT-CLOSURE" },
					{ pattern = "redundant field names", type = "WARNING-REDUNDANT-FIELD-NAMES" },
					{ pattern = "redundant static lifetimes", type = "WARNING-REDUNDANT-STATIC-LIFETIMES" },
					{ pattern = "identity op", type = "WARNING-IDENTITY-OP" },
					{ pattern = "zero width space", type = "WARNING-ZERO-WIDTH-SPACE" },
					{ pattern = "invisible character", type = "WARNING-INVISIBLE-CHARACTER" },
					{ pattern = "mixed script confusables", type = "WARNING-CONFUSABLE-IDENTS" },

					-- Performance warnings
					{ pattern = "large enum variant", type = "WARNING-LARGE-ENUM-VARIANT" },
					{ pattern = "large stack frame", type = "WARNING-LARGE-STACK-FRAME" },
					{ pattern = "expensive computation", type = "WARNING-EXPENSIVE-COMPUTATION" },
					{ pattern = "needless collect", type = "WARNING-NEEDLESS-COLLECT" },
					{ pattern = "loop could be written as", type = "WARNING-LOOP-COULD-BE-WRITTEN" },
					{ pattern = "string concatenation", type = "WARNING-STRING-CONCAT" },

					-- Documentation warnings
					{ pattern = "missing docs", type = "WARNING-MISSING-DOCS" },
					{ pattern = "intra doc link", type = "WARNING-INTRA-DOC-LINK" },
					{ pattern = "broken intra doc link", type = "WARNING-BROKEN-INTRA-DOC-LINK" },
					{ pattern = "private doc test", type = "WARNING-PRIVATE-DOC-TEST" },
					{ pattern = "doc test .* failed", type = "WARNING-DOC-TEST-FAILED" },

					-- Unsafe code warnings
					{ pattern = "unsafe code", type = "WARNING-UNSAFE-CODE" },
					{ pattern = "unsafe block", type = "WARNING-UNSAFE-BLOCK" },
					{ pattern = "unsafe function", type = "WARNING-UNSAFE-FUNCTION" },
					{ pattern = "unsafe trait", type = "WARNING-UNSAFE-TRAIT" },
					{ pattern = "unsafe impl", type = "WARNING-UNSAFE-IMPL" },

					-- Clippy warnings
					{ pattern = "clippy::", type = "WARNING-CLIPPY" },
					{ pattern = "should implement trait", type = "WARNING-SHOULD-IMPLEMENT-TRAIT" },
					{ pattern = "consider using", type = "WARNING-CONSIDER-USING" },
					{ pattern = "this could be written more concisely", type = "WARNING-COULD-BE-CONCISE" },
					{ pattern = "unnecessary mut", type = "WARNING-UNNECESSARY-MUT" },
					{ pattern = "explicit counter loop", type = "WARNING-EXPLICIT-COUNTER-LOOP" },
					{ pattern = "manual implementation", type = "WARNING-MANUAL-IMPLEMENTATION" },
					{ pattern = "use of .unwrap%()", type = "WARNING-USE-OF-UNWRAP" },
					{ pattern = "use of .expect%()", type = "WARNING-USE-OF-EXPECT" },
					{ pattern = "you should consider", type = "WARNING-YOU-SHOULD-CONSIDER" },

					-- Edition and compatibility warnings
					{ pattern = "edition idiom", type = "WARNING-EDITION-IDIOM" },
					{ pattern = "rust 2018 idiom", type = "WARNING-RUST-2018-IDIOM" },
					{ pattern = "rust 2021 idiom", type = "WARNING-RUST-2021-IDIOM" },
					{ pattern = "keyword .* is reserved", type = "WARNING-RESERVED-KEYWORD" },

					-- Feature and stability warnings
					{ pattern = "feature .* is deprecated", type = "WARNING-FEATURE-DEPRECATED" },
					{ pattern = "unstable feature", type = "WARNING-UNSTABLE-FEATURE" },
					{ pattern = "experimental feature", type = "WARNING-EXPERIMENTAL-FEATURE" },

					-- Import and extern warnings
					{ pattern = "unused qualifications", type = "WARNING-UNUSED-QUALIFICATIONS" },
					{ pattern = "ambiguous glob reexports", type = "WARNING-AMBIGUOUS-GLOB-REEXPORTS" },
					{ pattern = "hidden glob reexports", type = "WARNING-HIDDEN-GLOB-REEXPORTS" },
					{ pattern = "extern crate .* is required", type = "WARNING-EXTERN-CRATE-REQUIRED" },

					-- Type and trait warnings
					{ pattern = "trait objects without an explicit", type = "WARNING-TRAIT-OBJECTS-NO-EXPLICIT" },
					{ pattern = "bare trait objects", type = "WARNING-BARE-TRAIT-OBJECTS" },
					{ pattern = "elided lifetime", type = "WARNING-ELIDED-LIFETIME" },
					{ pattern = "anonymous lifetime", type = "WARNING-ANONYMOUS-LIFETIME" },
					{ pattern = "single use lifetimes", type = "WARNING-SINGLE-USE-LIFETIMES" },
					{ pattern = "trivial bounds", type = "WARNING-TRIVIAL-BOUNDS" },
					{ pattern = "where clauses", type = "WARNING-WHERE-CLAUSES" },

					-- Pattern matching warnings
					{ pattern = "irrefutable let pattern", type = "WARNING-IRREFUTABLE-LET-PATTERN" },
					{ pattern = "overlapping range", type = "WARNING-OVERLAPPING-RANGE" },
					{ pattern = "bindings with variant name", type = "WARNING-BINDINGS-VARIANT-NAME" },

					-- Macro and procedural macro warnings
					{ pattern = "macro expanded", type = "WARNING-MACRO-EXPANDED" },
					{ pattern = "proc macro", type = "WARNING-PROC-MACRO" },
					{ pattern = "derive helper", type = "WARNING-DERIVE-HELPER" },

					-- Testing warnings
					{ pattern = "test .* ignored", type = "WARNING-TEST-IGNORED" },
					{ pattern = "bench .* ignored", type = "WARNING-BENCH-IGNORED" },
					{ pattern = "should_panic", type = "WARNING-SHOULD-PANIC" },
				}

				for _, p in ipairs(rust_warning_patterns) do
					if line:match(p.pattern) then
						table.insert(warnings, {
							filename = vim.fn.expand("%"),
							lnum = 1,
							text = line,
							display = p.type .. ": " .. line,
						})
						break
					end
				end

				local test_patterns = {
					-- Test results
					{ pattern = "^test .* %... ok$", type = "TEST-PASSED", severity = "info" },
					{ pattern = "^test .* %... FAILED$", type = "TEST-FAILED", severity = "error" },
					{ pattern = "^test .* %... ignored$", type = "TEST-IGNORED", severity = "warning" },
					{ pattern = "^test .* %... bench:", type = "BENCH-RESULT", severity = "info" },

					-- Test failures with location
					{ pattern = "^---- .* stdout %-%-%-%-$", type = "TEST-OUTPUT-START", severity = "info" },
					{
						pattern = "^thread .* panicked at .*src/.*%.rs:%d+",
						type = "TEST-PANIC-WITH-LOCATION",
						severity = "error",
					},
					{ pattern = "^assertion failed:", type = "TEST-ASSERTION-FAILED", severity = "error" },
					{ pattern = "^left: .*", type = "TEST-ASSERTION-LEFT", severity = "error" },
					{ pattern = "^right: .*", type = "TEST-ASSERTION-RIGHT", severity = "error" },

					-- Test summary
					{ pattern = "^test result:", type = "TEST-SUMMARY", severity = "info" },
					{ pattern = "%d+ passed; %d+ failed", type = "TEST-RESULT-SUMMARY", severity = "info" },

					-- Doctest patterns
					{ pattern = "^Doc%-tests", type = "DOCTEST-START", severity = "info" },
					{ pattern = "doctest failed", type = "DOCTEST-FAILED", severity = "error" },
				}

				for _, p in ipairs(test_patterns) do
					if line:match(p.pattern) then
						local target_table = (p.severity == "error") and errors or warnings
						table.insert(target_table, {
							filename = vim.fn.expand("%"),
							lnum = 1,
							text = line,
							display = p.type .. ": " .. line,
						})
						break
					end
				end

				local runtime_error_patterns = {
					-- MIRI (Rust interpreter for detecting undefined behavior)
					{ pattern = "error: Undefined Behavior", type = "MIRI-UNDEFINED-BEHAVIOR" },
					{ pattern = "error: dereferencing pointer failed", type = "MIRI-DEREF-FAILED" },
					{ pattern = "error: memory access failed", type = "MIRI-MEMORY-ACCESS-FAILED" },
					{ pattern = "error: invalid use of NULL pointer", type = "MIRI-NULL-POINTER-USE" },
					{ pattern = "error: accessing memory based on pointer", type = "MIRI-POINTER-BASED-ACCESS" },
					{ pattern = "error: deallocating while item is protected", type = "MIRI-DEALLOC-PROTECTED" },
					{ pattern = "error: using uninitialized data", type = "MIRI-UNINITIALIZED-DATA" },
					{ pattern = "error: data race", type = "MIRI-DATA-RACE" },
					{ pattern = "error: race condition", type = "MIRI-RACE-CONDITION" },

					-- Stack traces with file info
					{ pattern = "^%s*at ([^:]+%.rs):(%d+):%d+", type = "STACK-TRACE-WITH-LOCATION" },
					{ pattern = "^%s*%d+: ([^:]+%.rs):(%d+)", type = "NUMBERED-STACK-TRACE" },

					-- Memory errors
					{ pattern = "stack overflow", type = "STACK-OVERFLOW" },
					{ pattern = "heap overflow", type = "HEAP-OVERFLOW" },
					{ pattern = "double free", type = "DOUBLE-FREE" },
					{ pattern = "use after free", type = "USE-AFTER-FREE" },
					{ pattern = "buffer overflow", type = "BUFFER-OVERFLOW" },
					{ pattern = "memory leak", type = "MEMORY-LEAK" },

					-- Async runtime errors
					{ pattern = "blocking call in async context", type = "ASYNC-BLOCKING-CALL" },
					{ pattern = "async runtime error", type = "ASYNC-RUNTIME-ERROR" },
					{ pattern = "executor error", type = "EXECUTOR-ERROR" },
					{ pattern = "future error", type = "FUTURE-ERROR" },
					{ pattern = "task error", type = "TASK-ERROR" },
				}

				for _, p in ipairs(runtime_error_patterns) do
					if line:match(p.pattern) then
						local rust_file, rust_line_num = line:match("^%s*at ([^:]+%.rs):(%d+):%d+")
						if not rust_file then
							rust_file, rust_line_num = line:match("^%s*%d+: ([^:]+%.rs):(%d+)")
						end

						table.insert(errors, {
							filename = rust_file or vim.fn.expand("%"),
							lnum = rust_line_num and tonumber(rust_line_num) or 1,
							text = line,
							display = p.type .. ": " .. line,
						})
						break
					end
				end

				local linter_patterns = {
					-- Clippy specific lints
					{ pattern = "clippy::complexity", type = "CLIPPY-COMPLEXITY" },
					{ pattern = "clippy::correctness", type = "CLIPPY-CORRECTNESS" },
					{ pattern = "clippy::style", type = "CLIPPY-STYLE" },
					{ pattern = "clippy::pedantic", type = "CLIPPY-PEDANTIC" },
					{ pattern = "clippy::perf", type = "CLIPPY-PERFORMANCE" },
					{ pattern = "clippy::cargo", type = "CLIPPY-CARGO" },
					{ pattern = "clippy::nursery", type = "CLIPPY-NURSERY" },
					{ pattern = "clippy::restriction", type = "CLIPPY-RESTRICTION" },

					-- Rustfmt issues
					{ pattern = "rustfmt failed", type = "RUSTFMT-FAILED" },
					{ pattern = "formatting error", type = "RUSTFMT-ERROR" },
					{ pattern = "parse error while formatting", type = "RUSTFMT-PARSE-ERROR" },

					-- Other tools
					{ pattern = "cargo audit", type = "CARGO-AUDIT" },
					{ pattern = "security advisory", type = "SECURITY-ADVISORY" },
					{ pattern = "vulnerability", type = "VULNERABILITY" },
					{ pattern = "cargo outdated", type = "CARGO-OUTDATED" },
					{ pattern = "dependency update", type = "DEPENDENCY-UPDATE" },
				}

				for _, p in ipairs(linter_patterns) do
					if line:match(p.pattern) then
						table.insert(warnings, {
							filename = vim.fn.expand("%"),
							lnum = 1,
							text = line,
							display = p.type .. ": " .. line,
						})
						break
					end
				end
			else
				-- Generic fallback for other filetypes
				file, line_num, msg = line:match("([^:]+):(%d+):%s*(.+)")
				if file and line_num and msg then
					local item = {
						filename = file,
						lnum = tonumber(line_num),
						text = msg,
						display = string.format("%s:%s: %s", vim.fn.fnamemodify(file, ":t"), line_num, msg),
					}

					local error_keywords = {
						"error",
						"fatal",
						"exception",
						"fail",
						"abort",
						"crash",
						"segmentation fault",
						"segfault",
						"assertion",
						"panic",
					}
					local warning_keywords = {
						"warning",
						"warn",
						"caution",
						"note",
						"info",
						"deprecated",
					}

					local is_error = false
					local is_warning = false

					for _, keyword in ipairs(error_keywords) do
						if msg:lower():match(keyword) then
							is_error = true
							break
						end
					end

					if not is_error then
						for _, keyword in ipairs(warning_keywords) do
							if msg:lower():match(keyword) then
								is_warning = true
								break
							end
						end
					end

					if is_error then
						table.insert(errors, item)
					elseif is_warning then
						table.insert(warnings, item)
					else
						-- Default to error for unrecognized patterns
						table.insert(errors, item)
					end
				else
					-- Generic error/warning detection for lines without file:line format
					local error_keywords = {
						"error",
						"fatal",
						"exception",
						"fail",
						"abort",
						"crash",
						"segmentation fault",
						"segfault",
						"assertion",
						"panic",
						"stack trace",
					}
					local warning_keywords = {
						"warning",
						"warn",
						"caution",
						"note",
						"info",
						"deprecated",
					}

					local found_error = false
					for _, keyword in ipairs(error_keywords) do
						if line:lower():match(keyword) then
							table.insert(errors, {
								filename = vim.fn.expand("%"),
								lnum = 1,
								text = line,
								display = "ERROR: " .. line,
							})
							found_error = true
							break
						end
					end

					if not found_error then
						for _, keyword in ipairs(warning_keywords) do
							if line:lower():match(keyword) then
								table.insert(warnings, {
									filename = vim.fn.expand("%"),
									lnum = 1,
									text = line,
									display = "WARNING: " .. line,
								})
								break
							end
						end
					end
				end
			end
		end
	end

	return errors, warnings
end

return M
