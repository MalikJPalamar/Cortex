import { useEffect, useState } from 'react'
import {
  BrainCircuit,
  Activity,
  CheckCircle,
  AlertTriangle,
  GitBranch,
  Server,
  Cpu
} from 'lucide-react'

interface DashboardStats {
  total_operations: number
  active_operations: number
  completed_today: number
  success_rate: number
  system_health: number
  active_pipelines: number
  recent_activity: Array<{
    type: string
    message: string
    time: string
  }>
}

interface LiveStatus {
  source: string
  phase: number | null
  dev_loop: {
    status: string | null
    date: string | null
    tests_remaining: number | null
    last_run: string | null
  }
  routing_decisions: number
  ratings_count: number
  generated_at: string
}

interface HealthStatus {
  status: string
  services: Array<{
    name: string
    status: string
    detail?: string
    last_run?: string
  }>
  last_check: string
}

const mockStats: DashboardStats = {
  total_operations: 0,
  active_operations: 0,
  completed_today: 0,
  success_rate: 0,
  system_health: 0,
  active_pipelines: 0,
  recent_activity: []
}

// Map a backend service/health status string to a status-badge color class.
function badgeClass(status: string): string {
  switch (status) {
    case 'operational':
    case 'configured':
      return 'success'
    case 'progressing':
    case 'running':
    case 'in_progress':
      return 'running'
    case 'unconfigured':
    case 'unknown':
    case 'degraded':
      return 'queued'
    case 'failed':
    case 'error':
      return 'failed'
    default:
      return 'queued'
  }
}

export default function Dashboard() {
  const [stats, setStats] = useState<DashboardStats | null>(null)
  const [live, setLive] = useState<LiveStatus | null>(null)
  const [health, setHealth] = useState<HealthStatus | null>(null)

  useEffect(() => {
    fetch('/api/dashboard/stats')
      .then(res => res.json())
      .then(data => setStats(data))
      .catch(() => setStats(mockStats))

    fetch('/api/status/live')
      .then(res => res.json())
      .then(data => setLive(data))
      .catch(() => setLive(null))

    fetch('/api/cicd/health')
      .then(res => res.json())
      .then(data => setHealth(data))
      .catch(() => setHealth(null))
  }, [])

  const displayStats = stats || mockStats

  const getActivityIcon = (type: string) => {
    switch (type) {
      case 'operation':
      case 'routing': return BrainCircuit
      case 'pipeline': return GitBranch
      case 'system': return Server
      default: return Activity
    }
  }

  return (
    <>
      <div className="dashboard-grid">
        <div className="stat-card">
          <div className="stat-icon">
            <BrainCircuit size={24} />
          </div>
          <div className="stat-value">{displayStats.total_operations}</div>
          <div className="stat-label">Routing Decisions</div>
          <div className="stat-trend up">
            <Activity size={14} />
            <span>logged total</span>
          </div>
        </div>

        <div className="stat-card">
          <div className="stat-icon">
            <Activity size={24} />
          </div>
          <div className="stat-value">{displayStats.active_operations}</div>
          <div className="stat-label">Active Operations</div>
          <div className="stat-trend up">
            <Cpu size={14} />
            <span>{displayStats.active_operations > 0 ? 'dev loop running' : 'idle'}</span>
          </div>
        </div>

        <div className="stat-card">
          <div className="stat-icon">
            <CheckCircle size={24} />
          </div>
          <div className="stat-value">{displayStats.success_rate}%</div>
          <div className="stat-label">Task Success Rate</div>
          <div className="stat-trend up">
            <CheckCircle size={14} />
            <span>{displayStats.completed_today} rated tasks</span>
          </div>
        </div>

        <div className="stat-card">
          <div className="stat-icon">
            <AlertTriangle size={24} />
          </div>
          <div className="stat-value">{displayStats.system_health}%</div>
          <div className="stat-label">System Health</div>
          <div className="stat-trend up">
            <Server size={14} />
            <span>{displayStats.active_pipelines} pipelines</span>
          </div>
        </div>
      </div>

      <div className="two-col-grid">
        <div className="card">
          <div className="card-header">
            <h3 className="card-title">
              <Activity className="card-title-icon" size={20} />
              Recent Activity
            </h3>
          </div>
          <div className="card-body">
            <div className="activity-list">
              {displayStats.recent_activity.length === 0 && (
                <div className="activity-item">
                  <div className="activity-content">
                    <div className="activity-title">No recent activity</div>
                    <div className="activity-time">waiting on the next routing decision</div>
                  </div>
                </div>
              )}
              {displayStats.recent_activity.map((activity, index) => {
                const Icon = getActivityIcon(activity.type)
                return (
                  <div key={index} className="activity-item">
                    <div className={`activity-icon ${activity.type}`}>
                      <Icon size={18} />
                    </div>
                    <div className="activity-content">
                      <div className="activity-title">{activity.message}</div>
                      <div className="activity-time">{activity.time}</div>
                    </div>
                  </div>
                )
              })}
            </div>
          </div>
        </div>

        {/* PT-3: live System Status driven by /api/status/live + /api/cicd/health */}
        <div className="card">
          <div className="card-header">
            <h3 className="card-title">
              <Server className="card-title-icon" size={20} />
              System Status
            </h3>
            {live && (
              <span className={`status-badge ${badgeClass(health?.status || 'unknown')}`}>
                {health?.status || (live.source === 'live' ? 'live' : 'offline')}
              </span>
            )}
          </div>
          <div className="card-body">
            {live && (
              <div className="activity-item">
                <div className="activity-icon system">
                  <Cpu size={18} />
                </div>
                <div className="activity-content">
                  <div className="activity-title">
                    Phase {live.phase ?? '—'} · dev loop {live.dev_loop.status ?? 'unknown'}
                  </div>
                  <div className="activity-time">
                    {live.dev_loop.tests_remaining ?? '—'} checks remaining ·
                    {' '}{live.routing_decisions} decisions · {live.ratings_count} ratings
                  </div>
                </div>
              </div>
            )}
            <div className="activity-list">
              {(health?.services ?? []).map((svc, index) => (
                <div key={index} className="activity-item">
                  <div className="activity-icon system">
                    <Server size={18} />
                  </div>
                  <div className="activity-content">
                    <div className="activity-title">{svc.name}</div>
                    {svc.detail && <div className="activity-time">{svc.detail}</div>}
                  </div>
                  <span className={`status-badge ${badgeClass(svc.status)}`}>
                    {svc.status}
                  </span>
                </div>
              ))}
              {!health && !live && (
                <div className="activity-item">
                  <div className="activity-content">
                    <div className="activity-title">System status unavailable</div>
                    <div className="activity-time">backend unreachable</div>
                  </div>
                </div>
              )}
            </div>
          </div>
        </div>
      </div>
    </>
  )
}
