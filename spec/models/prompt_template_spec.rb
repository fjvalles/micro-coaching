require "rails_helper"

RSpec.describe PromptTemplate do
  describe "#record_version!" do
    let(:template) { create(:prompt_template, current_body: "initial", current_version: 0) }

    it "creates a new version when body changes" do
      v = template.record_version!(body: "v1 body", change_note: "first")
      expect(v.version).to eq(1)
      expect(template.reload.current_version).to eq(1)
      expect(template.current_body).to eq("v1 body")
    end

    it "does not create duplicate when body unchanged" do
      template.record_version!(body: "same")
      expect { template.record_version!(body: "same") }.not_to change(PromptVersion, :count)
    end

    it "increments version monotonically" do
      template.record_version!(body: "a")
      template.record_version!(body: "b")
      v3 = template.record_version!(body: "c")
      expect(v3.version).to eq(3)
    end
  end
end
