import { useEffect, useState } from 'react'
import { TrendingUp, TrendingDown, Users, FileText, Radio } from 'lucide-react'

interface Sector {
  name: string
  sentiment?: string
  change?: number
}

interface Trend {
  topic: string
  volume?: number
  sentiment?: number
}

interface Competitor {
  name: string
  mention_volume?: number
  sentiment?: number
}

interface MarketIntelligence {
  status: string
  message?: string
  sectors: Sector[]
  trends: Trend[]
  competitors: Competitor[]
  tracked_tickers: string[]
  source?: string
  generated_at?: string
}

export default function MarketIntelligence() {
  const [data, setData] = useState<MarketIntelligence | null>(null)
  const [loaded, setLoaded] = useState(false)

  useEffect(() => {
    fetch('/api/market/intelligence')
      .then(res => res.json())
      .then((d: MarketIntelligence) => {
        setData(d)
        setLoaded(true)
      })
      .catch(() => {
        setData(null)
        setLoaded(true)
      })
  }, [])

  const sectors = data?.sectors ?? []
  const trends = data?.trends ?? []
  const competitors = data?.competitors ?? []
  const unconfigured = !data || data.status === 'unconfigured'
  const hasData = sectors.length > 0 || trends.length > 0 || competitors.length > 0

  return (
    <>
      <div className="section-header">
        <h2 className="section-title">Market Intelligence</h2>
        <button className="btn btn-secondary">
          <FileText size={18} />
          Generate Report
        </button>
      </div>

      {(unconfigured || !hasData) && (
        <div className="card">
          <div className="card-body" style={{ textAlign: 'center', padding: '48px 24px' }}>
            <Radio size={32} color="var(--text-tertiary)" style={{ marginBottom: '12px' }} />
            <div style={{ fontWeight: 600, marginBottom: '6px' }}>
              {data?.message || (loaded ? 'No live market feed connected' : 'Loading market data…')}
            </div>
            <div style={{ fontSize: '0.85rem', color: 'var(--text-tertiary)' }}>
              {data?.tracked_tickers && data.tracked_tickers.length > 0
                ? `Tracking ${data.tracked_tickers.length} ticker(s): ${data.tracked_tickers.join(', ')}`
                : 'Market intelligence will appear here once a Situational Awareness scan is connected.'}
            </div>
          </div>
        </div>
      )}

      {sectors.length > 0 && (
        <div className="dashboard-grid">
          {sectors.map((sector, index) => {
            const change = sector.change ?? 0
            return (
              <div key={index} className="stat-card">
                <div
                  className="stat-value"
                  style={{ color: change >= 0 ? 'var(--accent-emerald)' : 'var(--accent-crimson)' }}
                >
                  {change >= 0 ? '+' : ''}{change}%
                </div>
                <div className="stat-label">{sector.name}</div>
                {sector.sentiment && (
                  <div style={{ display: 'flex', alignItems: 'center', gap: '4px', marginTop: '12px', fontSize: '0.8rem' }}>
                    {change >= 0 ? (
                      <TrendingUp size={14} color="var(--accent-emerald)" />
                    ) : (
                      <TrendingDown size={14} color="var(--accent-crimson)" />
                    )}
                    <span style={{ color: change >= 0 ? 'var(--accent-emerald)' : 'var(--accent-crimson)' }}>
                      {sector.sentiment}
                    </span>
                  </div>
                )}
              </div>
            )
          })}
        </div>
      )}

      {(trends.length > 0 || competitors.length > 0) && (
        <div className="two-col-grid">
          <div className="card">
            <div className="card-header">
              <h3 className="card-title">
                <TrendingUp className="card-title-icon" size={20} />
                Trending Topics
              </h3>
            </div>
            <div className="card-body">
              <div className="activity-list">
                {trends.length === 0 && (
                  <div className="activity-item">
                    <div className="activity-content">
                      <div className="activity-title">No trends reported</div>
                    </div>
                  </div>
                )}
                {trends.map((trend, index) => {
                  const sentiment = trend.sentiment ?? 0
                  return (
                    <div key={index} className="activity-item">
                      <div className="activity-content">
                        <div className="activity-title">{trend.topic}</div>
                        <div className="activity-time">
                          {(trend.volume ?? 0).toLocaleString()} mentions • Sentiment: {Math.round(sentiment * 100)}%
                        </div>
                      </div>
                      <div style={{
                        width: '60px',
                        height: '60px',
                        borderRadius: '50%',
                        background: `conic-gradient(var(--accent-gold) ${sentiment * 360}deg, var(--bg-tertiary) 0deg)`,
                        display: 'flex',
                        alignItems: 'center',
                        justifyContent: 'center',
                        fontSize: '0.8rem',
                        fontWeight: 600
                      }}>
                        {Math.round(sentiment * 100)}%
                      </div>
                    </div>
                  )
                })}
              </div>
            </div>
          </div>

          <div className="card">
            <div className="card-header">
              <h3 className="card-title">
                <Users className="card-title-icon" size={20} />
                Competitor Mentions
              </h3>
            </div>
            <div className="card-body">
              <div className="activity-list">
                {competitors.length === 0 && (
                  <div className="activity-item">
                    <div className="activity-content">
                      <div className="activity-title">No competitor data reported</div>
                    </div>
                  </div>
                )}
                {competitors.map((competitor, index) => {
                  const sentiment = competitor.sentiment ?? 0
                  return (
                    <div key={index} className="activity-item">
                      <div className="activity-content">
                        <div className="activity-title">{competitor.name}</div>
                        <div className="activity-time">
                          {competitor.mention_volume ?? 0} mentions this week
                        </div>
                      </div>
                      <div style={{
                        padding: '4px 12px',
                        borderRadius: '20px',
                        background: sentiment >= 0.6 ? 'rgba(26, 95, 74, 0.2)' : 'rgba(201, 162, 39, 0.2)',
                        color: sentiment >= 0.6 ? '#4ade80' : 'var(--accent-gold)',
                        fontSize: '0.8rem',
                        fontWeight: 500
                      }}>
                        {sentiment >= 0.6 ? 'Positive' : 'Neutral'}
                      </div>
                    </div>
                  )
                })}
              </div>
            </div>
          </div>
        </div>
      )}
    </>
  )
}
