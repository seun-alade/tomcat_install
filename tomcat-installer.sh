#!/bin/bash

# Exit on any error
set -e

# Variables
TOMCAT_VERSION="10.1.34"
TOMCAT_USER="tomcat"
TOMCAT_GROUP="tomcat"
TOMCAT_INSTALL_DIR="/opt/tomcat"
TOMCAT_SERVICE_FILE="/etc/systemd/system/tomcat.service"
JAVA_HOME="/usr/lib/jvm/java-1.11.0-openjdk-amd64"

# Create a Tomcat system user
sudo useradd -m -d $TOMCAT_INSTALL_DIR -U -s /bin/false $TOMCAT_USER

# Update system and install Java
sudo apt update
sudo apt install default-jdk -y
java -version

# Download and extract Tomcat
cd /tmp
wget https://dlcdn.apache.org/tomcat/tomcat-10/v$TOMCAT_VERSION/bin/apache-tomcat-$TOMCAT_VERSION.tar.gz
sudo tar xzvf apache-tomcat-$TOMCAT_VERSION.tar.gz -C $TOMCAT_INSTALL_DIR --strip-components=1

# Grant ownership to the tomcat user
sudo chown -R $TOMCAT_USER:$TOMCAT_GROUP $TOMCAT_INSTALL_DIR
sudo chmod -R u+x $TOMCAT_INSTALL_DIR/bin

# Configure Tomcat users
cat <<EOL | sudo tee $TOMCAT_INSTALL_DIR/conf/tomcat-users.xml
<tomcat-users>
    <role rolename="manager-gui" />
    <user username="manager" password="manager_password" roles="manager-gui" />
    <role rolename="admin-gui" />
    <user username="admin" password="admin_password" roles="manager-gui,admin-gui" />
</tomcat-users>
EOL

# Remove restrictions for Manager and Host Manager pages
sudo sed -i '/<Valve className=/ s/^/<!-- /' $TOMCAT_INSTALL_DIR/webapps/manager/META-INF/context.xml
sudo sed -i '/allow=/ s/$/ -->/' $TOMCAT_INSTALL_DIR/webapps/manager/META-INF/context.xml
sudo sed -i '/<Valve className=/ s/^/<!-- /' $TOMCAT_INSTALL_DIR/webapps/host-manager/META-INF/context.xml
sudo sed -i '/allow=/ s/$/ -->/' $TOMCAT_INSTALL_DIR/webapps/host-manager/META-INF/context.xml

# Create the Tomcat systemd service file
cat <<EOL | sudo tee $TOMCAT_SERVICE_FILE
[Unit]
Description=Tomcat
After=network.target

[Service]
Type=forking

User=$TOMCAT_USER
Group=$TOMCAT_GROUP

Environment="JAVA_HOME=$JAVA_HOME"
Environment="JAVA_OPTS=-Djava.security.egd=file:///dev/urandom"
Environment="CATALINA_BASE=$TOMCAT_INSTALL_DIR"
Environment="CATALINA_HOME=$TOMCAT_INSTALL_DIR"
Environment="CATALINA_PID=$TOMCAT_INSTALL_DIR/temp/tomcat.pid"
Environment="CATALINA_OPTS=-Xms512M -Xmx1024M -server -XX:+UseParallelGC"

ExecStart=$TOMCAT_INSTALL_DIR/bin/startup.sh
ExecStop=$TOMCAT_INSTALL_DIR/bin/shutdown.sh

RestartSec=10
Restart=always

[Install]
WantedBy=multi-user.target
EOL

# Reload systemd and start Tomcat service
sudo systemctl daemon-reload
sudo systemctl start tomcat
sudo systemctl status tomcat
sudo systemctl enable tomcat

# Allow port 8080 through the firewall
sudo ufw allow 8080

# Display public IP address
curl ifconfig.io

echo "Tomcat installation and configuration completed successfully."
