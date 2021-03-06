namespace :load do
  # Import all mofid/mofkey in /lib/assets/mofid/*.csv
  desc "Import all csv files from mofid/mofkey"
  suc = 0
  fail = 0
  csvs = Dir.entries(Rails.root.join("lib", "assets", "mofid"))
  len = csvs.size
  task csv: :environment do
    csvs.each do |file|
      next if file[file.size - 4, file.size] != ".csv"
      results = File.open(Rails.root.join("lib", "assets", "mofid", file), 'r')

      results.each_with_index do |line, line_number|
        begin
          line = line.split(",")
          mofid = line[1]
          mofkey = line[2]
          mof = Mof.find_by(name: line[0])
          mof.update(mofid: mofid, mofkey: mofkey)
          suc += 1
        rescue
          puts "file: #{file} -- #{line}"
          fail += 1
        end
      end
      results.close
      puts "suc: #{suc}, fail: #{fail}, out of: #{len}"
    end
  end
end
