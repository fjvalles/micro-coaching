module Finances
  # Single source of truth for USD operating costs over a time range:
  # OpenAI usage (priced from PromptExecution token counts) plus prorated manual
  # monthly fixed costs (from Settings). Shared by Admin::FinancesController (cost
  # detail) and Admin::ProfitLossController (consolidated P&L) so pricing and the
  # proration math live in exactly one place.
  class CostCalculator
    # Pricing per 1M tokens in USD (as of 2026-06).
    OPENAI_PRICING = {
      "gpt-5-nano"                  => { input: 0.05,  output: 0.40  },
      "gpt-5-mini"                  => { input: 0.25,  output: 2.00  },
      "gpt-5.4-nano"                => { input: 0.20,  output: 1.25  },
      "gpt-5.4-mini"                => { input: 0.75,  output: 4.50  },
      "gpt-5.4"                     => { input: 2.50,  output: 15.00 },
      "gpt-4.1-mini"              => { input: 0.40,  output: 1.60  },
      "gpt-4.1-nano"              => { input: 0.10,  output: 0.40  },
      "gpt-4.1"                   => { input: 2.00,  output: 8.00  },
      "gpt-4o-mini"               => { input: 0.15,  output: 0.60  },
      "gpt-4o"                    => { input: 5.00,  output: 15.00 },
      "gpt-4o-mini-transcribe"    => { input: 1.25,  output: 5.00,  minute: 0.003 },
      "gpt-4o-transcribe"         => { input: 2.50,  output: 10.00, minute: 0.006 },
      # VoiceAnalyzer sends audio input; PromptExecution does not yet split text
      # vs audio tokens, so use audio-token pricing to avoid undercounting.
      "gpt-4o-mini-audio-preview" => { input: 10.00, output: 20.00 },
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
      :ai_by_participant, :ai_by_program,
      :manual_monthly, :manual_total, :total_cost, :period_months,
      keyword_init: true
    )

    def initialize(range)
      @range = range
    end

    def call
      ai             = compute_ai_costs_by_model
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
        ai_by_participant: compute_ai_costs_by_dimension(:participant_id),
        ai_by_program: compute_ai_costs_by_dimension(:program_id),
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

    def compute_ai_costs_by_model
      PromptExecution.where(created_at: @range)
        .group(:model_used)
        .select(
          :model_used,
          "COUNT(*) AS calls",
          "SUM(tokens_input) AS total_input",
          "SUM(tokens_output) AS total_output",
          "SUM(billable_seconds) AS total_billable_seconds"
        )
        .map do |row|
          pricing    = pricing_for(row.model_used)
          tokens_in  = row.total_input.to_i
          tokens_out = row.total_output.to_i
          billable_seconds = row.total_billable_seconds.to_i
          cost = cost_for(tokens_in, tokens_out, pricing, billable_seconds)
          {
            model:      row.model_used || "desconocido",
            calls:      row.calls.to_i,
            tokens_in:  tokens_in,
            tokens_out: tokens_out,
            billable_seconds: billable_seconds,
            cost:       cost
          }
        end
        .sort_by { |r| -r[:cost] }
    end

    def compute_ai_costs_by_dimension(dimension)
      grouped = {}

      PromptExecution.where(created_at: @range)
        .group(dimension, :model_used)
        .select(
          dimension,
          :model_used,
          "COUNT(*) AS calls",
          "SUM(tokens_input) AS total_input",
          "SUM(tokens_output) AS total_output",
          "SUM(billable_seconds) AS total_billable_seconds"
        )
        .each do |row|
          dimension_id = row.public_send(dimension)
          grouped[dimension_id] ||= empty_dimension_row(dimension_id)

          tokens_in = row.total_input.to_i
          tokens_out = row.total_output.to_i
          billable_seconds = row.total_billable_seconds.to_i
          grouped[dimension_id][:calls] += row.calls.to_i
          grouped[dimension_id][:tokens_in] += tokens_in
          grouped[dimension_id][:tokens_out] += tokens_out
          grouped[dimension_id][:billable_seconds] += billable_seconds
          grouped[dimension_id][:cost] += cost_for(tokens_in, tokens_out, pricing_for(row.model_used), billable_seconds)
        end

      label_dimension_rows(grouped.values, dimension)
        .sort_by { |r| -r[:cost] }
    end

    def empty_dimension_row(id)
      {
        id: id,
        name: nil,
        calls: 0,
        tokens_in: 0,
        tokens_out: 0,
        billable_seconds: 0,
        cost: 0.0
      }
    end

    def label_dimension_rows(rows, dimension)
      labels = labels_for(rows.filter_map { |r| r[:id] }, dimension)

      rows.map do |row|
        row.merge(name: labels[row[:id]] || fallback_label_for(dimension))
      end
    end

    def labels_for(ids, dimension)
      case dimension
      when :participant_id
        Participant.kept.where(id: ids).pluck(:id, :name, :phone_e164).to_h do |id, name, phone|
          [ id, [ name, phone ].compact_blank.join(" · ") ]
        end
      when :program_id
        Program.where(id: ids).pluck(:id, :name).to_h
      else
        {}
      end
    end

    def fallback_label_for(dimension)
      case dimension
      when :participant_id then "Sin participante o archivado"
      when :program_id then "Sin programa"
      else "Sin clasificar"
      end
    end

    def cost_for(tokens_in, tokens_out, pricing, billable_seconds = 0)
      (tokens_in / 1_000_000.0 * pricing[:input]) +
        (tokens_out / 1_000_000.0 * pricing[:output]) +
        (billable_seconds.to_i / 60.0 * pricing.fetch(:minute, 0.0))
    end

    def pricing_for(model)
      OPENAI_PRICING[model] ||
        OPENAI_PRICING[base_model_name(model)] ||
        DEFAULT_PRICING
    end

    def base_model_name(model)
      model.to_s.sub(/-\d{4}-\d{2}-\d{2}\z/, "")
    end
  end
end
