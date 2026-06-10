import { queryClickHouse } from '@/lib/clickhouse'
import { NextResponse } from 'next/server'

export const dynamic = 'force-dynamic'

export async function GET() {
  try {
    const query = `
      SELECT
        formatDateTime(minute, '%Y-%m-%d %H:%i') as minute,
        calls,
        answered,
        connect_rate_pct,
        round(total_talk_sec / 60, 1) as total_talk_min,
        branch_code
      FROM vq_live_cdr_minute
      ORDER BY minute DESC
      LIMIT 60
    `

    const data = await queryClickHouse(query)

    const metricsQuery = `
      SELECT
        count() as current_calls,
        round(avg(connect_rate_pct), 1) as connect_rate_pct,
        round(avg(round(total_talk_sec / calls, 0)), 0) as avg_talk_sec,
        sum(calls) as calls_last_hour
      FROM vq_live_cdr_minute
      WHERE minute >= now() - INTERVAL 60 MINUTE
    `

    const metrics = await queryClickHouse(metricsQuery)

    return NextResponse.json({
      data: data || [],
      metrics: (metrics && metrics.length > 0) ? metrics[0] : null,
    })
  } catch (error) {
    console.error('Streaming API error:', error)
    return NextResponse.json(
      { error: 'Failed to fetch streaming data' },
      { status: 500 }
    )
  }
}
