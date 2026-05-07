## Repeating in SVN: what `svn:mergeinfo` actually looks like

Earlier I waved at `svn:mergeinfo` as the thing git deliberately doesn't have. Worth showing the property string itself, because the shape is the whole point.

The same C2–C5 timeline replayed in a fresh local SVN repo gives this revision map:

| Repo rev | Meaning |
|---|---|
| r1 | layout (`mkdir trunk + branches + tags`) |
| r2 | C1 — initial Person CRUD app |
| r3 | C2 — `hair_color` (string) |
| r4 | C3 — UPPERCASE buttons |
| r5 | C4 — `hair_color` INTEGER |
| r6 | C5 — maintainer comment |
| r7 | `svn copy /trunk@r3 /branches/release` (cut at C2) |

### Scenario A — cherry-pick out of order (C4 then C3, then sweep)

```
$ cd svn-wc/branches/release

$ svn merge -c5 ^/trunk .            # cherry-pick C4
$ svn commit -m "cherry-pick C4 from trunk@r5"
$ svn propget svn:mergeinfo .
  /trunk:5

$ svn merge -c4 ^/trunk .            # cherry-pick C3
$ svn commit -m "cherry-pick C3 from trunk@r4"
$ svn propget svn:mergeinfo .
  /trunk:4-5

$ svn merge ^/trunk .                # sweep
--- Merging r6 through r9 into '.':
U    app.rb
$ svn commit -m "sweep merge ^/trunk into release"
$ svn propget svn:mergeinfo .
  /trunk:4-9
```

### Scenario B — cherry-pick in trunk order (C3 then C4, then sweep)

```
$ svn merge -c4 ^/trunk .            # cherry-pick C3
$ svn commit -m "cherry-pick C3 from trunk@r4"
$ svn propget svn:mergeinfo .
  /trunk:4

$ svn merge -c5 ^/trunk .            # cherry-pick C4
$ svn commit -m "cherry-pick C4 from trunk@r5"
$ svn propget svn:mergeinfo .
  /trunk:4-5

$ svn merge ^/trunk .                # sweep
$ svn commit -m "sweep merge ^/trunk into release"
$ svn propget svn:mergeinfo .
  /trunk:4-9
```

### What the property is telling you

Both scenarios converge to `/trunk:4-9`, and `svn diff ^/trunk ^/branches/release` reports no file content difference — only this property exists on the branch root. The intermediate path differs (`/trunk:5` → `/trunk:4-5` versus `/trunk:4` → `/trunk:4-5`), but order doesn't matter to the end state, just like in git.

What *is* different from git: the sweep `svn merge ^/trunk` reads the property and refuses to re-apply revisions named in it. Only `r6` (C5) actually produced edits in the sweep — `r4` and `r5` were already accounted for. SVN can answer the question "have I integrated this trunk revision yet?" because it wrote down the answer the first time. Git cannot, because git deliberately wrote nothing down.

There's a quirk visible in the final string: `/trunk:4-9`, not `/trunk:4-6`. SVN records the *closed range it considered* during the sweep, including repo revisions that touched neither trunk nor any merge source — `r7` was the branch copy, `r8` and `r9` were the cherry-pick commits themselves. This is exactly the kind of "mergeinfo creep" SVN earned its slightly-broken reputation for. It's harmless here; it can become noisy across years of long-lived branches, particularly if anyone bypasses `svn merge` and edits properties by hand.

### Reproducing the SVN side

The scripts are on the `svn-version` branch of the same repo:

```
git checkout svn-version
sudo apt install subversion       # or your platform's equivalent
./svn/start.sh                    # build trunk r2..r6 + release@r3
./svn/scenario-a-out-of-order.sh  # cherry-pick C4 then C3, then sweep
./svn/rollback.sh                 # wipe svn-repo/ and svn-wc/
./svn/scenario-b-in-order.sh      # cherry-pick C3 then C4, then sweep
```

Each scenario script wipes and rebuilds the repo (SVN is append-only, so "reset to a past revision" means start over), prints the `svn:mergeinfo` value after every step, and ends with a `svn diff` of trunk against release. The same `patches/` directory feeds both the git and SVN flows — the patches are applied with `patch -p1` rather than `git apply`, because the SVN working copy lives inside the outer git worktree and `git apply` would treat it as the parent repo's index.

So: SVN does have the audit trail, the property is human-readable, and the sweep merge is genuinely aware of it. The cost is the property's tendency to grow ranges that include revisions it had no business including, plus the institutional discipline of never touching `svn:mergeinfo` directly. Whether that's a better trade than git's "we keep no record at all" is a judgement call about what failure mode you'd rather face — false reassurance from a slightly-wrong record, or no record and a test suite doing all the work.
