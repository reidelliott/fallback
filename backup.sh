#!/bin/bash

# Server codename. Uncomment the next line and update the value within ""
server_code="LS9"

# Set the directory where backups will be stored
backup_dir="/path/to/backup/directory"

# Get a list of all domains on the server
domains=`ls /var/www`

# Create a log file in the backup directory
log_file=$backup_dir/backup.log
touch $log_file

# Set an empty variable for results
results=""

# Loop through each domain and create a backup of its database and theme and media uploads. Finally, compress the backups and remove the backup folder.
for domain in $domains
do
    echo "Starting backup for $domain"
    echo "Retrieving database credentials..."
    # Get the database name, username, and password for the domain
    db_name=`grep "define('DB_NAME'" /var/www/$domain/wp-config.php | awk -F"'" '{print $4}'`
    db_user=`grep "define('DB_USER'" /var/www/$domain/wp-config.php | awk -F"'" '{print $4}'`
    db_pass=`grep "define('DB_PASSWORD'" /var/www/$domain/wp-config.php | awk -F"'" '{print $4}'`
    
    # Set the timestamp
    timestamp=$(date +%Y-%m-%d-%H-%M)
    
    echo "Backing up the database..."
    # Create a backup of the database
    mysqldump -u $db_user -p$db_pass $db_name > $backup_dir/$domain/$domain-$timestamp.sql  || { echo "$(date +%Y-%m-%d-%H-%M) : Failed to backup $domain $db_name" >> $log_file; results+="$(date +%Y-%m-%d-%H-%M) : Failed to backup $domain $db_name\n"; continue; }
    echo "$(date +%Y-%m-%d-%H-%M) : Successfully backed up $domain $db_name" >> $log_file
    results+="$(date +%Y-%m-%d-%H-%M) : Successfully backed up $domain $db_name\n"
    
    echo "Backing up the active theme..."
    # Backup the active theme
    theme_path=`wp theme path --path=/var/www/$domain`
    active_theme=`wp theme get --field=stylesheet --path=$theme_path`
    cp -r $theme_path/$active_theme $backup_dir/$domain/$domain-$timestamp  || { echo "$(date +%Y-%m-%d-%H-%M) : Failed to backup $domain $active_theme" >> $log_file; results+="$(date +%Y-%m-%d-%H-%M) : Failed to backup $domain $active_theme\n";continue; }
    echo "$(date +%Y-%m-%d-%H-%M) : Successfully backed up $domain $active_theme" >> $log_file
    results+="$(date +%Y-%m-%d-%H-%M) : Successfully backed up $domain $active_theme\n"

    echo "Backing up the media uploads..."
    # Backup the media uploads
    cp -r /var/www/$domain/wp-content/uploads $backup_dir/$domain/$domain-$timestamp/  || { echo "$(date +%Y-%m-%d-%H-%M) : Failed to backup $domain media uploads" >> $log_file; results+="$(date +%Y-%m-%d-%H-%M) : Failed to backup $domain media uploads\n"; continue; }
    echo "$(date +%Y-%m-%d-%H-%M) : Successfully backed up $domain media uploads" >> $log_file
    results+="$(date +%Y-%m-%d-%H-%M) : Successfully backed up $domain media uploads\n"

    echo "Compressing the backup, and cleaning house..."
    # Create the Gzip tarball
    tar -czvf $backup_dir/$domain-$timestamp.tar.gz $backup_dir/$domain
    # Remove the original folder
    rm -rf $backup_dir/$domain

    echo "Backup for $domain completed!"

done

# Send the email with the summary of the results
echo -e $results | mail -s "Backup report for all domains on \$server_code" $recipient