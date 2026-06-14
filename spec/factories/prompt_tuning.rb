FactoryBot.define do
  factory :conversation_quality_score do
    window_start { 1.week.ago.beginning_of_week(:monday) }
    window_end { Time.current.beginning_of_week(:monday) }
    score { 62 }
    sample_size { 4 }
    subscores { { "compound_questions" => 40 } }
    examples { [ { "type" => "compound_questions", "body" => "¿A y B?" } ] }
  end

  factory :prompt_tuning_run do
    association :conversation_quality_score
    status { "proposed" }
    mode { "propose" }
    window_start { conversation_quality_score.window_start }
    window_end { conversation_quality_score.window_end }
    score { conversation_quality_score.score }
    current_guardrails { Setting::DEFAULT_FREE_CHAT_STYLE_GUARDRAILS }
    proposed_guardrails { "#{Setting::DEFAULT_FREE_CHAT_STYLE_GUARDRAILS}\n- Cuando detectes cansancio, cierra con una acción simple." }
    findings { { "examples" => [ { "type" => "compound_questions", "body" => "¿A y B?" } ] } }
    rationale { "Reduce preguntas compuestas." }
    change_kind { "append_bullet" }
  end
end
