# Additions and Updates to M1 Restore Script
- Fixed SQL queries so that they accept table names of only digits.
- Fixed dissagreement between help statement and actual option usage.
- Changed handling of configuration file so that values from the config file are always used but are overridden by values from the command line. All configuration values can be overwritten by their matching command line option. Where appropriate, options are similar to using "mysql" client.
- Added modes to only process code or only import data.
- The added and commented out code is a start at adding/changing the existing table name prefix. Table prefix handling is incomplete.
- Added options for setting administrator's email and site language with default values from the user.
- Added automatic restoring of logs archive if it exists.
- A number of automated features, such as caching, are turned off to aid in debugging.

These changes have been tested with Ubuntu 14.04 Server, Debian 8, OS X 10.11 and 10.12, and on 'aws-sparta-web1'.

Code was added to accept other file endings other than ".gz" and to also to accept Bzip2 archives. These alternate endings have not been tested.

Some systems might display the message
> mdoc warning: Empty input line #
Those messages can be ignored.

# Magento 1 Support Restore Script
```
> restore.sh
```

This script is designed to be run from a directory containing Magento dumps.
It restores dump files created by Magento Support module or backup.sh script:
> code dump (for ex. 5a9cefe85f8e1ccc2a5191553f31ab82.201607061906.sql.gz)

> DB dump (for ex. 5a9cefe85f8e1ccc2a5191553f31ab82.201607061906.tar.gz)

## Options
```
-c --config-file <file-name>
        Specify a configuration file.

-f --force
        Install without pause to check data.

-r --reconfigure
        ReConfigure only files and DB.

-i --install-only
        Standard fresh install procedure through CLI.

-m --mode <run-mode>
        This must have one of the following:
        "reconfigure", "install-only", "code", or "db"
        The first two are optional usages of the previous two options.
        "code" tells the script to only decompress the code, and
        "db" to only move the data into the database.

-h --host <host-name>|<ip-address>
        DB host name or IP address, defaults to "sparta-db".

-D --database <name-string>
        Database or schema name.

-u --user <user-name>
        DB user name.

-p --password <password>
        DB password. Default is empty. A password cannot contain spaces.

-b --base-url <url>
        Base URL for this deployment host.
        Defaults to "http://web1.sparta.corp.magento.com/dev/rwoodbury/".
        If this value is set here it is used precisely as given. If it's
        not set then the default or config file value will be used and
        appended with the working directory basename.

-e --email <email-address>
        Admin email address.

-l --locale <locale-code>
        "base/locale/code" configuration value.
```

This script can be located anywhere but it assumes the current working directory is the new deployment directory with the merchant's backup files. Your default ".restore.conf" file must be manually created in your home directory. Or you can pass in the name of a configuration file.

Missing entries are given default values. In most cases, if the requested value is not included on the command line then the corresponding value from the config file is used. In the special case of the DB name, if the DB name is empty in the config file and none is entered on the command line then the current working directory basename is used with the value in DEV_DB_PREFIX. Digits only are allowed as a DB name. Sparta users might not even need a configuration file.

Available config names with their default values are:
```
ADMIN_EMAIL="${USER}@magento.com"
ALT_PHP=
BASE_URL="http://web1.sparta.corp.magento.com/dev/${USER}/"
DBHOST='sparta-db'
DBNAME=
DBPASS=
DBUSER="$USER"
DEBUG_MODE=0
DEV_DB_PREFIX="${USER}_"
LOCALE_CODE=${LANG:0:5}
```

## Example
This is the contents of my "~/.restore.conf" that is running on my OS X workstation:
```
DBHOST=localhost
DBUSER=magento
DBPASS=magpass
DEV_DB_PREFIX=
BASE_URL=http://localhost/
ALT_PHP=/Applications/MAMP/bin/php/php5.6.28/bin/php
```

Say you're working on SUPEE-9999 and your web root is "/Users/rwoodbury/deploys/". Place your dump files in a directory inside your working web root, say "/Users/rwoodbury/deploys/9999/". You should see something like this (and type "n" or "no" to cancel the process):
```
ip-10-236-8-17:9999 rwoodbury$ ./restore.sh
Check parameters:
DB host is: localhost
DB name is: 9999
DB user is: magento
DB pass is: magpass
Full base url is: http://localhost/9999/
Admin email is: rwoodbury@magento.com
Locale code is: en_US
Continue? [Y/n]: n
Interrupted by user, exiting...
ip-10-236-8-17:9999 rwoodbury$
```

# Progress bar
In order to see a progress bar while restoring a dump you will need to install the `pv` utility.

# OS X
OS X users will need to install a newer version of `getopt` from a repository like MacPorts:

`> sudo port install getopt`
