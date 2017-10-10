#!/bin/sh

INITLOCK="/var/init.lock"
APPPATH="/var/www/app"

if [ -z "$INITSCRIPT" ] ; then
	INITSCRIPT="$APPPATH/init.sh"
fi
if [ -z "$STARTSCRIPT" ] ; then
	STARTSCRIPT="$APPPATH/start.sh"
fi

USER="www-data"
if [ ! -z "$USER_ID" -a ! -z "$GROUP_ID" ] ; then
	echo "Switching to user"
	USER="user"
	deluser "$USER"
	delgroup "$USER"
	addgroup --gid "$GROUP_ID" "$USER"
	adduser --disabled-password --disabled-login --no-create-home --system --uid "$USER_ID" --gid "$GROUP_ID" "$USER"
fi

#
# Set a default value for a variable if it is currently empty as defined by
# test -z "$VARIABLE_NAME"
#
# Parameters
# - $1 - Name of the variable for which a default value should be applier
# - $2 - Default value which should be set if the variable is empty
setDefault() {
	VARIABLE_NAME="$1"
	VARIABLE_DEFAULT_VALUE="$2"
	VARIABLE_VALUE=

	if eval "test -z \${"$VARIABLE_NAME"}" ; then
		eval "$VARIABLE_NAME=$VARIABLE_DEFAULT_VALUE"
	fi
}

setDefault 'PHP_MAX_CHILDREN' 100
setDefault 'PHP_START_SERVERS' 20
setDefault 'PHP_MIN_SPARE_SERVERS' 10
setDefault 'PHP_MAX_SPARE_SERVERS' 20
setDefault 'PHP_MEMORY_LIMIT' 128M
setDefault 'PHP_POST_MAX_SIZE' 32M
setDefault 'PHP_UPLOAD_MAX_FILESIZE' 32M
setDefault 'NGINX_CLIENT_MAX_BODY_SIZE' 32m

sed -e "s/%%USER%%/$USER/" /opt/config/nginx.conf.tpl > /etc/nginx/nginx.conf
sed \
	-e "s/%%USER%%/$USER/" \
	-e "s/%%PHP_MAX_CHILDREN%%/$PHP_MAX_CHILDREN/" \
	-e "s/%%PHP_START_SERVERS%%/$PHP_START_SERVERS/" \
	-e "s/%%PHP_MIN_SPARE_SERVERS%%/$PHP_MIN_SPARE_SERVERS/" \
	-e "s/%%PHP_MAX_SPARE_SERVERS%%/$PHP_MAX_SPARE_SERVERS/" \
	-e "s/%%PHP_MEMORY_LIMIT%%/$PHP_MEMORY_LIMIT/" \
	-e "s/%%PHP_POST_MAX_SIZE%%/$PHP_POST_MAX_SIZE/" \
	-e "s/%%PHP_UPLOAD_MAX_FILESIZE%%/$PHP_UPLOAD_MAX_FILESIZE/" \
  	/opt/config/www.conf.tpl > /etc/php/7.0/fpm/pool.d/www.conf

###############################################################################
# ensure the storage is writable by changing its user to the one running nginx
# and php-fpm
#
# Environment: STORAGE_REOWN_MODE decides how this is done
# - default / empty: Start the changing process int he foreground
# - background: Start the changing process in the background
# - none: Do nont change the ownership of the storage
###############################################################################
own_storage() {
	echo Started reowning storage
	for STORAGE in "${APPPATH}/storage" "${APPPATH}/app/storage" \
		"${APPPATH}/bootstrap/cache" ; do
	if [ -d $STORAGE ] ; then
		echo Making $STORAGE writable
		#chmod -R 777 $STORAGE
		chown -R $USER.$USER $STORAGE
	else
		echo Storage $STORAGE not found
	fi
done
echo Finished reowning storage
}

case "$STORAGE_REOWN_MODE" in
	background)
		own_storage &
		;;
	none)
		echo "Not reonwing storage."
		;;
	*)
		own_storage
		;;
