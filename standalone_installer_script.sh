#!/bin/bash

# TODO https://github.com/apache/activemq-artemis/blob/330b6b70b90954324f9dad4a7a2d21e0de5747cf/docs/user-manual/en/clusters.md#configuring-cluster-connections

#set -x
# Variables here you go

MASTER_HOST=node-0.rahmed.lab.pnq2.cee.redhat.com
MASTER_IP=192.168.12.12
MASTER_PORT=6161
CONSOLE_PORT=8161
CLUSTER_CONNECTION_NAME=amq_cluster_configuration

# Variables that should not change
PRODUCT_HOME=/home/quicklab/amq-broker-7.8.0

AMQ_SERVER_CONF=$PRODUCT_HOME/etc
AMQ_SERVER_BIN=$PRODUCT_HOME/bin
AMQ_INSTANCES=$PRODUCT_HOME/instances
AMQ_MASTER=master-0
AMQ_MASTER_HOME=$AMQ_INSTANCES/$AMQ_MASTER


SHARED_FILESYSTEM="\/home\/quicklab\/amq-data\/persistence"
#SHARED_FILESYSTEM="\/amq-data"
AMQ_SHARED_PERSISTENCE_PAGING="$SHARED_FILESYSTEM\/paging"
AMQ_SHARED_PERSISTENCE_BINDINGS="$SHARED_FILESYSTEM\/bindings"
AMQ_SHARED_PERSISTENCE_JOURNAL="$SHARED_FILESYSTEM\/journal"
AMQ_SHARED_PERSISTENCE_LARGE_MESSAGE="$SHARED_FILESYSTEM\/large-messages"

#DEFAULT ADDRESS PARAMETERS
AUTO_DELETE_QUEUES=false
# Redelivery Variables
REDELIVERY_DELAY=5000
REDELIVERY_DELAY_MULTIPLIER=2
MAX_REDELIVERY_DELAY=50000
MAX_DELIVERY_ATTEMPTS=5
#expiry-delay defines the expiration time in milliseconds that will be used for messages which are using the default expiration time. i.e This only valid for message which did not explicity set their expiration, 2 Hours
EXPIRY_DELAY=7200000
#default maximum memory size of any address is (xx)Mb, after that the broker will ensure that the messages sent to a full address will be paged to disk 
MAX_SIZE_BYTES=24Mb
PAGE_SIZE_BYTES=8Mb # Each address has an individual folder where messages are stored in multiple files (page files). Each file size will be up to max configured size (page-size-bytes), Normally pageSize should be significantly smaller than maxSize
PAGE_MAX_CACHE_SIZE=3 #The number of page files to keep in memory to optimize I/O

#redistribution-delay defines the delay in milliseconds after the last consumer is closed on a queue before redistributing messages from that queue to other nodes of the cluster which do have matching consumers.
# so the value 0 would enable instant (no delay) redistribution for all JMS queues and topic subscriptions
REDISTRIBUTION_DELAY=0


LOCAL_IP=127.0.0.1
ALL_ADDRESSES=0.0.0.0

JMX_REMOTE_PORT=1199
JMX_REMOTE_RMI_PORT=1198

AMQ_ADMIN_ROLE=amq
HAWTIO_ADMIN_ROLE=console_access
AMQ_USER_ROLE_SEND=snd_dev_role
AMQ_USER_ROLE_RECIEVE=rcv_dev_role
AMQ_USER_ROLE_MANAGE=mng_dev_role



AMQ_ADMIN_USER=admin
AMQ_ADMIN_PASSWORD=passw0rd

AMQ_USER_USERNAME=amq_dev_user
AMQ_USER_PASSWORD=passw0rd

AMQ_SERVICE_NAME="amq-broker-$AMQ_MASTER"
AMQ_SERVICE_FILE="/etc/systemd/system/$AMQ_SERVICE_NAME.service"

