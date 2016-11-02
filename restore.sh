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
CRYPT_KEY=
INSTALL_DATE=

DEBUG_MODE=0

MAGENTOROOT="$PWD"

CONFIG_FILE="${HOME}/restore.conf"
DEPLOYMENT_DIR_NAME=$(basename "$MAGENTOROOT")
ADMIN_EMAIL=
LOCALE_CODE="en_US"
FORCE_RESTORE=0

MAMP_PHP="/Applications/MAMP/bin/php/php5.6.25/bin/php"


####################################################################################################
#Define functions.

function showHelp()
{
    cat <<ENDHELP
Magento Deployment Restore Script
Usage: ${0} [option]
    -H, --help            Show available params for script (this screen).
    -c, --config-file     Specify a configuration file other than the default.
    -f, --force           Install without pause to check data.
    -r, --reconfigure     ReConfigure current Magento deployment.
    -i, --install-only    Standard fresh install procedure through CLI.
    -m, --mode            This must have one of the following:
                          "reconfigure", "install-only", "code", or "db"
                          The first two are optional usages of the previous two options.
                          "code" tells the script to only decompress the code, and
                          "db" to only move the data into the database.
    -h, --host            DB host IP address, defaults to "localhost".
    -D, --database        Database or schema name, defaults to current directory name.
    -u, --user            DB user name.
    -p, --password        DB password
    -b, --base-url        Base URL for this deployment host.
    -e, --email           Admin email address.
    -l, --locale          "base/locale/code" configuration value. Defaults to "en_US".

This script assumes it is being run from the new deployment directory with the
merchant's backup files.

Your "${CONFIG_FILE}" file must be manually created in your home directory.

Missing entries are treated as empty strings. In most cases, if the requested
value is not included on the command line then the corresponding value from the
config file is used. In the special case of the DB name, if the DB name is
empty in the config file and none is entered on the command line then the
current working directory basename is used. Digits are allowed as a DB name.

Sample "${CONFIG_FILE}":
DBHOST=sparta-db
DBNAME=rwoodbury_test
DBUSER=rwoodbury
DBPASS=
BASE_URL=http://web1.sparta.corp.magento.com/dev/rwoodbury/

NOTE: OS X users will need to install a newer version of "getopt" from a
repository like MacPorts:
> sudo port install getopt

ENDHELP

}

####################################################################################################
# Check required system tools
_check_installed_tools() {
    local missed=""

    until [ -z "$1" ]; do
        type -t $1 >/dev/null 2>/dev/null
        if (( $? != 0 )); then
            missed="$missed $1"
        fi
        shift
    done

    echo $missed
}

# Selftest for checking tools which will used
checkTools() {
    REQUIRED_UTILS='sed tar mysql head gzip getopt mysqladmin php'
    MISSED_REQUIRED_TOOLS=`_check_installed_tools $REQUIRED_UTILS`
    if (( `echo $MISSED_REQUIRED_TOOLS | wc -w` > 0 ));
    then
        echo -e "Unable to create backup due to missing required bash tools: $MISSED_REQUIRED_TOOLS"
        exit 1
    fi
}

####################################################################################################
function initVariables()
{
    CONFIG_FILE="${OPT_CONFIG_FILE:-$CONFIG_FILE}"

    # Read defaults from config file if it exists.
    if [[ -f "$CONFIG_FILE" ]]
    then
        source "$CONFIG_FILE"
    fi


    DBHOST="${OPT_DBHOST:-$DBHOST}"

    if [[ -z $DBNAME ]]
    then
        DBNAME="$DEPLOYMENT_DIR_NAME"
    fi

    # The variable DBNAME is often not quoted throughout the script as it should always appear as one word.
    DBNAME="${OPT_DBNAME:-$DBNAME}"
    # The variables DBUSER and DBPASS are quoted throughout the script as they could contain spaces.
    DBUSER="${OPT_DBUSER:-$DBUSER}"
    DBPASS="${OPT_DBPASS:-$DBPASS}"

#   if [[ $DBNAME != "$DEPLOYMENT_DIR_NAME" ]]
#   then
#       DEV_TABLE_PREFIX="${DEPLOYMENT_DIR_NAME}_"
#   fi
#   echo -n "Enter developer table prefix [[${DEV_TABLE_PREFIX}]]: "
#   read TMP_DEV_TABLE_PREFIX
#   if [[ -n "$TMP_DEV_TABLE_PREFIX" ]]
#   then
#       DEV_TABLE_PREFIX=$TMP_DEV_TABLE_PREFIX
#   fi

    BASE_URL="${OPT_BASE_URL:-$BASE_URL}"
    BASE_URL="${BASE_URL}${DEPLOYMENT_DIR_NAME}/"

    ADMIN_EMAIL="${OPT_ADMIN_EMAIL:-$ADMIN_EMAIL}"

    LOCALE_CODE="${OPT_LOCALE_CODE:-$LOCALE_CODE}"

    cat <<ENDCHECK
Check parameters:
DB host is: $DBHOST
DB name is: $DBNAME
DB user is: $DBUSER
DB pass is: $DBPASS
Full base url is: $BASE_URL
Admin email is: $ADMIN_EMAIL
Locale code is: $LOCALE_CODE
ENDCHECK

    if [[ ${FORCE_RESTORE} -eq 0 ]]
    then
        echo -n "Continue? [Y/n]: "
        read CONFIRM

        case "$CONFIRM" in
            [Nn]|[Nn][Oo]) echo "Interrupted by user, exiting..."; exit ;;
        esac
    fi
}

