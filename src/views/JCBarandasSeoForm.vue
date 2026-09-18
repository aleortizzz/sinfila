<script setup>
import { ref, reactive, onMounted, computed } from 'vue'
import { supabase } from '../lib/supabase'
import { notificarError, notificarExito } from '../lib/toast'
import { JCBARANDAS_SEO_FORM } from '../data/jcbarandasSeoForm'

// Formulario aislado para un cliente externo (jcbarandas.com.ar, sitio
// estático sin base propia) — se aprovecha esta base ya armada, pero no
// tiene relación con el resto de SinFila: ni ruta en el admin, ni tabla
// compartida, ni RLS que dependa de usuario_local_roles. Ver
// PROGRESO.md, 2026-09-18.

// Es un formulario largo (~35 preguntas) sin cuenta/login de por medio,
// así que "guardar progreso" es local al navegador (localStorage), no al
// servidor — alcanza para que la misma persona lo retome más tarde en el
// mismo dispositivo, sin la complejidad de manejar borradores en la base.
const CLAVE_PROGRESO = 'jcb_seo_progreso'

const respuestas = reactive({})
const enviando = ref(false)
const enviado = ref(false)
const erroresVisibles = ref(false)
const progresoRestaurado = ref(false)

onMounted(() => {
  if (document.getElementById('jcb-font-figtree')) return
  const link = document.createElement('link')
  link.id = 'jcb-font-figtree'
  link.rel = 'stylesheet'
  link.href = 'https://fonts.googleapis.com/css2?family=Figtree:wght@400;500;600;700;800&display=swap'
  document.head.appendChild(link)

  try {
    const guardado = localStorage.getItem(CLAVE_PROGRESO)
    if (guardado) {
      Object.assign(respuestas, JSON.parse(guardado))
      progresoRestaurado.value = true
    }
  } catch {
    // localStorage puede fallar (privado/bloqueado) — no es bloqueante, sigue sin restaurar nada.
  }
})

function guardarProgreso() {
  try {
    localStorage.setItem(CLAVE_PROGRESO, JSON.stringify(respuestas))
    notificarExito('Progreso guardado en este navegador. Podés cerrar la página y volver cuando quieras.')
  } catch {
    notificarError('No pudimos guardar el progreso en este navegador (¿estás en modo privado?).')
  }
}

function setValor(id, valor) {
  respuestas[id] = valor
}

function toggleMulti(id, valor) {
  const actual = Array.isArray(respuestas[id]) ? respuestas[id] : []
  respuestas[id] = actual.includes(valor) ? actual.filter((v) => v !== valor) : [...actual, valor]
}

function faltaCompletar(q) {
  if (!q.required) return false
  const v = respuestas[q.id]
  if (q.type === 'multi_select') return !Array.isArray(v) || v.length === 0
  return v === undefined || v === null || String(v).trim() === ''
}

const preguntasFaltantes = computed(() => {
  const faltan = []
  for (const s of JCBARANDAS_SEO_FORM.sections) {
    for (const q of s.questions) {
      if (faltaCompletar(q)) faltan.push(q.id)
    }
  }
  return faltan
})

const mostrarModalFaltantes = ref(false)

// Botón "Enviar respuestas": si falta algo obligatorio, no bloquea el
// envío — pregunta si de verdad quiere mandar así o prefiere seguir
// completando (el cliente puede no tener a mano un dato puntual y no
// queremos que eso le trabe todo el formulario).
function intentarEnviar() {
  erroresVisibles.value = true
  if (preguntasFaltantes.value.length > 0) {
    mostrarModalFaltantes.value = true
    return
  }
  enviarAhora()
}

function seguirRespondiendo() {
  mostrarModalFaltantes.value = false
  const el = document.getElementById(`campo-${preguntasFaltantes.value[0]}`)
  el?.scrollIntoView({ behavior: 'smooth', block: 'center' })
}

function enviarDeTodasFormas() {
  mostrarModalFaltantes.value = false
  enviarAhora()
}

