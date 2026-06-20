import { useEffect, useState } from 'react'
import { Plus, Play, Pause, RotateCcw } from 'lucide-react'

interface AIOperation {
  id: string
  name: string
  type: string
  status: string
  created_at: string | null
}

interface AIOperationsResponse {
  operations: AIOperation[]
  total: number
}

export default function AIOperations() {
  const [operations, setOperations] = useState<AIOperation[]>([])
  const [loaded, setLoaded] = useState(false)
  const [showCreate, setShowCreate] = useState(false)
  const [newOpName, setNewOpName] = useState('')
  const [newOpType, setNewOpType] = useState('general')

  const loadOperations = () => {
    fetch('/api/ai-operations')
      .then(res => res.json())
      .then((data: AIOperationsResponse) => {
        setOperations(Array.isArray(data.operations) ? data.operations : [])
        setLoaded(true)
      })
      .catch(() => {
        setOperations([])
        setLoaded(true)
      })
  }

  useEffect(() => {
    loadOperations()
  }, [])

  const handleCreate = () => {
    if (!newOpName.trim()) return

    fetch('/api/ai-operations', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ name: newOpName, type: newOpType })
    })
      .then(res => res.json())
      .then(() => {
        setNewOpName('')
        setShowCreate(false)
        loadOperations()
      })
      .catch(() => {
        setNewOpName('')
        setShowCreate(false)
      })
  }

  const getTypeIcon = (type: string) => {
    switch (type) {
      case 'market_analysis': return '📊'
      case 'monitoring': return '👁️'
      case 'content_generation': return '📝'
      case 'data_processing': return '⚙️'
      case 'nlp_analysis': return '🧠'
      case 'dev_loop': return '🔁'
      default: return '🎯'
    }
  }

  return (
    <>
      <div className="section-header">
        <h2 className="section-title">AI Operations</h2>
        <button className="btn btn-primary" onClick={() => setShowCreate(true)}>
          <Plus size={18} />
          New Operation
        </button>
      </div>

      {showCreate && (
        <div className="card" style={{ marginBottom: '24px' }}>
          <div className="card-header">
            <h3 className="card-title">Create New Operation</h3>
          </div>
          <div className="card-body">
            <div style={{ display: 'grid', gap: '16px', maxWidth: '500px' }}>
              <div className="form-group" style={{ marginBottom: 0 }}>
                <label className="form-label">Operation Name</label>
                <input
                  type="text"
                  className="form-input"
                  placeholder="Enter operation name..."
                  value={newOpName}
                  onChange={(e) => setNewOpName(e.target.value)}
                />
              </div>
              <div className="form-group" style={{ marginBottom: 0 }}>
                <label className="form-label">Type</label>
                <select
                  className="form-input"
                  value={newOpType}
                  onChange={(e) => setNewOpType(e.target.value)}
                >
                  <option value="general">General</option>
                  <option value="market_analysis">Market Analysis</option>
                  <option value="monitoring">Monitoring</option>
                  <option value="content_generation">Content Generation</option>
                  <option value="data_processing">Data Processing</option>
                  <option value="nlp_analysis">NLP Analysis</option>
                </select>
              </div>
              <div style={{ display: 'flex', gap: '12px' }}>
                <button className="btn btn-primary" onClick={handleCreate}>
                  <Plus size={18} />
                  Create
                </button>
                <button className="btn btn-ghost" onClick={() => setShowCreate(false)}>
                  Cancel
                </button>
              </div>
            </div>
          </div>
        </div>
      )}

      <div className="card">
        <div className="card-body" style={{ padding: 0 }}>
          <table className="table">
            <thead>
              <tr>
                <th>Operation</th>
                <th>Type</th>
                <th>Status</th>
                <th>Created</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>
              {operations.length === 0 && (
                <tr>
                  <td colSpan={5} style={{ textAlign: 'center', color: 'var(--text-tertiary)', padding: '32px' }}>
                    {loaded ? 'No operations logged yet' : 'Loading operations…'}
                  </td>
                </tr>
              )}
              {operations.map(op => (
                <tr key={op.id}>
                  <td>
                    <div style={{ fontWeight: 500 }}>{op.name}</div>
                  </td>
                  <td>
                    <span style={{ fontSize: '1.2rem', marginRight: '8px' }}>
                      {getTypeIcon(op.type)}
                    </span>
                    {op.type.replace(/_/g, ' ')}
                  </td>
                  <td>
                    <span className={`status-badge ${op.status}`}>
                      {op.status}
                    </span>
                  </td>
                  <td style={{ color: 'var(--text-secondary)' }}>
                    {op.created_at ? new Date(op.created_at).toLocaleString() : '—'}
                  </td>
                  <td>
                    <div style={{ display: 'flex', gap: '8px' }}>
                      {op.status === 'running' ? (
                        <button className="btn btn-ghost btn-sm">
                          <Pause size={16} />
                        </button>
                      ) : (
                        <button className="btn btn-ghost btn-sm">
                          <Play size={16} />
                        </button>
                      )}
                      <button className="btn btn-ghost btn-sm">
                        <RotateCcw size={16} />
                      </button>
                    </div>
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
