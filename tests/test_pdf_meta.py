"""Exercise the shared PDF helper with small, isolated PDF files."""

import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / "bash/pdf-meta"


def make_pdf(path, title=None, author=None):
    def pdf_string(value):
        return b"<" + (b"\xfe\xff" + value.encode("utf-16-be")).hex().encode() + b">"

    objects = [
        b"<< /Type /Catalog /Pages 2 0 R >>",
        b"<< /Type /Pages /Kids [3 0 R 4 0 R 5 0 R] /Count 3 >>",
        b"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 338 372] /Contents 6 0 R >>",
        b"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 338 558] /Contents 6 0 R >>",
        (b"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] "
         b"/CropBox [100 100 500 700] /Rotate 90 /Contents 6 0 R >>"),
        b"<< /Length 0 >>\nstream\n\nendstream",
    ]
    fields = []
    if title is not None:
        fields.append(b"/Title " + pdf_string(title))
    if author is not None:
        fields.append(b"/Author " + pdf_string(author))
    if fields:
        objects.append(b"<< " + b" ".join(fields) + b" >>")

    data = bytearray(b"%PDF-1.4\n%\xe2\xe3\xcf\xd3\n")
    offsets = [0]
    for number, obj in enumerate(objects, 1):
        offsets.append(len(data))
        data += f"{number} 0 obj\n".encode() + obj + b"\nendobj\n"
    xref = len(data)
    data += f"xref\n0 {len(offsets)}\n0000000000 65535 f \n".encode()
    for offset in offsets[1:]:
        data += f"{offset:010d} 00000 n \n".encode()
    trailer = f"trailer\n<< /Size {len(offsets)} /Root 1 0 R".encode()
    if fields:
        trailer += f" /Info {len(objects)} 0 R".encode()
    data += trailer + b" >>\n" + f"startxref\n{xref}\n%%EOF\n".encode()
    path.write_bytes(data)


class PdfMetaTests(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory(prefix="pdf-meta-test-")
        self.addCleanup(temp.cleanup)
        self.root = Path(temp.name)
        mutool = shutil.which("mutool")
        self.assertIsNotNone(mutool, "pdf-meta requires mutool")
        self.env = dict(os.environ, PATH=f"{Path(mutool).parent}:/usr/bin:/bin",
                        LC_ALL="C.UTF-8", NO_COLOR="1")
        self.pdf = self.root / "A reader's book.pdf"
        make_pdf(self.pdf, "Café (Draft): One", "Ada O'Neil")

    def run_meta(self, *args):
        return subprocess.run([str(SCRIPT), *args], env=self.env,
                              capture_output=True, text=True, timeout=10)

    def test_preview(self):
        result = self.run_meta("preview", str(self.pdf))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout,
                         "Title: Café (Draft): One\nAuthor: Ada O'Neil\nPages: 3\n")
        self.assertEqual(result.stderr, "")

    def test_missing_metadata(self):
        make_pdf(self.pdf)
        result = self.run_meta("preview", str(self.pdf))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout,
                         "Title: (not embedded)\nAuthor: (not embedded)\nPages: 3\n")
        make_pdf(self.pdf, title="Only a title")
        result = self.run_meta("preview", str(self.pdf))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout,
                         "Title: Only a title\nAuthor: (not embedded)\nPages: 3\n")

    def test_midpoints_and_invalid_pages(self):
        for page, expected in (("1", "186.000"), ("2", "279.000"),
                               ("3", "200.000")):
            with self.subTest(page=page):
                result = self.run_meta("yloc", str(self.pdf), page)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(result.stdout.strip(), expected)
        for page in ("0", "4", "-1", "1.5", "NaN"):
            with self.subTest(page=page):
                result = self.run_meta("yloc", str(self.pdf), page)
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(result.stdout, "")

    def test_unreadable_input(self):
        bad = self.root / "bad.pdf"
        bad.write_text("not a PDF")
        for mode, args in (("preview", ()), ("yloc", ("1",))):
            with self.subTest(mode=mode):
                result = self.run_meta(mode, str(bad), *args)
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(result.stdout, "")


if __name__ == "__main__":
    unittest.main()
