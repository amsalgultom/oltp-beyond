'use client'

import { useEffect, useState } from 'react'
import { PieChart, Pie, Cell, BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, Legend, ResponsiveContainer } from 'recharts'

const COLORS = ['#3498db', '#27ae60', '#e74c3c', '#f39c12', '#9b59b6']

interface Disposition {
  disposition: string
  total: number
  pct: number
}

interface AgingBucket {
  aging_bucket: string
  kontrak_count: number
  avg_days: number
  total_outstanding_mio: number
}

interface TalkDuration {
  quantiles: number[]
  mean_sec: number
  max_sec: number
  min_sec: number
}

interface DistributionData {
  talk_duration: TalkDuration | null
  disposition: Disposition[]
  aging: AgingBucket[]
}

export default function DistributionPage() {
  const [data, setData] = useState<DistributionData | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    const fetchData = async () => {
      try {
        const response = await fetch('/api/distribution')
        if (!response.ok) throw new Error(`HTTP ${response.status}`)
        const result = await response.json()
        setData(result)
        setError(null)
      } catch (err) {
        setError(err instanceof Error ? err.message : 'Failed to fetch distribution data')
      } finally {
        setLoading(false)
      }
    }

    fetchData()
  }, [])

  if (loading) return <div className="loading">Loading...</div>
  if (error) return <div className="error">Error: {error}</div>

  return (
    <div>
      <h2 className="page-title">Distribution Analytics</h2>
      <p className="page-subtitle">Talk duration, disposition, and aging distribution</p>

      <div className="grid">
        {data?.talk_duration && (
          <div className="card">
            <div className="card-title">Talk Duration (30d)</div>
            <div className="metric">
              <span className="metric-label">Min</span>
              <span className="metric-value">{data.talk_duration.min_sec}s</span>
            </div>
            <div className="metric">
              <span className="metric-label">P50 (Median)</span>
              <span className="metric-value">{data.talk_duration.quantiles[0]}s</span>
            </div>
            <div className="metric">
              <span className="metric-label">P95</span>
              <span className="metric-value">{data.talk_duration.quantiles[3]}s</span>
            </div>
            <div className="metric">
              <span className="metric-label">P99</span>
              <span className="metric-value">{data.talk_duration.quantiles[4]}s</span>
            </div>
            <div className="metric">
              <span className="metric-label">Mean</span>
              <span className="metric-value">{data.talk_duration.mean_sec}s</span>
            </div>
            <div className="metric">
              <span className="metric-label">Max</span>
              <span className="metric-value">{data.talk_duration.max_sec}s</span>
            </div>
          </div>
        )}

        {data?.disposition && data.disposition.length > 0 && (
          <div className="card">
            <div className="card-title">Call Disposition (30d)</div>
            <div className="chart-container">
              <ResponsiveContainer width="100%" height="100%">
                <PieChart>
                  <Pie
                    data={data.disposition}
                    dataKey="total"
                    nameKey="disposition"
                    cx="50%"
                    cy="50%"
                    outerRadius={80}
                    label
                  >
                    {data.disposition.map((_, index) => (
                      <Cell key={`cell-${index}`} fill={COLORS[index % COLORS.length]} />
                    ))}
                  </Pie>
                  <Tooltip />
                </PieChart>
              </ResponsiveContainer>
            </div>
          </div>
        )}

        {data?.aging && data.aging.length > 0 && (
          <div className="card">
            <div className="card-title">Overdue Distribution</div>
            <div className="chart-container">
              <ResponsiveContainer width="100%" height="100%">
                <BarChart data={data.aging}>
                  <CartesianGrid strokeDasharray="3 3" />
                  <XAxis dataKey="aging_bucket" stroke="#7f8c8d" />
                  <YAxis stroke="#7f8c8d" />
                  <Tooltip />
                  <Legend />
                  <Bar dataKey="kontrak_count" fill="#3498db" name="Contracts" />
                </BarChart>
              </ResponsiveContainer>
            </div>
          </div>
        )}

        {data?.aging && data.aging.length > 0 && (
          <div className="card">
            <div className="card-title">Outstanding by Aging</div>
            <table>
              <thead>
                <tr>
                  <th>Bucket</th>
                  <th>Contracts</th>
                  <th>Avg Days</th>
                  <th>Outstanding (M)</th>
                </tr>
              </thead>
              <tbody>
                {data.aging.map((row) => (
                  <tr key={row.aging_bucket}>
                    <td>{row.aging_bucket}</td>
                    <td>{row.kontrak_count}</td>
                    <td>{row.avg_days}</td>
                    <td>Rp {row.total_outstanding_mio}M</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </div>
  )
}
