#!/bin/bash

echo 'Ready to deploy customized Kafka cluster environment ...' >> /tmp/kafka-vm.log

VM_NAME=kafka-node
JSON_FILE=deployment.json
JSON_QUERY='.resources."'$VM_NAME'[0]".count'
OUTPUT_FILE=dns_records.txt
CONFIG_FILE=zookeeper.properties
MACHINE_NAME_PREFIX=kafka
VM_DNS_DOMAIN=krdemo.local

# get number of nodes in the cluster
KAFKA_NODES=`jq $JSON_QUERY $JSON_FILE | sed -e 's/^"//' -e 's/"$//'`

# ------- DNS Records --------
echo -e '\nDNS Records follow ...\n'

for ((i = 0 ; i < $KAFKA_NODES ; i++)); do

  JSON_QUERY='.resources."'$VM_NAME'['$i']".resourceName'
  #NODE_NAME=`jq $JSON_QUERY $JSON_FILE | sed -e 's/^"//' -e 's/"$//'`
  NODE_NAME=$MACHINE_NAME_PREFIX$((i+1))
  
  JSON_QUERY='.resources."'$VM_NAME'['$i']".networks[0].address'
  NODE_IP=`jq $JSON_QUERY $JSON_FILE | sed -e 's/^"//' -e 's/"$//'`

  echo -e $NODE_IP '\t' $NODE_NAME'.'$VM_DNS_DOMAIN >> $OUTPUT_FILE

  # add to array
  arrayIps+=$NODE_IP
  echo ${arrayIps[$(i)]}
  arrayFqdns+=$NODE_NAME'.'$VM_DNS_DOMAIN
  echo ${arrayFqdns[$(i)]}
done

# ------- zookeeper.properties --------
echo 'Going to generate zookeeper.properties file ...'
echo "INFO: Number of cluster nodes: " $CLUSTER_NODES
# ---
echo "tickTime=2000" > $CONFIG_FILE
echo "dataDir=/var/lib/zookeeper/" >> $CONFIG_FILE
echo "clientPort=2181" >> $CONFIG_FILE
echo "initLimit=5" >> $CONFIG_FILE
echo "syncLimit=2" >> $CONFIG_FILE

for ((i = 1 ; i <= $KAFKA_NODES ; i++)); do

  MACHINE_NAME=$MACHINE_NAME_PREFIX$i
  echo server.$i=$MACHINE_NAME.$VM_DNS_DOMAIN:2888:3888 >> $CONFIG_FILE

done

echo "autopurge.snapRetainCount=3" >> $CONFIG_FILE
echo "autopurge.purgeInterval=24" >> $CONFIG_FILE

# ------- Copy files to the rest of the cluster's nodes and enable services --------

SSHUSERNAME=demo
SSHOPTIONS='-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no'
PASSWORDFILE=/root/.sshpassword

# ... copy configuration files
sudo sshpass -f $PASSWORDFILE scp $SSHOPTIONS $CONFIG_FILE $SSHUSERNAME@$NODE_IP:/tmp/$CONFIG_FILE
sudo sshpass -f $PASSWORDFILE scp $SSHOPTIONS $OUTPUT_FILE $SSHUSERNAME@$NODE_IP:/tmp/$OUTPUT_FILE

# ... replace and merge 
sudo sshpass -f $PASSWORDFILE ssh $SSHOPTIONS $SSHUSERNAME@$NODE_IP "sudo mv /etc/kafka/$CONFIG_FILE /etc/kafka/$CONFIG_FILE.orig"
sudo sshpass -f $PASSWORDFILE ssh $SSHOPTIONS $SSHUSERNAME@$NODE_IP "sudo cp /tmp/$CONFIG_FILE /etc/kafka/$CONFIG_FILE"
sudo sshpass -f $PASSWORDFILE ssh $SSHOPTIONS $SSHUSERNAME@$NODE_IP "cat /tmp/$OUTPUT_FILE | sudo tee -a /etc/hosts"
