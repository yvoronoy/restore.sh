#!/bin/bash
# Magento restore script
#
# You can use config file
# Create file in home directory .restore.conf
# Or in directory where restore.sh placed

export LC_CTYPE=C
export LANG=C

#Define variables
DBHOST=
TMP_DBHOST=
DBNAME=
TMP_DBNAME=
DBUSER=
TMP_DBUSER=
DBPASS=
TMP_DBPASS=
BASE_URL=
TMP_BASE_URL=
# DEV_TABLE_PREFIX=
# TMP_DEV_TABLE_PREFIX=

TABLE_PREFIX=
DBPREFIX=
CRYPT_KEY=
INSTALL_DATE=

FILENAME_CODE_DUMP=
FILENAME_DB_DUMP=
SQLDUMPFILE=

DEBUG_MODE=0
DEBUG_KEY=
DEBUG_VAL=

# Magento folders
MAGENTOROOT=./
LOCALXMLPATH=${MAGENTOROOT}app/etc/local.xml
MAGENTO_FOLDER_VAR=${MAGENTOROOT}var
MAGENTO_FOLDER_MEDIA=${MAGENTOROOT}media
MAGENTO_FOLDER_ETC=${MAGENTOROOT}app/etc

CONFIG_FILE_NAME=.restore.conf
CURRENT_DIR_NAME=$(basename $(pwd))
SCRIPT_OPTIONS=$1
FORCE_WITHOUT_CONFIG=0;
FORCE_RESTORE=0;
VERBOSE=


function initScriptOptions()
{
    case "${SCRIPT_OPTIONS}" in
    -?|--help )
        echo "Magento Restore script"
        echo "Usage: ${0} [option]"
        echo "    -?, --help            show available params for script"
        echo "    -w, --without-config  do not use config file data"
        echo "    -f, --force           install without check step"
        echo "    -r, --reconfigure     ReConfigure current magento instance"
        echo "    -c, --clean-install   Standard install procedure through CLI"
        echo ""
        echo "Your \"~/${CONFIG_FILE_NAME}\" file must be manually created in your home directory."
        echo ""
        echo "Missing entries are treated as empty strings."
        echo ""
        echo "In most cases, if the requested value is left blank on the command line then"
        echo "the corresponding value from the config file is used. In the special case"
        echo "of the DB name, If the DB name is empty in the config file and none is entered"
        echo "on the command line then the current working directory basename is used."
        echo "Digits are allowed as a DB name."
        echo ""
        echo "Sample \"~/${CONFIG_FILE_NAME}\":"
        echo "DBHOST=sparta-db"
        echo "DBNAME=rwoodbury_test"
        echo "DBUSER=rwoodbury"
        echo "DBPASS="
        echo "BASE_URL=http://sparta.corp.magento.com/dev/rwoodbury/"
        exit;;
    -w|--without-config )
        FORCE_WITHOUT_CONFIG=1;
        ;;
    -f|--force )
        FORCE_RESTORE=1
        ;;
    -c|--clean-install )
        MODE=clean-install
        ;;
    -r|--reconfigure )
        MODE=reconfigure
        ;;

    -h|--host )
        DBHOST=reconfigure
        ;;
    esac
}

function checkBackupFiles()
{
    getCodeDumpFilename
    if [ ! -f "$FILENAME_CODE_DUMP" ]
    then
        echo "Code dump absent"
        exit 1
    fi

    getDbDumpFilename
    if [ ! -f "$FILENAME_DB_DUMP" ]
    then
        echo "Db dump absent"
        exit 1
    fi
}

function getPathConfigFile()
{
    if [ -f ~/"${CONFIG_FILE_NAME}" ]
    then
        PATH_CONFIG_FILE=~/${CONFIG_FILE_NAME}
    else
        PATH_CONFIG_FILE="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"/${CONFIG_FILE_NAME}
    fi
}

