<script setup>
import { ref, reactive, computed, onMounted, onUnmounted } from 'vue'
import { useRoute, useRouter, RouterLink } from 'vue-router'
import { obtenerLocalPorSlug } from '../lib/locales'
import { obtenerPedidosActivos, obtenerPedidoConItems, actualizarPedido, suscribirseAPedidos } from '../lib/pedidos'
import { supabase } from '../lib/supabase'
import { cerrarSesion } from '../lib/auth'

const route = useRoute()
const router = useRouter()

const cargando = ref(true)
const error = ref(null)
const local = ref(null)
// Map en vez de array: si por lo que sea llega el mismo pedido más de una
// vez (canales de Realtime duplicados de una recarga anterior, eventos que
// se pisan), escribir dos veces la misma clave no duplica nada — es
// imposible que un pedido aparezca dos veces en pantalla.
const pedidosPorId = reactive(new Map())
const pedidos = computed(() => [...pedidosPorId.values()].sort((a, b) => a.numero - b.numero))
const filtroEstacion = ref('todos') // 'todos' | 'barra' | 'cocina'

let canal = null

// Beep simple con Web Audio API — no hace falta ningún archivo de sonido.
// Los navegadores bloquean audio sin interacción previa del usuario; por
// eso el catch silencioso (no es un error real, solo no sonó esta vez).
function reproducirBeep() {
  try {
    const ctx = new (window.AudioContext || window.webkitAudioContext)()
    const osc = ctx.createOscillator()
    const gain = ctx.createGain()
    osc.connect(gain)
    gain.connect(ctx.destination)
    osc.frequency.value = 880
    gain.gain.setValueAtTime(0.2, ctx.currentTime)
    osc.start()
    osc.stop(ctx.currentTime + 0.25)
  } catch {
    // sin soporte / bloqueado por el navegador — no es crítico
  }
}

const ESTADOS_ACTIVOS = ['pendiente', 'en_preparacion', 'listo', 'avisado']

async function onCambioPedido(tipo, fila) {
  if (tipo === 'insert') {
    if (pedidosPorId.has(fila.id)) return // ya lo tenemos
    const completo = await obtenerPedidoConItems(fila.id)
    if (completo && !pedidosPorId.has(completo.id)) {
      pedidosPorId.set(completo.id, completo)
      reproducirBeep()
    }
    return
  }

  // update
  if (!ESTADOS_ACTIVOS.includes(fila.estado)) {
    pedidosPorId.delete(fila.id) // entregado / cancelado / rechazado -> sale de pantalla
    return
  }
  const existente = pedidosPorId.get(fila.id)
  if (!existente) {
    const completo = await obtenerPedidoConItems(fila.id)
    if (completo) pedidosPorId.set(completo.id, completo)
    return
  }
  // Mezclamos los campos de "pedidos" que cambiaron, conservando los
  // pedido_items ya cargados (el evento de UPDATE no los trae).
  pedidosPorId.set(fila.id, { ...existente, ...fila })
}

onMounted(async () => {
  try {
    local.value = await obtenerLocalPorSlug(route.params.slug)
    if (!local.value) {
      error.value = 'No encontramos este local.'
      return
    }
    const activos = await obtenerPedidosActivos(local.value.id)
    activos.forEach((p) => pedidosPorId.set(p.id, p))

    // Por las dudas queden canales de una recarga/HMR anterior sin cerrar
    // bien: los sacamos a todos antes de suscribirnos, así nunca hay dos
    // canales mandando el mismo evento dos veces.
    await supabase.removeAllChannels()
    canal = suscribirseAPedidos(local.value.id, onCambioPedido)
  } catch (e) {
    error.value = e.message
  } finally {
    cargando.value = false
  }
})

onUnmounted(() => {
  if (canal) supabase.removeChannel(canal)
})

// En la vista de una estación, un pedido solo tiene sentido mientras esa
// estación todavía tenga algo pendiente: ni pedidos que no le tocan, ni los
// que esa estación ya marcó lista (aunque el pedido en conjunto siga
// "en_preparación" esperando a la otra estación) — esos quedan solo en
// "Todos".
const pedidosFiltrados = computed(() => {
  if (filtroEstacion.value === 'todos') return pedidos.value
  const requiere = filtroEstacion.value === 'barra' ? 'requiere_barra' : 'requiere_cocina'
  const lista = filtroEstacion.value === 'barra' ? 'barra_lista' : 'cocina_lista'
  return pedidos.value.filter((p) => p[requiere] && !p[lista])
})

