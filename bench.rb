require 'fileutils'

original_branch = `git rev-parse --abbrev-ref HEAD`.strip

ids = `git log -3 --pretty=format:"%H"`


ts = Time.now.to_s.gsub(' ', '_')

bench_files = `find . -type f -name "*_bench.rb"`

`rm -r ./benches/logs/*`

#
# bench_files.lines.each do |file_name|
#   current_branch = `git rev-parse --abbrev-ref HEAD`.strip
#   clean_file_name = file_name.split('/').last.split('.').first
#
#   logs = `ruby #{file_name}`
#
#   new_dir_name = "benches/logs/#{clean_file_name}/"
#   new_file_name = "#{ts}--#{current_branch.gsub('/', '>')}"
#
#   FileUtils.mkdir_p(new_dir_name)
#
#   File.open(new_dir_name + new_file_name, 'w') do |file|
#     file.write(logs)
#   end
#
# end
