#!/bin/bash
# rotate-secret.sh
# Rotates DB password in RDS and Secrets Manager
# Usage: ./rotate-secret.sh
# WARNING: This will briefly disrupt DB connections

set -e

REGION="ap-southeast-2"
SECRET_ID="/payment-app/db-credentials"
DB_INSTANCE="payment-db"
DB_USER="adminUser"

# Colours
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "================================================"
echo " Payment App — Secret Rotation"
echo " $(date)"
echo "================================================"
echo ""
echo -e "${YELLOW}⚠️  WARNING: This will rotate the DB password.${NC}"
echo -e "${YELLOW}   Active DB connections will be briefly disrupted.${NC}"
echo ""
read -p "Are you sure you want to continue? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
  echo "Rotation cancelled."
  exit 0
fi

# ── 1. Generate new password ───────────────────────
echo ""
echo "[ 1/4 ] Generating new password..."
NEW_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/&$!@#%^*(){}[]|\\\"';<>?,\`~" | cut -c1-24)
echo "  ✅ Password generated"

# ── 2. Update RDS ──────────────────────────────────
echo ""
echo "[ 2/4 ] Updating RDS password..."
aws rds modify-db-instance \
  --db-instance-identifier $DB_INSTANCE \
  --master-user-password "$NEW_PASSWORD" \
  --apply-immediately \
  --region $REGION > /dev/null

echo "  ✅ RDS password updated"
echo "  ⏳ Waiting for RDS to apply changes..."

# Wait for RDS to be available
while true; do
  STATUS=$(aws rds describe-db-instances \
    --db-instance-identifier $DB_INSTANCE \
    --region $REGION \
    --query 'DBInstances[0].DBInstanceStatus' \
    --output text)

  if [ "$STATUS" == "available" ]; then
    echo "  ✅ RDS is available"
    break
  fi
  echo "     Status: $STATUS — waiting 10s..."
  sleep 10
done

# ── 3. Update Secrets Manager ──────────────────────
echo ""
echo "[ 3/4 ] Updating Secrets Manager..."
CURRENT_SECRET=$(aws secretsmanager get-secret-value \
  --secret-id $SECRET_ID \
  --region $REGION \
  --query 'SecretString' \
  --output text)

UPDATED_SECRET=$(echo $CURRENT_SECRET | python3 -c "
import json, sys
secret = json.load(sys.stdin)
secret['DB_PASSWORD'] = '$NEW_PASSWORD'
print(json.dumps(secret))
")

aws secretsmanager update-secret \
  --secret-id $SECRET_ID \
  --secret-string "$UPDATED_SECRET" \
  --region $REGION > /dev/null

echo "  ✅ Secrets Manager updated"

# ── 4. Force ECS task restart ──────────────────────
echo ""
echo "[ 4/4 ] Restarting ECS tasks to pick up new credentials..."
aws ecs update-service \
  --cluster payment-cluster \
  --service payment-service \
  --force-new-deployment \
  --region $REGION > /dev/null

echo "  ✅ ECS deployment triggered"
echo "  ⏳ New tasks will fetch updated secret from Secrets Manager"

echo ""
echo "================================================"
echo -e "${GREEN} Rotation complete!${NC}"
echo " New password stored in Secrets Manager"
echo " ECS tasks restarting with new credentials"
echo " $(date)"
echo "================================================"
