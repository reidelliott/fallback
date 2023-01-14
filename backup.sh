#!/bin/bash

# Server codename. Uncomment the next line and update the value within ""
server_code="LS1"

# Set the directory where backups will be stored
backup_dir="/backup"

# Check if $backup_dir exists, create it if not
if [ ! -d $backup_dir ]; then
    sudo mkdir $backup_dir
    echo "Directory $backup_dir created."
else
    echo "Directory $backup_dir already exists. Cool."
fi

# Set the directory for the domains
vhosts="/var/www/vhosts"

# Get the domain to backup
if [ -z "$1" ]; then
    echo "No domain specified, using all domains..."
    domains=`ls $vhosts`
else
    echo "Backing up $1..."
    domains=$1
fi

# Create a log file in the backup directory
log_file=$backup_dir/backup.log
sudo touch $log_file && sudo chmod 775 $log_file

# Set the recipient email address
recipient="reidburnett@gmail.com"

# Initialize an empty variable to store the results
results=""

# Loop through each domain and create a backup of its database and theme and media uploads. Finally, compress the backups and remove the backup folder.
for domain in $domains
do
    echo "Starting backup for $domain"

    # Check if wp-cli.yml exists to determine filepaths
    if [ -f httpdocs/production/current/wp-cli.yml ]; then
        echo "wp-cli.yml file found, using custom paths..."
        echo "Retrieving database credentials..."

        web_user=`grep $vhosts/$domain /etc/passwd | cut -d: -f1`
        # Get the database name, username, and password for the domain
        db_name=`sudo -u $web_user grep DB_NAME $vhosts/$domain/httpdocs/production/shared/.env | cut -d '=' -f2`
        db_user=`sudo -u $web_user grep DB_USER $vhosts/$domain/httpdocs/production/shared/.env | cut -d '=' -f2`
        db_pass=`sudo -u $web_user grep DB_PASSWORD $vhosts/$domain/httpdocs/production/shared/.env | cut -d '=' -f2`

        theme_path=`sudo -u $web_user -i -- wp --path=httpdocs/production/current/web/wp theme path`
        active_theme=`sudo -u $web_user -i -- wp --path=httpdocs/production/current/web/wp theme list --status=active --field=name`
        media_path=$vhosts/$domain'/httpdocs/production/shared/web/app/uploads'

    else
        echo "wp-cli.yml file not found, using standard WordPress filepaths..."
        echo "Retrieving database credentials..."

        # Get the database name, username, and password for the domain
        db_name=`grep "define('DB_NAME'" $vhosts/$domain/wp-config.php | awk -F"'" '{print $4}'`
        db_user=`grep "define('DB_USER'" $vhosts/$domain/wp-config.php | awk -F"'" '{print $4}'`
        db_pass=`grep "define('DB_PASSWORD'" $vhosts/$domain/wp-config.php | awk -F"'" '{print $4}'`

        theme_path=`sudo -u $web_user wp theme path`
        active_theme=`sudo -u $web_user wp theme list --status=active --field=name`
        media_path=$vhosts/$domain'/current/web/app/uploads'
    fi

    # Set the timestamp
    timestamp=$(date +%Y-%m-%d-%H-%M)

    # Check if a domain-specific subdirectory exists, create it if not
    if [ ! -d $backup_dir/$domain ]; then
        sudo mkdir $backup_dir/$domain
        echo "Creating a backup subdirectory for $domain..."
    else
        echo "Directory $domain already exists. Cool."
    fi

    # echo "Backing up the database..."
    # Create a backup of the database
    # sudo -u $web_user wp --path=httpdocs/production/current/web/wp db export $backup_dir/$domain/$domain-$timestamp.sql || { sudo -u $web_user echo "$(date +%Y-%m-%d-%H-%M) : Failed to backup $domain $db_name" >> $log_file; results+="$(date +%Y-%m-%d-%H-%M) : Failed to backup $domain $db_name\n"; sudo echo "Failed to backup $domain $db_name"; continue; }
    # sudo echo "$(date +%Y-%m-%d-%H-%M) : Successfully backed up $domain $db_name" >> $log_file
    # echo "Successfully backed up $domain $db_name"
    # results+="$(date +%Y-%m-%d-%H-%M) : Successfully backed up $domain $db_name\n"

    echo "Backing up the active theme..."
    # Backup the active theme
    sudo cp -r $theme_path/$active_theme $backup_dir/$domain || { sudo echo "$(date +%Y-%m-%d-%H-%M) : Failed to backup $domain $active_theme" >> $log_file; results+="$(date +%Y-%m-%d-%H-%M) : Failed to backup $domain $active_theme\n";continue; }
    sudo echo "$(date +%Y-%m-%d-%H-%M) : Successfully backed up $domain $active_theme" >> $log_file
    echo "✅ Successfully backed up $domain theme, '$active_theme'"
    results+="$(date +%Y-%m-%d-%H-%M) : Successfully backed up $domain $active_theme. \n"

    echo "Backing up the media uploads..."
    # Backup the media uploads
    sudo cp -r $media_path $backup_dir/$domain/ || { sudo echo "$(date +%Y-%m-%d-%H-%M) : Failed to backup $domain media uploads" >> $log_file; results+="$(date +%Y-%m-%d-%H-%M) : Failed to backup $domain media uploads\n"; echo "Failed to backup $domain media uploads"; continue; }
    sudo echo "$(date +%Y-%m-%d-%H-%M) : Successfully backed up $domain media uploads" >> $log_file
    echo "✅ Successfully backed up the media uploads for $domain"
    results+="$(date +%Y-%m-%d-%H-%M) : Successfully backed up $domain media uploads. \n"

    echo "Compressing the backup, and cleaning house..."
    # Create the Gzip tarball
    sudo tar -czf $backup_dir/$domain-$timestamp.tar.gz $backup_dir/$domain
    echo "✅ Compressed."

    # Remove the original folder
    sudo rm -rf $backup_dir/$domain
    echo "✅ Cleaned."
    results+="$(date +%Y-%m-%d-%H-%M) : Compressed backup as $domain-$timestamp.tar.gz and cleaned house. \n"
    echo "Backup for $domain completed!"

done

echo "Sending an email with the backup results..."
# Send the email with the summary of the results
echo -e $results | mail -s "Backup report for all domains on \$server_code" $recipient

# Remove tarballs older than 7 days
sudo find $backup_dir/*.tar.gz -mtime +7 -delete
