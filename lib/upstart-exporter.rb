require 'yaml'
require 'upstart-exporter/version'
require 'upstart-exporter/errors'
require 'upstart-exporter/templates'
require 'upstart-exporter/exporter_helpers'
require 'upstart-exporter/expanded_exporter'
require 'upstart-exporter/options/global'
require 'upstart-exporter/options/command_line'

module Upstart
  class Exporter
    include Errors
    include ExporterHelpers

    attr_reader :options

    def initialize(command_line_args)
      global_options = Options::Global.new
      command_line_options = Options::CommandLine.new(command_line_args)
      @options = global_options.merge(command_line_options)
      ensure_dirs
    end

    def export
      clear
      export_app
      if options[:commands]['version'] && options[:commands]['version'] == 2
        ExpandedExporter.export(options)
      else
        options[:commands].each do |cmd_name, cmd|
          export_command(cmd_name, cmd)
        end
      end
    end

    def clear
      FileUtils.rm(upstart_conf) if FileTest.file?(upstart_conf)
      Dir[upstart_cmd_conf('*')].each do |f|
        FileUtils.rm(f)
      end
      Dir[helper_cmd_conf('*')].each do |f|
        FileUtils.rm(f)
      end
    end

    protected

    def start_on_runlevel
      lvl = options[:commands]['start_on_runlevel'] || options[:start_on_runlevel]
      "runlevel #{lvl}"
    end

    def stop_on_runlevel
      lvl = options[:commands]['stop_on_runlevel'] || options[:stop_on_runlevel]
      "runlevel #{lvl}"
    end

    def ensure_dirs
      ensure_dir(options[:helper_dir])
      ensure_dir(options[:upstart_dir])
    end

    def export_app
      app_conf = Templates.app(
        :app_name => app_name,
        :run_user => options[:run_user],
        :run_group => options[:run_group],
        :start_on => start_on_runlevel,
        :stop_on => stop_on_runlevel
      )
      File.open(upstart_conf, 'w') do |f|
        f.write(app_conf)
      end
    end

    def ensure_dir(dir)
      FileUtils.mkdir_p(dir) unless FileTest.directory?(dir)
      error "Path #{dir} does not exist" unless FileTest.directory?(dir)
    end

    def upstart_conf
      File.join(options[:upstart_dir], "#{app_name}.conf")
    end

    def export_cmd_upstart_conf(cmd_name)
      cmd_upstart_conf_content = Templates.command(
        :app_name => app_name,
        :start_on => "starting #{app_name}",
        :stop_on => "stopping #{app_name}",
        :respawn => 'respawn',
        :respawn_limit => '',
        :run_user => options[:run_user],
        :run_group => options[:run_group],
        :cmd_name => cmd_name,
        :helper_cmd_conf => helper_cmd_conf(cmd_name)
      )
      File.open(upstart_cmd_conf(cmd_name), 'w') do |f|
        f.write(cmd_upstart_conf_content)
      end
    end

    def export_command(cmd_name, cmd)
      export_cmd_helper(cmd_name, cmd)
      export_cmd_upstart_conf(cmd_name)
    end

  end
end
