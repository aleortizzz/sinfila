<script setup>
import { ref } from 'vue'

defineProps({
  url: { type: String, default: '' },
  subiendo: { type: Boolean, default: false },
  ratio: { type: String, default: 'aspect-square' }, // aspect-square | aspect-video
  recomendado: { type: String, default: '' }, // ej. "800 × 600 px (4:3)"
})
const emit = defineEmits(['elegir', 'quitar'])

const inputRef = ref(null)

function onChange(e) {
  const f = e.target.files?.[0]
  if (f) emit('elegir', f)
  e.target.value = '' // permite re-elegir el mismo archivo
}
</script>

<template>
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
      <p class="text-[11px] text-slate-400">JPG, PNG o WEBP · hasta 5 MB</p>
    </div>

    <input ref="inputRef" type="file" accept="image/*" class="hidden" @change="onChange" />
  </div>
</template>
