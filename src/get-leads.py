import os
import json
import ydb
import ydb.iam

driver = ydb.Driver(
  endpoint=os.environ['endpoint'],
  database=os.environ['database'],
  credentials=ydb.iam.MetadataUrlCredentials(),
)
driver.wait(fail_fast=True, timeout=5)
pool = ydb.SessionPool(driver)

def get_query():
  def execute_query(session):
    return session.transaction().execute(
      "SELECT id, description, name, status, is_final FROM `root/leads`;",
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
  data_first = {
    'id': 1,
    'status': 'Новый',
    'items': []
  }
  data_second = {
    'id': 2,
    'status': 'В работе',
    'items': []
  }
  data_third = {
    'id': 3,
    'status': 'Отказ',
    'items': []
  }
  data_forth = {
    'id': 4,
    'status': 'Завершено',
    'items': []
  }
  for res in result:
    for row in res.rows:
      data_to_append = {
        "id": row["id"].decode("utf-8"),
        "description": row["description"].decode("utf-8"),
        "name": row["name"].decode("utf-8"),
        "status": row["status"].decode("utf-8"),
        "is_final": row["is_final"]
      }

      match data_to_append['status']:
        case 'Новый':
          data_first['items'].append(data_to_append)
        case 'В работе':
          data_second['items'].append(data_to_append)
        case 'Отказ':
          data_third['items'].append(data_to_append)
        case 'Завершено':
          data_forth['items'].append(data_to_append)
  return {
    'statusCode': 200,
    'body': json.dumps({
      "data": [
        data_first,
        data_second,
        data_third,
        data_forth
      ]
    }),
  }
