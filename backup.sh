#!/bin/bash

# Server codename. Uncomment the next line and update the value within ""
server_code="LS1"

# Set the directory where backups will be stored
backup_dir="/backup"

# Check if $backup_dir exists, create it if not
if [ ! -d $backup_dir ]; then
    sudo mkdir -p $backup_dir/$domain || { echo "Error: Failed to create backup directory." ; exit 1; }
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

# Set the heading text
heading_text="Backup Results for $server_code..."

# Format the heading text as bold
results+="*$heading_text* \n"

# Loop through each domain and create a backup of its database and theme and media uploads. Finally, compress the backups and remove the backup folder.
for domain in $domains
do
    echo "Starting backup for $domain"

    # Get the web user for the domain
    web_user=`grep $vhosts/$domain /etc/passwd | cut -d: -f1`

    # Check if wp-cli.yml exists to determine filepaths
    if sudo -u $web_user [ -f $vhosts/$domain/httpdocs/production/current/wp-cli.yml ]; then
        echo "wp-cli.yml file found, using custom paths..."
        echo "Retrieving database credentials..."

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

    echo "Backing up the database..."
    # Create a backup of the database
    db_fail_msg="Failed to backup $domain database $db_name."
    db_ok_msg="Successfully backed up $domain database $db_name."
    sudo -u $web_user -i -- wp --path=httpdocs/production/current/web/wp db export $backup_dir/$domain/$domain-$timestamp.sql || { echo "$(date +%Y-%m-%d-%H-%M): $theme_fail_msg" >> $log_file; results+="$(date +%Y-%m-%d-%H-%M): ❌ $db_fail_msg \n"; echo "❌ $db_fail_msg"; continue; }
    echo "$(date +%Y-%m-%d-%H-%M): $db_ok_msg" >> $log_file
    echo "✅ $db_ok_msg"
    results+="$(date +%Y-%m-%d-%H-%M): ✅ $db_ok_msg \n"

    echo "Backing up the active theme..."
    # Backup the active theme
    theme_fail_msg="Failed to backup $domain theme '$active_theme'."
    theme_ok_msg="Successfully backed up $domain theme, '$active_theme'."
    sudo cp -r $theme_path/$active_theme $backup_dir/$domain || { echo "$(date +%Y-%m-%d-%H-%M): $theme_fail_msg" >> $log_file; results+="$(date +%Y-%m-%d-%H-%M): ❌ $theme_fail_msg \n"; echo "❌ $theme_fail_msg"; continue; }
    echo "$(date +%Y-%m-%d-%H-%M): $theme_ok_msg" >> $log_file
    echo "✅ $theme_ok_msg"
    results+="$(date +%Y-%m-%d-%H-%M): ✅ $theme_ok_msg \n"

    echo "Backing up the media uploads..."
    # Backup the media uploads
    media_fail_msg="Failed to backup $domain media uploads."
    media_ok_msg="Successfully backed up the media uploads for $domain."
    sudo cp -r $media_path $backup_dir/$domain/ || { echo "$(date +%Y-%m-%d-%H-%M): $media_fail_msg" >> $log_file; results+="$(date +%Y-%m-%d-%H-%M): ❌ $media_fail_msg \n"; echo "❌ $media_fail_msg"; continue; }
    echo "$(date +%Y-%m-%d-%H-%M): $media_ok_msg" >> $log_file
    echo "✅ $media_ok_msg"
    results+="$(date +%Y-%m-%d-%H-%M): ✅ $media_ok_msg \n"

    echo "Compressing the backup, and cleaning house..."
    # Create the Gzip tarball
    tar_fail_msg="Failed to compress $domain backup."
    tar_ok_msg="Successfully compressed backup as $domain-$timestamp.tar.gz."
    sudo tar -czf $backup_dir/$domain-$timestamp.tar.gz $backup_dir/$domain || { echo "$(date +%Y-%m-%d-%H-%M): $tar_fail_msg" >> $log_file; results+="$(date +%Y-%m-%d-%H-%M): ❌ $tar_fail_msg \n"; echo "❌ $tar_fail_msg"; continue; }
    echo "✅ $tar_ok_msg"
    results+="$(date +%Y-%m-%d-%H-%M): ✅ $tar_ok_msg \n"

    # Remove the original folder
    clean_fail_msg="Failed to remove domain folder."
    clean_ok_msg="Cleaned $domain folder from $backup_dir."
    sudo rm -rf $backup_dir/$domain || { echo "$(date +%Y-%m-%d-%H-%M): $clean_fail_msg" >> $log_file; results+="$(date +%Y-%m-%d-%H-%M): ❌ $clean_fail_msg \n"; echo "❌ $clean_fail_msg"; continue; }
    echo "✅ $clean_ok_msg"
    results+="$(date +%Y-%m-%d-%H-%M): ✅ $clean_ok_msg \n"

    echo "Backup for $domain completed!"

done

# echo "Sending an email with the backup results..."
# Send the email with the summary of the results
# echo -e $results | mail -s "Backup report for all domains on \$server_code" $recipient

# echo "Posting the backup results to #backup-results Slack channel..."
# Set the Slack Webhook URL
SLACK_WEBHOOK_URL="https://hooks.slack.com/services/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"

# Set the Slack channel to post to
SLACK_CHANNEL="#backup-results"

# Set the Slack username to post as
SLACK_USERNAME="Backup Script"

# Set the Slack icon to use
SLACK_ICON=":floppy_disk:"

# Post the results to Slack
#curl -X POST -H 'Content-type: application/json' --data "{\"channel\": \"$SLACK_CHANNEL\", \"username\": \"$SLACK_USERNAME\", \"icon_emoji\": \"$SLACK_ICON\", \"text\": \"$results\"}" $SLACK_WEBHOOK_URL

echo "Clean up old backups..."
# Remove tarballs older than 7 days
sudo find $backup_dir -mtime +7 -type f -name "*tar.gz" -exec bash -c '
    count=$(find $(dirname {}) -mtime -7 -type f -name "*tar.gz" | wc -l)
    if [ $count -gt 1 ]; then
        rm {}
    fi
' \;

