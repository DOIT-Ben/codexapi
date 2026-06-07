import { beforeEach, describe, expect, it, vi } from 'vitest'
import { flushPromises, mount, RouterLinkStub } from '@vue/test-utils'

import OperationsConsoleView from '../OperationsConsoleView.vue'

const {
  getDashboardSnapshotV2,
  listRequestDetails,
  listRequestErrors,
  listUpstreamErrors,
  accountsList,
  groupsList,
  getCapacitySummary
} = vi.hoisted(() => ({
  getDashboardSnapshotV2: vi.fn(),
  listRequestDetails: vi.fn(),
  listRequestErrors: vi.fn(),
  listUpstreamErrors: vi.fn(),
  accountsList: vi.fn(),
  groupsList: vi.fn(),
  getCapacitySummary: vi.fn()
}))

vi.mock('@/api/admin', () => ({
  adminAPI: {
    ops: {
      getDashboardSnapshotV2,
      listRequestDetails,
      listRequestErrors,
      listUpstreamErrors
    },
    accounts: {
      list: accountsList
    },
    groups: {
      list: groupsList,
      getCapacitySummary
    }
  }
}))

vi.mock('@/stores/app', () => ({
  useAppStore: () => ({
    showError: vi.fn()
  })
}))

vi.mock('vue-i18n', async () => {
  const actual = await vi.importActual<typeof import('vue-i18n')>('vue-i18n')
  const messages: Record<string, string> = {
    'admin.ops.operations.title': '运营控制台',
    'admin.ops.operations.description': '看请求、看异常、看上游、看额度，一屏处理日常运维。',
    'admin.ops.loadingText': '加载中...',
    'common.refresh': '刷新',
    'admin.ops.totalRequests': '总请求',
    'admin.ops.success': '成功',
    'admin.ops.exceptions': '异常',
    'admin.ops.operations.businessLimited': '业务限流',
    'admin.ops.operations.slaIn': 'SLA 内',
    'admin.ops.operations.supplierAccounts': '供应商账号',
    'admin.ops.active': '活跃',
    'admin.ops.operations.upstreamGroups': '上游分组',
    'admin.ops.peak': '峰值',
    'admin.ops.operations.abnormalRequests': '异常请求',
    'admin.ops.operations.abnormalDescription': '最近的失败请求和上游错误，直接跳转到详细排查页。',
    'admin.ops.requestErrors': '请求错误',
    'admin.ops.upstreamErrors': '上游错误',
    'admin.ops.operations.lastUpdated': '最近更新时间',
    'admin.ops.operations.notUpdated': '未更新',
    'admin.ops.operations.noRecentAbnormalRequests': '暂无最近异常请求。',
    'admin.ops.operations.supplierHealth': '供应商状态',
    'admin.ops.operations.supplierDescription': '这里看的是你接进来的上游中转和直连供应商。',
    'admin.ops.operations.manageAccounts': '管理账号',
    'common.total': '总计',
    'admin.ops.operations.noSupplierAccounts': '暂无供应商账号。',
    'admin.ops.operations.limitsAndRate': '限额与限速',
    'admin.ops.operations.limitsDescription': '额度、RPM、并发和分组倍率都在这里串起来。',
    'admin.ops.operations.manageGroups': '管理分组',
    'admin.ops.concurrency': '并发',
    'admin.ops.sessions': '会话',
    'nav.groups': '分组',
    'admin.ops.operations.noCapacityData': '暂无分组容量数据。',
    'admin.ops.operations.upstreamAccounts': '上游账号',
    'nav.channelPricing': '渠道定价',
    'nav.riskControl': '风控',
    'admin.ops.operations.partialLoadFailed': '部分辅助数据加载失败：',
    'admin.ops.failedToLoadData': '加载运维数据失败'
  }
  return {
    ...actual,
    useI18n: () => ({
      t: (key: string) => messages[key] ?? key
    })
  }
})

const createWrapper = () => mount(OperationsConsoleView, {
  global: {
    stubs: {
      AppLayout: { template: '<main><slot /></main>' },
      RouterLink: RouterLinkStub,
      Icon: true
    }
  }
})

