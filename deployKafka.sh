#!/bin/bash

echo 'Ready to deploy customized Kafka cluster environment ...' >> /tmp/kafka-vm.log

VM_NAME=kafka-node
JSON_FILE=deployment.json
JSON_QUERY='.resources."'$VM_NAME'[0]".count'
OUTPUT_FILE=dns_records.txt
CONFIG_FILE=zookeeper.properties
SERVER_CONFIG_FILE=server.properties
CC_CONFIG_FILE=control-center-production.properties
MACHINE_NAME_PREFIX=kafka
VM_DNS_DOMAIN=krdemo.local

declare -a arrayIps=()
declare -a arrayFqdns=()

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

  # add node IP into array
  arrayIps[${#arrayIps[@]}]=$NODE_IP
  echo ${arrayIps[$i]}

  # add node FQDN into array
  arrayFqdns[${#arrayFqdns[@]}]=$NODE_NAME'.'$VM_DNS_DOMAIN
  echo ${arrayFqdns[$i]}
  
  # echo ${#arrayIps[@]} # returns number of items in the array
  # echo ${arrayIps[@]}  # returns content of the array
  # echo ${arrayIps[$i]} # returns specific nth value in the array
  
done

# ------- /etc/kafka/zookeeper.properties --------
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

# ------- /etc/kafka/server.properties --------
sudo sed -i 's/^broker.id/#&/' /etc/kafka/$SERVER_CONFIG_FILE
sudo sed -i 's/^zookeeper.connect=/#&/' /etc/kafka/$SERVER_CONFIG_FILE
echo "broker.id.generation.enable=true" | sudo tee -a /etc/kafka/$SERVER_CONFIG_FILE
echo "zookeeper.connect=kafka1.$VM_DNS_DOMAIN:2181" | sudo tee -a /etc/kafka/$SERVER_CONFIG_FILE

# ------- /etc/confluent-control-center/control-center-production.properties --------
echo 'bootstrap.servers=kafka1.krdemo.local:9092,kafka2.krdemo.local:9092' | sudo tee -a /etc/confluent-control-center/$CC_CONFIG_FILE
echo 'zookeeper.connect=kafka1.krdemo.local:2181,kafka2.krdemo.local:2181' | sudo tee -a /etc/confluent-control-center/$CC_CONFIG_FILE
echo "confluent.license="$CONFLUENT_LICENSE | sudo tee -a /etc/confluent-control-center/$CC_CONFIG_FILE

# ------- Copy files to the rest of the cluster's nodes and enable services --------

SSHUSERNAME=demo
SSHOPTIONS='-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -q'
PASSWORDFILE=/root/.sshpassword

for ((i = 0 ; i < $KAFKA_NODES ; i++)); do

  TMP_IP=${arrayIps[$i]}
  echo 'Going to process cluster with IP:'${arrayIps[$i]}

    if (( $i == 0 )); then
        # for the first node we configure files locally
        #
        sudo mv /etc/kafka/$CONFIG_FILE /etc/kafka/$CONFIG_FILE.orig
        sudo cp $CONFIG_FILE /etc/kafka/$CONFIG_FILE
        cat $OUTPUT_FILE | sudo tee -a /etc/hosts
        #
        
        sudo systemctl enable confluent-zookeeper
        sudo systemctl start confluent-zookeeper
        
        #sleep 5
        sudo systemctl enable confluent-server
        sudo systemctl start confluent-server
        
        #sleep 10
        #sudo systemctl enable confluent-control-center
        #sudo systemctl start confluent-control-center
        
    else
        # for the rest of the cluster nodes we are going to configure them remotely
        #
        # ... copy configuration files
        sudo sshpass -f $PASSWORDFILE scp $SSHOPTIONS $CONFIG_FILE $SSHUSERNAME@$TMP_IP:/tmp/$CONFIG_FILE
        sudo sshpass -f $PASSWORDFILE scp $SSHOPTIONS /etc/kafka/$SERVER_CONFIG_FILE $SSHUSERNAME@$TMP_IP:/tmp/$SERVER_CONFIG_FILE
        sudo sshpass -f $PASSWORDFILE scp $SSHOPTIONS /etc/confluent-control-center/$CC_CONFIG_FILE $SSHUSERNAME@$TMP_IP:/tmp/$CC_CONFIG_FILE
        sudo sshpass -f $PASSWORDFILE scp $SSHOPTIONS $OUTPUT_FILE $SSHUSERNAME@$TMP_IP:/tmp/$OUTPUT_FILE
        
        # ... backup and replace | merge /etc/kafka/zookeeper.properties
        sudo sshpass -f $PASSWORDFILE ssh $SSHOPTIONS $SSHUSERNAME@$TMP_IP "sudo mv /etc/kafka/$CONFIG_FILE /etc/kafka/$CONFIG_FILE.orig"
        sudo sshpass -f $PASSWORDFILE ssh $SSHOPTIONS $SSHUSERNAME@$TMP_IP "sudo cp /tmp/$CONFIG_FILE /etc/kafka/$CONFIG_FILE"
        
        # ... backup and replace | merge /etc/kafka/server.properties        
        sudo sshpass -f $PASSWORDFILE ssh $SSHOPTIONS $SSHUSERNAME@$TMP_IP "sudo mv /etc/confluent-control-center/$CC_CONFIG_FILE /etc/confluent-control-center/$CC_CONFIG_FILE.orig"
        sudo sshpass -f $PASSWORDFILE ssh $SSHOPTIONS $SSHUSERNAME@$TMP_IP "sudo cp /tmp/$CC_CONFIG_FILE /etc/confluent-control-center/$CC_CONFIG_FILE"

        # ... backup and replace | merge /etc/confluent-control-center/control-center-production.properties        
        sudo sshpass -f $PASSWORDFILE ssh $SSHOPTIONS $SSHUSERNAME@$TMP_IP "sudo mv /etc/kafka/$SERVER_CONFIG_FILE /etc/kafka/$SERVER_CONFIG_FILE.orig"
        sudo sshpass -f $PASSWORDFILE ssh $SSHOPTIONS $SSHUSERNAME@$TMP_IP "sudo cp /tmp/$SERVER_CONFIG_FILE /etc/kafka/$SERVER_CONFIG_FILE"
       
        # ... add new DNS records to the /etc/hosts file
        sudo sshpass -f $PASSWORDFILE ssh $SSHOPTIONS $SSHUSERNAME@$TMP_IP "cat /tmp/$OUTPUT_FILE | sudo tee -a /etc/hosts"
        #

        sudo sshpass -f $PASSWORDFILE ssh $SSHOPTIONS $SSHUSERNAME@$TMP_IP "sudo systemctl enable confluent-zookeeper && sudo systemctl start confluent-zookeeper"
        #sleep 5
        sudo sshpass -f $PASSWORDFILE ssh $SSHOPTIONS $SSHUSERNAME@$TMP_IP "sudo systemctl enable confluent-server && sudo systemctl start confluent-server"
        #sleep 10
        #sudo sshpass -f $PASSWORDFILE ssh $SSHOPTIONS $SSHUSERNAME@$TMP_IP "sudo systemctl enable confluent-control-center && sudo systemctl start confluent-control-center"
    fi

done

echo " ... Testing time ..."
