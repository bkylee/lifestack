# Module 1, Step 3 — multi-environment directory scaffolding

**Files you will create (after deciding [D1]–[D3]):**
- `infra/environments/dev/{backend,versions,main,locals,resource_groups,variables}.tf` + `terraform.tfvars`
- `infra/environments/staging/{backend,versions,main,locals,resource_groups,variables}.tf` + `terraform.tfvars`
- `infra/environments/README.md` — multi-env policy (write after the .tf files; same way you wrote prod's)

**Decisions in this step:** [D1] DRY pattern, [D2] state key convention, [D3] what varies per env.

**Cadence note:** Step 1 and Step 2 had me scaffold the files first; this step is mentor-only because the main architectural call [D1] is about file *layout*, not file *values*. Pick [D1]–[D3], then you write the files from scratch using `prod/` as the structural reference — same cadence as Step 2.

**Out of scope this step:** ADR-0005 itself. That's Step 4 — you draft, I edit.

---

## What we're building

Sibling directories `dev/` and `staging/` next to `prod/`, each a self-contained Terraform root that *could* be `terraform init`-ed and applied if a trigger fired. In v1, neither one gets initialized. The point is to lock in the layout convention now, before Module 2 adds enough content that retrofitting hurts.

## Why this matters

There are two ways to defend multi-env IaC in an architect interview:

1. *"We had multi-env from day one and applied prod-only to control cost."*  ← what we're doing.
2. *"We started single-env and retrofitted multi-env after the first scary migration."*  ← the slower-to-explain answer.

Both are real. (1) is easier to defend because the trigger conditions are documented up front rather than reconstructed from memory. The retrofitting version usually leaves scars — hardcoded "prod" strings buried in modules, state-file gymnastics, "we'll clean it up later." Building the convention while the codebase is small avoids those scars.

Also: the marginal cost of scaffolding two empty env dirs *now* is ~10 minutes. The marginal cost of retrofitting *later* is roughly one weekend of carefully-grep-replace-prod across every module + a tense `terraform plan` you read with your jaw clenched.

## Step 3 scope

Just the directory layout and three decisions. No Azure changes — these envs aren't `terraform init`-ed.

After this step:
- Step 4: ADR-0005 (multi-env strategy) + the `services/azure-resource-groups.md` doc you draft and I edit.

---

## Decisions

### [D1] DRY pattern across environments

This is the architectural call. Three patterns to evaluate.

- **Textbook:** "Don't repeat yourself."
- **Production reality:** Terraform DRY has a long-running culture war. Three real-world patterns:
  1. **Light duplication.** Each env has its own copy of every `.tf` file. Values differ; structure matches. Stays consistent through code review and a "did you update all three?" habit.
  2. **Shared root module.** `infra/modules/foundation/` (or similar) contains the resources; each env directory is a thin `main.tf` that calls the module with env-specific variables. More DRY, more abstraction. Common in mid-sized orgs.
  3. **Terragrunt.** Third-party wrapper on top of Terraform. Each env has a `terragrunt.hcl` that points at a shared module and passes inputs. Solves the multi-env DRY problem completely, at the cost of being one more tool to install and debug.

- **Recommendation:** **light duplication.**
- **Reasoning:**
  - Total HCL per env at Module 1 = ~40 lines. Extracting a module means one indirection to navigate every time you read the code; at this size the indirection is harder to read than the duplication it removes.
  - You learn more by *feeling* the duplication pain first, then refactoring when it bites. Refactoring under duress teaches better than scaffolding-with-abstraction-on-day-one. (Same reason senior engineers say "wait for the third copy before extracting.")
  - Module 2 (network) is where this likely starts to hurt: VNets, subnets, NSGs, private DNS zones — maybe 80-150 lines of HCL per env. That's the natural trigger to refactor toward pattern 2 (shared root module).
  - Terragrunt is the wrong tool at our scale. It earns its keep at ~10+ environments, or when backend config (state-account names per env) needs templating. We have 3 envs sharing one storage account; the savings are nil.

- **Interview-defensibility angle:** "We started with light duplication, planned the refactor trigger up front (Module 2), and intentionally avoided Terragrunt because it's overkill for 3 envs." That's a textbook seasoned-architect answer — knowing *when* a tool earns its complexity is more impressive than reaching for the fancy one.

- **If you pick light duplication:** you write each `dev/` and `staging/` file by hand, using `prod/` as your structural reference. (Specific guidance in "What to do" below.)
- **If you pick shared root module:** ping me — the file layout changes meaningfully (we extract `prod/`'s resources into a module first, then each env becomes a thin caller). Worth scaffolding together.
- **If you pick Terragrunt:** I'd push back hard at this scale, but I'll lay out the migration if you want.

### [D2] Remote-state key naming

- **Textbook:** "Use separate state per environment."
- **Production reality:** the `key` field in `backend.tf` is the path inside the storage container. It determines which `.tfstate` blob this directory reads and writes. **If two env directories share a key, they corrupt each other's state.** This is the single most-important "do not get wrong" line in a multi-env setup.
- **Recommendation:** `prod.tfstate` / `dev.tfstate` / `staging.tfstate`. Bare filenames at the root of the container, matching what `prod/backend.tf` already uses.
- **Alternatives:**
  - `prod/terraform.tfstate` — folder-style. Some shops prefer it because it groups state for one env if you ever add per-module states (e.g. `prod/network.tfstate`).
  - `<env>-foundation.tfstate` — explicit module-name suffix. Useful if you later split state per module (which can reduce blast radius — a corrupted network state doesn't take out the app state).
- **Recommendation:** stay with bare `<env>.tfstate` for v1. We're using one Terraform root per env; the simplest names are the right names. If we ever split state per module within an env, we revisit then.

### [D3] What varies between envs

- **Textbook:** "Environments should be as similar as possible."
- **Production reality:** four kinds of differences are normal across envs; everything else should be alarmed-on as drift.

| Dimension | Should vary? | Today |
|---|---|---|
| Environment label / tag | Yes (by definition) | `prod` / `dev` / `staging` |
| State key | Yes (by safety) | matches env |
| Resource sizing (SKU, replicas, retention) | Yes — non-prod always smaller | N/A in Module 1 |
| Region | Maybe — only if testing multi-region | All `eastus2` for v1 |
| Project shortname | **No** | `lifestack` everywhere |
| Tag schema (which tag keys exist) | **No** | Same three tags |
| RG split (which RGs exist) | **No** | 4-way split in all envs |

- **Recommendation:** all three envs identical except for `environment`, state key, and the implied per-env resource names. Same region, same RG split, same subscription.
- **Choices you might make differently:**
  - **Different region for dev/staging** — useful only if you specifically want a regional-failover learning rep. Costs nothing, but adds a "why is dev in westus3" complication to every later module.
  - **Different subscription** — the variable is already there; just change `subscription_id` in the env's `terraform.tfvars`. Useful in real orgs (cost isolation, blast-radius isolation); overkill for a solo project on one sub.
  - **Different RG split per env** — e.g. flatten `dev/` to a single RG to feel both patterns. Legitimate learning move; the cost is that `dev/` no longer mirrors `prod/`'s structure, which makes later "diff prod vs dev" harder.

---

## What to do

1. **Decide first.** Fill in **Decisions Brian made** at the bottom of this file:
   - [D1] DRY pattern — light duplication, shared root module, or Terragrunt.
   - [D2] State key convention — `<env>.tfstate`, or something else.
   - [D3] What varies — confirm the "should vary / shouldn't vary" table, or call out anything you want different.

2. **Then write the files yourself** (assuming [D1] = light duplication). Same cadence as Step 2: `prod/` is your structural reference, but type each file by hand. The keystroke reps are what stick.

   For `infra/environments/dev/`:
   - `backend.tf` — copy prod's shape; change `key = "prod.tfstate"` to your [D2] choice for dev.
   - `versions.tf` — verbatim copy of prod's.
   - `main.tf` — verbatim copy of prod's (provider block + features).
   - `variables.tf` — verbatim copy of prod's (just `subscription_id`).
   - `terraform.tfvars` — same `subscription_id` as prod (one sub for v1), unless [D3] says otherwise.
   - `locals.tf` — same structure as prod's, but **trim the long [D1]–[D5] explanatory comments** (those were Step 1's decision-time prompts; you've already decided). Swap `environment = "prod"` → `environment = "dev"`. The `rg_names` block stays identical; the `${local.environment}` interpolation handles the per-env naming automatically.
   - `resource_groups.tf` — verbatim copy of prod's.

   Repeat for `infra/environments/staging/`.

   Notice what stays the same and what changes. That's the "what differs" table from [D3] becoming muscle memory.

3. **Do not run `terraform init` or `plan`.** These envs intentionally have no state. They're scaffold-only until a trigger fires.

4. **Run `terraform fmt`** from each new env directory to verify your formatting matches prod's. If `fmt` rewrites anything, that's information — read the diff before accepting.

5. **Write `infra/environments/README.md`** explaining the multi-env policy: why scaffold envs we don't deploy, what triggers would activate dev or staging, what differs between envs (the table from [D3]), and what DRY pattern is in use and why. This is your service-doc-style writeup for this step; I'll edit it line-by-line after you draft.

6. **Step 4 is ADR-0005.** After Step 3 commits, you write the first pass of ADR-0005 (multi-env strategy) following the template in CLAUDE.md. I edit.

## Side note — a typo in m1-s2

`docs/mentor/m1-s2-reource-groups.md` is missing an `s` in "resource." Worth a `git mv` to fix and an update in `docs/mentor/README.md` (and the index entry I'm about to add for this file). I haven't touched it — your call whether to fix it as part of this commit or in a separate cleanup pass.

## Decisions Brian made

_(Fill this in after committing. Format suggestion: bullet per decision with the picked value and a one-sentence reason — especially if you went against the recommendation.)_

- [D1] _DRY pattern = light duplication
  Originally wanted to go with terragrunt as I wanted to get exposure to more tools/services that an architect might use, but based on recommendation, it looks like overkill for a single project with only 3 envs. Adding another dependency when I'm still learning the fundamentals of Terraform can cause more headache when troubleshooting potential issues down the road with the use of GitHub actions 
- [D2] _State key convention = <env>.tfstate
- [D3] _What varies = recommended
