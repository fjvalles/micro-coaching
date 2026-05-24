class AnalyzePromptJob < ApplicationJob
  queue_as :default

  def perform(prompt_template_id, sample_size: nil)
    template = PromptTemplate.find(prompt_template_id)
    critic = if sample_size.present?
      Openai::PromptCritic.new(template: template, sample_size: sample_size.to_i)
    else
      Openai::PromptCritic.new(template: template)
    end
    critic.call
  end
end
