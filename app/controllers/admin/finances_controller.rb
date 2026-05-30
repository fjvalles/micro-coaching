module Admin
  class FinancesController < BaseController
    include PeriodFilterable

    # Pricing per 1M tokens in USD (as of 2025-05)
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

    def index
      @period = params[:period] || "this_month"
      @range  = period_range(@period)

      executions = PromptExecution.where(created_at: @range)

      @ai_by_model = compute_ai_costs(executions)
      @ai_total    = @ai_by_model.sum { |r| r[:cost] }
      @ai_tokens_in  = @ai_by_model.sum { |r| r[:tokens_in] }
      @ai_tokens_out = @ai_by_model.sum { |r| r[:tokens_out] }
      @ai_calls      = @ai_by_model.sum { |r| r[:calls] }

      period_months   = months_in_range(@range)
      @manual_monthly = {
        hosting: Setting.fetch("cost_hosting_monthly_usd").to_f,
        email:   Setting.fetch("cost_email_monthly_usd").to_f,
        meta:    Setting.fetch("cost_meta_api_monthly_usd").to_f,
        ads:     Setting.fetch("cost_ads_monthly_usd").to_f,
        other:   Setting.fetch("cost_other_monthly_usd").to_f
      }
      @manual_total = @manual_monthly.values.sum * period_months

      @total_cost = @ai_total + @manual_total

      participants_in_period = Participant.kept
        .where("enrolled_at <= ? AND (completed_at IS NULL OR completed_at >= ?)", @range.end, @range.begin)
      @participant_count = participants_in_period.count

      @program_count = Program.where(active: true).count

      @period_months   = period_months
      @avg_monthly     = period_months > 0 ? @total_cost / period_months : 0
      @avg_participant = @participant_count > 0 ? @total_cost / @participant_count : 0
      @avg_program     = @program_count > 0 ? @total_cost / @program_count : 0

      @period_label = period_label(@period)
    end

    private

    def months_in_range(range)
      days = (range.end - range.begin) / 1.day
      [ days / 30.0, 0.1 ].max
    end

    def compute_ai_costs(executions)
      executions
        .group(:model_used)
        .select(
          :model_used,
          "COUNT(*) AS calls",
          "SUM(tokens_input) AS total_input",
          "SUM(tokens_output) AS total_output"
        )
        .map do |row|
          pricing = OPENAI_PRICING[row.model_used] || DEFAULT_PRICING
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
