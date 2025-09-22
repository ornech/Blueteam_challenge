<?php
$_DVWA = array();
$_DVWA[ 'db_server' ]   = getenv('MYSQL_HOST') ?: 'lab3_mariadb';
$_DVWA[ 'db_database' ] = getenv('MYSQL_DATABASE') ?: 'dvwa';
$_DVWA[ 'db_user' ]     = getenv('MYSQL_USER') ?: 'app';
$_DVWA[ 'db_password' ] = getenv('MYSQL_PASSWORD') ?: 'vulnerables';
$_DVWA[ 'default_security_level' ] = 'low';
$_DVWA[ 'default_phpids_level' ] = 'disabled';
$_DVWA[ 'default_phpids_verbose' ] = 'false';
?>
