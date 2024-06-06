import uuid
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

def get_query(name: str, description: str):
  id = str(uuid.uuid4())
  def execute_query(session):
    return session.transaction().execute(
      f"INSERT INTO `root/leads` (id, description, name, status, is_final) VALUES ('{id}', '{description}', '{name}', 'Новый', FALSE);",
      commit_tx=True,
      settings=ydb.BaseRequestSettings().with_timeout(3).with_operation_timeout(2)
    )
  return (id, execute_query)

def handler(event, context):
  if isinstance(event['body'], dict):
    event = event['body']
  else:
    event = json.loads(event['body'])
    
  if 'name' in event and 'description' in event:
    id, funct = get_query(
      name=event['name'],
      description=event['description']
    )
    result = pool.retry_operation_sync(funct)
    return {
      'statusCode': 200,
      'body': json.dumps({
        'id': id
      }),
    }
  else:
    return {
      'statusCode': 400,
      'body': 'Name or Description is None',
    }