create_standalone_broker () {
	echo "  - Create Standalone Broker"
	echo
	sh $AMQ_SERVER_BIN/artemis create --no-autotune --user $AMQ_ADMIN_USER --password $AMQ_ADMIN_PASSWORD  --role $AMQ_ADMIN_ROLE --name $AMQ_MASTER --host $MASTER_HOST --default-port $MASTER_PORT --require-login y --no-amqp-acceptor --no-hornetq-acceptor --no-mqtt-acceptor --no-stomp-acceptor $AMQ_INSTANCES/$AMQ_MASTER
}


update_broker_persistance_location () {
	# Setting persistance changes
	echo "  - Setting persistance changes"
	sed -i'' -e "s/data\/paging/$AMQ_SHARED_PERSISTENCE_PAGING/" $AMQ_MASTER_HOME/etc/broker.xml
	sed -i'' -e "s/data\/bindings/$AMQ_SHARED_PERSISTENCE_BINDINGS/" $AMQ_MASTER_HOME/etc/broker.xml
	sed -i'' -e "s/data\/journal/$AMQ_SHARED_PERSISTENCE_JOURNAL/" $AMQ_MASTER_HOME/etc/broker.xml
	sed -i'' -e "s/data\/large-messages/$AMQ_SHARED_PERSISTENCE_LARGE_MESSAGE/" $AMQ_MASTER_HOME/etc/broker.xml
}

allow_console_access () {
	# Allowing access to the console from the Any IPs. This is required in case of remote access to the console.
	echo "  - Adjust of the web console to listen all addresses"
	sed -i'' -e "s/localhost/0.0.0.0/" $AMQ_MASTER_HOME/etc/bootstrap.xml
	sed -i'' -e "s/8161/$CONSOLE_PORT/" $AMQ_MASTER_HOME/etc/bootstrap.xml

	sed -i'' -e "/<\/allow-origin>/ a \
		 \        <allow-origin>*:\/\/$MASTER_IP*<\/allow-origin>   \ " $AMQ_MASTER_HOME/etc/jolokia-access.xml
}

granting_custom_roles () {
	# Setup security permissions
	echo "  -Granting permissions for roles $AMQ_USER_ROLE_RECIEVE, $AMQ_USER_ROLE_SEND, $AMQ_USER_ROLE_MANAGE "

	sed -i'' -e "/<security-settings>/ a \ \n         <security-setting match=\"demo.#\"> \n            <permission type=\"createNonDurableQueue\" roles=\"$AMQ_ADMIN_ROLE, $AMQ_USER_ROLE_RECIEVE, $AMQ_USER_ROLE_SEND, $AMQ_USER_ROLE_MANAGE\" /> \n            <permission type=\"deleteNonDurableQueue\" roles=\"$AMQ_ADMIN_ROLE, $AMQ_USER_ROLE_MANAGE\" />          \n            <permission type=\"createDurableQueue\" roles=\"$AMQ_ADMIN_ROLE, $AMQ_USER_ROLE_RECIEVE, $AMQ_USER_ROLE_SEND, $AMQ_USER_ROLE_MANAGE\" />          \n            <permission type=\"deleteDurableQueue\" roles=\"$AMQ_ADMIN_ROLE, $AMQ_USER_ROLE_MANAGE\" />          \n            <permission type=\"createAddress\" roles=\"$AMQ_ADMIN_ROLE, $AMQ_USER_ROLE_RECIEVE, $AMQ_USER_ROLE_SEND, $AMQ_USER_ROLE_MANAGE\" />          \n            <permission type=\"deleteAddress\" roles=\"$AMQ_ADMIN_ROLE, $AMQ_USER_ROLE_MANAGE\" />          \n            <permission type=\"consume\" roles=\"$AMQ_ADMIN_ROLE, $AMQ_USER_ROLE_RECIEVE, $AMQ_USER_ROLE_MANAGE\" />          \n            <permission type=\"browse\" roles=\"$AMQ_ADMIN_ROLE, $AMQ_USER_ROLE_RECIEVE, $AMQ_USER_ROLE_MANAGE\" />          \n            <permission type=\"send\" roles=\"$AMQ_ADMIN_ROLE, $AMQ_USER_ROLE_SEND, $AMQ_USER_ROLE_MANAGE\" />          \n            <permission type=\"manage\" roles=\"$AMQ_ADMIN_ROLE, $AMQ_USER_ROLE_MANAGE\" /> \n         </security-setting>"  $AMQ_MASTER_HOME/etc/broker.xml

}

