# Module 1, Step 1 — foundational locals

**Scaffold file:** `infra/environments/prod/locals.tf`
**Decisions in this step:** [D1] project shortname, [D2] environment label, [D3] region, [D4] base tags, [D5] RG split strategy.

---

## What we're building this module

The wiring under `environments/prod/` that holds the project-wide knobs (naming, tags, region) and creates the resource groups. After Module 1, the Azure subscription will once again have RGs in it — but only RGs, no expensive resources. Module 2 onward fills them.

## Why this comes first

Every later module (`network`, `key_vault`, `acr`, …) will reference `local.project`, `local.location`, `local.base_tags`, and `local.rg_names`. Lock these in correctly now and the rest of the modules are short. Get them wrong (e.g. pick a project name that's > 12 chars and now your storage-account names overflow Azure's 24-char limit) and you fix it everywhere later.

## Step 1 scope

Just `locals.tf`. Five decisions [D1]–[D5]. Once those are in I review, then we move to:
- Step 2: `resource_groups.tf` + provider config in `main.tf`
- Step 3: multi-env dir scaffolding (`dev/`, `staging/`)
- Step 4: ADR-0005 + service doc

---

## Decisions

### [D1] Project shortname

- **Textbook:** "Use a consistent naming convention."
- **Production reality:** Azure has 6+ different naming-rule sets across resource types. Storage and ACR forbid hyphens; Key Vault caps names at 24 chars; storage caps at 24 chars *including* any random suffix you add to make it globally unique. Pick a short, lowercase, hyphen-free token NOW and you avoid playing tetris with name-length budgets later.
- **Examples:** `lifestack` (9 chars — fine), `lstk` (4 — very safe), `lstack` (6 — fine).
- **Recommendation:** **`lifestack`**. The old first-pass used it, you'll spell it dozens of times, and it's still well under the 24-char storage cap with room for a suffix (e.g. `stlifestackprod` + 4 random = 19 chars, fits).

### [D2] Environment label

- **Textbook:** "Tag and name resources by environment."
- **Production reality:** there's no Azure-side technical difference between `prod` and `production`. The only reason to care is consistency across all your tooling — alert rules, dashboards, log queries, RBAC scopes all hard-code the string. Pick once, never change.
- **Recommendation:** **`prod`**. Three chars, common, matches the directory name. The dev/staging dirs will use `dev` and `staging` later.

### [D3] Azure region

- **Textbook:** "Pick a region near your users."
- **Production reality:** The old first-pass used **`eastus2`**. It's the better default than `eastus` for a few reasons: newer hardware generations show up here first, availability-zone coverage is real (even the cheap SKUs sit in zone-aware infrastructure), and feature rollouts (e.g. new Postgres versions, new Front Door capabilities) land here before they propagate. `eastus` is older, more capacity-constrained, and occasionally throws "SKU not available in this region" errors that `eastus2` doesn't.
- **Cost note:** identical pricing between the two for everything we'll use.
- **Recommendation:** **`eastus2`**. Unless you're on the west coast and want lower personal-latency dev (in which case `westus3`).

### [D4] Base tags

- **Textbook:** "Tag everything."
- **Production reality:** You will use these tags. Real interview answer to "how do you find which resources belong to project X": `az resource list --tag project=lifestack`. Real answer to "which env got hit by the outage": cost-explorer grouped by `environment` tag. The provider doesn't have a `default_tags` block (AWS does; azurerm doesn't, which is annoying), so each module accepts a `tags` input and we pass `local.base_tags` through.
- **Schema discussion:** The three I've included (`project`, `environment`, `managed_by`) are the minimum that pays for itself. `managed_by = "terraform"` matters: when you spot a resource WITHOUT it, you know someone clicked something in the portal and you have drift. Optional adds I'd skip for a solo project: `owner` (it's always you), `cost_center` (no chargeback), `data_class` (overkill until you have real PII concerns — you don't yet at this stage).
- **Recommendation:** **leave the three baseline tags as-is. Don't add more yet.** You can add them later in one place and they propagate.

### [D5] RG split strategy

- **Textbook:** "Use resource groups to organize related resources."
- **Production reality:** This is the genuinely-architectural call of this step, and it's where the old first-pass quietly made a choice for you. The first-pass split into four RGs (`network`, `data`, `app`, `observability`).
- **Why the split was chosen then:** it mirrors how real orgs structure RBAC — DBAs get Contributor on the data RG, network team gets Contributor on the network RG, app team gets app + observability. It also makes the cost view "what does my database tier cost" trivially answerable.
- **Why you might NOT want it for a solo project:** you're every team. Splitting introduces friction (more for_each, more outputs to plumb between modules) for an RBAC story that doesn't exist for you.
- **Interview defensibility angle:** if you go FLAT and an interviewer asks "how would you scale this to a team?", the answer is "I'd split by tier — here's why." If you go SPLIT, the answer is "here's how I structured RBAC by tier — here's why." Both are defensible. Split is harder to defend if you can't articulate the RBAC story; flat is harder to defend if you can't articulate when you'd split.
- **Recommendation:** **SPLIT, with the four tiers from the old code (`network`, `data`, `app`, `observability`).** Reasoning: (a) the learning value of working with multiple RGs and seeing how modules consume them is higher than the friction cost, (b) it makes the cost discussion in `docs/operations/cost.md` legitimately useful later, (c) it's the more common production pattern and you want interview reps with it. Pick `flat` only if you have a strong intuition that the split friction will demotivate you.

---

## What to do

1. Open `infra/environments/prod/locals.tf`.
2. Fill in [D1]–[D5]. For [D5], pick ONE option block and uncomment+adjust; delete the other.
3. **Do not run `terraform plan` yet.** Send back for review first — typos and naming-collision risks are cheaper to catch before the plan call.
4. When you're ready for Step 2, ask and I'll scaffold `resource_groups.tf` and the provider config.

## Decisions Brian made

_(Fill this in after you commit the values, so the file is a complete record of what was chosen and why. Format suggestion: bullet per decision with the picked value and a one-sentence reason — especially if you went against the recommendation.)_

- [D1] _project = `…`_
- [D2] _environment = `…`_
- [D3] _location = `…`_
- [D4] _base tags = `…`_
- [D5] _RG strategy = `…`_
