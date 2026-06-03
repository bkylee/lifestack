# Phase 2: Infrastructure restart

The Phase 2 first pass was Claude-driven. On 2026-05-13 it was deliberately torn down — 29 Azure resources destroyed, the old code archived to `infra/.reference/` and `docs/.reference/` — and restarted under a hands-on cadence: Brian drives configuration and decisions, Claude scaffolds and mentors. The state backend storage account `stlifestack9k3l` survived the teardown.

The restart is organized into modules, each built in small steps. Steps follow the cadence in `docs/mentor/`.

---

## Module 1 — Resource groups + naming/tagging + multi-env scaffolding
*Commits: `5852f75` (Steps 1–2), `cf90dcb` (Step 3)*

Step 1 was `locals.tf` only — the values every later module reads. No Terraform run, no Azure change. See `docs/mentor/m1-s1-locals.md`.

Values settled: `lifestack` as the project name (short, lowercase, no special characters to stay inside Azure name-length budgets), `prod` as the environment, `eastus2` for location (newer hardware, no Postgres SKU restrictions like `eastus` had), and `base_tags` of project/environment/managed_by — `managed_by = terraform` is the signal that a resource is IaC-managed, not portal-created.

Step 2 added `main.tf`, `variables.tf`, `resource_groups.tf`, and the first `terraform apply`. Created the four prod RGs using `for_each` over the `rg_names` map in `locals.tf`. Split into tiers based on team/function — easier lifecycle management, cost reporting per tier, and access control. See `docs/mentor/m1-s2-resource-groups.md`.

Step 3 scaffolded `dev/` and `staging/` as sibling Terraform roots for potential future use when large changes need testing before production. No Azure resources created — scaffold only.

#### The DRY decision — light duplication ([D1])

Light duplication was chosen — no need to add another tool to learn (Terragrunt), and a shared root module is currently overkill for the few lines of HCL in use.

#### What varies per environment ([D2], [D3])

The only differences between environments are the state key in `backend.tf` and the `environment` value in `locals.tf`.




### Module 1, Step 4 — service doc + ADR-0005
*Commits: `07bf552` (ADR-0005), `e52a93c` (service doc edit pass)*

Brian drafted `docs/services/azure-resource-groups.md` covering all eight sections, then Claude did a line-by-line edit pass: merged the scaffold blockquote prompts into prose, removed all `>` remnants, fixed typos (`obersvability`, `storagge`), converted the "Why we use it" paragraph into a bulleted list matching the Mental model section, and added two alternatives to the Alternatives considered section that the draft had omitted (one-RG-per-resource and lifecycle/churn-rate grouping).

ADR-0005 covers the two multi-env decisions made in Module 1: deploy prod only in v1 (cost — no large migrations to justify extra envs yet), and use light duplication over Terragrunt or a shared root module (overkill at this HCL volume; Terragrunt earns its keep at 10+ envs). Both decisions are documented with explicit triggers for revisiting.

Module 1 complete.

---

## Module 2 — Network

> Entries added as steps complete.
