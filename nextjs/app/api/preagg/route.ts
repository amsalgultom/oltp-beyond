import { queryClickHouse } from '@/lib/clickhouse'
import { NextResponse } from 'next/server'

export const dynamic = 'force-dynamic'

export async function GET() {
  try {
    const agentProductivityQuery = `
      SELECT
        work_date,
        agent_username,
        tasks,
        calls,
        answered,
        ptp,
        round(talk_sec / 60, 1) AS talk_minutes,
        connect_rate_pct,
        ptp_rate_pct
      FROM vq_agent_productivity
      WHERE work_date >= toDate(now() - INTERVAL 30 DAY)
      ORDER BY work_date DESC, talk_sec DESC
      LIMIT 100
    `

    const totalProductivityQuery = `
      SELECT
        work_date,
        sumMerge(tasks_assigned) AS total_tasks,
        sumMerge(calls_made) AS total_calls,
        sumMerge(calls_answered) AS total_answered,
        sumMerge(ptp_achieved) AS total_ptp,
        round(sumMerge(talk_time_seconds) / 60, 0) AS total_talk_minutes
      FROM agg_agent_daily
      WHERE work_date >= toDate(now() - INTERVAL 30 DAY)
      GROUP BY work_date
      ORDER BY work_date DESC
    `

    const dispositionSummaryQuery = `
      SELECT
        count_date,
        disposition,
        countMerge(count) AS total_calls,
        round(avgMerge(avg_talk_sec), 1) AS avg_talk_seconds
      FROM agg_disposition_summary
      WHERE count_date >= toDate(now() - INTERVAL 30 DAY)
      GROUP BY count_date, disposition
      ORDER BY count_date DESC, total_calls DESC
    `

    const [agentProductivity, totalProductivity, dispositionSummary] = await Promise.all([
      queryClickHouse(agentProductivityQuery),
      queryClickHouse(totalProductivityQuery),
      queryClickHouse(dispositionSummaryQuery),
    ])

    return NextResponse.json({
      agent_productivity: agentProductivity || [],
      total_productivity: totalProductivity || [],
      disposition_summary: dispositionSummary || [],
    })
  } catch (error) {
    console.error('Pre-agg API error:', error)
    return NextResponse.json(
      { error: 'Failed to fetch pre-aggregated data' },
      { status: 500 }
    )
  }
}
