# Estrategia Comercial — Impulso by Comtraining

Documento de trabajo para aterrizar la salida a mercado del producto. Complementa la documentación técnica y pedagógica con decisiones de posicionamiento, buyer y estrategia de piloto.

> [!IMPORTANT]
> **Dos capas, no contradictorias.** Este documento describe la **tesis B2B** (venta consultiva a empresas, pilotos por cohorte) — sigue siendo la salida a mercado *aspiracional*. La sección **0** describe el **embudo B2C que ya está construido en el producto** (prueba gratis 14 días → Nivel 2 personalizado pagado). El embudo B2C actúa como motor de validación y sensor de demanda mientras se cierra el primer piloto B2B. Las reglas vivas de este embudo son canónicas en [`docs/business-rules.md`](business-rules.md) §21, §22, §29, §32.

---

## 0. Lo que ya está construido (embudo B2C)

A diferencia del piloto B2B (todavía por cerrar), el producto **ya implementa** un embudo individual de extremo a extremo:

1. **Nivel 1 gratis (14 días).** Todo participante vive el programa base sin costo (`Program#price_clp = 0`). El pago se movió de la puerta al **final**.
2. **Oferta de día 14.** Al completar, `SendNivel2OfferJob` (gated por `nivel2_offer_enabled`) envía una oferta generada por IA (`Openai::Nivel2OfferGenerator`, contraste día 1→14) para diseñar un **Nivel 2 personalizado pagado**. No hay catálogo pre-armado: el intake actúa como sensor de demanda.
3. **Ventana fundadora.** `nivel2_offer_window_hours` (default 48) abre un precio fundador (`Program#founder_price_clp`).
4. **Pagar para desbloquear.** El participante entra al intake → la IA genera el Nivel 2 → revisión humana obligatoria → el portal muestra "Desbloquea tu Nivel 2". El pago (Webpay Plus, único, `Payment.purpose = personalized`) activa el ciclo vía `Programs::Approver`/`ReEnroller`.
5. **Garantía condicional.** Un ciclo extra gratis dentro de `guarantee_claim_window_days` (default 30) si no hubo resultado.

Canales de pago vivos: **Webpay Plus** (pago único, `/pagos`) y **Webpay Oneclick** (suscripción recurrente, `/suscripcion` — build-complete pero tras kill-switch `webpay_oneclick_enabled` hasta tener credenciales de producción). Portal de participante en `/portal` (magic-link). Embudo de conversión observable en `/admin/funnel`.

> Esta capa B2C **no reemplaza** la tesis B2B: convive con la regla de membresía cubierta por empresa (`Company#covers_membership` → el miembro no paga individual; ver §21 de business-rules).

---

## 1. Tesis Comercial

### Posicionamiento recomendado

**Impulso by Comtraining** es un programa de acompanamiento conductual por WhatsApp que ayuda a convertir capacitacion, liderazgo y gestion del cambio en acciones concretas durante 14 dias.

No se vende como "bot de IA", ni como app de bienestar generica, ni como terapia. Se vende como una capa de **transferencia conductual post-intervencion**.

### Problema que resuelve

Muchas empresas invierten en talleres, coaching, liderazgo o iniciativas de cambio, pero el aprendizaje se diluye cuando las personas vuelven a su rutina. Falta acompanamiento liviano, frecuente y medible entre sesiones o despues de la intervencion.

### Promesa central

**De la capacitacion a la conducta.**

Impulso ayuda a que el aprendizaje no se quede en la sala: lo convierte en microconductas sostenidas durante 14 dias, con acompanamiento por WhatsApp, supervision experta y resultados observables para la organizacion.

---

## 2. Cliente Ideal Inicial

### Segmento prioritario

Partir por **empresas medianas en Chile** con:

- procesos de cambio activos
- jefaturas o lideres de proyecto bajo alta exigencia
- inversion ya existente en liderazgo, capacitacion o transformacion
- sponsor interno en PMO, gerencia de transformacion, RRHH o gerencia general

### Buyer inicial recomendado

El primer buyer no tiene que ser siempre el usuario directo. Los compradores mas factibles al inicio son:

1. **PMO / Oficina de Proyectos**
   - Dolor: iniciativas que arrancan bien y pierden traccion en la ejecucion diaria.
2. **Gerencias de Transformacion / Cambio**
   - Dolor: baja adopcion conductual despues de talleres, lanzamientos o comunicaciones.
3. **RRHH / L&D**
   - Dolor: dificultad para demostrar transferencia al puesto de trabajo despues de una capacitacion.
4. **Gerencia General o Gerencias de Area**
   - Dolor: lideres intermedios con ejecucion inconsistente, baja accountability o desgaste.

### Usuario directo

- mandos medios
- jefaturas
- lideres de proyecto
- lideres funcionales en contextos de cambio

---

## 3. Caso de Uso de Entrada

### Opcion recomendada

**Impulso Liderazgo en Accion**

Sprint de 14 dias para reforzar habitos concretos de liderazgo y ejecucion del cambio en jefaturas y lideres de proyecto.

### Habitos que puede trabajar

- seguimiento y accountability
- claridad en prioridades
- conversaciones dificiles
- regulacion de reactividad
- comunicacion de cambios
- foco del equipo
- consistencia entre intencion y accion

### Por que partir aqui

