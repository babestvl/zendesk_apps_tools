require "thor"
require 'zip/zip'
require 'pathname'

module ZendeskAppsTools
  require 'zendesk_apps_support'

  class Command < Thor

    include Thor::Actions
    include ZendeskAppsSupport
    
    source_root File.expand_path(File.join(File.dirname(__FILE__), "../.."))

    @@path = './'
    @@port = 4567

    def self.path
      @@path
    end

    def self.port
      @@port
    end

    desc "new", "Generate a new app"
    def new
      puts "Enter this app author's name:"
      @author_name = get_value_from_stdin(/^\w.*$/, "Invalid name, try again:")

      puts "Enter this app author's email:"
      @author_email = get_value_from_stdin(/^.+@.+\..+$/, "Invalid email, try again:")

      puts "Enter a name for this new app:"
      @app_name = get_value_from_stdin(/^\w.*$/, "Invalid app name, try again:")

      puts "Enter a directory name to save the new app (will create the dir if it dose not exist, default to current dir):"
      while @app_dir = $stdin.readline.chomp.strip do
        @app_dir = './' and break if @app_dir.empty?
        if !File.exists?(@app_dir)
          FileUtils.mkdir_p(@app_dir)
          break
        elsif !File.directory?(@app_dir)
          puts "Invalid dir, try again:"
        else
          break
        end
      end

      directory('template', @app_dir)
    end

    desc "validate", "Validate your app"
    method_option :path, :default => './', :required => false
    def validate
      setup_path(options[:path])
      errors = app_package.validate
      valid = errors.none?

      if valid
        say_status 'validate', 'OK'
      else
        errors.each do |e|
          say_status 'validate', e.to_s
        end
      end

      @destination_stack.pop if options[:path]
      exit 1 unless valid
      true
    end

    desc "package", "Package your app"
    method_option :path, :default => './', :required => false
    def package
      setup_path(options[:path])
      archive_path = File.join(tmp_dir, "app-#{Time.now.strftime('%Y%m%d%H%M%S')}.zip")

      return false unless invoke(:validate, [])

      archive_rel_path = relative_to_original_destination_root(archive_path)

      Zip::ZipFile.open(archive_path, 'w') do |zipfile|
        app_package.files.each do |file|
          say_status "package",  "adding #{file.relative_path}"
          zipfile.add(file.relative_path, app_dir.join('app', file.relative_path).to_path)
        end
      end

      say_status "package", "created at #{archive_rel_path}"
      true
    end

    desc "clean", "Remove temporary files"
    method_option :path, :default => './', :required => false
    def clean
      setup_path(options[:path])

      return unless File.exists?(Pathname.new(File.join(app_dir, "tmp")).to_path)

      inside(self.tmp_dir) do
        FileUtils.rm(Dir["app-*.*", ".*"] - ['.', '..'])
      end
    end

    desc "server", "Run a http server"
    method_option :path, :default => './', :required => false
    method_option :port, :default => 4567, :required => false
    def server
      @@path = options[:path]
      @@port = options[:port]
      setup_path(options[:path])
      require 'zendesk_apps_tools/sass_functions'
      require 'zendesk_apps_tools/server'
    end

    protected

    def get_value_from_stdin(valid_regex, error_msg)
      while input = $stdin.readline.chomp.strip do
        if input.empty? || !(input =~ valid_regex)
          puts error_msg
        else
          break
        end
      end

      return input
    end

    def setup_path(path)
      @destination_stack << relative_to_original_destination_root(path) unless @destination_stack.last == path
    end

    def app_dir
      @app_dir ||= Pathname.new(destination_root)
    end

    def tmp_dir
      @tmp_dir ||= Pathname.new(File.join(app_dir, "tmp")).tap do |dir|
        FileUtils.mkdir_p(dir)
      end
    end

    def app_package
      @app_package ||= Package.new(self.app_dir.join('app').to_path)
    end
  end
end

