<script setup>
import { ref, reactive, computed, onMounted, onUnmounted } from 'vue'
import { useRoute, useRouter, RouterLink } from 'vue-router'
import { obtenerLocalPorSlug } from '../lib/locales'
import { obtenerPedidosActivos, obtenerPedidoConItems, actualizarPedido, suscribirseAPedidos } from '../lib/pedidos'
import { pesos } from '../lib/formato'
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

// Vistas:
//  - caja: mostrador. Ve TODO el ciclo con todos los datos (cliente, pago,
//    entrega). El pedido entra 'pendiente' y solo se ve acá hasta que caja
//    confirma el pago/pedido → recién ahí pasa a preparación.
//  - barra / cocina: solo pedidos ya confirmados (en_preparacion) que les
//    tocan y que todavía no marcaron listos. Tarjeta mínima: sin pago ni
//    entrega, solo lo que hace falta para preparar.
const vista = ref('caja') // 'caja' | 'barra' | 'cocina'
const esCaja = computed(() => vista.value === 'caja')

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

const pedidosFiltrados = computed(() => {
  if (esCaja.value) return pedidos.value
  const requiere = vista.value === 'barra' ? 'requiere_barra' : 'requiere_cocina'
  const lista = vista.value === 'barra' ? 'barra_lista' : 'cocina_lista'
  return pedidos.value.filter(
    (p) => p.estado === 'en_preparacion' && p[requiere] && !p[lista],
  )
})

function itemsVisibles(pedido) {
  if (esCaja.value) return pedido.pedido_items
  return pedido.pedido_items.filter((i) => i.estacion === vista.value)
}

// El valor de "estado" en la base es lenguaje de sistema; acá lo traducimos.
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

// Etiqueta del botón que abre la preparación, según el método de pago.
function textoConfirmar(p) {
  return p.metodo_pago === 'transferencia' ? 'Confirmar pago e iniciar' : 'Aceptar e iniciar'
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
// "Listo" (cocina/barra terminaron) -> "avisado": se le avisa al cliente que
// venga a buscarlo. El pedido sigue en pantalla hasta que se confirma la
// entrega de verdad.
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
            v-for="op in [['caja', 'Caja'], ['barra', 'Barra'], ['cocina', 'Cocina']]"
            :key="op[0]"
            type="button"
            @click="vista = op[0]"
            :class="['chip', vista === op[0] && 'chip-active']"
          >
            {{ op[1] }}
          </button>
        </div>

        <p v-if="pedidosFiltrados.length === 0" class="mt-10 text-center text-slate-500">
          {{ esCaja ? 'No hay pedidos activos.' : 'No hay nada para preparar en esta estación.' }}
        </p>

        <div class="mt-5 grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4">
          <article
            v-for="p in pedidosFiltrados"
            :key="p.id"
            :class="['rounded-2xl border-2 bg-white p-4 shadow-sm', colorEstado(p.estado)]"
          >
            <!-- ===== Vista Caja / mostrador ===== -->
            <template v-if="esCaja">
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
                  {{ p.transferencia_avisada ? '· avisó que transfirió' : '· todavía no avisó' }}
                </span>
              </p>

              <ul class="mt-3 space-y-1 border-t border-slate-200/70 pt-2 text-sm">
                <li v-for="item in p.pedido_items" :key="item.id">
                  <span class="font-medium">{{ item.cantidad }}×</span> {{ item.nombre }}
                  <span v-if="item.opciones_elegidas?.length" class="text-xs text-slate-500">
                    ({{ item.opciones_elegidas.map((o) => o.opcion).join(', ') }})
                  </span>
                  <span class="text-xs text-slate-400">· {{ item.estacion }}</span>
                </li>
              </ul>

              <p class="mt-2 text-right font-bold text-slate-900">{{ pesos(p.total) }}</p>

              <div class="mt-3 flex flex-wrap gap-2">
                <template v-if="p.estado === 'pendiente'">
                  <button type="button" @click="aceptar(p)" class="btn btn-dark px-3 py-1.5 text-xs">
                    {{ textoConfirmar(p) }}
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
                  <span v-if="p.requiere_barra" :class="p.barra_lista ? 'text-green-700' : 'text-slate-500'" class="text-sm">
                    {{ p.barra_lista ? '✓ Barra lista' : '⏳ Falta barra' }}
                  </span>
                  <span v-if="p.requiere_cocina" :class="p.cocina_lista ? 'text-green-700' : 'text-slate-500'" class="text-sm">
                    {{ p.cocina_lista ? '✓ Cocina lista' : '⏳ Falta cocina' }}
                  </span>
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
            </template>

            <!-- ===== Vista Barra / Cocina: solo lo necesario para preparar ===== -->
            <template v-else>
              <div class="flex items-baseline justify-between">
                <span class="text-2xl font-extrabold text-slate-900">#{{ p.numero }}</span>
                <span class="text-sm font-medium text-slate-500">{{ p.nombre_cliente }}</span>
              </div>

              <ul class="mt-3 space-y-1 border-t border-slate-200/70 pt-3 text-base">
                <li v-for="item in itemsVisibles(p)" :key="item.id">
                  <span class="font-bold">{{ item.cantidad }}×</span> {{ item.nombre }}
                  <span v-if="item.opciones_elegidas?.length" class="text-sm text-slate-500">
                    ({{ item.opciones_elegidas.map((o) => o.opcion).join(', ') }})
                  </span>
                </li>
              </ul>

              <button
                type="button"
                @click="marcarEstacionLista(p, vista)"
                class="btn btn-dark mt-3 w-full py-2 text-sm"
              >
                Pedido listo
              </button>
            </template>
          </article>
        </div>
      </div>
    </section>
  </div>
</template>
