module Resources
  class Catalog
    def initialize(program: nil, limit: 30)
      @program = program
      @limit = limit
    end

    def call
      resources.map do |resource|
        "- #{resource.id}: #{resource.title} (#{resource.kind}) — temas: #{resource.topics.join(', ')}"
      end.join("\n")
    end

    def resources
      Resource.sendable
        .for_program(@program)
        .order(:title)
        .limit(@limit)
    end
  end
end
