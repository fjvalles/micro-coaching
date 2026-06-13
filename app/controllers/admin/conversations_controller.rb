module Admin
  class ConversationsController < BaseController
    before_action :set_conversation, only: [ :show, :destroy, :retry ]

    def index
      if params[:tab] == "unknown"
        @unknown_inbounds = UnknownInbound.order(received_at: :desc).limit(200)
        return
      end

      scope = Conversation.all

      # Search body, message id, template name
      if params[:q].present?
        scope = scope.where("body ILIKE :q OR whatsapp_message_id ILIKE :q OR whatsapp_template_name ILIKE :q", q: "%#{params[:q]}%")
      end

      # Filter by role
      if params[:role].present?
        scope = scope.where(role: params[:role])
      end

      # Filter by moment
      if params[:moment].present?
        scope = scope.where(moment: params[:moment])
      end

      # Filter by participant_id
      if params[:participant_id].present?
        scope = scope.where(participant_id: params[:participant_id])
      end

      # Filter by program
      if params[:program_id].present?
        if params[:program_id] == "none"
          scope = scope.joins(:participant).where(participants: { program_id: nil })
        else
          scope = scope.joins(:participant).where(participants: { program_id: params[:program_id] })
        end
      end

      # Filter by day number
      if params[:day_number].present?
        scope = scope.where(day_number: params[:day_number])
      end

      # Filter by delivery status
      if params[:delivery_status].present?
        if params[:delivery_status] == "error"
          scope = scope.failed
        elsif params[:delivery_status] == "success"
          scope = scope.where(error_message: nil)
        end
      end

      # Filter by created_at date range
      if params[:created_from].present?
        begin
          scope = scope.where("created_at >= ?", Time.zone.parse(params[:created_from]).beginning_of_day)
        rescue ArgumentError, TypeError
        end
      end
      if params[:created_to].present?
        begin
          scope = scope.where("created_at <= ?", Time.zone.parse(params[:created_to]).end_of_day)
        rescue ArgumentError, TypeError
        end
      end

      # Filter by message type (template / free-form)
      if params[:message_type].present?
        case params[:message_type]
        when "template" then scope = scope.where.not(whatsapp_template_name: nil)
        when "free"     then scope = scope.where(whatsapp_template_name: nil)
        end
      end

      # Filter by AI generation (tokens consumed)
      if params[:ai_generated].present?
        scope = params[:ai_generated] == "yes" ? scope.where("tokens_input > 0 OR tokens_output > 0") : scope.where(tokens_input: [ nil, 0 ], tokens_output: [ nil, 0 ])
      end

      # Simple pagination (using limit and offset)
      @page = (params[:page] || 1).to_i
      @per_page = 25
      @total_count = scope.count
      @total_pages = (@total_count.to_f / @per_page).ceil

      @programs = Program.ordered
      @conversations = scope.includes(:participant)
                            .order(created_at: :desc)
                            .limit(@per_page)
                            .offset((@page - 1) * @per_page)
    end

    def show
    end

    def destroy
      @conversation.destroy
      redirect_to admin_conversations_path, notice: "Mensaje eliminado."
    end

    def retry
      if @conversation.role != "assistant" || @conversation.error_message.blank?
        return redirect_back fallback_location: admin_conversations_path, alert: "Este mensaje no se puede reintentar."
      end

      client = Whatsapp::Client.new
      response = nil

      if @conversation.whatsapp_template_name.present?
        prefix = "[template:#{@conversation.whatsapp_template_name}] "
        variables = if @conversation.body.to_s.start_with?(prefix)
                      @conversation.body.to_s.sub(prefix, "").split(" | ")
        else
                      []
        end

        components = []
        if variables.any?
          components = [ {
            type: "body",
            parameters: variables.map { |v| { type: "text", text: v.to_s } }
          } ]
        end

        response = client.send_template(
          to: @conversation.participant.phone_e164,
          template_name: @conversation.whatsapp_template_name,
          components: components
        )
      else
        response = client.send_text(
          to: @conversation.participant.phone_e164,
          body: @conversation.body
        )
      end

      if response.success?
        @conversation.update!(
          whatsapp_message_id: response.wamid,
          sent_at: Time.current,
          error_message: nil
        )
        redirect_back fallback_location: admin_conversations_path, notice: "Mensaje reintentado con éxito."
      else
        @conversation.update!(error_message: response.error)
        redirect_back fallback_location: admin_conversations_path, alert: "El reintento falló: #{response.error}"
      end
    end

    private

    def set_conversation
      @conversation = Conversation.find(params[:id])
    end
  end
end
