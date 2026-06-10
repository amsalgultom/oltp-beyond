let chUrl: string
let chUser: string
let chPassword: string
let chDatabase: string

function initClickHouse() {
  const url = process.env.CLICKHOUSE_URL
  const user = process.env.CLICKHOUSE_USER
  const password = process.env.CLICKHOUSE_PASSWORD
  const database = process.env.CLICKHOUSE_DATABASE

  if (!url || !user || !password || !database) {
    throw new Error('Missing ClickHouse connection variables in env')
  }

  chUrl = url.endsWith('/') ? url : url + '/'
  chUser = user
  chPassword = password
  chDatabase = database
}

export async function queryClickHouse(query: string, params?: Record<string, any>) {
  if (!chUrl) initClickHouse()

  const headers: Record<string, string> = {
    'X-ClickHouse-User': chUser,
    'X-ClickHouse-Key': chPassword,
    'X-ClickHouse-Database': chDatabase,
    'Content-Type': 'application/json',
  }

  const queryStr = params ? `${query} FORMAT JSONEachRow` : `${query} FORMAT JSONEachRow`

  const response = await fetch(chUrl, {
    method: 'POST',
    headers,
    body: queryStr,
  })

  if (!response.ok) {
    throw new Error(`ClickHouse error: ${response.status} ${response.statusText}`)
  }

  const text = await response.text()
  return text.split('\n').filter(Boolean).map(line => JSON.parse(line))
}