function itemsVisibles(pedido) {
  if (filtroEstacion.value === 'todos') return pedido.pedido_items
  return pedido.pedido_items.filter((i) => i.estacion === filtroEstacion.value)
}

// El valor de "estado" en la base es lenguaje de sistema (útil para el
// código); acá lo traducimos a algo que lea un humano en la pantalla.
function etiquetaEstado(p) {
  const delivery = p.tipo_entrega === 'delivery'
  return (
    {
      pendiente: 'Pendiente',
      en_preparacion: 'En preparación',
      listo: 'Listo',
      avisado: delivery ? 'En camino' : 'Listo para retirar',
    }[p.estado] ?? p.estado
  )
}

function colorEstado(estado) {
  return {
    pendiente: 'border-amber-400 bg-amber-50',
    en_preparacion: 'border-blue-400 bg-blue-50',
    listo: 'border-green-400 bg-green-50',
    avisado: 'border-purple-400 bg-purple-50',
  }[estado]
}

async function aceptar(p) {
  await actualizarPedido(p.id, { estado: 'en_preparacion' })
}
async function rechazar(p) {
  if (confirm(`¿Rechazar el pedido #${p.numero}?`)) await actualizarPedido(p.id, { estado: 'rechazado' })
}
async function marcarEstacionLista(p, estacion) {
  await actualizarPedido(p.id, { [`${estacion}_lista`]: true })
}
// "Listo" (cocina/barra terminaron) -> "avisado": se le avisa al cliente
// que venga a buscarlo (más adelante esto dispara el push al celu del
// cliente). El pedido sigue en pantalla hasta que alguien confirma que
// se lo llevó de verdad.
async function avisarListo(p) {
  await actualizarPedido(p.id, { estado: 'avisado' })
}
async function entregar(p) {
  await actualizarPedido(p.id, { estado: 'entregado' })
}

function linkWhatsapp(p) {
  const tel = p.telefono_cliente.replace(/\D/g, '')
  const msg = encodeURIComponent(
    `Hola ${p.nombre_cliente}! Tu pedido #${p.numero} en ${local.value.nombre} ya está listo para retirar 🎉`,
  )
  return `https://wa.me/${tel}?text=${msg}`
}

async function salir() {
  await cerrarSesion()
  router.push('/login')
}
</script>