async function enviarAhora() {
  enviando.value = true
  try {
    const { error } = await supabase.from('jcbarandas_seo_respuestas').insert({ respuestas: { ...respuestas } })
    if (error) throw error
    enviado.value = true
    try {
      localStorage.removeItem(CLAVE_PROGRESO)
    } catch {
      // no-op — si falló guardar, tampoco hay nada que limpiar
    }
    window.scrollTo({ top: 0, behavior: 'smooth' })
  } catch (e) {
    notificarError('No pudimos guardar las respuestas. Probá de nuevo en un momento — si sigue fallando, avisanos por WhatsApp.')
  } finally {
    enviando.value = false
  }
}
</script>

<template>
  <div class="jcb-page min-h-screen bg-[#020617] text-slate-100">
    <div class="mx-auto max-w-3xl px-4 py-10 sm:py-14">
      <header class="text-center">
        <p class="text-sm font-bold uppercase tracking-[0.2em] text-blue-500">JC Barandas</p>
        <h1 class="mt-2 text-2xl font-extrabold text-white sm:text-3xl">{{ JCBARANDAS_SEO_FORM.meta.formTitle }}</h1>
        <p class="mx-auto mt-3 max-w-xl text-sm text-slate-400">{{ JCBARANDAS_SEO_FORM.meta.formDescription }}</p>
      </header>

      <p v-if="progresoRestaurado && !enviado" class="mx-auto mt-4 max-w-lg rounded-lg bg-blue-500/10 px-4 py-2 text-center text-xs text-blue-300">
        Recuperamos el progreso que habías guardado en este navegador.
      </p>

      <!-- Gracias -->
      <div v-if="enviado" class="mx-auto mt-10 max-w-lg rounded-2xl bg-white p-8 text-center text-slate-900 shadow-xl">
        <div class="mx-auto flex h-14 w-14 items-center justify-center rounded-full bg-blue-100 text-3xl">✅</div>
        <h2 class="mt-4 text-xl font-bold">¡Gracias por completar el formulario!</h2>
        <p class="mt-2 text-sm text-slate-500">
          Ya recibimos tus respuestas. Con esta información vamos a mejorar los títulos, textos y estructura de
          jcbarandas.com.ar para que aparezca mejor en Google. Cualquier duda, escribinos.
        </p>
      </div>

      <!-- Form -->
      <form v-else @submit.prevent="intentarEnviar" class="mt-8 space-y-6 pb-24">
        <section v-for="s in JCBARANDAS_SEO_FORM.sections" :key="s.id" class="rounded-2xl bg-white p-6 text-slate-900 shadow-xl sm:p-8">
          <h2 class="text-lg font-extrabold text-slate-900">{{ s.title }}</h2>
          <p class="mt-1.5 text-sm text-slate-500">{{ s.description }}</p>

          <div class="mt-6 space-y-6">
            <div v-for="q in s.questions" :key="q.id" :id="`campo-${q.id}`">
              <label class="block text-sm font-semibold text-slate-800">
                {{ q.label }}
                <span v-if="q.required" class="text-blue-600">*</span>
              </label>
              <p v-if="q.helpText" class="mt-1 text-xs italic text-slate-400">{{ q.helpText }}</p>

              <!-- text / number -->
              <input
                v-if="q.type === 'text' || q.type === 'number'"
                :type="q.type"
                :value="respuestas[q.id] ?? ''"
                @input="setValor(q.id, $event.target.value)"
                :placeholder="q.placeholder"
                class="jcb-input mt-2 w-full"
              />

              <!-- textarea -->
              <textarea
                v-else-if="q.type === 'textarea'"
                :value="respuestas[q.id] ?? ''"
                @input="setValor(q.id, $event.target.value)"
                :placeholder="q.placeholder"
                rows="3"
                class="jcb-input mt-2 w-full resize-y"
              />

              <!-- single_select: radios -->
              <div v-else-if="q.type === 'single_select'" class="mt-2 space-y-1.5">
                <label
                  v-for="op in q.options" :key="op.value"
                  class="flex cursor-pointer items-start gap-2 rounded-lg border border-slate-200 p-2.5 text-sm hover:bg-slate-50"
                  :class="respuestas[q.id] === op.value && 'border-blue-500 bg-blue-50/60'"
                >
                  <input
                    type="radio"
                    :name="q.id"
                    :value="op.value"
                    :checked="respuestas[q.id] === op.value"
                    @change="setValor(q.id, op.value)"
                    class="mt-0.5 h-4 w-4 shrink-0 accent-blue-600"
                  />
                  <span>{{ op.label }}</span>
                </label>
              </div>

              <!-- multi_select: checkboxes -->
              <div v-else-if="q.type === 'multi_select'" class="mt-2 space-y-1.5">
                <label
                  v-for="op in q.options" :key="op.value"
                  class="flex cursor-pointer items-start gap-2 rounded-lg border border-slate-200 p-2.5 text-sm hover:bg-slate-50"
                  :class="(respuestas[q.id] ?? []).includes(op.value) && 'border-blue-500 bg-blue-50/60'"
                >
                  <input
                    type="checkbox"
                    :checked="(respuestas[q.id] ?? []).includes(op.value)"
                    @change="toggleMulti(q.id, op.value)"
                    class="mt-0.5 h-4 w-4 shrink-0 accent-blue-600"
                  />
                  <span>{{ op.label }}</span>
                </label>
              </div>

              <p v-if="erroresVisibles && faltaCompletar(q)" class="mt-1.5 text-xs font-medium text-red-600">
                Esta pregunta es obligatoria.
              </p>
            </div>
          </div>
        </section>

        <div class="fixed inset-x-0 bottom-0 z-40 flex justify-center gap-3 border-t border-white/10 bg-[#020617]/95 px-4 py-3 backdrop-blur">
          <button type="button" @click="guardarProgreso" class="jcb-secondary">
            Guardar progreso
          </button>
          <button type="submit" :disabled="enviando" class="jcb-submit">
            {{ enviando ? 'Enviando…' : 'Enviar respuestas' }}
          </button>
        </div>
      </form>
    </div>

    <!-- Modal: preguntas obligatorias sin responder -->
    <div v-if="mostrarModalFaltantes" class="fixed inset-0 z-50 flex items-center justify-center bg-slate-950/70 p-4">
      <div class="w-full max-w-sm rounded-2xl bg-white p-6 text-center text-slate-900 shadow-2xl">
        <h3 class="text-lg font-bold">
          Te falta{{ preguntasFaltantes.length === 1 ? '' : 'n' }} responder
          {{ preguntasFaltantes.length }} pregunta{{ preguntasFaltantes.length === 1 ? '' : 's' }}
        </h3>
        <p class="mt-2 text-sm text-slate-500">Podés mandarlo igual así como está, o volver a completarlas.</p>
        <div class="mt-5 flex flex-col gap-2">
          <button type="button" @click="seguirRespondiendo" class="jcb-submit w-full">Seguir respondiendo</button>
          <button type="button" @click="enviarDeTodasFormas" class="jcb-secondary w-full text-slate-500! border-slate-300!">
            Enviar de todas formas
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.jcb-page {
  font-family: 'Figtree', ui-sans-serif, system-ui, sans-serif;
}
.jcb-input {
  border-radius: 0.5rem;
  border: 1px solid #cbd5e1;
  padding: 0.5rem 0.75rem;
  font-size: 0.875rem;
  color: #0f172a;
}
.jcb-input:focus {
  outline: none;
  border-color: #2563eb;
  box-shadow: 0 0 0 3px rgb(37 99 235 / 0.15);
}
.jcb-submit {
  border-radius: 9999px;
  background: #2563eb;
  color: white;
  font-weight: 700;
  padding: 0.75rem 2rem;
  box-shadow: 0 10px 25px -5px rgb(37 99 235 / 0.5);
}
.jcb-submit:hover:not(:disabled) {
  background: #1d4ed8;
}
.jcb-submit:disabled {
  opacity: 0.6;
  cursor: not-allowed;
}
.jcb-secondary {
  border-radius: 9999px;
  background: transparent;
  border: 1.5px solid #475569;
  color: #cbd5e1;
  font-weight: 600;
  padding: 0.75rem 1.75rem;
}
.jcb-secondary:hover {
  border-color: #2563eb;
  color: white;
}
</style>
