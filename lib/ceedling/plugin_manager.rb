# =========================================================================
#   Ceedling - Test-Centered Build System for C
#   ThrowTheSwitch.org
#   Copyright (c) 2010-24 Mike Karlesky, Mark VanderVoord, & Greg Williams
#   SPDX-License-Identifier: MIT
# =========================================================================

require 'ceedling/constants'

class PluginManager

  constructor :configurator, :plugin_manager_helper, :streaminator, :reportinator, :system_wrapper

  def setup
    @build_fail_registry = []
    @plugin_objects = [] # List so we can preserve order
  end

  def load_programmatic_plugins(plugins, system_objects)
    environment = []

    plugins.each do |plugin|
      # Protect against instantiating object multiple times due to processing config multiple times (option files, etc)
      next if (@plugin_manager_helper.include?(@plugin_objects, plugin))
      begin
        @system_wrapper.require_file( "#{plugin}.rb" )
        object = @plugin_manager_helper.instantiate_plugin_script( camelize(plugin), system_objects, plugin )
        @plugin_objects << object
        environment += object.environment

        # Add plugins to hash of all system objects
        system_objects[plugin.downcase.to_sym] = object
      rescue
        puts "Exception raised while trying to load plugin: #{plugin}"
        raise
      end
    end

    yield( { :environment => environment } ) if (environment.size > 0)
  end

  def plugins_failed?
    return (@build_fail_registry.size > 0)
  end

  def print_plugin_failures
    if (@build_fail_registry.size > 0)
      report = @reportinator.generate_banner('BUILD FAILURE SUMMARY')

      @build_fail_registry.each do |failure|
        report += "#{' - ' if (@build_fail_registry.size > 1)}#{failure}\n"
      end

      report += "\n"

      @streaminator.stream_puts(report, Verbosity::ERRORS)
    end
  end

  def register_build_failure(message)
    @build_fail_registry << message if (message and not message.empty?)
  end

  #### execute all plugin methods ####

  def pre_mock_preprocess(arg_hash); execute_plugins(:pre_mock_preprocess, arg_hash); end
  def post_mock_preprocess(arg_hash); execute_plugins(:post_mock_preprocess, arg_hash); end

  def pre_test_preprocess(arg_hash); execute_plugins(:pre_test_preprocess, arg_hash); end
  def post_test_preprocess(arg_hash); execute_plugins(:post_test_preprocess, arg_hash); end

  def pre_mock_generate(arg_hash); execute_plugins(:pre_mock_generate, arg_hash); end
  def post_mock_generate(arg_hash); execute_plugins(:post_mock_generate, arg_hash); end

  def pre_runner_generate(arg_hash); execute_plugins(:pre_runner_generate, arg_hash); end
  def post_runner_generate(arg_hash); execute_plugins(:post_runner_generate, arg_hash); end

  def pre_compile_execute(arg_hash); execute_plugins(:pre_compile_execute, arg_hash); end
  def post_compile_execute(arg_hash); execute_plugins(:post_compile_execute, arg_hash); end

  def pre_link_execute(arg_hash); execute_plugins(:pre_link_execute, arg_hash); end
  def post_link_execute(arg_hash); execute_plugins(:post_link_execute, arg_hash); end

  def pre_test_fixture_execute(arg_hash); execute_plugins(:pre_test_fixture_execute, arg_hash); end
  def post_test_fixture_execute(arg_hash)
    # Special arbitration: Raw test results are printed or taken over by plugins handling the job
    @streaminator.stream_puts(arg_hash[:shell_result][:output]) if (@configurator.plugins_display_raw_test_results)
    execute_plugins(:post_test_fixture_execute, arg_hash)
  end

  def pre_test(test); execute_plugins(:pre_test, test); end
  def post_test(test); execute_plugins(:post_test, test); end

  def pre_release; execute_plugins(:pre_release); end
  def post_release; execute_plugins(:post_release); end

  def pre_build; execute_plugins(:pre_build); end
  def post_build; execute_plugins(:post_build); end
  def post_error; execute_plugins(:post_error); end

  def summary; execute_plugins(:summary); end

  private ####################################

  def camelize(underscored_name)
    return underscored_name.gsub(/(_|^)([a-z0-9])/) {$2.upcase}
  end

  def execute_plugins(method, *args)
    handlers = 0

    @plugin_objects.each do |plugin|
      handlers += 1 if plugin.respond_to?(method) 
    end

    if handlers > 0
      heading = @reportinator.generate_heading( "Plugins (#{handlers}) > :#{method}" )
      @streaminator.stream_puts(heading, Verbosity::OBNOXIOUS)
    end

    @plugin_objects.each do |plugin|
      begin
        if plugin.respond_to?(method)
          message = @reportinator.generate_progress( " + #{plugin.name}" )
          @streaminator.stream_puts(message, Verbosity::OBNOXIOUS)
          plugin.send(method, *args)
        end
      rescue
        @streaminator.stream_puts("Exception raised in plugin `#{plugin.name}` within build hook :#{method}")
        raise
      end
    end
  end

end
