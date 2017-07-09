#!/bin/bash
set -e

CONFIG_PATH=/data/options.json

PLAIN=$(jq --raw-output ".plain" $CONFIG_PATH)
SSL=$(jq --raw-output ".ssl" $CONFIG_PATH)
LOGINS=$(jq --raw-output ".logins | length" $CONFIG_PATH)
ANONYMOUS=$(jq --raw-output ".anonymous" $CONFIG_PATH)
KEYFILE=$(jq --raw-output ".keyfile" $CONFIG_PATH)
CERTFILE=$(jq --raw-output ".certfile" $CONFIG_PATH)
BRIDGES=$(jq --raw-output ".bridges | length" $CONFIG_PATH)

PLAIN_CONFIG="
listener 1883
"

SSL_CONFIG="
listener 8883
cafile /ssl/$CERTFILE
certfile /ssl/$CERTFILE
keyfile /ssl/$KEYFILE
"

# Add plain configs
if [ "$PLAIN" == "true" ]; then
    echo "$PLAIN_CONFIG" >> /etc/mosquitto.conf
fi

# Add ssl configs
if [ "$SSL" == "true" ]; then
    echo "$SSL_CONFIG" >> /etc/mosquitto.conf
fi

# Allow anonymous connections
if [ "$ANONYMOUS" == "false" ]; then
    sed -i "s/#allow_anonymous/allow_anonymous/g" /etc/mosquitto.conf
fi

# Generate user data
if [ "$LOGINS" -gt "0" ]; then
    sed -i "s/#password_file/password_file/g" /etc/mosquitto.conf
    rm -f /data/users.db || true
    touch /data/users.db

    for (( i=0; i < "$LOGINS"; i++ )); do
        USERNAME=$(jq --raw-output ".logins[$i].username" $CONFIG_PATH)
        PASSWORD=$(jq --raw-output ".logins[$i].password" $CONFIG_PATH)

        mosquitto_passwd -b /data/users.db "$USERNAME" "$PASSWORD"
    done
fi

touch /data/debug0
# Load external config files
if [ "$BRIDGES" -gt "0" ]; then
    sed -i "s/#include_dir/include_dir/g" /etc/mosquitto.conf
	touch /data/debug1
	
	for (( i=0; i < "$BRIDGES"; i++ )); do
		touch /data/debug2
        CONNECTION=$(jq --raw-output ".bridges[$i].connection" $CONFIG_PATH)
        ADDRESS=$(jq --raw-output ".bridges[$i].address" $CONFIG_PATH)
		USERNAME=$(jq --raw-output ".bridges[$i].remote_username" $CONFIG_PATH)
		PASSWORD=$(jq --raw-output ".bridges[$i].remote_password" $CONFIG_PATH)
		CLIENTID=$(jq --raw-output ".bridges[$i].clientid" $CONFIG_PATH)
		PRIVATE=$(jq --raw-output ".bridges[$i].try_private" $CONFIG_PATH)
		TYPE=$(jq --raw-output ".bridges[$i].start_type" $CONFIG_PATH)
		TOPIC=$(jq --raw-output ".bridges[$i].topic" $CONFIG_PATH)

		rm -f /data/"$CONNECTION".conf || true
        touch /data/"$CONNECTION".conf
		touch /data/debug3
		echo "connection $CONNECTION" >> /data/"$CONNECTION".conf
		echo "address $ADDRESS" >> /data/"$CONNECTION".conf
		echo "remote_username $USERNAME" >> /data/"$CONNECTION".conf
		echo "remote_password $PASSWORD" >> /data/"$CONNECTION".conf
		echo "clientid $CLIENTID" >> /data/"$CONNECTION".conf
		echo "try_private $PRIVATE" >> /data/"$CONNECTION".conf
		echo "start_type $TYPE" >> /data/"$CONNECTION".conf
		echo "topic $TOPIC" >> /data/"$CONNECTION".conf
		touch /data/debug4
    done
fi
touch /data/debug_end

# start server
exec mosquitto -c /etc/mosquitto.conf < /dev/null