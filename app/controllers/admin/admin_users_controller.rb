module Admin
  class AdminUsersController < BaseController
    before_action :set_admin_user, only: [ :show, :edit, :update, :destroy ]

    def index
      @admin_users = AdminUser.all.order(:email)
    end

    def show
    end

    def new
      @admin_user = AdminUser.new
    end

    def edit
    end

    def create
      @admin_user = AdminUser.new(admin_user_params)
      if @admin_user.save
        redirect_to admin_admin_users_path, notice: "Usuario administrador creado exitosamente."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def update
      # Support updating email/password. Skip password validation if empty.
      params_to_update = admin_user_params
      if params_to_update[:password].blank? && params_to_update[:password_confirmation].blank?
        params_to_update.delete(:password)
        params_to_update.delete(:password_confirmation)
      end

      if @admin_user.update(params_to_update)
        redirect_to admin_admin_users_path, notice: "Usuario administrador actualizado."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      if AdminUser.count <= 1
        redirect_to admin_admin_users_path, alert: "No puedes eliminar el único usuario administrador restante."
        return
      end

      if @admin_user == current_admin_user
        redirect_to admin_admin_users_path, alert: "No puedes eliminarte a ti mismo."
        return
      end

      @admin_user.destroy
      redirect_to admin_admin_users_path, notice: "Usuario administrador eliminado."
    end

    private

    def set_admin_user
      @admin_user = AdminUser.find(params[:id])
    end

    def admin_user_params
      params.require(:admin_user).permit(:name, :email, :password, :password_confirmation, :superadmin)
    end
  end
end
