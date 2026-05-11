#!/bin/bash
# deploy-check.sh
# Checks the health of the payment-app pipeline and ECS service
# Usage: ./deploy-check.sh

set -e

REGION="ap-southeast-2"
CLUSTER="payment-cluster"
SERVICE="payment-service"
PIPELINE="payment-pipeline"

# Colours
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No colour

echo "================================================"
echo " Payment App — Deployment Health Check"
echo " $(date)"
echo "================================================"

# ── 1. Pipeline state ──────────────────────────────
echo ""
echo "[ PIPELINE ]"
STAGES=$(aws codepipeline get-pipeline-state \
  --name $PIPELINE \
  --region $REGION \
  --query 'stageStates[*].{Stage:stageName,Status:latestExecution.status}' \
  --output json)

echo "$STAGES" | python3 -c "
import json, sys
stages = json.load(sys.stdin)
for s in stages:
    status = s['Status'] or 'NOT_STARTED'
    if status == 'Succeeded':
        print(f\"  ✅ {s['Stage']:<20} {status}\")
    elif status == 'Failed':
        print(f\"  ❌ {s['Stage']:<20} {status}\")
    elif status == 'InProgress':
        print(f\"  🔄 {s['Stage']:<20} {status}\")
    else:
        print(f\"  ⏸  {s['Stage']:<20} {status}\")
"

# ── 2. ECS service health ──────────────────────────
echo ""
echo "[ ECS SERVICE ]"
SERVICE_INFO=$(aws ecs describe-services \
  --cluster $CLUSTER \
  --services $SERVICE \
  --region $REGION \
  --query 'services[0].{Running:runningCount,Desired:desiredCount,Pending:pendingCount,Status:status}' \
  --output json)

RUNNING=$(echo $SERVICE_INFO | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['Running'])")
DESIRED=$(echo $SERVICE_INFO | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['Desired'])")
PENDING=$(echo $SERVICE_INFO | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['Pending'])")

if [ "$RUNNING" -eq "$DESIRED" ] && [ "$PENDING" -eq "0" ]; then
  echo -e "  ${GREEN}✅ Running: $RUNNING / Desired: $DESIRED / Pending: $PENDING${NC}"
else
  echo -e "  ${RED}❌ Running: $RUNNING / Desired: $DESIRED / Pending: $PENDING${NC}"
fi

# ── 3. CloudWatch alarms ───────────────────────────
echo ""
echo "[ ALARMS ]"
ALARMS=$(aws cloudwatch describe-alarms \
  --alarm-names \
    "payment-task-stopped" \
    "payment-alb-5xx-errors" \
    "payment-high-cpu" \
  --region $REGION \
  --query 'MetricAlarms[*].{Name:AlarmName,State:StateValue}' \
  --output json)

echo "$ALARMS" | python3 -c "
import json, sys
alarms = json.load(sys.stdin)
for a in alarms:
    if a['State'] == 'OK':
        print(f\"  ✅ {a['Name']:<35} {a['State']}\")
    elif a['State'] == 'ALARM':
        print(f\"  ❌ {a['Name']:<35} {a['State']}\")
    else:
        print(f\"  ⚠️  {a['Name']:<35} {a['State']}\")
"

# ── 4. ALB target health ───────────────────────────
echo ""
echo "[ TARGET HEALTH ]"
TG_ARN=$(aws elbv2 describe-target-groups \
  --names payment-targets payment-targets-green \
  --region $REGION \
  --query 'TargetGroups[*].TargetGroupArn' \
  --output text)

for ARN in $TG_ARN; do
  TG_NAME=$(aws elbv2 describe-target-groups \
    --target-group-arns $ARN \
    --region $REGION \
    --query 'TargetGroups[0].TargetGroupName' \
    --output text)

  HEALTH=$(aws elbv2 describe-target-health \
    --target-group-arn $ARN \
    --region $REGION \
    --query 'TargetHealthDescriptions[*].TargetHealth.State' \
    --output text)

  if [ -z "$HEALTH" ]; then
    echo "  ⏸  $TG_NAME — no targets registered"
  elif echo "$HEALTH" | grep -q "healthy"; then
    echo -e "  ${GREEN}✅ $TG_NAME — healthy${NC}"
  else
    echo -e "  ${RED}❌ $TG_NAME — $HEALTH${NC}"
  fi
done

echo ""
echo "================================================"