function initVariables()
{
    getPathConfigFile

    # Read defaults from config file if it exists.
    if [ ${FORCE_WITHOUT_CONFIG} -ne 1 ] && [ -f "$PATH_CONFIG_FILE" ]
    then
        source ${PATH_CONFIG_FILE}
    fi

    echo -n "Enter DB host [${DBHOST}]: "
    read TMP_DBHOST
    if [ -n "$TMP_DBHOST" ]
    then
        DBHOST=$TMP_DBHOST
    fi

    if [ -z "$DBNAME" ]
    then
        DBNAME=$CURRENT_DIR_NAME
    fi
    echo -n "Enter DB name [${DBNAME}]: "
    read TMP_DBNAME
    if [ -n "$TMP_DBNAME" ]
    then
        DBNAME=$TMP_DBNAME
    fi

    echo -n "Enter DB user [${DBUSER}]: "
    read TMP_DBUSER
    if [ -n "$TMP_DBUSER" ]
    then
        DBUSER=$TMP_DBUSER
    fi

    echo -n "Enter DB user's password [${DBPASS}]: "
    read TMP_DBPASS
    if [ -n "$TMP_DBPASS" ]
    then
        DBPASS=$TMP_DBPASS
    fi

#   if [ "${DBNAME}" != "${CURRENT_DIR_NAME}" ]
#   then
#       DEV_TABLE_PREFIX="${CURRENT_DIR_NAME}_"
#   fi
#   echo -n "Enter developer table prefix [${DEV_TABLE_PREFIX}]: "
#   read TMP_DEV_TABLE_PREFIX
#   if [ -n "$TMP_DEV_TABLE_PREFIX" ]
#   then
#       DEV_TABLE_PREFIX=$TMP_DEV_TABLE_PREFIX
#   fi

    echo -n "Enter base url [${BASE_URL}]: "
    read TMP_BASE_URL
    if [ -n "$TMP_BASE_URL" ]
    then
        BASE_URL="${TMP_BASE_URL}"
    fi

    BASE_URL="${BASE_URL}${CURRENT_DIR_NAME}/"


    _prepareDbName;
    echo ""
    echo "Check parameters:"
    echo "DB host is: ${DBHOST}"
    echo "DB name is: ${DBNAME}"
    echo "DB user is: ${DBUSER}"
    echo "DB pass is: ${DBPASS}"
#   echo "Additional table prefix: ${DEV_TABLE_PREFIX}"
    echo "Full base url is: ${BASE_URL}"

    if [ ${FORCE_RESTORE} -eq 0 ]
    then
        echo -n "Continue? [Y/n]: "
        read CONFIRM

        case ${CONFIRM} in
            [Yy]|[Yy][Ee][Ss]) ;;
            [Nn]|[Nn][Oo]) echo "Interrupted by user, exiting..." && exit;;
        esac
    fi

    echo ""
}

function _prepareDbName()
{
    DBNAME=$(echo "$DBNAME" | sed "s/[^a-zA-Z0-9_]//g" | tr '[A-Z]' '[a-z]');
}

function getCodeDumpFilename()
{
	# TODO: more file types/endings
    FILENAME_CODE_DUMP=$(ls -1 *.tbz2 *.tar.bz2 2> /dev/null | head -n1)
    if [ "${FILENAME_CODE_DUMP}" == "" ]
    then
        FILENAME_CODE_DUMP=$(ls -1 *.tar.gz | grep -v 'logs.tar.gz' | head -n1)
    fi
    DEBUG_KEY="Code dump Filename"
    DEBUG_VAL=$FILENAME_CODE_DUMP
    debug
}

function getDbDumpFilename()
{
    FILENAME_DB_DUMP=$(ls -1 *.sql.gz | head -n1)
    DEBUG_KEY="DB dump Filename"
    DEBUG_VAL=$FILENAME_DB_DUMP
    debug
}

