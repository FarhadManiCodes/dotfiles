// PDF-only preview and one-based page midpoint for Sioyek.
var mode = scriptArgs[0];
var file = scriptArgs[1];
if (!file || (mode !== "preview" && mode !== "yloc"))
	throw new Error("usage: pdf-meta preview FILE | pdf-meta yloc FILE PAGE");

var doc = Document.openDocument(file);
if (!doc.isPDF()) throw new Error("not a PDF");

if (mode === "preview") {
	var field = function (key) {
		var value = doc.getMetaData("info:" + key);
		return value ? value.replace(/[\x00-\x1f\x7f-\x9f]/g, " ").trim() || "(not embedded)" : "(not embedded)";
	};
	var title = field("Title");
	var author = field("Author");
	var pages = doc.countPages();
	print("Title: " + title);
	print("Author: " + author);
	print("Pages: " + pages);
	print("");
	var lines = pages ? doc.loadPage(0).toStructuredText().asText().split(/\r?\n/) : [];
	var shown = 0;
	for (var i = 0; i < lines.length && shown < 16; i++) {
		var line = lines[i].replace(/[\x00-\x1f\x7f-\x9f]/g, " ").trim();
		if (line) {
			if (shown === 0) print("First page:");
			print(line.substring(0, 120));
			shown++;
		}
	}
	if (!shown) print("First page: no extractable text");
} else {
	var page = scriptArgs[2];
	if (!page || !/^[1-9][0-9]*$/.test(page) || Number(page) > doc.countPages())
		throw new Error("invalid page");
	var bounds = doc.loadPage(Number(page) - 1).getBounds();
	var midpoint = (bounds[3] - bounds[1]) / 2;
	if (!isFinite(midpoint) || midpoint <= 0) throw new Error("invalid page bounds");
	print(midpoint.toFixed(3));
}
