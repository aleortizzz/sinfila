<script setup>
import { ref, reactive, computed, onMounted, watch } from 'vue'
import { useRoute, useRouter, RouterLink } from 'vue-router'
import { useCartStore } from '../stores/cart'
import { obtenerLocalPorSlug } from '../lib/locales'
import { obtenerZonasDelivery, crearPedido } from '../lib/pedidos'

const route = useRoute()
const router = useRouter()
const cart = useCartStore()

const cargando = ref(true)
const error = ref(null)
const local = ref(null)
const zonas = ref([])

const nombreCliente = ref('')
const telefonoCliente = ref('')
const tipoEntrega = ref('retiro')
const metodoPago = ref('efectivo')
const transferenciaConfirmada = ref(false)
const direccion = reactive({ barrio: '', calle: '', numero: '', pisoDepto: '', referencia: '' })

const enviando = ref(false)
const errorEnvio = ref(null)
const pedidoConfirmado = ref(null)

onMounted(async () => {
  // Sin carrito (o de otro local) acá no hay nada que hacer.
  if (cart.items.length === 0 || cart.localSlug !== route.params.slug) {
    router.replace(`/${route.params.slug}`)
    return
  }
  try {
    local.value = await obtenerLocalPorSlug(route.params.slug)
    if (!local.value) {
      error.value = 'No encontramos este local.'
      return
    }
    tipoEntrega.value = local.value.acepta_retiro ? 'retiro' : 'delivery'
    metodoPago.value = local.value.acepta_efectivo ? 'efectivo' : 'transferencia'
    if (local.value.acepta_delivery) {
      zonas.value = await obtenerZonasDelivery(local.value.id)
    }
  } catch (e) {
    error.value = e.message
  } finally {
    cargando.value = false
  }
})

// Si el cliente vacía el carrito desde acá mismo (sacando todo con el "−"),
// no tiene sentido seguir en el checkout. No aplica si ya se confirmó el
// pedido: ahí el carrito se vacía a propósito al terminar.
watch(
  () => cart.items.length,
  (cantidad) => {
    if (cantidad === 0 && !pedidoConfirmado.value) {
      router.replace(`/${route.params.slug}`)
    }
  },
)

const zonaElegida = computed(() => zonas.value.find((z) => z.barrio === direccion.barrio))

const costoEnvio = computed(() => {
  if (tipoEntrega.value !== 'delivery' || !zonaElegida.value) return 0
  // Number(): los numeric de Postgres llegan como string por PostgREST.
  return Number(
    local.value.delivery_costo_modo === 'por_barrio'
      ? zonaElegida.value.costo
      : local.value.delivery_costo_fijo,
  )
})

const total = computed(() => cart.subtotal + costoEnvio.value)

const cumpleMinimo = computed(
  () => tipoEntrega.value !== 'delivery' || cart.subtotal >= Number(local.value?.delivery_minimo_compra ?? 0),
)

const direccionValida = computed(
  () => tipoEntrega.value !== 'delivery' || (direccion.barrio && direccion.calle && direccion.numero),
)

// El botón de confirmar nunca está bloqueado: si falta algo, al apretarlo
// se marca el campo en rojo y la vista sube hasta ahí, en vez de dejar al
// cliente adivinando por qué no puede avanzar.
const intentoConfirmar = ref(false)
const datosRef = ref(null)
const entregaRef = ref(null)
const pagoRef = ref(null)

const errorNombre = computed(() => intentoConfirmar.value && !nombreCliente.value.trim())
const errorTelefono = computed(() => intentoConfirmar.value && !telefonoCliente.value.trim())
const errorDireccion = computed(() => intentoConfirmar.value && !direccionValida.value)
const errorTransferencia = computed(
  () => intentoConfirmar.value && metodoPago.value === 'transferencia' && !transferenciaConfirmada.value,
)

function scrollA(elRef) {
  elRef.value?.scrollIntoView({ behavior: 'smooth', block: 'center' })
}

async function onConfirmarClick() {
  intentoConfirmar.value = true

  if (errorNombre.value || errorTelefono.value) {
    scrollA(datosRef)
    return
  }
  if (errorDireccion.value || !cumpleMinimo.value) {
    scrollA(entregaRef)
    return
  }
  if (errorTransferencia.value) {
    scrollA(pagoRef)
    return
  }
  await confirmar()
}

