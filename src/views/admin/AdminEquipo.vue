<script setup>
import { computed, onMounted, ref, watch } from 'vue'
import {
  obtenerEquipoLocal,
  generarContraseña,
  crearCuentaStaff,
  quitarDeEquipo,
  cambiarNivelEquipo,
  nivelDeFila,
  NIVELES_EQUIPO,
  CAPACIDADES,
} from '../../lib/admin'
import { pedirResetContrasena, obtenerSesion, cerrarSesion } from '../../lib/auth'
import { notificarExito, notificarError } from '../../lib/toast'
import FichaEmpleado from '../../components/FichaEmpleado.vue'

const props = defineProps({ local: Object })

// El nav y los guards de ruta leen los permisos una sola vez por sesión (ver
// router/index.js) — si te cambiás el nivel a vos mismo acá, hace falta
// recargar para que se note en todos lados, si no seguís viendo pantallas
// a las que ya no deberías tener acceso hasta la próxima navegación.
const miUsuarioId = ref(null)
onMounted(async () => {
  const sesion = await obtenerSesion()
  miUsuarioId.value = sesion?.user?.id ?? null
})

const SECCIONES = [
  ['agregar', 'Agregar'],
  ['ver', 'Ver equipo'],
]
const seccion = ref('agregar')

const cargando = ref(true)
const error = ref(null)
const equipo = ref([])

const expandidos = ref(new Set())
function toggleExpandido(valor) {
  if (expandidos.value.has(valor)) expandidos.value.delete(valor)
  else expandidos.value.add(valor)
}

const nombre = ref('')
const email = ref('')
const telefono = ref('')
const password = ref(generarContraseña())
const nivelNuevo = ref('staff')
const creando = ref(false)
const errorForm = ref(null)
const creado = ref(null) // { email, password, telefono } de la última cuenta creada

const fichaAbierta = ref(null) // miembro del equipo cuya ficha se está viendo/editando

let cargado = false
watch(
  () => props.local,
  (v) => {
    if (v && !cargado) {
      cargado = true
      cargar()
    }
  },
  { immediate: true },
)

async function cargar() {
  cargando.value = true
  try {
    equipo.value = await obtenerEquipoLocal(props.local.id)
  } catch (e) {
    error.value = e.message
  } finally {
    cargando.value = false
  }
}

function regenerar() {
  password.value = generarContraseña()
}

async function crear() {
  if (!email.value.trim()) return
  errorForm.value = null
  creando.value = true
  try {
    const { yaExistia } = await crearCuentaStaff(props.local.id, email.value, password.value, nivelNuevo.value, {
      nombre: nombre.value,
      telefono: telefono.value,
    })
    creado.value = {
      email: email.value.trim(),
      password: yaExistia ? null : password.value,
      telefono: telefono.value.trim(),
      yaExistia,
    }
    nombre.value = ''
    email.value = ''
    telefono.value = ''
    password.value = generarContraseña()
    nivelNuevo.value = 'staff'
    await cargar()
    notificarExito(yaExistia ? 'Ya tenía cuenta — la sumamos de nuevo al equipo.' : 'Cuenta creada correctamente.')
  } catch (e) {
    errorForm.value = e.message
    notificarError(e.message)
  } finally {
    creando.value = false
  }
}

function abrirFicha(m) {
  fichaAbierta.value = m
}
function cerrarFicha() {
  fichaAbierta.value = null
}
async function fichaGuardada() {
  await cargar()
  fichaAbierta.value = null
}

async function quitar(m) {
  if (!confirm(`¿Sacar a "${m.email}" del equipo? Deja de poder entrar al panel/KDS de este local.`)) return
  const esUnoMismo = m.usuario_id === miUsuarioId.value
  try {
    await quitarDeEquipo(props.local.id, m.usuario_id)
    if (esUnoMismo) {
      notificarExito('Te sacaste del equipo. Cerrando sesión…')
      await cerrarSesion()
      setTimeout(() => { window.location.href = '/login' }, 800)
      return
    }
    equipo.value = equipo.value.filter((x) => x.usuario_id !== m.usuario_id)
    notificarExito(`Se sacó a ${m.email} del equipo.`)
  } catch (e) {
    notificarError(e.message)
  }
}

