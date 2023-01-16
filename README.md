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
* Allow sudo for all users on the backup script file only 
```sh
# Edit sudoer file will root user
sudo visudo

# Add the following line to the end of the file
* ALL=(root) NOPASSWD: /backup.sh
```
* Install `gdrive` command line tool
* mysql is configured to allow remote connections.

## TODO
* Add check to remove backups older than 30 days.
* Integrate with Google Drive to offload backups from server.
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
0 3 * * * /path/to/backup.sh

# This will run the script every day at 3am.
```

## Linux Server Script Sample
The file `backup.sh` here is your backup script sample.You can use it to take database backups of domains on a Linux server. This includes a step to back up the active WordPress theme and the media uploads using `wp-cli`. It should compress all of that into a file, then send an email with the results of the backup.  

This script should work on Ubuntu as well as on CentOS, as long as the necessary dependencies are installed on the server. The script uses standard Linux commands such as `ls`, `grep`, `awk`, `mysqldump`, `wp`, `cp`, and `tar` to perform the backups. These commands are available on both Ubuntu and CentOS. However, the package names for the dependencies could be different between Ubuntu and CentOS. For example, wp-cli package is available in Ubuntu's default package manager apt, whereas on CentOS you will have to install it via other means such as downloading with the instructions above. In addition, the path to the webroot directory and the location of the WordPress configuration file might be different on Ubuntu compared to CentOS.  Make sure to verify the correct paths and dependencies before running the script on an Ubuntu server.

## GDrive Integration
First, you will need to install the `gdrive` command line tool by following the instructions on this page: https://github.com/gdrive-org/gdrive

Once `gdrive` is installed, you will need to authenticate it with your Google account by running the command gdrive about. This will open a browser window where you can sign in to your Google account and give gdrive access to your Google Drive.

Next, you can use the gdrive upload command to upload the tarball files to Google Drive. For example, you can add the following command to your script after the tarball files have been created:

```sh
gdrive upload --parent <folder_id> $backup_dir/$domain-$timestamp.tar.gz
```

## Slack integration
```sh
# Set the Slack Webhook URL
SLACK_WEBHOOK_URL="https://hooks.slack.com/services/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"

# Set the Slack channel to post to
SLACK_CHANNEL="#backup-results"

# Set the Slack username to post as
SLACK_USERNAME="Backup Script"

# Set the Slack icon to use
SLACK_ICON=":floppy_disk:"

# Post the results to Slack
curl -X POST -H 'Content-type: application/json' --data "{\"channel\": \"$SLACK_CHANNEL\", \"username\": \"$SLACK_USERNAME\", \"icon_emoji\": \"$SLACK_ICON\", \"text\": \"$results\"}" $SLACK_WEBHOOK_URL
```
