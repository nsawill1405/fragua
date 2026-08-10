local TestRunner = require("./TestRunner")

TestRunner.run({
	InteractionMath = require("./InteractionMath.spec"),
	TypeDraft = require("./TypeDraft.spec"),
	SchemaMigration = require("./SchemaMigration.spec"),
	DocumentStore = require("./DocumentStore.spec"),
	CompletionEngine = require("./CompletionEngine.spec"),
	Diagnostics = require("./Diagnostics.spec"),
	ColorText = require("./ColorText.spec"),
	EditorLayout = require("./EditorLayout.spec"),
})
