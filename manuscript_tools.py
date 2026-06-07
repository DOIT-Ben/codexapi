import argparse
import copy
import json
import os
import re
import shutil
import zipfile
from collections import Counter, defaultdict
from pathlib import Path
from xml.etree import ElementTree as ET

W_NS = "http://schemas.openxmlformats.org/wordprocessingml/2006/main"
R_NS = "http://schemas.openxmlformats.org/officeDocument/2006/relationships"
MC_NS = "http://schemas.openxmlformats.org/markup-compatibility/2006"
XML_NS = "http://www.w3.org/XML/1998/namespace"
NS = {"w": W_NS, "r": R_NS}
ET.register_namespace("w", W_NS)
ET.register_namespace("r", R_NS)
ET.register_namespace("mc", MC_NS)


def preserve_root_namespaces(original_xml, modified_xml):
    original_match = re.search(rb"<w:document\b[^>]*>", original_xml)
    modified_match = re.search(rb"<w:document\b[^>]*>", modified_xml)
    if not original_match or not modified_match:
        return modified_xml
    original_head = original_match.group(0)[:-1]
    modified_head = modified_match.group(0)[:-1]
    for m in re.finditer(rb"\sxmlns(?::[A-Za-z0-9_]+)?=\"[^\"]+\"", original_head):
        decl = m.group(0)
        name = decl.split(b"=", 1)[0].strip()
        if name not in modified_head:
            modified_head += decl
    return (
        modified_xml[: modified_match.start()]
        + modified_head
        + b">"
        + modified_xml[modified_match.end() :]
    )


def qn(ns, tag):
    return f"{{{ns}}}{tag}"


def paragraph_text(p):
    return "".join(t.text or "" for t in p.findall(".//w:t", NS))


def load_document_xml(docx_path):
    with zipfile.ZipFile(docx_path) as z:
        return z.read("word/document.xml")


def paragraphs(docx_path):
    root = ET.fromstring(load_document_xml(docx_path))
    out = []
    for idx, p in enumerate(root.findall(".//w:p", NS)):
        text = paragraph_text(p)
        if text.strip():
            out.append({"idx": idx, "text": text})
    return out


def find_references(paras):
    ref_start = None
    for i, item in enumerate(paras):
        if item["text"].strip().lower() in {"references", "bibliography"}:
            ref_start = i
            break
    if ref_start is None:
        return None, []
    refs = []
    current = None
    sequential_num = 1
    for item in paras[ref_start + 1 :]:
        text = item["text"].strip()
        m = re.match(r"^\s*(?:\[(\d+)\]|(\d+)[\.\)])\s*(.+)", text)
        if m:
            if current:
                refs.append(current)
            num = int(m.group(1) or m.group(2))
            current = {
                "num": num,
                "para_idx": item["idx"],
                "text": text,
            }
            sequential_num = max(sequential_num, num + 1)
        elif current is None and text:
            # Word stores some bibliography numbers as automatic list labels,
            # not as text. In that common case, each non-empty paragraph after
            # the References heading is one bibliography entry.
            current = {
                "num": sequential_num,
                "para_idx": item["idx"],
                "text": text,
            }
            sequential_num += 1
        elif current and text and (
            "https://doi.org/" not in current["text"]
            and "arXiv:" not in current["text"]
            and not re.search(r"\.\s*$", current["text"])
        ):
            # Fallback for rare wrapped entries represented as separate
            # paragraphs. Most Word bibliography items are one paragraph.
            current["text"] += " " + text
        elif current and text:
            refs.append(current)
            current = {
                "num": sequential_num,
                "para_idx": item["idx"],
                "text": text,
            }
            sequential_num += 1
    if current:
        refs.append(current)
    return paras[ref_start]["idx"], refs


def parse_citation_token(token):
    nums = []
    for part in re.split(r"\s*,\s*", token.strip()):
        if not part:
            continue
        if re.fullmatch(r"\d+", part):
            nums.append(int(part))
            continue
        m = re.fullmatch(r"(\d+)\s*[-–]\s*(\d+)", part)
        if m:
            a, b = int(m.group(1)), int(m.group(2))
            step = 1 if a <= b else -1
            nums.extend(range(a, b + step, step))
    return nums


def find_citations(paras, ref_heading_idx):
    citations = []
    pattern = re.compile(r"\[([0-9][0-9,\s\-–]*)\]")
    for item in paras:
        if item["idx"] >= ref_heading_idx:
            continue
        text = item["text"]
        for m in pattern.finditer(text):
            nums = parse_citation_token(m.group(1))
            if nums:
                citations.append(
                    {
                        "para_idx": item["idx"],
                        "token": m.group(0),
                        "nums": nums,
                        "context": text[max(0, m.start() - 80) : m.end() + 80],
                    }
                )
    return citations


