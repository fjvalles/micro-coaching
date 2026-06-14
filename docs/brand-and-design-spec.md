# Especificación de Diseño y Branding — Impulso by Comtraining

Este documento consolida la identidad visual, el sistema de diseño y las decisiones de branding adoptadas tras el reposicionamiento B2B de la plataforma. Sirve de guía para mantener consistencia en la web pública, el panel de administración y futuras interfaces.

---

## 1. Identidad de Marca y Posicionamiento

*   **Nombre de Marca:** Impulso by Comtraining
*   **Tagline Principal:** Logra eso que te propones, un paso a la vez.
*   **Enfoque (landing pública, B2C):** Coaching personal por WhatsApp. La persona **elige qué quiere mejorar** (dormir mejor, moverte más, tener calma, lo que sea) y recibe un micro-reto diario hecho a su medida durante 14 días. Respaldado por la metodología de Comtraining con supervisión humana. No se presenta como "bot" ni "terapia". (El posicionamiento B2B original —transferencia conductual para líderes— se conserva para la venta corporativa, pero la landing prioriza al individuo.)
*   **Valores de Diseño (Territorio Verbal & Visual):**
    *   **Cálido y cercano:** Tema claro, acogedor, nunca clínico ni frío. Caras y lenguaje humano.
    *   **Personal:** Todo gira en torno a "tú eliges el foco"; el programa se adapta a la persona.
    *   **Positivo:** Sin palabras negativas. Se habla de lo que se gana, no de lo que falla.
    *   **Claro y liviano:** Poco texto, mucho aire, secciones bien diferenciadas. Regla de claridad en 5 segundos.

---

## 2. Paleta de Colores y Tipografía

El sistema de diseño usa variables CSS nativas sobre un **tema claro y cálido** (definido en `app/assets/stylesheets/landing.css`). Pensado para legibilidad en todas las edades y para transmitir confianza/calidez propia del coaching.

### Colores Clave
*   **Fondo Principal (`--bg`):** `#fcf8f2` (crema cálido) con suaves blooms de luz orgánicos.
*   **Fondo Alterno (`--bg-soft`):** `#f4eede` — para alternar secciones y darles ritmo visual.
*   **Fondo de Tarjetas (`--bg-card`):** `#ffffff`.
*   **Texto (`--text-main` / `--text-soft`):** `#21272f` / `#59616e` (alto contraste sobre crema).
*   **Bordes (`--border`):** `#ece3d3` (cálido, suave).
*   **Acento Primario (`--primary`):** `#0f9d72` (Verde esmeralda WhatsApp, legible sobre crema).
*   **Acento Secundario (`--accent`):** `#e07a4f` (terracota cálido, para realces).

### Tipografía
*   **Títulos:** `Outfit` (Tipografía sans-serif con personalidad geométrica y moderna).
*   **Cuerpo de Texto:** `Inter` (Estándar de legibilidad excepcional para textos ejecutivos y flujos de lectura en interfaces).

---

## 3. Marca Gráfica (Logo y Favicon)

Se ha creado un logotipo vectorial único ubicado en `public/icon.svg`.

### El Concepto del Logo Mark:
Consiste en dos barras/cápsulas paralelas inclinadas a -30 grados que ascienden de izquierda a derecha.
*   La barra izquierda representa la **capacitación inicial** y las intenciones del participante.
*   La barra derecha, más alta y con mayor desarrollo, representa el **impulso y la conducta sostenida** en el puesto de trabajo.
*   Un círculo esmeralda brillante en la parte superior derecha simboliza el **logro del objetivo y la ejecución diaria**.
*   El logotipo se utiliza tanto en el Favicon de la landing page como en el header de navegación pública.

### Favicon e Integración en Rails:
El archivo de diseño `public/icon.svg` se carga dinámicamente usando:
```html
<link rel="icon" href="/icon.svg" type="image/svg+xml">
<link rel="apple-touch-icon" href="/icon.png">
```

---

## 4. Motion Design e Interactividad (Landing Page)

Para "maravillar" al cliente corporativo y demostrar el producto sin fricción, se implementaron dos dinámicas animadas e interactivas claves:

### A. El Simulador Interactivo de Conversación (WhatsApp)
En el Hero de la página, en lugar de una captura estática, se diseñó un teléfono interactivo que simula una conversación de WhatsApp en tiempo real.
*   **Selector de Ejemplos (cotidianos, B2C):** La persona elige entre 4 focos de la vida diaria:
    1.  *Dormir mejor*.
    2.  *Moverte más* (volver al ejercicio sin presión).
    3.  *Tener más calma*.
    4.  *Estar presente* (tiempo real con los tuyos).
*   **Animación de Escritura (Typing Effect):** El chat se borra y escribe dinámicamente los globos usando un indicador de carga (`typing-bubble-sim`) simulando las respuestas de la IA y el usuario real.

### B. Otras secciones clave
*   **"¿Qué te gustaría mejorar?"** — grilla de focos cotidianos (chips) + nota "tú eliges el foco y tu programa se arma a tu medida". Comunica **personalización + abanico de posibilidades**.
*   **"Cómo funciona"** — 3 pasos simples y positivos.
*   **Coach / confianza** — foto + nombre + credencial del coach de Comtraining (placeholders marcados con `TODO` en `index.html.erb` hasta tener los datos reales).
*   **Sonido ambiente opcional** — botón flotante (`.ambient-btn`), apagado por defecto; reproduce `/public/ambient.mp3` (archivo a proveer) sin autoplay.

> El endpoint `/preview_challenge` sigue existiendo pero **ya no se usa en la landing** (se retiró el generador IA duplicado).

---

## 5. Embudo de Conversión (B2C)

Formulario de inscripción reducido a 3 campos para máxima conversión individual:
1.  **Nombre.**
2.  **WhatsApp** (normalizado a E.164).
3.  **Correo** (para acceso al portal).

> El controlador sigue aceptando `company`/`role` por si un flujo B2B futuro los envía, pero la landing pública no los pide. CTA único.

### Precio fundador (configurable por Settings)
La landing muestra un precio con descuento anclado (precio normal tachado → precio fundador) con urgencia por cupos. Los valores **nunca se hardcodean**; se leen de `Setting` en `HomeController#index`:

*   `membership_price_clp` — precio fundador (el que se cobra; gatilla el flujo de pago Webpay vía `Participant#payment_required?`).
*   `membership_regular_price_clp` — precio "normal" tachado (solo anclaje visual).
*   `founder_spots_total` — total de cupos de fundador; se muestra "Quedan N" restando `Participant.kept.count`.

Si `membership_price_clp` es 0/vacío, la landing cae a modo **gratis** ("Empieza gratis · sin tarjeta") y no publica ninguna cifra de placeholder. La sección de precio, el copy del hero, del formulario y de la FAQ de costo se adaptan solos al flag `paid = @founder_price.positive?`.

La sección **"Solos cuesta. Acompañados, no."** ancla el valor con estadística real de cambio de hábitos (≈80% de propósitos fracasan; 43% abandona en el primer mes; plan + seguimiento diario = 2-3× más éxito) y compara con hacerlo solo / coach o psicólogo tradicional.

---

*Última Actualización: 14 de Junio de 2026 — rediseño a tema claro/cálido y posicionamiento B2C personalizado.*
