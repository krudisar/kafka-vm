# ------- Download & extract OSS Kafka scripts to test provisioned env -> based on https://kafka.apache.org/quickstart
wget https://dlcdn.apache.org/kafka/2.8.0/kafka_2.13-2.8.0.tgz
tar -xzf kafka_2.13-2.8.0.tgz
cd kafka_2.13-2.8.0/bin/

# ... try to create a few topics - against different kafka brokers
bash kafka-topics.sh --create --topic quickstart-events --bootstrap-server localhost:9092
bash kafka-topics.sh --create --topic quickstart-events-1 --bootstrap-server kafka1.krdemo.local:9092
bash kafka-topics.sh --create --topic quickstart-events-2 --bootstrap-server kafka2.krdemo.local:9092
bash kafka-topics.sh --create --topic quickstart-events-3 --bootstrap-server kafka3.krdemo.local:9092

# ... get topic description referencing the 'other' broker
bash kafka-topics.sh --describe --topic quickstart-events-3 --bootstrap-server kafka1.krdemo.local:9092
bash kafka-topics.sh --describe --topic quickstart-events-1 --bootstrap-server kafka2.krdemo.local:9092
bash kafka-topics.sh --describe --topic quickstart-events-2 --bootstrap-server kafka3.krdemo.local:9092

# ... list all availble topics
bash kafka-topics.sh --list --zookeeper localhost:2181
bash kafka-topics.sh --list --zookeeper kafka1.krdemo.local:2181
bash kafka-topics.sh --list --zookeeper kafka2.krdemo.local:2181
bash kafka-topics.sh --list --zookeeper kafka3.krdemo.local:2181
# ------- End of testing ...