async function cambiarNivel(m, nuevoNivel) {
  const anterior = nivelDeFila(m)
  if (anterior === nuevoNivel) return
  if (
    nuevoNivel === 'administrador' &&
    !confirm(`¿Hacer a "${m.email}" administrador? Va a poder hacer todo lo mismo que vos, incluido gestionar el equipo y la configuración del local.`)
  ) {
    return
  }
  const esUnoMismo = m.usuario_id === miUsuarioId.value
  if (
    esUnoMismo &&
    !confirm(`Estás por cambiarte tu propio nivel a "${NIVELES_EQUIPO.find((n) => n.valor === nuevoNivel)?.label}". La página se va a recargar para aplicar el cambio. ¿Continuar?`)
  ) {
    return
  }
  try {
    await cambiarNivelEquipo(props.local.id, m.usuario_id, nuevoNivel)
    if (esUnoMismo) {
      notificarExito('Guardado. Actualizando tus permisos…')
      setTimeout(() => window.location.reload(), 800)
      return
    }
    await cargar()
    notificarExito('Guardado correctamente.')
  } catch (e) {
    notificarError(e.message)
  }
}

async function restablecer(m) {
  try {
    await pedirResetContrasena(m.email)
    notificarExito(`Le mandamos un mail a ${m.email} para que elija una contraseña nueva.`)
  } catch (e) {
    notificarError(e.message)
  }
}

function ultimoAccesoTexto(m) {
  if (!m.ultimo_acceso) return 'Nunca entró'
  const f = new Date(m.ultimo_acceso).toLocaleString('es-AR', {
    day: '2-digit', month: '2-digit', year: 'numeric', hour: '2-digit', minute: '2-digit',
  })
  return `Última vez: ${f}`
}

function mensajeInvitacion(c) {
  if (c.yaExistia) {
    return `Te volví a sumar a SinFila. Entrá con tu cuenta de siempre: ${window.location.origin}/login\n(si no te acordás la contraseña, pedime que te la restablezca)`
  }
  return `Te sumé a SinFila para que puedas entrar al panel.\nEmail: ${c.email}\nContraseña: ${c.password}\n\nEntrá en: ${window.location.origin}/login\n(te va a pedir confirmar el mail, y elegir tu propia contraseña la primera vez)`
}

const linkWhatsapp = computed(() => {
  if (!creado.value?.telefono) return null
  const tel = creado.value.telefono.replace(/\D/g, '')
  return `https://wa.me/${tel}?text=${encodeURIComponent(mensajeInvitacion(creado.value))}`
})

const copiado = ref(false)
async function copiarMensaje() {
  if (!creado.value) return
  try {
    await navigator.clipboard.writeText(mensajeInvitacion(creado.value))
    copiado.value = true
    setTimeout(() => (copiado.value = false), 1500)
  } catch {
    // clipboard puede fallar sin HTTPS/permiso — el texto ya está a la vista, no es bloqueante.
  }
}
</script>

