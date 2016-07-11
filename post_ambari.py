import requests
import json
import sys
import time

user = 'admin'
password = 'admin'

blueprint = None
with open('/vagrant/conf/ambari_blueprint_simple.json', 'r') as content_file:
    blueprint = json.load(content_file)

cluster = None
with open('/vagrant/conf/ambari_cluster.json', 'r') as content_file:
    cluster = json.load(content_file)

headers = { 'X-Requested-By': 'vagrant'}

def checkForAmbari():
    "wait for ambari to be ready"
    print "Wait for ambari to be ready"   
    try:
        r = requests.get('http://localhost:8080/api/v1/clusters', auth=(user, password))
        if r.status_code != 200:
            print "Status code" + str(r.status_code)
            return False
        else:
            return True
    except:
        print("Unexpected error:", sys.exc_info()[0])
        return False

while True:
  ready = checkForAmbari()
  time.sleep(5)
  if ready:
    break

print "Ambari Ready"

r = requests.post('http://localhost:8080/api/v1/blueprints/blueprint-simple', auth=(user, password), data=json.dumps(blueprint), headers=headers)

if r.status_code != 201:
    print r
    print r.json()
    sys.exit(1)

print "Blueprint uploaded"

r = requests.post('http://localhost:8080/api/v1/clusters/DEV', auth=(user, password), data=json.dumps(cluster), headers=headers)

if r.status_code != 202:
    print r
    print r.json()
    sys.exit(1)

print "Cluster creation submited"

clusterRequest = r.json()

if clusterRequest['Requests']['status'] != 'Accepted':
    print clusterRequest['Requests']['status']
    sys.exit(1)


def checkForClusterRequest( requestId ):
    "wait for cluster to be ready"
    print "Wait for cluster to be ready"   
    r = requests.get('http://localhost:8080/api/v1/clusters/DEV/requests/'+str(requestId), auth=(user, password))
    if r.status_code != 200:
        sys.exit(1)
    requestDetail = r.json()
    if requestDetail['Requests']['request_status'] == 'IN_PROGRESS' or requestDetail['Requests']['task_count'] == 0:
        return False
    else:
        return True

time.sleep(20)

while True:
  ready = checkForClusterRequest(clusterRequest['Requests']['id'])
  time.sleep(10)
  if ready:
    break

print "Cluster Ready"