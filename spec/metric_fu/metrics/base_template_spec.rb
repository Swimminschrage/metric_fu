require "spec_helper"
require 'tempfile'
require 'erb'

describe MetricFu::Template do

  before(:each) do
    @template =  Template.new
  end

  describe "#erbify" do
    it 'should evaluate a erb doc' do
      section = 'section'
      erb = double('erb')
      erb.should_receive(:result)
      @template.should_receive(:template).and_return('foo')
      @template.should_receive(:erb_template_source).with('foo').and_return(erb)
      @template.send(:erbify, section)
    end
  end

  describe "#template_exists? " do

    before(:each) do
      @section = double('section')
    end

    describe 'if the template exists' do
      it 'should return true' do
        Tempfile.open('file') do |file|
          @template.should_receive(:template).with(@section).and_return(file.path)
          result = @template.send(:template_exists?,@section)
          result.should be_true
        end
      end
    end

    describe 'if the template does not exist' do
      it 'should return false' do
        path = 'path'
        @template.should_receive(:template).with(@section).and_return(path)
        result = @template.send(:template_exists?,@section)
        result.should be_false
      end
    end
  end

  describe "#create_instance_var" do
    it 'should set an instance variable with the passed contents' do
      section = 'section'
      contents = 'contents'
      @template.send(:create_instance_var, section, contents)
      @template.instance_variable_get(:@section).should == contents
    end
  end

  describe "#template" do
    it 'should generate the filename of the template file' do
      section = double('section')
      section.stub(:to_s).and_return('section')
      @template.should_receive(:template_directory).and_return('dir')
      result = @template.send(:template, section)
      result.should == "dir/section.html.erb"
    end
  end

  describe "#output_filename" do
    it 'should generate the filename of the output file' do
      section = double('section')
      section.should_receive(:to_s).and_return('section')
      result = @template.send(:output_filename, section)
      result.should == "section.html"
    end
  end

  describe "#inline_css" do
    it 'should return the contents of a css file' do
      css = 'mycss.css'
      dir = File.join(MetricFu.lib_dir, 'templates', css)
      contents = "css contents"
      MetricFu::Utility.should_receive(:binread).with(dir).and_return(contents)
      result = @template.send(:inline_css, css)
      expect(result).to eq(contents)
    end
  end

  describe "#link_to_filename " do
    describe "when on OS X" do
      before(:each) do
        config = double("configuration")
        config.stub(:osx?).and_return(true)
        config.stub(:platform).and_return('universal-darwin-9.0')
        config.stub(:templates_option).with('darwin_txmt_protocol_no_thanks').and_return(false)
        config.stub(:templates_option).with('link_prefix').and_return(nil)
        MetricFu.stub(:configuration).and_return(config)
      end

      it 'should return a textmate protocol link' do
        @template.should_receive(:complete_file_path).with('filename').and_return('/expanded/filename')
        result = @template.send(:link_to_filename, 'filename')
        result.should eql("<a href='txmt://open/?url=file://" \
                         + "/expanded/filename'>filename</a>")
      end

      it "should do the right thing with a filename that starts with a slash" do
        @template.should_receive(:complete_file_path).with('/filename').and_return('/expanded/filename')
        result = @template.send(:link_to_filename, '/filename')
        result.should eql("<a href='txmt://open/?url=file://" \
                         + "/expanded/filename'>/filename</a>")
      end

      it "should include a line number" do
        @template.should_receive(:complete_file_path).with('filename').and_return('/expanded/filename')
        result = @template.send(:link_to_filename, 'filename', 6)
        result.should eql("<a href='txmt://open/?url=file://" \
                         + "/expanded/filename&line=6'>filename:6</a>")
      end

      describe "but no thanks for txtmt" do
        before(:each) do
          config = double("configuration")
          config.stub(:osx?).and_return(true)
          config.stub(:platform).and_return('universal-darwin-9.0')
          config.stub(:templates_option).with('darwin_txmt_protocol_no_thanks').and_return(true)
          config.stub(:templates_option).with('link_prefix').and_return('file:/')
          MetricFu.stub(:configuration).and_return(config)
          @template.should_receive(:complete_file_path).and_return('filename')
        end

        it "should return a file protocol link" do
          name = "filename"
          result = @template.send(:link_to_filename, name)
          result.should == "<a href='file://filename'>filename</a>"
        end
      end

      describe "and given link text" do
        it "should use the submitted link text" do
          @template.should_receive(:complete_file_path).with('filename').and_return('/expanded/filename')
          result = @template.send(:link_to_filename, 'filename', 6, 'link content')
          result.should eql("<a href='txmt://open/?url=file://" \
                           + "/expanded/filename&line=6'>link content</a>")
        end
      end
    end

    describe "when on other platforms"  do
      before(:each) do
        config = double("configuration")
        config.should_receive(:osx?).and_return(false)
        config.stub(:templates_option).with('link_prefix').and_return('file:/')
        MetricFu.stub(:configuration).and_return(config)
        @template.should_receive(:complete_file_path).and_return('filename')
      end

      it 'should return a file protocol link' do
        name = "filename"
        result = @template.send(:link_to_filename, name)
        result.should == "<a href='file://filename'>filename</a>"
      end
    end
    describe "when configured with a link_prefix" do
      before(:each) do
        config = double("configuration")
        config.stub(:templates_option).with('darwin_txmt_protocol_no_thanks').and_return(true)
        config.stub(:templates_option).with('link_prefix').and_return('http://example.org/files')
        config.stub(:osx?).and_return(true)
        MetricFu.stub(:configuration).and_return(config)
        @template.should_receive(:complete_file_path).and_return('filename')
      end

      it 'should return a http protocol link' do
        name = "filename"
        result = @template.send(:link_to_filename, name)
        result.should == "<a href='http://example.org/files/filename'>filename</a>"
      end
    end
  end

  describe "#cycle" do
    it 'should return the first_value passed if iteration passed is even' do
      first_val = "first"
      second_val = "second"
      iter = 2
      result = @template.send(:cycle, first_val, second_val, iter)
      result.should == first_val
    end

    it 'should return the second_value passed if iteration passed is odd' do
      first_val = "first"
      second_val = "second"
      iter = 1
      result = @template.send(:cycle, first_val, second_val, iter)
      result.should == second_val
    end
  end

end
