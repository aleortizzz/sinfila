<script setup>
import { ref, onMounted, onBeforeUnmount } from 'vue'

// Chrome/Edge/Android disparan 'beforeinstallprompt'. iOS Safari no lo
// soporta (ahí se instala con Compartir → Agregar a inicio); el manifest
// igual hace que quede con ícono y nombre.
const evento = ref(null)
const oculto = ref(true)

function onPrompt(e) {
  e.preventDefault()
  evento.value = e
  try {
    oculto.value = localStorage.getItem('sinfila_install_off') === '1'
  } catch {
    oculto.value = false
  }
}
function onInstalled() {
  evento.value = null
  oculto.value = true
}

onMounted(() => {
  window.addEventListener('beforeinstallprompt', onPrompt)
  window.addEventListener('appinstalled', onInstalled)
})
onBeforeUnmount(() => {
  window.removeEventListener('beforeinstallprompt', onPrompt)
  window.removeEventListener('appinstalled', onInstalled)
})

async function instalar() {
  if (!evento.value) return
  evento.value.prompt()
  await evento.value.userChoice
  evento.value = null
  oculto.value = true
}
function noGracias() {
  try {
    localStorage.setItem('sinfila_install_off', '1')
  } catch {
    /* privado / sin storage — igual lo ocultamos esta vez */
  }
  oculto.value = true
}
</script>

<template>
  <div v-if="evento && !oculto" class="mx-auto mt-3 max-w-5xl px-5">
    <div class="flex items-center justify-between gap-3 rounded-xl border border-slate-200 bg-white px-4 py-2.5 text-sm shadow-sm">
      <span class="text-slate-700">Instalá la carta como app para entrar más rápido.</span>
      <div class="flex shrink-0 gap-2">
        <button type="button" @click="noGracias" class="text-xs font-medium text-slate-400 hover:text-slate-600">
          Ahora no
        </button>
        <button type="button" @click="instalar" class="btn btn-brand px-3 py-1.5 text-xs">Instalar</button>
      </div>
    </div>
  </div>
</template>
