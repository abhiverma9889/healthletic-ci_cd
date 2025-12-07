#!/bin/bash
set -euo pipefail

if [[ $# -ne 3 ]]; then
  echo "Usage: ./deploy.sh <environment> <version> <registry>"
  exit 1
fi

ENVIRONMENT=$1
VERSION=$2
REGISTRY=$3
LOG_FILE="deploy.log"
echo "[$(date -Iseconds)] Starting deployment: env=$ENVIRONMENT version=$VERSION registry=$REGISTRY" | tee -a $LOG_FILE

# Determine active color
ACTIVE_COLOR=$(kubectl get svc backend -n ${ENVIRONMENT} -o jsonpath='{.spec.selector.color}' 2>/dev/null || echo "blue")
if [[ "$ACTIVE_COLOR" == "blue" ]]; then
  INACTIVE_COLOR="green"
else
  INACTIVE_COLOR="blue"
fi

echo "Active color: $ACTIVE_COLOR. Deploying new version to: $INACTIVE_COLOR" | tee -a $LOG_FILE

# Install or upgrade inactive deployment
helm upgrade --install backend-${INACTIVE_COLOR} helm/backend       --set color=${INACTIVE_COLOR}       --set image.repository=${REGISTRY}/backend       --set image.tag=${VERSION}       --namespace ${ENVIRONMENT} --create-namespace --wait --timeout 5m | tee -a $LOG_FILE

# Run smoke tests against the inactive deployment service (temporary service)
TEMP_SVC="backend-${INACTIVE_COLOR}-temp"
kubectl expose deployment backend-${INACTIVE_COLOR} --type=ClusterIP --name=${TEMP_SVC} -n ${ENVIRONMENT} --port=5000 --target-port=5000 --dry-run=client -o yaml | kubectl apply -n ${ENVIRONMENT} -f - | tee -a $LOG_FILE
sleep 5
POD_IP=$(kubectl get svc ${TEMP_SVC} -n ${ENVIRONMENT} -o jsonpath='{.spec.clusterIP}')
echo "Temporary service IP: $POD_IP" | tee -a $LOG_FILE

# Smoke test endpoints
set +e
curl -sS --fail http://${POD_IP}:5000/health -m 10
CURL_RC=$?
set -e
if [[ $CURL_RC -ne 0 ]]; then
  echo "Smoke test failed against new deployment. Rolling back." | tee -a $LOG_FILE
  kubectl delete svc ${TEMP_SVC} -n ${ENVIRONMENT} || true
  helm rollback backend-${INACTIVE_COLOR} 1 || true
  exit 1
fi

# Switch service selector to new color
echo "Promoting ${INACTIVE_COLOR} to active." | tee -a $LOG_FILE
kubectl patch svc backend -n ${ENVIRONMENT} -p "{"spec":{"selector":{"app":"backend","color":"${INACTIVE_COLOR}"}}}" || {
  # If patch fails, create the service
  kubectl create service clusterip backend --tcp=5000:5000 -n ${ENVIRONMENT}
  kubectl patch svc backend -n ${ENVIRONMENT} -p "{"spec":{"selector":{"app":"backend","color":"${INACTIVE_COLOR}"}}}"
}

# Cleanup temp service
kubectl delete svc ${TEMP_SVC} -n ${ENVIRONMENT} || true

echo "Deployment to ${ENVIRONMENT} successful. Active color is now ${INACTIVE_COLOR}." | tee -a $LOG_FILE