function createDb
{
    mysqladmin --force -h$DBHOST -u$DBUSER -p$DBPASS drop $DBNAME 2>/dev/null

    echo -n "Creating DB \"${DBNAME}\" - "
    mysqladmin -h$DBHOST -u$DBUSER -p$DBPASS create $DBNAME 2>/dev/null
    echo "OK"
}

function restoreDb()
{
    echo -n "Restoring DB from dump"

    if which pv > /dev/null
    then
        echo ":"
        pv ${FILENAME_DB_DUMP} | gunzip -c | gunzip -cf | sed -e 's/DEFINER[ ]*=[ ]*[^*]*\*/\*/' | mysql -h$DBHOST -u$DBUSER -p$DBPASS --force $DBNAME 2>/dev/null
    else
        echo -n " - "
        gunzip -c $FILENAME_DB_DUMP | gunzip -cf | sed -e 's/DEFINER[ ]*=[ ]*[^*]*\*/\*/' | mysql -h$DBHOST -u$DBUSER -p$DBPASS --force $DBNAME 2>/dev/null
        echo "OK"
    fi
}

function extractCode()
{
    echo -n "Extracting code - "

    EXTRACT_FILENAME=$FILENAME_CODE_DUMP
    extract

    find . -type f -exec chmod 664 {} \;
    find . -type d -exec chmod 775 {} \;
    mkdir -p $MAGENTO_FOLDER_VAR
    mkdir -p $MAGENTO_FOLDER_MEDIA
    chmod -R 02777 $MAGENTO_FOLDER_VAR $MAGENTO_FOLDER_MEDIA $MAGENTO_FOLDER_ETC

    PARAMNAME=table_prefix
    getLocalValue
    TABLE_PREFIX=${PARAMVALUE}

    PARAMNAME=date
    getLocalValue
    INSTALL_DATE=${PARAMVALUE}

    PARAMNAME=key
    getLocalValue
    CRYPT_KEY=${PARAMVALUE}

    echo "OK"
}

function extract()
{
	# Modern versions of tar can automatically choose the p
     if [ -f $EXTRACT_FILENAME ] ; then
         case $EXTRACT_FILENAME in
             *.tar.gz|*.tgz|*.tar.bz2|*.tbz2|*.tbz)   tar xf $EXTRACT_FILENAME;;
             *.gz)        gunzip -k $EXTRACT_FILENAME;;
             *.bz|*.bz2)  bunzip2 -k $EXTRACT_FILENAME;;
             *)           echo "'$EXTRACT_FILENAME' could not be extracted";;
         esac
     else
         echo "'$EXTRACT_FILENAME' is not a valid file"
     fi
}

function setupDbConfig()
{
    echo -n "Replacing DB values. - "

    SQLQUERY="UPDATE ${TABLE_PREFIX}core_config_data SET value = '${BASE_URL}' WHERE path IN ('web/secure/base_url', 'web/unsecure/base_url')"
    runMysqlQuery

    SQLQUERY="DELETE FROM ${TABLE_PREFIX}core_config_data WHERE path LIKE 'web/cookie/%'"
    runMysqlQuery

    SQLQUERY="DELETE FROM ${TABLE_PREFIX}core_config_data WHERE path IN ('web/unsecure/base_link_url', 'web/unsecure/base_skin_url', 'web/unsecure/base_media_url', 'web/unsecure/base_js_url')"
    runMysqlQuery

    SQLQUERY="DELETE FROM ${TABLE_PREFIX}core_config_data WHERE path IN ('web/secure/base_link_url', 'web/secure/base_skin_url', 'web/secure/base_media_url', 'web/secure/base_js_url')"
    runMysqlQuery

    SQLQUERY="DELETE FROM ${TABLE_PREFIX}core_config_data WHERE path IN ('web/secure/use_in_adminhtml')"
    runMysqlQuery

    SQLQUERY="DELETE FROM ${TABLE_PREFIX}core_config_data WHERE path LIKE 'admin/url/%'"
    runMysqlQuery


    SQLQUERY="SELECT user_id FROM ${TABLE_PREFIX}admin_user WHERE username = 'admin'";
    runMysqlQuery
    USER_ID=$(echo ${SQLQUERY_RESULT} | sed -e 's/^[a-zA-Z_]*//');

    if [ -z "$USER_ID" ]
    then
        SQLQUERY="SELECT user_id FROM ${TABLE_PREFIX}admin_user ORDER BY user_id ASC LIMIT 1";
        runMysqlQuery
        USER_ID=$(echo ${SQLQUERY_RESULT} | sed -e 's/^[a-zA-Z_]*//');
    fi

    SQLQUERY="UPDATE ${TABLE_PREFIX}admin_user SET password='eef6ebe8f52385cdd347d75609309bb29a555d7105980916219da792dc3193c6:6D', username='admin', is_active=1 WHERE user_id = ${USER_ID}";
    runMysqlQuery

    SQLQUERY="UPDATE ${TABLE_PREFIX}enterprise_admin_passwords SET expires = UNIX_TIMESTAMP() + (365 * 24 * 60 * 60) WHERE user_id = ${USER_ID}";
    runMysqlQuery

    echo "OK"
}

