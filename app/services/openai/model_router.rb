module Openai
  class ModelRouter
    DEFAULT_MODEL = "gpt-4.1-mini".freeze

    TASK_DEFAULTS = {
      preview_challenge: "gpt-5-nano",
      morning_message: "gpt-5-mini",
      free_response: "gpt-5-mini",
      inbound_intent_classifier: "gpt-5-nano",
      checkin_summarizer: "gpt-5-nano",
      participant_summary: "gpt-5-nano",
      skill_tagger: "gpt-5-nano",
      manifesto: "gpt-5-mini",
      pattern_clusterer: "gpt-5-nano",
      prompt_critic: "gpt-5-mini",
      guardrail_proposer: "gpt-5-mini",
      copilot: "gpt-5-mini",
      program_assistant: "gpt-5-mini",
      program_generator: "gpt-5-mini",
      resource_finder: "gpt-4o-search-preview",
      resource_verifier: "gpt-5-nano",
      resource_gap_detector: "gpt-5-nano"
    }.freeze

    def self.for(task)
      key = setting_key(task)
      configured = key ? Setting.fetch(key).presence : nil
      configured || Setting.fetch("openai_model").presence || default_for(task)
    end

    def self.default_for(task)
      TASK_DEFAULTS[task.to_s.to_sym] || DEFAULT_MODEL
    end

    def self.setting_key(task)
      task_key = task.to_s
      return nil unless TASK_DEFAULTS.key?(task_key.to_sym)

      "openai_model_#{task_key}"
    end
  end
end
