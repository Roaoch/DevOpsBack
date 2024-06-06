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

def get_query(id: str):
  def execute_query(session):
    return session.transaction().execute(
      f"DELETE FROM `root/leads` WHERE id = '{id}';",
      commit_tx=True,
      settings=ydb.BaseRequestSettings().with_timeout(3).with_operation_timeout(2)
    )
  return execute_query

def handler(event, context):
  if isinstance(event['body'], dict):
    event = event['body']
  else:
    event = json.loads(event['body'])

  if 'id' in event:
    result = pool.retry_operation_sync(get_query(
      id=event['id']
    ))
    return {
      'statusCode': 200,
      'body': "",
    }
  else:
    return {
      'statusCode': 400,
      'body': 'Id is None',
    }
