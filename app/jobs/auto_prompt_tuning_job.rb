class AutoPromptTuningJob < ApplicationJob
  queue_as :default

  def perform(now = Time.current)
    return unless Setting.fetch("auto_prompt_tuning_enabled")

    mode = Setting.fetch("auto_prompt_tuning_mode").to_s
    return unless PromptTuningRun::MODES.include?(mode)

    window_end = now.beginning_of_week(:monday)
    window_start = window_end - 1.week
    return if PromptTuningRun.for_window(window_start, window_end).exists?

    quality_score = score_window(window_start, window_end)
    rollback_if_regressed!(quality_score.score)

    run = PromptTuningRun.create!(
      conversation_quality_score: quality_score,
      status: mode == "observe" ? "observed" : "no_change",
      mode: mode,
      window_start: window_start,
      window_end: window_end,
      score: quality_score.score,
      current_guardrails: current_guardrails,
      findings: {
        "subscores" => quality_score.subscores,
        "examples" => quality_score.examples
      }
    )

    return if mode == "observe"
    return if quality_score.score >= Setting.fetch("auto_tuning_score_threshold").to_i

    propose_or_apply!(run, quality_score, mode)
  end

  private

  def score_window(window_start, window_end)
    conversations = Conversation.kept
      .includes(:participant)
      .where(created_at: window_start...window_end)
      .where(moment: %w[free_user free_assistant], role: %w[user assistant])
      .order(:created_at)
      .limit(Setting.fetch("auto_tuning_sample_size").to_i)

    result = Conversations::QualityScorer.new(conversations: conversations).call
    ConversationQualityScore.create!(
      window_start: window_start,
      window_end: window_end,
      score: result.score,
      sample_size: result.sample_size,
      subscores: result.subscores,
      examples: result.examples,
      metadata: { "source" => "auto_prompt_tuning_job" }
    )
  end

  def propose_or_apply!(run, quality_score, mode)
    proposal = Openai::GuardrailProposer.new(
      current_guardrails: current_guardrails,
      quality_result: quality_score
    ).call

    run.update!(
      status: proposal.change_kind == "no_change" ? "no_change" : "proposed",
      proposed_guardrails: proposal.proposed_guardrails,
      rationale: proposal.rationale,
      change_kind: proposal.change_kind,
      findings: run.findings.merge("llm" => proposal.findings)
    )
    PromptTuningRun.capture_observability("Prompt tuning proposed", run_id: run.id, score: run.score) if run.proposed?
    PromptTuningMailer.proposal(run.id).deliver_later if run.proposed?
    return unless mode == "apply" && run.proposed?

    run.apply!
  end

  def rollback_if_regressed!(new_score)
    applied = PromptTuningRun.applied.where.not(baseline_score: nil).recent.first
    return unless applied

    margin = Setting.fetch("auto_tuning_rollback_margin").to_i
    return unless new_score < applied.baseline_score.to_i - margin

    applied.rollback!(post_score: new_score)
  end

  def current_guardrails
    Setting.fetch("free_chat_style_guardrails").to_s.presence ||
      Setting::DEFAULT_FREE_CHAT_STYLE_GUARDRAILS
  end
end
