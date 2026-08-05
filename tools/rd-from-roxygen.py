#!/usr/bin/env python3
"""
Generate .Rd documentation from the roxygen comments in R/.

roxygen2 is the normal tool for this and should be used when available
(devtools::document()). This converter exists so that the reference manual can
be built in an environment where CRAN is unreachable. It handles the subset of
roxygen syntax the package actually uses: @param, @return, @export, @examples,
@rdname, @keywords, @section, @examples, inline markdown code spans, [fn()]
cross-references, and \\eqn/\\deqn passed through verbatim.
"""
import os, re, sys, textwrap

R_DIR = sys.argv[1] if len(sys.argv) > 1 else "R"
MAN = sys.argv[2] if len(sys.argv) > 2 else "man"
os.makedirs(MAN, exist_ok=True)


def esc(s):
    """Escape the characters Rd treats specially, leaving existing macros."""
    out = []
    i = 0
    while i < len(s):
        c = s[i]
        if c == "\\":
            # keep known Rd macros intact
            m = re.match(r"\\(eqn|deqn|code|link|emph|strong|dots|href|item)\b", s[i:])
            if m:
                out.append(s[i])
                i += 1
                continue
            out.append("\\\\")
        elif c in "%{}":
            out.append("\\" + c)
        else:
            out.append(c)
        i += 1
    return "".join(out)


def md(s):
    """Convert the markdown roxygen actually uses into Rd."""
    s = re.sub(r"\[([A-Za-z._][A-Za-z0-9._]*)\(\)\]", r"\\code{\\link{\1}}", s)
    s = re.sub(r"\[([A-Za-z._][A-Za-z0-9._:]+)\]\(([^)]+)\)", r"\\href{\2}{\1}", s)
    s = re.sub(r"`([^`]+)`", r"\\code{\1}", s)
    s = re.sub(r"\*\*([^*]+)\*\*", r"\\strong{\1}", s)
    s = re.sub(r"(?<![\*\w])\*([^*\n]+)\*(?!\w)", r"\\emph{\1}", s)
    return s


def parse_file(path):
    lines = open(path, encoding="utf-8").read().split("\n")
    blocks, i = [], 0
    while i < len(lines):
        if re.match(r"^\s*#'", lines[i]):
            j = i
            while j < len(lines) and re.match(r"^\s*#'", lines[j]):
                j += 1
            raw = [re.sub(r"^\s*#'\s?", "", l) for l in lines[i:j]]
            k = j
            while k < len(lines) and lines[k].strip() == "":
                k += 1
            defline = lines[k] if k < len(lines) else ""
            m = re.match(r"^([A-Za-z._][A-Za-z0-9._]*)\s*<-\s*function\s*\((.*)$", defline)
            if m:
                name = m.group(1)
                # gather the full argument list across continuation lines
                args, depth, buf = "", 0, m.group(2)
                idx = k
                while True:
                    for ch in buf:
                        if ch == "(":
                            depth += 1
                        elif ch == ")":
                            if depth == 0:
                                break
                            depth -= 1
                    pos = None
                    d = 0
                    for p, ch in enumerate(buf):
                        if ch == "(":
                            d += 1
                        elif ch == ")":
                            if d == 0:
                                pos = p
                                break
                            d -= 1
                    if pos is not None:
                        args += buf[:pos]
                        break
                    args += buf + " "
                    idx += 1
                    if idx >= len(lines):
                        break
                    buf = lines[idx]
                blocks.append((name, raw, re.sub(r"\s+", " ", args).strip()))
            i = j
        else:
            i += 1
    return blocks


def split_tags(raw):
    title, desc, tags = "", [], {}
    cur, buf = None, []

    def flush():
        if cur is not None:
            tags.setdefault(cur, []).append("\n".join(buf).strip())

    for l in raw:
        m = re.match(r"^@(\w+)\s*(.*)$", l)
        if m:
            flush()
            cur, buf = m.group(1), [m.group(2)]
        elif cur is None:
            desc.append(l)
        else:
            buf.append(l)
    flush()
    body = "\n".join(desc).strip().split("\n\n")
    title = body[0].replace("\n", " ").strip() if body else ""
    description = "\n\n".join(body[1:]).strip() if len(body) > 1 else title
    return title, description, tags


