resource "azurerm_consumption_budget_subscription" "monthly" {
  name            = "lifestack-monthly"
  subscription_id = "/subscriptions/${var.subscription_id}"

  amount     = 100
  time_grain = "Monthly"

  time_period {
    start_date = "2026-05-01T00:00:00Z"
    end_date   = "2030-05-01T00:00:00Z"
  }

  notification {
    enabled        = true
    threshold      = 80
    operator       = "GreaterThan"
    threshold_type = "Actual"
    contact_emails = ["brian.ky.lee@outlook.com"]
  }

  notification {
    enabled        = true
    threshold      = 100
    operator       = "GreaterThanOrEqualTo"
    threshold_type = "Actual"
    contact_emails = ["brian.ky.lee@outlook.com"]
  }

  notification {
    enabled        = true
    threshold      = 100
    operator       = "GreaterThan"
    threshold_type = "Forecasted"
    contact_emails = ["brian.ky.lee@outlook.com"]
  }
}
