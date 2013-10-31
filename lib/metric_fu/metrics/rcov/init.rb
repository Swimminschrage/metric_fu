module MetricFu
  class MetricRcov < Metric

    def name
      :rcov
    end

    def default_run_options
      {
        :environment => 'test',
        :test_files =>  Dir['{spec,test}/**/*_{spec,test}.rb'],
        :rcov_opts => rcov_opts,
        :external => nil,
      }
    end

    def has_graph?
      true
    end

    def enable
      if external_coverage_file
        super
      else
        MetricFu.configuration.mf_debug("RCov is not available. See README")
      end
    end

    def activate
      super
    end

    def external_coverage_file
      run_options.fetch(:external) { nil }
    end

    private


    def rcov_opts
      rcov_opts = [
        "--sort coverage",
        "--no-html",
        "--text-coverage",
        "--no-color",
        "--profile",
        "--exclude-only '.*'",
        '--include-file "\Aapp,\Alib"'
      ]
      rcov_opts << "-Ispec" if File.exist?("spec")
      rcov_opts
    end

  end
end