def audit(args):
    main_paras = paragraphs(args.main)
    supp_paras = paragraphs(args.supp)
    ref_heading_idx, refs = find_references(main_paras)
    citations = find_citations(main_paras, ref_heading_idx)
    ref_nums = {r["num"] for r in refs}
    cite_nums = set(n for c in citations for n in c["nums"])
    payload = {
        "main_paragraphs": len(main_paras),
        "supp_paragraphs": len(supp_paras),
        "reference_heading_idx": ref_heading_idx,
        "reference_count": len(refs),
        "reference_numbers": [r["num"] for r in refs],
        "citation_count": len(citations),
        "cited_numbers": sorted(cite_nums),
        "missing_reference_numbers": sorted(cite_nums - ref_nums),
        "uncited_reference_numbers": sorted(ref_nums - cite_nums),
        "duplicate_reference_numbers": sorted(k for k, v in Counter(r["num"] for r in refs).items() if v > 1),
        "citations": citations,
        "references": refs,
    }
    print(json.dumps(payload, ensure_ascii=False, indent=2))


def next_bookmark_id(root):
    ids = []
    for elem in root.iter():
        val = elem.attrib.get(qn(W_NS, "id"))
        if val and elem.tag in {qn(W_NS, "bookmarkStart"), qn(W_NS, "bookmarkEnd")}:
            try:
                ids.append(int(val))
            except ValueError:
                pass
    return max(ids, default=0) + 1


def preserve_space(t_elem):
    text = t_elem.text or ""
    if text[:1].isspace() or text[-1:].isspace():
        t_elem.set(qn(XML_NS, "space"), "preserve")


def clone_run_with_text(source_run, text):
    new_run = copy.deepcopy(source_run)
    for child in list(new_run):
        if child.tag != qn(W_NS, "rPr"):
            new_run.remove(child)
    t = ET.SubElement(new_run, qn(W_NS, "t"))
    t.text = text
    preserve_space(t)
    return new_run


def make_hyperlink_run(source_run, text, anchor):
    hl = ET.Element(qn(W_NS, "hyperlink"), {qn(W_NS, "anchor"): anchor})
    hl.append(clone_run_with_text(source_run, text))
    return hl


def citation_nodes(source_run, token, refs_available):
    nodes = []
    last = 0
    for m in re.finditer(r"\d+", token):
        if m.start() > last:
            nodes.append(clone_run_with_text(source_run, token[last : m.start()]))
        num = int(m.group(0))
        if num in refs_available:
            nodes.append(make_hyperlink_run(source_run, m.group(0), f"_Ref_{num}"))
        else:
            nodes.append(clone_run_with_text(source_run, m.group(0)))
        last = m.end()
    if last < len(token):
        nodes.append(clone_run_with_text(source_run, token[last:]))
    return nodes


def split_run_for_citations(parent, child_index, refs_available):
    run = parent[child_index]
    text_elems = run.findall("w:t", NS)
    if len(text_elems) != 1:
        return 0
    full = text_elems[0].text or ""
    pattern = re.compile(r"\[([0-9][0-9,\s\-–]*)\]")
    matches = list(pattern.finditer(full))
    if not matches:
        return 0
    pieces = []
    last = 0
    changes = 0
    for m in matches:
        nums = parse_citation_token(m.group(1))
        if not nums or any(n not in refs_available for n in nums):
            continue
        if m.start() > last:
            pieces.append(("text", full[last : m.start()], None))
        token = m.group(0)
        pieces.append(("citation", token, None))
        last = m.end()
        changes += 1
    if not changes:
        return 0
    if last < len(full):
        pieces.append(("text", full[last:], None))
    new_nodes = []
    for kind, txt, anchor in pieces:
        if txt == "":
            continue
        if kind == "citation":
            new_nodes.extend(citation_nodes(run, txt, refs_available))
        else:
            new_nodes.append(clone_run_with_text(run, txt))
    parent.remove(run)
    for offset, node in enumerate(new_nodes):
        parent.insert(child_index + offset, node)
    return changes


def add_reference_bookmark(p, name, bookmark_id):
    start = ET.Element(
        qn(W_NS, "bookmarkStart"),
        {qn(W_NS, "id"): str(bookmark_id), qn(W_NS, "name"): name},
    )
    end = ET.Element(qn(W_NS, "bookmarkEnd"), {qn(W_NS, "id"): str(bookmark_id)})
    insert_at = 1 if len(p) and p[0].tag == qn(W_NS, "pPr") else 0
    p.insert(insert_at, start)
    p.append(end)


