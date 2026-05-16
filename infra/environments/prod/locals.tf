# =============================================================================
# Module 1, Step 1 — foundational locals
#
# This file holds the "knobs" the rest of prod/ will reference: project token,
# environment label, region, base tags, and the resource-group naming scheme.
#
# Decisions for you to make are marked [D1]..[D5]. Fill them in, then send back
# for review BEFORE running `terraform plan`.
# =============================================================================

locals {
  # ---------------------------------------------------------------------------
  # [D1] Project shortname.
  #
  # What it does:
  #   A short token that goes into every resource name (e.g. "rg-${project}-...",
  #   "kv-${project}-...", "acr${project}...").
  #
  # Constraints:
  #   - Lowercase alphanumeric only. Some Azure resources (storage, ACR) reject
  #     hyphens; the safe path is no hyphens anywhere so one token works
  #     everywhere.
  #   - 3-12 chars is the practical sweet spot. Storage accounts cap at 24 chars
  #     TOTAL (incl. suffixes) and ACR caps at 50.
  #
  # See mentor message for examples + recommendation.
  # ---------------------------------------------------------------------------
  project = "lifestack"

  # ---------------------------------------------------------------------------
  # [D2] Environment label for THIS directory.
  #
  # What it does:
  #   Goes into resource names and the `environment` tag.
  #
  # This file lives under environments/prod/, so this is mostly a labels
  # question: do you write it as "prod" (short) or "production" (verbose)?
  # Azure has no preference. Whatever you pick, the dev/ and staging/ dirs
  # later will mirror it ("dev" vs "development", "staging" vs "stage").
  # ---------------------------------------------------------------------------
  environment = "prod"

  # ---------------------------------------------------------------------------
  # [D3] Azure region.
  #
  # What it does:
  #   Default location for every resource group in this environment.
  #
  # Constraints / consequences:
  #   - Single region in v1. Cross-region traffic costs money and complicates
  #     private DNS, so all v1 resources live in one region.
  #   - Two practical East-coast picks: "eastus" (older, sometimes capacity-
  #     constrained for newer SKUs, no AZ guarantee for cheap tiers) and
  #     "eastus2" (newer, better availability-zone coverage, gets new feature
  #     rollouts first).
  #   - West-coast equivalents: "westus2" / "westus3".
  #
  # See mentor message for recommendation.
  # ---------------------------------------------------------------------------
  location = "eastus2"

  # ---------------------------------------------------------------------------
  # [D4] Base tags — applied to every resource we create in this env.
  #
  # Why tag at all:
  #   Tags are how you slice cost reports, identify ownership during incidents,
  #   and let Azure Policy / governance rules target the right resources later.
  #   Real-world architect interview question: "how do you know which subscription
  #   resource X belongs to a team?" Answer: tags + policy enforcement.
  #
  # Minimum baseline:
  #   - project     — which app/system
  #   - environment — prod/dev/staging
  #   - managed_by  — "terraform" (so manual changes stand out as drift)
  #
  # Common adds: owner (email/team), cost_center, criticality, data_class.
  # For a solo project the minimum baseline is fine. Add anything you'd want
  # to filter cost-explorer or alerts by.
  # ---------------------------------------------------------------------------
  base_tags = {
    project     = local.project
    environment = local.environment
    managed_by  = "terraform"
    # [D4] Add or remove tags here. Keep it intentional — every tag is one more
    # thing to keep consistent across all modules.
  }

  # ---------------------------------------------------------------------------
  # [D5] Resource group naming + split strategy.
  #
  # The decision:
  #   Do you put every resource in ONE resource group, or split across multiple
  #   RGs by tier (e.g. network / data / app / observability)?
  #
  # Trade-offs:
  #   FLAT (one RG)
  #     + Simpler. Easier to grant access ("contributor on this RG = full env").
  #     + One blast-radius boundary to think about.
  #     - Cost reports lump everything together — harder to answer
  #       "how much does the data tier cost vs the app tier?"
  #     - Granular RBAC ("DBAs can touch data, not network") is harder.
  #
  #   SPLIT (per-tier RGs — what the old first-pass code used)
  #     + Tier-level RBAC: e.g. only DBAs get Contributor on rg-...-data-...
  #     + Cost reports naturally roll up by tier.
  #     + Lets you destroy/recreate one tier without touching others.
  #     - More RGs to track. Slightly more provider boilerplate.
  #     - Easy to over-engineer if you only have one team (you).
  #
  # See mentor message for recommendation.
  #
  # Pick ONE of the two patterns below and uncomment+fill it. Delete the other.
  # ---------------------------------------------------------------------------

  # Split option — one RG per tier. Match the keys to the tiers you actually
  # plan to use. (Old first-pass used: network, data, app, observability.)
  rg_names = {
    network       = "rg-${local.project}-network-${local.environment}"
    data          = "rg-${local.project}-data-${local.environment}"
    app           = "rg-${local.project}-app-${local.environment}"
    observability = "rg-${local.project}-observability-${local.environment}"
  }
}
