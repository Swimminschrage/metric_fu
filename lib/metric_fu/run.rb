MetricFu.configure
module MetricFu
  class Run
    def initialize
      STDOUT.sync = true
    end
    def run(options={})
      configure_run(options)
      measure
      reset_git(options) if git_configured? options
      display_results if options[:open]
    end

    def report_metrics(metrics=MetricFu::Metric.enabled_metrics)
      metrics.map(&:name)
    end
    def measure
      reporter.start
      report_metrics.each {|metric|
        reporter.start_metric(metric)
        MetricFu.result.add(metric)
        reporter.finish_metric(metric)
      }
      reporter.finish
    end
    def display_results
      reporter.display_results
    end
    private
    def configure_run(options)
      disable_metrics(options)
      configure_git(options)
      configure_formatters(options)
    end
    def disable_metrics(options)
      return if options.size == 0
      report_metrics.each do |metric|
        metric = metric.to_sym
        if (metric_options = options[metric] )
          mf_debug "using metric #{metric}"
          configure_metric(metric, metric_options) if metric_options.is_a?(Hash)
        else
          mf_debug "disabling metric #{metric}"
          MetricFu::Metric.get_metric(metric).enabled = false
          mf_debug "active metrics are #{MetricFu::Metric.enabled_metrics.inspect}"
        end
      end
    end
    def configure_metric(metric, metric_options)
      MetricFu::Configuration.run do |config|
        config.configure_metric(metric) do |metric|
          metric_options.each do |option, value|
            mf_log "Setting #{metric} option #{option} to #{value}"
            metric.public_send("#{option}=", value)
          end
        end
      end
    end
    def configure_formatters(options)
      filename = options[:githash] # Set the filename for the output; nil is a valid value

      # Configure from command line if any.
      if options[:format]
        MetricFu.configuration.formatters.clear # Command-line format takes precedence.
        Array(options[:format]).each do |format, o|
          MetricFu.configuration.configure_formatter(format, o, filename)
        end
      end
      # If no formatters specified, use defaults.
      if MetricFu.configuration.formatters.empty?
        Array(MetricFu::Formatter::DEFAULT).each do |format, o|
          MetricFu.configuration.configure_formatter(format, o, filename)
        end
      end
    end
    def configure_git(options)
      return unless git_configured? options

      execute_with_git do
        begin
          @git ||= Git.init
          @orig_branch ||= @git.current_branch

          mf_log "CHECKING OUT '#{options[:githash]}'"
          @git.checkout(options[:githash])
        rescue Git::GitExecuteError => e
          mf_log "Unable to checkout githash: #{options[:githash]}"
          raise "Unable to checkout githash: #{options[:githash]}: #{e}"
        end
      end
    end
    def reset_git(options)
      return unless git_configured? options

      execute_with_git do
        begin
          @git ||= Git.init
          mf_log "CHECKING OUT ORIGINAL BRANCH '#{@orig_branch}'"
          @git.checkout(@orig_branch)
        rescue Git::GitExecuteError => e
          mf_log "Unable to reset git status to branch '#{@orig_branch}'"
          raise "Unable to reset git status to branch '#{@orig_branch}'"
        end
      end
    end
    def execute_with_git(&block)
      begin
        require 'git'
        yield
      rescue LoadError => e
        mf_log 'Cannot select git hash; please install git gem'
        raise 'Cannot select git hash; please install git gem'
      end
    end
    def git_configured?(options)
      options.size > 0 && options.has_key?(:githash)
    end
    def reporter
      MetricFu::Reporter.new(MetricFu.configuration.formatters)
    end
  end
end