async function confirmar() {
  errorEnvio.value = null
  enviando.value = true
  try {
    let direccionPayload = null
    if (tipoEntrega.value === 'delivery') {
      const partes = [
        `${direccion.calle} ${direccion.numero}`,
        direccion.pisoDepto,
        direccion.barrio,
      ].filter(Boolean)
      direccionPayload = {
        calle: direccion.calle,
        numero: direccion.numero,
        piso_depto: direccion.pisoDepto || null,
        barrio: direccion.barrio,
        referencia: direccion.referencia || null,
        maps_url: `https://www.google.com/maps/search/?api=1&query=${encodeURIComponent(partes.join(', '))}`,
      }
    }

    const resultado = await crearPedido({
      local_slug: route.params.slug,
      tipo_entrega: tipoEntrega.value,
      metodo_pago: metodoPago.value,
      nombre_cliente: nombreCliente.value.trim(),
      telefono_cliente: telefonoCliente.value.trim(),
      direccion: direccionPayload,
      items: cart.items.map((i) => ({
        tipo: i.tipo,
        ref_id: i.refId,
        cantidad: i.cantidad,
        opciones: i.opciones.map((o) => o.opcionId),
      })),
    })
    pedidoConfirmado.value = resultado
    cart.vaciar()
  } catch (e) {
    errorEnvio.value = e.message
  } finally {
    enviando.value = false
  }
}
</script>