esac

if [ x"$SERVER_URL" = x"" ] ; then
	SERVER_URL=localhost
fi

if [ ! -z "$CACHE_DIRECTORY" ] ; then
	if [ ! -d "$CACHE_DIRECTORY" ] ; then
		echo "Creating Cache Directory"
		mkdir -p "$CACHE_DIRECTORY"
	fi
	echo "Setting Ownership for Cache directory $CACHE_DIRECTORY"
	chown -R $USER.$USER "$CACHE_DIRECTORY"
	echo "Setting permissions for Cache directory $CACHE_DIRECTORY"
	chmod -R 770 "$CACHE_DIRECTORY"
fi

echo Creating NGINX Configuration
echo "Setting Server Url to $SERVER_URL"
for FILEPATH in /etc/nginx/conf.template.d/*
do FILENAME=$(basename $FILEPATH | sed -e 's/\.tpl//')
sed \
	-e 's/<SERVER_URL>/'$SERVER_URL'/g' \
	-e 's/<CLIENT_MAX_BODY_SIZE>/'$NGINX_CLIENT_MAX_BODY_SIZE'/g' \
		"$FILEPATH" > "/etc/nginx/conf.d/$FILENAME"
done

# Check MySQL Connection
if [ "$DB_HOST" = "" -o "$DB_USERNAME" = "" -o "$DB_PASSWORD" = "" ]
then
	echo "DB_HOST, DB_USERNAME or DB_PASSWORD not set, continueing without waiting for database."
	echo "Please set DB_HOST DB_USERNAME and DB_PASSWORD to enable database wait"
else
	echo "Waiting for Database connection on $DB_HOST"
	mysql -h $DB_HOST -u $DB_USERNAME "--password=$DB_PASSWORD" -e exit
	while [ "$?" != "0" ]
	do echo "Waiting 5s until next try to"
		sleep 5s
		mysql -h $DB_HOST -u $DB_USERNAME "--password=$DB_PASSWORD" -e exit
	done
fi

# This command causes the script to fail if any command exits with a status != 0
# In effect if any command fails then the container will stop - a visual
# indication that something has gone wrong
set -e

ARTISAN="${APPPATH}/artisan "

if [ -f $ARTISAN ] ; then
	echo Taking Application into maintenance mode
	php $ARTISAN down
else
	echo "Artisan not found at $ARTISAN: skipping maintenance mode"
fi

# Do not start fpm if NO_FPM was set
# This is used when the user wants to provide a different fpm version and mount
# the socket to /var/run/php/php-fpm.sock via volumes_from
if [ -z "$NO_FPM" ] ; then
	echo Starting PHP7 fpm
	/etc/init.d/php7.0-fpm start
fi

#
# Run INITSCRIPT if the file $INITLOCK does not exist yet.
# - Then create $INITLOCK
# -> Should only be run once per container.
#
if [ ! -f "$INITLOCK" ] ; then

	if [ -f "$INITSCRIPT" ] ; then
		$INITSCRIPT
	fi

	echo "The existance of this files prevents the INITSCRIPT to be run." > "$INITLOCK"
fi

if [ -f "$STARTSCRIPT" ] ; then
	$STARTSCRIPT
fi

echo Starting NGINX
nginx -g "daemon off;" &

if [ -f $ARTISAN ] ; then
	if [ -z "$NO_MIGRATE" ] ; then
		echo Migrating
		php ${APPPATH}/artisan migrate --no-interaction --force
	fi

	if [ -z "$NO_SEED" ] ; then
		echo Seeding
		php ${APPPATH}/artisan db:seed --no-interaction --force
	fi

	echo Taking Application out of maintenance mode
	php ${APPPATH}/artisan up
else
	echo "Artisan not found at $ARTISAN: skipping migrate and seed"
fi


echo "Entering main-wait for the webserver"
wait

echo "Webserver has stopped"
