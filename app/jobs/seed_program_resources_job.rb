class SeedProgramResourcesJob < ApplicationJob
  queue_as :default

  def perform(program_id, topics)
    return unless Setting.fetch("resource_catalog_enabled") || Setting.fetch("resource_autodiscovery_enabled")

    program = Program.find_by(id: program_id)
    return unless program

    Array(topics).map(&:to_s).reject(&:blank?).uniq.each do |topic|
      result = Resources::Finder.new(topic: topic, kind: "article", program: program, source: :program_seed).call
      result.resources.each do |resource|
        Resources::Verifier.new(resource: resource, topic: topic).call
      end
    end
  end
end
