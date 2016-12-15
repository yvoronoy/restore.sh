# Magento Support Restore Tool
~/bin/restore.sh

This script is designed to be run from folder with Magento dumps.
It restores dump files created by Magento Support module or backup.sh script:
```
code dump (for ex. f0fe94ea2a96cfb1ff3be6dada7be17f.201205151512.sql.gz)
DB dump (for ex. f0fe94ea2a96cfb1ff3be6dada7be17f.201205151512.tar.gz)
```
![Screencast restore.sh](https://github.com/yvoronoy/ReadmeMedia/blob/master/restore.sh.gif)

### Options
```
restore.sh [option]
[options]
-h|--help - show available params for script
-w|--without-config - force do not use config
-f|--force - force install without wizzard
-r|--reconfigure - ReConfigure current magento instance
-i|--clean-install - Standard install procedure through CLI
```

### Configuration file
You can use own configuration file.
Create new file .restore.conf in your home directory. (~/.restore.conf)

Add configuration params:
```
DBHOST=localhost
DBUSER=your_user
DBPASS=your_pass
BASE_URL_PREFIX=http://dev.local/path/to/magento/
```
Run script

- DB name will be DBUSER DBPREFIX CURENT_DIR_NAME (ex: root_magento_sup1234) 
- Base url will be BASE_URL_PREFIX AND CURRENT_DIR_NAME (ex: http://dev.local/path/to/magento/current)

### Progress bar
In order to see progress bar while restoring DB dump you should install pv util.
