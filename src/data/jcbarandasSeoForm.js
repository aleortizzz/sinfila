// Cuestionario de SEO para JC Barandas (jcbarandas.com.ar) — dato estático,
// nada de esto se edita desde ningún panel. Ver PROGRESO.md, 2026-09-18.
export const JCBARANDAS_SEO_FORM = {
  meta: {
    formTitle: 'Cuestionario SEO — JC Barandas',
    formDescription:
      'Respuestas del dueño del negocio para poder optimizar jcbarandas.com.ar: títulos, encabezados, textos y estructura del sitio, orientados a atraer búsquedas por palabra clave (no solo por el nombre de la empresa).',
  },
  sections: [
    {
      id: 'zona-geografica',
      title: 'Zona geográfica de trabajo',
      description:
        'El SEO local depende directamente de decir con precisión dónde trabajan. Hoy el sitio no menciona ninguna zona geográfica en los títulos ni encabezados, y eso es una de las razones por las que casi todo el tráfico es gente que ya conocía el nombre "JC Barandas".',
      questions: [
        {
          id: 'zona_principal',
          label: '¿Cuál dirías que es la zona principal donde trabajan?',
          type: 'single_select',
          options: [
            { value: 'zona_norte_gba', label: 'Zona Norte del Gran Buenos Aires (San Isidro, Vicente López, Tigre, San Fernando, Pilar, etc.)' },
            { value: 'caba_zona_norte', label: 'CABA + Zona Norte del GBA' },
            { value: 'costa_atlantica', label: 'Costa Atlántica (Pinamar, Cariló, Costa Esmeralda, etc.)' },
            { value: 'zona_norte_y_costa', label: 'Zona Norte del GBA + Costa Atlántica (las dos)' },
            { value: 'provincia_bsas', label: 'Toda la Provincia de Buenos Aires' },
            { value: 'todo_el_pais', label: 'Todo el país' },
            { value: 'otro', label: 'Otra (especificar)' },
          ],
          helpText: 'Esta respuesta define el título principal de la página de inicio y las descripciones de todo el sitio. Es la pregunta más importante del formulario.',
          required: true,
        },
        {
          id: 'localidades_especificas',
          label:
            "Nombrá las localidades o partidos donde ya hicieron trabajos o donde les gustaría aparecer en Google al buscar 'barandas + localidad'",
          type: 'textarea',
          placeholder: 'Ej: San Isidro, Tigre, Pilar, Nordelta, Vicente López, Béccar, San Fernando, Escobar, Cariló, Costa Esmeralda...',
          helpText: 'Cada localidad que menciones es una oportunidad de aparecer cuando alguien busca "barandas de vidrio templado + esa localidad". Podemos crear secciones específicas para las 2-3 zonas más importantes.',
          required: true,
        },
        {
          id: 'countries_barrios_cerrados',
          label: '¿Trabajan en countries, barrios cerrados o clubes de campo? Si es así, ¿en cuáles ya trabajaron?',
          type: 'textarea',
          placeholder: 'Ej: Nordelta, La Martona, San Isidro Labrador, Haras Santa María...',
          helpText: 'Los countries suelen tener búsquedas específicas ("barandas Nordelta") con poca competencia. Si ya trabajaron ahí, vale la pena nombrarlo.',
          required: false,
        },
        {
          id: 'disponibilidad_viajar',
          label: '¿Viajan a otras provincias o zonas alejadas para proyectos grandes?',
          type: 'single_select',
          options: [
            { value: 'si_cualquier_zona', label: 'Sí, a cualquier zona si el proyecto lo justifica' },
            { value: 'si_zona_limitada', label: 'Sí, pero solo dentro de un radio limitado' },
            { value: 'no', label: 'No, solo trabajamos en nuestra zona habitual' },
          ],
          helpText: 'Define si conviene mostrar un mensaje del tipo "trabajos a medida en toda la provincia" o mantener el foco 100% local.',
          required: true,
        },
      ],
    },
    {
      id: 'servicios-prioritarios',
      title: 'Servicios y productos prioritarios',
      description:
        "El sitio ya tiene 5 páginas de 'Modelos' (vidrio templado y botones, minipostes, estructura de acero, barandas de exterior, otros). Necesitamos saber cuál de estos es el que más consultas/ventas genera para priorizarlo en la home y en Google.",
      questions: [
        {
          id: 'servicio_principal',
          label: '¿Cuál de estos productos es el que más vende o el que más te gustaría que apareciera primero en Google?',
          type: 'single_select',
          options: [
            { value: 'vid_tem_bot', label: 'Vidrio templado y botones' },
            { value: 'vid_tem_minipostes', label: 'Vidrio templado y minipostes' },
            { value: 'vid_tem_estructura', label: 'Vidrio templado y estructura de acero inoxidable' },
            { value: 'barandas_exterior', label: 'Barandas de exterior' },
            { value: 'otros', label: 'Ninguno en particular / depende del proyecto' },
          ],
          helpText: 'Define el orden de los productos en el menú y en la home, y cuál desarrollamos con más contenido.',
          required: true,
        },
        {
          id: 'servicios_secundarios',
          label: '¿Qué otros trabajos hacen además de barandas? (aunque no tengan página propia todavía)',
          type: 'textarea',
          placeholder: 'Ej: escaleras completas, cerramientos de vidrio, mamparas de baño, puertas de acero inoxidable, pasamanos de madera y acero, rejas...',
          helpText: 'Si hacen algo que no está reflejado en el sitio, puede ser una página nueva con su propia oportunidad de búsqueda.',
          required: false,
        },
        {
          id: 'servicios_no_ofrecidos',
          label: '¿Hay algo que la gente les suele pedir pero que NO hacen? (para aclararlo y evitar consultas que no les sirven)',
          type: 'textarea',
          placeholder: 'Ej: no hacemos aberturas de aluminio, no hacemos herrería de rejas comunes...',
          helpText: 'Ayuda a filtrar el tráfico y evitar malentendidos.',
          required: false,
        },
        {
          id: 'tipo_proyecto_tipico',
          label: '¿Qué es más común: instalaciones nuevas (obra en construcción) o reemplazo de barandas existentes?',
          type: 'single_select',
          options: [
            { value: 'obra_nueva', label: 'Mayormente obra nueva / en construcción' },
            { value: 'reemplazo', label: 'Mayormente reemplazo de barandas viejas' },
            { value: 'ambos', label: 'Mitad y mitad' },
          ],
          helpText: 'Gente que busca "cambiar baranda vieja por vidrio" busca distinto a alguien construyendo una casa nueva — ayuda a cubrir ambos casos.',
          required: false,
        },
      ],
    },
    {
      id: 'cliente-objetivo',
      title: 'Cliente objetivo',
      description:
        'Entender quién decide y contrata ayuda a escribir con el tono correcto y a decidir si conviene contenido dirigido a arquitectos/constructoras o a particulares.',
      questions: [
        {
          id: 'tipo_cliente',
          label: '¿Quiénes son sus clientes habituales?',
          type: 'multi_select',
          options: [
            { value: 'particulares', label: 'Dueños de casa particulares' },
            { value: 'arquitectos', label: 'Arquitectos / estudios de arquitectura' },
            { value: 'constructoras', label: 'Constructoras / desarrolladores' },
            { value: 'consorcios', label: 'Consorcios / administradores de edificios' },
            { value: 'comercios', label: 'Locales comerciales / oficinas' },
          ],
          helpText: 'Si trabajan mucho con arquitectos, conviene sumar contenido técnico. Si es sobre todo particulares, el foco tiene que ser más simple y visual.',
          required: true,
        },
        {
          id: 'quien_decide',
          label: '¿Quién suele contactarlos primero: el dueño de casa, el arquitecto, o el maestro mayor de obra?',
          type: 'text',
          helpText: 'Ayuda a decidir a quién le "habla" la página de inicio.',
          required: false,
        },
      ],
    },
    {
      id: 'diferenciales',
      title: 'Diferenciales frente a la competencia',
      description:
        'Google también mide qué tan confiable y completa es la información de un sitio. Estos datos alimentan la sección "Nos caracteriza" y ayudan a que un cliente elija llamarlos a ellos y no a otro instalador.',
      questions: [
        {
          id: 'anios_experiencia',
          label: '¿Cuántos años de experiencia tiene el negocio?',
          type: 'number',
          helpText: 'Los años de trayectoria son un factor de confianza tanto para el usuario como para el posicionamiento.',
          required: true,
        },
        {
          id: 'que_los_diferencia',
          label: '¿Por qué un cliente debería elegirlos a ustedes y no a otro instalador de barandas?',
          type: 'textarea',
          placeholder: 'Ej: hacemos todo el proceso in-house (no tercerizamos), usamos vidrio de tal calidad, entregamos en X días, damos garantía por escrito...',
          helpText: 'Esta es la respuesta más importante para diferenciarse de la competencia en el contenido de la web.',
          required: true,
        },
        {
          id: 'garantia',
          label: '¿Ofrecen garantía? ¿De cuánto tiempo y sobre qué cubre?',
          type: 'text',
          helpText: 'La garantía es algo que la gente busca activamente antes de contratar y genera confianza.',
          required: false,
        },
        {
          id: 'certificaciones',
          label: '¿Tienen matrícula, certificaciones de calidad, seguros de responsabilidad civil u otra credencial formal?',
          type: 'text',
          helpText: 'Suma credibilidad, especialmente para clientes corporativos o consorcios.',
          required: false,
        },
        {
          id: 'materiales_proveedores',
          label: '¿Usan alguna marca o calidad de vidrio/acero en particular que valga la pena mencionar?',
          type: 'text',
          placeholder: 'Ej: vidrio templado de 10mm, acero inoxidable AISI 304...',
          helpText: 'Detalles técnicos específicos ayudan tanto al SEO como a la credibilidad frente a clientes más exigentes.',
          required: false,
        },
      ],
    },
    {
      id: 'competencia',
      title: 'Competencia',
      description: 'Saber quién es la competencia directa ayuda a entender qué palabras clave están disputando y qué está funcionando (o no) en el mercado.',
      questions: [
        {
          id: 'competidores_directos',
          label: 'Nombrá 3 a 5 competidores directos (nombre y, si lo sabés, su web o Instagram)',
          type: 'textarea',
          helpText: 'Sirve para analizar qué palabras clave usan ellos y en qué se les puede ganar.',
          required: false,
        },
        {
          id: 'diferencia_competencia',
          label: '¿Qué creés que la competencia hace mejor o peor que ustedes?',
          type: 'textarea',
          helpText: 'Opcional, pero útil para afinar el mensaje de diferenciación.',
          required: false,
        },
      ],
    },
    {
      id: 'presencia-online',
      title: 'Presencia y reputación online',
      description:
        'Google le da mucho peso a las señales que vienen de fuera del sitio (Google Business Profile, reseñas, redes sociales activas) para decidir cuánto confiar en un negocio local.',
      questions: [
        {
          id: 'google_business_profile',
          label: '¿Tienen ficha de Google Business Profile (la que aparece en Google Maps al buscar el negocio)?',
          type: 'single_select',
          options: [
            { value: 'si_activa', label: 'Sí, y la mantenemos actualizada' },
            { value: 'si_desactualizada', label: 'Sí, pero hace tiempo que no la actualizamos' },
            { value: 'no', label: 'No tenemos' },
            { value: 'no_se', label: 'No sé / hay que revisar' },
          ],
          helpText: 'Es probablemente la herramienta gratuita más importante para SEO local.',
          required: true,
        },
        {
          id: 'link_google_business',
          label: 'Si tienen, pasá el link de la ficha de Google Business Profile',
          type: 'text',
          helpText: 'Para revisar el estado actual y sugerir mejoras puntuales.',
          required: false,
        },
        {
          id: 'cantidad_resenas',
          label: 'Aproximadamente, ¿cuántas reseñas de clientes tienen en Google?',
          type: 'number',
          helpText: 'Ayuda a dimensionar si conviene una campaña activa de pedir reseñas a clientes recientes.',
          required: false,
        },
        {
          id: 'redes_sociales_activas',
          label: '¿Qué redes usan activamente hoy (suben contenido seguido)?',
          type: 'multi_select',
          options: [
            { value: 'instagram', label: 'Instagram' },
            { value: 'facebook', label: 'Facebook' },
            { value: 'tiktok', label: 'TikTok' },
            { value: 'ninguna', label: 'Ninguna de forma activa' },
          ],
          helpText: 'El sitio ya enlaza a Instagram y Facebook. Si hay una red activa que no está enlazada, se agrega.',
          required: false,
        },
        {
          id: 'testimonios_clientes',
          label: '¿Tienen mensajes, audios o comentarios reales de clientes conformes que podamos citar como testimonio?',
          type: 'textarea',
          helpText: 'Los testimonios reales (con nombre y localidad) mejoran mucho la sección de opiniones, hoy genérica.',
          required: false,
        },
      ],
    },
    {
      id: 'palabras-clave',
      title: 'Palabras clave y lenguaje real del cliente',
      description:
        'Esta es la sección más valiosa de todo el formulario: nadie conoce mejor que ustedes las palabras exactas que usa la gente cuando llama o escribe pidiendo presupuesto. Esas palabras, tal cual las dice el cliente, son las que hay que usar en la web (no las que "suenan más profesionales").',
      questions: [
        {
          id: 'como_llaman_clientes',
          label: 'Cuando un cliente nuevo llama o escribe, ¿cómo describe lo que necesita? Escribí frases textuales si las recordás',
          type: 'textarea',
          placeholder: "Ej: 'quiero sacar la reja y poner vidrio', 'necesito una baranda para la escalera', 'quiero cerrar el balcón con vidrio sin marco'...",
          helpText: 'Estas frases, tal cual las dice la gente, suelen ser mejores palabras clave que los términos técnicos.',
          required: true,
        },
        {
          id: 'preguntas_frecuentes',
          label: 'Las 5 a 10 preguntas que más te hacen los clientes antes de contratar',
          type: 'textarea',
          placeholder: '¿cuánto sale?, ¿cuánto tarda?, ¿el vidrio se puede romper fácil?, ¿hay que hacer mantenimiento?, ¿trabajan en countries?...',
          helpText: 'Cada pregunta frecuente es contenido potencial para una sección de Preguntas Frecuentes.',
          required: true,
        },
        {
          id: 'objeciones_frecuentes',
          label: '¿Cuáles son las dudas o miedos más comunes que frenan a alguien de contratar?',
          type: 'textarea',
          placeholder: 'Ej: miedo a que el vidrio se rompa, dudas sobre el precio comparado con rejas tradicionales, tiempos de entrega...',
          helpText: 'Responder estas objeciones directamente en la web mejora tanto conversión como SEO.',
          required: false,
        },
      ],
    },
    {
      id: 'contenido-futuro',
      title: 'Contenido futuro / blog',
      description:
        'Google premia a los sitios que se actualizan con contenido nuevo y relevante. Un blog o sección de novedades con casos y tips es una de las formas más efectivas de atraer tráfico por palabra clave a mediano plazo.',
      questions: [
        {
          id: 'disponibilidad_fotos_nuevas',
          label: '¿Pueden ir mandando fotos de obras nuevas a medida que las terminan?',
          type: 'single_select',
          options: [
            { value: 'si_seguido', label: 'Sí, seguido (varias veces al mes)' },
            { value: 'si_ocasional', label: 'Sí, pero de forma ocasional' },
            { value: 'no', label: 'No, es difícil para nosotros' },
          ],
          helpText: 'Define si conviene planificar actualizaciones de contenido mensuales o trimestrales.',
          required: true,
        },
        {
          id: 'frecuencia_proyectos_nuevos',
          label: 'Aproximadamente, ¿cuántos proyectos nuevos terminan por mes?',
          type: 'text',
          helpText: 'Ayuda a estimar cada cuánto se puede sumar un proyecto nuevo a la sección de Proyectos.',
          required: false,
        },
        {
          id: 'quien_genera_contenido',
          label: '¿Quién podría sacar fotos o escribir dos líneas sobre cada obra nueva?',
          type: 'text',
          helpText: 'Para saber si conviene armar una plantilla simple que el propio cliente pueda completar.',
          required: false,
        },
      ],
    },
    {
      id: 'datos-negocio',
      title: 'Datos de negocio para SEO local',
      description:
        'Estos datos tienen que ser exactamente iguales en la web, en Google Business Profile y en cualquier otro directorio online — la consistencia de estos datos es una señal de confianza para Google.',
      questions: [
        {
          id: 'direccion_publica',
          label: "La dirección actual en el sitio es 'Ingeniero Marconi 2816, Béccar'. ¿Confirmás que es correcta y que puede mostrarse públicamente?",
          type: 'single_select',
          options: [
            { value: 'confirmada', label: 'Sí, es correcta y puede mostrarse' },
            { value: 'corregir', label: 'Hay que corregirla (especificar la correcta)' },
            { value: 'no_mostrar', label: 'Preferimos no mostrar la dirección exacta' },
          ],
          helpText: 'La dirección debe coincidir exactamente con la de Google Business Profile para reforzar el SEO local.',
          required: true,
        },
        {
          id: 'telefono_principal',
          label: 'De los dos teléfonos que aparecen en la web (+54 9 11 6446-3400 y +54 9 11 2578-7279), ¿cuál preferís que sea el principal?',
          type: 'single_select',
          options: [
            { value: '6446-3400', label: '+54 9 11 6446-3400' },
            { value: '2578-7279', label: '+54 9 11 2578-7279' },
            { value: 'ambos_igual', label: 'Los dos por igual, no hay preferencia' },
          ],
          helpText: 'Tener un número principal consistente ayuda a mantener los datos iguales en todos lados.',
          required: false,
        },
        {
          id: 'horario_atencion',
          label: 'Horario de atención (para mostrar en la web y en Google Business Profile)',
          type: 'text',
          placeholder: 'Ej: Lunes a viernes de 8 a 18hs',
          helpText: 'Los horarios visibles mejoran tanto la experiencia del usuario como las señales de negocio local.',
          required: false,
        },
      ],
    },
    {
      id: 'objetivos',
      title: 'Objetivo del sitio',
      description: 'Para priorizar el trabajo según lo que más le importa al negocio.',
      questions: [
        {
          id: 'objetivo_principal',
          label: '¿Qué es lo que más querés que genere la web?',
          type: 'single_select',
          options: [
            { value: 'whatsapp', label: 'Más consultas por WhatsApp' },
            { value: 'llamadas', label: 'Más llamadas telefónicas' },
            { value: 'formulario', label: 'Más consultas por el formulario de contacto' },
            { value: 'reconocimiento', label: 'Más reconocimiento de marca, sin importar el canal' },
          ],
          helpText: 'Ya existen los tres canales, pero saber cuál priorizás ayuda a decidir dónde poner más énfasis visual.',
          required: true,
        },
        {
          id: 'estacionalidad',
          label: '¿Notás que hay una época del año con más consultas? (por ejemplo, antes del verano si trabajan con casas de countries o de la costa)',
          type: 'text',
          helpText: 'Si hay estacionalidad, conviene reforzar el contenido y las campañas en los meses previos al pico.',
          required: false,
        },
      ],
    },
  ],
}