function updateLocalXml()
{
    echo -n "Updating local XML files. - "

    LOCALXML_PARAM_NAME=key
    LOCALXML_VALUE=${CRYPT_KEY}
    _updateLocalXmlParam

    LOCALXML_PARAM_NAME=date
    LOCALXML_VALUE=${INSTALL_DATE}
    _updateLocalXmlParam

    LOCALXML_PARAM_NAME=table_prefix
    LOCALXML_VALUE=${TABLE_PREFIX}
    _updateLocalXmlParam

    LOCALXML_PARAM_NAME=username
    LOCALXML_VALUE=${DBUSER}
    _updateLocalXmlParam

    LOCALXML_PARAM_NAME=password
    LOCALXML_VALUE=${DBPASS}
    _updateLocalXmlParam

    LOCALXML_PARAM_NAME=dbname
    LOCALXML_VALUE=${DBNAME}
    _updateLocalXmlParam

    LOCALXML_PARAM_NAME=host
    LOCALXML_VALUE=${DBHOST}
    _updateLocalXmlParam

    LOCALXML_PARAM_NAME=frontName
    LOCALXML_VALUE="admin"
    _updateLocalXmlParam

    echo "OK"
}

function _updateLocalXmlParam()
{
    sed "s/<${LOCALXML_PARAM_NAME}><\!\[CDATA\[.*\]\]><\/${LOCALXML_PARAM_NAME}>/<${LOCALXML_PARAM_NAME}><\!\[CDATA\[${LOCALXML_VALUE}\]\]><\/${LOCALXML_PARAM_NAME}>/" $LOCALXMLPATH > $LOCALXMLPATH.new
    mv -f $LOCALXMLPATH.new $LOCALXMLPATH
}

getLocalValue() {
    PARAMVALUE=$(sed -n -e "s/.*<$PARAMNAME><!\[CDATA\[\(.*\)\]\]><\/$PARAMNAME>.*/\1/p" ${LOCALXMLPATH} | head -n 1)
}

function runMysqlQuery()
{
    SQLQUERY_RESULT=$(mysql -h$DBHOST -u$DBUSER -p$DBPASS -D $DBNAME -e "${SQLQUERY}" 2>/dev/null);
}

function debug()
{
    if [ $DEBUG_MODE -eq 0 ]
    then
        return
    fi

    echo "KEY: ${DEBUG_KEY} VALUE: ${DEBUG_VAL}"
}

