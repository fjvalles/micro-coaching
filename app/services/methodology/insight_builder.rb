module Methodology
  class InsightBuilder
    PHASES = %w[see choose anchor].freeze
    STUCK_REPEAT_THRESHOLD = 3
    PROMPT_BEFORE_AFTER_WINDOW = 30

    def self.call(**kwargs)
      new(**kwargs).call
    end

    def initialize(program: nil, clusterer: nil)
      @program   = program
      @clusterer = clusterer || Openai::PatternClusterer.new(program: program)
    end

    def call
      [
        build_key_pattern_cluster,
        build_voice_trend_by_phase,
        build_prompt_finding_digest,
        build_phase_kpi,
        build_stuck_pattern,
        build_prompt_evolution
      ].compact
    end

    private

    attr_reader :program, :clusterer

    def persist(scope, payload, window_start: nil, window_end: nil)
      MethodologyInsight.create!(
        scope: scope,
        payload: payload,
        program_id: program&.id,
        generated_at: Time.current,
        window_start: window_start,
        window_end: window_end
      )
    end

    # ---- key_pattern_cluster ----------------------------------------------

    def build_key_pattern_cluster
      result = clusterer.call
      persist(
        "key_pattern_cluster",
        {
          "clusters" => result.clusters,
          "total_reports_analyzed" => result.total_reports_analyzed,
          "model" => result.model
        }
      )
    end

    # ---- voice_trend_by_phase ---------------------------------------------

    def build_voice_trend_by_phase
      phases_payload = PHASES.each_with_object({}) do |phase, acc|
        rows = inbound_conversations_for_phase(phase)
                 .where("voice_analysis::text <> ?", "{}")
                 .pluck(:voice_analysis)

        tones, energies = aggregate_voice(rows)
        acc[phase] = {
          "tone_histogram" => tones,
          "energy_avg" => energies[:avg],
          "sample_size" => rows.size
        }
      end

      persist("voice_trend_by_phase", { "phases" => phases_payload })
    end

    def inbound_conversations_for_phase(phase)
      participant_ids = participants_in_phase(phase)
      return Conversation.none if participant_ids.empty?

      Conversation.kept
                  .where(role: :user, participant_id: participant_ids)
                  .where.not(voice_analysis: nil)
    end

    def participants_in_phase(phase)
      day_numbers = DayContent.where(program_id: program_ids_filter).where(phase: phase).pluck(:day_number).uniq
      return [] if day_numbers.empty?

      scope = Participant.kept.where(current_day: day_numbers)
      scope = scope.where(program_id: program.id) if program
      scope.pluck(:id)
    end

    def program_ids_filter
      program ? [ program.id ] : Program.pluck(:id)
    end

    def aggregate_voice(rows)
      tones = Hash.new(0)
      energy_sum = 0.0
      energy_count = 0

      rows.each do |va|
        next unless va.is_a?(Hash)
        tone = va["tone"] || va["emotion"]
        tones[tone.to_s] += 1 if tone.present?
        energy = va["energy"]
        if energy.is_a?(Numeric)
          energy_sum += energy
          energy_count += 1
        end
      end

      avg = energy_count.positive? ? (energy_sum / energy_count).round(2) : nil
      [ tones, { avg: avg } ]
    end

    # ---- prompt_finding_digest --------------------------------------------

    def build_prompt_finding_digest
      analyses = PromptAnalysis.recent.limit(30).includes(:prompt_template)
      weakness_counts = Hash.new(0)
      templates_seen  = []

      analyses.each do |a|
        Array((a.findings || {})["weaknesses"]).each do |w|
          weakness_counts[w.to_s] += 1 if w.present?
        end
        next unless a.prompt_template
        templates_seen << {
          "template_id" => a.prompt_template.id,
          "key" => a.prompt_template.key,
          "name" => a.prompt_template.name,
          "analyzed_at" => a.created_at.iso8601
        }
      end

      recurring = weakness_counts.sort_by { |_w, n| -n }.first(15).map { |w, n| { "weakness" => w, "count" => n } }

      persist(
        "prompt_finding_digest",
        {
          "recurring_weaknesses" => recurring,
          "templates_with_recent_analysis" => templates_seen.uniq { |t| t["template_id"] }.first(20),
          "analyses_sampled" => analyses.size
        }
      )
    end

    # ---- phase_kpi --------------------------------------------------------

    def build_phase_kpi
      phases_payload = PHASES.each_with_object({}) do |phase, acc|
        participant_ids = participants_in_phase(phase)
        if participant_ids.empty?
          acc[phase] = blank_phase_kpi
          next
        end

        outgoing_checkins = Conversation.kept.where(participant_id: participant_ids, moment: :checkin_question).count
        inbound_responses = Conversation.kept.where(participant_id: participant_ids, moment: :checkin_response, role: :user).count
        audio_responses   = Conversation.kept.where(participant_id: participant_ids, moment: :checkin_response, role: :user).where.not(media_id: nil).count
        body_chars        = Conversation.kept.where(participant_id: participant_ids, moment: :checkin_response, role: :user).pluck(:body, :transcription)

        avg_chars = if body_chars.any?
          total = body_chars.sum { |body, transcription| (body || transcription).to_s.length }
          (total.to_f / body_chars.size).round(1)
        else
          0.0
        end

        response_rate = outgoing_checkins.positive? ? ((inbound_responses.to_f / outgoing_checkins) * 100).round(1) : 0.0
        audio_share   = inbound_responses.positive? ? ((audio_responses.to_f / inbound_responses) * 100).round(1) : 0.0

        completed = Participant.kept.where(id: participant_ids, status: :completed).count
        completion_rate = participant_ids.size.positive? ? ((completed.to_f / participant_ids.size) * 100).round(1) : 0.0

        acc[phase] = {
          "participants" => participant_ids.size,
          "response_rate" => response_rate,
          "avg_response_chars" => avg_chars,
          "audio_share" => audio_share,
          "completion_rate" => completion_rate
        }
      end

      persist("phase_kpi", { "phases" => phases_payload })
    end

    def blank_phase_kpi
      {
        "participants" => 0,
        "response_rate" => 0.0,
        "avg_response_chars" => 0.0,
        "audio_share" => 0.0,
        "completion_rate" => 0.0
      }
    end

    # ---- stuck_pattern ----------------------------------------------------

    def build_stuck_pattern
      participants_scope = Participant.kept.active
      participants_scope = participants_scope.where(program_id: program.id) if program

      stuck = []
      participants_scope.find_each do |p|
        recent_reports = p.daily_reports.where.not(ai_key_pattern: [ nil, "" ]).order(day_number: :desc).limit(5)
        grouped = recent_reports.group_by { |r| r.ai_key_pattern.to_s.downcase.strip }
        repeated = grouped.find { |_pattern, rs| rs.size >= STUCK_REPEAT_THRESHOLD }
        next unless repeated

        pattern, reports = repeated
        stuck << {
          "participant_id" => p.id,
          "participant_name" => p.name,
          "repeated_pattern" => pattern,
          "days" => reports.map(&:day_number),
          "daily_report_ids" => reports.map(&:id)
        }
      end

      persist("stuck_pattern", { "participants" => stuck, "threshold" => STUCK_REPEAT_THRESHOLD })
    end

    # ---- prompt_evolution -------------------------------------------------

    def build_prompt_evolution
      templates = PromptTemplate.kept.ordered
      payload = templates.map do |tmpl|
        versions = tmpl.prompt_versions.chronological.map do |v|
          before_window, after_window = window_for_version(tmpl, v)
          {
            "n" => v.version,
            "applied_at" => v.created_at.iso8601,
            "origin" => v.origin,
            "tokens_avg_before" => before_window[:tokens_avg],
            "tokens_avg_after" => after_window[:tokens_avg],
            "latency_avg_before" => before_window[:latency_avg],
            "latency_avg_after" => after_window[:latency_avg]
          }
        end

        {
          "template_id" => tmpl.id,
          "key" => tmpl.key,
          "name" => tmpl.name,
          "current_version" => tmpl.current_version,
          "versions" => versions
        }
      end

      persist("prompt_evolution", { "templates" => payload })
    end

    def window_for_version(template, version)
      before = template.prompt_executions
                       .where("created_at < ?", version.created_at)
                       .order(created_at: :desc).limit(PROMPT_BEFORE_AFTER_WINDOW)
      after = template.prompt_executions
                      .where(prompt_version_id: version.id)
                      .order(created_at: :asc).limit(PROMPT_BEFORE_AFTER_WINDOW)
      [ aggregate_executions(before), aggregate_executions(after) ]
    end

    def aggregate_executions(scope)
      rows = scope.pluck(:tokens_input, :tokens_output, :latency_ms)
      return { tokens_avg: nil, latency_avg: nil } if rows.empty?

      tokens = rows.map { |i, o, _| (i.to_i + o.to_i) }
      lats   = rows.map { |_, _, l| l }.compact
      {
        tokens_avg: (tokens.sum.to_f / tokens.size).round(1),
        latency_avg: lats.any? ? (lats.sum.to_f / lats.size).round(1) : nil
      }
    end
  end
end
