#!/bin/bash

#---------------- Comprueba existencia de parametros -------------------
	if [ $# -ne 4 ]; then
		echo $0: Falta indicar NumeroServicio o NombreServicio o IPFailover -u opcionalmente NombreNube-
		exit 1
	fi

#---------------- Variables -------------------
	NombreNube=nube
	NumeroServicio=$1
	NombreServicio=$2
	Failover=$3
	NombreNube=$4

#---------------- Procede-------------------
	service apache2 stop
	
	sed -i "s|10.10.99.230|10.10.$NumeroServicio.230|g" /etc/network/interfaces
	sed -i "s|10.10.99.1|10.10.$NumeroServicio.1|g" /etc/network/interfaces
	
	sed -i "s|owncloud|$NombreServicio|g" /etc/hostname
	sed -i "s|owncloud|$NombreServicio|g" /etc/hosts
	
	sed -i "s|servicios.puntogalicia.com|$NombreNube.$NombreServicio|g" /etc/apache2/sites-enabled/000-default.conf
	sed -i "s|servicios.puntogalicia.com|$NombreNube.$NombreServicio|g" /etc/apache2/sites-enabled/000-default.conf
	
	sed -i "s|servicios.puntogalicia.com|$NombreNube.$NombreServicio|g" /etc/apache2/sites-enabled/owncloud-self-signed-ssl.conf
	
	sudo -u www-data sed -i "s|10.10.99.230|10.10.$NumeroServicio.230|g" /var/www/owncloud/config/config.php
	sudo -u www-data sed -i "s|212.129.39.185|$Failover|g" /var/www/owncloud/config/config.php
	sudo -u www-data sed -i "s|servicios.puntogalicia.com|$NombreNube.$NombreServicio|g" /var/www/owncloud/config/config.php
	sudo -u www-data sed -i "s|servicios.puntogalicia.com|$NombreNube.$NombreServicio|g" /var/www/owncloud/config/config.php
	
	service apache2 start
