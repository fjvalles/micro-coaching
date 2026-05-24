# Especificación de Diseño y Branding — Impulso by Comtraining

Este documento consolida la identidad visual, el sistema de diseño y las decisiones de branding adoptadas tras el reposicionamiento B2B de la plataforma. Sirve de guía para mantener consistencia en la web pública, el panel de administración y futuras interfaces.

---

## 1. Identidad de Marca y Posicionamiento

*   **Nombre de Marca:** Impulso by Comtraining
*   **Tagline Principal:** De la capacitación a la conducta.
*   **Enfoque:** Capa de transferencia conductual post-talleres/intervenciones para jefaturas y líderes de proyectos. No se presenta como un "bot de IA" ni "terapia", sino como una metodología corporativa seria, con supervisión humana y reportería anonimizada.
*   **Valores de Diseño (Territorio Verbal & Visual):**
    *   **Ejecutivo:** Sobrio, limpio, orientado a métricas y resultados empresariales.
    *   **Humano:** Apoyado en el respaldo de Comtraining, no en la automatización fría.
    *   **Útil:** Acción inmediata sobre conductas observables, sin sobrecargar de información.
    *   **Claro:** Sin lenguaje técnico excesivo ni adornos futuristas/cyberpunk.

---

## 2. Paleta de Colores y Tipografía

El sistema de diseño utiliza variables CSS nativas para soportar un tema oscuro ejecutivo con acentos de alta energía.

### Colores Clave
*   **Fondo Principal (`--bg`):** `#070a13` (Azul prusiano muy oscuro, proporciona profundidad ejecutiva).
*   **Fondo de Tarjetas (`--bg-card`):** `#111726` (Azul marino medio, excelente contraste para bento grids).
*   **Bordes y Líneas (`--border`):** `rgba(255, 255, 255, 0.08)` (Delicados bordes semi-transparentes para un look de vidrio pulido).
*   **Acento Primario (`--primary`):** `#10b981` (Verde Esmeralda WhatsApp, transmite comunicación activa y cercanía).
*   **Acento Secundario (`--secondary`):** `#6366f1` (Indigo/Violeta AI, representa la tecnología y automatización con criterio).
*   **Color de Foco (`--border-focus`):** `#4f46e5` (Para inputs activos).

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
*   **Selector de Desafíos:** Los usuarios (managers, RRHH) pueden seleccionar entre 4 problemáticas típicas:
    1.  *Conversaciones difíciles* (Alineación con colaboradores).
    2.  *Priorización y Foco* (Evitar urgencias diarias).
    3.  *Dar Feedback* (Refuerzo inmediato).
    4.  *Comunicar Cambios* (Alinear equipos).
*   **Animación de Escritura (Typing Effect):** El chat se borra y escribe dinámicamente los globos usando un indicador de carga (`typing-bubble`) simulando las respuestas de la IA y el usuario real.

### B. Generador de Micro-Pasos con IA en Tiempo Real
En la sección de pruebas, el usuario puede ingresar su propio desafío laboral en lenguaje natural.
*   La landing page hace un request a `/preview_challenge` que utiliza `gpt-4.1-mini` en el backend para generar un primer mensaje de Día 1 real basado en el marco pedagógico de Comtraining.
*   El resultado se despliega en una caja estilizada de WhatsApp, abriendo paso al formulario de registro B2B que captura su **Empresa** y **Cargo / Rol**.

---

## 5. Alineación del Embudo de Conversión (B2B)

El formulario de inscripción ha sido rediseñado para capturar la estructura organizativa y permitir la venta corporativa:
1.  **Nombre:** Del líder que probará el piloto.
2.  **WhatsApp Corporativo:** Normalizado al formato E.164.
3.  **Empresa:** Permite segmentar empresas medianas/grandes.
4.  **Cargo / Rol:** Identifica si el prospecto es un tomador de decisiones (PMO, RRHH, Gerencia de Transformación).

---

*Última Actualización: 24 de Mayo de 2026*
