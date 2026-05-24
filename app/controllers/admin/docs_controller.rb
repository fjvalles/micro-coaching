require "kramdown"
require "kramdown-parser-gfm"

module Admin
  class DocsController < BaseController
    # Whitelist: slug → path relative to Rails.root. Prevents traversal.
    DOCS = {
      "business-rules" => {
        path:        "docs/business-rules.md",
        title:       "Reglas de Negocio",
        description: "Fuente canónica de cómo se comporta el programa."
      },
      "decisions" => {
        path:        "docs/decisions.md",
        title:       "Decisiones",
        description: "Por qué elegimos lo que elegimos durante la implementación."
      },
      "pedagogy" => {
        path:        "docs/pedagogy-coaching.md",
        title:       "Metodología y Pedagogía",
        description: "El marco cognitivo See-Choose-Anchor y la cadencia de micro-coaching."
      },
      "architecture" => {
        path:        "docs/architecture-flows.md",
        title:       "Arquitectura y Flujos",
        description: "Procesamiento asíncrono, webhooks de WhatsApp e integraciones de IA."
      },
      "admin-guide" => {
        path:        "docs/admin-guide.md",
        title:       "Manual del Administrador",
        description: "Cómo utilizar el panel de administración, gestionar participantes y auditar chats."
      },
      "commercial-strategy" => {
        path:        "docs/commercial-strategy.md",
        title:       "Estrategia Comercial",
        description: "Posicionamiento B2B, buyer inicial, ruta de pilotos y métricas de validación."
      },
      "lean-canvas" => {
        path:        "docs/lean-canvas.md",
        title:       "Lean Canvas",
        description: "Resumen del modelo de negocio, problema, solución, canales y ventaja inicial."
      },
      "dvf-analysis" => {
        path:        "docs/dvf-analysis.md",
        title:       "Análisis DVF",
        description: "Evaluación de deseabilidad, viabilidad y factibilidad de la oferta."
      },
      "customer-interviews" => {
        path:        "docs/customer-interviews.md",
        title:       "Entrevistas de Descubrimiento",
        description: "Guión y plantilla para conversar con buyers, sponsors y usuarios potenciales."
      },
      "offer-hormozi" => {
        path:        "docs/offer-hormozi.md",
        title:       "Oferta Irresistible",
        description: "Marco de oferta inspirado en 100M Leads adaptado al contexto B2B."
      },
      "brand-positioning" => {
        path:        "docs/brand-positioning.md",
        title:       "Marca y Posicionamiento",
        description: "Definición de Impulso by Comtraining, tagline y reglas de consistencia comercial."
      },
      "interaction-examples-reports" => {
        path:        "docs/interaction-examples-reports.md",
        title:       "Ejemplos e Interacciones",
        description: "Simulación de interacciones completas de 14 días y estrategia de reportes de valor para participantes y empresas."
      },
      "readme" => {
        path:        "README.md",
        title:       "README",
        description: "Stack, setup local y configuración de Meta Cloud API."
      },
      "claude" => {
        path:        "CLAUDE.md",
        title:       "Guía técnica",
        description: "Arquitectura, dominio y convenciones de código."
      }
    }.freeze

    def index
      @docs = DOCS.map do |slug, meta|
        full = Rails.root.join(meta[:path])
        meta.merge(slug: slug, exists: full.exist?, mtime: (File.mtime(full) if full.exist?))
      end
    end

    def show
      entry = DOCS[params[:id]]
      return head(:not_found) unless entry

      full = Rails.root.join(entry[:path])
      return head(:not_found) unless full.exist?

      @doc      = entry.merge(slug: params[:id])
      @mtime    = File.mtime(full)
      @html     = Kramdown::Document.new(File.read(full), input: "GFM", hard_wrap: false).to_html.html_safe
      @raw_path = entry[:path]
    end
  end
end