<template>
  <div
    class="mx-auto max-w-xl px-5 py-6"
    :style="local && local.color_primario ? { '--brand': local.color_primario } : null"
  >
    <section v-if="cargando" class="py-24 text-center text-slate-500">Cargando…</section>
    <section v-else-if="error" class="py-24 text-center text-red-600">{{ error }}</section>

    <!-- Confirmación -->
    <section v-else-if="pedidoConfirmado" class="card mt-6 p-8 text-center">
      <div class="mx-auto flex h-14 w-14 items-center justify-center rounded-full bg-green-100">
        <svg viewBox="0 0 24 24" class="h-7 w-7 text-green-600" fill="none" stroke="currentColor" stroke-width="2.5">
          <path d="M5 13l4 4L19 7" stroke-linecap="round" stroke-linejoin="round" />
        </svg>
      </div>
      <p class="mt-3 text-sm text-slate-500">¡Listo, {{ nombreCliente }}!</p>
      <p class="mt-1 text-4xl font-extrabold text-slate-900">Pedido #{{ pedidoConfirmado.numero }}</p>
      <p class="mt-2 text-sm text-slate-500">Te avisamos cuando esté listo.</p>
      <RouterLink :to="`/pedido/${pedidoConfirmado.id}`" class="btn btn-brand mt-6 w-full">
        Seguir mi pedido
      </RouterLink>
      <RouterLink
        :to="`/${route.params.slug}`"
        class="mt-3 inline-block text-sm font-medium text-slate-500 underline"
      >
        Volver a la carta
      </RouterLink>
    </section>

    <!-- Formulario -->
    <section v-else>
      <div class="flex items-center justify-between">
        <h1 class="text-xl font-bold text-slate-900">Confirmá tu pedido</h1>
        <RouterLink
          :to="`/${route.params.slug}`"
          class="text-sm font-medium text-slate-500 underline hover:text-slate-900"
        >
          ← Seguir pidiendo
        </RouterLink>
      </div>

      <!-- Resumen -->
      <div class="card mt-4 p-4">
        <ul class="divide-y divide-slate-100 text-sm">
          <li
            v-for="item in cart.items"
            :key="item.id"
            class="flex items-center justify-between gap-2 py-2.5"
          >
            <div class="min-w-0">
              <p class="truncate font-medium text-slate-900">{{ item.nombre }}</p>
              <p v-if="item.opciones.length" class="truncate text-xs text-slate-500">
                {{ item.opciones.map((o) => o.opcionNombre).join(', ') }}
              </p>
            </div>
            <div class="flex shrink-0 items-center gap-3">
              <div class="flex items-center gap-1.5">
                <button
                  type="button"
                  @click="cart.cambiarCantidad(item.id, item.cantidad - 1)"
                  class="flex h-7 w-7 items-center justify-center rounded-full border border-slate-300 text-slate-600 hover:bg-slate-100"
                >
                  −
                </button>
                <span class="w-4 text-center">{{ item.cantidad }}</span>
                <button
                  type="button"
                  @click="cart.cambiarCantidad(item.id, item.cantidad + 1)"
                  class="flex h-7 w-7 items-center justify-center rounded-full border border-slate-300 text-slate-600 hover:bg-slate-100"
                >
                  +
                </button>
              </div>
              <span class="w-16 text-right font-medium">${{ cart.precioUnitario(item) * item.cantidad }}</span>
              <button type="button" @click="cart.quitar(item.id)" class="text-slate-300 hover:text-brand-600">✕</button>
            </div>
          </li>
        </ul>
        <div class="mt-2 space-y-1 border-t border-slate-200 pt-2 text-sm">
          <div class="flex justify-between text-slate-500"><span>Subtotal</span><span>${{ cart.subtotal }}</span></div>
          <div v-if="tipoEntrega === 'delivery'" class="flex justify-between text-slate-500">
            <span>Envío</span><span>${{ costoEnvio }}</span>
          </div>
          <div class="flex justify-between pt-1 text-base font-bold text-slate-900">
            <span>Total</span><span>${{ total }}</span>
          </div>
        </div>
      </div>

      <!-- Datos del cliente -->
      <div ref="datosRef" class="card mt-4 p-4">
        <h2 class="label">Tus datos</h2>
        <div class="mt-3 space-y-2">
          <div>
            <input
              v-model="nombreCliente"
              type="text"
              placeholder="Nombre"
              :class="['input', errorNombre && 'border-red-500']"
            />
            <p v-if="errorNombre" class="mt-1 text-xs text-red-600">Campo obligatorio</p>
          </div>
          <div>
            <input
              v-model="telefonoCliente"
              type="tel"
              placeholder="Teléfono"
              :class="['input', errorTelefono && 'border-red-500']"
            />
            <p v-if="errorTelefono" class="mt-1 text-xs text-red-600">Campo obligatorio</p>
          </div>
        </div>
      </div>

      <!-- Entrega -->
      <div ref="entregaRef" class="card mt-4 p-4">
        <h2 class="label">Entrega</h2>
        <div class="mt-3 flex gap-2">
          <button
            v-if="local.acepta_retiro"
            type="button"
            @click="tipoEntrega = 'retiro'"
            :class="['chip', tipoEntrega === 'retiro' && 'chip-active']"
          >
            Retiro en el local
          </button>
          <button
            v-if="local.acepta_delivery"
            type="button"
            @click="tipoEntrega = 'delivery'"
            :class="['chip', tipoEntrega === 'delivery' && 'chip-active']"
          >
            Delivery
          </button>
        </div>

        <div v-if="tipoEntrega === 'delivery'" class="mt-3 space-y-2">
          <select
            v-model="direccion.barrio"
            :class="['input', errorDireccion && !direccion.barrio && 'border-red-500']"
          >
            <option value="" disabled>Elegí tu barrio…</option>
            <option v-for="z in zonas" :key="z.barrio" :value="z.barrio">{{ z.barrio }}</option>
          </select>
          <div class="flex gap-2">
            <input
              v-model="direccion.calle"
              type="text"
              placeholder="Calle"
              :class="['input w-2/3', errorDireccion && !direccion.calle && 'border-red-500']"
            />
            <input
              v-model="direccion.numero"
              type="text"
              placeholder="Número"
              :class="['input w-1/3', errorDireccion && !direccion.numero && 'border-red-500']"
            />
          </div>
          <p v-if="errorDireccion" class="text-xs text-red-600">Completá barrio, calle y número.</p>
          <input v-model="direccion.pisoDepto" type="text" placeholder="Piso / depto (opcional)" class="input" />
          <input v-model="direccion.referencia" type="text" placeholder="Referencia (opcional)" class="input" />
          <p v-if="!cumpleMinimo" class="text-sm text-red-600">
            El mínimo para delivery es ${{ Number(local.delivery_minimo_compra) }}.
          </p>
        </div>
      </div>

      <!-- Pago -->
      <div ref="pagoRef" class="card mt-4 p-4">
        <h2 class="label">Pago</h2>
        <div class="mt-3 flex gap-2">
          <button
            v-if="local.acepta_efectivo"
            type="button"
            @click="metodoPago = 'efectivo'"
            :class="['chip', metodoPago === 'efectivo' && 'chip-active']"
          >
            Efectivo
          </button>
          <button
            v-if="local.acepta_transferencia"
            type="button"
            @click="metodoPago = 'transferencia'"
            :class="['chip', metodoPago === 'transferencia' && 'chip-active']"
          >
            Transferencia
          </button>
        </div>

        <div v-if="metodoPago === 'transferencia'" class="mt-3 rounded-xl bg-slate-50 p-3 text-sm">
          <p v-if="local.alias_transferencia">Alias: <strong>{{ local.alias_transferencia }}</strong></p>
          <p v-if="local.cbu_transferencia">CBU: <strong>{{ local.cbu_transferencia }}</strong></p>
          <label class="mt-2 flex items-center gap-2">
            <input v-model="transferenciaConfirmada" type="checkbox" />
            Ya hice la transferencia
          </label>
          <p v-if="errorTransferencia" class="mt-1 text-xs text-red-600">
            Confirmá que ya hiciste la transferencia para continuar.
          </p>
        </div>
      </div>

      <p v-if="errorEnvio" class="mt-4 text-sm text-red-600">{{ errorEnvio }}</p>

      <button
        type="button"
        :disabled="enviando"
        @click="onConfirmarClick"
        class="btn btn-brand mt-5 w-full py-3.5 text-base"
      >
        {{ enviando ? 'Enviando…' : `Confirmar pedido — $${total}` }}
      </button>
    </section>
  </div>
</template>
