#!/bin/bash
# Magento restore script
#
# You can use config file
# Create file in home directory .restore.conf
# Or in directory where restore.sh placed

export LC_CTYPE=C
export LANG=C

####################################################################################################
#Define variables
DBHOST="localhost"
DBNAME=
DBUSER=
DBPASS=
BASE_URL=
# DEV_TABLE_PREFIX=

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
DEPLOYMENT_DIR_NAME=$(basename "$(pwd)")
FORCE_WITHOUT_CONFIG=0
FORCE_RESTORE=0
VERBOSE=0

# unset OPT_DBHOST
# unset OPT_DBNAME
# unset OPT_DBUSER
# unset OPT_DBPASS
# unset OPT_BASE_URL



####################################################################################################
#Define functions.

function showHelp()
{
    echo "Magento Restore script"
    echo "Usage: ${0} [option]"
    echo "    --help                show available params for script (this screen)"
    echo "    -w, --without-config  do not use config file data"
    echo "    -f, --force           install without check step"
    echo "    -r, --reconfigure     ReConfigure current magento instance"
    echo "    -c, --clean-install   Standard install procedure through CLI"
    echo "    -m, --mode            must have one of the following:"
    echo "                          \"reconfigure\", \"clean-install\", \"code\", or \"db\""
    echo "                          The first two are optional usages of the previous two options."
    echo "                          \"code\" tells the script to only decompress the code, and"
    echo "                          \"db\" to only move the data into the database."
    echo "    -h, --host            DB host IP address, defaults to \"localhost\""
    echo "    -D, --database        Database or schema name, defaults to current directory name"
    echo "    -u, --user            DB user name"
    echo "    -p, --password        DB password"
    echo "    -b, --base-url        Base URL for this deployment host."
    echo ""
    echo "This script assumes it is being run from the new deployment directory with merchant backup files."
    echo ""
    echo "Your \"~/${CONFIG_FILE_NAME}\" file must be manually created in your home directory."
    echo ""
    echo "Missing entries are treated as empty strings."
    echo ""
    echo "In most cases, if the requested value is not included on the command line then"
    echo "the corresponding value from the config file is used. In the special case"
    echo "of the DB name, if the DB name is empty in the config file and none is entered"
    echo "on the command line then the current working directory basename is used."
    echo "Digits are allowed as a DB name."
    echo ""
    echo "Sample \"~/${CONFIG_FILE_NAME}\":"
    echo "DBHOST=sparta-db"
    echo "DBNAME=rwoodbury_test"
    echo "DBUSER=rwoodbury"
    echo "DBPASS="
    echo "BASE_URL=http://sparta.corp.magento.com/dev/rwoodbury/"
    echo ""
}

function getCodeDumpFile()
{
    # TODO: more file types/endings
    FILENAME_CODE_DUMP=$(ls -1 *.tbz2 *.tar.bz2 2> /dev/null | head -n1)
    if [ "${FILENAME_CODE_DUMP}" == "" ]
    then
        FILENAME_CODE_DUMP=$(ls -1 *.tar.gz | grep -v 'logs.tar.gz' | head -n1)
    fi

    debug "Code dump Filename" "$FILENAME_CODE_DUMP"

    if [ ! -f "$FILENAME_CODE_DUMP" ]
    then
        echo "Code dump absent" >&2
        exit 1
    fi
}

function getDbDumpFile()
{
    FILENAME_DB_DUMP=$(ls -1 *.sql.gz | head -n1)

    debug "DB dump Filename" "$FILENAME_DB_DUMP"

    if [ ! -f "$FILENAME_DB_DUMP" ]
    then
        echo "DB dump absent" >&2
        exit 1
    fi
}

function getPathConfigFile()
{
    if [ -f ~/"${CONFIG_FILE_NAME}" ]
    then
        PATH_CONFIG_FILE=~/"${CONFIG_FILE_NAME}"
    else
        PATH_CONFIG_FILE="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/${CONFIG_FILE_NAME}"
    fi
}

