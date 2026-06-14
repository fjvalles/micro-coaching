module PortalHelper
  # Tabs shown in the portal nav (bottom on mobile, top on desktop).
  # Each entry: [label, path, icon_key, active_controllers].
  # Grown phase by phase as each section ships.
  def portal_tabs
    [
      [ "Inicio", portal_root_path, :home, %w[dashboard] ]
    ]
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
      file:     '<path d="M6 3h8l4 4v14H6V3Z"/><path d="M14 3v4h4M9 13h6M9 17h6"/>'
    }
    body = paths.fetch(key, paths[:file])
    raw %(<svg viewBox="0 0 24 24" fill="none" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">#{body}</svg>)
  end
end
