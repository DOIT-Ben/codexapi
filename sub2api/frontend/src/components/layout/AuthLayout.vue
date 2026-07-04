<template>
  <div class="relative flex min-h-screen items-center justify-center overflow-hidden bg-[#faf9f5] p-4 text-[#263126] dark:bg-[#10120d] dark:text-gray-100">
    <div
      class="absolute inset-0 bg-[linear-gradient(135deg,#fffdf8_0%,#faf9f5_54%,#eee6dc_100%)] dark:bg-[linear-gradient(135deg,#191b12_0%,#10120d_56%,#1e2417_100%)]"
    ></div>

    <div class="pointer-events-none absolute inset-0 overflow-hidden">
      <div class="absolute inset-x-0 top-0 h-48 bg-gradient-to-b from-primary-100/70 to-transparent dark:from-primary-950/25"></div>
      <div class="absolute inset-y-0 right-0 w-1/3 bg-gradient-to-l from-accent-100/35 to-transparent dark:from-accent-950/20"></div>
      <div
        class="absolute inset-0 bg-[linear-gradient(rgba(124,84,11,0.045)_1px,transparent_1px),linear-gradient(90deg,rgba(124,84,11,0.04)_1px,transparent_1px)] bg-[size:64px_64px] dark:bg-[linear-gradient(rgba(217,154,20,0.055)_1px,transparent_1px),linear-gradient(90deg,rgba(47,143,91,0.05)_1px,transparent_1px)]"
      ></div>
    </div>

    <div class="relative z-10 w-full max-w-md">
      <div class="mb-8 text-center">
        <template v-if="settingsLoaded">
          <div
            class="mb-4 inline-flex h-16 w-16 items-center justify-center overflow-hidden rounded-2xl bg-[#fffdf4] shadow-lg shadow-primary-600/20 ring-1 ring-primary-200/80 dark:bg-dark-800 dark:ring-primary-900/60"
          >
            <img :src="siteLogo || '/logo.png'" alt="Logo" class="h-full w-full object-contain" />
          </div>
          <h1 class="text-gradient mb-2 text-3xl font-bold">
            {{ siteName }}
          </h1>
          <p class="text-sm text-[#7b765e] dark:text-dark-400">
            {{ siteSubtitle }}
          </p>
        </template>
      </div>

      <div class="card-glass rounded-2xl border border-[#e7dccd]/80 p-8 shadow-glass dark:border-[#2f2619]/80">
        <slot />
      </div>

      <div class="mt-6 text-center text-sm">
        <slot name="footer" />
      </div>

      <div class="mt-8 text-center text-xs text-[#8a805e] dark:text-dark-500">
        &copy; {{ currentYear }} {{ siteName }}. All rights reserved.
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed, onMounted } from 'vue'
import { useAppStore } from '@/stores'
import { sanitizeUrl } from '@/utils/url'

const appStore = useAppStore()

const siteName = computed(() => appStore.siteName || 'Doit API')
const siteLogo = computed(() => sanitizeUrl(appStore.siteLogo || '', { allowRelative: true, allowDataUrl: true }))
const siteSubtitle = computed(() => appStore.cachedPublicSettings?.site_subtitle || 'Subscription to API Conversion Platform')
const settingsLoaded = computed(() => appStore.publicSettingsLoaded)

const currentYear = computed(() => new Date().getFullYear())

onMounted(() => {
  appStore.fetchPublicSettings()
})
</script>

<style scoped>
.text-gradient {
  @apply bg-gradient-to-r from-accent-700 to-primary-500 bg-clip-text text-transparent;
}
</style>