####################################################################################################
function initVariables()
{
    getPathConfigFile

    # Read defaults from config file if it exists.
    if [ ${FORCE_WITHOUT_CONFIG} -ne 1 ] && [ -f "$PATH_CONFIG_FILE" ]
    then
        source ${PATH_CONFIG_FILE}
    fi

    DBHOST="${OPT_DBHOST:-$DBHOST}"

    if [ -z "$DBNAME" ]
    then
        DBNAME="$DEPLOYMENT_DIR_NAME"
    fi

    DBNAME="${OPT_DBNAME:-$DBNAME}"
    DBUSER="${OPT_DBUSER:-$DBUSER}"
    DBPASS="${OPT_DBPASS:-$DBPASS}"

#   if [ "${DBNAME}" != "${DEPLOYMENT_DIR_NAME}" ]
#   then
#       DEV_TABLE_PREFIX="${DEPLOYMENT_DIR_NAME}_"
#   fi
#   echo -n "Enter developer table prefix [${DEV_TABLE_PREFIX}]: "
#   read TMP_DEV_TABLE_PREFIX
#   if [ -n "$TMP_DEV_TABLE_PREFIX" ]
#   then
#       DEV_TABLE_PREFIX=$TMP_DEV_TABLE_PREFIX
#   fi

    BASE_URL="${OPT_BASE_URL:-$BASE_URL}"
    BASE_URL="${BASE_URL}${DEPLOYMENT_DIR_NAME}/"

    DBNAME=$(echo "$DBNAME" | sed "s/[^a-zA-Z0-9_]//g" | tr '[A-Z]' '[a-z]');

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
            [Nn]|[Nn][Oo]) echo "Interrupted by user, exiting..."; exit;;
        esac
    fi

    echo ""
}

####################################################################################################
function createDb
{
    mysqladmin --force -h$DBHOST -u$DBUSER -p$DBPASS drop $DBNAME 2>/dev/null

    echo -n "Creating DB \"${DBNAME}\" - "
    mysqladmin -h"$DBHOST" -u"$DBUSER" -p"$DBPASS" create "$DBNAME" 2>/dev/null
    echo "OK"
}

function restoreDb()
{
    echo -n "Restoring DB from dump"

    if which pv > /dev/null
    then
        echo ":"
        pv $FILENAME_DB_DUMP | gunzip -cf | sed -e 's/DEFINER[ ]*=[ ]*[^*]*\*/\*/' | mysql -h"$DBHOST" -u"$DBUSER" -p"$DBPASS" --force "$DBNAME" 2>/dev/null
    else
        echo -n " - "
        gunzip -c $FILENAME_DB_DUMP | gunzip -cf | sed -e 's/DEFINER[ ]*=[ ]*[^*]*\*/\*/' | mysql -h"$DBHOST" -u"$DBUSER" -p"$DBPASS" --force "$DBNAME" 2>/dev/null
        echo "OK"
    fi
}

####################################################################################################
function extractCode()
{
    echo -n "Extracting code"

    if [ ! -f $FILENAME_CODE_DUMP ] ; then
        echo "'$FILENAME_CODE_DUMP' is not a valid file" >&2
        exit 1
    fi

    if which pv > /dev/null; then
        echo ":"
        case $FILENAME_CODE_DUMP in
            *.tar.gz|*.tgz)         pv -B 32k $FILENAME_CODE_DUMP | tar zxf - ;;
            *.tar.bz2|*.tbz2|*.tbz) pv -B 32k $FILENAME_CODE_DUMP | tar jxf - ;;
            *.gz)        gunzip -k $FILENAME_CODE_DUMP;;
            *.bz|*.bz2)  bunzip2 -k $FILENAME_CODE_DUMP;;
            *)           echo "'$FILENAME_CODE_DUMP' could not be extracted" >&2; exit 1;;
        esac
    else
        echo -n " - "
        # Modern versions of tar can automatically choose the decompression type when needed.
        case $FILENAME_CODE_DUMP in
            *.tar.gz|*.tgz|*.tar.bz2|*.tbz2|*.tbz)   tar xf $FILENAME_CODE_DUMP;;
            *.gz)        gunzip -k $FILENAME_CODE_DUMP;;
            *.bz|*.bz2)  bunzip2 -k $FILENAME_CODE_DUMP;;
            *)           echo "'$FILENAME_CODE_DUMP' could not be extracted" >&2; exit 1;;
        esac
    fi

    chmod -R 02777 $MAGENTO_FOLDER_ETC

    echo "OK"
}