def build(blocks):
    topics = {}
    for name, raw, args in blocks:
        title, description, tags = split_tags(raw)
        if "noRd" in tags or "keywords" in tags and any(
            "internal" in v for v in tags.get("keywords", [])
        ):
            continue
        if "export" not in tags:
            continue
        topic = tags["rdname"][0].strip() if "rdname" in tags else name
        t = topics.setdefault(
            topic,
            dict(aliases=[], usage=[], params=[], title="", desc="", ret="",
                 ex="", secs=[], seealso=""),
        )
        t["aliases"].append(name)
        t["usage"].append("%s(%s)" % (name, args))
        if title and not t["title"]:
            t["title"] = title
        if description and not t["desc"]:
            t["desc"] = description
        for p in tags.get("param", []):
            m = re.match(r"^(\S+)\s+([\s\S]*)$", p)
            if m and m.group(1) not in [x[0] for x in t["params"]]:
                t["params"].append((m.group(1), m.group(2)))
        if "return" in tags and not t["ret"]:
            t["ret"] = tags["return"][0]
        if "examples" in tags and not t["ex"]:
            t["ex"] = tags["examples"][0]
        for s in tags.get("section", []):
            m = re.match(r"^([^:]+):\s*([\s\S]*)$", s)
            if m:
                t["secs"].append((m.group(1), m.group(2)))
        if "seealso" in tags:
            t["seealso"] = tags["seealso"][0]
    return topics


def write(topic, t):
    L = ["%% Generated from roxygen comments by tools/rd-from-roxygen.py",
         "%% Do not edit by hand",
         "\\name{%s}" % topic]
    for a in dict.fromkeys(t["aliases"]):
        L.append("\\alias{%s}" % a)
    L.append("\\title{%s}" % md(esc(t["title"] or topic)))
    L.append("\\usage{")
    for u in dict.fromkeys(t["usage"]):
        L.append(textwrap.fill(u, 76, subsequent_indent="  "))
    L.append("}")
    if t["params"]:
        L.append("\\arguments{")
        for k, v in t["params"]:
            for kk in k.split(","):
                L.append("  \\item{%s}{%s}" % (kk.strip(), md(esc(v)).strip()))
        L.append("}")
    L.append("\\description{\n%s\n}" % md(esc(t["desc"] or t["title"])))
    if t["ret"]:
        L.append("\\value{\n%s\n}" % md(esc(t["ret"])))
    for nm, body in t["secs"]:
        L.append("\\section{%s}{\n%s\n}" % (esc(nm), md(esc(body))))
    if t["ex"]:
        L.append("\\examples{\n%s\n}" % t["ex"])
    if t["seealso"]:
        L.append("\\seealso{%s}" % md(esc(t["seealso"])))
    open(os.path.join(MAN, topic + ".Rd"), "w", encoding="utf-8").write(
        "\n".join(L) + "\n"
    )


blocks = []
for f in sorted(os.listdir(R_DIR)):
    if f.endswith(".R"):
        blocks += parse_file(os.path.join(R_DIR, f))
topics = build(blocks)
for topic, t in topics.items():
    write(topic, t)

# Package-level topic
open(os.path.join(MAN, "cloudscape-package.Rd"), "w", encoding="utf-8").write(
    """%% Generated by tools/rd-from-roxygen.py
\\name{cloudscape-package}
\\alias{cloudscape}
\\alias{cloudscape-package}
\\docType{package}
\\title{cloudscape: Clear-Observation Availability and Cloud Analysis for
Optical Satellite Image Time Series}
\\description{
A multi-sensor framework that turns cloud statistics into decision-relevant
measures of whether an optical time-series study is feasible at a given
location. Statistics are aggregated onto an equal-area analysis grid rather
than onto sensor footprints, removing the latitude bias that affects per-scene
counts and making Landsat and Sentinel-2 directly comparable.
}
\\section{Where to start}{
\\itemize{
  \\item \\code{\\link{cl_grid}} defines the equal-area analysis grid.
  \\item \\code{\\link{cl_search}} queries a catalogue;
        \\code{\\link{cl_items_to_obs}} maps results onto the grid.
  \\item \\code{\\link{cl_clear_obs}}, \\code{\\link{cl_gaps}} and
        \\code{\\link{cl_seasonality}} summarise availability.
  \\item \\code{\\link{cl_persistence}} measures cloud autocorrelation.
  \\item \\code{\\link{cl_pheno_power}} converts an acquisition pattern into
        phenological retrieval error in days.
  \\item \\code{\\link{cl_probability}} and \\code{\\link{cl_shadow}} detect
        cloud and cloud shadow.
  \\item \\code{\\link{cl_simulate}} and \\code{\\link{cl_compare}} benchmark
        detectors against known truth.
}
}
\\author{
Ehsan Rahimi \\email{ehsanrahimi666@gmail.com} and Chuleui Jung
}
\\keyword{package}
"""
)
print("wrote %d Rd topics" % (len(topics) + 1))
