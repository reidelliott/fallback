# Fallback
Backup scripts for 1905 New Media. 
These scripts takes a database dump, then uses the `wp-cli` tool to get the path to the theme directory and the name of the active theme, then it copies the theme to the backup directory. It also copies the media uploads to the backup directory. It uses the date command to get the current date and time in the format of `%Y-%m-%d-%H-%M`, and appends this timestamp to the backup directory name, this way each backup will have a unique name, and you can easily identify the date and time when the backup was taken.
It's important to note that the paths '/var/www/$domain' and '/path/to/backup/directory' should be adjusted accordingly to match your server configuration.

## Requirements
* `wp-cli` version ~2.7.1
```sh
# If needed, install WP-CLI 
curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
chmod +x wp-cli.phar
sudo mv wp-cli.phar /usr/local/bin/wp
```
## TODO
* Add check to remove backups older than 30 days.
* Integrate with Dropbox to offload backups from server.
* Create and write to a log file in $backup_dir.
* Skip over failed backups, log failure to log file.
* Send an email with the backup results.
* Check if the wp-cli.yml exists and use it to get the theme path, else go vanilla wp.

## Scheduling
There might be various ways to schedule these backups, either in plesk or directly using contjob.
```sh
# Open the edit view of crontab
crontab -e

# and add this line
0 3 * * * /path/to/script.sh

# This will run the script every day at 3am.
# Replace script.sh with the script you need, such as centosbkup.sh
```

## CentOS7
Here is a script that you can use to take database backups of domains on a Media Temple CentOS7 server. This includes a step to back up the active WordPress theme and the media uploads using `wp-cli`.

```sh
# centosbkup.sh
#!/bin/bash

# Set the directory where backups will be stored
backup_dir="/path/to/backup/directory"

# Get a list of all domains on the server
domains=`ls /var/www`

# Loop through each domain and create a backup of its database and theme and media uploads
for domain in $domains
do
    # Get the database name, username, and password for the domain
    db_name=`grep "define('DB_NAME'" /var/www/$domain/wp-config.php | awk -F"'" '{print $4}'`
    db_user=`grep "define('DB_USER'" /var/www/$domain/wp-config.php | awk -F"'" '{print $4}'`
    db_pass=`grep "define('DB_PASSWORD'" /var/www/$domain/wp-config.php | awk -F"'" '{print $4}'`
    
    # Set the timestamp
    timestamp=$(date +%Y-%m-%d-%H-%M)
    
    # Create a backup of the database
    mysqldump -u $db_user -p$db_pass $db_name > $backup_dir/$domain/$domain-$timestamp.sql
    
    # Backup the active theme
    theme_path=`wp theme path --path=/var/www/$domain`
    active_theme=`wp theme get --field=stylesheet --path=$theme_path`
    cp -r $theme_path/$active_theme $backup_dir/$domain/$domain-$timestamp
    
    # Backup the media uploads
    cp -r /var/www/$domain/wp-content/uploads $backup_dir/$domain/$domain-$timestamp/
    
done
```