const createSnapshot = (requestCount: number) => ({
  generated_at: '2026-05-25T08:00:00Z',
  overview: {
    start_time: '2026-05-25T07:00:00Z',
    end_time: '2026-05-25T08:00:00Z',
    platform: '',
    success_count: Math.max(0, requestCount - 8),
    error_count_total: 8,
    business_limited_count: 2,
    error_count_sla: 6,
    request_count_total: requestCount,
    request_count_sla: Math.max(0, requestCount - 2),
    token_consumed: 64000,
    sla: 0.984,
    error_rate: 0.0625,
    upstream_error_rate: 0.031,
    upstream_error_count_excl_429_529: 4,
    upstream_429_count: 1,
    upstream_529_count: 0,
    qps: { current: 1.4, peak: 5.2, avg: 2.1 },
    tps: { current: 240, peak: 980, avg: 420 },
    duration: { p95_ms: 980, avg_ms: 320 },
    ttft: { p95_ms: 520, avg_ms: 180 }
  },
  throughput_trend: { bucket: 'minute', points: [] },
  error_trend: { bucket: 'minute', points: [] }
})

function deferred<T>() {
  let resolve!: (value: T) => void
  const promise = new Promise<T>((res) => {
    resolve = res
  })
  return { promise, resolve }
}

