module Conversations
  class QualityScorer
    Result = Struct.new(:score, :subscores, :examples, :sample_size, :window_start, :window_end, keyword_init: true)

    BODY_TERMS = /cuerpo|garganta|pecho|respiraci[oó]n|sensaci[oó]n|pesadez|tensi[oó]n/i
    ACK_PREFIXES = [
      /\Agracias por/i,
      /\Aperfecto,?\s+gracias/i,
      /\Aentiendo/i,
      /\Ate leo/i
    ].freeze
    QUESTION_FRAGMENT = /¿[^?]+(?:\s+y\s+|\s+o\s+)[^?]+\?/i
    WEIGHTS = {
      compound_questions: 20,
      repeated_acknowledgments: 15,
      somatic_loop: 20,
      asymmetry: 20,
      cap_with_engagement: 10,
      insistence: 15
    }.freeze

    def initialize(conversations:)
      @conversations = conversations.to_a.sort_by(&:created_at)
    end

    def call
      examples = []
      penalties = {
        compound_questions: compound_questions_penalty(examples),
        repeated_acknowledgments: repeated_acknowledgments_penalty(examples),
        somatic_loop: somatic_loop_penalty(examples),
        asymmetry: asymmetry_penalty(examples),
        cap_with_engagement: cap_with_engagement_penalty(examples),
        insistence: insistence_penalty(examples)
      }

      total_penalty = penalties.sum { |type, value| value * WEIGHTS.fetch(type) / 100.0 }
      score = (100 - total_penalty).round.clamp(0, 100)
      Result.new(
        score: score,
        subscores: penalties.transform_values { |value| (100 - value).round.clamp(0, 100) },
        examples: examples.first(8),
        sample_size: @conversations.size,
        window_start: @conversations.first&.created_at,
        window_end: @conversations.last&.created_at
      )
    end

    private

    def assistant_messages
      @assistant_messages ||= @conversations.select(&:assistant?)
    end

    def user_messages
      @user_messages ||= @conversations.select(&:user?)
    end

    def compound_questions_penalty(examples)
      offenders = assistant_messages.select do |conversation|
        body = conversation.body.to_s
        body.count("?") > 1 || body.match?(QUESTION_FRAGMENT)
      end
      add_examples(examples, :compound_questions, offenders)
      ratio_penalty(offenders.size, assistant_messages.size, scale: 0.25)
    end

    def repeated_acknowledgments_penalty(examples)
      offenders = assistant_messages.each_cons(2).filter_map do |previous, current|
        current if acknowledgment_key(previous.body) && acknowledgment_key(previous.body) == acknowledgment_key(current.body)
      end
      add_examples(examples, :repeated_acknowledgments, offenders)
      ratio_penalty(offenders.size, [ assistant_messages.size - 1, 0 ].max, scale: 0.35)
    end

    def somatic_loop_penalty(examples)
      offenders = assistant_messages.each_cons(3).filter_map do |group|
        group.last if group.all? { |conversation| conversation.body.to_s.match?(BODY_TERMS) }
      end
      add_examples(examples, :somatic_loop, offenders)
      ratio_penalty(offenders.size, [ assistant_messages.size - 2, 0 ].max, scale: 0.25)
    end

    def asymmetry_penalty(examples)
      ratios = conversation_pairs.filter_map do |user, assistant|
        next if user.body.to_s.length < 10

        assistant.body.to_s.length.to_f / user.body.to_s.length
      end
      return 0 if ratios.empty?

      average = ratios.sum / ratios.size
      if average > 4.0
        offender = conversation_pairs.max_by { |user, assistant| assistant.body.to_s.length.to_f / [ user.body.to_s.length, 1 ].max }&.last
        add_examples(examples, :asymmetry, [ offender ].compact)
      end
      (((average - 2.5) / 3.5) * 100).round.clamp(0, 100)
    end

    def cap_with_engagement_penalty(examples)
      cap = Setting.fetch("max_free_messages_per_day").to_i
      return 0 unless cap.positive?

      grouped = user_messages.select { |conversation| conversation.moment == "free_user" }
                             .group_by { |conversation| [ conversation.participant_id, conversation.created_at.in_time_zone(conversation.participant.timezone).to_date ] }
      offenders = grouped.values.filter_map { |messages| messages.last if messages.size >= cap }
      add_examples(examples, :cap_with_engagement, offenders)
      ratio_penalty(offenders.size, grouped.size, scale: 0.2)
    end

    def insistence_penalty(examples)
      offenders = []
      assistant_messages.each_cons(2) do |previous, current|
        previous_question = normalized_question(previous.body)
        current_question = normalized_question(current.body)
        next if previous_question.blank? || current_question.blank?

        offenders << current if previous_question == current_question
      end
      add_examples(examples, :insistence, offenders)
      ratio_penalty(offenders.size, [ assistant_messages.size - 1, 0 ].max, scale: 0.25)
    end

    def conversation_pairs
      pairs = []
      pending_user = nil
      @conversations.each do |conversation|
        pending_user = conversation if conversation.user?
        if conversation.assistant? && pending_user
          pairs << [ pending_user, conversation ]
          pending_user = nil
        end
      end
      pairs
    end

    def acknowledgment_key(body)
      normalized = body.to_s.squish.downcase
      ACK_PREFIXES.find { |pattern| normalized.match?(pattern) }&.source
    end

    def normalized_question(body)
      question = body.to_s.scan(/¿([^?]+)\?/).flatten.first.to_s
      question.downcase.gsub(/[^\p{Alnum}\s]/, "").squish.presence
    end

    def ratio_penalty(count, total, scale:)
      return 0 if count.zero? || total.zero?

      ((count.to_f / total) / scale * 100).round.clamp(0, 100)
    end

    def add_examples(examples, type, conversations)
      conversations.first(2).each do |conversation|
        examples << {
          type: type.to_s,
          conversation_id: conversation.id,
          participant_id: conversation.participant_id,
          body: conversation.body.to_s.truncate(350),
          created_at: conversation.created_at&.iso8601
        }
      end
    end
  end
end
