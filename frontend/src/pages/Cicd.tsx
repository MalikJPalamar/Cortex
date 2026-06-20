import { useEffect, useState } from 'react'
import { Play, AlertCircle, RefreshCw } from 'lucide-react'

interface Pipeline {
  id: string
  name: string
  status: string
  branch: string
}

interface PipelinesResponse {
  pipelines: Pipeline[]
  total: number
}

interface HealthService {
  name: string
  status: string
  detail?: string
  last_run?: string
}

interface HealthStatus {
  status: string
  services: HealthService[]
  last_check: string
}

// Treat these statuses as "good" (green dot / success styling).
function isHealthy(status: string): boolean {
  return status === 'operational' || status === 'configured' || status === 'healthy'
}

export default function Cicd() {
  const [pipelines, setPipelines] = useState<Pipeline[]>([])
  const [pipelinesLoaded, setPipelinesLoaded] = useState(false)
  const [health, setHealth] = useState<HealthStatus | null>(null)
  const [triggering, setTriggering] = useState<string | null>(null)

  const loadPipelines = () => {
    fetch('/api/cicd/pipelines')
      .then(res => res.json())
      .then((data: PipelinesResponse) => {
        setPipelines(Array.isArray(data.pipelines) ? data.pipelines : [])
        setPipelinesLoaded(true)
      })
      .catch(() => {
        setPipelines([])
        setPipelinesLoaded(true)
      })
  }

  const loadHealth = () => {
    fetch('/api/cicd/health')
      .then(res => res.json())
      .then((data: HealthStatus) => setHealth(data))
      .catch(() => setHealth(null))
  }

  useEffect(() => {
    loadPipelines()
    loadHealth()
  }, [])

  const handleRefresh = () => {
    loadPipelines()
    loadHealth()
  }

  const handleTrigger = (pipelineId: string) => {
    setTriggering(pipelineId)
    fetch('/api/cicd/trigger', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ pipeline_id: pipelineId })
    })
      .then(res => res.json())
      .catch(() => undefined)
      .finally(() => setTimeout(() => setTriggering(null), 1500))
  }

  const services = health?.services ?? []

  return (
    <>
      <div className="section-header">
        <h2 className="section-title">CI/CD Automation</h2>
        <button className="btn btn-primary" onClick={handleRefresh}>
          <RefreshCw size={18} />
          Refresh Status
        </button>
      </div>

      <div className="card" style={{ marginBottom: '24px' }}>
        <div className="card-header">
          <h3 className="card-title">
            <AlertCircle className="card-title-icon" size={20} />
            System Health
          </h3>
          {health && (
            <span className={`status-badge ${isHealthy(health.status) ? 'success' : 'queued'}`}>
              {health.status}
            </span>
          )}
        </div>
        <div className="card-body">
          {services.length === 0 ? (
            <div style={{ color: 'var(--text-tertiary)', padding: '8px' }}>
              {health ? 'No services reported' : 'Loading health…'}
            </div>
          ) : (
            <div style={{
              display: 'grid',
              gridTemplateColumns: `repeat(${Math.min(services.length, 5)}, 1fr)`,
              gap: '16px'
            }}>
              {services.map((service, index) => (
                <div key={index} style={{
                  padding: '16px',
                  background: 'var(--bg-tertiary)',
                  borderRadius: '12px',
                  textAlign: 'center'
                }}>
                  <div style={{
                    width: '12px',
                    height: '12px',
                    borderRadius: '50%',
                    background: isHealthy(service.status) ? '#4ade80' : 'var(--accent-gold)',
                    margin: '0 auto 8px'
                  }} />
                  <div style={{ fontWeight: 500, marginBottom: '4px' }}>{service.name}</div>
                  <div style={{ fontSize: '0.8rem', color: 'var(--text-tertiary)' }}>
                    {service.detail || service.status}
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>
      </div>

      <div className="card">
        <div className="card-header">
          <h3 className="card-title">
            <Play className="card-title-icon" size={20} />
            Pipelines
          </h3>
        </div>
        <div className="card-body" style={{ padding: 0 }}>
          <table className="table">
            <thead>
              <tr>
                <th>Pipeline</th>
                <th>Branch</th>
                <th>Status</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>
              {pipelines.length === 0 && (
                <tr>
                  <td colSpan={4} style={{ textAlign: 'center', color: 'var(--text-tertiary)', padding: '32px' }}>
                    {pipelinesLoaded ? 'No pipelines configured' : 'Loading pipelines…'}
                  </td>
                </tr>
              )}
              {pipelines.map(pipe => (
                <tr key={pipe.id}>
                  <td>
                    <div style={{ fontWeight: 500 }}>{pipe.name}</div>
                  </td>
                  <td>
                    <span style={{
                      padding: '4px 8px',
                      background: 'var(--bg-tertiary)',
                      borderRadius: '4px',
                      fontSize: '0.8rem',
                      fontFamily: 'var(--font-mono)'
                    }}>
                      {pipe.branch}
                    </span>
                  </td>
                  <td>
                    <span className={`status-badge ${pipe.status}`}>
                      {pipe.status}
                    </span>
                  </td>
                  <td>
                    <button
                      className="btn btn-secondary btn-sm"
                      onClick={() => handleTrigger(pipe.id)}
                      disabled={triggering === pipe.id}
                    >
                      <Play size={14} />
                      {triggering === pipe.id ? 'Triggering...' : 'Run'}
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    </>
  )
}
