#!/bin/bash
## Tech and Me ## - ©2016, https://www.techandme.se/
# Tested on Ubuntu Server 14.04

#---------------- Comprueba existencia de parametro -------------------
if [ $# -ne 1 ]; then
    echo $0: Falta indicar la versión - 8.2.x -
    exit 1
fi

#Variables
	OCVERSION=$1
	SCRIPTS=/root/00-Scripts # OJO - modificado
	LOGS=/root/00-Scripts/logs # OJO - añadido
	BACKUP=/var/www/backup # OJO - modificado a la partición montada en /var/www con más capacidad para servidores en producción
	OCPATH=/var/www/owncloud
	DATA=/var/www/owncloud/data # OJO - modificado
	BASE=/var/www # OJO - añadido
	SECURE="$SCRIPTS/fixpermissions.sh"
	SHARED="https://raw.githubusercontent.com/Maldita/OwnConfig/OC/8.2/" # OJO - modificado
	THEME_NAME=""
	NEW_VERSION="https://download.owncloud.org/community/owncloud-$OCVERSION.tar.bz2"
	FILES_BACKUP=$LOGS/"01-DatosSalvados.log" # OJO - añadido
	FILES_NEW=$LOGS/"02-DatosNuevaVersion.log" # OJO - añadido
	FILES_RESTORE=$LOGS/"03-DatosRestaurados.log" # OJO - añadido
	UPDATE_RESULT=$LOGS/"04-ResultadoActualizacion.log" # OJO - añadido

# Provisional # OJO - añadido apartado
	mkdir $BACKUP
	mkdir $LOGS
	chown -R www-data:root /$BACKUP
	chmod -R 770 $BACKUP

# Must be root
	[[ $(id -u) -eq 0 ]] || { echo "Must be root to run script, in Ubuntu type: sudo -i"; exit 1; }

# Set secure permissions
	if [ -f $SECURE ];
		then
		        echo "Script exists"
		else
		        mkdir -p $SCRIPTS
		        wget $SHARED/fixpermissions.sh -P $SCRIPTS
	fi

# System Upgrade
	apt-get update
	aptitude full-upgrade -y
	clear # OJO - añadido

# Enable maintenance mode
# echo "Manteinance mode ON" # OJO - añadido - Innecesario
	sudo -u www-data php $OCPATH/occ maintenance:mode --on

# Stop Apache # OJO - Añadido todo el apartado
	echo "Stopping Apache server"
	service apache2 stop

# Backup data
	echo "Realizando Copia de Seguridad de data y themes"
	touch $FILES_BACKUP # OJO - añadido
	#rsync -Aaxv --info=progress2 $DATA $BACKUP | tee -a $FILES_BACKUP # OJO - modificado - añadido parámetro "v" para aumentar salida verbose a log
	mv $OCPATH/data/ $BACKUP/data/ #nueva versión para backup de data, para hacer más rapido el proceso. Sólo apto si se hace snapshot de seguridad.Arriesgado.
	mkdir $DATA #Debe existir un directorio vacio de data para que la comprobación posterior no falle.
	rsync -Aaxv --info=progress2 $OCPATH/config $BACKUP | tee -a $FILES_BACKUP # OJO - modificado
	rsync -Aaxv --info=progress2 $OCPATH/themes $BACKUP | tee -a $FILES_BACKUP # OJO - modificado
	#rsync -Aaxv $OCPATH/apps $BACKUP >> $FILES_BACKUP # OJO - modificado # OJO, innecesario si no hay apps 3rd party, modificadas o de GIT
	if [[ $? > 0 ]]
		then
		    echo "Backup was not OK. Please check $BACKUP and see if the folders are backed up properly"
		    exit
		else
				echo -e "\e[32m"
		    echo "Backup OK!"
		    echo -e "\e[0m"
	fi
	
	# Download new version
		wget $NEW_VERSION -P $BACKUP
		
		if [ -f $BACKUP/owncloud-$OCVERSION.tar.bz2 ];
			then
			        echo "$BACKUP/owncloud-latest.tar.bz2 exists"
			else
			        echo "Aborting,something went wrong with the download"
				exit 1
		fi

	if [ -d $OCPATH/config/ ]; 
		then
		        echo "config/ exists" 
		else
		        echo "Something went wrong with backing up your old ownCloud instance, please check in $BACKUP if config/ folder exist."
		   	exit 1
	fi

	if [ -d $OCPATH/themes/ ]; 
		then
		        echo "themes/ exists" 
		else
		        echo "Something went wrong with backing up your old ownCloud instance, please check in $BACKUP if themes/ folder exist."
		   	exit 1
	fi

	#if [ -d $OCPATH/apps/ ]; # OJO, innecesario si no hay apps 3rd party, modificadas o de GIT
		#then
		        #echo "apps/ exists" 
		#else
		        #echo "Something went wrong with backing up your old ownCloud instance, please check in $BACKUP if apps/ folder exist."
		   	#exit 1
	#fi

	if [ -d $DATA/ ]; 
		then
		        echo "data/ exists" && sleep 2
		        rm -rf $OCPATH
		        tar -xvf $BACKUP/owncloud-$OCVERSION.tar.bz2 -C $BASE >> $FILES_NEW # OJO - modificado en ruta de destino y opciones tar
		        rm $BACKUP/owncloud-$OCVERSION.tar.bz2
		        touch $FILES_RESTORE # OJO - añadido
		        cp -R $BACKUP/themes $OCPATH/ | tee -a $FILES_RESTORE && rm -rf $BACKUP/themes # OJO - modificado #150717 Descomentado, aparentemente estaba mal comentado, hace falta para restaurar el tema
			mv $BACKUP/data/ $OCPATH/data/
		        #cp -Rv $BACKUP/data $DATA | tee -a $FILES_RESTORE && rm -rf $BACKUP/data # OJO - modificado #150717 Aparentemente obsoleto, al mover DATA y no copiarlo ya no existe en es ruta en este momento
		        cp -R $BACKUP/config $OCPATH/ | tee -a $FILES_RESTORE  && rm -rf $BACKUP/config # OJO - modificado  
		        # cp -R $BACKUP/apps $OCPATH/  >> $FILES_RESTORE  && rm -rf $BACKUP/apps # OJO - modificado, solo se puede hacer para 3party apps, modificadas o de git - Importante no tocar
		        bash $SECURE
		        # Start Apache # OJO - Añadido todo el apartado
		        echo "Starting Apache server"
		        service apache2 start
		        # echo "Manteinance mode OFF" # OJO - añadido - Innecesario
		        sudo -u www-data php $OCPATH/occ maintenance:mode --off
		        sudo -u www-data php $OCPATH/occ upgrade
		else
		        echo "Something went wrong with backing up your old ownCloud instance, please check in $BACKUP if data/ folder exist."
		   	exit 1
	fi

# Enable Apps
	#sudo -u www-data php $OCPATH/occ app:enable calendar
	#sudo -u www-data php $OCPATH/occ app:enable contacts
	#sudo -u www-data php $OCPATH/occ app:enable documents
	sudo -u www-data php $OCPATH/occ app:enable external #OJO - Comprobar que no tengamos que activar alguna más por defecto

# Disable maintenance mode
	# sudo -u www-data php $OCPATH/occ maintenance:mode --off #OJO - modificado por aparentemente redundante. Si falla el proceso queda con manteinance activado para evitar problemas si usuarios acceden

# Increase max filesize (expects that changes are made in /etc/php5/apache2/php.ini)
# Here is a guide: https://www.techandme.se/increase-max-file-size/
	VALUE="# php_value upload_max_filesize 2000M" # OJO - Se aplica solo si el valor está por defecto a 512M o 1000M...
	if grep -Fxq "$VALUE" $OCPATH/.htaccess
		then
		        echo "Upload value correct"
		else
			# OJO - en .htacces están comentados con "#", buscar razones y ver php.ini...
		        sed -i 's/  php_value upload_max_filesize 513M/# php_value upload_max_filesize 2000M/g' $OCPATH/.htaccess
		        sed -i 's/  php_value post_max_size 513M/# php_value post_max_size 2000M/g' $OCPATH/.htaccess
		        sed -i 's/  php_value memory_limit 512M/# php_value memory_limit 2000M/g' $OCPATH/.htaccess
		      	
		      	sed -i 's/  php_value upload_max_filesize 513M/# php_value upload_max_filesize 2000M/g' $OCPATH/.htaccess
		        sed -i 's/  php_value post_max_size 513M/# php_value post_max_size 2000M/g' $OCPATH/.htaccess
		        sed -i 's/  php_value memory_limit 512M/# php_value memory_limit 2000M/g' $OCPATH/.htaccess
	fi

# Set $THEME_NAME
	VALUE2="$THEME_NAME"
	if grep -Fxq "$VALUE2" $OCPATH/config/config.php
		then
		        echo "Theme correct"
		else
		        sed -i "s|'theme' => '',|'theme' => '$THEME_NAME',|g" $OCPATH/config/config.php
		        echo "Theme set"
	fi

# Repair
	sudo -u www-data php $OCPATH/occ maintenance:repair

# Cleanup un-used packages
	sudo apt-get autoremove -y
	sudo apt-get autoclean

# Update GRUB, just in case
	sudo update-grub

# Write to log
	touch $UPDATE_RESULT #OJO - modificada ruta
	echo "OWNCLOUD UPDATE success-$(date +"%Y%m%d")" >> $UPDATE_RESULT
	echo ownCloud version:
	sudo -u www-data php $OCPATH/occ status
	sleep 3

# Set secure permissions again
	bash $SECURE

# Un-hash this if you want the system to reboot
	# sudo reboot

exit 0