allow_hawtio_access () {
	# Allow HAWTIO_ADMIN_ROLE to access the HAWTIO admin screen and also give them privileges
	echo "  - Allow HAWTIO_ADMIN_GROUP to access the HAWTIO admin screen"
	sed -i.bak "s/hawtio.role=$AMQ_ADMIN_ROLE/hawtio.role=\"$AMQ_ADMIN_ROLE,$HAWTIO_ADMIN_ROLE\"/g" $AMQ_MASTER_HOME/etc/artemis.profile

	sed -i'' -e 's/method="list\*" roles="'$AMQ_ADMIN_ROLE'"/method="list\*" roles="'$HAWTIO_ADMIN_ROLE,$AMQ_ADMIN_ROLE'" / ' $AMQ_MASTER_HOME/etc/management.xml
	sed -i'' -e 's/method="get\*" roles="'$AMQ_ADMIN_ROLE'"/method="get\*" roles="'$HAWTIO_ADMIN_ROLE,$AMQ_ADMIN_ROLE'" / ' $AMQ_MASTER_HOME/etc/management.xml
	sed -i'' -e 's/method="is\*" roles="'$AMQ_ADMIN_ROLE'"/method="is\*" roles="'$HAWTIO_ADMIN_ROLE,$AMQ_ADMIN_ROLE'" / ' $AMQ_MASTER_HOME/etc/management.xml
	sed -i'' -e 's/method="set\*" roles="'$AMQ_ADMIN_ROLE'"/method="set\*" roles="'$HAWTIO_ADMIN_ROLE,$AMQ_ADMIN_ROLE'" / ' $AMQ_MASTER_HOME/etc/management.xml
	sed -i'' -e 's/method="\*" roles="'$AMQ_ADMIN_ROLE'"/method="\*" roles="'$HAWTIO_ADMIN_ROLE,$AMQ_ADMIN_ROLE'" / ' $AMQ_MASTER_HOME/etc/management.xml
}

enable_jmx_external_access () {
	# Enable JMX Management
	echo "  - Enable JMX Management"
	sed -i'' -e "/<\/addresses>/a \ \n      <jmx-management-enabled>true</jmx-management-enabled> \ " $AMQ_MASTER_HOME/etc/broker.xml
	#sed -i'' -e "/<authorisation>/i \ \n   <connector connector-host=\"$MASTER_HOST\" connector-port=\"$JMX_REMOTE_PORT\"/> \ " $AMQ_MASTER_HOME/etc/management.xml
	sed -i'' -e "/# JAVA_ARGS=/a \ \nif [ \"\$1\" = \"run\" ] || [ \"\$1\" = \"start\" ]; then \nJAVA_ARGS=\"\$JAVA_ARGS -Dcom.sun.management.jmxremote=true -Dcom.sun.management.jmxremote.port=$JMX_REMOTE_PORT -Dcom.sun.management.jmxremote.rmi.port=$JMX_REMOTE_RMI_PORT -Dcom.sun.management.jmxremote.ssl=false -Dcom.sun.management.jmxremote.authenticate=false\" \ \nfi" $AMQ_MASTER_HOME/etc/artemis.profile
}

