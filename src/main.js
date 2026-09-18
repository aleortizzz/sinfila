import { createApp } from 'vue'
import { createPinia } from 'pinia'
import './style.css'
import { router } from './router'
import App from './App.vue'

// El service worker (registrado automáticamente por vite-plugin-pwa, ver
// vite.config.js) solo revisa si hay una versión nueva cuando el
// navegador hace una navegación real — pero esto es una SPA: alguien
// puede dejar el panel/KDS abierto todo el día sin recargar nunca, y ese
// chequeo no se dispara solo. Sin esto, la única forma de ver un deploy
// nuevo era entrar en incógnito o forzar un hard refresh (inviable si
// escala a un local con varios empleados en distintos dispositivos).
// Con "autoUpdate" configurado, apenas encuentra una versión nueva la
// aplica y recarga sola — esto solo agrega el chequeo periódico que
// faltaba para que eso realmente llegue a dispararse.
if ('serviceWorker' in navigator) {
  navigator.serviceWorker.ready.then((registration) => {
    const revisar = () => registration.update()
    setInterval(revisar, 15 * 60 * 1000)
    document.addEventListener('visibilitychange', () => {
      if (document.visibilityState === 'visible') revisar()
    })
  })
}

createApp(App).use(createPinia()).use(router).mount('#app')