####################################################################################################
function extractCode()
{
    FILENAME=$(ls -1 *.gz *.tgz *.bz2 *.tbz2 *.tbz *.gz *.bz *.bz2 2> /dev/null | grep -v '\.logs\.' | grep -v '\.sql\.' | head -n1)

    debug "Code dump Filename" "$FILENAME"

    if [[ -z "$FILENAME" ]]
    then
        echo "\"$FILENAME\" is not a valid file" >&2
        exit 1
    fi

    echo -n "Extracting code"

    if which pv > /dev/null; then
        echo ":"
        case "$FILENAME" in
            *.tar.gz|*.tgz)
                pv -B 16k "$FILENAME" | tar zxf - 2>/dev/null ;;
            *.tar.bz2|*.tbz2|*.tbz)
                pv -B 16k "$FILENAME" | tar jxf - 2>/dev/null ;;
            *.gz)
                gunzip -k "$FILENAME" ;;
            *.bz|*.bz2)
                bunzip2 -k "$FILENAME" ;;
            *)
                echo "\"$FILENAME\" could not be extracted" >&2; exit 1 ;;
        esac
    else
        echo -n " - "
        # Modern versions of tar can automatically choose the decompression type when needed.
        case "$FILENAME" in
            *.tar.gz|*.tgz|*.tar.bz2|*.tbz2|*.tbz)
                tar xf "$FILENAME" ;;
            *.gz)
                gunzip -k "$FILENAME" ;;
            *.bz|*.bz2)
                bunzip2 -k "$FILENAME" ;;
            *)
                echo "\"$FILENAME\" could not be extracted" >&2; exit 1 ;;
        esac
        echo "OK"
    fi

    mkdir -pm 2777 "${MAGENTOROOT}/var" "${MAGENTOROOT}/media"

    # Also do the log archive if it exists.
    FILENAME=$(ls -1 *.gz *.tgz *.bz2 *.tbz2 *.tbz *.gz *.bz *.bz2 2>/dev/null | grep '\.logs\.' | head -n1)
    if [[ -n "$FILENAME" ]]
    then
        echo -n "Extracting log files - "
        case "$FILENAME" in
            *.tar.gz|*.tgz|*.tar.bz2|*.tbz2|*.tbz)
                tar xf "$FILENAME" 2>/dev/null ;;
            *.gz)
                gunzip -k "$FILENAME" ;;
            *.bz|*.bz2)
                bunzip2 -k "$FILENAME" ;;
            *)
                echo "\"$FILENAME\" could not be extracted" >&2; exit 1 ;;
        esac
        echo "OK"
    fi

    echo -n "Updating permissions and cleanup - "

    # Remove confusing OS X garbage if any.
#     find . -name '._*' -print0 | xargs -0 rm

    find . -type d -print0 | xargs -0 chmod a+rx
    find . -type f -print0 | xargs -0 chmod 644

    mkdir -p "${MAGENTOROOT}/var/log/"
    touch "${MAGENTOROOT}/var/log/exception_dev.log"
    touch "${MAGENTOROOT}/var/log/system_dev.log"
    chmod -R 2777 "${MAGENTOROOT}/app/etc" "${MAGENTOROOT}/var" "${MAGENTOROOT}/media"
    chmod -R 2777 "${MAGENTOROOT}/app/etc" "${MAGENTOROOT}/var" "${MAGENTOROOT}/media"

    echo "OK"
}

