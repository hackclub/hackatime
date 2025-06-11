# Application metrics calculated at startup

lines_of_code = `find . -name "*.rb" -not -path "./vendor/*" -not -path "./tmp/*" -exec wc -l {} + | tail -1 | awk '{print $1}'`.strip.to_i rescue 0
Rails.application.config.lines_of_code = lines_of_code
