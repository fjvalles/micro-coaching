module Admin
  class SettingsController < BaseController
    CATEGORY_LABELS = {
      "timing"   => "Tiempos / Cadencia",
      "openai"   => "OpenAI",
      "whatsapp" => "WhatsApp / Meta",
      "program"  => "Programa",
      "admin"    => "Administración",
      "general"  => "General",
      "finances" => "Finanzas"
    }.freeze

    # Settings are a privileged surface — only superadmins may view or change them.
    before_action :require_superadmin
    before_action :set_setting, only: [ :edit, :update ]

    def index
      @grouped_settings = Setting.all.order(:category, :key).group_by(&:category)
      @category_labels  = CATEGORY_LABELS
    end

    def edit
    end

    def update
      if @setting.update(setting_params)
        redirect_to admin_settings_path, notice: "Configuración '#{@setting.key}' actualizada correctamente."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    private

    def set_setting
      @setting = Setting.find(params[:id])
    end

    def setting_params
      raw = params.require(:setting).permit(:value)
      # Browser sends checked checkboxes as "1" / unchecked as "0".
      # Normalize to canonical "true"/"false" strings before validation.
      if @setting.value_type == "boolean"
        raw[:value] = ActiveModel::Type::Boolean.new.cast(raw[:value]).to_s
      end
      raw
    end
  end
end
