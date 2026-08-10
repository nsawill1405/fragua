local TestRunner = require("./TestRunner")

TestRunner.run({
	InteractionMath = require("./InteractionMath.spec"),
	TypeDraft = require("./TypeDraft.spec"),
	SchemaMigration = require("./SchemaMigration.spec"),
	ColorText = require("./ColorText.spec"),
	PreviewCommit = require("./PreviewCommit.spec"),
	PropertyRefreshPolicy = require("./PropertyRefreshPolicy.spec"),
	SchemaResolver = require("./SchemaResolver.spec"),
	TypeEditorLayout = require("./TypeEditorLayout.spec"),
	InsertFlow = require("./InsertFlow.spec"),
	IconData = require("./IconData.spec"),
	EnginePropResolver = require("./EnginePropResolver.spec"),
	LifecycleGate = require("./LifecycleGate.spec"),
	ScriptHeader = require("./ScriptHeader.spec"),
	TypeCatalog = require("./TypeCatalog.spec"),
	ApiSource = require("./ApiSource.spec"),
})
