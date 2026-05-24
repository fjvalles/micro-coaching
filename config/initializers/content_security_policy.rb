# Be sure to restart your server when you modify this file.

Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self
    policy.font_src    :self, :https, :data
    policy.img_src     :self, :https, :data
    policy.object_src  :none
    policy.script_src  :self, :https, :unsafe_inline  # Turbo/Stimulus require inline
    policy.style_src   :self, :https, :unsafe_inline   # cssbundling inline styles
    policy.connect_src :self
    policy.frame_ancestors :none
  end
end
