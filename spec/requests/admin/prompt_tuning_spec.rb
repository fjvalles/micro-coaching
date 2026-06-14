require "rails_helper"

RSpec.describe "Admin::PromptTuning", type: :request do
  include Warden::Test::Helpers

  let(:superadmin) { create(:admin_user, superadmin: true) }
  let(:regular) { create(:admin_user, email: "regular-prompt-tuning@example.com") }

  after { Warden.test_reset! }

  it "requires superadmin access" do
    login_as(regular, scope: :admin_user)

    get "/admin/prompt_tuning"

    expect(response).to have_http_status(:forbidden)
  end

  it "lists prompt tuning runs" do
    login_as(superadmin, scope: :admin_user)
    create(:prompt_tuning_run, rationale: "Reduce preguntas compuestas.")

    get "/admin/prompt_tuning"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Reduce preguntas compuestas")
  end

  it "approves a pending proposal" do
    login_as(superadmin, scope: :admin_user)
    Setting.set("free_chat_style_guardrails", Setting::DEFAULT_FREE_CHAT_STYLE_GUARDRAILS)
    run = create(:prompt_tuning_run)

    post "/admin/prompt_tuning/#{run.id}/approve"

    expect(response).to redirect_to(admin_prompt_tuning_path(run))
    expect(run.reload.status).to eq("applied")
    expect(Setting.fetch("free_chat_style_guardrails")).to include("cansancio")
  end

  it "rejects a pending proposal" do
    login_as(superadmin, scope: :admin_user)
    run = create(:prompt_tuning_run)

    post "/admin/prompt_tuning/#{run.id}/reject"

    expect(response).to redirect_to(admin_prompt_tuning_index_path)
    expect(run.reload.status).to eq("rejected")
  end
end
