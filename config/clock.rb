require "./config/boot"
require "./config/environment"
require "dropbox_backup"

module Clockwork
  configure do |config|
    config[:tz] = "America/New_York"
  end

  every(1.day, "Backup to Dropbox", at: "01:00") do
    DropboxBackup.new.backup
  end

  every(1.day, "Backfill Item Counts", at: "00:00") do
    start_date = Item.unscoped.order("created_at ASC").select("created_at").first.created_at.to_date
    (start_date..Date.today).each do |date|
      puts "Processing #{date}"
      ItemCount.update_or_create_day(date)
    end
  end
end