####################################################################################################
function createDb
{
    mysqladmin --force -h"$DBHOST" -u"$DBUSER" -p"$DBPASS" drop $DBNAME &>/dev/null

    mysqladmin -h"$DBHOST" -u"$DBUSER" -p"$DBPASS" create $DBNAME 2>/dev/null
}

function restoreDb()
{
    echo -n "Restoring DB from dump"

    FILENAME=$(ls -1 *.sql.* | head -n1)

    debug "DB dump Filename" "$FILENAME"

    if [[ -z "$FILENAME" ]]
    then
        echo "DB dump absent" >&2
        exit 1
    fi

    if which pv > /dev/null
    then
        echo ":"
        pv "$FILENAME" | gunzip -cf | sed -e 's/DEFINER[ ]*=[ ]*[^*]*\*/\*/' | mysql -h"$DBHOST" -u"$DBUSER" -p"$DBPASS" --force $DBNAME 2>/dev/null
    else
        echo -n " - "
        gunzip -c "$FILENAME" | gunzip -cf | sed -e 's/DEFINER[ ]*=[ ]*[^*]*\*/\*/' | mysql -h"$DBHOST" -u"$DBUSER" -p"$DBPASS" --force $DBNAME 2>/dev/null
        echo "OK"
    fi
}

####################################################################################################
function doDbReconfigure()
{
    echo -n "Replacing DB values. - "

    getMerchantLocalXmlValues

    setConfigValue 'admin/captcha/enable' '0'

    setConfigValue 'admin/dashboard/enable_charts' '0'

    setConfigValue 'admin/enterprise_logging/actions' 'a:0:{}'

    setConfigValue 'admin/security/lockout_failures' '0'
    setConfigValue 'admin/security/lockout_threshold' '0'
    setConfigValue 'admin/security/password_is_forced' '0'
    setConfigValue 'admin/security/password_lifetime' '9999'
    setConfigValue 'admin/security/session_cookie_lifetime' '0'
    setConfigValue 'admin/security/use_form_key' '0'

    setConfigValue 'admin/startup/page' 'system/config'

    setConfigValue 'dev/css/merge_css_files' '0'
    setConfigValue 'dev/js/merge_files' '0'
    setConfigValue 'dev/log/active' '1'
    setConfigValue 'dev/log/exception_file' 'exception_dev.log'
    setConfigValue 'dev/log/file' 'system_dev.log'

    setConfigValue 'general/locale/code' "$LOCALE_CODE"

    setConfigValue 'system/csrf/use_form_key' '0'
    setConfigValue 'system/page_cache/multicurrency' '0'
    setConfigValue 'system/page_crawl/multicurrency' '0'

    setConfigValue 'web/cookie/cookie_domain' ''
    setConfigValue 'web/cookie/cookie_path' ''
    setConfigValue 'web/cookie/cookie_lifetime' '0'

    setConfigValue 'web/secure/base_url' "$BASE_URL"
    setConfigValue 'web/secure/use_in_adminhtml' '0'
    setConfigValue 'web/unsecure/base_url' "$BASE_URL"

    deleteFromConfigWhere "IN ('web/unsecure/base_link_url', 'web/unsecure/base_skin_url', 'web/unsecure/base_media_url', 'web/unsecure/base_js_url')"

    deleteFromConfigWhere "IN ('web/secure/base_link_url', 'web/secure/base_skin_url', 'web/secure/base_media_url', 'web/secure/base_js_url')"

    deleteFromConfigWhere "LIKE 'admin/url/%'"

    runMysqlQuery "SELECT user_id FROM ${TABLE_PREFIX}admin_user WHERE username = 'admin'"
    USER_ID=$(echo "$SQLQUERY_RESULT" | sed -e 's/^[a-zA-Z_]*//');

    if [[ -z "$USER_ID" ]]
    then
        runMysqlQuery "SELECT user_id FROM ${TABLE_PREFIX}admin_user ORDER BY user_id ASC LIMIT 1"
        USER_ID=$(echo "$SQLQUERY_RESULT" | sed -e 's/^[a-zA-Z_]*//');
    fi

    runMysqlQuery "UPDATE ${TABLE_PREFIX}admin_user SET password='eef6ebe8f52385cdd347d75609309bb29a555d7105980916219da792dc3193c6:6D', username='admin', is_active=1, email='${ADMIN_EMAIL}' WHERE user_id = ${USER_ID}"

    runMysqlQuery "UPDATE ${TABLE_PREFIX}enterprise_admin_passwords SET expires = UNIX_TIMESTAMP() + (365 * 24 * 60 * 60) WHERE user_id = ${USER_ID}"

    runMysqlQuery "UPDATE ${TABLE_PREFIX}core_cache_option SET value = 0 WHERE 1"

    echo "OK"
}

