<script setup>
import { ref } from 'vue'

const props = defineProps({
  url: { type: String, default: '' },
  subiendo: { type: Boolean, default: false },
  ratio: { type: String, default: 'aspect-square' }, // aspect-square | aspect-video
  recomendado: { type: String, default: '' }, // ej. "800 × 600 px (4:3)"
  nota: { type: String, default: '' }, // aclaración extra (ej. cómo se recorta)
  error: { type: String, default: '' }, // error de subida que setea el padre
})
const emit = defineEmits(['elegir', 'quitar'])

const TIPOS_OK = ['image/png', 'image/jpeg', 'image/webp', 'image/gif']
const MAX_MB = 5

const inputRef = ref(null)
const errorLocal = ref('')

function onChange(e) {
  errorLocal.value = ''
  const f = e.target.files?.[0]
  e.target.value = '' // permite re-elegir el mismo archivo
  if (!f) return

  if (!TIPOS_OK.includes(f.type)) {
    errorLocal.value = `Ese archivo es ${f.type || 'de un tipo no reconocido'}. Subí una imagen JPG, PNG o WEBP.`
    return
  }
  const mb = f.size / 1024 / 1024
  if (mb > MAX_MB) {
    errorLocal.value = `La imagen pesa ${mb.toFixed(1)} MB y el máximo son ${MAX_MB} MB. Probá con una más liviana.`
    return
  }
  emit('elegir', f)
}
</script>

<template>
  <div>
    <div class="flex items-center gap-3">
      <div :class="['w-28 shrink-0 overflow-hidden rounded-lg border border-slate-200 bg-slate-50', ratio]">
        <img v-if="url" :src="url" alt="" class="h-full w-full object-cover" />
        <div v-else class="flex h-full w-full items-center justify-center text-[11px] text-slate-400">
          sin imagen
        </div>
      </div>

      <div class="flex flex-col items-start gap-1">
        <button
          type="button"
          :disabled="subiendo"
          @click="inputRef?.click()"
          class="btn btn-ghost px-3 py-1.5 text-xs"
        >
          {{ subiendo ? 'Subiendo…' : url ? 'Cambiar imagen' : 'Subir imagen' }}
        </button>
        <button
          v-if="url && !subiendo"
          type="button"
          @click="emit('quitar')"
          class="text-xs font-medium text-slate-500 hover:text-red-600"
        >
          Quitar
        </button>
        <p v-if="recomendado" class="text-[11px] font-medium text-slate-500">
          Resolución recomendada: {{ recomendado }}
        </p>
        <p v-if="nota" class="max-w-xs text-[11px] leading-tight text-slate-400">{{ nota }}</p>
        <p class="text-[11px] text-slate-400">JPG, PNG o WEBP · hasta 5 MB</p>
      </div>

      <input ref="inputRef" type="file" accept="image/*" class="hidden" @change="onChange" />
    </div>

    <p v-if="errorLocal || error" class="mt-2 text-xs font-medium text-red-600">
      {{ errorLocal || error }}
    </p>
  </div>
</template>
