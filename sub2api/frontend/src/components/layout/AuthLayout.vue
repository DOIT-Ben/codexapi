<template>
  <div class="relative flex min-h-screen items-center justify-center overflow-hidden bg-[#f7f2ea] p-4 text-[#3a332a] dark:bg-[#100d0b] dark:text-gray-100">
    <div
      class="absolute inset-0 bg-[linear-gradient(135deg,#fffaf4_0%,#f7f2ea_46%,#f1dfcb_100%)] dark:bg-[linear-gradient(135deg,#1b1410_0%,#100d0b_56%,#241711_100%)]"
    ></div>

    <div class="pointer-events-none absolute inset-0 overflow-hidden">
      <div class="absolute inset-x-0 top-0 h-48 bg-gradient-to-b from-primary-100/70 to-transparent dark:from-primary-950/25"></div>
      <div class="absolute inset-y-0 right-0 w-1/3 bg-gradient-to-l from-primary-100/35 to-transparent dark:from-primary-950/20"></div>
      <div
        class="absolute inset-0 bg-[linear-gradient(rgba(228,133,86,0.045)_1px,transparent_1px),linear-gradient(90deg,rgba(228,133,86,0.045)_1px,transparent_1px)] bg-[size:64px_64px] dark:bg-[linear-gradient(rgba(228,133,86,0.06)_1px,transparent_1px),linear-gradient(90deg,rgba(228,133,86,0.06)_1px,transparent_1px)]"
      ></div>
    </div>

    <div class="relative z-10 w-full max-w-md">
      <div class="mb-8 text-center">
        <template v-if="settingsLoaded">
          <div
            class="mb-4 inline-flex h-16 w-16 items-center justify-center overflow-hidden rounded-2xl bg-[#fffaf4] shadow-lg shadow-primary-600/20 ring-1 ring-primary-200/80 dark:bg-dark-800 dark:ring-primary-900/60"
          >
            <img :src="siteLogo || '/logo.png'" alt="Logo" class="h-full w-full object-contain" />
          </div>
          <h1 class="text-gradient mb-2 text-3xl font-bold">
            {{ siteName }}
          </h1>
          <p class="text-sm text-[#8a8174] dark:text-dark-400">
            {{ siteSubtitle }}
          </p>
        </template>
      </div>

      <div class="card-glass rounded-2xl border border-[#eadfce]/80 p-8 shadow-glass dark:border-[#3b2a22]/80">
        <slot />
      </div>

      <div class="mt-6 text-center text-sm">
        <slot name="footer" />
      </div>

      <div class="mt-8 text-center text-xs text-[#a69a8b] dark:text-dark-500">
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

const siteName = computed(() => appStore.siteName || 'Sub2API')
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
  @apply bg-gradient-to-r from-primary-600 to-primary-500 bg-clip-text text-transparent;
}
</style>
