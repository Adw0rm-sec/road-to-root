# Wiki staging — Chapters 05–08 — STAGED, not pushed

This folder holds the GitHub-wiki pages for the four new chapters, written in
the same lean, exploit-first 6-section template the existing station pages use.
**Nothing here has been pushed to the live wiki.** Review, then push.

## New pages (18 + nav)

**Chapter 05 — Capabilities** (`chapter-05/`)
- `Chapter-05-Overview.md`
- `C05-Station-A-cap_setuid-python.md`
- `C05-Station-B-cap_setuid-perl.md`
- `C05-Station-C-cap_dac_read_search-tar.md`
- `C05-Station-D-cap_dac_override-write.md`
- `C05-Station-E-cap_setuid-launcher.md`

**Chapter 06 — Wildcard Expansion** (`chapter-06/`)
- `Chapter-06-Overview.md`
- `C06-Station-A-tar-checkpoint.md`
- `C06-Station-B-rsync-e.md`
- `C06-Station-C-chown-reference.md`
- `C06-Station-D-chmod-reference.md`

**Chapter 07 — Local Service + Port Forwarding** (`chapter-07/`)
- `Chapter-07-Overview.md`
- `C07-Station-A-local-forward-redis.md`
- `C07-Station-B-remote-forward-updater.md`

**Chapter 08 — Docker socket** (`chapter-08/`)
- `Chapter-08-Overview.md`
- `C08-Station-A-mount-chroot.md`
- `C08-Station-B-persistence.md`
- `C08-Station-C-raw-socket-api.md`

**Navigation** (`wiki-staging/_Sidebar.md`)
- `_Sidebar.md` — the full sidebar with the four new chapter sections added
  between Chapter 04 and Chapter 09. This supersedes the older
  `chapter-09/_Sidebar.md`.

## Still TODO before/after pushing (not blocking the code labs)

- `Home.md` — add the four roster rows (the `chapter-09/Home.md` is the current
  base; bump "Five chapters live" → "Nine").
- `Blue-Team-Playbook.md` — add detect/fix sections for capabilities, wildcard,
  port-forwarding, and the docker socket (full recipes already live in each
  chapter's `targets/<name>/WRITEUP.md`).
- `Methodology-Map.md` — add `getcap`, `ss -tlnp`, `id | grep docker`, and the
  wildcard branch to the decision tree.

## How to push (only after review)

```bash
cd /tmp && git clone https://github.com/Adw0rm-sec/road-to-root.wiki.git
cp "<repo>/wiki-staging/chapter-05/"*.md /tmp/road-to-root.wiki/
cp "<repo>/wiki-staging/chapter-06/"*.md /tmp/road-to-root.wiki/
cp "<repo>/wiki-staging/chapter-07/"*.md /tmp/road-to-root.wiki/
cp "<repo>/wiki-staging/chapter-08/"*.md /tmp/road-to-root.wiki/
cp "<repo>/wiki-staging/_Sidebar.md"      /tmp/road-to-root.wiki/
cd /tmp/road-to-root.wiki
git add . && git commit -m "Add Chapters 05-08: Capabilities, Wildcard, Port Forwarding, Docker socket" && git push
```

> `README.md` files in `wiki-staging/` are staging notes — do **not** copy them
> into the wiki (the wiki front page is `Home.md`).