function getOrigHtaccess()
{
    cp ${MAGENTOROOT}.htaccess ${MAGENTOROOT}.htaccess.merchant
    cat << 'EOF' > .htaccess
############################################
## uncomment these lines for CGI mode
## make sure to specify the correct cgi php binary file name
## it might be /cgi-bin/php-cgi

#    Action php5-cgi /cgi-bin/php5-cgi
#    AddHandler php5-cgi .php

############################################
## GoDaddy specific options

#   Options -MultiViews

## you might also need to add this line to php.ini
##     cgi.fix_pathinfo = 1
## if it still doesn't work, rename php.ini to php5.ini

############################################
## this line is specific for 1and1 hosting

    #AddType x-mapp-php5 .php
    #AddHandler x-mapp-php5 .php

############################################
## default index file

    DirectoryIndex index.php

<IfModule mod_php5.c>

############################################
## adjust memory limit

#    php_value memory_limit 64M
    php_value memory_limit 256M
    php_value max_execution_time 18000

############################################
## disable magic quotes for php request vars

    php_flag magic_quotes_gpc off

############################################
## disable automatic session start
## before autoload was initialized

    php_flag session.auto_start off

############################################
## enable resulting html compression

    #php_flag zlib.output_compression on

###########################################
# disable user agent verification to not break multiple image upload

    php_flag suhosin.session.cryptua off

###########################################
# turn off compatibility with PHP4 when dealing with objects

    php_flag zend.ze1_compatibility_mode Off

</IfModule>

<IfModule mod_security.c>
###########################################
# disable POST processing to not break multiple image upload

    SecFilterEngine Off
    SecFilterScanPOST Off
</IfModule>

<IfModule mod_deflate.c>

############################################
## enable apache served files compression
## http://developer.yahoo.com/performance/rules.html#gzip

    # Insert filter on all content
    ###SetOutputFilter DEFLATE
    # Insert filter on selected content types only
    #AddOutputFilterByType DEFLATE text/html text/plain text/xml text/css text/javascript

    # Netscape 4.x has some problems...
    #BrowserMatch ^Mozilla/4 gzip-only-text/html

    # Netscape 4.06-4.08 have some more problems
    #BrowserMatch ^Mozilla/4\.0[678] no-gzip

    # MSIE masquerades as Netscape, but it is fine
    #BrowserMatch \bMSIE !no-gzip !gzip-only-text/html

    # Don't compress images
    #SetEnvIfNoCase Request_URI \.(?:gif|jpe?g|png)$ no-gzip dont-vary

    # Make sure proxies don't deliver the wrong content
    #Header append Vary User-Agent env=!dont-vary

</IfModule>

<IfModule mod_ssl.c>

############################################
## make HTTPS env vars available for CGI mode

    SSLOptions StdEnvVars

</IfModule>

<IfModule mod_rewrite.c>

############################################
## enable rewrites

    Options +FollowSymLinks
    RewriteEngine on

############################################
## you can put here your magento root folder
## path relative to web root

    #RewriteBase /magento/

############################################
## uncomment next line to enable light API calls processing

#    RewriteRule ^api/([a-z][0-9a-z_]+)/?$ api.php?type=$1 [QSA,L]

############################################
## rewrite API2 calls to api.php (by now it is REST only)

    RewriteRule ^api/rest api.php?type=rest [QSA,L]

############################################
## workaround for HTTP authorization
## in CGI environment

    RewriteRule .* - [E=HTTP_AUTHORIZATION:%{HTTP:Authorization}]

############################################
## TRACE and TRACK HTTP methods disabled to prevent XSS attacks

    RewriteCond %{REQUEST_METHOD} ^TRAC[EK]
    RewriteRule .* - [L,R=405]

############################################
## redirect for mobile user agents

    #RewriteCond %{REQUEST_URI} !^/mobiledirectoryhere/.*$
    #RewriteCond %{HTTP_USER_AGENT} "android|blackberry|ipad|iphone|ipod|iemobile|opera mobile|palmos|webos|googlebot-mobile" [NC]
    #RewriteRule ^(.*)$ /mobiledirectoryhere/ [L,R=302]

############################################
## always send 404 on missing files in these folders

    RewriteCond %{REQUEST_URI} !^/(media|skin|js)/

############################################
## never rewrite for existing files, directories and links

    RewriteCond %{REQUEST_FILENAME} !-f
    RewriteCond %{REQUEST_FILENAME} !-d
    RewriteCond %{REQUEST_FILENAME} !-l

############################################
## rewrite everything else to index.php

    RewriteRule .* index.php [L]

</IfModule>


############################################
## Prevent character encoding issues from server overrides
## If you still have problems, use the second line instead

    AddDefaultCharset Off
    #AddDefaultCharset UTF-8

<IfModule mod_expires.c>

############################################
## Add default Expires header
## http://developer.yahoo.com/performance/rules.html#expires

    ExpiresDefault "access plus 1 year"

</IfModule>

############################################
## By default allow all access

    Order allow,deny
    Allow from all

###########################################
## Deny access to release notes to prevent disclosure of the installed Magento version

    <Files RELEASE_NOTES.txt>
        order allow,deny
        deny from all
    </Files>

############################################
## If running in cluster environment, uncomment this
## http://developer.yahoo.com/performance/rules.html#etags

    #FileETag none
EOF

}

