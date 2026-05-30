class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  helper_method :current_participant

  # Logged-in participant for the public portal (passwordless magic-link session).
  # nil unless a portal session is set. Distinct from current_admin_user (Devise).
  def current_participant
    return @current_participant if defined?(@current_participant)

    id = session[:portal_participant_id]
    @current_participant = id && Participant.kept.find_by(id: id)
  end
end
