module Finances
  # Single source of truth for USD operating costs over a time range:
  # OpenAI usage (priced from PromptExecution token counts) plus prorated manual
  # monthly fixed costs (from Settings). Shared by Admin::FinancesController (cost
  # detail) and Admin::ProfitLossController (consolidated P&L) so pricing and the
  # proration math live in exactly one place.
  class CostCalculator
    # Pricing per 1M tokens in USD (as of 2025-05).
    OPENAI_PRICING = {
      "gpt-4.1-mini"              => { input: 0.40,  output: 1.60  },
      "gpt-4.1"                   => { input: 2.00,  output: 8.00  },
      "gpt-4o-mini"               => { input: 0.15,  output: 0.60  },
      "gpt-4o"                    => { input: 5.00,  output: 15.00 },
      "gpt-4o-mini-transcribe"    => { input: 1.25,  output: 5.00  },
      "gpt-4o-transcribe"         => { input: 2.50,  output: 10.00 },
      "gpt-4o-mini-audio-preview" => { input: 0.10,  output: 0.20  },
      "gpt-4o-audio-preview"      => { input: 2.50,  output: 10.00 }
    }.freeze
    DEFAULT_PRICING = { input: 0.40, output: 1.60 }.freeze

    # Manual monthly fixed-cost Settings, keyed by the symbol the views expect.
    MANUAL_COST_KEYS = {
      hosting: "cost_hosting_monthly_usd",
      email:   "cost_email_monthly_usd",
      meta:    "cost_meta_api_monthly_usd",
      ads:     "cost_ads_monthly_usd",
      other:   "cost_other_monthly_usd"
    }.freeze

    Result = Struct.new(
      :ai_by_model, :ai_total, :ai_tokens_in, :ai_tokens_out, :ai_calls,
      :manual_monthly, :manual_total, :total_cost, :period_months,
      keyword_init: true
    )

    def initialize(range)
      @range = range
    end

    def call
      ai             = compute_ai_costs
      months         = period_months
      manual_monthly = MANUAL_COST_KEYS.transform_values { |key| Setting.fetch(key).to_f }
      manual_total   = manual_monthly.values.sum * months
      ai_total       = ai.sum { |r| r[:cost] }

      Result.new(
        ai_by_model:   ai,
        ai_total:      ai_total,
        ai_tokens_in:  ai.sum { |r| r[:tokens_in] },
        ai_tokens_out: ai.sum { |r| r[:tokens_out] },
        ai_calls:      ai.sum { |r| r[:calls] },
        manual_monthly: manual_monthly,
        manual_total:  manual_total,
        total_cost:    ai_total + manual_total,
        period_months: months
      )
    end

    private

    # Fractional months in the range (min 0.1 so a same-day range still prorates).
    def period_months
      days = (@range.end - @range.begin) / 1.day
      [ days / 30.0, 0.1 ].max
    end

    def compute_ai_costs
      PromptExecution.where(created_at: @range)
        .group(:model_used)
        .select(
          :model_used,
          "COUNT(*) AS calls",
          "SUM(tokens_input) AS total_input",
          "SUM(tokens_output) AS total_output"
        )
        .map do |row|
          pricing    = OPENAI_PRICING[row.model_used] || DEFAULT_PRICING
          tokens_in  = row.total_input.to_i
          tokens_out = row.total_output.to_i
          cost = (tokens_in / 1_000_000.0 * pricing[:input]) +
                 (tokens_out / 1_000_000.0 * pricing[:output])
          {
            model:      row.model_used || "desconocido",
            calls:      row.calls.to_i,
            tokens_in:  tokens_in,
            tokens_out: tokens_out,
            cost:       cost
          }
        end
        .sort_by { |r| -r[:cost] }
    end
  end
end