enable_config_reload () {
	# Enable reloading configuration updates
	echo "  - Enable reloading configuration updates"
	sed -i'' -e "/<\/addresses>/a \ \n     <configuration-file-refresh-period>60000<\/configuration-file-refresh-period> \ " $AMQ_MASTER_HOME/etc/broker.xml
}


set_default_address_setting_attributes () {
	# Setting Message Redistribution
	# Redelivery delay
	# Message expire
	# Dead letter address
	# Slow consumer handling
	# Paging
	echo "  - Setting Message Redistribution, Redelivery delay, Message expire, Dead letter address, Slow consumer handling, Paging"
	sed -i'' -e "s/<redelivery-delay>0/<redelivery-delay>$REDELIVERY_DELAY/ " $AMQ_MASTER_HOME/etc/broker.xml
	sed -i'' -e "s/<max-size-bytes>-1/<max-size-bytes>$MAX_SIZE_BYTES/ " $AMQ_MASTER_HOME/etc/broker.xml

	sed -i'' -e "/<address-setting match=\"#\">/ a \            <redistribution-delay>$REDISTRIBUTION_DELAY</redistribution-delay> \n\
	 \   <redelivery-delay-multiplier>$REDELIVERY_DELAY_MULTIPLIER</redelivery-delay-multiplier> \n\
	 \   <max-redelivery-delay>$MAX_REDELIVERY_DELAY</max-redelivery-delay> \n\
	 \   <expiry-delay>$EXPIRY_DELAY</expiry-delay> \n\
	 \   <max-delivery-attempts>$MAX_DELIVERY_ATTEMPTS</max-delivery-attempts> \n\
	 \   <slow-consumer-policy>NOTIFY</slow-consumer-policy> \n\
	 \   <slow-consumer-check-period>10</slow-consumer-check-period> \n\
	 \   <default-queue-routing-type>ANYCAST</default-queue-routing-type> \n\
	 \   <slow-consumer-threshold>10</slow-consumer-threshold> \n\
	 \   <page-size-bytes>$PAGE_SIZE_BYTES</page-size-bytes> \n\
	 \   <page-max-cache-size>$PAGE_MAX_CACHE_SIZE</page-max-cache-size> \n\
	 \   <auto-delete-jms-queues>$AUTO_DELETE_QUEUES</auto-delete-jms-queues> \n\
	 \   <auto-delete-queues>$AUTO_DELETE_QUEUES</auto-delete-queues> \n\
	 \ " $AMQ_MASTER_HOME/etc/broker.xml
}

config_default_dlq () {
	#Set limits on DLQ
	echo "  - Set limits on DLQ"
	sed -i'' -e "/<address-settings>/ a \ \n         <address-setting match=\"DLQ\"> \n            <max-size-bytes>8Mb</max-size-bytes> \n            <page-size-bytes>1Mb</page-size-bytes>          \n            <page-max-cache-size>1</page-max-cache-size>          \n            <address-full-policy>PAGE</address-full-policy> \n         </address-setting>"  $AMQ_MASTER_HOME/etc/broker.xml
}

config_default_expiry_q () {
	#Set limits on ExpiryQueue
	echo "  - Set limits on ExpiryQueue"
	sed -i'' -e "/<address-settings>/ a \ \n         <address-setting match=\"ExpiryQueue\"> \n            <max-size-bytes>8Mb</max-size-bytes> \n            <page-size-bytes>1Mb</page-size-bytes>          \n            <page-max-cache-size>1</page-max-cache-size>          \n            <address-full-policy>PAGE</address-full-policy> \n         </address-setting>"  $AMQ_MASTER_HOME/etc/broker.xml
}


create_user () {
	# Create user 
	echo "  -Creating user amq_dev_poc_user "
	echo
	sh $AMQ_MASTER_HOME/bin/artemis user add --user $AMQ_ADMIN_USER --password $AMQ_ADMIN_PASSWORD --user-command-user $AMQ_USER_USERNAME --user-command-password $AMQ_USER_PASSWORD --role $AMQ_USER_ROLE_SEND,$AMQ_USER_ROLE_RECIEVE,$AMQ_USER_ROLE_MANAGE
	echo
}