##  Pass parameters as key / value.
function setConfigValue()
{
    runMysqlQuery "REPLACE INTO ${TABLE_PREFIX}core_config_data SET path = '$1', value = '$2'"
}

function deleteFromConfigWhere()
{
    runMysqlQuery "DELETE FROM ${TABLE_PREFIX}core_config_data WHERE path $1"
}

function getMerchantLocalXmlValues()
{
    #   If empty then get the values.
    if [[ -z "$INSTALL_DATE" ]]
    then
        getLocalXmlValue "table_prefix"
        TABLE_PREFIX="$PARAMVALUE"

        getLocalXmlValue "date"
        INSTALL_DATE="$PARAMVALUE"

        getLocalXmlValue "key"
        CRYPT_KEY="$PARAMVALUE"
    fi
}

getLocalXmlValue()
{
    # First, assume we're doing a dump restore.
    APP_ETC_LOCAL_XML="${MAGENTOROOT}/app/etc/local.xml.merchant"

    if [[ ! -f "$APP_ETC_LOCAL_XML" ]]
    then
        # Else, we're doing an install-only.
        APP_ETC_LOCAL_XML="${MAGENTOROOT}/app/etc/local.xml"
    fi

    # Next:
    # First look for value surrounded by "CDATA" construct.
    LOCAL_XML_SEARCH="s/.*<${1}><!\[CDATA\[\(.*\)\]\]><\/${1}>.*/\1/p"
    debug "local XML search string" "$LOCAL_XML_SEARCH"
    PARAMVALUE=$(sed -n -e "$LOCAL_XML_SEARCH" "$APP_ETC_LOCAL_XML" | head -n 1)
    debug "local XML found" "$PARAMVALUE"

    # If not found then try searching without.
    if [[ -z "$PARAMVALUE" ]]
    then
        LOCAL_XML_SEARCH="s/.*<${1}>\(.*\)<\/${1}>.*/\1/p"
        debug "local XML search string" "$LOCAL_XML_SEARCH"
        PARAMVALUE=$(sed -n -e "$LOCAL_XML_SEARCH" "$APP_ETC_LOCAL_XML" | head -n 1)
        debug "local XML found" "$PARAMVALUE"

        # Prevent disaster.
        if [[ "$PARAMVALUE" == '<![CDATA[]]>' ]]
        then
            PARAMVALUE=''
        fi
    fi
}

function runMysqlQuery()
{
    SQLQUERY_RESULT=$(mysql -h"$DBHOST" -u"$DBUSER" -p"$DBPASS" -D $DBNAME -e "$1" 2>/dev/null);
}

function debug()
{
    if [[ $DEBUG_MODE -eq 0 ]]
    then
        return
    fi

    echo "KEY: $1  VALUE: $2"
}

