module Portal
  class SessionsController < ApplicationController
    layout "portal"

    def new
    end

    # Request a magic link. Always responds the same way so we never reveal
    # whether an email is registered.
    def create
      email = params[:email].to_s.downcase.strip
      if email.present?
        participant = Participant.kept.where("lower(email) = ?", email).first
        if participant&.email.present?
          token = participant.generate_token_for(:portal_login)
          ParticipantMailer.magic_link(participant.id, token).deliver_later
        end
      end

      redirect_to portal_login_path, notice: "Si tu correo está registrado, te enviamos un enlace de acceso."
    end

    # Consume the magic link.
    def show
      participant = Participant.find_by_token_for(:portal_login, params[:token])
      if participant && participant.kept?
        reset_session # prevent session fixation
        session[:portal_participant_id] = participant.id
        redirect_to portal_root_path, notice: "¡Hola de nuevo, #{participant.name}!"
      else
        redirect_to portal_login_path, alert: "El enlace es inválido o expiró. Solicita uno nuevo."
      end
    end

    def destroy
      reset_session
      redirect_to portal_login_path, notice: "Cerraste tu sesión."
    end
  end
end
