#!/usr/bin/env python3
"""Points sam-prusa-connect at a newly built image.

Usage: bump.py <version> <sha256:digest> <release notes file>

Rewrites the image line in docker-compose.yml and version/releaseNotes in
umbrel-app.yml in place (as text, so comments and layout survive).
"""

import json
import re
import sys

version, digest, notes_path = sys.argv[1:]
if not re.fullmatch(r"sha256:[0-9a-f]{64}", digest):
    sys.exit("bad digest: " + digest)
if not re.fullmatch(r"[0-9A-Za-z.+-]+", version):
    sys.exit("bad version: " + version)

app = "sam-prusa-connect"
image = "ghcr.io/sam-apostel/prusa-connect"

compose_path = app + "/docker-compose.yml"
compose = open(compose_path).read()
compose, count = re.subn(
    r"(?m)^(\s*image: )" + re.escape(image) + r":\S+$",
    lambda m: m.group(1) + image + ":" + version + "@" + digest,
    compose,
)
if count != 1:
    sys.exit(compose_path + ": expected one image line, found " + str(count))
open(compose_path, "w").write(compose)

# Upstream notes are Markdown; umbrelOS shows plain text. Keep it short and
# always link to the full notes.
notes = open(notes_path).read().replace("\r", "").strip()
lines = []
for line in notes.splitlines():
    line = re.sub(r"^#+\s*", "", line)
    line = re.sub(r"\*\*|__|`", "", line)
    line = re.sub(r"\[([^\]]+)\]\([^)]+\)", r"\1", line)
    lines.append(line.rstrip())
notes = re.sub(r"\n{3,}", "\n\n", "\n".join(lines)).strip()
if len(notes) > 1500:
    notes = notes[:1500].rsplit("\n", 1)[0] + "\n..."
link = "Full release notes: https://github.com/prusa3d/prusa-connect/releases/tag/v" + version
notes = (notes + "\n\n" + link) if notes else link
# A double-quoted YAML scalar is valid JSON, so json.dumps escapes it safely.
release_notes = "releaseNotes: " + json.dumps(notes)

manifest_path = app + "/umbrel-app.yml"
manifest = open(manifest_path).read()
manifest, count_version = re.subn(r'(?m)^version: .*$', 'version: "' + version + '"', manifest)
# releaseNotes may be a folded block: replace it up to the next top-level key.
manifest, count_notes = re.subn(
    r"(?ms)^releaseNotes:.*?(?=^\S)", lambda m: release_notes + "\n\n", manifest, count=1
)
if count_version != 1 or count_notes != 1:
    sys.exit(manifest_path + ": could not find version/releaseNotes")
open(manifest_path, "w").write(manifest)
print("sam-prusa-connect -> " + version + "@" + digest)