def crossref(args):
    src = Path(args.main)
    out = Path(args.out)
    if src.resolve() == out.resolve():
        raise SystemExit("Refusing to overwrite the source docx.")

    with zipfile.ZipFile(src) as zin:
        xml_bytes = zin.read("word/document.xml")
        root = ET.fromstring(xml_bytes)
        para_elements = root.findall(".//w:p", NS)

        nonempty = []
        for idx, p in enumerate(para_elements):
            text = paragraph_text(p)
            if text.strip():
                nonempty.append({"idx": idx, "text": text, "element": p})
        ref_heading_idx, refs = find_references(nonempty)
        if ref_heading_idx is None:
            raise SystemExit("No References heading found.")
        refs_by_num = {r["num"]: r for r in refs}
        next_id = next_bookmark_id(root)

        bookmark_added = 0
        for num, ref in sorted(refs_by_num.items()):
            p = para_elements[ref["para_idx"]]
            name = f"_Ref_{num}"
            already = any(
                elem.tag == qn(W_NS, "bookmarkStart")
                and elem.attrib.get(qn(W_NS, "name")) == name
                for elem in p.iter()
            )
            if not already:
                add_reference_bookmark(p, name, next_id)
                next_id += 1
                bookmark_added += 1

        hyperlink_count = 0
        refs_available = set(refs_by_num)
        for idx, p in enumerate(para_elements):
            if idx >= ref_heading_idx:
                continue
            # Work recursively through direct children of paragraphs and hyperlinks,
            # because Word sometimes nests runs inside fields or smart tags.
            stack = [p]
            while stack:
                parent = stack.pop()
                i = 0
                while i < len(parent):
                    child = parent[i]
                    if child.tag == qn(W_NS, "r"):
                        delta = split_run_for_citations(parent, i, refs_available)
                        hyperlink_count += delta
                        i += 1
                    else:
                        stack.append(child)
                        i += 1

        tmp = out.with_suffix(out.suffix + ".tmp")
        if tmp.exists():
            tmp.unlink()
        with zipfile.ZipFile(tmp, "w", zipfile.ZIP_DEFLATED) as zout:
            for item in zin.infolist():
                data = zin.read(item.filename)
                if item.filename == "word/document.xml":
                    data = ET.tostring(root, encoding="utf-8", xml_declaration=True)
                    data = preserve_root_namespaces(xml_bytes, data)
                zout.writestr(item, data)
        shutil.move(tmp, out)

    print(
        json.dumps(
            {
                "output": str(out),
                "bookmarks_added": bookmark_added,
                "citation_hyperlinks_added": hyperlink_count,
                "reference_count": len(refs_by_num),
            },
            ensure_ascii=False,
            indent=2,
        )
    )


def visible_text_sequence(docx_path):
    root = ET.fromstring(load_document_xml(docx_path))
    return [t.text or "" for t in root.findall(".//w:t", NS)]


def verify_crossref(args):
    src_seq = visible_text_sequence(args.main)
    out_seq = visible_text_sequence(args.out)
    src_text = "".join(src_seq)
    out_text = "".join(out_seq)
    with zipfile.ZipFile(args.out) as z:
        root = ET.fromstring(z.read("word/document.xml"))
    bookmark_names = {
        elem.attrib.get(qn(W_NS, "name"))
        for elem in root.iter(qn(W_NS, "bookmarkStart"))
        if elem.attrib.get(qn(W_NS, "name"), "").startswith("_Ref_")
    }
    anchors = [
        elem.attrib.get(qn(W_NS, "anchor"))
        for elem in root.iter(qn(W_NS, "hyperlink"))
        if elem.attrib.get(qn(W_NS, "anchor"), "").startswith("_Ref_")
    ]
    bad_anchors = sorted({a for a in anchors if a not in bookmark_names})
    payload = {
        "visible_text_identical": src_text == out_text,
        "source_text_nodes": len(src_seq),
        "output_text_nodes": len(out_seq),
        "reference_bookmarks": len(bookmark_names),
        "citation_hyperlinks": len(anchors),
        "bad_hyperlink_anchors": bad_anchors,
    }
    if src_text != out_text:
        for i, (a, b) in enumerate(zip(src_text, out_text)):
            if a != b:
                payload["first_text_difference"] = {"index": i, "source": a, "output": b}
                break
        if "first_text_difference" not in payload:
            payload["first_text_difference"] = {
                "index": min(len(src_text), len(out_text)),
                "source_extra": src_text[min(len(src_text), len(out_text)) : min(len(src_text), len(out_text)) + 80],
                "output_extra": out_text[min(len(src_text), len(out_text)) : min(len(src_text), len(out_text)) + 80],
            }
    print(json.dumps(payload, ensure_ascii=False, indent=2))


def main():
    parser = argparse.ArgumentParser()
    sub = parser.add_subparsers(dest="cmd", required=True)
    a = sub.add_parser("audit")
    a.add_argument("--main", required=True)
    a.add_argument("--supp", required=True)
    a.set_defaults(func=audit)
    c = sub.add_parser("crossref")
    c.add_argument("--main", required=True)
    c.add_argument("--out", required=True)
    c.set_defaults(func=crossref)
    v = sub.add_parser("verify-crossref")
    v.add_argument("--main", required=True)
    v.add_argument("--out", required=True)
    v.set_defaults(func=verify_crossref)
    args = parser.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
