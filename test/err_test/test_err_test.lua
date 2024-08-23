local PATH = ... and (...):match("(.-)[^%.]+$") or ""


local errTest = require(PATH .. "err_test")
local strict = require(PATH .. "test.lib.strict")


local function dummyAlwaysError()
	error("This function intentionally raises an error.")
end

local function dummyOK()
	return true
end
local function dummyNotOK()
	return false, "This function intentionally returns false + this string."
end


-- The verbosity of the main tester object.
local cli_verbosity
for i = 0, #arg do
	if arg[i] == "--verbosity" then
		cli_verbosity = tonumber(arg[i + 1])
		if not cli_verbosity then
			error("invalid verbosity value")
		end
	end
end


-- The verbosity of the tester instances being tested.
local sub_ver = 0


local self = errTest.new("errTest self-test", cli_verbosity)
local _mt_test = getmetatable(errTest.new("tester"))


-- [===[
self:registerFunction("errTest.new()", errTest.new)

self:registerJob("errTest.new()", function(self)
	self:expectLuaError("arg #1 bad type", errTest.new, {})
	self:expectLuaError("arg #2 bad type", errTest.new, "foobar", "oops")

	self:expectLuaReturn("arg #1 nil description is OK", errTest.new)
	self:expectLuaReturn("arg #2 any verbosity number is permitted", errTest.new, "foobar", -5)
end
)
--]===]


-- [===[
self:registerFunction("Tester:registerFunction()", _mt_test.registerFunction)

self:registerJob("Tester:registerFunction()", function(self)
	do
		local tester = errTest.new("tester", sub_ver)
		self:expectLuaError("arg #1 bad type", _mt_test.registerFunction, tester, {}, function() end)
		self:expectLuaError("arg #2 bad type", _mt_test.registerFunction, tester, "foo", "oops")

		self:expectLuaReturn("arg #1 nil description is OK", _mt_test.registerFunction, tester, nil, function() end)
	end
end
)
--]===]

-- [===[
self:registerFunction("Tester:registerJob()", _mt_test.registerJob)

self:registerJob("Tester:registerJob()", function(self)
	do
		local tester = errTest.new("tester", sub_ver)
		self:expectLuaError("arg #1 bad type", _mt_test.registerJob, tester, {}, function() end)
		self:expectLuaError("arg #2 bad type", _mt_test.registerJob, tester, "foo", "oops")
	end

	do
		local tester = errTest.new("tester", sub_ver)
		local dupe = function() end
		tester:registerJob("first job", dupe)
		self:expectLuaError("attempt to add dupe job", _mt_test.registerJob, tester, "dupe job", dupe)
	end

	do
		local tester = errTest.new("tester", sub_ver)
		self:expectLuaReturn("arg #1 nil description is OK", _mt_test.registerJob, tester, nil, function() end)
	end
end
)
--]===]


-- [===[
self:registerFunction("Tester:runJobs()", _mt_test.runJobs)

self:registerJob("Tester:runJobs()", function(self)
	do
		local tester = errTest.new("tester", sub_ver)
		local dupe = function() end
		tester.jobs = {
			{"dupe1", dupe},
			{"dupe2", dupe},
		}
		self:expectLuaError("attempt to run the same job function twice", _mt_test.runJobs, tester)
	end

	do
		local tester = errTest.new("tester", sub_ver)
		tester.jobs = {
			{"func1", function() end},
			{"missing_function"},
		}
		self:expectLuaError("missing function in job table", _mt_test.runJobs, tester)
	end
end
)
--]===]


-- skip Tester:print(), Tester:write(), Tester:warn() and Tester:lf().


-- [===[
self:registerFunction("Tester:expectLuaReturn()", _mt_test.expectLuaReturn)

self:registerJob("Tester:expectLuaReturn()", function(self)
	do
		local tester = errTest.new("tester", sub_ver)
		self:expectLuaError("arg #1 bad type", _mt_test.expectLuaReturn, tester, {}, function() end)
		self:expectLuaError("arg #2 bad type", _mt_test.expectLuaReturn, tester, "foo", "oops")

		self:expectLuaReturn("expect return", _mt_test.expectLuaReturn, tester, "success", dummyOK)
		local a,b,c,d,e,f,g = self:expectLuaReturn("expect six return values", _mt_test.expectLuaReturn, tester, "retvals", function() return 1, 2, 3, 4, 5, 6 end)
		self:isEqual(a, 1)
		self:isEqual(b, 2)
		self:isEqual(c, 3)
		self:isEqual(d, 4)
		self:isEqual(e, 5)
		self:isEqual(f, 6)
		self:isEqual(g, nil)
	end
end
)
--]===]


