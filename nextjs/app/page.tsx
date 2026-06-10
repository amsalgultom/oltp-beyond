'use client'

import { useEffect, useState } from 'react'
import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, Legend, ResponsiveContainer } from 'recharts'

interface StreamingData {
  minute: string
  calls: number
  answered: number
  connect_rate_pct: number
  total_talk_min: number
  branch_code: string
}

interface LiveMetrics {
  current_calls: number
  connect_rate_pct: number
  avg_talk_sec: number
  calls_last_hour: number
}

export default function Overview() {
  const [data, setData] = useState<StreamingData[]>([])
  const [metrics, setMetrics] = useState<LiveMetrics | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    const fetchData = async () => {
      try {
        const response = await fetch('/api/streaming')
        if (!response.ok) throw new Error(`HTTP ${response.status}`)
        const result = await response.json()
        setData(result.data || [])
        setMetrics(result.metrics || null)
        setError(null)
      } catch (err) {
        setError(err instanceof Error ? err.message : 'Failed to fetch streaming data')
      } finally {
        setLoading(false)
      }
    }

    fetchData()
    const interval = setInterval(fetchData, 10000)
    return () => clearInterval(interval)
  }, [])

  return (
    <div>
      <h2 className="page-title">Overview</h2>
      <p className="page-subtitle">Real-time collection pipeline metrics</p>

      {error && <div className="error">Error: {error}</div>}

      <div className="grid">
        <div className="card">
          <div className="card-title">Live Metrics</div>
          {loading ? (
            <div className="loading">Loading...</div>
          ) : metrics ? (
            <div>
              <div className="metric">
                <span className="metric-label">Current Calls (last minute)</span>
                <span className="metric-value">{metrics.current_calls}</span>
              </div>
              <div className="metric">
                <span className="metric-label">Connect Rate</span>
                <span className="metric-value">{metrics.connect_rate_pct}%</span>
              </div>
              <div className="metric">
                <span className="metric-label">Avg Talk Duration</span>
                <span className="metric-value">{metrics.avg_talk_sec}<span className="metric-unit">sec</span></span>
              </div>
              <div className="metric">
                <span className="metric-label">Calls (last hour)</span>
                <span className="metric-value">{metrics.calls_last_hour}</span>
              </div>
            </div>
          ) : (
            <div className="loading">No data</div>
          )}
        </div>

        <div className="card">
          <div className="card-title">Calls per Minute (60 min)</div>
          {data.length > 0 ? (
            <div className="chart-container">
              <ResponsiveContainer width="100%" height="100%">
                <LineChart data={data}>
                  <CartesianGrid strokeDasharray="3 3" />
                  <XAxis dataKey="minute" stroke="#7f8c8d" />
                  <YAxis stroke="#7f8c8d" />
                  <Tooltip />
                  <Legend />
                  <Line type="monotone" dataKey="calls" stroke="#3498db" />
                  <Line type="monotone" dataKey="answered" stroke="#27ae60" />
                </LineChart>
              </ResponsiveContainer>
            </div>
          ) : (
            <div className="loading">Loading chart...</div>
          )}
        </div>
      </div>
    </div>
  )
}
