# restore.sh
Magento Support Restore Script

This script is designed to be run from folder with Magento dumps.
It restores dump files created by Magento Support module or backup.sh script:
```
code dump (for ex. f0fe94ea2a96cfb1ff3be6dada7be17f.201205151512.sql.gz)
DB dump (for ex. f0fe94ea2a96cfb1ff3be6dada7be17f.201205151512.tar.gz)
```

### Options
```
restore.sh [option]
[options]
-h|--help - show available params for script
-w|--without-config - force do not use config
-f|--force - force install without wizzard
-c|--reconfigure - ReConfigure current magento instance
-r|--clean-install - Standard install procedure through CLI
```

### Configuration file
You can use own configuration file.
Create new file .restore.conf in your home directory. (~/.restore.conf)

Add configuration params:
```
DBHOST=sparta-db
DBUSER=your_user
DBPASS=your_pass
BASE_URL_PREFIX=http://dev.local/magento/custom/
```
Run script

- DB name will be DBUSER DBPREFIX CURENT_DIR_NAME (ex: root_magento_sup1234) 
- Base url will be BASE_URL_PREFIX AND CURRENT_DIR_NAME (ex: http://dev.local/path/to/magento/current)

### Some examples
```
$ls
f0fe94ea2a96cfb1ff3be6dada7be17f.201205151512.sql.gz  f0fe94ea2a96cfb1ff3be6dada7be17f.201205151512.tar.gz

$restore.sh
Enter DB name and press [ENTER]: mage_tmp
Enter DB user and press [ENTER]: root
Enter DB password and press [ENTER]: root
Enter Base url and press [ENTER]: http://dev.local/path/to/magento/
Start create new DB mage_tmp - OK
Please wait DB dump start restore - OK
Please wait Code dump start extract - OK
```
### Progress bar
In order to see progress bar while restoring DB dump you can install pv util.