function getMediaOrigHtaccess()
{
    if [ ! -f "${MAGENTOROOT}get.php" ]
    then
        return;
    fi
    if [ -f "${MAGENTO_FOLDER_MEDIA}/.htaccess" ]
    then
        cp ${MAGENTO_FOLDER_MEDIA}/.htaccess ${MAGENTO_FOLDER_MEDIA}/.htaccess.merchant
    fi
    cat << 'EOF' > ${MAGENTO_FOLDER_MEDIA}/.htaccess
Options All -Indexes
<IfModule mod_php5.c>
php_flag engine 0
</IfModule>

AddHandler cgi-script .php .pl .py .jsp .asp .htm .shtml .sh .cgi
Options -ExecCGI

<IfModule mod_rewrite.c>

############################################
## enable rewrites

    Options +FollowSymLinks
    RewriteEngine on

############################################
## never rewrite for existing files
    RewriteCond %{REQUEST_FILENAME} !-f

############################################
## rewrite everything else to index.php

    RewriteRule .* ../get.php [L]
</IfModule>
EOF
}

function getOrigLocalXml()
{
    cp ${LOCALXMLPATH} ${LOCALXMLPATH}.merchant
    cat << 'EOF' > ${LOCALXMLPATH}
<?xml version="1.0"?>
<!--
/**
 * Magento
 *
 * NOTICE OF LICENSE
 *
 * This source file is subject to the Academic Free License (AFL 3.0)
 * that is bundled with this package in the file LICENSE_AFL.txt.
 * It is also available through the world-wide-web at this URL:
 * http://opensource.org/licenses/afl-3.0.php
 * If you did not receive a copy of the license and are unable to
 * obtain it through the world-wide-web, please send an email
 * to license@magentocommerce.com so we can send you a copy immediately.
 *
 * DISCLAIMER
 *
 * Do not edit or add to this file if you wish to upgrade Magento to newer
 * versions in the future. If you wish to customize Magento for your
 * needs please refer to http://www.magentocommerce.com for more information.
 *
 * @category   Mage
 * @package    Mage_Core
 * @copyright  Copyright (c) 2008 Irubin Consulting Inc. DBA Varien (http://www.varien.com)
 * @license    http://opensource.org/licenses/afl-3.0.php  Academic Free License (AFL 3.0)
 */
-->
<config>
    <global>
        <install>
            <date><![CDATA[]]></date>
        </install>
        <crypt>
            <key><![CDATA[]]></key>
        </crypt>
        <disable_local_modules>false</disable_local_modules>
        <resources>
            <db>
                <table_prefix><![CDATA[]]></table_prefix>
            </db>
            <default_setup>
                <connection>
                    <host><![CDATA[localhost]]></host>
                    <username><![CDATA[root]]></username>
                    <password><![CDATA[]]></password>
                    <dbname><![CDATA[magento]]></dbname>
                    <initStatements><![CDATA[SET NAMES utf8]]></initStatements>
                    <model><![CDATA[mysql4]]></model>
                    <type><![CDATA[pdo_mysql]]></type>
                    <pdoType><![CDATA[]]></pdoType>
                    <active>1</active>
                </connection>
            </default_setup>
        </resources>
        <session_save><![CDATA[files]]></session_save>
    </global>
    <admin>
        <routers>
            <adminhtml>
                <args>
                    <frontName><![CDATA[admin]]></frontName>
                </args>
            </adminhtml>
        </routers>
    </admin>
</config>
EOF
}

