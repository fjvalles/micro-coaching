require "rails_helper"

RSpec.describe ProgramAssistant::AgentRunner do
  let(:admin) { create(:admin_user) }
  let(:session) { admin.program_assistant_sessions.create!(status: :active) }

  def result(content:, tool_calls: nil, tin: 100, tout: 20)
    Openai::Client::Result.new(
      content: content, tokens_input: tin, tokens_output: tout,
      model: "gpt-5-mini", latency_ms: 5, tool_calls: tool_calls
    )
  end

  def tool_call(name, args)
    { "id" => "call_#{name}", "type" => "function",
      "function" => { "name" => name, "arguments" => args.to_json } }
  end

  before { session.program_assistant_messages.create!(role: :user, content: "¿qué programas hay?") }

  it "runs a read-tool round trip and persists a final answer" do
    create(:program, name: "Foco", slug: "foco")
    client = instance_double(Openai::Client)
    allow(client).to receive(:chat).and_return(
      result(content: "", tool_calls: [ tool_call("list_programs", {}) ]),
      result(content: "Tienes 1 programa.")
    )

    described_class.new(session: session, client: client).call

    tool_row = session.program_assistant_messages.find_by(role: :tool, tool_name: "list_programs")
    expect(tool_row.tool_result["count"]).to be >= 1
    expect(session.program_assistant_messages.where(role: :assistant).last.content).to eq("Tienes 1 programa.")
    expect(session.program_assistant_pending_actions).to be_empty
  end

  it "accumulates token usage onto the session" do
    client = instance_double(Openai::Client)
    allow(client).to receive(:chat).and_return(result(content: "ok", tin: 100, tout: 20))

    described_class.new(session: session, client: client).call

    expect(session.reload.tokens_input).to eq(100)
    expect(session.tokens_output).to eq(20)
  end

  it "instructs program fragments not to include greetings or signatures" do
    client = instance_double(Openai::Client)
    allow(client).to receive(:chat) do |args|
      prompt = args[:messages].first[:content]
      expect(prompt).to include("morning_template, iareto_text y checkin_questions son fragmentos")
      expect(prompt).to include("No incluyas saludo inicial")
      expect(prompt).to include("firma/remitente")
      expect(prompt).to include("español chileno natural")
      expect(prompt).to include("te late")
      result(content: "ok")
    end

    described_class.new(session: session, client: client).call
  end

  it "gates create_program: records a pending action and never writes inline" do
    client = instance_double(Openai::Client)
    spec = { name: "Nuevo", total_days: 1,
             days: [ { day_number: 1, phase: "see", title: "Día 1" } ] }
    allow(client).to receive(:chat).and_return(
      result(content: "", tool_calls: [ tool_call("create_program", spec) ])
    )
    expect { described_class.new(session: session, client: client).call }
      .not_to change(Program, :count)

    action = session.program_assistant_pending_actions.last
    expect(action).to be_pending
    expect(action.tool_name).to eq("create_program")
    tool_row = session.program_assistant_messages.find_by(role: :tool, tool_name: "create_program")
    expect(tool_row.tool_result["status"]).to eq("pending_approval")
  end

  it "returns an error result for an unknown tool" do
    client = instance_double(Openai::Client)
    allow(client).to receive(:chat).and_return(
      result(content: "", tool_calls: [ tool_call("drop_database", {}) ]),
      result(content: "listo")
    )

    described_class.new(session: session, client: client).call

    tool_row = session.program_assistant_messages.find_by(role: :tool, tool_name: "drop_database")
    expect(tool_row.tool_result["error"]).to match(/desconocida/)
  end

  it "stops when the token budget is exhausted" do
    Setting.set("program_assistant_token_budget_per_session", 1000)
    session.update!(tokens_input: 999, tokens_output: 999)
    client = instance_double(Openai::Client)

    described_class.new(session: session, client: client).call

    expect(session.program_assistant_messages.where(role: :assistant).last.content).to match(/Presupuesto/)
  end
end