<template>
  <div class="min-h-screen bg-slate-100">
    <section v-if="cargando" class="p-6 text-slate-500">Cargando…</section>
    <section v-else-if="error" class="p-6 text-red-600">{{ error }}</section>

    <section v-else>
      <header class="border-b border-slate-200 bg-white">
        <div class="mx-auto flex max-w-6xl flex-wrap items-center justify-between gap-3 px-6 py-3">
          <h1 class="text-lg font-bold text-slate-900">{{ local.nombre }} · Pedidos</h1>
          <div class="flex items-center gap-4 text-sm">
            <RouterLink
              :to="`/panel/${route.params.slug}/admin`"
              class="font-medium text-slate-500 hover:text-slate-900"
            >
              Panel admin
            </RouterLink>
            <button type="button" @click="salir" class="font-medium text-slate-500 hover:text-slate-900">
              Cerrar sesión
            </button>
          </div>
        </div>
      </header>

      <div class="mx-auto max-w-6xl p-6">
        <div class="flex gap-2">
          <button
            v-for="op in [['todos', 'Todos'], ['barra', 'Barra'], ['cocina', 'Cocina']]"
            :key="op[0]"
            type="button"
            @click="filtroEstacion = op[0]"
            :class="['chip', filtroEstacion === op[0] && 'chip-active']"
          >
            {{ op[1] }}
          </button>
        </div>

        <p v-if="pedidosFiltrados.length === 0" class="mt-10 text-center text-slate-500">
          No hay pedidos activos.
        </p>

        <div class="mt-5 grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4">
          <article
            v-for="p in pedidosFiltrados"
            :key="p.id"
            :class="['rounded-2xl border-2 bg-white p-4 shadow-sm', colorEstado(p.estado)]"
          >
            <div class="flex items-center justify-between">
              <span class="text-xl font-extrabold text-slate-900">#{{ p.numero }}</span>
              <span class="rounded-full bg-white/70 px-2 py-0.5 text-[11px] font-bold uppercase tracking-wide text-slate-600">
                {{ etiquetaEstado(p) }}
              </span>
            </div>

            <p class="mt-2 font-semibold text-slate-900">{{ p.nombre_cliente }}</p>
            <p class="text-sm text-slate-500">{{ p.telefono_cliente }}</p>
            <p class="mt-1 text-sm text-slate-500">
              {{ p.tipo_entrega === 'delivery' ? '🛵 Delivery' : '🏠 Retiro' }}
              <span v-if="p.tipo_entrega === 'delivery'">— {{ p.direccion_calle }} {{ p.direccion_numero }}, {{ p.direccion_barrio }}</span>
            </p>
            <p class="text-sm text-slate-500">
              {{ p.metodo_pago === 'efectivo' ? '💵 Efectivo' : '🏦 Transferencia' }}
              <span v-if="p.metodo_pago === 'transferencia'">
                {{ p.transferencia_avisada ? '(avisó que ya transfirió)' : '(todavía no avisó)' }}
              </span>
            </p>

            <ul class="mt-3 space-y-1 border-t border-slate-200/70 pt-2 text-sm">
              <li v-for="item in itemsVisibles(p)" :key="item.id">
                <span class="font-medium">{{ item.cantidad }}×</span> {{ item.nombre }}
                <span v-if="item.opciones_elegidas?.length" class="text-xs text-slate-500">
                  ({{ item.opciones_elegidas.map((o) => o.opcion).join(', ') }})
                </span>
                <span class="text-xs text-slate-400">· {{ item.estacion }}</span>
              </li>
            </ul>

            <p class="mt-2 text-right font-bold text-slate-900">${{ p.total }}</p>

            <div class="mt-3 flex flex-wrap gap-2">
              <template v-if="p.estado === 'pendiente'">
                <button type="button" @click="aceptar(p)" class="btn btn-dark px-3 py-1.5 text-xs">
                  Iniciar preparación
                </button>
                <button
                  type="button"
                  @click="rechazar(p)"
                  class="btn border border-red-300 px-3 py-1.5 text-xs text-red-600 hover:bg-red-50"
                >
                  Rechazar
                </button>
              </template>

              <template v-else-if="p.estado === 'en_preparacion'">
                <!-- Vista Todos: solo el estado de cada estación (acá no se accionan). -->
                <template v-if="filtroEstacion === 'todos'">
                  <span v-if="p.requiere_barra" :class="p.barra_lista ? 'text-green-700' : 'text-slate-500'" class="text-sm">
                    {{ p.barra_lista ? '✓ Barra lista' : '⏳ Falta barra' }}
                  </span>
                  <span v-if="p.requiere_cocina" :class="p.cocina_lista ? 'text-green-700' : 'text-slate-500'" class="text-sm">
                    {{ p.cocina_lista ? '✓ Cocina lista' : '⏳ Falta cocina' }}
                  </span>
                </template>
                <!-- Vista Barra/Cocina: ya está filtrado a lo que falta, un solo botón. -->
                <button
                  v-else
                  type="button"
                  @click="marcarEstacionLista(p, filtroEstacion)"
                  class="btn btn-dark px-3 py-1.5 text-xs"
                >
                  Pedido listo
                </button>
              </template>

              <template v-else-if="p.estado === 'listo'">
                <button type="button" @click="avisarListo(p)" class="btn btn-dark px-3 py-1.5 text-xs">
                  Listo para entregar
                </button>
                <a
                  :href="linkWhatsapp(p)"
                  target="_blank"
                  rel="noopener"
                  class="btn border border-green-300 px-3 py-1.5 text-xs text-green-700 hover:bg-green-50"
                >
                  Avisar por WhatsApp
                </a>
              </template>

              <template v-else-if="p.estado === 'avisado'">
                <button type="button" @click="entregar(p)" class="btn btn-dark px-3 py-1.5 text-xs">
                  Marcar entregado
                </button>
                <a
                  :href="linkWhatsapp(p)"
                  target="_blank"
                  rel="noopener"
                  class="btn border border-green-300 px-3 py-1.5 text-xs text-green-700 hover:bg-green-50"
                >
                  Avisar por WhatsApp
                </a>
              </template>
            </div>
          </article>
        </div>
      </div>
    </section>
  </div>
</template>
