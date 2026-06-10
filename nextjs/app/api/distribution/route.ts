import { queryClickHouse } from '@/lib/clickhouse'
import { NextResponse } from 'next/server'

export const dynamic = 'force-dynamic'

export async function GET() {
  try {
    const talkDurationQuery = `
      SELECT
        quantilesExact(0.5, 0.75, 0.9, 0.95, 0.99)(billsec) AS quantiles,
        round(avg(billsec), 1) AS mean_sec,
        max(billsec) AS max_sec,
        min(billsec) AS min_sec
      FROM cdr FINAL
      WHERE _is_deleted = 0 AND disposition = 'ANSWERED'
        AND toDate(calldate) >= toDate(now() - INTERVAL 30 DAY)
    `

    const dispositionQuery = `
      SELECT
        disposition,
        count() AS total,
        round(100.0 * total / sum(total) OVER (), 1) AS pct
      FROM cdr FINAL
      WHERE _is_deleted = 0 AND toDate(calldate) >= toDate(now() - INTERVAL 30 DAY)
      GROUP BY disposition
      ORDER BY total DESC
    `

    const agingQuery = `
      SELECT
        aging_bucket,
        count() AS kontrak_count,
        round(avg(days_overdue), 1) AS avg_days,
        round(sum(outstanding_amount) / 1000000, 2) AS total_outstanding_mio
      FROM v_collection_task
      GROUP BY aging_bucket
      ORDER BY
        CASE
          WHEN aging_bucket = '1-30' THEN 1
          WHEN aging_bucket = '31-60' THEN 2
          WHEN aging_bucket = '61-90' THEN 3
          ELSE 4
        END
    `

    const [talkDuration, disposition, aging] = await Promise.all([
      queryClickHouse(talkDurationQuery),
      queryClickHouse(dispositionQuery),
      queryClickHouse(agingQuery),
    ])

    return NextResponse.json({
      talk_duration: talkDuration && talkDuration.length > 0 ? talkDuration[0] : null,
      disposition: disposition || [],
      aging: aging || [],
    })
  } catch (error) {
    console.error('Distribution API error:', error)
    return NextResponse.json(
      { error: 'Failed to fetch distribution data' },
      { status: 500 }
    )
  }
}
