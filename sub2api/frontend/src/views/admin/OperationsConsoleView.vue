<template>
  <AppLayout>
    <div class="space-y-6 pb-10">
      <section class="space-y-3">
        <div class="flex flex-wrap items-end justify-between gap-3">
          <div>
            <p class="text-xs font-medium uppercase tracking-wide text-[#a69a8b] dark:text-gray-400">
              Admin / Operations
            </p>
            <h1 class="text-2xl font-semibold text-[#3a332a] dark:text-white">{{ t('admin.ops.operations.title') }}</h1>
            <p class="mt-1 text-sm text-[#8a8174] dark:text-gray-400">
              {{ t('admin.ops.operations.description') }}
            </p>
          </div>

          <div class="flex flex-wrap gap-2">
            <button
              v-for="range in timeRanges"
              :key="range.value"
              type="button"
              class="rounded-lg border px-3 py-1.5 text-sm transition"
              :class="range.value === timeRange
                ? 'border-primary-600 bg-primary-600 text-white shadow-sm shadow-primary-600/20'
                : 'border-[#eadfce] bg-[#fffaf4] text-[#6f6258] hover:border-primary-200 hover:text-primary-800 dark:border-[#3b2a22] dark:bg-gray-900 dark:text-gray-200'"
              @click="setTimeRange(range.value)"
              :disabled="loading"
            >
              {{ range.label }}
            </button>
            <button
              type="button"
              class="btn btn-secondary btn-sm"
              :disabled="loading"
              @click="loadData"
            >
              {{ loading ? t('admin.ops.loadingText') : t('common.refresh') }}
            </button>
          </div>
        </div>

        <div
          v-if="errorMessage"
          class="rounded-lg border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700 dark:border-red-900/40 dark:bg-red-950/30 dark:text-red-300"
        >
          {{ errorMessage }}
        </div>
        <div
          v-if="warningMessage"
          class="rounded-lg border border-amber-200 bg-amber-50 px-4 py-3 text-sm text-amber-800 dark:border-amber-900/40 dark:bg-amber-950/30 dark:text-amber-200"
        >
          {{ warningMessage }}
        </div>
      </section>

      <section class="grid grid-cols-1 gap-4 md:grid-cols-2 xl:grid-cols-4">
        <div class="card p-4">
          <p class="text-xs font-medium text-[#8a8174] dark:text-gray-400">{{ t('admin.ops.totalRequests') }}</p>
          <p class="mt-2 text-2xl font-semibold text-[#3a332a] dark:text-white">
            {{ formatNumber(overview?.request_count_total ?? 0) }}
          </p>
          <p class="mt-1 text-xs text-[#8a8174] dark:text-gray-400">
            {{ t('admin.ops.success') }} {{ formatNumber(overview?.success_count ?? 0) }} / {{ t('admin.ops.exceptions') }} {{ formatNumber(overview?.error_count_total ?? 0) }}
          </p>
        </div>

        <div class="card p-4">
          <p class="text-xs font-medium text-[#8a8174] dark:text-gray-400">{{ t('admin.ops.operations.businessLimited') }}</p>
          <p class="mt-2 text-2xl font-semibold text-[#3a332a] dark:text-white">
            {{ formatNumber(overview?.business_limited_count ?? 0) }}
          </p>
          <p class="mt-1 text-xs text-[#8a8174] dark:text-gray-400">
            {{ t('admin.ops.operations.slaIn') }} {{ formatNumber(overview?.request_count_sla ?? 0) }}
          </p>
        </div>

        <div class="card p-4">
          <p class="text-xs font-medium text-[#8a8174] dark:text-gray-400">{{ t('admin.ops.operations.supplierAccounts') }}</p>
          <p class="mt-2 text-2xl font-semibold text-[#3a332a] dark:text-white">
            {{ formatNumber(accountStats.total) }}
          </p>
          <p class="mt-1 text-xs text-[#8a8174] dark:text-gray-400">
            {{ t('admin.ops.active') }} {{ formatNumber(accountStats.active) }} / {{ t('admin.ops.exceptions') }} {{ formatNumber(accountStats.error) }}
          </p>
        </div>

        <div class="card p-4">
          <p class="text-xs font-medium text-[#8a8174] dark:text-gray-400">{{ t('admin.ops.operations.upstreamGroups') }}</p>
          <p class="mt-2 text-2xl font-semibold text-[#3a332a] dark:text-white">
            {{ formatNumber(groups.length) }}
          </p>
          <p class="mt-1 text-xs text-[#8a8174] dark:text-gray-400">
            RPM {{ t('admin.ops.peak') }} {{ formatNumber(maxCapacity.rpm_max) }}
          </p>
        </div>
      </section>

      <section class="grid grid-cols-1 gap-6 xl:grid-cols-3">
        <div class="card p-5 xl:col-span-2">
          <div class="flex items-center justify-between gap-3">
            <div>
              <h2 class="text-base font-semibold text-[#3a332a] dark:text-white">{{ t('admin.ops.operations.abnormalRequests') }}</h2>
              <p class="mt-1 text-sm text-[#8a8174] dark:text-gray-400">
                {{ t('admin.ops.operations.abnormalDescription') }}
              </p>
            </div>
            <div class="flex flex-wrap gap-2 text-sm">
              <RouterLink
                class="btn btn-secondary btn-sm"
                to="/admin/ops?open_error_details=1&error_type=request"
              >
                {{ t('admin.ops.requestErrors') }}
              </RouterLink>
              <RouterLink
                class="btn btn-secondary btn-sm"
                to="/admin/ops?open_error_details=1&error_type=upstream"
              >
                {{ t('admin.ops.upstreamErrors') }}
              </RouterLink>
            </div>
          </div>

          <div class="mt-4 grid grid-cols-1 gap-4 md:grid-cols-3">
            <div class="rounded-lg border border-[#eadfce] bg-[#fff7ed]/50 p-4 dark:border-gray-800 dark:bg-dark-800/30">
              <p class="text-xs text-[#8a8174] dark:text-gray-400">{{ t('admin.ops.requestErrors') }}</p>
              <p class="mt-2 text-2xl font-semibold text-[#3a332a] dark:text-white">
                {{ formatNumber(requestErrorsTotal) }}
              </p>
            </div>
            <div class="rounded-lg border border-[#eadfce] bg-[#fff7ed]/50 p-4 dark:border-gray-800 dark:bg-dark-800/30">
              <p class="text-xs text-[#8a8174] dark:text-gray-400">{{ t('admin.ops.upstreamErrors') }}</p>
              <p class="mt-2 text-2xl font-semibold text-[#3a332a] dark:text-white">
                {{ formatNumber(upstreamErrorsTotal) }}
              </p>
            </div>
            <div class="rounded-lg border border-[#eadfce] bg-[#fff7ed]/50 p-4 dark:border-gray-800 dark:bg-dark-800/30">
              <p class="text-xs text-[#8a8174] dark:text-gray-400">{{ t('admin.ops.operations.lastUpdated') }}</p>
              <p class="mt-2 text-sm font-medium text-[#3a332a] dark:text-white">
                {{ formatDate(lastUpdated, dateTimeFormat) || t('admin.ops.operations.notUpdated') }}
              </p>
            </div>
          </div>

          <div class="mt-4 divide-y divide-[#eadfce] rounded-lg border border-[#eadfce] dark:divide-gray-800 dark:border-gray-800">
            <article
              v-for="item in recentRequestRows"
              :key="item.request_id"
              class="flex flex-col gap-2 px-4 py-3 md:flex-row md:items-center md:justify-between"
            >
              <div class="min-w-0">
                <div class="flex flex-wrap items-center gap-2">
                  <span
                    class="rounded-full px-2 py-0.5 text-xs font-medium"
                    :class="item.kind === 'error'
                      ? 'bg-red-100 text-red-700 dark:bg-red-900/30 dark:text-red-300'
                      : 'bg-green-100 text-green-700 dark:bg-green-900/30 dark:text-green-300'"
                  >
                    {{ item.kind === 'error' ? 'error' : 'success' }}
                  </span>
                  <span class="text-sm font-medium text-[#3a332a] dark:text-white">
                    {{ item.platform || 'unknown' }} / {{ item.model || 'unknown model' }}
                  </span>
                  <span class="text-xs text-[#8a8174] dark:text-gray-400">
                    {{ item.status_code ?? '-' }} · {{ item.phase || '-' }}
                  </span>
                </div>
                <p class="mt-1 truncate text-sm text-[#6f6258] dark:text-gray-300">
                  {{ item.message || item.request_id }}
                </p>
              </div>
              <div class="text-xs text-[#8a8174] dark:text-gray-400">
                {{ formatDate(item.created_at, dateTimeFormat) }}
              </div>
            </article>
            <p v-if="recentRequestRows.length === 0" class="px-4 py-6 text-sm text-[#8a8174] dark:text-gray-400">
              {{ t('admin.ops.operations.noRecentAbnormalRequests') }}
            </p>
          </div>
        </div>

        <div class="space-y-6">
          <div class="card p-5">
            <div class="flex items-center justify-between gap-3">
              <div>
                <h2 class="text-base font-semibold text-[#3a332a] dark:text-white">{{ t('admin.ops.operations.supplierHealth') }}</h2>
                <p class="mt-1 text-sm text-[#8a8174] dark:text-gray-400">
                  {{ t('admin.ops.operations.supplierDescription') }}
                </p>
              </div>
              <RouterLink class="text-sm font-medium text-primary-700 hover:text-primary-600 dark:text-primary-300" to="/admin/accounts">
                {{ t('admin.ops.operations.manageAccounts') }}
              </RouterLink>
            </div>

            <div class="mt-4 space-y-3">
              <div
                v-for="row in supplierRows"
                :key="row.platform"
                class="rounded-lg border border-[#eadfce] bg-[#fff7ed]/50 p-3 dark:border-gray-800 dark:bg-dark-800/30"
              >
                <div class="flex items-center justify-between gap-2">
                  <div>
                    <p class="text-sm font-medium text-[#3a332a] dark:text-white">{{ row.platform }}</p>
                    <p class="text-xs text-[#8a8174] dark:text-gray-400">{{ t('common.total') }} {{ formatNumber(row.total) }}</p>
                  </div>
                  <div class="text-right text-xs text-[#8a8174] dark:text-gray-400">
                    <p>{{ t('admin.ops.active') }} {{ formatNumber(row.active) }}</p>
                    <p>{{ t('admin.ops.exceptions') }} {{ formatNumber(row.error) }}</p>
                  </div>
                </div>
              </div>
              <p v-if="supplierRows.length === 0" class="text-sm text-[#8a8174] dark:text-gray-400">
                {{ t('admin.ops.operations.noSupplierAccounts') }}
              </p>
            </div>
          </div>

          <div class="card p-5">
            <div class="flex items-center justify-between gap-3">
              <div>
                <h2 class="text-base font-semibold text-[#3a332a] dark:text-white">{{ t('admin.ops.operations.limitsAndRate') }}</h2>
                <p class="mt-1 text-sm text-[#8a8174] dark:text-gray-400">
                  {{ t('admin.ops.operations.limitsDescription') }}
                </p>
              </div>
              <RouterLink class="text-sm font-medium text-primary-700 hover:text-primary-600 dark:text-primary-300" to="/admin/groups">
                {{ t('admin.ops.operations.manageGroups') }}
              </RouterLink>
            </div>

            <div class="mt-4 space-y-3">
              <div
                v-for="row in capacityRows"
                :key="row.group_id"
                class="rounded-lg border border-[#eadfce] bg-[#fff7ed]/50 p-3 dark:border-gray-800 dark:bg-dark-800/30"
              >
                <div class="flex items-start justify-between gap-3">
                  <div>
                    <p class="text-sm font-medium text-[#3a332a] dark:text-white">{{ row.name }}</p>
                    <p class="text-xs text-[#8a8174] dark:text-gray-400">
                      {{ t('admin.ops.concurrency') }} {{ row.concurrency_used }}/{{ row.concurrency_max }} ·
                      {{ t('admin.ops.sessions') }} {{ row.sessions_used }}/{{ row.sessions_max }} ·
                      RPM {{ row.rpm_used }}/{{ row.rpm_max }}
                    </p>
                  </div>
                  <div class="text-right text-xs text-[#8a8174] dark:text-gray-400">
                    <p>{{ t('nav.groups') }} {{ row.platform }}</p>
                    <p>{{ row.status }}</p>
                  </div>
                </div>
              </div>
              <p v-if="capacityRows.length === 0" class="text-sm text-[#8a8174] dark:text-gray-400">
                {{ t('admin.ops.operations.noCapacityData') }}
              </p>
            </div>

            <div class="mt-4 flex flex-wrap gap-2 text-sm">
              <RouterLink
                class="btn btn-secondary btn-sm"
                to="/admin/accounts"
              >
                {{ t('admin.ops.operations.upstreamAccounts') }}
              </RouterLink>
              <RouterLink
                class="btn btn-secondary btn-sm"
                to="/admin/channels/pricing"
              >
                {{ t('nav.channelPricing') }}
              </RouterLink>
              <RouterLink
                class="btn btn-secondary btn-sm"
                to="/admin/risk-control"
              >
                {{ t('nav.riskControl') }}
              </RouterLink>
            </div>
          </div>
        </div>
      </section>
    </div>
  </AppLayout>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { RouterLink } from 'vue-router'