function getOrigEnterpriseXml()
{
    cp ${MAGENTOROOT}app/etc/enterprise.xml ${MAGENTOROOT}app/etc/enterprise.xml.merchant
    cat << 'EOF' > ${MAGENTOROOT}app/etc/enterprise.xml
<?xml version='1.0' encoding="utf-8" ?>
<!--
/**
 * Magento Enterprise Edition
 *
 * NOTICE OF LICENSE
 *
 * This source file is subject to the Magento Enterprise Edition License
 * that is bundled with this package in the file LICENSE_EE.txt.
 * It is also available through the world-wide-web at this URL:
 * http://www.magentocommerce.com/license/enterprise-edition
 * If you did not receive a copy of the license and are unable to
 * obtain it through the world-wide-web, please send an email
 * to license@magentocommerce.com so we can send you a copy immediately.
 *
 * DISCLAIMER
 *
 * Do not edit or add to this file if you wish to upgrade Magento to newer
 * versions in the future. If you wish to customize Magento for your
 * needs please refer to http://www.magentocommerce.com for more information.
 *
 * @category    Enterprise
 * @copyright   Copyright (c) 2009 Irubin Consulting Inc. DBA Varien (http://www.varien.com)
 * @license     http://www.magentocommerce.com/license/enterprise-edition
 */
-->
<config>
    <global>
        <cache>
            <request_processors>
                <ee>Enterprise_PageCache_Model_Processor</ee>
            </request_processors>
            <frontend_options>
                <slab_size>1040000</slab_size>
            </frontend_options>
        </cache>
        <full_page_cache>
            <backend>Mage_Cache_Backend_File</backend>
            <backend_options>
                <cache_dir>full_page_cache</cache_dir>
            </backend_options>
        </full_page_cache>
        <skip_process_modules_updates>0</skip_process_modules_updates>
    </global>
</config>
EOF
}

