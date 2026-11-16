# Chapter 09 wiki — STAGED, not pushed

This folder holds the GitHub-wiki pages for **Chapter 09 — "Foothold" (Web RCE)**,
written in the same lean, exploit-first 6-section template the existing 20
station pages use. **Nothing here has been pushed to the live wiki.** Review,
then push when you're happy.

## New pages (8)

- `Chapter-09-Overview.md`
- `C09-Station-A-Unrestricted-Upload.md`
- `C09-Station-B-Upload-Filter-Bypass.md`
- `C09-Station-C-Command-Injection.md`
- `C09-Station-D-LFI-RCE.md`
- `C09-Station-E-SSTI-Twig.md`
- `C09-Station-F-PHP-Deserialization.md`
- `Reverse-Shell-Reference.md`

## Modified pages (3) — based on the **current live** wiki

- `_Sidebar.md` — adds the Chapter 09 section + `Reverse-Shell-Reference`
- `Home.md` — adds the Chapter 09 roster row + station list (now "Five chapters live")
- `Blue-Team-Playbook.md` — new **§6 "The web perimeter"** (upload hardening,
  input validation / argv exec, `disable_functions`, egress filtering, detection
  one-liners); old §6 (IR canary) renumbered to §7

## How to push (only after you've reviewed)

```bash
# clone the wiki repo if you don't have it
cd /tmp && git clone https://github.com/Adw0rm-sec/road-to-root.wiki.git

# copy this bundle in (overwrites _Sidebar/Home/Blue-Team-Playbook with the
# Chapter-09 versions — they were built from the current live pages, so this is
# an add, not a regress)
cp "<repo>/wiki-staging/chapter-09/"*.md /tmp/road-to-root.wiki/
rm /tmp/road-to-root.wiki/README.md        # this file is staging-only, not a wiki page

cd /tmp/road-to-root.wiki
git add .
git commit -m "Add Chapter 09 — Foothold (Web RCE): overview, 6 stations, Reverse-Shell-Reference; wire nav + Blue-Team-Playbook"
git push
```

> Note: `README.md` in this folder is staging documentation — do **not** copy it
> into the wiki (the wiki's front page is `Home.md`).