import { useI18n } from 'vue-i18n'
import AppLayout from '@/components/layout/AppLayout.vue'
import { adminAPI } from '@/api/admin'
import { formatDate, formatNumber } from '@/utils/format'
import type { Account, AdminGroup } from '@/types'
import type { OpsDashboardOverview, OpsRequestDetail } from '@/api/admin/ops'

interface GroupCapacitySummary {
  group_id: number
  concurrency_used: number
  concurrency_max: number
  sessions_used: number
  sessions_max: number
  rpm_used: number
  rpm_max: number
}

const timeRanges = [
  { label: '1h', value: '1h' },
  { label: '6h', value: '6h' },
  { label: '24h', value: '24h' }
] as const

const { t } = useI18n()

const dateTimeFormat = {
  year: 'numeric',
  month: '2-digit',
  day: '2-digit',
  hour: '2-digit',
  minute: '2-digit',
  second: '2-digit',
  hour12: false
} as const

const timeRange = ref<(typeof timeRanges)[number]['value']>('1h')
const loading = ref(false)
const errorMessage = ref('')
const warningMessage = ref('')
const overview = ref<OpsDashboardOverview | null>(null)
const recentRequests = ref<OpsRequestDetail[]>([])
const requestErrorsTotal = ref(0)
const upstreamErrorsTotal = ref(0)
const accounts = ref<Account[]>([])
const groups = ref<AdminGroup[]>([])
const capacitySummary = ref<GroupCapacitySummary[]>([])
const lastUpdated = ref<Date | null>(null)
let loadSeq = 0