function getOrigIndex()
{
    cp ${MAGENTOROOT}index.php ${MAGENTOROOT}index.php.merchant
    cat << 'EOF' > index.php
<?php
/**
 * Magento Enterprise Edition
 *
 * NOTICE OF LICENSE
 *
 * This source file is subject to the Magento Enterprise Edition End User License
 * Agreement that is bundled with this package in the file LICENSE_EE.txt.
 * It is also available through the world-wide-web at this URL:
 * http://www.magento.com/license/enterprise-edition
 * If you did not receive a copy of the license and are unable to
 * obtain it through the world-wide-web, please send an email
 * to license@magento.com so we can send you a copy immediately.
 *
 * DISCLAIMER
 *
 * Do not edit or add to this file if you wish to upgrade Magento to newer
 * versions in the future. If you wish to customize Magento for your
 * needs please refer to http://www.magento.com for more information.
 *
 * @category    Mage
 * @package     Mage
 * @copyright Copyright (c) 2006-2015 X.commerce, Inc. (http://www.magento.com)
 * @license http://www.magento.com/license/enterprise-edition
 */

if (version_compare(phpversion(), '5.3.0', '<')===true) {
    echo  '<div style="font:12px/1.35em arial, helvetica, sans-serif;">
<div style="margin:0 0 25px 0; border-bottom:1px solid #ccc;">
<h3 style="margin:0; font-size:1.7em; font-weight:normal; text-transform:none; text-align:left; color:#2f2f2f;">
Whoops, it looks like you have an invalid PHP version.</h3></div><p>Magento supports PHP 5.3.0 or newer.
<a href="http://www.magentocommerce.com/install" target="">Find out</a> how to install</a>
 Magento using PHP-CGI as a work-around.</p></div>';
    exit;
}

/**
 * Error reporting
 */
error_reporting(E_ALL | E_STRICT);

/**
 * Compilation includes configuration file
 */
define('MAGENTO_ROOT', getcwd());

$compilerConfig = MAGENTO_ROOT . '/includes/config.php';
if (file_exists($compilerConfig)) {
    include $compilerConfig;
}

$mageFilename = MAGENTO_ROOT . '/app/Mage.php';
$maintenanceFile = 'maintenance.flag';

if (!file_exists($mageFilename)) {
    if (is_dir('downloader')) {
        header("Location: downloader");
    } else {
        echo $mageFilename, " was not found";
    }
    exit;
}

if (file_exists($maintenanceFile)) {
    include_once dirname(__FILE__) . '/errors/503.php';
    exit;
}

require_once $mageFilename;

#Varien_Profiler::enable();

if (isset($_SERVER['MAGE_IS_DEVELOPER_MODE'])) {
    Mage::setIsDeveloperMode(true);
}

ini_set('display_errors', 1);

umask(0);

/* Store or website code */
$mageRunCode = isset($_SERVER['MAGE_RUN_CODE']) ? $_SERVER['MAGE_RUN_CODE'] : '';

/* Run store or run website */
$mageRunType = isset($_SERVER['MAGE_RUN_TYPE']) ? $_SERVER['MAGE_RUN_TYPE'] : 'store';

Mage::run($mageRunCode, $mageRunType);
EOF
}

function reConfigure()
{
#     echo -n "Reconfigure - "

    getOrigHtaccess
    getMediaOrigHtaccess
    getOrigLocalXml
    getOrigEnterpriseXml
    getOrigIndex
    updateLocalXml
    setupDbConfig

#     echo "OK"
}

function cleanInstall()
{
    if [ -f "$LOCALXMLPATH" ]
    then
        echo "Magento already installed, remove local.xml file to reinstall"
        exit 1;
    fi
    createDb
    echo -n "Please wait started installation - "

    CMD="chmod -R 2777 ${MAGENTOROOT}var ${MAGENTOROOT}media ${MAGENTOROOT}app/etc"
    runCommand;

    CMD="php -f install.php -- --license_agreement_accepted yes \
        --locale en_US --timezone America/Los_Angeles --default_currency USD \
        --db_host ${DBHOST} --db_name ${DBNAME} --db_user ${DBUSER} --db_pass '${DBPASS}' \
        --url ${BASE_URL} --use_rewrites yes \
        --use_secure no --secure_base_url ${BASE_URL} --use_secure_admin no \
        --skip_url_validation yes \
        --admin_lastname Owner --admin_firstname Store --admin_email qa277@magento.com \
        --admin_username admin --admin_password 123123q"
    runCommand;
}

function runCommand()
{
    if [[ "$VERBOSE" -eq 1 ]]
    then
        echo $CMD;
    fi

    eval $CMD;
}

function gitAdd()
{
    if [ -d ".git" ]
    then
        rm -rf ".git" 2>/dev/null;
    fi

    `git init 2>/dev/null`;
    `git add !(@(*.gz|*.tgz|*.tbz2|var|media)) 2>/dev/null`;
    `git commit -m "initial customer deployment" 1&2>/dev/null`;
}

function main()
{
    initScriptOptions
    initVariables

    case "$MODE" in
        clean-install)
            cleanInstall
            ;;
        reconfigure)
            reConfigure
            ;;
        *)
            checkBackupFiles
            extractCode
            createDb
            restoreDb
            reConfigure
            gitAdd
            ;;
    esac

    exit 0
}

main

