# errTest Changelog

# v2.1.1 2024-JUL-04
* Changed `Tester:expectLuaReturn()` to return the first six return values provided by `pcall()`. Previously, it returned `pcall()`'s first argument (indicating success of the call) -- which is unnecessary in this context -- and the first return value only.
* Changed `Tester:expectLuaError()` to return just the error string dispatched by `pcall()`, or the first six return values if `pcall()` is successful. Previously, it returned `pcall()`'s first argument (indicating failure of the call), which is unnecessary in this context.


# v2.1.0 2024-JUL-03

* errTest now halts if a job raises a Lua error. In the event of a failed job, it's easier to see the error and stack trace immediately, rather than have to dig through the output of a dozen or so tests to find the one part that exploded.
* Removed `Tester:allGood()`; a test is considered passed if it did not raise a Lua error.
* Changed output formatting of tests.
* Changed built-in assertions to print messages before running the assertion, rather than afterwards upon success.
* Added `--verbosity <n>` CLI argument to `test_err_test.lua`.
* Added `self:lf()`.


# v2.0.0 2024-MAY-20

* This is a major overhaul from v1.0.0. There are so many differences that I wanted to move it to a new repo (ie errTest2), but it's probably better to keep the project's Git history and repo name + URL.
