
# frozen_string_literal: true

require 'rake'
require 'date'

VERSION_FILE = 'lib/json_to_toon/version.rb'
CHANGELOG_FILE = 'CHANGELOG.md'

def current_version
	content = File.read(VERSION_FILE)
	m = content.match(/VERSION\s*=\s*['"](\d+\.\d+\.\d+)['"]/) or raise "Can't find version"
	m[1]
end

def bump_version(version, level)
	major, minor, patch = version.split('.').map(&:to_i)
	case level
	when 'major'
		major += 1; minor = 0; patch = 0
	when 'minor'
		minor += 1; patch = 0
	else
		patch += 1
	end
	[major, minor, patch].join('.')
end

def update_version_file(new_version)
	text = File.read(VERSION_FILE)
	new_text = text.sub(/VERSION\s*=\s*['"](\d+\.\d+\.\d+)['"]/, "VERSION = '#{new_version}'")
	File.write(VERSION_FILE, new_text)
end

def prepend_changelog(new_version)
	date = Date.today.strftime('%Y-%m-%d')
	header = "## [v#{new_version}] - #{date}\n\n- Release: version #{new_version}\n\n"
	content = File.exist?(CHANGELOG_FILE) ? File.read(CHANGELOG_FILE) : "# Changelog\n\n"
	# Insert after the main title if present
	if content =~ /# Changelog\n\n/m
		parts = content.split("# Changelog\n\n", 2)
		new_content = parts[0] + "# Changelog\n\n" + header + parts[1]
	else
		new_content = header + content
	end
	File.write(CHANGELOG_FILE, new_content)
end

desc 'Bump version, update CHANGELOG, commit and create annotated tag'
task :release, [:level, :push] do |_t, args|
	level = (args[:level] || 'patch').to_s
	push = args[:push] == 'true'

	old_version = current_version
	new_version = bump_version(old_version, level)

	puts "Bumping version: #{old_version} -> #{new_version} (level=#{level})"
	update_version_file(new_version)
	prepend_changelog(new_version)

	sh "git add #{VERSION_FILE} #{CHANGELOG_FILE}"
	sh "git commit -m \"release: v#{new_version}\""
	sh "git tag -a v#{new_version} -m \"Release v#{new_version}\""

	if push
		puts 'Pushing commits and tag to origin...'
		sh 'git push origin HEAD'
		sh "git push origin v#{new_version}"
	else
		puts "Created tag v#{new_version}. Run:\n  git push origin HEAD\n  git push origin v#{new_version}"
	end
end