const accountStats = computed(() => {
  const stats = {
    total: accounts.value.length,
    active: 0,
    error: 0
  }

  for (const account of accounts.value) {
    if (account.status === 'active') stats.active += 1
    if (account.status === 'error') stats.error += 1
  }

  return stats
})

const supplierRows = computed(() => {
  const map = new Map<string, { platform: string, total: number, active: number, error: number }>()

  for (const account of accounts.value) {
    const platform = account.platform || 'unknown'
    const row = map.get(platform) ?? { platform, total: 0, active: 0, error: 0 }
    row.total += 1
    if (account.status === 'active') row.active += 1
    if (account.status === 'error') row.error += 1
    map.set(platform, row)
  }

  return [...map.values()].sort((a, b) => b.total - a.total)
})

const capacityByGroup = computed(() => {
  return new Map(capacitySummary.value.map(item => [item.group_id, item]))
})

const capacityRows = computed(() => {
  return groups.value.map((group) => {
    const capacity = capacityByGroup.value.get(group.id)
    return {
      group_id: group.id,
      name: group.name,
      platform: group.platform,
      status: group.status,
      concurrency_used: capacity?.concurrency_used ?? 0,
      concurrency_max: capacity?.concurrency_max ?? 0,
      sessions_used: capacity?.sessions_used ?? 0,
      sessions_max: capacity?.sessions_max ?? 0,
      rpm_used: capacity?.rpm_used ?? 0,
      rpm_max: capacity?.rpm_max ?? group.rpm_limit ?? 0
    }
  })
})

