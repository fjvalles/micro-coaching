require "kramdown"
require "kramdown-parser-gfm"

module Admin
  module MarkdownHelper
    def render_markdown_file(relative_path)
      full = Rails.root.join(relative_path)
      return "".html_safe unless full.exist?

      Kramdown::Document.new(File.read(full), input: "GFM", hard_wrap: false).to_html.html_safe
    end
  end
end