####################################################################################################
function setupDbConfig()
{
    echo -n "Replacing DB values. - "

    getLocalValue "table_prefix"
    TABLE_PREFIX="${PARAMVALUE}"

    runMysqlQuery "UPDATE ${TABLE_PREFIX}core_config_data SET value = '${BASE_URL}' WHERE path IN ('web/secure/base_url', 'web/unsecure/base_url')"

    runMysqlQuery "DELETE FROM ${TABLE_PREFIX}core_config_data WHERE path LIKE 'web/cookie/%'"

    runMysqlQuery "DELETE FROM ${TABLE_PREFIX}core_config_data WHERE path IN ('web/unsecure/base_link_url', 'web/unsecure/base_skin_url', 'web/unsecure/base_media_url', 'web/unsecure/base_js_url')"

    runMysqlQuery "DELETE FROM ${TABLE_PREFIX}core_config_data WHERE path IN ('web/secure/base_link_url', 'web/secure/base_skin_url', 'web/secure/base_media_url', 'web/secure/base_js_url')"

    runMysqlQuery "DELETE FROM ${TABLE_PREFIX}core_config_data WHERE path IN ('web/secure/use_in_adminhtml')"

    runMysqlQuery "DELETE FROM ${TABLE_PREFIX}core_config_data WHERE path LIKE 'admin/url/%'"


    runMysqlQuery "SELECT user_id FROM ${TABLE_PREFIX}admin_user WHERE username = 'admin'"
    USER_ID=$(echo "${SQLQUERY_RESULT}" | sed -e 's/^[a-zA-Z_]*//');

    if [ -z "$USER_ID" ]
    then
        runMysqlQuery "SELECT user_id FROM ${TABLE_PREFIX}admin_user ORDER BY user_id ASC LIMIT 1"
        USER_ID=$(echo "${SQLQUERY_RESULT}" | sed -e 's/^[a-zA-Z_]*//');
    fi

    runMysqlQuery "UPDATE ${TABLE_PREFIX}admin_user SET password='eef6ebe8f52385cdd347d75609309bb29a555d7105980916219da792dc3193c6:6D', username='admin', is_active=1 WHERE user_id = ${USER_ID}"

    runMysqlQuery "UPDATE ${TABLE_PREFIX}enterprise_admin_passwords SET expires = UNIX_TIMESTAMP() + (365 * 24 * 60 * 60) WHERE user_id = ${USER_ID}"

    echo "OK"
}

####################################################################################################
function updateLocalXml()
{
    echo -n "Updating local XML files. - "

    getLocalValue "table_prefix"
    TABLE_PREFIX="${PARAMVALUE}"

    getLocalValue "date"
    INSTALL_DATE="${PARAMVALUE}"

    getLocalValue "key"
    CRYPT_KEY="${PARAMVALUE}"

    _updateLocalXmlParam "key" "${CRYPT_KEY}"
    _updateLocalXmlParam "date" "${INSTALL_DATE}"
    _updateLocalXmlParam "table_prefix" "${TABLE_PREFIX}"
    _updateLocalXmlParam "username" "${DBUSER}"
    _updateLocalXmlParam "password" "${DBPASS}"
    _updateLocalXmlParam "dbname" "${DBNAME}"
    _updateLocalXmlParam "host" "${DBHOST}"
    _updateLocalXmlParam "frontName" "admin"

    echo "OK"
}

function _updateLocalXmlParam()
{
    sed "s/<${1}><\!\[CDATA\[.*\]\]><\/${1}>/<${1}><\!\[CDATA\[${2}\]\]><\/${1}>/" $LOCALXMLPATH > $LOCALXMLPATH.new
    mv -f $LOCALXMLPATH.new $LOCALXMLPATH
}

getLocalValue() {
    PARAMVALUE=$(sed -n -e "s/.*<${1}><!\[CDATA\[\(.*\)\]\]><\/${1}>.*/\1/p" ${LOCALXMLPATH} | head -n 1)
}

