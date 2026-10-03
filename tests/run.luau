-- Test runner: `lune run tests/run.luau [filter]` from the repository root.
-- Runs every tests/specs/*.spec.luau file. Specs receive a context table with helpers.

local fs = require("@lune/fs")
local process = require("@lune/process")
local luau = require("@lune/luau")

local Loader = require("./harness/Loader")
local RobloxEnv = require("./harness/RobloxEnv")
Loader.Scan()

local filter = process.args[1]

local results = { passed = 0, failed = 0, failures = {} }

local function makeContext(specName)
	local ctx = {}
	ctx.tests = {}
	function ctx.test(name, fn)
		table.insert(ctx.tests, { name = name, fn = fn })
	end
	function ctx.expect(condition, message, ...)
		if not condition then
			error(string.format(message or "expectation failed", ...), 2)
		end
	end
	function ctx.near(a, b, epsilon, message)
		if math.abs(a - b) > (epsilon or 1e-6) then
			error(
				string.format(
					"%s: expected %s ~= %s (eps %s)",
					message or "near",
					tostring(a),
					tostring(b),
					tostring(epsilon)
				),
				2
			)
		end
	end
	ctx.require = Loader.Require
	ctx.globals = Loader.Globals
	ctx.Loader = Loader
	ctx.RobloxEnv = RobloxEnv
	ctx.log = function(...)
		print("    [" .. specName .. "]", ...)
	end
	return ctx
end

local specFiles = fs.readDir("tests/specs")
table.sort(specFiles)

for _, file in specFiles do
	if string.match(file, "%.spec%.luau$") and (not filter or string.find(file, filter, 1, true)) then
		local specName = string.gsub(file, "%.spec%.luau$", "")
		local ctx = makeContext(specName)
		local source = fs.readFile("tests/specs/" .. file)
		local chunk = luau.load(source, {
			debugName = file,
			environment = (function()
				local env = table.clone(Loader.Globals)
				env.ctx = ctx
				return env
			end)(),
		})
		local loaded, loadError = pcall(chunk)
		if not loaded then
			results.failed += 1
			table.insert(results.failures, { spec = specName, name = "<load>", err = tostring(loadError) })
			print("✗ " .. specName .. " failed to load: " .. tostring(loadError))
		else
			print("● " .. specName)
			for _, t in ctx.tests do
				local started = os.clock()
				local ok, err = pcall(t.fn)
				local elapsed = os.clock() - started
				if ok then
					results.passed += 1
					print(string.format("  ✓ %s (%.2fs)", t.name, elapsed))
				else
					results.failed += 1
					table.insert(results.failures, { spec = specName, name = t.name, err = tostring(err) })
					print(string.format("  ✗ %s\n      %s", t.name, tostring(err)))
				end
			end
		end
	end
end

print(string.format("\n%d passed, %d failed", results.passed, results.failed))
if results.failed > 0 then
	process.exit(1)
end
