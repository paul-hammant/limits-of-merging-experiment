## Repeating in Perforce: integration records, not properties

Perforce solves the same problem SVN does — *what's been integrated where* — but it stores the answer per-file in the integration database rather than as a string-property on the branch root. Run `p4 integrated` and the depot tells you, for every file revision on the branch, which trunk revision it came from and whether it arrived as a clean copy or a three-way merge.

Same C2–C5 timeline, replayed against a local `p4d`:

| Changelist | Meaning |
|---|---|
| CL1 | C1 — initial Person CRUD app |
| CL2 | C2 — `hair_color` (string) |
| CL3 | C3 — UPPERCASE buttons |
| CL4 | C4 — `hair_color` INTEGER |
| CL5 | C5 — maintainer comment |
| CL6 | `p4 populate //depot/trunk/...@2 //depot/branches/release/...` (cut at C2) |

### Scenario A — cherry-pick out of order (C4 then C3, then sweep)

```
$ p4 integrate //depot/trunk/...@4,@4 //depot/branches/release/...
$ p4 resolve -am //depot/branches/release/...
$ p4 submit -d "cherry-pick C4 from trunk@CL4"
$ p4 integrated //depot/branches/release/app.rb
//depot/branches/release/app.rb#1 - branch from //depot/trunk/app.rb#1,#2
//depot/branches/release/app.rb#2 - merge from //depot/trunk/app.rb#4

$ p4 integrate //depot/trunk/...@3,@3 //depot/branches/release/...
$ p4 resolve -am //depot/branches/release/...
$ p4 submit -d "cherry-pick C3 from trunk@CL3"
$ p4 integrated //depot/branches/release/app.rb
//depot/branches/release/app.rb#1 - branch from //depot/trunk/app.rb#1,#2
//depot/branches/release/app.rb#3 - merge from //depot/trunk/app.rb#3
//depot/branches/release/app.rb#2 - merge from //depot/trunk/app.rb#4

$ p4 integrate //depot/trunk/... //depot/branches/release/...
$ p4 resolve -am //depot/branches/release/...
$ p4 submit -d "sweep merge //depot/trunk into //depot/branches/release"
$ p4 integrated //depot/branches/release/app.rb
//depot/branches/release/app.rb#1 - branch from //depot/trunk/app.rb#1,#2
//depot/branches/release/app.rb#3 - merge from //depot/trunk/app.rb#3
//depot/branches/release/app.rb#2 - merge from //depot/trunk/app.rb#4
//depot/branches/release/app.rb#4 - copy from //depot/trunk/app.rb#5
```

### Scenario B — cherry-pick in trunk order (C3 then C4, then sweep)

```
$ p4 integrate //depot/trunk/...@3,@3 //depot/branches/release/...
$ p4 resolve -am //depot/branches/release/... ; p4 submit -d "cherry-pick C3"
$ p4 integrated //depot/branches/release/app.rb
//depot/branches/release/app.rb#1 - branch from //depot/trunk/app.rb#1,#2
//depot/branches/release/app.rb#2 - copy from //depot/trunk/app.rb#3

$ p4 integrate //depot/trunk/...@4,@4 //depot/branches/release/...
$ p4 resolve -am //depot/branches/release/... ; p4 submit -d "cherry-pick C4"
$ p4 integrated //depot/branches/release/app.rb
//depot/branches/release/app.rb#1 - branch from //depot/trunk/app.rb#1,#2
//depot/branches/release/app.rb#2 - copy from //depot/trunk/app.rb#3
//depot/branches/release/app.rb#3 - copy from //depot/trunk/app.rb#4

$ p4 integrate //depot/trunk/... //depot/branches/release/...
$ p4 resolve -am //depot/branches/release/... ; p4 submit -d "sweep merge"
$ p4 integrated //depot/branches/release/app.rb
//depot/branches/release/app.rb#1 - branch from //depot/trunk/app.rb#1,#2
//depot/branches/release/app.rb#2 - copy from //depot/trunk/app.rb#3
//depot/branches/release/app.rb#3 - copy from //depot/trunk/app.rb#4
//depot/branches/release/app.rb#4 - copy from //depot/trunk/app.rb#5
```

### What the records are telling you

Same content in both scenarios — `p4 diff2 //depot/trunk/... //depot/branches/release/...` reports `identical` for every file. The two depots converged.

But the integration verbs differ in a way SVN's mergeinfo and git's history don't expose at all:

- **Scenario A**: every cherry-pick is recorded as `merge from`. Cherry-picking C4 onto a branch that doesn't yet have C3 forced a three-way resolve under the hood — P4 noticed and labelled it.
- **Scenario B**: every cherry-pick is recorded as `copy from`. C3 then C4 in trunk order produced clean takes on each step.

The "verb that landed me here" is part of the audit trail. If you ever investigate why a release branch file diverges from trunk, knowing whether it got there via a `merge` or a `copy` (and from which exact source revision) is the question P4 answers and the question git can't.

The sweep `p4 integrate //depot/trunk/... //depot/branches/release/...` with no rev range consults the integration database and only re-applies revisions that haven't been credited yet — `r5` (C5) in our run. That's what P4 marketing meant by "merge tracking" decades before SVN tried to bolt the same idea on with `svn:mergeinfo`. The cost is that it's all *server-side* state, locked behind the depot — there's no offline, no pull-request workflow, and an `Unloaded depot` for archival is its own ceremony. The benefit is the integration history is structured, queryable per-file, and never gets out of sync with what was actually integrated.

### Reproducing the Perforce side

Scripts are on the `perforce-version` branch:

```
git checkout perforce-version
# install p4 + p4d — see https://www.perforce.com/downloads/helix-core
# (or the primer at github.com/paul-hammant/fast_perforce_setup)
./p4/start.sh                    # build trunk CL1..CL5 + release@CL2 on a sandbox p4d
./p4/scenario-a-out-of-order.sh  # cherry-pick C4 then C3, then sweep
./p4/rollback.sh                 # stop p4d, wipe p4-server/ and p4-wc/
./p4/scenario-b-in-order.sh      # cherry-pick C3 then C4, then sweep
```

The sandbox runs `p4d` on `localhost:1667` (not the conventional 1666), with no SSL and no security level set, so no passwords. Everything lives under `p4/p4-server` and `p4/p4-wc`; both are wiped on every run. Patches are applied with `patch -p1` for the same reason as the SVN scripts — `git apply` would notice the outer git worktree and refuse to write.

### So which VCS "knows what's been integrated"?

| | Records integration history? | Where it lives | What it records |
|---|---|---|---|
| **Git** | No | Nowhere (optional `(cherry picked from …)` comment, never read) | Nothing machine-checkable |
| **SVN** | Yes | `svn:mergeinfo` property on branch root | A revision-range string, e.g. `/trunk:4-9` |
| **Perforce** | Yes | Per-file integration database | Source path, source rev, integration verb (`branch`, `copy`, `merge`) |

All three converge on the same source tree when the underlying patches don't conflict. The difference is what the tool can *tell you afterwards* about how that tree got built — and therefore what kinds of "did the cherry-pick land safely?" questions you can ask the tool versus answer with tests.