function runMysqlQuery()
{
    SQLQUERY_RESULT=$(mysql -h"$DBHOST" -u"$DBUSER" -p"$DBPASS" -D "$DBNAME" -e "${1}" 2>/dev/null);
}

function debug()
{
    if [ $DEBUG_MODE -eq 0 ]; then
        return
    fi

    echo "KEY: ${1} VALUE: ${2}"
}

function getOrigHtaccess()
{
    if [ -f ${MAGENTOROOT}.htaccess ]; then
        cp ${MAGENTOROOT}.htaccess ${MAGENTOROOT}.htaccess.merchant
    fi

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
    getOrigHtaccess
    getMediaOrigHtaccess
    getOrigLocalXml
    getOrigEnterpriseXml
    getOrigIndex
    updateLocalXml
}

function cleanInstall()
{
    if [ -f "$LOCALXMLPATH" ]
    then
        echo "Magento already installed, remove local.xml file to reinstall" >&2
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
    echo -n "Wrapping deployment with local only 'git' repository - "

    if [ -d ".git" ]
    then
        rm -rf .git >/dev/null 2>&1
    fi

    cat << 'GIT_IGNORE_EOF' > .gitignore
media/
var/
.idea/
*.gz
*.tgz
*.bz
*.bz2
*.tbz2
*.tbz
*.zip

GIT_IGNORE_EOF

    git init >/dev/null 2>&1
    # don't add files ending with 'z'
    git add ./.ht* .gitignore *[a-y] >/dev/null 2>&1
    git commit -m "initial customer deployment" >/dev/null 2>&1

    echo "OK"
}


####################################################################################################
##  MAIN  ##########################################################################################
####################################################################################################

####################################################################################################
#   Parse options and set environment.
OPTIONS=`getopt -o wfrcm:h:D:u:p:b: -l help,without-config,force,reconfigure,clean-install,mode:,host:,database:,user:,password:,base-url: -n "${0}" -- "$@"`

if [ $? != 0 ] ; then
    echo "Failed parsing options." >&2
    echo
    showHelp
    exit 1
fi

eval set -- "$OPTIONS"

while true; do
    case "$1" in
        --help )                showHelp; exit 0;;
        -w|--without-config )   FORCE_WITHOUT_CONFIG=1; shift 1;;
        -f|--force )            FORCE_RESTORE=1; shift 1;;
        -r|--reconfigure )      MODE="reconfigure"; shift 1;;
        -c|--clean-install )    MODE="clean-install"; shift 1;;
        -m|--mode )             MODE="$2"; shift 2;;
        -h|--host )             OPT_DBHOST="$2"; shift 2;;
        -D|--database )         OPT_DBNAME="$2"; shift 2;;
        -u|--user )             OPT_DBUSER="$2"; shift 2;;
        -p|--password )         OPT_DBPASS="$2"; shift 2;;
        -b|--base-url )         OPT_BASE_URL="$2"; shift 2;;
        -- ) shift; break;;
        * ) echo "Internal getopt parse error!"; echo; showHelp; exit 1;;
    esac
done


####################################################################################################
# Execute.
case "$MODE" in
    # --reconfigure
    'reconfigure')
        initVariables
        reConfigure
        setupDbConfig
        gitAdd
        ;;

    # --clean-install
    'clean-install')
        initVariables
        cleanInstall
        ;;

    # --mode code
    'code')
        initVariables
        getCodeDumpFile
        extractCode
        reConfigure
        gitAdd
        mkdir -pm 02777 $MAGENTO_FOLDER_MEDIA $MAGENTO_FOLDER_VAR
        ;;

    # --mode db
    'db')
        initVariables
        getDbDumpFile
        createDb
        restoreDb
        setupDbConfig
        ;;

    # Empty "mode". Do everything.
    '')
        initVariables
        getCodeDumpFile
        extractCode
        getDbDumpFile
        createDb
        restoreDb
        reConfigure
        setupDbConfig
        gitAdd
        mkdir -pm 02777 $MAGENTO_FOLDER_MEDIA $MAGENTO_FOLDER_VAR
        ;;

    *)
        echo "Bad mode."
        echo
        showHelp
        exit 1

esac

exit 0