producer_test () {
	sh $AMQ_MASTER_HOME/bin/artemis producer --user $AMQ_USER_USERNAME --password $AMQ_USER_PASSWORD --destination demo.helloworld --message-count 100
}

add_console_access_to_user () {
	# Adding additional role to user 
	echo "  -Adding additional role to user "
	echo
	sh $AMQ_MASTER_HOME/bin/artemis user reset --user $AMQ_ADMIN_USER --password $AMQ_ADMIN_PASSWORD --user-command-user $AMQ_USER_USERNAME --user-command-password $AMQ_USER_PASSWORD --role $AMQ_USER_ROLE_SEND,$AMQ_USER_ROLE_RECIEVE,$AMQ_USER_ROLE_MANAGE,$HAWTIO_ADMIN_ROLE
	echo
}

create_linux_service () {
	# Create Linux Service
	echo "  -Creating Linux Service "
	echo


	/bin/cat <<EOM >$AMQ_SERVICE_FILE
[Unit]
Description=AMQ Broker
After=syslog.target network.target

[Service]
ExecStart="$AMQ_MASTER_HOME/bin/artemis run"
Restart=on-failure
User=amq-broker
Group=amq-broker
Restart=always
StartLimitInterval=200
StartLimitBurst=5
RestartSec=50

# A workaround for Java signal handling
SuccessExitStatus=143

[Install]
WantedBy=multi-user.target
EOM

sudo systemctl enable "$AMQ_SERVICE_NAME"
sudo systemctl start "$AMQ_SERVICE_NAME"

}

create_configured_broker_instance () {
	create_standalone_broker
	update_broker_persistance_location
	allow_console_access
	granting_custom_roles
	allow_hawtio_access
	enable_jmx_external_access
	enable_config_reload
	set_default_address_setting_attributes
	config_default_dlq
	config_default_expiry_q

	echo "  - Start up AMQ Master in the background"
	sh $AMQ_MASTER_HOME/bin/artemis-service start --verbose

	sleep 5
	
	COUNTER=5
	#===Test if the broker is ready=====================================
	echo "  - Testing broker,retry when not ready"
	while true; do
		if [ $(sh $AMQ_MASTER_HOME/bin/artemis-service status | grep "running" | wc -l ) -ge 1 ]; then
		    break
		fi

		if [  $COUNTER -le 0 ]; then
			echo ERROR, while starting broker, please check your settings.
			break
		fi
		let COUNTER=COUNTER-1
		sleep 2
	done
	#===================================================================
}


case "$1" in
  (create_amq_broker) 
    create_configured_broker_instance
    exit 0
    ;;
  (create_user)
    create_user
    exit 0
    ;;
  (add_console_access_to_user)
    add_console_access_to_user
    exit 0
    ;;
  (producer_test)
    producer_test
    exit 0
    ;;
  (create_linux_service)
    create_linux_service
    exit 0
    ;;
  (*)
    echo "#==================================================================="
    echo "Hello to setting up AMQ Broker 7 script"
	echo "This script is developed by Raif Ahmed rahmed@redhat.com, you need help just let me know."
	echo "Usage: $0 {create_amq_broker|create_user|add_console_access_to_user|producer_test}"
	echo "   create_amq_broker : create a broker instance"
	echo "   create_user : create messaging user with snd_poc_role,rcv_poc_role,mng_poc_role which allows you to send, recieve & manage"
	echo "   add_console_access_to_user : Allow user to have access to Console, it use user created in create_user step"
	echo "   create_linux_service : Create a Linux Service to manage the AMQ 
	echo "Green & Clean .. Deal"
	echo "===================================================================#"
    exit 1
    ;;
esac
