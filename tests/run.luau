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
	SyntaxHighlighter = require("./SyntaxHighlighter.spec"),
	PreviewCommit = require("./PreviewCommit.spec"),
	PropertyRefreshPolicy = require("./PropertyRefreshPolicy.spec"),
	SchemaResolver = require("./SchemaResolver.spec"),
	TypeEditorLayout = require("./TypeEditorLayout.spec"),
	InsertFlow = require("./InsertFlow.spec"),
	IconData = require("./IconData.spec"),
	EnginePropResolver = require("./EnginePropResolver.spec"),
	ScriptHeader = require("./ScriptHeader.spec"),
	TypeCatalog = require("./TypeCatalog.spec"),
})
