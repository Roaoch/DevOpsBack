import requests

url = 'https://d5dnebshjibq2cticp6u.apigw.yandexcloud.net/get-leads'
myobj = {}

x = requests.post(url, json = myobj)

print(x.json())