describe('admin OperationsConsoleView', () => {
  beforeEach(() => {
    getDashboardSnapshotV2.mockReset()
    listRequestDetails.mockReset()
    listRequestErrors.mockReset()
    listUpstreamErrors.mockReset()
    accountsList.mockReset()
    groupsList.mockReset()
    getCapacitySummary.mockReset()

    getDashboardSnapshotV2.mockResolvedValue(createSnapshot(128))
    listRequestDetails.mockResolvedValue({
      items: [
        {
          kind: 'error',
          created_at: '2026-05-25T07:55:00Z',
          request_id: 'req_1',
          platform: 'openai',
          model: 'gpt-4.1',
          duration_ms: 1200,
          status_code: 500,
          phase: 'upstream',
          severity: 'error',
          message: 'upstream timeout'
        }
      ],
      total: 1,
      page: 1,
      page_size: 5,
      pages: 1
    })
    listRequestErrors.mockResolvedValue({ items: [], total: 3, page: 1, page_size: 1, pages: 3 })
    listUpstreamErrors.mockResolvedValue({ items: [], total: 5, page: 1, page_size: 1, pages: 5 })
    accountsList.mockResolvedValue({
      items: [
        { id: 1, name: 'NexaHub OpenAI', platform: 'openai', status: 'active' },
        { id: 2, name: 'Claude Relay', platform: 'anthropic', status: 'error' },
        { id: 3, name: 'Backup OpenAI', platform: 'openai', status: 'inactive' }
      ],
      total: 3,
      page: 1,
      page_size: 100,
      pages: 1
    })
    groupsList.mockResolvedValue({
      items: [
        { id: 10, name: 'test-openai', platform: 'openai', status: 'active', rpm_limit: 60 },
        { id: 11, name: 'claude-users', platform: 'anthropic', status: 'active', rpm_limit: 20 }
      ],
      total: 2,
      page: 1,
      page_size: 100,
      pages: 1
    })
    getCapacitySummary.mockResolvedValue([
      { group_id: 10, concurrency_used: 2, concurrency_max: 8, sessions_used: 1, sessions_max: 10, rpm_used: 12, rpm_max: 60 },
      { group_id: 11, concurrency_used: 1, concurrency_max: 4, sessions_used: 0, sessions_max: 6, rpm_used: 5, rpm_max: 20 }
    ])
  })

  it('loads the operational summary from existing admin APIs', async () => {
    createWrapper()
    await flushPromises()

    expect(getDashboardSnapshotV2).toHaveBeenCalledWith({ time_range: '1h', mode: 'auto' })
    expect(listRequestDetails).toHaveBeenCalledWith({ time_range: '1h', kind: 'error', sort: 'created_at_desc', page: 1, page_size: 5 })
    expect(listRequestErrors).toHaveBeenCalledWith({ time_range: '1h', page: 1, page_size: 1, resolved: 'false' })
    expect(listUpstreamErrors).toHaveBeenCalledWith({ time_range: '1h', page: 1, page_size: 1, resolved: 'false' })
    expect(accountsList).toHaveBeenCalledWith(1, 100, { sort_by: 'updated_at', sort_order: 'desc' })
    expect(groupsList).toHaveBeenCalledWith(1, 100, { status: 'active', sort_by: 'sort_order', sort_order: 'asc' })
    expect(getCapacitySummary).toHaveBeenCalledTimes(1)
  })

  it('loads every account and active group page before calculating overview totals', async () => {
    accountsList
      .mockResolvedValueOnce({
        items: Array.from({ length: 100 }, (_, index) => ({
          id: index + 1,
          name: `OpenAI Relay ${index + 1}`,
          platform: 'openai',
          status: index === 0 ? 'error' : 'active'
        })),
        total: 101,
        page: 1,
        page_size: 100,
        pages: 2
      })
      .mockResolvedValueOnce({
        items: [{ id: 101, name: 'Claude Relay 101', platform: 'anthropic', status: 'active' }],
        total: 101,
        page: 2,
        page_size: 100,
        pages: 2
      })
    groupsList
      .mockResolvedValueOnce({
        items: Array.from({ length: 100 }, (_, index) => ({
          id: index + 1,
          name: `group-${index + 1}`,
          platform: 'openai',
          status: 'active',
          rpm_limit: 60
        })),
        total: 101,
        page: 1,
        page_size: 100,
        pages: 2
      })
      .mockResolvedValueOnce({
        items: [{ id: 101, name: 'group-101', platform: 'anthropic', status: 'active', rpm_limit: 20 }],
        total: 101,
        page: 2,
        page_size: 100,
        pages: 2
      })

    const wrapper = createWrapper()
    await flushPromises()

    expect(accountsList).toHaveBeenNthCalledWith(1, 1, 100, { sort_by: 'updated_at', sort_order: 'desc' })
    expect(accountsList).toHaveBeenNthCalledWith(2, 2, 100, { sort_by: 'updated_at', sort_order: 'desc' })
    expect(groupsList).toHaveBeenNthCalledWith(1, 1, 100, { status: 'active', sort_by: 'sort_order', sort_order: 'asc' })
    expect(groupsList).toHaveBeenNthCalledWith(2, 2, 100, { status: 'active', sort_by: 'sort_order', sort_order: 'asc' })
    expect(wrapper.text()).toContain('101')
    expect(wrapper.text()).toContain('anthropic')
  })

  it('renders supplier health, abnormal request, and limit management entry points', async () => {
    const wrapper = createWrapper()
    await flushPromises()

    expect(wrapper.text()).toContain('运营控制台')
    expect(wrapper.text()).toContain('128')
    expect(wrapper.text()).toContain('供应商状态')
    expect(wrapper.text()).toContain('openai')
    expect(wrapper.text()).toContain('anthropic')
    expect(wrapper.text()).toContain('异常请求')
    expect(wrapper.text()).toContain('upstream timeout')
    expect(wrapper.text()).toContain('限额与限速')

    const links = wrapper.findAllComponents(RouterLinkStub).map(link => link.props('to'))
    expect(links).toContain('/admin/ops?open_error_details=1&error_type=request')
    expect(links).toContain('/admin/ops?open_error_details=1&error_type=upstream')
    expect(links).toContain('/admin/accounts')
    expect(links).toContain('/admin/groups')
  })

  it('keeps the latest selected time range when an older request resolves late', async () => {
    const firstSnapshot = deferred<ReturnType<typeof createSnapshot>>()
    getDashboardSnapshotV2
      .mockReturnValueOnce(firstSnapshot.promise)
      .mockResolvedValueOnce(createSnapshot(2400))

    const wrapper = createWrapper()
    await wrapper.findAll('button').find(button => button.text() === '24h')!.trigger('click')
    await flushPromises()

    expect(wrapper.text()).toContain('2,400')

    firstSnapshot.resolve(createSnapshot(100))
    await flushPromises()

    expect(wrapper.text()).toContain('2,400')
    expect(wrapper.text()).not.toContain('100')
  })

  it('does not use group rpm limit as a fallback concurrency limit', async () => {
    getCapacitySummary.mockResolvedValue([
      { group_id: 10, concurrency_used: 2, concurrency_max: 8, sessions_used: 1, sessions_max: 10, rpm_used: 12, rpm_max: 60 }
    ])

    const wrapper = createWrapper()
    await flushPromises()

    expect(wrapper.text()).toContain('claude-users')
    expect(wrapper.text()).toContain('并发 0/0')
    expect(wrapper.text()).not.toContain('并发 0/20')
  })

  it('keeps core operations data visible when account and group side panels fail', async () => {
    accountsList.mockRejectedValue(new Error('accounts unavailable'))
    groupsList.mockRejectedValue(new Error('groups unavailable'))

    const wrapper = createWrapper()
    await flushPromises()

    expect(wrapper.text()).toContain('128')
    expect(wrapper.text()).toContain('upstream timeout')
    expect(wrapper.text()).toContain('部分辅助数据加载失败')
    expect(wrapper.text()).not.toContain('加载运营数据失败')
  })
})
