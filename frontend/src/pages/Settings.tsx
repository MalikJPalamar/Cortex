import { useEffect, useState } from 'react'
import { Database, Info, CheckCircle, XCircle, Sliders } from 'lucide-react'

interface SettingsData {
  identity: {
    service: string
    description?: string
    version: string
  }
  memory: {
    service: string
    tier: string
    status: string
    api_key_configured: boolean
    auto_capture?: boolean
    auto_recall?: boolean
  }
  preferences?: {
    theme: string
    auto_refresh: boolean
    refresh_interval: number
  }
}

function BoolBadge({ value }: { value: boolean }) {
  return (
    <span
      style={{
        display: 'inline-flex',
        alignItems: 'center',
        gap: '6px',
        color: value ? '#4ade80' : 'var(--text-tertiary)',
        fontWeight: 500
      }}
    >
      {value ? <CheckCircle size={16} /> : <XCircle size={16} />}
      {value ? 'Yes' : 'No'}
    </span>
  )
}

function Row({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <div
      style={{
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'space-between',
        gap: '16px'
      }}
    >
      <div style={{ color: 'var(--text-secondary)' }}>{label}</div>
      <div style={{ fontWeight: 500, textAlign: 'right' }}>{children}</div>
    </div>
  )
}

export default function SettingsPage() {
  const [settings, setSettings] = useState<SettingsData | null>(null)
  const [loaded, setLoaded] = useState(false)

  useEffect(() => {
    fetch('/api/settings')
      .then(res => res.json())
      .then((data: SettingsData) => {
        setSettings(data)
        setLoaded(true)
      })
      .catch(() => {
        setSettings(null)
        setLoaded(true)
      })
  }, [])

  return (
    <>
      <div className="section-header">
        <h2 className="section-title">Settings</h2>
      </div>

      {!settings ? (
        <div className="card">
          <div className="card-body" style={{ color: 'var(--text-tertiary)' }}>
            {loaded ? 'Settings unavailable — backend unreachable' : 'Loading settings…'}
          </div>
        </div>
      ) : (
        <div style={{ display: 'grid', gap: '24px', maxWidth: '800px' }}>
          <div className="card">
            <div className="card-header">
              <h3 className="card-title">
                <Info className="card-title-icon" size={20} />
                Identity
              </h3>
            </div>
            <div className="card-body">
              <div style={{ display: 'grid', gap: '16px' }}>
                <Row label="Service">{settings.identity.service}</Row>
                {settings.identity.description && (
                  <Row label="Description">{settings.identity.description}</Row>
                )}
                <Row label="Version">
                  <span style={{ fontFamily: 'var(--font-mono)' }}>{settings.identity.version}</span>
                </Row>
              </div>
            </div>
          </div>

          <div className="card">
            <div className="card-header">
              <h3 className="card-title">
                <Database className="card-title-icon" size={20} />
                Memory
              </h3>
            </div>
            <div className="card-body">
              <div style={{ display: 'grid', gap: '16px' }}>
                <Row label="Service">{settings.memory.service}</Row>
                <Row label="Tier">{settings.memory.tier}</Row>
                <Row label="Status">
                  <span className={`status-badge ${settings.memory.status === 'active' ? 'success' : 'queued'}`}>
                    {settings.memory.status}
                  </span>
                </Row>
                <Row label="API Key Configured">
                  <BoolBadge value={settings.memory.api_key_configured} />
                </Row>
                {settings.memory.auto_capture !== undefined && (
                  <Row label="Auto Capture">
                    <BoolBadge value={settings.memory.auto_capture} />
                  </Row>
                )}
                {settings.memory.auto_recall !== undefined && (
                  <Row label="Auto Recall">
                    <BoolBadge value={settings.memory.auto_recall} />
                  </Row>
                )}
              </div>
            </div>
          </div>

          {settings.preferences && (
            <div className="card">
              <div className="card-header">
                <h3 className="card-title">
                  <Sliders className="card-title-icon" size={20} />
                  Preferences
                </h3>
              </div>
              <div className="card-body">
                <div style={{ display: 'grid', gap: '16px' }}>
                  <Row label="Theme">{settings.preferences.theme}</Row>
                  <Row label="Auto Refresh">
                    <BoolBadge value={settings.preferences.auto_refresh} />
                  </Row>
                  <Row label="Refresh Interval">{settings.preferences.refresh_interval}s</Row>
                </div>
                <div style={{ marginTop: '16px', fontSize: '0.8rem', color: 'var(--text-tertiary)' }}>
                  Read-only — configuration is managed in the repo.
                </div>
              </div>
            </div>
          )}
        </div>
      )}
    </>
  )
}
