module Admin
  class ResponseModesController < BaseController
    def update
      scope = params[:scope].to_s
      mode  = params[:mode].to_s
      mode  = nil if mode == "inherit"

      case scope
      when "global"
        if mode.nil?
          redirect_back fallback_location: admin_root_path, alert: "Modo global no puede ser inherit."
          return
        end
        Setting.set("response_mode", mode)
      when "program"
        program = Program.find(params[:program_id])
        program.update!(response_mode: mode)
      when "participant"
        participant = Participant.kept.find(params[:participant_id])
        participant.update!(response_mode: mode)
      else
        redirect_back fallback_location: admin_root_path, alert: "Scope inválido." and return
      end

      redirect_back fallback_location: admin_root_path, notice: "Modo de respuesta actualizado."
    end
  end
end