-- [===[
self:registerFunction("Tester:expectLuaError()", _mt_test.expectLuaError)

self:registerJob("Tester:expectLuaError()", function(self)
	do
		local tester = errTest.new("tester", sub_ver)

		self:expectLuaError("arg #1 bad type", _mt_test.expectLuaError, tester, {}, function() end)
		self:expectLuaError("arg #2 bad type", _mt_test.expectLuaError, tester, "foo", "oops")

		self:expectLuaReturn("expect return", _mt_test.expectLuaError, tester, "success", dummyAlwaysError)

		self:expectLuaError("unexpected return", _mt_test.expectLuaError, tester, "unexpected return", function() return 1, 2, 3, 4, 5, 6 end)
	end
end
)
--]===]


-- [===[
self:registerFunction("Tester:isEqual()", _mt_test.isEqual)
self:registerFunction("Tester:isNotEqual()", _mt_test.isNotEqual)
self:registerFunction("Tester:isBoolTrue()", _mt_test.isBoolTrue)
self:registerFunction("Tester:isBoolFalse()", _mt_test.isBoolFalse)
self:registerFunction("Tester:isEvalTrue()", _mt_test.isEvalTrue)
self:registerFunction("Tester:isEvalFalse()", _mt_test.isEvalFalse)
self:registerFunction("Tester:isNil()", _mt_test.isNil)
self:registerFunction("Tester:isNotNil()", _mt_test.isNotNil)
self:registerFunction("Tester:isNan()", _mt_test.isNan)
self:registerFunction("Tester:isNotNan()", _mt_test.isNotNan)
self:registerFunction("Tester:isType()", _mt_test.isType)
self:registerFunction("Tester:isNotType()", _mt_test.isNotType)

self:registerJob("Tester: <various assertion methods>", function(self)
	do
		local tester = errTest.new("tester", sub_ver)

		self:expectLuaError("a ~= b", _mt_test.isEqual, tester, 1, 2)
		self:expectLuaReturn("a == b", _mt_test.isEqual, tester, 1, 1)

		self:expectLuaError("a == b", _mt_test.isNotEqual, tester, 1, 1)
		self:expectLuaReturn("a ~= b", _mt_test.isNotEqual, tester, 1, 2)

		self:expectLuaError("a ~= true", _mt_test.isBoolTrue, tester, false)
		self:expectLuaReturn("a == true", _mt_test.isBoolTrue, tester, true)

		self:expectLuaError("a ~= false", _mt_test.isBoolFalse, tester, true)
		self:expectLuaReturn("a == false", _mt_test.isBoolFalse, tester, false)

		self:expectLuaError("a == false", _mt_test.isEvalTrue, tester, false)
		self:expectLuaError("a == nil", _mt_test.isEvalTrue, tester, nil)
		self:expectLuaReturn("a ~= false and a ~= nil", _mt_test.isEvalTrue, tester, true)

		self:expectLuaError("a ~= false and a ~= nil", _mt_test.isEvalFalse, tester, true)
		self:expectLuaReturn("a == nil", _mt_test.isEvalFalse, tester, nil)
		self:expectLuaReturn("a == false", _mt_test.isEvalFalse, tester, false)

		self:expectLuaError("a ~= nil", _mt_test.isNil, tester, 1)
		self:expectLuaReturn("a == nil", _mt_test.isNil, tester, nil)

		self:expectLuaError("a == nil", _mt_test.isNotNil, tester, nil)
		self:expectLuaReturn("a ~= nil", _mt_test.isNotNil, tester, 1)

		self:expectLuaError("a == a", _mt_test.isNan, tester, 0, 0)
		self:expectLuaReturn("a ~= a", _mt_test.isNan, tester, 0/0, 0/0)

		self:expectLuaError("a ~= a", _mt_test.isNotNan, tester, 0/0, 0/0)
		self:expectLuaReturn("a == a", _mt_test.isNotNan, tester, 0, 0)

		self:expectLuaError("#2 bad type", _mt_test.isType, tester, "foo", function() end)
		self:expectLuaError("type not in arg #2", _mt_test.isType, tester, "foo", "nil/number/table/userdata")
		self:expectLuaReturn("type is in arg #2", _mt_test.isType, tester, "foo", "number/string")

		self:expectLuaError("#2 bad type", _mt_test.isNotType, tester, "foo", function() end)
		self:expectLuaError("type is in arg #2", _mt_test.isNotType, tester, "foo", "number/string")
		self:expectLuaReturn("type not in arg #2", _mt_test.isNotType, tester, "foo", "nil/number/table/userdata")
	end
end
)
--]===]


self:runJobs()
