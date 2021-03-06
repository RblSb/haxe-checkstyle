package checkstyle.checks.coding;

import checkstyle.utils.StringUtils;

/**
	Checks for unused local variables.
 **/
@name("UnusedLocalVar")
@desc("Checks for unused local variables.")
class UnusedLocalVarCheck extends Check {

	public function new() {
		super(TOKEN);
	}

	override function actualRun() {
		var root:TokenTree = checker.getTokenTree();
		var functions:Array<TokenTree> = root.filter([Kwd(KwdFunction)], ALL);

		for (f in functions) {
			if (isPosSuppressed(f.pos)) continue;
			var skipFirstFunction:Bool = true;
			var localVars:Array<TokenTree> = f.filterCallback(function(tok:TokenTree, depth:Int):FilterResult {
				return switch (tok.tok) {
					case Kwd(KwdVar): FOUND_SKIP_SUBTREE;
					case Kwd(KwdFunction):
						if (skipFirstFunction) {
							skipFirstFunction = false;
							GO_DEEPER;
						}
						else SKIP_SUBTREE;
					default: GO_DEEPER;
				}
			});
			checkLocalVars(f, localVars);
		}
	}

	function checkLocalVars(f:TokenTree, localVars:Array<TokenTree>) {
		for (localVar in localVars) {
			for (child in localVar.children) {
				switch (child.tok) {
					case Const(CIdent(name)):
						checkLocalVar(f, child, name);
					default:
				}
			}
		}
	}

	function checkLocalVar(f:TokenTree, v:TokenTree, name:String) {
		var ignoreFunctionSignature:Bool = true;
		var nameList:Array<TokenTree> = f.filterCallback(function(tok:TokenTree, depth:Int):FilterResult {
			if (ignoreFunctionSignature) {
				switch (tok.tok) {
					case Kwd(KwdPublic), Kwd(KwdPrivate):
						return SKIP_SUBTREE;
					case At:
						return SKIP_SUBTREE;
					case Comment(_), CommentLine(_):
						return SKIP_SUBTREE;
					case POpen:
						ignoreFunctionSignature = false;
						return SKIP_SUBTREE;
					default:
						return GO_DEEPER;
				}
			}
			return switch (tok.tok) {
				case Const(CIdent(n)):
					if (n == name) FOUND_GO_DEEPER;
					else GO_DEEPER;
				case Const(CString(s)):
					checkStringInterpolation(tok, name, s);
				default: GO_DEEPER;
			}
		});
		if (nameList.length > 1) return;

		logPos('Unused local variable $name', v.parent.getPos());
	}

	function checkStringInterpolation(tok:TokenTree, name:String, s:String):FilterResult {
		if (!StringUtils.isStringInterpolation(s, checker.file.content, tok.pos)) {
			return GO_DEEPER;
		}

		// $name
		var format:String = "\\$" + name + "([^_0-9a-zA-Z]|$)";
		var r:EReg = new EReg(format, "");
		if (r.match(s)) {
			return FOUND_GO_DEEPER;
		}

		// '${name.doSomething()} or ${doSomething(name)} or ${name}
		format = "\\$\\{(|.*[^_0-9a-zA-Z])" + name + "([^_0-9a-zA-Z].*|)\\}";
		r = new EReg(format, "");
		if (r.match(s)) {
			return FOUND_GO_DEEPER;
		}
		return GO_DEEPER;
	}

	override public function detectableInstances():DetectableInstances {
		return [{
			fixed: [],
			properties: [{
				propertyName: "severity",
				values: [SeverityLevel.INFO]
			}]
		}];
	}
}