const maxCapacity = computed(() => {
  let rpm_max = 0
  for (const row of capacitySummary.value) {
    rpm_max = Math.max(rpm_max, row.rpm_max)
  }
  return { rpm_max }
})

const recentRequestRows = computed(() => {
  return recentRequests.value.slice(0, 5)
})

async function loadAllPages<T>(
  loader: (page: number, pageSize: number) => Promise<{ items: T[], pages?: number, total?: number }>
): Promise<T[]> {
  const pageSize = 100
  const first = await loader(1, pageSize)
  const items = [...first.items]
  const pages = first.pages ?? Math.ceil((first.total ?? first.items.length) / pageSize)

  for (let page = 2; page <= pages; page += 1) {
    const next = await loader(page, pageSize)
    items.push(...next.items)
  }

  return items
}

function collectRejectedMessages(results: PromiseSettledResult<unknown>[]): string[] {
  return results
    .filter((result): result is PromiseRejectedResult => result.status === 'rejected')
    .map(result => result.reason instanceof Error ? result.reason.message : 'unknown error')
}

async function loadData() {
  const seq = ++loadSeq
  loading.value = true
  errorMessage.value = ''
  warningMessage.value = ''

  try {
    const [snapshot, requestDetails, requestErrors, upstreamErrors] = await Promise.all([
      adminAPI.ops.getDashboardSnapshotV2({ time_range: timeRange.value, mode: 'auto' }),
      adminAPI.ops.listRequestDetails({ time_range: timeRange.value, kind: 'error', sort: 'created_at_desc', page: 1, page_size: 5 }),
      adminAPI.ops.listRequestErrors({ time_range: timeRange.value, page: 1, page_size: 1, resolved: 'false' }),
      adminAPI.ops.listUpstreamErrors({ time_range: timeRange.value, page: 1, page_size: 1, resolved: 'false' })
    ])

    const [accountResult, groupResult, capacityResult] = await Promise.allSettled([
      loadAllPages<Account>((page, pageSize) => adminAPI.accounts.list(page, pageSize, { sort_by: 'updated_at', sort_order: 'desc' })),
      loadAllPages<AdminGroup>((page, pageSize) => adminAPI.groups.list(page, pageSize, { status: 'active', sort_by: 'sort_order', sort_order: 'asc' })),
      adminAPI.groups.getCapacitySummary()
    ])

    if (seq !== loadSeq) return

    overview.value = snapshot.overview
    recentRequests.value = requestDetails.items
    requestErrorsTotal.value = requestErrors.total
    upstreamErrorsTotal.value = upstreamErrors.total
    accounts.value = accountResult.status === 'fulfilled' ? accountResult.value : []
    groups.value = groupResult.status === 'fulfilled' ? groupResult.value : []
    capacitySummary.value = capacityResult.status === 'fulfilled' ? capacityResult.value : []
    lastUpdated.value = new Date(snapshot.generated_at)
    const sidePanelErrors = collectRejectedMessages([accountResult, groupResult, capacityResult])
    warningMessage.value = sidePanelErrors.length > 0
      ? `${t('admin.ops.operations.partialLoadFailed')}${sidePanelErrors.join('；')}`
      : ''
  } catch (err) {
    if (seq !== loadSeq) return
    errorMessage.value = err instanceof Error ? err.message : t('admin.ops.failedToLoadData')
  } finally {
    if (seq === loadSeq) {
      loading.value = false
    }
  }
}

function setTimeRange(range: (typeof timeRanges)[number]['value']) {
  timeRange.value = range
  void loadData()
}

onMounted(() => {
  void loadData()
})
</script>
