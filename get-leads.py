import json
import ydb
import ydb.iam

driver = ydb.Driver(
  endpoint='grpcs://ydb.serverless.yandexcloud.net:2135',
  database='/ru-central1/b1gfns2re5nhiv564e87/etnptel3hir13svk41ca',
  credentials=ydb.iam.MetadataUrlCredentials(),
)
driver.wait(fail_fast=True, timeout=5)
pool = ydb.SessionPool(driver)

def get_query():
  def execute_query(session):
    return session.transaction().execute(
      "SELECT id, description, name, status, is_final FROM leads;",
      commit_tx=True,
      settings=ydb.BaseRequestSettings().with_timeout(3).with_operation_timeout(2)
    )
  return execute_query

def handler(event, context):
  if isinstance(event['body'], dict):
    event = event['body']
  else:
    event = json.loads(event['body'])

  result = pool.retry_operation_sync(get_query())
  data = []
  for res in result:
    for row in res.rows:
      data.append({
        "id": str(row["id"]),
        "description": str(row["description"]),
        "name": str(row["name"]),
        "status": str(row["status"]),
        "is_final": row["is_final"]
      })
  return {
    'statusCode': 200,
    'body': json.dumps({
      "data": data
    }),
  }