function getOrigHtaccess()
{
    if [[ ! -f "${MAGENTOROOT}/.htaccess.merchant" && -f "${MAGENTOROOT}/.htaccess" ]]
    then
        mv "${MAGENTOROOT}/.htaccess" "${MAGENTOROOT}/.htaccess.merchant"
    fi

    cat <<EOF > "${MAGENTOROOT}/.htaccess"
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
    if [[ ! -f "${MAGENTOROOT}/get.php" ]]
    then
        return;
    fi

    if [[ ! -f "${MAGENTOROOT}/media/.htaccess.merchant" && -f "${MAGENTOROOT}/media/.htaccess" ]]
    then
        mv "${MAGENTOROOT}/media/.htaccess" "${MAGENTOROOT}/media/.htaccess.merchant"
    fi

    cat <<EOF > "${MAGENTOROOT}/media/.htaccess"
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
    if [[ ! -f "${MAGENTOROOT}/app/etc/local.xml.merchant" && -f "${MAGENTOROOT}/app/etc/local.xml" ]]
    then
        mv "${MAGENTOROOT}/app/etc/local.xml" "${MAGENTOROOT}/app/etc/local.xml.merchant"
    fi

    getMerchantLocalXmlValues

    cat <<EOF > "${MAGENTOROOT}/app/etc/local.xml"
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
            <date><![CDATA[${INSTALL_DATE}]]></date>
        </install>
        <crypt>
            <key><![CDATA[${CRYPT_KEY}]]></key>
        </crypt>
        <disable_local_modules>false</disable_local_modules>
        <resources>
            <db>
                <table_prefix><![CDATA[${TABLE_PREFIX}]]></table_prefix>
            </db>
            <default_setup>
                <connection>
                    <host><![CDATA[${DBHOST}]]></host>
                    <username><![CDATA[${DBUSER}]]></username>
                    <password><![CDATA[${DBPASS}]]></password>
                    <dbname><![CDATA[${DBNAME}]]></dbname>
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
    if [[ ! -f "${MAGENTOROOT}/app/etc/enterprise.xml.merchant" && -f "${MAGENTOROOT}/app/etc/enterprise.xml" ]]
    then
        mv "${MAGENTOROOT}/app/etc/enterprise.xml" "${MAGENTOROOT}/app/etc/enterprise.xml.merchant"
    fi

    cat <<EOF > "${MAGENTOROOT}/app/etc/enterprise.xml"
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
    if [[ ! -f "${MAGENTOROOT}/index.php.merchant" && -f "${MAGENTOROOT}/index.php" ]]
    then
        mv "${MAGENTOROOT}/index.php" "${MAGENTOROOT}/index.php.merchant"
    fi

    cat <<EOF > index.php
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

\$compilerConfig = MAGENTO_ROOT . '/includes/config.php';
if (file_exists(\$compilerConfig)) {
    include \$compilerConfig;
}

\$mageFilename = MAGENTO_ROOT . '/app/Mage.php';
\$maintenanceFile = 'maintenance.flag';

if (!file_exists(\$mageFilename)) {
    if (is_dir('downloader')) {
        header("Location: downloader");
    } else {
        echo \$mageFilename." was not found";
    }
    exit;
}

if (file_exists(\$maintenanceFile)) {
    include_once dirname(__FILE__) . '/errors/503.php';
    exit;
}

require_once \$mageFilename;

#Varien_Profiler::enable();

if (isset(\$_SERVER['MAGE_IS_DEVELOPER_MODE'])) {
    Mage::setIsDeveloperMode(true);
}

ini_set('display_errors', 1);

umask(0);

/* Store or website code */
\$mageRunCode = isset(\$_SERVER['MAGE_RUN_CODE']) ? \$_SERVER['MAGE_RUN_CODE'] : '';

/* Run store or run website */
\$mageRunType = isset(\$_SERVER['MAGE_RUN_TYPE']) ? \$_SERVER['MAGE_RUN_TYPE'] : 'store';

Mage::run(\$mageRunCode, \$mageRunType);

EOF

}

function doFileReconfigure()
{
    echo -n "Reconfiguring files. - "

    getOrigHtaccess
    getMediaOrigHtaccess
    getOrigLocalXml
    getOrigEnterpriseXml
    getOrigIndex

    echo "OK"
}

####################################################################################################
function installOnly()
{
    if [[ -f "${MAGENTOROOT}/app/etc/local.xml" ]]
    then
        echo "Magento already installed, remove app/etc/local.xml file to reinstall" >&2
        exit 1;
    fi

    echo "Performing Magento install."

    createDb

    chmod 2777 "${MAGENTOROOT}/var"
    mkdir -p "${MAGENTOROOT}/var/log/"
    chmod 2777 "${MAGENTOROOT}/var/log"
    touch "${MAGENTOROOT}/var/log/exception.log"
    touch "${MAGENTOROOT}/var/log/system.log"

    chmod 2777 "${MAGENTOROOT}/app/etc" "${MAGENTOROOT}/media"

    if [[ -f "$MAMP_PHP" ]]
    then
        THIS_PHP="$MAMP_PHP"
    else
        THIS_PHP="php"
    fi

    # MAMP 4.0.5 returns the wrong timezone.
    TIMEZONE=`php -r 'echo date_default_timezone_get();'`

    "$THIS_PHP" -f install.php -- --license_agreement_accepted yes \
        --locale en_US --timezone "$TIMEZONE" --default_currency USD \
        --db_host $DBHOST --db_name "$DBNAME" --db_user "$DBUSER" --db_pass "$DBPASS" \
        --url "$BASE_URL" --use_rewrites yes \
        --use_secure no --secure_base_url "$BASE_URL" --use_secure_admin no \
        --skip_url_validation yes \
        --admin_lastname Owner --admin_firstname Store --admin_email "$ADMIN_EMAIL" \
        --admin_username admin --admin_password 123123q

    doDbReconfigure

    # Add GIT repo if none exists.
    if [[ ! -d ".git" ]]
    then
        gitAdd
    fi
}

