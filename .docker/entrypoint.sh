#!/bin/bash

echo -e "$(getent hosts host.docker.internal | awk '{ print $1 }')\tpgsql" | tee -a /etc/hosts >/dev/null

# BEGIN: xDebug setup
if [ "${XDEBUG_ENABLED}" = "true" ]; then
  cp /home/xdebug/xdebug-on.ini /usr/local/etc/php/conf.d/xdebug.ini
else
  cp /home/xdebug/xdebug-off.ini /usr/local/etc/php/conf.d/xdebug.ini
fi
# END: xDebug setup

su www-data -s /bin/bash -c "php ${PROJECT_ROOT}/artisan storage:link"

supervisord -c /etc/supervisor/supervisord.conf -n
