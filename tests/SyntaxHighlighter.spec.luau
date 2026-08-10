local SyntaxHighlighter = require("../src/App/ScriptEditor/SyntaxHighlighter")

return {
	["escapes RichText before coloring"] = function()
		local out = SyntaxHighlighter.render('local x = "<tag>&"', { schema = {}, typeIds = {} })
		assert(out:find("&lt;tag&gt;&amp;", 1, true), out)
	end,
	["colors comments strings numbers and keywords"] = function()
		local out = SyntaxHighlighter.render("local hp = 100 -- value", { schema = {}, typeIds = {} })
		assert(out:find('color="#C586C0"', 1, true), out)
		assert(out:find('color="#B5CEA8"', 1, true), out)
		assert(out:find('color="#6A9955"', 1, true), out)
	end,
	["colors custom types and schema properties"] = function()
		local out = SyntaxHighlighter.render('Fragua.create("Zombie"):SetAttribute("Health", 90)', {
			typeIds = { "Zombie" },
			schema = { { name = "Health" } },
		})
		assert(out:find('color="#4EC9B0"', 1, true), out)
		assert(out:find('color="#9CDCFE"', 1, true), out)
	end,
}
