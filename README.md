# Additions and Updates to Restore Script
- Fixed SQL queries so that they accept table names of only digits.
- Fixed dissagreement between help statement and actual option usage.
- Changed handling of configuration file so that values from the config file are always used but are overridden by values from the command line.
- The added and commented out code is a start at adding/changing the existing table name prefix. Table prefix handling is incomplete.

These changes have been tested with Ubuntu 14.04 Server.

# Magento Support Restore Script
> restore.sh

This script is designed to be run from folder with Magento dumps.
It restores dump files created by Magento Support module or backup.sh script:
```
code dump (for ex. f0fe94ea2a96cfb1ff3be6dada7be17f.201205151512.sql.gz)
DB dump (for ex. f0fe94ea2a96cfb1ff3be6dada7be17f.201205151512.tar.gz)
```
![Screencast restore.sh](https://github.com/yvoronoy/ReadmeMedia/blob/master/restore.sh.gif)

### Options
```
Usage: ./restore.sh [option]
    -h, --help            show available params for script
    -w, --without-config  force do not use config
    -f, --force           force install without wizzard
    -r, --reconfigure     ReConfigure current magento instance
    -c, --clean-install   Standard install procedure through CLI

Your "~/.restore.conf" file must be manually created in your home directory.

Missing entries are treated as empty strings.

In most cases, if the requested value is left blank on the command line then
the corresponding value from the config file is used. In the special case
of the DB name, If the DB name is empty in the config file and none is entered
on the command line then the current working directory basename is used.
Digits are allowed as a DB name.

Sample "~/.restore.conf":
DBHOST=sparta-db
DBNAME=rwoodbury_test
DBUSER=rwoodbury
BASE_URL=http://sparta.corp.magento.com/dev/rwoodbury/
```

### Progress bar
In order to see progress bar while restoring DB dump you should install pv util.