- Es un dolor transversal a industrias.
- Tiene alto valor percibido para buyer y sponsor.
- Se apalanca bien en la credibilidad de Comtraining.
- Permite luego expandirse a cambio, productividad sostenible o bienestar preventivo.

---

## 4. Oferta Piloto Fundacional

### Nombre sugerido

**Impulso Sprint 14**

### Formato

- cohorte de 20 a 30 participantes
- 14 dias de acompanamiento por WhatsApp
- foco conductual definido con sponsor
- supervision humana liviana
- alertas internas de adherencia o posibles casos sensibles
- reporte final agregado y anonimizado
- sesion ejecutiva de cierre

### Modalidad comercial inicial

**Piloto fundacional sin costo** para las primeras empresas, a cambio de:

- sponsor interno comprometido
- acceso a feedback estructurado
- autorizacion para usar aprendizajes anonimizados como caso
- disponibilidad para una reunion de cierre

### Objetivo del piloto

No es "probar una tecnologia". Es validar:

- interes real del mercado
- tasa de adherencia
- claridad del caso de uso
- valor percibido por sponsor y participantes
- capacidad de convertir luego a un cliente pagado

---

## 5. Modelo Comercial Evolutivo

### Fase 1 — Validacion

- 1 a 3 pilotos fundacionales
- alto componente de supervision humana
- foco en aprendizaje, prueba social y testimonios

### Fase 2 — Pilotos pagados

- pricing por cohorte o por participante
- opcion de servicios anexos
- conversion de sponsors satisfechos a clientes recurrentes

### Fase 3 — Producto + servicios

- acompanamiento automatizado con alertas
- sesiones premium con coach
- reporteria ejecutiva
- integraciones con ecosistemas de RRHH o beneficios

---

## 6. Pricing

> [!NOTE]
> **B2C (vivo en el producto):** el precio es **por programa**, no global. `Program#price_clp` (0 = gratis, p. ej. el Nivel 1 de prueba) y `Program#founder_price_clp` (precio fundador dentro de la ventana). El Nivel 2 personalizado es el único producto pagado hoy; su precio se define al crear/aprobar el programa. Ver `business-rules.md` §32.1.

### 6.1 Pricing B2B tentativo (piloto fundacional, aspiracional)

Una vez validado el piloto fundacional, el rango inicial sugerido es:

- **CLP 18.000 a 29.000** por participante
- o un minimo por cohorte de **CLP 590.000 a 890.000**

Versiones con mayor acompanamiento o cierre consultivo pueden subir a:

- **CLP 990.000 a 1.490.000** por cohorte

Servicios adicionales:

- coaching 1:1 con el coach experto
- sesion grupal de refuerzo
- version post-taller recurrente
- cohortes por lideres senior o equipos criticos

---

## 7. Ruta de Canales

### Canal 1 — Red actual del coach

Prioridad maxima al inicio:

- ex alumnos de magister en gestion de proyectos
- ex alumnos de gestion del cambio
- clientes previos de Comtraining
- sponsors con problemas visibles de adopcion o liderazgo

### Canal 2 — Venta directa consultiva

- outreach a PMO
- conversaciones con gerencias de transformacion
- RRHH / L&D de empresas medianas

### Canal 3 — Partners y beneficios

A mediano plazo se puede explorar una salida por ecosistemas tipo BUK, idealmente como:

- partner asesor
- beneficio corporativo
- oferta co-branded o complemento de programas de desarrollo

No debe ser una dependencia para la validacion inicial.

---

## 8. Riesgos Comerciales Actuales

### 8.1 Posicionamiento demasiado amplio

Si se intenta vender a la vez como habitos, bienestar, coaching personal, liderazgo, cambio y productividad, el producto se vuelve dificil de entender.

### 8.2 Promesas desalineadas con el producto actual

El producto hoy tiene limites claros. La promesa comercial debe mantenerse dentro de:

- texto por WhatsApp
- acompanamiento breve
- supervision humana
- reporteria agregada

### 8.3 Riesgo de verse como "bot barato"

Si el pricing o la narrativa se apoyan demasiado en automatizacion, el valor percibido cae. La propuesta debe apalancarse en metodo, criterio, supervision y expertise de Comtraining.

### 8.4 Riesgo de privacidad y confianza

La empresa no debe recibir conversaciones individuales salvo consentimiento expreso. La confianza del participante es parte del valor del producto.

---

## 9. Indicadores de Exito para los Primeros 90 Dias

### Objetivos recomendados

1. Conseguir 1 piloto fundacional real.
2. Ejecutar el piloto de punta a punta.
3. Obtener 1 testimonio ejecutivo.
4. Convertir al menos 1 interes en oportunidad pagada.

### KPI de producto / negocio

- tasa de activacion
- tasa de respuesta dia 1
- tasa promedio de respuesta diaria
- tasa de finalizacion dia 14
- porcentaje de participantes con alta, media y baja adherencia
- satisfaccion del sponsor
- interes por una segunda cohorte
- costo operativo por participante

---

## 10. Proximos Pasos

1. Definir una unica oferta de entrada: **Impulso Liderazgo en Accion**.
2. Preparar one-pager comercial y guion de discovery.
3. Seleccionar 10 prospectos concretos de la red existente.
4. Conseguir 3 a 5 reuniones exploratorias.
5. Cerrar 1 piloto fundacional con cohorte limitada.
6. Documentar resultados para convertir aprendizaje en venta pagada.