####################################################################################################
function gitAdd()
{
    echo -n "Wrapping deployment with local-only 'git' repository - "

    gitAddQuiet

    echo "OK"
}

function gitAddQuiet()
{
    if [[ -f ".gitignore" ]]
    then
        mv -f .gitignore .gitignore.merchant
    fi

    cat <<GIT_IGNORE_EOF > .gitignore
/media/
/var/
/.idea/
.svn/
*.gz
*.tgz
*.bz
*.bz2
*.tbz2
*.tbz
*.zip
*.tar
.DS_Store

GIT_IGNORE_EOF

    if [[ -d ".git" ]]
    then
        mv -f .git .git.merchant
    fi

    git init >/dev/null 2>&1

    if [[ `uname` == 'Darwin' ]]
    then
        FIND_REGEX_TYPE='find -E . -type f'
    else
        FIND_REGEX_TYPE='find . -type f -regextype posix-extended'
    fi

    $FIND_REGEX_TYPE ! -regex \
        '\./\.git/.*|\./media/.*|\./var/.*|.*\.svn/.*|\./\.idea/.*|.*\.gz|.*\.tgz|.*\.bz|.*\.bz2|.*\.tbz2|.*\.tbz|.*\.zip|.*\.tar|.*DS_Store' \
        -print0 | xargs -0 git add -f

    git commit -m "initial merchant deployment" >/dev/null 2>&1
}


####################################################################################################
##  MAIN  ##########################################################################################
####################################################################################################

checkTools

####################################################################################################
#   Parse options and set environment.
OPTIONS=`getopt -o Hc:frim:h:D:u:p:b:e:l: -l help,config-file:,force,reconfigure,install,mode:,host:,database:,user:,password:,base-url:,email:,locale: -n "$0" -- "$@"`

if [[ $? != 0 ]]
then
    echo "Failed parsing options." >&2
    echo
    showHelp
    exit 1
fi

eval set -- "$OPTIONS"

while true; do
    case "$1" in
        -H|--help )             showHelp; exit 0;;
        -c|--config-file )      OPT_CONFIG_FILE="$2"; shift 2;;
        -f|--force )            FORCE_RESTORE=1; shift 1;;
        -r|--reconfigure )      MODE="reconfigure"; shift 1;;
        -i|--install-only )     MODE="install-only"; shift 1;;
        -m|--mode )             MODE="$2"; shift 2;;
        -h|--host )             OPT_DBHOST="$2"; shift 2;;
        -D|--database )         OPT_DBNAME="$2"; shift 2;;
        -u|--user )             OPT_DBUSER="$2"; shift 2;;
        -p|--password )         OPT_DBPASS="$2"; shift 2;;
        -b|--base-url )         OPT_BASE_URL="$2"; shift 2;;
        -e|--email )            OPT_ADMIN_EMAIL="$2"; shift 2;;
        -l|--locale )           OPT_LOCALE_CODE="$2"; shift 2;;
        -- ) shift; break;;
        * ) echo "Internal getopt parse error."; echo; showHelp; exit 1;;
    esac
done


####################################################################################################
# Execute.

# Catch bad modes before initializing variables.
case "$MODE" in
    reconfigure|install-only|code|db) ;;
    '') ;;
    *) echo "Bad mode."; echo; showHelp; exit 1 ;;
esac

initVariables

case "$MODE" in
    # --reconfigure
    reconfigure)
        doFileReconfigure
        doDbReconfigure
        ;;

    # --install-only
    install-only)
        installOnly
        ;;

    # --mode code
    code)
        extractCode
        doFileReconfigure
        gitAdd
        ;;

    # --mode db
    db)
        createDb
        restoreDb
        doDbReconfigure
        ;;

    # Empty "mode". Do everything.
    '')
        ( createDb ) &
        extractCode
        doFileReconfigure
        ( gitAddQuiet ) &
        restoreDb
        doDbReconfigure
        ;;
esac

exit 0
