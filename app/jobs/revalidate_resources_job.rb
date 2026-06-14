class RevalidateResourcesJob < ApplicationJob
  queue_as :default

  def perform
    Resource.stale.find_each do |resource|
      was_approved = resource.approved?
      result = Resources::Verifier.new(resource: resource).call
      resource.discard! if resource.dead? || (was_approved && !result.ok?)
    end
  end
end