<template>
  <section v-if="cargando" class="text-slate-500">Cargando…</section>
  <section v-else-if="error" class="text-red-600">{{ error }}</section>

  <section v-else class="max-w-3xl">
    <h1 class="text-2xl font-bold text-slate-900">Equipo</h1>
    <p class="text-sm text-slate-500">
      Cuentas para tu equipo. Todos entran al panel de pedidos (KDS); el nivel define qué más
      pueden ver o tocar del panel admin.
    </p>

    <div class="mt-4 flex flex-wrap gap-2">
      <button
        v-for="s in SECCIONES" :key="s[0]"
        type="button" @click="seccion = s[0]"
        :class="['chip', seccion === s[0] && 'chip-active']"
      >
        {{ s[1] }}
      </button>
    </div>

    <div v-show="seccion === 'agregar'">
    <div class="card mt-5 p-5">
      <h2 class="text-base font-bold text-slate-900">Sumar a alguien</h2>
      <form @submit.prevent="crear" class="mt-3 space-y-3">
        <div>
          <label class="mb-1 block text-sm font-medium text-slate-700">Nombre (opcional)</label>
          <input v-model="nombre" type="text" placeholder="Nombre y apellido" class="input w-full" />
        </div>
        <div>
          <label class="mb-1 block text-sm font-medium text-slate-700">Email</label>
          <input v-model="email" type="email" required placeholder="empleado@mail.com" class="input w-full" />
        </div>
        <div>
          <label class="mb-1 block text-sm font-medium text-slate-700">Teléfono (opcional)</label>
          <input v-model="telefono" type="tel" placeholder="+54 9 11 1234 5678" class="input w-full" />
          <p class="mt-1 text-xs text-slate-400">Para poder mandarle los datos directo por WhatsApp.</p>
        </div>
        <div>
          <label class="mb-1 block text-sm font-medium text-slate-700">Contraseña generada</label>
          <div class="flex gap-2">
            <input :value="password" readonly class="input w-full font-mono" />
            <button type="button" @click="regenerar" class="btn btn-ghost shrink-0 px-3 text-sm">Generar otra</button>
          </div>
        </div>
        <div>
          <label class="mb-1 block text-sm font-medium text-slate-700">Nivel de acceso</label>
          <div class="space-y-1.5">
            <div
              v-for="n in NIVELES_EQUIPO" :key="n.valor"
              :class="[
                'overflow-hidden rounded-lg border transition',
                nivelNuevo === n.valor ? 'border-brand-500' : 'border-slate-200',
              ]"
            >
              <label
                :class="['flex cursor-pointer items-start gap-2.5 p-2.5 text-sm', nivelNuevo === n.valor ? 'bg-brand-50/50' : 'hover:bg-slate-50']"
              >
                <input type="radio" :value="n.valor" v-model="nivelNuevo" class="mt-0.5 h-4 w-4 shrink-0 accent-brand-500" />
                <span class="min-w-0 flex-1">
                  <span class="block font-medium text-slate-900">{{ n.label }}</span>
                  <span class="block text-xs text-slate-500">{{ n.descripcion }}</span>
                </span>
                <button
                  type="button" @click.prevent="toggleExpandido(n.valor)"
                  class="shrink-0 rounded p-1 text-slate-400 hover:bg-slate-200/60 hover:text-slate-700"
                  :aria-label="`Ver el detalle de ${n.label}`"
                >
                  <svg
                    viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"
                    :class="['h-4 w-4 transition-transform', expandidos.has(n.valor) && 'rotate-180']"
                  >
                    <path d="M19.5 8.25l-7.5 7.5-7.5-7.5" stroke-linecap="round" stroke-linejoin="round" />
                  </svg>
                </button>
              </label>
              <div v-if="expandidos.has(n.valor)" class="border-t border-slate-100 bg-slate-50 px-3 py-2">
                <p
                  v-for="(activo, cap) in n.capacidades" :key="cap"
                  class="flex items-center gap-1.5 py-0.5 text-xs"
                  :class="activo ? 'text-slate-700' : 'text-slate-400'"
                >
                  <span :class="activo ? 'text-emerald-600' : 'text-slate-300'">{{ activo ? '✅' : '❌' }}</span>
                  {{ CAPACIDADES[cap] }}
                </p>
              </div>
            </div>
          </div>
        </div>
        <p v-if="errorForm" class="text-sm text-red-600">{{ errorForm }}</p>
        <button type="submit" :disabled="creando" class="btn btn-dark">
          {{ creando ? 'Creando…' : 'Crear cuenta' }}
        </button>
      </form>
    </div>

    <div v-if="creado" class="card mt-4 border-2 border-brand-500 p-5">
      <template v-if="creado.yaExistia">
        <h2 class="text-base font-bold text-slate-900">Ya tenía cuenta — la re-sumamos al equipo</h2>
        <p class="mt-1 text-sm text-slate-500">
          Ese mail ya estaba registrado (probablemente estuvo antes en el equipo y lo sacaste en algún
          momento). Ya puede entrar con la cuenta y la contraseña de siempre — no hizo falta crear una
          nueva. Si no se acuerda la contraseña, usá "Restablecer contraseña" en la lista de abajo.
        </p>
        <p class="mt-3 rounded-lg bg-slate-50 p-3 text-sm"><span class="text-slate-500">Email:</span> {{ creado.email }}</p>
      </template>
      <template v-else>
        <h2 class="text-base font-bold text-slate-900">Cuenta creada — pasale estos datos</h2>
        <p class="mt-1 text-sm text-slate-500">
          Le va a llegar un mail para confirmar la cuenta antes de poder entrar. Pasale el email y la
          contraseña (por WhatsApp, por ejemplo) para que pueda loguearse.
        </p>
        <div class="mt-3 rounded-lg bg-slate-50 p-3 text-sm">
          <p><span class="text-slate-500">Email:</span> {{ creado.email }}</p>
          <p><span class="text-slate-500">Contraseña:</span> <span class="font-mono">{{ creado.password }}</span></p>
        </div>
      </template>
      <div class="mt-3 flex flex-wrap gap-2">
        <a v-if="linkWhatsapp" :href="linkWhatsapp" target="_blank" rel="noopener" class="btn btn-brand text-sm">
          Enviar por WhatsApp
        </a>
        <button type="button" @click="copiarMensaje" class="btn btn-ghost text-sm">
          {{ copiado ? 'Copiado ✓' : 'Copiar mensaje para mandar' }}
        </button>
      </div>
    </div>
    </div>

    <div v-show="seccion === 'ver'" class="mt-5">
      <h2 class="text-lg font-bold text-slate-900">Tu equipo</h2>
      <ul class="mt-3 space-y-2">
        <li v-for="m in equipo" :key="m.usuario_id" class="card flex flex-wrap items-center justify-between gap-3 p-4">
          <div class="min-w-0">
            <p class="truncate text-sm font-medium text-slate-900">{{ m.nombre || m.email }}</p>
            <p v-if="m.nombre" class="truncate text-xs text-slate-400">{{ m.email }}</p>
            <div class="mt-1 flex flex-wrap items-center gap-1.5">
              <span
                :class="[
                  'rounded-full px-2 py-0.5 text-[10px] font-medium',
                  m.rol === 'dueño' ? 'bg-indigo-100 text-indigo-700' : 'bg-slate-100 text-slate-600',
                ]"
              >
                {{ m.rol === 'dueño' ? 'Dueño' : NIVELES_EQUIPO.find((n) => n.valor === nivelDeFila(m))?.label }}
              </span>
              <span v-if="!m.email_confirmado" class="rounded-full bg-amber-100 px-2 py-0.5 text-[10px] font-medium text-amber-700">
                Mail sin confirmar
              </span>
            </div>
            <p class="mt-1 text-xs text-slate-400">{{ ultimoAccesoTexto(m) }}</p>
          </div>

          <div class="flex shrink-0 flex-wrap items-center gap-3">
            <button type="button" @click="abrirFicha(m)" class="text-xs font-medium text-slate-500 hover:text-slate-800">
              Ficha
            </button>
            <template v-if="m.rol !== 'dueño'">
              <select
                :value="nivelDeFila(m)"
                @change="cambiarNivel(m, $event.target.value)"
                class="input w-auto py-1.5 text-sm"
              >
                <option v-for="n in NIVELES_EQUIPO" :key="n.valor" :value="n.valor">{{ n.label }}</option>
              </select>
              <button type="button" @click="restablecer(m)" class="text-xs font-medium text-slate-500 hover:text-slate-800">
                Restablecer contraseña
              </button>
              <button type="button" @click="quitar(m)" class="text-xs font-medium text-red-500 hover:text-red-700">
                Quitar
              </button>
            </template>
          </div>
        </li>
      </ul>
    </div>

    <FichaEmpleado :local="local" :miembro="fichaAbierta" @cerrar="cerrarFicha" @guardado="fichaGuardada" />
  </section>
</template>
