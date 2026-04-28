#!/usr/bin/env bash
# Launch a small spot VM for the B3 Neo4j baseline experiment.
#
# Defaults:
#   Instance: r7i.2xlarge (8 vCPU, 64 GB RAM, ~$0.20/h spot)
#   Region:   ap-south-1, AZ ap-south-1b
#   AMI:      ami-064db7e473d174d07 (biomed-demo, has Samyama prereqs)
#   Disk:     100 GB gp3 (snapshots ~750 MB + Neo4j data + CSVs)
#
# Usage:
#   SG_ID=sg-xxxx ./launch-b3-vm.sh
#
# After launch:
#   ssh -i ~/.ssh/pem/graph.pem ubuntu@<PUB_IP>

set -euo pipefail

export AWS_REGION="${AWS_REGION:-ap-south-1}"
INSTANCE_TYPE="${INSTANCE_TYPE:-r7i.2xlarge}"
AZ="${AZ:-ap-south-1b}"
AMI="${AMI:-ami-064db7e473d174d07}"
DISK_GB="${DISK_GB:-100}"
KEY_NAME="${KEY_NAME:-graph}"
KEY_FILE="${KEY_FILE:-$HOME/.ssh/pem/graph.pem}"
SG_ID="${SG_ID:?SG_ID required — export your EC2 security group ID}"

echo "Launching $INSTANCE_TYPE in $AZ (AMI $AMI, disk ${DISK_GB}GB)"
INST=$(aws ec2 run-instances --region "$AWS_REGION" \
  --image-id "$AMI" \
  --instance-type "$INSTANCE_TYPE" \
  --placement "AvailabilityZone=$AZ" \
  --key-name "$KEY_NAME" \
  --security-group-ids "$SG_ID" \
  --instance-market-options '{"MarketType":"spot","SpotOptions":{"SpotInstanceType":"one-time"}}' \
  --block-device-mappings "[{\"DeviceName\":\"/dev/sda1\",\"Ebs\":{\"VolumeSize\":${DISK_GB},\"VolumeType\":\"gp3\"}}]" \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=samyama-b3-baseline}]' \
  --query 'Instances[0].InstanceId' --output text)

echo "Instance ID: $INST"
for _ in $(seq 1 30); do
  PUB_IP=$(aws ec2 describe-instances --region "$AWS_REGION" --instance-ids "$INST" \
    --query "Reservations[0].Instances[0].PublicIpAddress" --output text)
  [[ "$PUB_IP" != "None" && -n "$PUB_IP" ]] && break
  sleep 2
done
echo "Public IP: $PUB_IP"
echo
echo "Wait ~30s for boot, then:"
echo "  ssh -i $KEY_FILE ubuntu@$PUB_IP"
echo
echo "On the VM, run:"
echo "  curl -fsSL https://raw.githubusercontent.com/samyama-ai/samyama-graph-book/main/research/paper5-iswc-inuse/b3-neo4j-baseline/setup-b3.sh | bash"
echo
echo "To terminate when done:"
echo "  aws ec2 terminate-instances --region $AWS_REGION --instance-ids $INST"
