module PortalHelper
  # Tabs shown in the portal nav (bottom on mobile, top on desktop).
  # Each entry: [label, path, icon_key, active_controllers].
  # Grown phase by phase as each section ships.
  def portal_tabs
    [
      [ "Inicio",   portal_root_path,      :home,     %w[dashboard] ],
      [ "Programa", portal_program_path,   :map,      %w[programs] ],
      [ "Recursos", portal_resources_path, :bookmark, %w[resources] ],
      [ "Pagos",    portal_billing_path,   :receipt,  %w[billings] ],
      [ "Perfil",   portal_profile_path,   :user,     %w[profiles] ]
    ]
  end

  SUBSCRIPTION_STATUS = {
    "pending"  => [ "Pendiente", "pill-warn" ],
    "active"   => [ "Activa", "pill-ok" ],
    "past_due" => [ "Pago pendiente", "pill-warn" ],
    "canceled" => [ "Cancelada", "pill-muted" ],
    "paused"   => [ "Pausada", "pill-muted" ]
  }.freeze

  PAYMENT_STATUS = {
    "pending"    => [ "Pendiente", "pill-warn" ],
    "authorized" => [ "Pagado", "pill-ok" ],
    "rejected"   => [ "Rechazado", "pill-warn" ],
    "failed"     => [ "Fallido", "pill-warn" ],
    "aborted"    => [ "Cancelado", "pill-muted" ],
    "refunded"   => [ "Reembolsado", "pill-info" ]
  }.freeze

  def portal_subscription_status(status)
    SUBSCRIPTION_STATUS.fetch(status.to_s, [ status.to_s.humanize, "pill-muted" ])
  end

  def portal_payment_status(status)
    PAYMENT_STATUS.fetch(status.to_s, [ status.to_s.humanize, "pill-muted" ])
  end

  def portal_clp(amount)
    "$#{number_with_delimiter(amount.to_i, delimiter: '.')} CLP"
  end

  PHASE_LABEL = { "see" => "Ver", "choose" => "Elegir", "anchor" => "Anclar" }.freeze

  def portal_phase_label(phase)
    PHASE_LABEL.fetch(phase.to_s, phase.to_s.humanize)
  end

  RESOURCE_KIND_ICON = { "video" => :video, "article" => :article, "audio_ref" => :headphones }.freeze
  RESOURCE_KIND_LABEL = { "video" => "Video", "article" => "Artículo", "audio_ref" => "Audio" }.freeze

  def portal_resource_icon(kind)
    portal_icon(RESOURCE_KIND_ICON.fetch(kind, :link))
  end

  def portal_resource_label(kind)
    RESOURCE_KIND_LABEL.fetch(kind, "Recurso")
  end

  def portal_tab_active?(controllers)
    controllers.include?(controller_name)
  end

  # Minimal inline outline icons (stroke = currentColor via CSS).
  def portal_icon(key)
    paths = {
      home:     '<path d="M3 11.5 12 4l9 7.5"/><path d="M5 10v10h14V10"/>',
      map:      '<path d="m9 5-6 2v14l6-2 6 2 6-2V5l-6 2-6-2Z"/><path d="M9 5v14M15 7v14"/>',
      bookmark: '<path d="M6 4h12v16l-6-4-6 4V4Z"/>',
      receipt:  '<path d="M6 3h12v18l-2-1.5L14 21l-2-1.5L10 21l-2-1.5L6 21V3Z"/><path d="M9 8h6M9 12h6"/>',
      user:     '<circle cx="12" cy="8" r="4"/><path d="M4 21c0-4 4-6 8-6s8 2 8 6"/>',
      link:     '<path d="M9 15 15 9"/><path d="M11 6.5 13 4.5a4 4 0 0 1 6 6l-2 2"/><path d="M13 17.5 11 19.5a4 4 0 0 1-6-6l2-2"/>',
      file:     '<path d="M6 3h8l4 4v14H6V3Z"/><path d="M14 3v4h4M9 13h6M9 17h6"/>',
      video:    '<rect x="3" y="5" width="14" height="14" rx="2"/><path d="m17 9 4-2v10l-4-2Z"/>',
      article:  '<path d="M5 4h11l3 3v13H5V4Z"/><path d="M8 9h8M8 13h8M8 17h5"/>',
      headphones: '<path d="M4 13a8 8 0 0 1 16 0"/><rect x="3" y="13" width="4" height="7" rx="1.5"/><rect x="17" y="13" width="4" height="7" rx="1.5"/>',
      check:    '<path d="m5 12 4 4L19 7"/>',
      external: '<path d="M14 4h6v6"/><path d="M20 4 10 14"/><path d="M19 14v5H5V5h5"/>',
      calendar: '<rect x="4" y="5" width="16" height="16" rx="2"/><path d="M8 3v4M16 3v4M4 11h16"/>'
    }
    body = paths.fetch(key, paths[:file])
    raw %(<svg viewBox="0 0 24 24" fill="none" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">#{body}</svg>)
  end
end
